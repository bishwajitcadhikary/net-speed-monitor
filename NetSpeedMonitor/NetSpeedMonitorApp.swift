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
        // Use a more stable approach similar to the original NetSpeedMonitor
        // Calculate appropriate width based on expected text content
        let expectedText = "↑ 999.9M\n↓ 999.9M"
        let font = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        let textSize = expectedText.size(withAttributes: [.font: font])
        let fixedWidth = max(textSize.width + 20, 70) // Add padding and minimum width
        
        statusBarItem = NSStatusBar.system.statusItem(withLength: fixedWidth)
        
        if let button = statusBarItem.button {
            button.title = "↑ --\n↓ --"
            button.action = #selector(togglePopover)
            button.target = self
            
            // Configure button for proper vertical centering
            button.imagePosition = .noImage
            button.alignment = .center
            if let cell = button.cell {
                cell.controlSize = .regular
                cell.font = font
            }
            
            // Add right-click context menu
            let contextMenu = createContextMenu()
            button.menu = contextMenu
            
            // Update button text when view model changes
            let cancellable = viewModel.$menuBarText
                .receive(on: DispatchQueue.main)
                .sink { [weak self] text in
                    self?.updateStatusBarButton(with: text)
                }
            viewModel.addCancellable(cancellable)
        }
    }
    
    @MainActor private func updateStatusBarButton(with text: String) {
        guard let button = statusBarItem.button else { return }
        
        // Use simple title update for better stability
        // This approach is more similar to the original NetSpeedMonitor
        button.title = text
        
        // Ensure consistent button configuration
        button.imagePosition = .noImage
        button.alignment = .center
        button.cell?.controlSize = .regular
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
