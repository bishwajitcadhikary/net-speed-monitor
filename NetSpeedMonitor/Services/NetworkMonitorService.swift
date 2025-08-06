import Foundation
import Network
import Combine
import AppKit

@MainActor
class NetworkMonitorService: ObservableObject {
    @Published var currentStats = NetworkStats.empty
    @Published var isConnected = false
    @Published var connectionType: NetworkInterface.InterfaceType = .other
    private var publicIP: String?
    
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
        appUsageMonitor.start()
        pingService.start(host: "8.8.8.8")

        timer = Timer.scheduledTimer(withTimeInterval: refreshRate, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateNetworkStats()
            }
        }

        // Initial update
        updateNetworkStats()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        pathMonitor.cancel()
        appUsageMonitor.stop()
        pingService.stop()
    }
    
    private func setupNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(from: path) ?? .other

                if path.status == .satisfied {
                    Task { [weak self] in
                        self?.publicIP = await self?.getPublicIP()
                    }
                }
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
    
    private func updateNetworkStats() {
        Task {
            let speed = await speedCalculator.getCurrentSpeed()
            let topApps = appUsageMonitor.getTopApps(limit: 10)
            let activeInterface = getCurrentInterface()
            let ping = pingService.getCurrentPingTime()

            currentStats = NetworkStats(
                currentSpeed: speed,
                topApps: topApps,
                activeInterface: activeInterface,
                publicIP: publicIP,
                ping: ping
            )
        }
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

    func start() {
        processMonitor.start()
    }

    func stop() {
        processMonitor.stop()
    }

    func getTopApps(limit: Int) -> [AppNetworkUsage] {
        return processMonitor.getTopNetworkApps(limit: limit)
    }
}

// MARK: - Process Monitor

class ProcessMonitor {
    private var task: Process?
    private var pipe: Pipe?
    private var buffer = ""

    func start() {
        guard task == nil else { return }

        task = Process()
        task?.launchPath = "/usr/bin/nettop"
        task?.arguments = ["-L", "0", "-P", "-x"]

        pipe = Pipe()
        task?.standardOutput = pipe

        pipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8) {
                self?.buffer.append(output)
            }
        }

        do {
            try task?.run()
        } catch {
            print("Error starting nettop: \(error)")
        }
    }

    func stop() {
        task?.terminate()
        task = nil
        pipe?.fileHandleForReading.readabilityHandler = nil
        pipe = nil
    }

    func getTopNetworkApps(limit: Int) -> [AppNetworkUsage] {
        let lines = buffer.components(separatedBy: .newlines)
        buffer = "" // Clear buffer after processing

        var apps: [String: AppNetworkUsage] = [:]

        for line in lines {
            let components = line.components(separatedBy: ",")
            if components.count > 5 {
                let processNameWithPid = components[1]
                let bytesIn = Double(components[4]) ?? 0
                let bytesOut = Double(components[5]) ?? 0

                let processName = getProcessName(from: processNameWithPid)
                let pid = getPid(from: processNameWithPid)

                if var app = apps[processName] {
                    app.upload += bytesOut
                    app.download += bytesIn
                    apps[processName] = app
                } else {
                    let bundleId = getBundleIdentifier(for: pid)
                    let icon = NSImage.appIcon(for: pid) ?? NSImage.appIcon(for: bundleId ?? "")
                    apps[processName] = AppNetworkUsage(
                        processID: pid,
                        processName: processName,
                        bundleIdentifier: bundleId,
                        upload: bytesOut,
                        download: bytesIn,
                        icon: icon
                    )
                }
            }
        }

        return Array(apps.values.sorted { $0.totalUsage > $1.totalUsage }.prefix(limit))
    }

    private func getProcessName(from processNameWithPid: String) -> String {
        if let dotIndex = processNameWithPid.lastIndex(of: ".") {
            return String(processNameWithPid[..<dotIndex])
        }
        return processNameWithPid
    }

    private func getPid(from processNameWithPid: String) -> Int32 {
        if let dotIndex = processNameWithPid.lastIndex(of: ".") {
            let pidString = processNameWithPid[processNameWithPid.index(after: dotIndex)...]
            return Int32(pidString) ?? 0
        }
        return 0
    }

    private func getBundleIdentifier(for pid: Int32) -> String? {
        if pid == 0 { return nil }
        let runningApp = NSWorkspace.shared.runningApplications.first { $0.processIdentifier == pid }
        return runningApp?.bundleIdentifier
    }
}

// MARK: - Ping Service

class PingService {
    private var task: Process?
    private var pipe: Pipe?
    private var lastPingTime: Double?

    func start(host: String) {
        guard task == nil else { return }

        task = Process()
        task?.launchPath = "/sbin/ping"
        task?.arguments = ["-i", "1", host]

        pipe = Pipe()
        task?.standardOutput = pipe

        pipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8) {
                self?.lastPingTime = self?.parsePingTime(from: output)
            }
        }

        do {
            try task?.run()
        } catch {
            print("Error starting ping: \(error)")
        }
    }

    func stop() {
        task?.terminate()
        task = nil
        pipe?.fileHandleForReading.readabilityHandler = nil
        pipe = nil
    }

    func getCurrentPingTime() -> Double? {
        return lastPingTime
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

