import SwiftUI
import AppKit

@main
struct NetSpeedMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Menu bar only app - no main window needed
        // All UI is managed through AppDelegate
        WindowGroup {
            EmptyView()
                .frame(width: 0, height: 0)
                .hidden()
        }
        .windowStyle(.hiddenTitleBar)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    var popover: NSPopover!
    var viewModel: NetworkMonitorViewModel!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock and any main window
        NSApp.setActivationPolicy(.accessory)
        
        // Hide any main window that might have been created by SwiftUI
        for window in NSApp.windows {
            window.orderOut(nil)
        }
        
        // Create view model
        viewModel = NetworkMonitorViewModel()
        
        // Setup status bar
        setupStatusBar()
        
        // Setup popover
        setupPopover()
        
        // Start monitoring
        viewModel.startMonitoring()
        
        // Handle window closing behavior
        setupWindowBehavior()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        viewModel?.stopMonitoring()
    }
    
    @MainActor private func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem.button {
            button.title = "-- KB/s"
            button.action = #selector(togglePopover)
            button.target = self
            
            // Add right-click context menu
            let contextMenu = createContextMenu()
            button.menu = contextMenu
            
            // Update button text when view model changes
            let cancellable = viewModel.$menuBarText
                .receive(on: DispatchQueue.main)
                .sink { [weak self] text in
                    self?.statusBarItem.button?.title = text
                }
            viewModel.addCancellable(cancellable)
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
    
    private func setupWindowBehavior() {
        // Handle settings window closing
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let window = notification.object as? NSWindow,
               window.title.contains("Settings") {
                Task { @MainActor in
                    self?.viewModel.hideSettings()
                }
            }
        }
        
        // Handle settings window opening requests
        NotificationCenter.default.addObserver(
            forName: .openSettingsWindow,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.openSettings()
            }
        }
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

// MARK: - Menu Support

extension AppDelegate: NSMenuDelegate {
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
    
    @MainActor @objc func openSettings() {
        print("DEBUG: openSettings() called - creating settings window")
        
        // Set the flag in viewModel
        viewModel.showingSettings = true
        
        // Check if settings window already exists
        if let settingsWindow = NSApp.windows.first(where: { $0.title.contains("Settings") }) {
            print("DEBUG: Found existing settings window, bringing to front")
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        // Create new settings window if it doesn't exist
        print("DEBUG: Creating new settings window")
        let settingsView = SettingsView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Net Speed Monitor Settings"
        window.setContentSize(NSSize(width: 500, height: 400))
        window.styleMask = [.titled, .closable, .resizable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        print("DEBUG: Settings window created and shown")
    }
    
    @MainActor @objc private func quitApp() {
        viewModel.quitApplication()
    }
}

import Combine
