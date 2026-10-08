# Jump Hub v4.0 - Changelog

File: `JumpHubClient.lua` (v3.3 -> v4.0, khoảng 3060 dòng, vẫn là MỘT file).

## Cách hoạt động
- Toàn bộ phần mới nằm trong hàm `InstallV4()` (trước mục FUNCTIONALITY LOOP). Nếu phần mới lỗi, script cũ vẫn chạy và in cảnh báo `[JumpHub] v4 extension failed to load` trong console.
- Chỉ sửa 3 dòng của code cũ: dòng WalkSpeed (cộng thêm Sprint), dòng màu viền (Rainbow), và dòng tiêu đề phiên bản.
- Thanh tab giờ cuộn ngang được, có 11 tab: Move, Player, Misc, FPS, Find + 6 tab mới (Cam, HUD, Light, Util, Fun, UI).

## Kết quả theo danh sách 150 tính năng
- **Đã có sẵn từ bản cũ (40):** 1, 2, 3, 5, 6, 7, 8, 11, 13, 20, 21, 22, 23, 31, 43, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 57, 58, 59, 61, 62, 68, 73, 108, 111, 113, 114, 124, 127, 128, 131
- **Mới thêm trong v4.0 (60):** 10, 12, 16, 24, 25, 28, 30, 32, 33, 35, 39, 40, 42, 44, 45, 60, 64, 66, 67, 69, 70, 71, 74, 75, 76, 78, 79, 81, 82, 83, 84, 85, 86, 87, 89, 91, 94, 96, 97, 98, 99, 100, 101, 105, 106, 107, 109, 110, 115, 116, 117, 119, 120, 121, 123, 143, 145, 146, 147, 148
- **Chưa làm (50):** 4, 9, 14, 15, 17, 18, 19, 26, 27, 29, 34, 36, 37, 38, 41, 56, 63, 65, 72, 77, 80, 88, 90, 92, 93, 95, 102, 103, 104, 112, 118, 122, 125, 126, 129, 130, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 144, 149, 150

Ghi chú:
- Mục 12 (Triple Jump) làm bằng slider "Extra Air Jumps" (0-5 lần nhảy thêm).
- Mục 115-117 là 3 theme mới Ocean, Pink, Mono (không phải bản Light). Thêm theme Custom chỉnh bằng 3 slider RGB.
- Mục 59 được mở rộng bằng "Hide Far Players" (ẩn theo khoảng cách).
- Mục 91 chỉ hiện số máu ở HUD, chưa làm thanh máu tùy chỉnh.
- Mục 87, 101, 109, 110 cần executor có `setclipboard`; nếu không có sẽ hiện nội dung trong thông báo.
- Mục 143 (nhạc) dùng Sound ID bạn nhập, nhiều ID có thể bị khóa.
- Các mục chưa làm gồm: những thứ phức tạp (Free Cam, Slide, Emote wheel, minimap, biểu đồ FPS, keybind editor, đa ngôn ngữ, nhiều profile...) và những thứ không có API script (master volume, tắt rung camera).

## CHƯA ĐƯỢC TEST
Mình không có Luau/Roblox trong môi trường làm việc, nên **chưa chạy thử trong game**. Mới kiểm tra: các khối `function/if/for/end` cân bằng, các biến dùng đều đã được khai báo trước. Lỗi logic hoặc lỗi API vẫn có thể có.

## Checklist test nhanh (5-10 phút)
1. Chạy script: có thấy 11 tab, vuốt thanh tab ngang được, console có dòng `v4 extension installed`.
2. Tab Move: bật Bunny Hop (giữ Space), Sprint (giữ Left Shift), kéo Extra Air Jumps lên 2 và nhảy 3 lần, Glide (giữ Space khi rơi), Float Platform.
3. Tab Cam: bật Orbit Camera rồi tắt (camera phải về bình thường), thử Top-Down, Cinematic Bars, Screenshot Mode (UI ẩn 5 giây rồi hiện lại).
4. Tab HUD: bật vài dòng, kiểm tra bảng HUD xuất hiện góc phải và kéo được.
5. Tab Light: bật Lock Time, đổi giờ, tắt (phải về giờ ban đầu); thử Bloom, Color Boost, Blur rồi tắt.
6. Tab FPS: bấm Quality Preset đủ vòng 4 mức, kể cả từ Ultra Low về Normal.
7. Tab Util: stopwatch, countdown, calculator, tìm người chơi.
8. Tab UI: Rainbow Border, kéo Menu Size %, Apply Custom Accent.
9. Respawn nhân vật khi đang bật Trail, Aura, Float Platform.
10. Nút "Menu Size" cũ ở tab Misc vẫn đổi kích thước menu bình thường.

Nếu có lỗi, gửi lại dòng lỗi trong console (F9) kèm tên tính năng.