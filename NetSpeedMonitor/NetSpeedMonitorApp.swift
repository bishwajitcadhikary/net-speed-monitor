import SwiftUI
import AppKit

@main
struct NetSpeedMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView(viewModel: appDelegate.viewModel)
        }
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
        
        // Start monitoring
        viewModel.startMonitoring()
        
        
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        viewModel.stopMonitoring()
    }
    
    @MainActor private func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem.button {
            button.title = "↑ -- KB/s\n↓ -- KB/s"
            button.action = #selector(togglePopover)
            button.target = self
            
            // Configure button for proper vertical centering
            button.imagePosition = .noImage
            button.alignment = .center
            if let cell = button.cell {
                cell.controlSize = .regular
                cell.font = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
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
        
        // Create attributed string for multi-line support with proper centering
        let lines = text.components(separatedBy: "\n")
        if lines.count == 2 {
            _ = NSMutableAttributedString()
            
            // Create paragraph style for center alignment
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineSpacing = 0
            paragraphStyle.lineHeightMultiple = 0
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .regular),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle,
                .baselineOffset: 0
            ]
            
            // Combine both lines into a single attributed string
            let fullText = lines.joined(separator: "\n")
            let fullAttributedString = NSAttributedString(string: fullText, attributes: attributes)
            
            button.attributedTitle = fullAttributedString
            
            // Configure button properties for proper centering
            button.imagePosition = .noImage
            button.alignment = .center
            button.cell?.controlSize = .regular
            
            // Force button to recalculate its frame
            button.needsLayout = true
        } else {
            // Fallback to regular title
            button.title = text
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
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @MainActor @objc private func quitApp() {
        viewModel.quitApplication()
    }
}

import Combine
