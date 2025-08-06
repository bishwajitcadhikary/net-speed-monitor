import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: NetworkMonitorViewModel
    
    var body: some View {
        HStack(spacing: 0) {
            Text(viewModel.menuBarText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.primary)
        }
        .onTapGesture {
            viewModel.togglePopover()
        }
    }
}

struct MenuBarContentView: View {
    @ObservedObject var viewModel: NetworkMonitorViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with current speeds
            HeaderView(viewModel: viewModel)
            
            Divider()
            
            // Network info
            NetworkInfoView(viewModel: viewModel)
            
            Divider()
            
            // Top apps list
            TopAppsView(viewModel: viewModel)
                .frame(height: 300)
            
            Divider()
            
            // Footer with controls
            FooterView(viewModel: viewModel)
        }
        .frame(width: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct HeaderView: View {
    @ObservedObject var viewModel: NetworkMonitorViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "arrow.up")
                            .foregroundColor(.orange)
                        Text("Upload")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(viewModel.formatSpeed(viewModel.networkStats.currentSpeed.upload))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    HStack {
                        Text("Download")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "arrow.down")
                            .foregroundColor(.blue)
                    }
                    Text(viewModel.formatSpeed(viewModel.networkStats.currentSpeed.download))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            }
            
            // Speed chart preview
            SpeedChartView(speedHistory: viewModel.getSpeedHistory())
                .frame(height: 50)
        }
        .padding()
    }
}

struct NetworkInfoView: View {
    @ObservedObject var viewModel: NetworkMonitorViewModel
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                InfoRow(
                    label: "Interface:",
                    value: viewModel.formatInterface(viewModel.networkStats.activeInterface)
                )
                
                Spacer()
                
                InfoRow(
                    label: "IP:",
                    value: viewModel.formatIPAddress(viewModel.networkStats.activeInterface?.ipAddress)
                )
            }
            
            HStack {
                InfoRow(
                    label: "Public IP:",
                    value: viewModel.formatIPAddress(viewModel.networkStats.publicIP)
                )
                
                Spacer()
                
                InfoRow(
                    label: "Ping:",
                    value: viewModel.formatPing(viewModel.networkStats.ping)
                )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()
        }
    }
}

struct TopAppsView: View {
    @ObservedObject var viewModel: NetworkMonitorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Top Apps by Network Usage")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                Spacer()
                
                Button("Refresh") {
                    // Trigger manual refresh if needed
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .padding(.horizontal)
                .padding(.top, 8)
            }
            
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(Array(viewModel.getTopApps().enumerated()), id: \.element.processID) { index, app in
                        AppUsageRow(app: app, rank: index + 1, viewModel: viewModel)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct AppUsageRow: View {
    let app: AppNetworkUsage
    let rank: Int
    @ObservedObject var viewModel: NetworkMonitorViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            // Rank
            Text("\(rank)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .trailing)
            
            // App icon
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "app")
                    .frame(width: 20, height: 20)
                    .foregroundColor(.secondary)
            }
            
            // App name
            VStack(alignment: .leading, spacing: 2) {
                Text(app.processName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                
                if let bundleId = app.bundleIdentifier, bundleId != app.processName {
                    Text(bundleId)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Network usage
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                    Text(viewModel.formatSpeed(app.upload))
                        .font(.system(size: 10, design: .monospaced))
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 8))
                        .foregroundColor(.blue)
                    Text(viewModel.formatSpeed(app.download))
                        .font(.system(size: 10, design: .monospaced))
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(rank % 2 == 0 ? Color.clear : Color(NSColor.controlBackgroundColor))
        )
    }
}

struct SpeedChartView: View {
    let speedHistory: [NetworkSpeed]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(NSColor.controlBackgroundColor))
                
                if !speedHistory.isEmpty {
                    // Upload line
                    SpeedLine(
                        speeds: speedHistory.map { $0.upload },
                        color: .orange,
                        size: geometry.size
                    )
                    
                    // Download line
                    SpeedLine(
                        speeds: speedHistory.map { $0.download },
                        color: .blue,
                        size: geometry.size
                    )
                } else {
                    Text("No data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct SpeedLine: View {
    let speeds: [Double]
    let color: Color
    let size: CGSize
    
    var body: some View {
        Path { path in
            guard !speeds.isEmpty, size.width > 0, size.height > 0 else { return }
            
            // Filter out invalid values (NaN, infinite) and ensure we have valid data
            let validSpeeds = speeds.compactMap { speed -> Double? in
                guard speed.isFinite && speed >= 0 else { return nil }
                return speed
            }
            
            guard !validSpeeds.isEmpty else { return }
            
            // Ensure maxSpeed is valid and not zero
            let maxSpeed = validSpeeds.max() ?? 0
            guard maxSpeed > 0 else { return }
            
            let stepX = size.width / CGFloat(max(validSpeeds.count - 1, 1))
            
            for (index, speed) in validSpeeds.enumerated() {
                let x = CGFloat(index) * stepX
                let normalizedY = CGFloat(speed / maxSpeed)
                let y = size.height - (normalizedY * size.height)
                
                // Ensure coordinates are valid
                guard x.isFinite && y.isFinite else { continue }
                
                let point = CGPoint(x: x, y: y)
                
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
        .stroke(color, lineWidth: 1.5)
    }
}

struct FooterView: View {
    @ObservedObject var viewModel: NetworkMonitorViewModel
    
    var body: some View {
        HStack {
            Button(action: viewModel.showSettings) {
                Image(systemName: "gear")
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderless)
            .help("Settings")
            
            Spacer()
            
            Text("Updated: \(viewModel.getCurrentDateTime())")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Quit") {
                viewModel.quitApplication()
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

#Preview {
    MenuBarContentView(viewModel: NetworkMonitorViewModel())
}