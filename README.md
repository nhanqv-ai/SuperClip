# SuperClip

[English](#english) | [Tiếng Việt](#tiếng-việt)

---

<a name="english"></a>
## English

**SuperClip** is an ultra-lightweight, native macOS menu bar clipboard manager built with Swift and SwiftUI. It seamlessly monitors clipboard history, provides instant search, and offers quick selection via both a menu bar popover and a global floating panel.

### Highlights

- **Ultra-Compact Single-Line Design**: Every clip is presented cleanly on a single line with tail truncation, fitting 15-20 clips into view without scrolling.
- **Dual Presentation**:
  - **Menu Bar Popover**: Click the status item in the menu bar to review recent clips.
  - **Global Floating Panel**: Press `Option + V` anywhere on macOS to summon a floating panel centered at your mouse cursor.
- **Quick & Intuitive Selection**: Click any clip to copy it immediately back to your pasteboard and dismiss the panel, or navigate using Up/Down arrow keys and press Enter.
- **Multi-Language Support**:
  - Full dynamic runtime translation without restarting: English, Vietnamese (Tiếng Việt), Simplified Chinese (简体中文), Japanese (日本語), Korean (한국어), Spanish (Español), French (Français), German (Deutsch), and System Default.
- **Text & Image Clip Support**: Captures both plain text and copied images with dimensions (`[Image] 1920x1080` / `[Ảnh] 1920x1080`).
- **Instant Search**: Real-time filtering across both pinned and recent items with diacritic-insensitive matching.
- **Privacy-First & Zero Accessibility Permissions**: Uses standard macOS pasteboard monitoring; does not require Accessibility keystroke-logging permissions.
- **Native Preferences Window**: Native macOS tabbed settings with General, Ignored Apps, Clips Management, and About tabs.
- **Zero Emojis Invariant**: Flat, elegant typography and SF Symbols for a distraction-free professional interface.

### Keyboard Shortcuts

| Shortcut | Action | Scope |
| :--- | :--- | :--- |
| `Option + V` | Summon Floating Panel at cursor position | Global |
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

> [!NOTE]
> **First-Time Launch (macOS Gatekeeper)**:
> Since SuperClip is an independent open-source project without Apple Developer ID notarization, macOS may show a verification dialog (*"SuperClip" Not Opened*). You can allow it via any of these methods:
> - **Terminal (Recommended)**: Run `xattr -cr /Applications/SuperClip.app` (or on the unzipped path).
> - **System Settings**: Go to **System Settings** -> **Privacy & Security** -> click **Open Anyway**.
> - **Finder**: Right-click `SuperClip.app` -> choose **Open** -> click **Open**.

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

- **Giao diện một dòng siêu gọn gàng**: Mỗi dữ liệu sao chép hiển thị gọn gàng trên đúng một dòng với dấu chấm lửng (`...`), hiển thị được 15-20 mục trong tầm nhìn mà không cần cuộn chuột.
- **Hai chế độ hiển thị linh hoạt**:
  - **Menu Bar Popover**: Nhấn vào icon trên thanh menu để xem danh sách clipboard.
  - **Cửa sổ nổi toàn cục (Floating Panel)**: Nhấn `Option + V` ở bất kỳ ứng dụng nào để mở cửa sổ chọn nhanh ngay tại vị trí con trỏ chuột.
- **Chọn nhanh và trực quan**: Nhấp chuột vào bất kỳ mục nào để sao chép ngay vào clipboard và tự động đóng cửa sổ, hoặc dùng phím Mũi tên Lên/Xuống và bấm Enter.
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

> [!NOTE]
> **Mở ứng dụng lần đầu (macOS Gatekeeper)**:
> Do SuperClip là phần mềm mã nguồn mở độc lập (chưa đăng ký chứng chỉ Apple Developer có phí), macOS có thể hiển thị thông báo bảo vệ (*"SuperClip" Not Opened*). Bạn có thể mở ứng dụng dễ dàng bằng một trong các cách:
> - **Dùng Terminal (Nhanh nhất)**: Chạy lệnh `xattr -cr /Applications/SuperClip.app` (hoặc đường dẫn file vừa giải nén).
> - **Dùng Cài đặt hệ thống**: Vào **System Settings** -> **Privacy & Security** -> cuộn xuống mục **Security** -> chọn **Open Anyway** (Vẫn mở).
> - **Dùng chuột phải**: Nhấp chuột phải (hoặc giữ phím `Control` + click) vào `SuperClip.app` -> chọn **Open** (Mở) -> chọn **Open**.

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
