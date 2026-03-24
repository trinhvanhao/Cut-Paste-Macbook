# CutPaste

**True Cut & Paste for macOS Finder.**

macOS Finder chỉ hỗ trợ Copy (⌘C) + Paste (⌘V). CutPaste bổ sung tính năng **Cut (⌘X)** để di chuyển file nhanh chóng — giống như Windows Explorer.

## Tính năng

- **⌘X** — Cut file/folder đang chọn trong Finder
- **⌘V** — Paste (di chuyển) file đến thư mục hiện tại
- **⌘C** — Copy bình thường (tự động hủy cut nếu có)
- Hiển thị icon trên menu bar với số file đang chờ paste
- Tự động xử lý trùng tên file
- Hỗ trợ khởi động cùng macOS
- Universal Binary — chạy trên cả Apple Silicon và Intel Mac

## Cài đặt

### Tải DMG (Khuyến nghị)

1. Tải file `.dmg` từ [Releases](../../releases)
2. Mở DMG, kéo **CutPaste** vào thư mục **Applications**
3. Mở app, cấp quyền **Accessibility** khi được hỏi

### Build từ source

```bash
git clone https://github.com/trinhhao/CutPaste.git
cd CutPaste
bash Scripts/build.sh
cp -r build/CutPaste.app /Applications/
```

## Cấp quyền Accessibility

App cần quyền Accessibility để hoạt động:

1. Mở **System Settings** → **Privacy & Security** → **Accessibility**
2. Nhấn **+**, thêm **CutPaste**
3. Bật toggle

### Nếu vẫn chưa hoạt động

Trên một số phiên bản macOS, bạn cần bật thêm:

- **Privacy & Security → Input Monitoring** (CutPaste)
- **Privacy & Security → Automation** → cho phép **CutPaste** điều khiển **Finder**

Sau khi bật quyền, hãy **Thoát CutPaste và mở lại**.

Nếu bạn **build lại** hoặc **di chuyển app sang đường dẫn khác**, macOS có thể yêu cầu cấp quyền lại. Khi đó hãy tắt/bật lại CutPaste trong các mục quyền ở trên.

## Yêu cầu hệ thống

- macOS 13.0 (Ventura) trở lên
- Apple Silicon hoặc Intel Mac

## License

MIT License
