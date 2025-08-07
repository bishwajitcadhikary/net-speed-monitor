import Foundation
import ServiceManagement
import Combine

@MainActor
class SettingsService: ObservableObject {
    @Published var settings = AppSettings()
    
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "NetSpeedMonitorSettings"
    
    init() {
        loadSettings()
    }
    
    func loadSettings() {
        if let data = userDefaults.data(forKey: settingsKey),
           let decodedSettings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decodedSettings
        }
    }
    
    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
        }
    }
    
    func updateRefreshRate(_ rate: AppSettings.RefreshRate) {
        settings.refreshRate = rate
        saveSettings()
    }
    
    func updateSpeedUnit(_ unit: AppSettings.SpeedUnit) {
        settings.speedUnit = unit
        saveSettings()
    }
    
    func updateTopAppsCount(_ count: Int) {
        settings.topAppsCount = max(1, min(50, count)) // Clamp between 1 and 50
        saveSettings()
    }
    
    func updateStartAtLogin(_ enabled: Bool) {
        settings.startAtLogin = enabled
        saveSettings()
        
        if enabled {
            enableStartAtLogin()
        } else {
            disableStartAtLogin()
        }
    }
    
    func updateNotifications(_ enabled: Bool) {
        settings.showNotifications = enabled
        saveSettings()
    }
    
    func updateNotificationThreshold(_ threshold: Double) {
        settings.notificationThreshold = max(0.1, threshold) // Minimum 0.1 MB/s
        saveSettings()
    }
    
    func updateNotificationDuration(_ duration: Int) {
        settings.notificationDuration = max(1, min(30, duration)) // Between 1 and 30 seconds
        saveSettings()
    }
    
    func updateSpeedAlertNotifications(_ enabled: Bool) {
        settings.speedAlertNotifications = enabled
        saveSettings()
    }
    
    func updateInterfaceChangeNotifications(_ enabled: Bool) {
        settings.interfaceChangeNotifications = enabled
        saveSettings()
    }
    
    func updateConnectionStatusNotifications(_ enabled: Bool) {
        settings.connectionStatusNotifications = enabled
        saveSettings()
    }
    
    func updateTheme(_ theme: AppSettings.Theme) {
        settings.theme = theme
        saveSettings()
    }
    
    private func enableStartAtLogin() {
        do {
            if #available(macOS 13.0, *) {
                try SMAppService.mainApp.register()
            } else {
                // Fallback for older macOS versions
                let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.frolax.netspeedmonitor"
                let helperBundleIdentifier = "\(bundleIdentifier).LaunchHelper"
                SMLoginItemSetEnabled(helperBundleIdentifier as CFString, true)
            }
        } catch {
            print("Failed to enable start at login: \(error)")
        }
    }
    
    private func disableStartAtLogin() {
        do {
            if #available(macOS 13.0, *) {
                try SMAppService.mainApp.unregister()
            } else {
                // Fallback for older macOS versions
                let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.frolax.netspeedmonitor"
                let helperBundleIdentifier = "\(bundleIdentifier).LaunchHelper"
                SMLoginItemSetEnabled(helperBundleIdentifier as CFString, false)
            }
        } catch {
            print("Failed to disable start at login: \(error)")
        }
    }
    
    func resetToDefaults() {
        settings = AppSettings()
        saveSettings()
    }
    
    func exportSettings() -> String? {
        guard let data = try? JSONEncoder().encode(settings) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func importSettings(from jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8),
              let importedSettings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return false
        }
        
        settings = importedSettings
        saveSettings()
        return true
    }
}

// MARK: - Notification Service

class NotificationService: ObservableObject {
    private let settings: SettingsService
    private var lastNotificationTime: Date?
    private let minimumNotificationInterval: TimeInterval = 60 // 1 minute
    
    init(settings: SettingsService) {
        self.settings = settings
        requestNotificationPermission()
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    @MainActor func checkForSpeedAlert(currentSpeed: NetworkSpeed) {
        guard settings.settings.showNotifications && settings.settings.speedAlertNotifications else { return }
        
        let totalSpeed = (currentSpeed.upload + currentSpeed.download) / (1024 * 1024) // Convert to MB/s
        let threshold = settings.settings.notificationThreshold
        
        if totalSpeed < threshold {
            sendLowSpeedNotification(speed: totalSpeed, threshold: threshold)
        }
    }
    
    private func sendLowSpeedNotification(speed: Double, threshold: Double) {
        // Prevent notification spam
        if let lastTime = lastNotificationTime,
           Date().timeIntervalSince(lastTime) < minimumNotificationInterval {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Low Network Speed"
        content.body = String(format: "Current speed (%.1f MB/s) is below threshold (%.1f MB/s)", speed, threshold)
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "low-speed-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if error == nil {
                self?.lastNotificationTime = Date()
            }
        }
    }
    
    @MainActor func sendInterfaceChangeNotification(newInterface: NetworkInterface) {
        guard settings.settings.showNotifications && settings.settings.interfaceChangeNotifications else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Network Interface Changed"
        content.body = "Now connected via \(newInterface.name)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "interface-change-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    @MainActor func sendConnectionStatusNotification(isConnected: Bool) {
        guard settings.settings.showNotifications && settings.settings.connectionStatusNotifications else { return }
        
        let content = UNMutableNotificationContent()
        content.title = isConnected ? "Network Connected" : "Network Disconnected"
        content.body = isConnected ? "Internet connection has been restored" : "Internet connection has been lost"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "connection-status-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

import UserNotifications