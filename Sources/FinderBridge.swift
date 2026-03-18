import Cocoa

struct FinderBridge {

    static func isFinderActive() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        return app.bundleIdentifier == "com.apple.finder"
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
}
