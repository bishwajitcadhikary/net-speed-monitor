import Foundation

// MARK: - Network Speed Data Models

struct NetworkSpeed {
    let upload: Double      // bytes per second
    let download: Double    // bytes per second
    let timestamp: Date
    
    init(upload: Double = 0, download: Double = 0) {
        // Ensure values are finite and non-negative
        self.upload = upload.isFinite && upload >= 0 ? upload : 0
        self.download = download.isFinite && download >= 0 ? download : 0
        self.timestamp = Date()
    }
}

struct AppNetworkUsage {
    let processID: Int32
    let processName: String
    let bundleIdentifier: String?
    let upload: Double      // bytes per second
    let download: Double    // bytes per second
    let icon: NSImage?
    
    var totalUsage: Double {
        let total = upload + download
        return total.isFinite ? total : 0
    }
    
    init(processID: Int32, processName: String, bundleIdentifier: String?, upload: Double, download: Double, icon: NSImage?) {
        self.processID = processID
        self.processName = processName
        self.bundleIdentifier = bundleIdentifier
        // Ensure values are finite and non-negative
        self.upload = upload.isFinite && upload >= 0 ? upload : 0
        self.download = download.isFinite && download >= 0 ? download : 0
        self.icon = icon
    }
}

struct NetworkInterface {
    let name: String
    let type: InterfaceType
    let isActive: Bool
    let ipAddress: String?
    
    enum InterfaceType: String, CaseIterable {
        case wifi = "Wi-Fi"
        case ethernet = "Ethernet"
        case cellular = "Cellular"
        case other = "Other"
    }
}

struct NetworkStats {
    let currentSpeed: NetworkSpeed
    let topApps: [AppNetworkUsage]
    let activeInterface: NetworkInterface?
    let publicIP: String?
    let ping: Double?  // milliseconds
    
    static let empty = NetworkStats(
        currentSpeed: NetworkSpeed(),
        topApps: [],
        activeInterface: nil,
        publicIP: nil,
        ping: nil
    )
}

// MARK: - Settings Data Models

struct AppSettings: Codable {
    var refreshRate: RefreshRate = .oneSecond
    var speedUnit: SpeedUnit = .mbps
    var topAppsCount: Int = 10
    var startAtLogin: Bool = false
    var showNotifications: Bool = true
    var notificationThreshold: Double = 1.0 // MB/s
    var notificationDuration: Int = 5 // seconds
    var isDarkMode: Bool = false
    
    enum RefreshRate: Double, CaseIterable, Codable {
        case oneSecond = 1.0
        case fiveSeconds = 5.0
        case tenSeconds = 10.0
        
        var displayName: String {
            switch self {
            case .oneSecond: return "1 second"
            case .fiveSeconds: return "5 seconds"
            case .tenSeconds: return "10 seconds"
            }
        }
    }
    
    enum SpeedUnit: String, CaseIterable, Codable {
        case kbps = "KB/s"
        case mbps = "MB/s"
        case auto = "Auto"
        
        var displayName: String { rawValue }
    }
}

// MARK: - Helper Extensions

extension Double {
    func formatBytes(unit: AppSettings.SpeedUnit = .auto) -> String {
        let value = self
        
        switch unit {
        case .kbps:
            return String(format: "%.1f KB/s", value / 1024)
        case .mbps:
            return String(format: "%.1f MB/s", value / (1024 * 1024))
        case .auto:
            if value >= 1024 * 1024 * 1024 {
                return String(format: "%.1f GB/s", value / (1024 * 1024 * 1024))
            } else if value >= 1024 * 1024 {
                return String(format: "%.1f MB/s", value / (1024 * 1024))
            } else if value >= 1024 {
                return String(format: "%.1f KB/s", value / 1024)
            } else {
                return String(format: "%.0f B/s", value)
            }
        }
    }
}

import AppKit

extension NSImage {
    static func appIcon(for bundleIdentifier: String) -> NSImage? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }
    
    static func appIcon(for processID: Int32) -> NSImage? {
        let runningApp = NSWorkspace.shared.runningApplications.first { $0.processIdentifier == processID }
        return runningApp?.icon
    }
}