import AppKit

/// Browsers this menu-bar app can set as the system default for http and https links.
enum Browser: String, CaseIterable {
    case safari
    case chrome

    var displayName: String {
        switch self {
        case .safari: "Safari"
        case .chrome: "Google Chrome"
        }
    }

    /// Short label shown in the menu bar.
    var statusTitle: String {
        switch self {
        case .safari: "Safari"
        case .chrome: "Chrome"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .safari: "com.apple.Safari"
        case .chrome: "com.google.Chrome"
        }
    }

    var applicationURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    static func matching(bundleIdentifier: String) -> Browser? {
        allCases.first { $0.bundleIdentifier == bundleIdentifier }
    }
}

/// Which app currently opens https links, whether or not it is Safari or Chrome.
struct BrowserState: Equatable {
    var selection: Browser?
    var bundleIdentifier: String?
    var displayName: String
    var statusTitle: String

    static let unknown = BrowserState(
        selection: nil,
        bundleIdentifier: nil,
        displayName: "Unknown",
        statusTitle: "Browser"
    )
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var state = BrowserState.unknown
    private var isSwitching = false
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu

        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }

    func menuWillOpen(_ menu: NSMenu) {
        refresh()
        rebuildMenu(menu)
    }

    @objc private func selectBrowser(_ sender: NSMenuItem) {
        guard !isSwitching,
              let raw = sender.representedObject as? String,
              let browser = Browser(rawValue: raw),
              browser != state.selection,
              let appURL = browser.applicationURL
        else { return }

        isSwitching = true
        Task {
            await switchDefault(to: browser, appURL: appURL)
            isSwitching = false
            refresh()
        }
    }

    @objc private func quit(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }

    private func refresh() {
        let detected = Self.detectCurrentBrowser()
        guard detected != state else { return }
        state = detected
        applyStatusItem()
    }

    private func applyStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = nil
        button.imagePosition = .noImage
        button.title = state.statusTitle
        button.font = NSFont.systemFont(ofSize: 13)
        button.toolTip = "Default browser: \(state.displayName)"
    }

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem(title: "Default Browser", action: nil, keyEquivalent: "")
        header.isEnabled = false
        if #available(macOS 14.4, *) {
            header.subtitle = "Switch your browser, change your life"
        }
        menu.addItem(header)
        menu.addItem(.separator())

        for browser in Browser.allCases {
            let installed = browser.applicationURL != nil
            var title = browser.displayName
            if !installed {
                title += " (not installed)"
            }
            let item = NSMenuItem(title: title, action: #selector(selectBrowser(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = browser.rawValue
            item.state = browser == state.selection ? .on : .off
            item.isEnabled = installed && !isSwitching
            menu.addItem(item)
        }

        if state.selection == nil, state.displayName != "Unknown" {
            menu.addItem(.separator())
            let other = NSMenuItem(title: "Current: \(state.displayName)", action: nil, keyEquivalent: "")
            other.isEnabled = false
            menu.addItem(other)
        }

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(quit(_:)), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    /// Sets the https handler first (what System Settings calls the default web browser),
    /// then http if that scheme still points somewhere else. macOS asks the user to confirm.
    private func switchDefault(to browser: Browser, appURL: URL) async {
        do {
            for scheme in ["https", "http"] {
                if Self.bundleIdentifier(forScheme: scheme) == browser.bundleIdentifier {
                    continue
                }
                try await NSWorkspace.shared.setDefaultApplication(
                    at: appURL,
                    toOpenURLsWithScheme: scheme
                )
            }
        } catch {
            if !Self.isCancellation(error) {
                presentError(error, browser: browser)
            }
        }
    }

    private func presentError(_ error: Error, browser: Browser) {
        let alert = NSAlert()
        alert.messageText = "Couldn’t switch to \(browser.displayName)"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        NSApp.activate()
        alert.runModal()
    }

    private static func detectCurrentBrowser() -> BrowserState {
        guard let probe = URL(string: "https://example.com"),
              let appURL = NSWorkspace.shared.urlForApplication(toOpen: probe)
        else {
            return .unknown
        }

        let bundleIdentifier = Bundle(url: appURL)?.bundleIdentifier
        let bundle = Bundle(url: appURL)
        let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? appURL.deletingPathExtension().lastPathComponent

        if let bundleIdentifier, let browser = Browser.matching(bundleIdentifier: bundleIdentifier) {
            return BrowserState(
                selection: browser,
                bundleIdentifier: bundleIdentifier,
                displayName: browser.displayName,
                statusTitle: browser.statusTitle
            )
        }

        return BrowserState(
            selection: nil,
            bundleIdentifier: bundleIdentifier,
            displayName: name,
            statusTitle: compact(name)
        )
    }

    private static func bundleIdentifier(forScheme scheme: String) -> String? {
        guard let url = URL(string: "\(scheme)://example.com"),
              let appURL = NSWorkspace.shared.urlForApplication(toOpen: url)
        else { return nil }
        return Bundle(url: appURL)?.bundleIdentifier
    }

    private static func compact(_ name: String) -> String {
        if name.count <= 14 { return name }
        return String(name.prefix(13)) + "…"
    }

    private static func isCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError
    }
}

// Process entry is the main thread; AppDelegate is main-actor isolated.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)

    let bundleID = Bundle.main.bundleIdentifier ?? "com.gigacorp.DefaultBrowserSwitch"
    let myPID = ProcessInfo.processInfo.processIdentifier
    for running in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) where running.processIdentifier != myPID {
        running.terminate()
    }

    app.run()
}
