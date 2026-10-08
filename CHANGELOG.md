# Jump Hub v4.1 - Changelog

File: `JumpHubClient.lua` (v4.0 -> v4.1, ~5870 dòng, vẫn là MỘT file). Backup bản cũ: `JumpHubClient.backup.lua`.

## Cách hoạt động
- Toàn bộ 50 tính năng mới nằm trong hàm `InstallV5()` (cùng kiểu `InstallV4`, gọi bằng pcall ngay sau `pcall(InstallV4)`). Nếu phần mới lỗi, script v4.0 vẫn chạy và in `[JumpHub] v4.1 extension failed to load: ...` trong console.
- Driver v4.1 được nối Heartbeat **giữa** driver v4.0 và vòng lặp chính: v4.0 đặt `SpeedBonus` (Sprint) trước, v4.1 cộng thêm (Crouch/Swim/Climb/Slide...), vòng lặp chính mới ghi `hum.WalkSpeed`. Không có chỗ nào ghi đè `hum.WalkSpeed` ngoài vòng lặp cũ. Có cơ chế tự chống cộng dồn nếu driver v4.0 chết.
- Camera v4.1 chạy `BindToRenderStep` priority `Camera.Value + 2` (sau camera v4.0 +1).
- Thêm 1 tab mới: **Set** (Settings). Các tính năng còn lại xếp vào tab cũ (Move/Cam/HUD/Light/FPS/Util/Fun/Misc).
- Sửa 6 chỗ nhỏ trong code cũ, đều **giữ nguyên hành vi mặc định**:
  1. Dòng tiêu đề phiên bản (v4.0 -> v4.1) + text Info tab UI + Copy Debug Info.
  2. Handler hotkey cũ: `HotkeyMap[code]` -> `ResolveKeybind(code)` (mặc định vẫn F/H/N như cũ; cho phép đổi phím).
  3. Phím Dash `Q` -> `KeyBinds.Dash` (mặc định vẫn Q).
  4. Phím Sprint `LeftShift` -> `KeyBinds.Sprint` (mặc định vẫn LeftShift).
  5. Phím ẩn/hiện menu `RightShift` -> `KeyBinds.Menu` (mặc định vẫn RightShift).
  6. Spin trong vòng lặp chính: `0.1` rad/frame -> `(Sliders.SpinRate or 10)/100` (mặc định vẫn 0.1).

## Kết quả theo 50 mục còn thiếu

### Đợt A - Movement + Camera (15/15 xong)
- **4 Hover đi ngang**: toggle "Hover Moves Sideways" — khi Hover đang bật, giữ hướng di chuyển để bay ngang theo WalkSpeed; tắt trả về đứng yên đúng như cũ.
- **9 Air Control**: slider 0-100% — trên không, vận tốc ngang được lerp về hướng di chuyển.
- **14 Air Dash**: toggle + slider lực + phím E + nút AIR DASH trên mobile; chỉ trên không, cooldown 1.2s, tốn stamina.
- **15 Slide**: toggle + slider tốc độ/thời gian + phím V + nút SLIDE; chỉ trên mặt đất, đang di chuyển; hạ camera lúc trượt; nhảy lên là hết.
- **17 Thanh Stamina**: toggle bật thanh dưới màn hình; sprint liên tục -16/s, Air Dash -25, Slide -15; hết thì chặn sprint/dash/slide đến khi hồi >= 25 (cản trở sprint v4.0 bằng cách về 0 trong SpeedBonus).
- **18 Crouch**: toggle + giữ C (hoặc giữ nút CROUCH trên mobile) -> đi chậm theo slider % + hạ camera.
- **19 Tốc độ leo**: toggle + slider — chỉ áp dụng khi Humanoid đang ở trạng thái Climbing (thang/dây).
- **26 Giới hạn tốc độ rơi**: toggle + slider MaxFall (mặc định 70).
- **27 Tốc độ bơi**: toggle + slider — chỉ áp dụng khi trạng thái Swimming.
- **29 Spin speed**: slider 0-60 (10 = 0.1 rad/frame như bản cũ) — chỉnh spin của tab Misc.
- **34 Free Cam**: toggle + slider tốc độ + phím P. WASD di chuyển, Space lên, Ctrl xuống; nhìn bằng giữ chuột phải (PC) hoặc kéo màn hình (mobile, có 6 nút ảo); nhân vật đứng yên trong lúc bật; tắt trả camera về Custom.
- **36 Shift Lock**: bản mô phỏng client (Roblox không có API bật Shift Lock từ script): tắt AutoRotate, xoay nhân vật theo camera khi di chuyển; tắt khôi phục AutoRotate.
- **37 Camera mượt**: toggle + slider; low-pass góc nhìn, tự snap khi quay quá 50°/frame.
- **38 Tắt rung màn hình**: **KHÔNG KHA THI 100%** — Roblox không có API tắt camera shake, game tự tạo rung bằng cách ghi Camera.CFrame. Đã làm phiên bản "giảm rung": toggle lọc dao động tần suất cao (di chuyển lớn/vượt 45° hoặc 25 studs thì snap ngay để không trễ thao tác thật). Không tắt được 100%.
- **41 Camera offset**: toggle + 2 slider lên/ngang (dùng `Humanoid.CameraOffset`, lưu giá trị gốc và trả lại khi tắt).

### Đợt B - HUD + Perf + Light + Util (15/15 xong)
- **88 Biểu đồ Ping**: 40 mẫu, cập nhật 4 lần/giây, góc trên trái.
- **90 Minimap**: 140px, chấm người chơi xoay theo camera, slider bán kính (30-500 studs).
- **92 Keystrokes**: W/A/S/D + Space sáng khi nhấn (cập nhật mỗi frame).
- **93 CPS**: đếm chuột trái/chạm trong 1 giây.
- **95 Biểu đồ FPS**: 40 mẫu, tự vẽ 4 lần/giây.
- **56 Giảm chi tiết mesh**: MeshPart.RenderFidelity = Performance (lưu giá trị gốc vào attribute, tắt khôi phục đúng; cả part stream vào sau).
- **63 Giảm animation NPC ở xa**: chỉ NPC (không phải người chơi); xa hơn slider thì `AdjustSpeed(0)`, lại gần thì `AdjustSpeed(1)`; tắt khôi phục toàn bộ.
- **65 Ẩn GUI game theo tên**: toggle + ô nhập tên (phân cách bằng dấu phẩy, mặc định "leaderboard, stats, shop"); GUI của hub luôn loại trừ; tắt bật lại đúng GUI đã ẩn.
- **72 Sky preset**: 5 preset (Clear Blue dùng skybox rbxasset mặc định của Roblox, Sunset, Night, Foggy, Dark Red) + nút Reset Sky lưu/khôi phục toàn bộ.
- **77 Sun Rays**: toggle + cường độ (SunRaysEffect tên JH_SunRays, tắt là Destroy).
- **80 Lưu/tải preset ánh sáng**: file `JumpHub_LightPreset.json` (cần writefile/readfile, không có thì báo Không hỗ trợ).
- **102 Lịch sử clipboard**: mọi copy từ tính năng v4.1 (vị trí, JobId, export...) ghi vào danh sách; bấm 1 mục để copy lại; có nút Copy Whole History + Clear. Lưu ý: các nút copy của v4.0 (Copy My Position...) nằm trong code cũ nên chưa ghi vào lịch sử.
- **103 Chat nhanh**: gửi qua `TextChatService.TextChannels.RBXGeneral:SendAsync` (API chính thức, KHÔNG dùng RemoteEvent); game dùng chat legacy sẽ báo Không hỗ trợ.
- **104 Emote wheel**: bánh xe 6 nút (Wave/Point/Cheer/Laugh/Dance/Dance2) giữa màn hình, gửi lệnh `/e` qua chat; phím T; nút X để đóng.

### Đợt C - UI + Settings (8 xong + 1 không khả thi)
- **112 Đổi kích thước cửa sổ**: **KHÔNG KHẢ THI** — Roblox không cung cấp API nào cho script đổi kích thước cửa sổ/viewport client (đã ghi rõ trong tab Set). Thay thế hợp lệ: "Menu Size %" cũ + nút "Fit Menu to Screen".
- **118 Theme Sáng**: toggle đổi Background/Panel/Text/SubText/Off trên MỌI GUI của hub (đổi cả màu chữ, placeholder); accent giữ nguyên; tắt trả về đúng palette tối cũ.
- **122 Icon tab**: toggle thêm ký hiệu hình học (▶ ● ◆ ▲ ○ ◎ ▤ ◐ ▩ ★ ■ ▦) vào từng tab; tắt trả về tên gốc. Nếu một vài font mobile hiện ô trống thì chỉ cần tắt toggle.
- **125 Yêu thích**: mỗi hàng có nút sao (36px) bên trái để ghim/bỏ ghim; danh sách ghim ở tab Set, bấm tên để nhảy tới đúng trang + cuộn tới hàng + nhấp nháy viền. Lưu vào `JumpHub_V5.json`.
- **126 Tooltip**: hover chuột (PC) hoặc giữ 0.45s (mobile) hiện giải thích cho ~120 tính năng; toggle bật/tắt.
- **129 Ripple**: hiệu ứng gợn sóng khi bấm mọi nút của hub (kể cả nút tạo sau); tắt là ngắt hết connection + hủy ripple đang chạy.
- **130 Responsive**: tự chạy 4 lần/giây: tab cao 42px (nút >= 36px) trên mobile, dịch trang xuống cho khớp, thu nhỏ menu vừa màn hình nhỏ; nút "Fit Menu to Screen" áp dụng ngay.
- **132 Tự tải cấu hình**: mỗi đợt key mới đều đọc lại `JumpHub_Settings.json` khi khởi động (key di chuyển/camera vẫn bị loại theo SaveExclude đúng quy tắc).
- **133 Nhiều profile**: file `JumpHub_Profiles.json`, Save/Load/Delete theo tên.
- **134 Xuất/nhập**: Export copy chuỗi JSON ra clipboard; Import dán chuỗi -> áp dụng + làm mới UI.
- **135 Reset ALL**: về mặc định toàn bộ States/Sliders/Theme/Keybinds/Yêu thích/Auto-Start, xóa cả file cài đặt.
- **136 Keybind editor**: 14 action (Fly/Hover/NoClip/Dash/Sprint/Menu/Crouch/Slide/AirDash/FreeCam/ShiftLock/EmoteWheel/Dance/Wave); bấm dòng -> gõ phím mới (Esc hủy; tạm khóa hotkeys trong lúc chờ); lưu `JumpHub_V5.json`; có nút Reset Keybinds.
- **137 Ngôn ngữ Việt/Anh**: nút Language ở tab Set; ~150 label được dịch; label tạm bị code cũ trả về tiếng Anh sẽ tự sửa lại trong 1 giây; lưu vào file.
- **138 Auto-start**: "Save ON Features as Auto-Start" ghi danh sách tính năng đang bật; lần vào game sau tự bật lại (kể cả key thuộc SaveExclude vì đây là lựa chọn chủ động của người dùng); có Clear.
- **139 Version + changelog**: bảng trong tab Set liệt kê v4.1 + mục không khả thi.
- **140 Log nội bộ**: mọi lỗi bị pcall bắt trong v4.1 ghi vào tab Set (giới hạn 120 dòng, chống spam trùng), kèm Refresh/Clear.

### Đợt D - Audio + Fun (5/5 xong)
- **141 Âm lượng tổng**: toggle + slider 0-100%. Roblox không có thuộc tính master volume, nên làm bằng cách nhân Volume của mọi Sound/AudioEmitter trong Workspace + SoundService (lưu gốc, tắt trả đúng như cũ; sound mới cũng được áp). Một số âm phát bằng API Audio mới hoặc từ nơi script không thấy được có thể không nằm trong phạm vi.
- **142 Tắt nhạc nền**: đoán nhạc theo tên Sound/SoundGroup chứa "music/bgm/theme/soundtrack/background"; tắt trả đúng âm lượng gốc.
- **144 Âm click UI**: thử lần lượt 3 ID (electronicpingshort.wav, button.wav, uuhhh.mp3), không nạp được thì tự tắt + báo "Không hỗ trợ".
- **149 Phím tắt emote**: Y = dance, U = wave, T = wheel (đổi được trong Keybind editor); mobile có nút trên tab Fun + bánh xe.
- **150 Easter egg Konami**: ↑↑↓↓←→←→BA trên bàn phím, hoặc gõ `KONAMI`/`UUDDLRLRBA` vào ô trên tab Fun (cho mobile); hiệu ứng Rainbow + Trail 30 giây rồi trả lại trạng thái cũ.

## Chưa được test trong game (nói thật)
Môi trường không có Roblox/executor, nên **chưa chạy thử trong game**. Đã kiểm tra bằng công cụ chính thức của Luau:
- `luau-compile` (Luau 0.6xx bản chính thức): **SYNTAX OK** toàn file sau mỗi đợt.
- `luau-analyze`: không còn "Unknown global" mới so với bản gốc (tức không gọi nhầm biến/toàn cục), các cảnh báo còn lại chỉ là lint cũ (biến không dùng, shadow) có sẵn từ v4.0.
- Kiểm đếm local chunk chính: 172/200 (còn dư, nhờ toàn bộ code mới nằm trong InstallV5).

Chưa kiểm chứng được: hành vi runtime thật (Roblox API từng property/event), executor có/không có writefile-setclipboard, hành vi TextChatService của từng game, việc nạp rbxasset sound, hiệu năng của minimap/graph trong map lớn, va chạm giữa các tính năng của từng game (vd Shift Lock + game tự xoay nhân vật).

## Checklist test nhanh (10-15 phút)
1. Chạy script: console có `v4 extension installed` + `v4.1 extension installed`; thanh tab có 12 tab gồm "Set"; mọi tính năng cũ (Bunny Hop, Fly, Sprint, FPS counter...) vẫn hoạt động như v4.0.
2. Move: bật Hover + "Hover Moves Sideways" rồi tắt (phải đứng yên lại); Air Control; Air Dash phím E; Slide phím V; bật Stamina Bar rồi giữ Shift chạy đến cạn.
3. Crouch giữ C; Climb Speed trên thang; Limit Fall Speed (nhảy từ cao); Swim Speed dưới nước; kéo Spin Speed về 0 rồi về 10 (phải quay đúng như cũ).
4. Cam: Free Cam phím P (nhân vật đứng yên, WASD+Space/Ctrl, chuột phải để nhìn, tắt về camera thường); Shift Lock Z; Camera Smoothing (kéo về 5 để thấy rõ); Reduce Shake; Camera Offset.
5. HUD: Ping Graph, FPS Graph, Minimap, Keystrokes, CPS; tắt từng cái là widget biến mất hết vẽ (không sót frame).
6. Light: Sky Preset vòng 5 preset rồi Reset Sky (phải về như cũ); Sun Rays; Save/Load Light Preset.
7. FPS tab: Reduce Mesh Detail bật/tắt (mesh mờ đi rồi về như cũ); Freeze Far NPC Animations.
8. Util: Clipboard History (copy vị trí rồi xem lịch sử); Quick Chat (game TextChatService mới gửi được); Emote Wheel phím T.
9. Set: Light Theme bật/tắt; Tab Icons; bật 1 vài star rồi mở Favorites bấm để nhảy tới; Save Profile/Load; Export -> Copy -> dán vào Import; Reset ALL; Keybind editor (đổi Fly sang J, bấm J phải bật Fly, bấm F phải không còn tác dụng); Language đổi Việt/Anh; xem Log.
10. Fun: Master Volume kéo 0 (tắt hết tiếng) rồi tắt toggle (tiếng về đúng cũ); Mute Game Music; UI Click Sound; Konami bằng bàn phím và bằng ô nhập.
11. Respawn khi đang bật: Trail/Aura (v4), Stamina, Camera Offset, Slide — không được lỗi, không còn dư CameraOffset cũ.
12. Mobile: nút ảo CROUCH/SLIDE/AIR DASH (>=36px), pad Free Cam 6 nút, kéo màn hình để nhìn khi Free Cam; giữ 0.45s vào 1 hàng để hiện tooltip.
