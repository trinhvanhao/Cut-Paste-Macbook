import ServiceManagement

class LoginItemManager {
    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                    NSLog("CutPaste: Đã bật khởi động cùng macOS")
                } else {
                    try SMAppService.mainApp.unregister()
                    NSLog("CutPaste: Đã tắt khởi động cùng macOS")
                }
            } catch {
                NSLog("CutPaste: Lỗi thay đổi login item: \(error)")
            }
        }
    }
}
