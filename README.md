# Net Speed Monitor

A lightweight, native macOS application that provides real-time network speed monitoring in your menu bar with detailed per-app bandwidth usage statistics.

![Menu Bar Display](https://via.placeholder.com/200x50/000000/FFFFFF?text=↑1.2M+↓5.4M)

## Features

### 🔹 Menu Bar Display
- **Real-time Upload/Download speeds** in menu bar
- **Auto-scaling units**: Automatically switches between B/s, KB/s, MB/s, GB/s
- **Compact display**: Minimal UI that doesn't clutter your menu bar
- **Live updates**: Configurable refresh rates (1s, 5s, 10s)

### 🔹 Detailed Popup Interface
- **Real-time bandwidth graph** with upload/download visualization
- **Top N apps** using most bandwidth (configurable: 5, 10, 20, etc.)
- **Per-app statistics**: Shows app name, PID, icon, upload & download speeds
- **Network information**: Active interface, IP addresses, ping to 8.8.8.8
- **Sortable by usage**: Apps automatically sorted by total bandwidth usage

### 🔹 Comprehensive Settings
- **Unit preferences**: Choose between KB/s, MB/s, Mbps, or Auto
- **Refresh rate control**: 1-second to 10-second intervals
- **Launch at login**: Seamless startup integration
- **Top apps count**: Configure how many apps to display
- **Dark/light mode** toggle
- **Export/Import settings** for easy backup and sharing

### 🔹 Smart Notifications
- **Speed drop alerts**: Get notified when speeds fall below threshold
- **Interface change alerts**: Know when switching between Wi-Fi/Ethernet
- **Configurable thresholds**: Set custom MB/s limits
- **Notification cooldown**: Prevent spam with intelligent timing

### 🔹 Privacy & Performance
- **No root access required**: Uses only non-privileged system APIs
- **Sandbox compliant**: Secure implementation with proper entitlements
- **Low resource usage**: Optimized async operations, minimal CPU/memory impact
- **Native Swift**: Built with Swift 5.10+ and SwiftUI for macOS 15.0+

## System Requirements

- **macOS Sequoia 15.0** or later (includes macOS Tahoe 16.0+ support)
- **Universal Binary**: Native support for both Intel and Apple Silicon Macs
- **Architecture**: ARM64 and x86_64 supported

## Installation

### Option 1: Direct Download
1. Download the latest `NetSpeedMonitor-1.0.0.dmg` from releases
2. Open the DMG file
3. Drag `NetSpeedMonitor.app` to your Applications folder
4. Launch from Applications or Spotlight

### Option 2: Build from Source
```bash
# Clone the repository
git clone https://github.com/frolax/net-speed-monitor.git
cd net-speed-monitor

# Install xcodegen (if not already installed)
brew install xcodegen

# Generate Xcode project
xcodegen

# Build the project
xcodebuild -project NetSpeedMonitor.xcodeproj -scheme NetSpeedMonitor -configuration Release build

# Create distribution package
./create_dmg.sh
```

## Usage

### First Launch
1. **Grant permissions**: macOS may prompt for network monitoring permissions
2. **Menu bar icon**: Look for the network speed indicator in your menu bar
3. **Click to explore**: Click the menu bar item to see detailed statistics

### Basic Operation
- **Menu bar display**: Shows current upload (↑) and download (↓) speeds
- **Click for details**: Access full interface with app breakdown and settings
- **Right-click menu**: Quick access to settings and quit options

### Keyboard Shortcuts
- **⌘,** - Open Settings (when popup is active)
- **⌘Q** - Quit application (when popup is active)

## Technical Implementation

### Core Technologies
- **Swift 5.10+**: Modern Swift with latest language features
- **SwiftUI**: Native macOS 15.0+ user interface framework
- **Network.framework**: Apple's modern networking APIs
- **Combine**: Reactive programming for real-time updates
- **Swift Concurrency**: Async/await for performance optimization

### Network Monitoring
- **Network.framework**: Interface monitoring and status detection
- **nettop integration**: Per-app bandwidth parsing via JSON output
- **ICMP ping**: Network latency measurement to 8.8.8.8
- **Interface detection**: Automatic Wi-Fi/Ethernet/Cellular recognition

### Data Collection Methods
```swift
// Network interface monitoring
NWPathMonitor() // Real-time interface status
getifaddrs()    // Low-level interface statistics

// Per-app bandwidth tracking  
nettop -P -x -J // JSON output parsing
NSWorkspace    // App icon and bundle ID resolution

// System integration
ServiceManagement // Launch at login functionality
UserNotifications // Speed and interface change alerts
```

### Privacy & Security
- **Sandbox enabled**: App runs in macOS application sandbox
- **Minimal permissions**: Only network monitoring entitlements
- **No admin access**: Uses only user-level system APIs
- **Local processing**: All data processing happens locally

## Project Structure

```
NetSpeedMonitor/
├── Models/
│   └── NetworkData.swift          # Data models and structures
├── Views/
│   ├── MenuBarView.swift          # Menu bar interface and popup
│   └── SettingsView.swift         # Settings panel with tabs
├── ViewModels/
│   └── NetworkMonitorViewModel.swift # Main coordinator and state
├── Services/
│   ├── NetworkMonitorService.swift   # Network monitoring logic
│   └── SettingsService.swift         # Settings and preferences
├── Utilities/
├── Resources/
├── NetSpeedMonitorApp.swift       # Main app and AppDelegate
├── Info.plist                     # App configuration
└── NetSpeedMonitor.entitlements   # Sandbox permissions
```

## Build Configuration

### Xcode Project Generation
The project uses `xcodegen` for maintaining the Xcode project:

```yaml
# project.yml
name: NetSpeedMonitor
deploymentTarget:
  macOS: "15.0"
settings:
  SWIFT_VERSION: "5.10"
  MACOSX_DEPLOYMENT_TARGET: "15.0"
```

### Code Signing
- **Automatic signing**: Uses Xcode's automatic code signing
- **Hardened runtime**: Enabled for enhanced security
- **Entitlements**: Minimal required permissions for network monitoring

## Development

### Prerequisites
- Xcode 16.0+ (for macOS 15.0+ SDK)
- Swift 5.10+
- macOS 15.0+ for testing

### Building
```bash
# Install dependencies
brew install xcodegen

# Generate project
xcodegen

# Build debug version
xcodebuild -project NetSpeedMonitor.xcodeproj -scheme NetSpeedMonitor -configuration Debug build

# Build release version  
xcodebuild -project NetSpeedMonitor.xcodeproj -scheme NetSpeedMonitor -configuration Release build
```

### Testing
- **Unit tests**: Core networking and data processing logic
- **UI tests**: SwiftUI interface interactions
- **Performance tests**: Memory and CPU usage validation
- **Integration tests**: System API interaction verification

## Distribution

### DMG Creation
```bash
# Create distribution package
./create_dmg.sh

# Output: NetSpeedMonitor-1.0.0.dmg
```

### Release Signing
For distribution outside the Mac App Store:
1. **Developer ID Application** certificate required
2. **Notarization** through Apple for Gatekeeper compatibility
3. **Hardened runtime** with necessary entitlements

## Roadmap

### Planned Features
- [ ] **Historical data**: Daily/weekly/monthly usage statistics
- [ ] **Export data**: CSV export of usage statistics  
- [ ] **Advanced filtering**: Hide system processes, filter by app type
- [ ] **Connection inspector**: Remote IP:port details per app
- [ ] **Multiple interfaces**: Separate tracking for different networks
- [ ] **Bandwidth limits**: Per-app usage warnings and limits
- [ ] **Menu bar customization**: Configurable display format

### Advanced Features
- [ ] **Network quality**: Latency, jitter, packet loss monitoring
- [ ] **VPN detection**: Identify and track VPN usage
- [ ] **Hotspot monitoring**: Track mobile hotspot data usage
- [ ] **Smart notifications**: ML-based anomaly detection
- [ ] **Widget support**: macOS dashboard widget integration

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup
1. Fork the repository
2. Create a feature branch
3. Make your changes with proper tests
4. Submit a pull request

### Code Style
- **Swift style guide**: Follow Apple's Swift style conventions
- **SwiftUI patterns**: Use modern SwiftUI declarative patterns
- **Documentation**: Comprehensive inline documentation required
- **Testing**: Unit tests for all business logic

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/frolax/net-speed-monitor/issues)
- **Discussions**: [GitHub Discussions](https://github.com/frolax/net-speed-monitor/discussions)
- **Email**: support@frolax.com

## Acknowledgments

- **Apple**: For excellent networking frameworks and development tools
- **macOS Community**: For inspiration and feedback on menu bar applications
- **Open Source**: Built with open source tools and libraries

---

**Net Speed Monitor** - Real-time network monitoring for macOS  
© 2024 Frolax. All rights reserved.