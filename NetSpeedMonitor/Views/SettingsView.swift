import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: NetworkMonitorViewModel
    @State private var selectedTab = 0
    
    private let tabs = [
        (id: 0, icon: "gear", title: "General"),
        (id: 1, icon: "display", title: "Display"),
        (id: 2, icon: "bell", title: "Notifications"),
        (id: 3, icon: "slider.horizontal.3", title: "Advanced"),
        (id: 4, icon: "info.circle", title: "About")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom tab bar
            HStack(spacing: 0) {
                ForEach(tabs, id: \.id) { tab in
                    Button(action: {
                        selectedTab = tab.id
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 24, weight: .regular))
                                .foregroundColor(selectedTab == tab.id ? .accentColor : .secondary)
                            
                            Text(tab.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(selectedTab == tab.id ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(NSColor.separatorColor)),
                alignment: .bottom
            )
            
            // Content area
            ScrollView {
                Group {
                    switch selectedTab {
                    case 0:
                        GeneralSettingsView(viewModel: viewModel)
                    case 1:
                        DisplaySettingsView(viewModel: viewModel)
                    case 2:
                        NotificationSettingsView(viewModel: viewModel)
                    case 3:
                        AdvancedSettingsView(viewModel: viewModel)
                    case 4:
                        AboutSettingsView(viewModel: viewModel)
                    default:
                        GeneralSettingsView(viewModel: viewModel)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(width: 550, height: 450)
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
        savePanel.nameFieldStringValue = "NetSpeedMonitor.json"
        
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
                        Text("Custom Status Bar")
                            .font(.system(size: 11, design: .monospaced))
                            .padding(4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                        Spacer()
                    }
                    
                    Text("The menu bar shows network speeds with icons, arrows, and toggle switches in a modern layout.")
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

struct AboutView: View {
    @ObservedObject var viewModel: NetworkMonitorViewModel
    
    var body: some View{
        VStack(alignment: .leading){
            Text("About US")
                .font(.headline)
        }
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

struct AboutSettingsView: View {
    @ObservedObject var viewModel: NetworkMonitorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("About Net Speed Monitor")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 16) {
                // App Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Application Information")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    InfoItemView(label: "Version", value: "1.0.0")
                    InfoItemView(label: "Build", value: "1")
                    InfoItemView(label: "Bundle ID", value: "com.frolax.netspeedmonitor")
                }
                
                Divider()
                
                // Company Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Developer Information")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    InfoItemView(label: "Company", value: "Frolax")
                    InfoItemView(label: "Developer", value: "Bishwajit Adhikary")
                    InfoItemView(label: "Contact", value: "support@frolax.com")
                }
                
                Divider()
                
                // System Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("System Information")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    InfoItemView(label: "macOS Version", value: ProcessInfo.processInfo.operatingSystemVersionString)
                    InfoItemView(label: "Architecture", value: getSystemArchitecture())
                }
                
                Divider()
                
                // Links
                VStack(alignment: .leading, spacing: 8) {
                    Text("Resources")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Button("Website") {
                            NSWorkspace.shared.open(URL(string: "https://frolax.agency")!)
                        }
                        .buttonStyle(.link)
                        
                        Button("GitHub") {
                            NSWorkspace.shared.open(URL(string: "https://github.com/bishwajitcadhikary/net-speed-monitor")!)
                        }
                        .buttonStyle(.link)
                        
                        Button("Support") {
                            NSWorkspace.shared.open(URL(string: "mailto:bishwajitcadhikary@gmail.com")!)
                        }
                        .buttonStyle(.link)
                        
                        Spacer()
                    }
                }
                
                Divider()
                
                // Copyright
                VStack(alignment: .leading, spacing: 4) {
                    Text("Copyright © 2025 Frolax. All rights reserved.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Net Speed Monitor is a lightweight macOS application for monitoring network speed and bandwidth usage in real-time.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func getSystemArchitecture() -> String {
        #if arch(arm64)
        return "Apple Silicon (ARM64)"
        #elseif arch(x86_64)
        return "Intel (x86_64)"
        #else
        return "Unknown"
        #endif
    }
}

#Preview {
    SettingsView(viewModel: NetworkMonitorViewModel())
}
