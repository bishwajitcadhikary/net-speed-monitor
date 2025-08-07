import SwiftUI
import Combine
import AppKit

// MARK: - Notification Names
extension Notification.Name {
    static let openSettingsWindow = Notification.Name("openSettingsWindow")
}

@MainActor
class NetworkMonitorViewModel: ObservableObject {
    @Published var networkStats = NetworkStats.empty
    @Published var isMonitoring = false
    @Published var showingPopover = false
    @Published var showingSettings = false
    
    private let networkService = NetworkMonitorService()
    private let settingsService = SettingsService()
    private let notificationService: NotificationService
    
    var cancellables = Set<AnyCancellable>()
    private var speedHistory: [NetworkSpeed] = []
    private let maxHistoryCount = 60 // Keep 1 minute of history at 1s intervals
    
    var settings: AppSettings {
        settingsService.settings
    }
    
    init() {
        self.notificationService = NotificationService(settings: settingsService)
        setupBindings()
    }
    
    private func setupBindings() {
        // Monitor network stats changes
        networkService.$currentStats
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stats in
                self?.networkStats = stats
                self?.updateSpeedHistory(with: stats.currentSpeed)
                self?.notificationService.checkForSpeedAlert(currentSpeed: stats.currentSpeed)
            }
            .store(in: &cancellables)

        // Monitor settings changes and trigger UI updates
        settingsService.$settings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                guard let self = self else { return }
                self.networkService.updateRefreshRate(settings.refreshRate.rawValue)
                // Manually notify SwiftUI that the viewModel has changed to force view updates
                self.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        networkService.startMonitoring(refreshRate: settings.refreshRate.rawValue)
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        networkService.stopMonitoring()
    }
    
    private func updateSpeedHistory(with speed: NetworkSpeed) {
        speedHistory.append(speed)
        
        // Keep only recent history
        if speedHistory.count > maxHistoryCount {
            speedHistory.removeFirst(speedHistory.count - maxHistoryCount)
        }
    }
    
    func getSpeedHistory() -> [NetworkSpeed] {
        return speedHistory
    }
    
    func getTopApps() -> [AppNetworkUsage] {
        let apps = Array(networkStats.topApps.prefix(settings.topAppsCount))
        // Ensure we return a stable array to prevent unnecessary view updates
        return apps
    }
    
    // MARK: - Settings Actions
    
    func updateRefreshRate(_ rate: AppSettings.RefreshRate) {
        settingsService.updateRefreshRate(rate)
    }
    
    func updateSpeedUnit(_ unit: AppSettings.SpeedUnit) {
        settingsService.updateSpeedUnit(unit)
    }
    
    func updateTopAppsCount(_ count: Int) {
        settingsService.updateTopAppsCount(count)
    }
    
    func updateStartAtLogin(_ enabled: Bool) {
        settingsService.updateStartAtLogin(enabled)
    }
    
    func updateNotifications(_ enabled: Bool) {
        settingsService.updateNotifications(enabled)
    }
    
    func updateNotificationThreshold(_ threshold: Double) {
        settingsService.updateNotificationThreshold(threshold)
    }
    
    func updateNotificationDuration(_ duration: Int) {
        settingsService.updateNotificationDuration(duration)
    }
    
    func updateDarkMode(_ enabled: Bool) {
        settingsService.updateDarkMode(enabled)
    }
    
    func resetSettings() {
        settingsService.resetToDefaults()
    }
    
    func exportSettings() -> String? {
        return settingsService.exportSettings()
    }
    
    func importSettings(from jsonString: String) -> Bool {
        return settingsService.importSettings(from: jsonString)
    }
    
    // MARK: - UI Actions
    
    func togglePopover() {
        showingPopover.toggle()
    }
    
    func showSettings() {
        print("🔧 showSettings() called")
        showingSettings = true
        
        // Post a notification to open settings - this is more reliable than casting delegates
        NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
    }
    
    func hideSettings() {
        showingSettings = false
    }
    
    func quitApplication() {
        stopMonitoring()
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Utility Methods
    
    func getCurrentDateTime() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
    
    func getTotalDataTransferred() -> (upload: Double, download: Double) {
        let totalUpload = speedHistory.reduce(0) { $0 + $1.upload }
        let totalDownload = speedHistory.reduce(0) { $0 + $1.download }
        return (totalUpload, totalDownload)
    }
    
    func getAverageSpeed() -> NetworkSpeed {
        guard !speedHistory.isEmpty else { return NetworkSpeed() }
        
        let totalUpload = speedHistory.reduce(0) { $0 + $1.upload }
        let totalDownload = speedHistory.reduce(0) { $0 + $1.download }
        
        return NetworkSpeed(
            upload: totalUpload / Double(speedHistory.count),
            download: totalDownload / Double(speedHistory.count)
        )
    }
    
    func getPeakSpeed() -> NetworkSpeed {
        guard !speedHistory.isEmpty else { return NetworkSpeed() }
        
        let maxUpload = speedHistory.max { $0.upload < $1.upload }?.upload ?? 0
        let maxDownload = speedHistory.max { $0.download < $1.download }?.download ?? 0
        
        return NetworkSpeed(upload: maxUpload, download: maxDownload)
    }
}

// MARK: - Extensions for UI Formatting

extension NetworkMonitorViewModel {
    func formatSpeed(_ speed: Double) -> String {
        return speed.formatBytes(unit: settings.speedUnit)
    }
    
    func formatPing(_ ping: Double?) -> String {
        guard let ping = ping else { return "N/A" }
        return String(format: "%.0f ms", ping)
    }
    
    func formatIPAddress(_ ip: String?) -> String {
        return ip ?? "N/A"
    }
    
    func formatInterface(_ interface: NetworkInterface?) -> String {
        guard let interface = interface else { return "Unknown" }
        return "\(interface.name) (\(interface.type.rawValue))"
    }
}
