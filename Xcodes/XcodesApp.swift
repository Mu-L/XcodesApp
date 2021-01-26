import AppKit
import Preferences
import Sparkle
import SwiftUI

@main
struct XcodesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate: AppDelegate
    @SwiftUI.Environment(\.scenePhase) private var scenePhase: ScenePhase
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup("Xcodes") {
            MainWindow()
                .environmentObject(appState)
                // This is intentionally used on a View, and not on a WindowGroup, 
                // so that it's triggered when an individual window's phase changes instead of all window phases.
                // When used on a View it's also invoked on launch, which doesn't occur with a WindowGroup. 
                // FB8954581 ScenePhase read from App doesn't return a value on launch
                .onChange(of: scenePhase) { newScenePhase in
                    guard !isTesting else { return }
                    if case .active = newScenePhase {
                        appState.updateIfNeeded()
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Xcodes") {
                    appDelegate.showAboutWindow()
                }
            }
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    appDelegate.checkForUpdates()
                }
            }
            CommandGroup(replacing: .appSettings) {
                Button("Preferences...") {
                    showPreferencesWindow()
                }
                .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
            }
            
            CommandGroup(after: CommandGroupPlacement.newItem) {
                Button("Refresh") {
                    appState.update()
                }
                .keyboardShortcut(KeyEquivalent("r"))
                .disabled(appState.isUpdating)
            }

            XcodeCommands(appState: appState)
        }
    }
    
    private func showPreferencesWindow() {
        PreferencesWindowController(
            panes: [
                Preferences.Pane(
                    identifier: .general,
                    title: "General",
                    toolbarIcon: NSImage(systemSymbolName: "gearshape", accessibilityDescription: "General")!
                ) {
                    GeneralPreferencePane()
                        .environmentObject(appState)
                },
                Preferences.Pane(
                    identifier: .updates,
                    title: "Updates",
                    toolbarIcon: NSImage(systemSymbolName: "arrow.triangle.2.circlepath.circle", accessibilityDescription: "Updates")!
                ) {
                    UpdatesPreferencePane()
                },
                Preferences.Pane(
                    identifier: .advanced,
                    title: "Advanced",
                    toolbarIcon: NSImage(systemSymbolName: "gearshape.2", accessibilityDescription: "Advanced")!
                ) {
                    AdvancedPreferencePane()
                        .environmentObject(appState)
                },
            ]
        )
        .show()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var aboutWindow = configure(NSWindow(
        contentRect: .zero,
        styleMask: [.closable, .resizable, .miniaturizable, .titled],
        backing: .buffered,
        defer: false
    )) {
        $0.title = "About Xcodes"
        $0.contentView = NSHostingView(rootView: AboutView(showAcknowledgementsWindow: showAcknowledgementsWindow))
        $0.isReleasedWhenClosed = false
    }
    
    private let acknowledgementsWindow = configure(NSWindow(
        contentRect: .zero,
        styleMask: [.closable, .resizable, .miniaturizable, .titled],
        backing: .buffered,
        defer: false
    )) {
        $0.title = "Xcodes Acknowledgements"
        $0.contentView = NSHostingView(rootView: AcknowledgmentsView())
        $0.isReleasedWhenClosed = false
    }

    /// If we wanted to use only SwiftUI API to do this we could make a new WindowGroup and use openURL and handlesExternalEvents.
    /// WindowGroup lets the user open more than one window right now, which is a little strange for an About window.
    /// (It's also weird that the main Xcode list window can be opened more than once, there should only be one.)
    /// To work around this, an AppDelegate holds onto a single instance of an NSWindow that is shown here.  
    /// FB8954588 Scene / WindowGroup is missing API to limit the number of windows that can be created
    func showAboutWindow() {
        aboutWindow.center()
        aboutWindow.makeKeyAndOrderFront(nil)
    }
    
    func showAcknowledgementsWindow() {
        acknowledgementsWindow.center()
        acknowledgementsWindow.makeKeyAndOrderFront(nil)
    }
    
    func checkForUpdates() {
        SUUpdater.shared()?.checkForUpdates(self)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize manually
        SUUpdater.shared()
    }
}