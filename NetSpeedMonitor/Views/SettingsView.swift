import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: NetworkMonitorViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        TabView {
            GeneralSettingsView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "gear")
                    Text("General")
                }
            
            DisplaySettingsView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "display")
                    Text("Display")
                }
            
            NotificationSettingsView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "bell")
                    Text("Notifications")
                }
            
            AdvancedSettingsView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "slider.horizontal.3")
                    Text("Advanced")
                }
        }
        .frame(width: 500, height: 400)
        .navigationTitle("Net Speed Monitor Settings")
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var viewModel: NetworkMonitorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General Settings")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Refresh Rate:")
                        .frame(width: 120, alignment: .leading)
                    Picker("Refresh Rate", selection: Binding(
                        get: { viewModel.settings.refreshRate },
                        set: { viewModel.updateRefreshRate($0) }
                    )) {
                        ForEach(AppSettings.RefreshRate.allCases, id: \.self) { rate in
                            Text(rate.displayName).tag(rate)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                    Spacer()
                }
                
                HStack {
                    Text("Speed Unit:")
                        .frame(width: 120, alignment: .leading)
                    Picker("Speed Unit", selection: Binding(
                        get: { viewModel.settings.speedUnit },
                        set: { viewModel.updateSpeedUnit($0) }
                    )) {
                        ForEach(AppSettings.SpeedUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                    Spacer()
                }
                
                HStack {
                    Text("Top Apps Count:")
                        .frame(width: 120, alignment: .leading)
                    Stepper(
                        value: Binding(
                            get: { viewModel.settings.topAppsCount },
                            set: { viewModel.updateTopAppsCount($0) }
                        ),
                        in: 1...50,
                        step: 1
                    ) {
                        Text("\(viewModel.settings.topAppsCount)")
                            .frame(width: 30, alignment: .trailing)
                    }
                    Spacer()
                }
                
                HStack {
                    Toggle(
                        "Start at Login",
                        isOn: Binding(
                            get: { viewModel.settings.startAtLogin },
                            set: { viewModel.updateStartAtLogin($0) }
                        )
                    )
                    Spacer()
                }
            }
            
            Spacer()
            
            HStack {
                Button("Reset to Defaults") {
                    viewModel.resetSettings()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Export Settings") {
                    exportSettings()
                }
                .buttonStyle(.bordered)
                
                Button("Import Settings") {
                    importSettings()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
    
    private func exportSettings() {
        guard let settings = viewModel.exportSettings() else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "NetSpeedMonitor-Settings.json"
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                do {
                    try settings.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Failed to export settings: \(error)")
                }
            }
        }
    }
    
    private func importSettings() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        
        openPanel.begin { result in
            if result == .OK, let url = openPanel.url {
                do {
                    let data = try String(contentsOf: url, encoding: .utf8)
                    if !viewModel.importSettings(from: data) {
                        print("Failed to import settings: Invalid format")
                    }
                } catch {
                    print("Failed to import settings: \(error)")
                }
            }
        }
    }
}

struct DisplaySettingsView: View {
    @ObservedObject var viewModel: NetworkMonitorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Display Settings")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Toggle(
                        "Dark Mode",
                        isOn: Binding(
                            get: { viewModel.settings.isDarkMode },
                            set: { viewModel.updateDarkMode($0) }
                        )
                    )
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Menu Bar Preview:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Text("Current: ")
                        Text(viewModel.menuBarText)
                            .font(.system(size: 11, design: .monospaced))
                            .padding(4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                        Spacer()
                    }
                    
                    Text("The menu bar shows upload (↑) and download (↓) speeds in a compact format.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Network Information:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let interface = viewModel.networkStats.activeInterface {
                        InfoItemView(label: "Interface", value: interface.name)
                        InfoItemView(label: "Type", value: interface.type.rawValue)
                        InfoItemView(label: "Status", value: interface.isActive ? "Connected" : "Disconnected")
                        
                        if let ip = interface.ipAddress {
                            InfoItemView(label: "Local IP", value: ip)
                        }
                    } else {
                        Text("No active connection")
                            .foregroundColor(.secondary)
                    }
                    
                    if let publicIP = viewModel.networkStats.publicIP {
                        InfoItemView(label: "Public IP", value: publicIP)
                    }
                    
                    if let ping = viewModel.networkStats.ping {
                        InfoItemView(label: "Ping", value: String(format: "%.0f ms", ping))
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct InfoItemView: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text("\(label):")
                .frame(width: 80, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
                .textSelection(.enabled)
            Spacer()
        }
    }
}

struct NotificationSettingsView: View {
    @ObservedObject var viewModel: NetworkMonitorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Notification Settings")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Toggle(
                        "Enable Notifications",
                        isOn: Binding(
                            get: { viewModel.settings.showNotifications },
                            set: { viewModel.updateNotifications($0) }
                        )
                    )
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Speed Alert Threshold:")
                            .frame(width: 140, alignment: .leading)
                        TextField(
                            "Threshold",
                            value: Binding(
                                get: { viewModel.settings.notificationThreshold },
                                set: { viewModel.updateNotificationThreshold($0) }
                            ),
                            format: .number.precision(.fractionLength(1))
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        Text("MB/s")
                        Spacer()
                    }
                    
                    Text("Get notified when network speed drops below this threshold.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Notification Cooldown:")
                            .frame(width: 140, alignment: .leading)
                        Stepper(
                            value: Binding(
                                get: { viewModel.settings.notificationDuration },
                                set: { viewModel.updateNotificationDuration($0) }
                            ),
                            in: 1...30,
                            step: 1
                        ) {
                            Text("\(viewModel.settings.notificationDuration) seconds")
                                .frame(width: 100, alignment: .trailing)
                        }
                        Spacer()
                    }
                    
                    Text("Minimum time between similar notifications to prevent spam.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("You will be notified when:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Network speed drops below the threshold")
                        Text("• Network interface changes (Wi-Fi ↔ Ethernet)")
                        Text("• Connection is lost or restored")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct AdvancedSettingsView: View {
    @ObservedObject var viewModel: NetworkMonitorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Advanced Settings")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Performance Statistics:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                let avgSpeed = viewModel.getAverageSpeed()
                let peakSpeed = viewModel.getPeakSpeed()
                let totalData = viewModel.getTotalDataTransferred()
                
                InfoItemView(label: "Avg Upload", value: viewModel.formatSpeed(avgSpeed.upload))
                InfoItemView(label: "Avg Download", value: viewModel.formatSpeed(avgSpeed.download))
                InfoItemView(label: "Peak Upload", value: viewModel.formatSpeed(peakSpeed.upload))
                InfoItemView(label: "Peak Download", value: viewModel.formatSpeed(peakSpeed.download))
                InfoItemView(label: "Total Upload", value: viewModel.formatSpeed(totalData.upload))
                InfoItemView(label: "Total Download", value: viewModel.formatSpeed(totalData.download))
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("System Status:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text("Monitoring Status:")
                        .frame(width: 120, alignment: .leading)
                    Text(viewModel.isMonitoring ? "Active" : "Stopped")
                        .foregroundColor(viewModel.isMonitoring ? .green : .red)
                        .fontWeight(.medium)
                    Spacer()
                }
                
                HStack {
                    Text("Update Frequency:")
                        .frame(width: 120, alignment: .leading)
                    Text(viewModel.settings.refreshRate.displayName)
                        .fontWeight(.medium)
                    Spacer()
                }
                
                HStack {
                    Text("Apps Monitored:")
                        .frame(width: 120, alignment: .leading)
                    Text("\(viewModel.networkStats.topApps.count)")
                        .fontWeight(.medium)
                    Spacer()
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("About Net Speed Monitor")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Version 1.0.0")
                    .font(.caption)
                
                Text("A lightweight macOS app for monitoring network speed and app usage in real-time.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Button("GitHub") {
                        NSWorkspace.shared.open(URL(string: "https://github.com/frolax/net-speed-monitor")!)
                    }
                    .buttonStyle(.link)
                    
                    Button("Report Bug") {
                        NSWorkspace.shared.open(URL(string: "https://github.com/frolax/net-speed-monitor/issues")!)
                    }
                    .buttonStyle(.link)
                    
                    Spacer()
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    SettingsView(viewModel: NetworkMonitorViewModel())
}