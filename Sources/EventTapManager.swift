import Cocoa
import ApplicationServices

class EventTapManager {
    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Protect cutBuffer with a dedicated serial queue to avoid data races
    private let bufferQueue = DispatchQueue(label: "com.cutpaste.bufferQueue")
    private var _cutBuffer: [String] = []
    private var cutBuffer: [String] {
        get { bufferQueue.sync { _cutBuffer } }
        set { bufferQueue.sync { _cutBuffer = newValue } }
    }

    private let fileMover = FileMover()

    var onCutBufferChanged: ((Int) -> Void)?

    private var permissionTimer: Timer?

    func start() {
        // Only Accessibility is required for cgSessionEventTap.
        // Do NOT call CGPreflightListenEventAccess / CGRequestListenEventAccess —
        // those are for a different permission and cause false-negatives on macOS 14+.
        if !AXIsProcessTrusted() {
            NSLog("CutPaste: Accessibility chưa được cấp, hiển thị dialog hệ thống")
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            startPermissionPolling()
            return
        }

        createEventTap()
    }

    private func startPermissionPolling() {
        permissionTimer?.invalidate()
        NSLog("CutPaste: Bắt đầu polling quyền Accessibility...")
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            if AXIsProcessTrusted() {
                NSLog("CutPaste: Quyền Accessibility đã được cấp!")
                timer.invalidate()
                self?.permissionTimer = nil
                self?.createEventTap()
            }
        }
    }

    private func createEventTap() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("CutPaste: Không thể tạo event tap dù đã có quyền Accessibility")
            showPermissionsAlert(missingAccessibility: false, missingInputMonitoring: false)
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        NSLog("CutPaste: Event tap đã khởi động thành công")
        FinderBridge.preflightAutomation()
    }

    func stop() {
        permissionTimer?.invalidate()
        permissionTimer = nil
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    func clearCutBuffer() {
        cutBuffer = []
        onCutBufferChanged?(0)
        NSLog("CutPaste: Cut buffer đã được xóa")
    }

    fileprivate func handleKeyEvent(_ event: CGEvent) -> CGEvent? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        let isCommand = flags.contains(.maskCommand)
        let isShift = flags.contains(.maskShift)
        let isOption = flags.contains(.maskAlternate)
        let isControl = flags.contains(.maskControl)

        // Only handle pure Command+key (no other modifiers)
        guard isCommand && !isShift && !isOption && !isControl else {
            return event
        }

        guard FinderBridge.isFinderActive() else {
            return event
        }

        switch keyCode {
        case 7: // X key - Cut
            handleCutAsync()
            return nil

        case 9: // V key - Paste
            if !cutBuffer.isEmpty {
                handlePasteAsync()
                return nil
            }
            return event

        case 8: // C key - Copy (clear cut buffer)
            if !cutBuffer.isEmpty {
                clearCutBuffer()
            }
            return event

        default:
            return event
        }
    }

    private func handleCutAsync() {
        // AppleScript MUST run on main thread for reliable permission prompts
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let files = FinderBridge.getSelectedFiles()
            guard !files.isEmpty else {
                NSLog("CutPaste: Không có file nào được chọn")
                return
            }
            self.cutBuffer = files
            self.onCutBufferChanged?(files.count)
            NSLog("CutPaste: Đã cut \(files.count) file(s)")
        }
    }

    private func handlePasteAsync() {
        // Read buffer safely on main thread, then do the actual work on a background queue
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Capture buffer snapshot on main thread to avoid race with clearCutBuffer
            let filesToMove = self.cutBuffer
            guard !filesToMove.isEmpty else { return }

            guard let destination = FinderBridge.getCurrentFolder() else {
                NSLog("CutPaste: Không thể xác định thư mục đích")
                self.showNotification(title: "CutPaste", message: "Không thể xác định thư mục đích")
                return
            }

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                let result = self.fileMover.moveFiles(filesToMove, to: destination)
                DispatchQueue.main.async {
                    switch result {
                    case .success(let count):
                        self.clearCutBuffer()
                        NSLog("CutPaste: Đã di chuyển \(count) file(s) đến \(destination)")
                    case .failure(let error):
                        NSLog("CutPaste: Lỗi di chuyển file: \(error)")
                        self.showNotification(title: "CutPaste - Lỗi", message: error.localizedDescription)
                    }
                }
            }
        }
    }

    private func showPermissionsAlert(missingAccessibility: Bool, missingInputMonitoring: Bool) {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "CutPaste cần quyền Accessibility"
            alert.informativeText = """
Vui lòng vào System Settings → Privacy & Security → Accessibility,
thêm CutPaste và bật toggle.

Sau khi bật, hãy thoát CutPaste và mở lại.
"""
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Mở Accessibility")
            alert.addButton(withTitle: "Đóng")

            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private func showNotification(title: String, message: String) {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.runModal()
        }
    }
}

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let manager = Unmanaged<EventTapManager>.fromOpaque(userInfo).takeUnretainedValue()

    // Re-enable tap if the system disables it
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = manager.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    guard type == .keyDown else {
        return Unmanaged.passUnretained(event)
    }

    if let modifiedEvent = manager.handleKeyEvent(event) {
        return Unmanaged.passUnretained(modifiedEvent)
    }

    return nil // Swallow the event
}
