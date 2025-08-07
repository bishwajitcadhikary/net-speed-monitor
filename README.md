# Net Speed Monitor

A macOS menu bar application that monitors and displays real-time network bandwidth statistics.

## Features

- 📊 Real-time upload and download speed monitoring
- 🍎 Native macOS menu bar integration
- ⚙️ Customizable settings and preferences
- 🔄 Background monitoring with minimal resource usage
- 🎨 Clean, modern SwiftUI interface
- 📱 Support for macOS 15.0+

## Screenshots

*Screenshots will be added here*

## Installation

### From Release
1. Download the latest DMG from the [Releases](https://github.com/your-username/net-speed-monitor/releases) page
2. Open the DMG and drag Net Speed Monitor to Applications
3. Launch the app from Applications or Spotlight

### From Source
1. Clone the repository
   ```bash
   git clone https://github.com/your-username/net-speed-monitor.git
   cd net-speed-monitor
   ```

2. Install XcodeGen (if not already installed)
   ```bash
   gem install xcodegen
   ```

3. Generate Xcode project
   ```bash
   xcodegen generate
   ```

4. Open the project in Xcode
   ```bash
   open NetSpeedMonitor.xcodeproj
   ```

5. Build and run the project

## Development

### Prerequisites
- Xcode 16.0 or later
- macOS 15.0 or later
- Ruby 3.2+ (for XcodeGen)

### Project Structure
```
NetSpeedMonitor/
├── Models/
│   └── NetworkData.swift          # Data models
├── Services/
│   ├── NetworkMonitorService.swift # Network monitoring logic
│   └── SettingsService.swift      # User preferences
├── ViewModels/
│   └── NetworkMonitorViewModel.swift # MVVM view model
├── Views/
│   ├── MenuBarView.swift          # Menu bar interface
│   └── SettingsView.swift         # Settings window
└── Resources/
    └── Assets.xcassets/           # App icons and assets
```

### Building
The project uses XcodeGen to generate the Xcode project from `project.yml`. To rebuild the project:

```bash
xcodegen generate
```

## GitHub Actions

This project includes automated build and release workflows:

### Build Workflow
- Automatically builds on push to main/develop branches
- Runs on pull requests
- Creates build artifacts for testing
- No code signing required

### Release Workflow
- Triggers on version tags (e.g., v1.0.0)
- Code signs and notarizes the application
- Creates a DMG installer
- Publishes GitHub releases

For detailed setup instructions, see [GitHub Actions Setup](docs/GITHUB_ACTIONS_SETUP.md).

## Configuration

### Code Signing
To build for distribution, you'll need:
- Apple Developer Account
- Developer ID certificate
- App-specific password for notarization

See the [GitHub Actions Setup](docs/GITHUB_ACTIONS_SETUP.md) guide for detailed instructions.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with SwiftUI and Combine
- Uses Network framework for bandwidth monitoring
- Icons designed for macOS menu bar integration

## Support

If you encounter any issues or have questions:
1. Check the [Issues](https://github.com/your-username/net-speed-monitor/issues) page
2. Create a new issue with detailed information
3. Include your macOS version and app version

## Roadmap

- [ ] Dark mode support
- [ ] Multiple network interface monitoring
- [ ] Historical data and graphs
- [ ] Export functionality
- [ ] Widget support
- [ ] Localization
