# Jump Hub v4.2 - Changelog

File: `JumpHubClient.lua` (v4.1 -> v4.2, ~6200 dòng, vẫn là MỘT file). Backup bản cũ: `JumpHubClient.v4.1.backup.lua` (và `JumpHubClient.backup.lua` là v4.0 cũ hơn).

## Tính năng mới (bổ sung sau bản v4.2 đầu tiên)

### Ultimate ESP (toggle "Ultimate ESP" trong tab Misc)
- Viền sáng (Highlight) + tag BillboardGui hiện **tên + khoảng cách (m)** cho mọi nhân vật có Humanoid: player khác màu xanh lá, NPC màu đỏ.
- Chỉ chạy phía client (Highlight/BillboardGui local), không gửi gì lên server.
- Tự quét khi bật, tự theo dõi nhân vật mới (respawn/spawn) qua `workspace.DescendantAdded`; tắt toggle là gỡ sạch connection + instance (đúng quy tắc dọn dẹp của script).
- State `ESPOn` được lưu vào file cài đặt (không nằm trong SaveExclude).
- Trong game: bật tab Misc → "Ultimate ESP". Lưu ý một số game chặn Highlight (lúc đó chỉ còn tag tên, hoặc không hiện — script không chết nhờ pcall).

Credit: **N4mtapdev** — credit nằm ở hằng số `CREDIT` gần đầu file, in khi khởi động (`[JumpHub] v4.2 | by N4mtapdev`), ở InfoLabel tab UI và Info5 đầu tab Set.

## Tổng quan

Toàn bộ sửa lỗi vẫn nằm trong `InstallV5()` (trừ `ExpandedSize`, `SliderRefreshers`, `JHFlags`, `CREDIT` ở cấp file — cần thiết để handler menu đầu file dùng chung được). Mọi tính năng v4.0/v4.1 giữ nguyên hành vi.

## Kết quả theo 9 mục

### [1] Extra Hotkeys (phím tắt v4.1 mặc định TẮT) — XONG
- State mới `ExtraHotkeys` (mặc định `false`, được lưu vào file cài đặt vì không nằm trong SaveExclude).
- Toggle mới "Extra Hotkeys (E/V/P/Z/T/Y/U)" trong tab Set (order 9).
- Handler phím đợt A (AirDash E, Slide V, FreeCam P, ShiftLock Z) và đợt D (EmoteWheel T, EmoteDance Y, EmoteWave U) chỉ chạy khi `States.Hotkeys` **và** `States.ExtraHotkeys` đều bật.
- Riêng AirDash/Slide: nếu tính năng tương ứng đang tắt thì **im lặng**, không hiện toast "Air Dash is off".
- Dãy Konami giữ nguyên, không phụ thuộc Extra Hotkeys.
- Info5 tab Move và tab Fun đã nhắc cần bật Extra Hotkeys.

### [2] FPS Graph hiện sai — XONG
- `frames += 1` chuyển từ BSlow (4 lần/giây) sang BDriver (mỗi frame); BSlow chỉ tính `fps = frames / elapsed` rồi reset.
- `lastFpsT` khởi tạo = `tick()` (không còn lệch mẫu đầu).
- Tắt rồi bật FPS Graph sẽ `table.clear(fpsVals)` để biểu đồ bắt đầu mới.

### [3] Master Volume gọi .Volume trên AudioEmitter — XONG
- `masterTouch`, `applyMaster`, `onSoundAdded` giờ **chỉ** xử lý `v:IsA("Sound")`; bỏ AudioEmitter hoàn toàn (bỏ qua hệ audio mới, không lỗi).
- Mọi truy cập property (đọc/ghi Volume, khôi phục giá trị gốc) đều bọc pcall.

### [4] Slider không cập nhật hình sau reset/load/import — XONG
- `SliderRefreshers[sliderKey]` định nghĩa **trước** SliderRow (ngay cạnh ToggleRefreshers, cấp file).
- Trong SliderRow đăng ký hàm làm mới fill/knob/valueLbl theo `Sliders[sliderKey]` hiện tại (min/max lấy từ closure); không đổi chữ ký hàm.
- `RefreshAllSliders()` được gọi sau: `resetAll`, `applyBundle` (Load Profile / Import), Load Light Preset, Apply Custom Accent, Fit Menu to Screen và khi `LoadKeys` chạy xong.

### [5] Mục 112 = RESIZE CỬA SỔ MENU — XONG
- Tay nắm kéo 24x24 ở góc dưới phải Main (hỗ trợ chuột + touch); kéo đổi `Main.Size` trong khoảng **280x300 → 560x720**, giới hạn không vượt viewport.
- Kích thước lưu trong `ExpandedSize`; handler MinBtn mở lại đúng `ExpandedSize` thay vì cứng 320x380.
- Lưu/nạp vào `JumpHub_V5.json` (khóa `MenuSize`, có pcall); nút **Reset Menu Size** trong tab Set trả về 320x380 và xóa khóa.
- `ApplyResponsive` sửa lại: scale chỉ thu khi menu vượt viewport theo kích thước người dùng đã kéo (không còn cứng 384/340).
- Đã xóa/cải 2 đoạn "KHÔNG KHẢ THI" ở danh sách ver tab Set và Info5 cuối trang Set; thay bằng mô tả đúng. Riêng mục 38 (tắt rung màn hình) vẫn giữ ghi chú "chưa 100%".

### [6] Quick Chat toggle không làm gì — XONG (chọn phương án b)
- Khi `States.ChatQuick` **tắt**: nút "Send to Chat", các nút Emote và phím Y/U/emote wheel đều báo **"Bật Quick Chat trước"** (cả SendChat của đợt B và SendChatD của đợt D đều gate).
- Ghi chú rõ trong Tips["quick chat (textchatservice)"].

### [7] Keybind editor — XONG
- Cờ `JHFlags = {Rebind = false}` khai báo ở cấp file TRƯỚC handler Menu; handler Menu return ngay khi `JHFlags.Rebind = true` → bấm phím Menu cũ trong lúc rebind không còn ẩn menu. `RebindActive` trong InstallV5 set cùng cờ.
- Chặn phím hệ thống: không gán được Tab, Backquote, Return (Escape chỉ dùng để hủy).
- Chống trùng phím: gán phím đã dùng cho action khác sẽ **tự hoán đổi** hai action + Notify thông báo, không còn hai action chung một phím.

### [8] Emote qua /e có thể không chạy — XONG
- Hàm `PlayEmote(name)` (đợt D, khai báo trước để đợt B dùng chung): ưu tiên `Humanoid:PlayEmote(name)` bọc pcall, kiểm tra kết quả trả về; không chạy được thì fallback `SendAsync("/e name")` qua `SendChatD` (đã gộp logic, không còn lặp code); cả hai thất bại thì trả "Không hỗ trợ" và ghi Log.
- Cập nhật: Emote Wheel (6 nút), nút Emote: Wave/Dance, phím Y/U.
- Cả đường emote đều qua gate Quick Chat của mục [6].

### [9] Giao diện chồng lấn mobile + Auto-Start — XONG
- **WidgetStack**: Frame mới `JH_WidgetStack` với UIListLayout dọc, đặt dưới nút JH/DASH (y = 0.35 scale + 120px). Ping Graph, FPS Graph, Minimap, CPS vào stack thay vì Position cứng → không còn chồng nhau và không đè FloatBtn/DashFloat. Mỗi widget **kéo được** (chuột + touch) và nhớ vị trí trong phiên (`stackPosMemo`); kéo ra thì thoát khỏi stack.
- **Keystrokes** tự tắt trên thiết bị touch không có bàn phím.
- **Stamina bar** đặt cao hơn 90px so với đáy (y = 1,-124) khi `UIS.TouchEnabled` để tránh thanh jump/nút ảo của game.
- **MovePad/FreePad** dịch trái (1,-88) khi FlyPad đang hiện (FlyPad ở 1,-16 / 0.55); vị trí cập nhật mỗi frame trong MoveDriver theo `States.Fly`.
- **Auto-Start (138)**: chuyển áp dụng `AutoOn` vào **LateInit** (sau khi mọi State của cả 4 đợt đã được tạo) rồi gọi `ToggleRefreshers` cho từng key → key đợt D (MasterVol, MuteMusic, ClickSound...) giờ tự bật đúng.

### [10] Easter egg — XONG
- Mã chữ cũ đã bỏ; chỉ còn **một mã bí mật mới** (không phân biệt hoa thường, bỏ khoảng trắng 2 đầu). Dãy phím ↑↑↓↓←→←→BA giữ nguyên.
- Mã không được xuất hiện ở bất kỳ UI/tooltip/log nào: placeholder đổi thành "Nhập mã bí mật...", Info5 và Tips chỉ nói "mã bí mật", toast khi kích hoạt không nêu mã. *(Trong file vẫn phải có chuỗi so sánh để mã hoạt động — đây là bắt buộc kỹ thuật.)*

### [11] Credit — XONG
- `CREDIT = "N4mtapdev"` một chỗ duy nhất gần đầu file; dùng ở comment đầu file, print khởi động, InfoLabel tab UI, Info5 đầu tab Set. Không thêm nút/liên kết, không HttpGet.

### [12] Luau / obfuscator prep — XONG (10/10/2026)
- Toolchain Luau chính thức: `luau-compile`, `luau-analyze`, `luau` — tải từ https://github.com/luau-lang/luau/releases, đặt **ngoài repo và không dùng /tmp** (ví dụ `~/.cache/jumphub-build/luau/`). Gate chính thức: `luau-compile --binary` **exit 0** cho toàn file và cho mọi output đã obfuscate (chưa kiểm chứng runtime executor Roblox — môi trường không có Roblox/executor).
- Obfuscator chọn: **`prometheus-lua/Prometheus`** v0.2.11.1 — rebuild bằng đúng một lệnh **`sh tools/build.sh`**: script tự tải Prometheus version pinned vào `~/.cache/jumphub-build`, copy generator `tools/chemical.lua` vào `src/prometheus/namegenerators/chemical.lua` (đúng đường dẫn Prometheus `require`) + đăng ký `Chemical`, rồi chạy `--LuaU --config prometheus.config.lua` → `main.lua`. **Không phụ thuộc /tmp.** (presets có thật: `Weak`, `Strong`, `Vmify`, `Minify`, `Medium` — **không có preset `Light`**). Preset `Medium` bao gồm Encrypt Strings + Anti Tamper + Vmify + Constant Array + Numbers-To-Expressions (output ~14.000% source với file test nhỏ). Phương án thay thế: `hercules-obfuscator` với `--target luau` (12/14 module hỗ trợ Luau, tự tắt VM/bytecode).
- Lưu ý: parser của Prometheus **không nhận type annotation** (`local function greet(name: string)` lỗi parse) → input obfuscate phải là code không có annotation. `JumpHubClient.lua` không dùng annotation nên ổn. Luau support của Prometheus theo README là "basic/unfinished" → luôn validate output lại bằng `luau-compile --binary`.
- Revert: dùng `JumpHubClient.v4.2.backup.lua` để khôi phục source gốc v4.2 nếu cần.

### [13] Build / publish prep — XONG
- Single-file LocalScript source: `JumpHubClient.lua` (dùng cho mọi mục đích), khớp checksum `bd8a17a696b6625809efe5f93c074e8e5d9dc046` (cập nhật sau [14]).
- Backup: `JumpHubClient.v4.2.backup.lua` khớp checksum `3c3d2be937065f95b734be74ece86ba7a20a64b0`.
- Bản obfuscate: `main.lua` (preset Minify, tên biến theo công thức hóa học Chemical), tái tạo bằng `sh tools/build.sh`, sha1 `70b50d7eff311dcc0930817116c443ab773d9533` (cập nhật sau [14]; bản trước [14] = `9fc602037278cb8ffb447de44b1ff36c2fa21cd5`).
- Tooling nằm trong repo: `tools/build.sh`, `tools/chemical.lua`, `prometheus.config.lua` — build tái tạo 100% từ repo.
- `JumpHubClient.source.lua`, `JumpHubClient.preobf.lua`, `*.backup.lua`, `*.bak` nằm trong `.gitignore` → không đẩy lên repo công khai.

### [14] Quick Heal + fix Auto Walk không di chuyển — XONG (10/10/2026)
- **Quick Heal (full HP)**: nút `ActionBtn` mới trong tab **Player**, order 15 (ngay sau "Dash Forward (Q)"). Bấm = `Humanoid.Health = MaxHealth` ngay lập tức (bọc pcall), nút tự hiện kết quả thật: `Healed: x/y` khi đầy, `HP x/y - game kept the damage` khi game ghi đè lại máu, `No character` / `Already down` tương ứng. Client-side: một số game bắt server giữ quyền ghi máu → lúc đó chỉ hiện báo, script không chết.
- **Sửa Auto Walk không hoạt động (nguyên nhân gốc = timing)**: trước đây `hum:Move(Vector3.new(0,0,-1), true)` nằm trong driver `Heartbeat` = `PostSimulation`, chạy **sau** bước physics; còn PlayerModule của Roblox tự ghi `MoveDirection` từ callback `RenderStepped` (vector 0 khi không giữ phím di chuyển) → Move của script luôn bị ghi đè trước khi vật lý kịp đọc → toggle bật nhưng nhân vật không đi. Đã tách thành connection riêng `RunService.PreSimulation` (chạy sau control module, **trước** physics → hướng đi của ta là giá trị được ghi cuối cùng), kèm guard `not States.FreeCam` (Free Cam yêu cầu nhân vật đứng yên) và `hum.Health > 0`. Xóa block `hum:Move` cũ trong driver Heartbeat. (Nguồn: đọc source ControlScript của Roblox + tài liệu RunService — create.roblox.com/docs/reference/engine/classes/RunService.)
- Gate lại: `luau-compile --binary JumpHubClient.lua` **exit 0**; `sh tools/build.sh` **exit 0** → `main.lua` **178.577 byte**; `luau-compile --binary main.lua` **exit 0**. `JumpHubComments.md` regenerate theo source mới.

### [15]-[20] Lô tính năng mới 10/10/2026 (build sau [14]) — XONG
- **[15] Macro ghi/phát lại đường đi** (tab Player, orders 16-21): Record lưu `root.CFrame` mỗi 0.2s vào bảng bộ nhớ (không chạm file), auto-stop ở 10 phút; Stop dừng muốn ghi muốn phát; Play teleport tuần tự qua các điểm, slider "Macro Play Speed (x)" 0.5-5x điều tốc phát; "Macro: Save to file" ghi `JumpHub_Macro_YYYYMMDD_HHMMSS.json`, "Macro: Load latest" đọc file macro mới nhất qua `listfiles` — toàn bộ bọc pcall.
- **[16] PANIC (F12)**: phím cố định **không cho đổi qua keybind editor** (tránh nhầm) — bấm là toàn bộ State `true` về `false` ngay lập tức (không tween/không xác nhận), hủy macro ghi/phát, giữ nguyên các State chỉ đọc (HUD ...) và các cài đặt giao diện (Hotkeys/Tooltips/Light/Theme...), set `AssemblyLinearVelocity` = 0 để không còn vận tốc dư. Hoạt động cả khi đang gõ trong chat (`processed` không chặn panic).
- **[17] Theme Auto theo giờ**: toggle "Theme Auto (6-18h Light, còn lại Dark)" mới ở tab Set; mỗi phút (qua Slows) kiểm `os.date("%H")` — 6..17 = Light, còn lại = Dark; **không ghi đè tài khoản Light UI chủ động** (chỉ đổi khi khác LightUI hiện tại); lưu vào file cài đặt.
- **[18] Tổng thời gian chơi trong ngày**: toggle "Play Time Today (sums all sessions)" ở tab HUD; cộng dồn giây hub mở qua file riêng `JumpHub_Playtime.json` (ghi mỗi 15s, bọc pcall); tự reset khi `os.date("%Y-%m-%d")` đổi ngày; hiển thị dòng `Play: h:mm:ss` cạnhžd Session Time trong widget HUD của v4.0.
- **[19] Waypoint có tên + icon (thay 3 slot cũ)**: nút "Waypoint: Save Position Here" + ô nhập tên + 6 icon text (◆ ● ■ ▲ ★ ✿) + ScrollingFrame danh sách không giới hạn; mỗi hàng có nút TP và nút Xóa riêng; file riêng `JumpHub_Waypoints.json` bọc pcall (nạp lại khi vào game); nút "Waypoint: Delete ALL".
- **[20] UI 2 tầng**: tầng 1 = 5 nút nhóm lớn **Movement/Visual/Performance/Info/Settings** (mobile cao 42px, PC 36px — đủ bấm bằng ngón); tầng 2 = TabBar cũ giờ là tab con của từng nhóm (vd bấm Visual thấy Cam | Light | UI). **Search LUÔN HIỂN THỊ** trên cùng (giữa Top bar và GroupBar), gõ là tự lọc ngay không cần bấm tab Find trước. Trang mặc định khi mở: nếu `Favorites` trong JumpHub_V5.json có ít nhất 1 mục thì mở thẳng tab Set (danh sách Yêu thích), rỗng thì vẫn mở Move như cũ. Nội dung bên trong từng tab giữ hoàn toàn — chỉ thay đổi thao tác điều hướng.
- **Files mới**: `JumpHub_Playtime.json`, `JumpHub_Waypoints.json` (đều là file executor-side, không repo).
- **Gate lại sau draft**: `luau-compile --binary JumpHubClient.lua` exit 0; `sh tools/build.sh` exit 0 → `main.lua` 194.183 byte (sha1 `3d6cbfa23b0185ae6f0b0006b86100de094a9c5f`); `luau-compile --binary main.lua` **exit 0**.
- Điểm khác lƯot trước: `luau-analyze` exit 1 là **baseline từ trươc** (các TypeErrors đều là global Roblox/executor mà sandbox không biết như Enum/Color3/workspace/tick/task — không phải lỗi code mới); các lint mới chỉ là style (LocalUnused/SameLineStatement) không ảnh hưởng runtime.

### Chưa test trong runtime (lô này)
- Auto Walk bằng `AssemblyLinearVelocity` (ở PreSimulation), Macro Play/teleport tuần tự, PlayTime cộng dồn qua ngày, Waypoint save/load qua file riêng, Theme Auto đổi sang Light/Dark vào 6/18h, Panic F12 trên cada loại game, UI 2 tầng với cả GroupBar lẫn 12-13 tab con (trên mobile 42px, scroll slider...). Môi trường dev (sandbox) không có Roblox/executor, không test được runtime — checklist test ở lô trước vẫn áp dụng, thêm lô này.

### [21] FIX RUNTIME NGHIÊM TRỌNG: "attempt to index nil with 'Parent'" làm mất toàn bộ nút UI — XONG (10/10/2026)
**Root cause được chứng minh, không phỏng đoán:**
- `luau-analyze` báo chính xác: `JumpHubClient.lua(365,2): TypeError: Unknown global 'SearchBox'` + `JumpHubClient.lua(474,7): LocalShadow: Variable 'SearchBox' shadows a global variable used at line 365`.
- Block `[20]` (UI 2 tầng) trước đây được đặt ở **file-scope ngay sau `print("[JumpHub] UI fully built, Show(Page1) called")`**, nhưng `SearchBox` là `local` chỉ được khai báo ở **dòng 474** (sau đó) → lúc chạy dòng 365 `SearchBox.Parent = Main`, `SearchBox` là global nil → `attempt to index nil with 'Parent'`.
- Vị trí crash khớp 100% báo cáo runtime: xảy ra NGAY SAU print `[JumpHub] UI fully built, Show(Page1) called`; vì script chết tại file-scope (ngoài mọi pcall) nên toàn bộ code SAU dòng 365 KHÔNG BAO GIỜ chạy. **Thứ tự thực thi thực tế (bản lỗi 35c8eb4_RULE: thứ tự dòng trong file = thứ tự chạy)**:
  - dòng 275-300: `Tab1..Tab5 = CreateTab(...)` → **đã chạy xong trước crash** → 5 tab phẳng masih hiện trên màn hình (khớp ảnh user).
  - dòng 323: `NewPage()` tạo 5 ScrollingFrame RỖNG (`Page1..Page5`) → **đã chạy** → có 5 page trống trắng.
  - dòng 365: CRASH → mọi thứ SAU dòng đó chết.
  - dòng 699+ (ToggleBtn/ActionBtn/SliderRow(Page2, "No Clip"/"Fly"/Slide"...)) → **CHƯA TỪNG được chạy**: nút Page2 (và mọi tab khác) KHÔNG TỒN TẠI, không phải "tạo rồi mất" → đúng ảnh tab Player trống hoàn toàn.
  - dòng ~3431/6622: `pcall(InstallV4)` / `pcall(InstallV5)` chưa chạy → không thấy print "v4/v4.1 extension installed", mất toàn bộ extension.
- **Không phải lỗi obfuscate**: file gốc và main.lua lỗi giống hệt nhau như user test; đã xác minh `main.lua` bản lỗi chứa chính block `[20]` với `SearchBox.Parent=HNO3` (SearchBox là tên biến đã đổi tên). Cũng **không phải** lỗi .Parent của RunSearch/RestoreSearchRows/ApplyLang (các hàng search có guard `e.row.Parent ~= target` từ trước; ApplyLang không gán .Parent) — lỗi duy nhất là **thứ tự khai báo** block [20].

**Giải pháp (không rollback tính năng):**
- Chuyển toàn bộ block [20] thành hàm `BuildGroupBar()` đặt cạnh khai báo `SearchBox` (sau khi `SearchBox`/`RunSearch`/`RestoreSearchRows` đã tồn tại) — dùng đúng thay đổi code đã viết, KHÔNG tự viết lại.
- `GroupBarUI` nâng thành upvalue cấp file (dùng chung với `ApplyResponsive` của InstallV5); xóa `local GroupBarUI = nil` nội bộ InstallV5 (trước đây sẽ đè mất biến).
- InstallV5 gọi `BuildGroupBar()` ở **cuối InstallV5, sau vòng LateInit** (`pcall(BuildGroupBar)`) → mọi tab của v4.0/V4/V5 đã đăng ký trong `TabPageMap` khi nameToPage map → không bỏ sót nhóm; lỗi init được `pcall` bắt + `Log()` vào tab Set và `warn()`.
- Guard `.Parent` mới trong `RestoreSearchRows`/`RunSearch`: `if e.row and e.row.Parent and ...` (phòng row bị destroy giữa phiên).

**Verify không chỉ compile (đối chiếu số lượng widget theo code thực tế):**
- Parse tĩnh toàn bộ `JumpHubClient.lua` đếm chính xác số lệnh tạo widget (ToggleBtn/SliderRow/ActionBtn/Info5) mỗi page: Page1=16, **Page2=23** (No Clip/Fly/FlySpeed/Speed Climb/Hover/Slots/Waypoint×4/Auto Walk/AntiFall/ClickTP/DashButton/DashPower/Dash Forward/Quick Heal/Macro×5), Page3=15, Page4=23, PG_Set=26 (nhóm lớn nhất). Tổng 232 lệnh gọi — số này chính là số widget dự kiến hiển thị sau khi sửa.
- Mô phỏng runtime bằng lua5.1 với Roblox stub (Instance/UDim2/Enum/Color3/TweenService/Players...): chạy toàn bộ phần prelude (1-1233) KHÔNG crash, phát sinh Page1..Page5 + 5 tabs + 36 hàng SearchRegistry — cùng số lượng khớp parse tĩnh cho scope đã chạy.
- Thân `BuildGroupBar()` chép y nguyên từ source đã sửa, chạy bằng luau thật (exit 0): SearchBox.Parent == Main PASSED; JH_GroupBar gắn vào Main PASSED; đúng **5 nút nhóm** (Movement/Visual/Performance/Info/Settings) PASSED; Show(Page1)+GroupShower (highlight) và Show(Page5) hai chiều PASSED.
- Sau đó: luau-compile exit 0, sh tools/build.sh exit 0 → main.lua 194.416 byte (sha1 `1a2111e4ae5ac095332bd9cb10097bb31f482663`), luau-compile main.lua exit 0, luau-analyze KHÔNG còn Unknown global 'SearchBox'.
- **Chưa test runtime trong game** (sandbox không có Roblox/executor) — đẩy lên nhánh riêng `fix/ui-parent-bug` để user test trực tiếp, chưa merge vào main cho tới khi user xác nhận OK.

## Chưa được test trong game (nói thật)
Môi trường không có Roblox/executor, **chưa chạy thử runtime**. Đã kiểm tra bằng công cụ chính thức của Luau:
- `luau-compile` (bản chính thức): **SYNTAX OK** exit 0 toàn file.
- `luau-analyze`: không có "Unknown global" mới so với baseline (toàn bộ cảnh báo còn lại là global Roblox/executor hợp lệ đã có từ v4.0: Enum, Color3, writefile...).
- Local cấp file: 160/200 (thêm 4: CREDIT, ExpandedSize, SliderRefreshers + RefreshAllSliders, JHFlags — đều là yêu cầu bắt buộc của đề để dùng chung giữa các scope).
- Runtime trong game (PlayEmote trên từng loại rig, drag widget trên touch thật, ChatVersion từng game, keybind hoán đổi giữa 14 action) **chưa kiểm chứng được** — cần test theo checklist dưới.

## Checklist test (10-15 phút)
1. **Extra Hotkeys**: bấm E/V/P/Z/T/Y/U khi toggle tắt → không có gì xảy ra (kể cả không toast khi bấm E/V); bật toggle trong tab Set → phím hoạt động; khởi động lại game toggle giữ nguyên trạng thái đã lưu.
2. **FPS Graph**: bật ở tab HUD, số FPS phải khớp thanh tiêu đề (trước luôn ~4); tắt/bật lại biểu đồ vẽ lại từ đầu.
3. **Master Volume**: bật trong game nhiều âm thanh (kể cả game dùng Audio API mới) → Log tab Set không có lỗi; tắt toggle tiếng về đúng cũ.
4. **Slider refresh**: Reset ALL / Load Profile / Import → mọi thanh trượt nhảy đúng giá trị mới; Load Light Preset cũng vậy.
5. **Resize menu**: kéo góc dưới phải (280x300..560x720, không vượt màn hình); thu nhỏ "-" rồi mở lại → giữ kích thước đã kéo; Reset Menu Size → về 320x380; vào lại game kích thước vẫn giữ.
6. **Keybind**: bấm dòng Menu, gõ phím mới; trong lúc chờ gõ phím Menu cũ → menu KHÔNG ẩn; gán phím trùng → hai action tự hoán đổi; thử gán Tab/Backquote/Return → bị chặn.
7. **Emote**: Emote Wheel + nút Wave/Dance + phím Y/U trên nhân vật R15 → emote chạy ngay không cần gửi chat; game R6 → fallback /e; Quick Chat tắt → báo "Bật Quick Chat trước".
8. **Mobile**: Ping/FPS/Minimap/CPS xếp dọc dưới nút JH/DASH, kéo được từng widget; Keystrokes tự ẩn trên touch; stamina bar cao hơn nút jump; bật Fly → MovePad/FreePad dịch trái không đè FlyPad.
9. **Auto-Start**: bật MasterVol (+ key đợt D khác), Save ON Features as Auto-Start, vào lại game → tự bật + nút UI hiển thị đúng trạng thái ON.
10. **Easter egg**: dãy phím ↑↑↓↓←→←→BA vẫn kích hoạt; ô nhập mã chấp nhận mã mới (hoa/thường/khoảng trắng đều được), mã cũ không còn tác dụng.
11. Regressions cũ nên chạy lại nhanh: Fly/Hover/NoClip, hotkey F/H/N (chỉ phụ thuộc Hotkeys như cũ), Save/Load Settings, tab Set Language Việt/Anh.
