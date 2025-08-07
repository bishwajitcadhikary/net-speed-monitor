import SwiftUI
import AppKit

@main
struct NetSpeedMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // This is required for the app lifecycle but the window will be hidden.
        WindowGroup { EmptyView() }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    var popover: NSPopover!
    let viewModel = NetworkMonitorViewModel()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock and any main window
        NSApp.setActivationPolicy(.accessory)
        
        // Hide any main window that might have been created by SwiftUI
        for window in NSApp.windows {
            window.orderOut(nil)
        }
        
        // Setup status bar
        setupStatusBar()
        
        // Setup popover
        setupPopover()
        
        // Setup notification observers
        setupNotificationObservers()
        
        // Start monitoring
        viewModel.startMonitoring()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        viewModel.stopMonitoring()
    }
    
    @MainActor private func setupStatusBar() {
        // Create status bar item with fixed width for consistent layout
        statusBarItem = NSStatusBar.system.statusItem(withLength: 200)
        
        if let button = statusBarItem.button {
            // Configure button for custom view
            button.action = #selector(togglePopover)
            button.target = self
            
            // Create custom view for the status bar
            let customView = createStatusBarView()
            button.subviews.forEach { $0.removeFromSuperview() }
            button.addSubview(customView)
            
            // Position the custom view
            customView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                customView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 4),
                customView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -4),
                customView.topAnchor.constraint(equalTo: button.topAnchor, constant: 2),
                customView.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -2)
            ])
            
            // Add right-click context menu
            let contextMenu = createContextMenu()
            button.menu = contextMenu
            
            // Update status bar when view model changes
            let cancellable = viewModel.$networkStats
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.updateStatusBarView()
                }
            viewModel.addCancellable(cancellable)
        }
    }
    
    private func createStatusBarView() -> NSView {
        let containerView = NSView()
        containerView.wantsLayer = true
        
        // Create the status bar content view
        let contentView = StatusBarContentView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: contentView)
        
        containerView.addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        return containerView
    }
    
    @MainActor private func updateStatusBarView() {
        guard let button = statusBarItem.button,
              let customView = button.subviews.first else { return }
        
        // Force redraw of the custom view
        customView.needsDisplay = true
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .openSettingsWindow,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("DEBUG: Received openSettingsWindow notification")
            DispatchQueue.main.async {
                self?.openSettings()
            }
        }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 500)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarContentView(viewModel: viewModel)
        )
    }
    
    @objc private func togglePopover() {
        guard let button = statusBarItem.button else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            
            // Ensure the popover becomes the key window
            DispatchQueue.main.async {
                self.popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
    
    // Handle menu bar right-click
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        togglePopover()
        return false
    }
}

// MARK: - Status Bar Content View
struct StatusBarContentView: View {
    @ObservedObject var viewModel: NetworkMonitorViewModel
    @State private var isFirstToggleOn = true
    @State private var isSecondToggleOn = false
    
    var body: some View {
        HStack(spacing: 6) {
            // Leftmost icon (sun/brightness symbol)
            Image(systemName: "sun.max.fill")
                .font(.system(size: 11))
                .foregroundColor(.primary)
                .frame(width: 12, height: 12)
            
            // Ellipsis icon (three dots)
            Image(systemName: "ellipsis")
                .font(.system(size: 9))
                .foregroundColor(.primary)
                .frame(width: 10, height: 10)
            
            // Traffic direction arrows
            VStack(spacing: 1) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 7))
                    .foregroundColor(.primary)
                Image(systemName: "arrow.down")
                    .font(.system(size: 7))
                    .foregroundColor(.primary)
            }
            .frame(width: 8, height: 16)
            
            // Network speed values (vertically centered)
            VStack(spacing: 0) {
                Text(formatSpeed(viewModel.networkStats.currentSpeed.upload))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(height: 10, alignment: .center)
                    .lineLimit(1)
                Text(formatSpeed(viewModel.networkStats.currentSpeed.download))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(height: 10, alignment: .center)
                    .lineLimit(1)
            }
            .frame(width: 40)
            
            Spacer()
            
            // Toggle switches on the right
            VStack(spacing: 1) {
                Toggle("", isOn: $isFirstToggleOn)
                    .toggleStyle(SwitchToggleStyle())
                    .scaleEffect(0.5)
                    .labelsHidden()
                    .frame(width: 20, height: 12)
                
                Toggle("", isOn: $isSecondToggleOn)
                    .toggleStyle(SwitchToggleStyle())
                    .scaleEffect(0.5)
                    .labelsHidden()
                    .frame(width: 20, height: 12)
            }
            .frame(width: 20, height: 24)
        }
        .frame(height: 20)
        .padding(.horizontal, 4)
        .background(Color.clear)
    }
    
    private func formatSpeed(_ bytes: Double) -> String {
        // Handle invalid or zero values
        guard bytes.isFinite && bytes >= 0 else {
            return "0.0K"
        }
        
        let value: Double
        let unit: String
        
        if bytes >= 1024 * 1024 * 1024 {
            value = bytes / (1024 * 1024 * 1024)
            unit = "G"
        } else if bytes >= 1024 * 1024 {
            value = bytes / (1024 * 1024)
            unit = "M"
        } else if bytes >= 1024 {
            value = bytes / 1024
            unit = "K"
        } else {
            value = bytes
            unit = "B"
        }
        
        // Use compact format with consistent width
        if value >= 100 {
            return String(format: "%.0f%@", value, unit)
        } else if value >= 10 {
            return String(format: "%.1f%@", value, unit)
        } else {
            return String(format: "%.1f%@", value, unit)
        }
    }
}

// MARK: - Extensions

extension NetworkMonitorViewModel {
    func addCancellable(_ cancellable: AnyCancellable) {
        cancellable.store(in: &cancellables)
    }
}

extension AppDelegate {
    private func createContextMenu() -> NSMenu {
        let menu = NSMenu()

        let showItem = NSMenuItem(title: "Show Net Speed Monitor", action: #selector(togglePopover), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Net Speed Monitor", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc func openSettings() {
        print("DEBUG: openSettings() called")
        // Ensure we have a reference to the settings window.
        var settingsWindow: NSWindow?

        // Check if the window already exists.
        for window in NSApp.windows {
            if window.title == "Net Speed Monitor Settings" {
                settingsWindow = window
                break
            }
        }

        // If the window exists, bring it to the front.
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // Otherwise, create a new settings window.
            print("DEBUG: Creating SettingsView...")
            let settingsView = SettingsView(viewModel: viewModel)
            print("DEBUG: SettingsView created, creating NSHostingController...")
            let hostingController = NSHostingController(rootView: settingsView)
            print("DEBUG: NSHostingController created, creating NSWindow...")
            let newWindow = NSWindow(contentViewController: hostingController)
            newWindow.title = "Net Speed Monitor Settings"
            newWindow.setContentSize(NSSize(width: 550, height: 450))
            newWindow.styleMask = [.titled, .closable, .resizable]
            newWindow.center()
            print("DEBUG: About to show window...")
            newWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            settingsWindow = newWindow
            print("DEBUG: Settings window should be visible now")
        }
    }

    @MainActor @objc private func quitApp() {
        viewModel.quitApplication()
    }
}

import Combine
