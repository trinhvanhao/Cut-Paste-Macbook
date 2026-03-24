import Cocoa

struct FinderBridge {
    private static var didShowAutomationAlert = false

    static func isFinderActive() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        return app.bundleIdentifier == "com.apple.finder"
    }

    static func preflightAutomation() {
        // Trigger the Automation prompt early (CutPaste → Finder) so hotkeys "just work".
        // Run on a background thread to avoid blocking the main run loop at startup.
        DispatchQueue.global(qos: .utility).async {
            _ = runAppleScript(#"tell application "Finder" to get name of startup disk"#)
        }
    }

    static func getSelectedFiles() -> [String] {
        let script = """
        tell application "Finder"
            set selectedItems to selection
            set filePaths to {}
            repeat with anItem in selectedItems
                set end of filePaths to POSIX path of (anItem as alias)
            end repeat
            return filePaths
        end tell
        """
        return runAppleScript(script)
    }

    static func getCurrentFolder() -> String? {
        let script = """
        tell application "Finder"
            try
                set currentFolder to (target of front Finder window) as alias
                return POSIX path of currentFolder
            on error
                return POSIX path of (path to desktop folder)
            end try
        end tell
        """
        let results = runAppleScript(script)
        return results.first
    }

    private static func runAppleScript(_ source: String) -> [String] {
        guard let script = NSAppleScript(source: source) else { return [] }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)

        if let error = error {
            NSLog("CutPaste AppleScript error: \(error)")
            maybeShowAutomationAlertIfNeeded(error)
            return []
        }

        // Handle list result
        if result.numberOfItems > 0 {
            var paths: [String] = []
            for i in 1...result.numberOfItems {
                if let item = result.atIndex(i) {
                    paths.append(item.stringValue ?? "")
                }
            }
            return paths.filter { !$0.isEmpty }
        }

        // Handle single string result
        if let str = result.stringValue, !str.isEmpty {
            return [str]
        }

        return []
    }

    private static func maybeShowAutomationAlertIfNeeded(_ error: NSDictionary) {
        guard !didShowAutomationAlert else { return }

        // -1743 is a common "Not authorized to send Apple events to ..." error.
        if let number = error["NSAppleScriptErrorNumber"] as? Int, number == -1743 || number == -1744 {
            didShowAutomationAlert = true
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                let alert = NSAlert()
                alert.messageText = "CutPaste cần quyền Automation để điều khiển Finder"
                alert.informativeText = """
Vui lòng vào System Settings → Privacy & Security → Automation,
sau đó bật quyền cho CutPaste điều khiển Finder.

Sau khi bật, hãy thoát CutPaste và mở lại.
"""
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Mở Automation")
                alert.addButton(withTitle: "Đóng")

                if alert.runModal() == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}
