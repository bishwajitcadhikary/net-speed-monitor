import Foundation
import Network
import Combine
import AppKit

@MainActor
class NetworkMonitorService: ObservableObject {
    @Published var currentStats = NetworkStats.empty
    @Published var isConnected = false
    @Published var connectionType: NetworkInterface.InterfaceType = .other
    
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor", qos: .utility)
    private var speedCalculator = NetworkSpeedCalculator()
    private var appUsageMonitor = AppUsageMonitor()
    private var pingService = PingService()
    
    private var timer: Timer?
    private var refreshRate: TimeInterval = 1.0
    
    init() {
        setupNetworkMonitoring()
    }
    
    func startMonitoring(refreshRate: TimeInterval = 1.0) {
        self.refreshRate = refreshRate
        
        pathMonitor.start(queue: monitorQueue)
        
        timer = Timer.scheduledTimer(withTimeInterval: refreshRate, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateNetworkStats()
            }
        }
        
        // Initial update
        Task {
            await updateNetworkStats()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        pathMonitor.cancel()
    }
    
    private func setupNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(from: path) ?? .other
            }
        }
    }
    
    private func getConnectionType(from path: NWPath) -> NetworkInterface.InterfaceType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else {
            return .other
        }
    }
    
    private func updateNetworkStats() async {
        let speed = await speedCalculator.getCurrentSpeed()
        let topApps = await appUsageMonitor.getTopApps(limit: 10)
        let activeInterface = getCurrentInterface()
        let publicIP = await getPublicIP()
        let ping = await pingService.ping(host: "8.8.8.8")
        
        currentStats = NetworkStats(
            currentSpeed: speed,
            topApps: topApps,
            activeInterface: activeInterface,
            publicIP: publicIP,
            ping: ping
        )
    }
    
    private func getCurrentInterface() -> NetworkInterface? {
        // Get current network interface information
        // This is a simplified implementation
        return NetworkInterface(
            name: connectionType.rawValue,
            type: connectionType,
            isActive: isConnected,
            ipAddress: getLocalIPAddress()
        )
    }
    
    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" { // WiFi or Ethernet
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                    if addrFamily == UInt8(AF_INET) { break } // Prefer IPv4
                }
            }
        }
        
        freeifaddrs(ifaddr)
        return address
    }
    
    private func getPublicIP() async -> String? {
        guard let url = URL(string: "https://api.ipify.org?format=text") else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
    
    func updateRefreshRate(_ rate: TimeInterval) {
        guard rate != refreshRate else { return }
        
        stopMonitoring()
        startMonitoring(refreshRate: rate)
    }
}

// MARK: - Network Speed Calculator

class NetworkSpeedCalculator {
    private var lastMeasurement: (bytes: (rx: UInt64, tx: UInt64), time: Date)?
    
    func getCurrentSpeed() async -> NetworkSpeed {
        let currentBytes = await getNetworkBytes()
        let currentTime = Date()
        
        defer {
            lastMeasurement = (currentBytes, currentTime)
        }
        
        guard let last = lastMeasurement else {
            return NetworkSpeed()
        }
        
        let timeDiff = currentTime.timeIntervalSince(last.time)
        guard timeDiff > 0 else { return NetworkSpeed() }
        
        let rxDiff = Double(currentBytes.rx > last.bytes.rx ? currentBytes.rx - last.bytes.rx : 0)
        let txDiff = Double(currentBytes.tx > last.bytes.tx ? currentBytes.tx - last.bytes.tx : 0)
        
        return NetworkSpeed(
            upload: txDiff / timeDiff,
            download: rxDiff / timeDiff
        )
    }
    
    private func getNetworkBytes() async -> (rx: UInt64, tx: UInt64) {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var totalRx: UInt64 = 0
                var totalTx: UInt64 = 0
                
                var ifaddr: UnsafeMutablePointer<ifaddrs>?
                guard getifaddrs(&ifaddr) == 0 else {
                    continuation.resume(returning: (0, 0))
                    return
                }
                
                var ptr = ifaddr
                while ptr != nil {
                    defer { ptr = ptr?.pointee.ifa_next }
                    
                    guard let addr = ptr?.pointee.ifa_addr else { continue }
                    guard addr.pointee.sa_family == UInt8(AF_LINK) else { continue }
                    
                    let name = String(cString: ptr!.pointee.ifa_name)
                    if name.hasPrefix("en") || name.hasPrefix("wifi") {
                        let data = ptr!.pointee.ifa_data?.assumingMemoryBound(to: if_data.self).pointee
                        if let data = data {
                            totalRx += UInt64(data.ifi_ibytes)
                            totalTx += UInt64(data.ifi_obytes)
                        }
                    }
                }
                
                freeifaddrs(ifaddr)
                continuation.resume(returning: (totalRx, totalTx))
            }
        }
    }
}

// MARK: - App Usage Monitor

class AppUsageMonitor {
    private let processMonitor = ProcessMonitor()
    
    func getTopApps(limit: Int) async -> [AppNetworkUsage] {
        return await processMonitor.getTopNetworkApps(limit: limit)
    }
}

// MARK: - Process Monitor

class ProcessMonitor: @unchecked Sendable {
    func getTopNetworkApps(limit: Int) async -> [AppNetworkUsage] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let apps = self.parseNettopOutput(limit: limit)
                continuation.resume(returning: apps)
            }
        }
    }
    
    private func parseNettopOutput(limit: Int) -> [AppNetworkUsage] {
        let task = Process()
        task.launchPath = "/usr/bin/nettop"
        task.arguments = ["-P", "-x", "-J", "-l", "1"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return parseNetworkUsage(from: output, limit: limit)
        } catch {
            print("Error running nettop: \(error)")
            return []
        }
    }
    
    private func parseNetworkUsage(from output: String, limit: Int) -> [AppNetworkUsage] {
        var apps: [AppNetworkUsage] = []
        
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            if let app = parseAppUsageLine(line) {
                apps.append(app)
            }
        }
        
        // Sort by total usage and return top apps
        return Array(apps.sorted { $0.totalUsage > $1.totalUsage }.prefix(limit))
    }
    
    private func parseAppUsageLine(_ line: String) -> AppNetworkUsage? {
        // This is a simplified parser - nettop output format can vary
        // In a real implementation, you'd need to parse the JSON output properly
        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        guard components.count >= 6,
              let pid = Int32(components[0]),
              let downloadBytes = Double(components[4]),
              let uploadBytes = Double(components[5]) else {
            return nil
        }
        
        let processName = components[1]
        let bundleId = getBundleIdentifier(for: pid)
        let icon = NSImage.appIcon(for: pid) ?? NSImage.appIcon(for: bundleId ?? "")
        
        return AppNetworkUsage(
            processID: pid,
            processName: processName,
            bundleIdentifier: bundleId,
            upload: uploadBytes,
            download: downloadBytes,
            icon: icon
        )
    }
    
    private func getBundleIdentifier(for pid: Int32) -> String? {
        let runningApp = NSWorkspace.shared.runningApplications.first { $0.processIdentifier == pid }
        return runningApp?.bundleIdentifier
    }
}

// MARK: - Ping Service

class PingService: @unchecked Sendable {
    func ping(host: String) async -> Double? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let task = Process()
                task.launchPath = "/sbin/ping"
                task.arguments = ["-c", "1", "-W", "1000", host]
                
                let pipe = Pipe()
                task.standardOutput = pipe
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    
                    let pingTime = self.parsePingTime(from: output)
                    continuation.resume(returning: pingTime)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func parsePingTime(from output: String) -> Double? {
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            if line.contains("time=") {
                let components = line.components(separatedBy: "time=")
                if components.count > 1 {
                    let timeString = components[1].components(separatedBy: " ")[0]
                    return Double(timeString)
                }
            }
        }
        
        return nil
    }
}

