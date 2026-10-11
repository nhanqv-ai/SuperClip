# SuperClip

[English](#english) | [Tiếng Việt](#tiếng-việt)

---

<a name="english"></a>
## English

**SuperClip** is an ultra-lightweight, native macOS menu bar clipboard manager built with Swift and SwiftUI. It seamlessly monitors clipboard history, provides instant search, and offers quick selection via both a menu bar popover and a global floating panel.

### Highlights

- **Ultra-Compact Single-Line Design**: Inspired by macOS CopyClip, every clip is presented cleanly on a single line with tail truncation, fitting 15-20 clips without scrolling.
- **Dual Presentation**:
  - **Menu Bar Popover**: Click the status item in the menu bar to review recent clips.
  - **Global Floating Panel**: Press `Option + V` anywhere on macOS to summon a floating panel centered at your mouse cursor.
- **Differentiated Shortcuts**:
  - **Pinned Clips**: Numbered independently from 1 to 9 with `Option + 1` .. `Option + 9` (`⌥ 1` .. `⌥ 9`).
  - **Recent History**: Numbered independently from 1 to 9 with `Command + 1` .. `Command + 9` (`⌘ 1` .. `⌘ 9`).
  - **Bare Number Navigation**: Press `1..9` directly when list is focused.
- **Multi-Language Support**:
  - Full dynamic runtime translation without restarting: English, Vietnamese (Tiếng Việt), Simplified Chinese (简体中文), Japanese (日本語), Korean (한국어), Spanish (Español), French (Français), German (Deutsch), and System Default.
- **Text & Image Clip Support**: Captures both plain text and copied images with dimensions (`[Image] 1920x1080` / `[Ảnh] 1920x1080`).
- **Instant Search**: Real-time filtering across both pinned and recent items with diacritic-insensitive matching.
- **Privacy-First & Zero Accessibility Permissions**: Uses standard macOS pasteboard monitoring; does not require Accessibility keystroke-logging permissions.
- **Native Preferences Window**: CopyClip-style tabbed settings with General, Ignored Apps, Clips Management, and About tabs.
- **Zero Emojis Invariant**: Flat, elegant typography and SF Symbols for a distraction-free professional interface.

### Keyboard Shortcuts

| Shortcut | Action | Scope |
| :--- | :--- | :--- |
| `Option + V` | Summon Floating Panel at cursor position | Global |
| `Option + 1..9` | Instantly copy corresponding Pinned item | Inside Panel |
| `Command + 1..9` | Instantly copy corresponding Recent item | Inside Panel |
| `1..9` (bare) | Instantly copy corresponding Recent item | Inside Panel (search blurred) |
| `Up / Down Arrow` | Navigate through items | Inside Panel |
| `Return / Enter` | Copy selected item and dismiss | Inside Panel |
| `Command + ,` | Open Preferences window | Inside Panel / Menu |
| `Escape` | Dismiss panel | Inside Panel |
| `Command + Q` | Quit SuperClip | Inside Panel / Menu |

### System Requirements

- macOS 13.0 (Ventura) or newer
- Apple Silicon (M1/M2/M3/M4) or Intel Mac

### Installation

#### Pre-built Release
1. Download the latest `SuperClip-v1.0.0.zip` from [Releases](https://github.com/nhanqv-ai/SuperClip/releases).
2. Unzip and drag `SuperClip.app` into your `/Applications` folder.
3. Open `SuperClip.app`. An icon will appear on your macOS menu bar.

#### Build from Source
```bash
git clone https://github.com/nhanqv-ai/SuperClip.git
cd SuperClip
make app
open SuperClip.app
```

### Development & Testing

```bash
# Compile and run complete test suite (590+ tests, 100% pass)
make test

# Verify standalone app bundle integrity
make verify-app

# Check strict 0-emoji invariant
make lint

# Clean build artifacts
make clean
```

### License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<a name="tiếng-việt"></a>
## Tiếng Việt

**SuperClip** là ứng dụng quản lý lịch sử clipboard siêu nhẹ, native cho macOS được xây dựng hoàn toàn bằng Swift và SwiftUI. Ứng dụng tự động theo dõi nội dung sao chép, hỗ trợ tìm kiếm tức thì, ghim mục quan trọng và cho phép chọn nhanh qua thanh Menu Bar hoặc cửa sổ nổi (floating panel) gọi bằng phím tắt toàn cục.

### Tính năng nổi bật

- **Giao diện một dòng siêu gọn gàng**: Lấy cảm hứng từ ứng dụng CopyClip kinh điển, mỗi dữ liệu sao chép hiển thị gọn gàng trên đúng một dòng với dấu chấm lửng (`...`), hiển thị được 15-20 mục mà không cần cuộn chuột.
- **Hai chế độ hiển thị linh hoạt**:
  - **Menu Bar Popover**: Nhấn vào icon trên thanh menu để xem danh sách clipboard.
  - **Cửa sổ nổi toàn cục (Floating Panel)**: Nhấn `Option + V` ở bất kỳ ứng dụng nào để mở cửa sổ chọn nhanh ngay tại vị trí con trỏ chuột.
- **Phân biệt phím tắt riêng biệt**:
  - **Mục đã ghim (Pinned)**: Đánh số độc lập từ 1 đến 9 với phím tắt `Option + 1` .. `Option + 9` (`⌥ 1` .. `⌥ 9`).
  - **Lịch sử thường (Recent)**: Đánh số độc lập từ 1 đến 9 với phím tắt `Command + 1` .. `Command + 9` (`⌘ 1` .. `⌘ 9`).
  - **Phím số trực tiếp**: Bấm số `1..9` khi không nhập tìm kiếm để chọn nhanh mục tương ứng.
- **Hỗ trợ đa ngôn ngữ**:
  - Thay đổi ngôn ngữ tức thì trong cài đặt: Tiếng Việt, Tiếng Anh, Tiếng Trung, Tiếng Nhật, Tiếng Hàn, Tiếng Tây Ban Nha, Tiếng Pháp, Tiếng Đức và Mặc định theo hệ điều hành.
- **Hỗ trợ văn bản và hình ảnh**: Ghi nhận cả văn bản thuần và ảnh chụp màn hình kèm thông số kích thước (`[Ảnh] 1920x1080`).
- **Tìm kiếm tức thì**: Lọc kết quả real-time theo nội dung, không phân biệt dấu tiếng Việt.
- **Bảo mật & Không cần quyền trợ năng**: Sử dụng cơ chế pasteboard tiêu chuẩn của macOS, hoàn toàn không yêu cầu cấp quyền Accessibility giám sát bàn phím.
- **Cửa sổ Cài đặt chuẩn macOS**: Giao diện tabbed preferences chuyên nghiệp gồm Cài đặt chung, Ứng dụng bỏ qua, Quản lý dữ liệu và Giới thiệu.
- **Quy chuẩn 0 Emojis**: Sử dụng font chữ tiêu chuẩn và icon SF Symbols hiện đại, tinh tế.

### Bảng phím tắt thông dụng

| Phím tắt | Thao tác | Phạm vi |
| :--- | :--- | :--- |
| `Option + V` | Mở cửa sổ nổi chọn clipboard tại vị trí chuột | Toàn hệ thống |
| `Option + 1..9` | Chọn và sao chép mục đã ghim tương ứng | Trong cửa sổ |
| `Command + 1..9` | Chọn và sao chép mục lịch sử thường tương ứng | Trong cửa sổ |
| `1..9` (phím số) | Chọn và sao chép mục lịch sử khi không focus tìm kiếm | Trong cửa sổ |
| `Mũi tên Lên / Xuống` | Di chuyển giữa các mục clipboard | Trong cửa sổ |
| `Return / Enter` | Chọn sao chép mục đang chọn và đóng cửa sổ | Trong cửa sổ |
| `Command + ,` | Mở cửa sổ Cài đặt (Preferences) | Trong cửa sổ / Menu |
| `Escape` | Đóng cửa sổ clipboard | Trong cửa sổ |
| `Command + Q` | Thoát ứng dụng SuperClip | Trong cửa sổ / Menu |

### Yêu cầu hệ thống

- macOS 13.0 (Ventura) trở lên
- Hỗ trợ tốt trên chip Apple Silicon (M1/M2/M3/M4) và chip Intel

### Hướng dẫn cài đặt

#### Tải bản đóng gói sẵn
1. Tải bản phát hành mới nhất `SuperClip-v1.0.0.zip` tại mục [Releases](https://github.com/nhanqv-ai/SuperClip/releases).
2. Giải nén và kéo file `SuperClip.app` vào thư mục `/Applications` (Ứng dụng).
3. Mở `SuperClip.app`. Biểu tượng ứng dụng sẽ xuất hiện trên thanh menu macOS.

#### Biên dịch từ mã nguồn
```bash
git clone https://github.com/nhanqv-ai/SuperClip.git
cd SuperClip
make app
open SuperClip.app
```

### Lệnh phát triển & Kiểm thử

```bash
# Chạy bộ kiểm thử tự động toàn diện (590+ bài test, pass 100%)
make test

# Xác thực tính toàn vẹn của bundle ứng dụng
make verify-app

# Kiểm tra quy chuẩn 0-emoji
make lint

# Dọn dẹp file build
make clean
```

### Giấy phép (License)

Dự án được phân phối dưới giấy phép [MIT License](LICENSE).
