import Cocoa

class EventTapManager {
    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var cutBuffer: [String] = []
    private let fileMover = FileMover()

    var onCutBufferChanged: ((Int) -> Void)?

    func start() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("CutPaste: Không thể tạo event tap. Hãy cấp quyền Accessibility trong System Settings.")
            showAccessibilityAlert()
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        NSLog("CutPaste: Event tap đã khởi động thành công")
    }

    func stop() {
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
        cutBuffer.removeAll()
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
            handleCut()
            return nil // Swallow the event

        case 9: // V key - Paste
            if !cutBuffer.isEmpty {
                handlePaste()
                return nil // Swallow the event
            }
            return event // No files in buffer, let normal paste through

        case 8: // C key - Copy (clear cut buffer if user switches to copy)
            if !cutBuffer.isEmpty {
                clearCutBuffer()
            }
            return event // Let normal copy through

        default:
            return event
        }
    }

    private func handleCut() {
        let files = FinderBridge.getSelectedFiles()
        guard !files.isEmpty else {
            NSLog("CutPaste: Không có file nào được chọn")
            return
        }

        cutBuffer = files
        onCutBufferChanged?(cutBuffer.count)
        NSLog("CutPaste: Đã cut \(files.count) file")
    }

    private func handlePaste() {
        guard let destination = FinderBridge.getCurrentFolder() else {
            NSLog("CutPaste: Không thể xác định thư mục đích")
            showNotification(title: "CutPaste", message: "Không thể xác định thư mục đích")
            return
        }

        let filesToMove = cutBuffer
        clearCutBuffer()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = self?.fileMover.moveFiles(filesToMove, to: destination)

            DispatchQueue.main.async {
                switch result {
                case .success(let count):
                    NSLog("CutPaste: Đã di chuyển \(count) file đến \(destination)")
                case .failure(let error):
                    NSLog("CutPaste: Lỗi di chuyển file: \(error)")
                    self?.showNotification(title: "CutPaste - Lỗi", message: error.localizedDescription)
                case .none:
                    break
                }
            }
        }
    }

    private func showAccessibilityAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "CutPaste cần quyền Accessibility"
            alert.informativeText = "Vui lòng vào System Settings → Privacy & Security → Accessibility và bật CutPaste."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Mở System Settings")
            alert.addButton(withTitle: "Đóng")

            if alert.runModal() == .alertFirstButtonReturn {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func showNotification(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
}

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // Re-enable tap if it gets disabled by the system
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let userInfo = userInfo {
            let manager = Unmanaged<EventTapManager>.fromOpaque(userInfo).takeUnretainedValue()
            if let tap = manager.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        return Unmanaged.passRetained(event)
    }

    guard type == .keyDown, let userInfo = userInfo else {
        return Unmanaged.passRetained(event)
    }

    let manager = Unmanaged<EventTapManager>.fromOpaque(userInfo).takeUnretainedValue()

    if let modifiedEvent = manager.handleKeyEvent(event) {
        return Unmanaged.passRetained(modifiedEvent)
    }

    return nil // Swallow the event
}
