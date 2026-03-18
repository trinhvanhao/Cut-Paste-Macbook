import Cocoa

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var cutCountItem: NSMenuItem!
    private var cancelCutItem: NSMenuItem!
    private var launchAtLoginItem: NSMenuItem!
    private let eventTapManager = EventTapManager()
    private let loginItemManager = LoginItemManager()

    override init() {
        super.init()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "scissors", accessibilityDescription: "CutPaste")
            button.image?.size = NSSize(width: 16, height: 16)
        }

        setupMenu()

        eventTapManager.onCutBufferChanged = { [weak self] fileCount in
            self?.updateStatus(fileCount: fileCount)
        }

        eventTapManager.start()
    }

    private func setupMenu() {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "CutPaste", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        cutCountItem = NSMenuItem(title: "Không có file nào đang cut", action: nil, keyEquivalent: "")
        cutCountItem.isEnabled = false
        menu.addItem(cutCountItem)

        cancelCutItem = NSMenuItem(title: "Hủy Cut", action: #selector(cancelCut), keyEquivalent: "")
        cancelCutItem.target = self
        cancelCutItem.isHidden = true
        menu.addItem(cancelCutItem)

        menu.addItem(NSMenuItem.separator())

        launchAtLoginItem = NSMenuItem(title: "Khởi động cùng macOS", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginItem.state = loginItemManager.isEnabled ? .on : .off
        menu.addItem(launchAtLoginItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Thoát", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func updateStatus(fileCount: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if fileCount > 0 {
                self.statusItem.button?.image = NSImage(systemSymbolName: "scissors.badge.ellipsis", accessibilityDescription: "CutPaste - \(fileCount) file")
                self.cutCountItem.title = "\(fileCount) file đang chờ paste"
                self.cancelCutItem.isHidden = false
            } else {
                self.statusItem.button?.image = NSImage(systemSymbolName: "scissors", accessibilityDescription: "CutPaste")
                self.cutCountItem.title = "Không có file nào đang cut"
                self.cancelCutItem.isHidden = true
            }
        }
    }

    @objc private func cancelCut() {
        eventTapManager.clearCutBuffer()
    }

    @objc private func toggleLaunchAtLogin() {
        let newState = !loginItemManager.isEnabled
        loginItemManager.setEnabled(newState)
        launchAtLoginItem.state = newState ? .on : .off
    }

    @objc private func quit() {
        eventTapManager.stop()
        NSApp.terminate(nil)
    }
}
