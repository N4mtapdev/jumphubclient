# Jump Hub v4.2 - Ghi chú và ghi chú kỹ thuật trong code
L1	-- Jump Hub v4.2 (v4.1 + 9 fix: hotkey gate, FPS graph, master volume, slider refresh, menu resize, quick chat, keybind, emote, mobile layout)
L2	-- Created by N4mtapdev
L3	-- Pure client-side LocalScript. No remotes, no server dependency, no admin/kick code.
L4	-- (toan bo chi tiet va ghi chu duoc chuyen sang JumpHubComments.md)
L19	-- Cache original settings so "Restore Graphics" can undo everything cleanly.
L20	-- Wrapped in pcall: some executors/games block settings() or certain properties,
L21	-- and an unhandled error here would kill the whole script before the UI is even built.
L39	-- ================= THEME =================
L56	-- ================= STATE =================
L60		-- Graphics / performance toggles
L66		-- v3.2 extras
L69		-- v3.3
L78	-- Slider-driven values (not simple on/off)
L91	-- ================= SAVED SETTINGS / THEMES =================
L92	-- Saving needs an executor that exposes writefile/readfile; if it doesn't, everything
L93	-- below silently does nothing and the hub just uses its defaults.
L105	-- Movement-type toggles are never auto-restored (you don't want to spawn mid-spin or flying)
L151	-- ================= GUI ROOT =================
L152	-- WaitForChild + explicit .Parent assignment (rather than Instance.new's second-arg shorthand)
L153	-- since some executors/environments handle the shorthand inconsistently, which can
L154	-- silently fail to parent the GUI and make it look like "nothing happened".
L180	-- ================= TOP BAR =================
L186	-- mask the bottom corners of Top so it looks flush with Main
L233		-- Hover feedback (MouseEnter/Leave) only fires for mouse users - on touch devices
L234		-- there's no hover state, so InputBegan/InputEnded give the same visual feedback
L235		-- for a finger tap as MouseEnter/Leave gives a cursor, ensuring taps feel responsive.
L256	-- Using plain ASCII-safe characters instead of "-"/"X": some mobile fonts/executors
L257	-- fail to render those glyphs and show a blank box instead, which is what made these
L258	-- buttons look "broken" even though the click handlers underneath were working fine.
L262	-- ================= TAB BAR (horizontal, restored from the earlier working version) =================
L273	-- Plain emoji-free text labels for tabs - simplest possible version to rule out
L274	-- any icon/image loading logic as a source of trouble.
L290	-- 5 tabs: Move, Player, Misc, FPS, Find (search)
L303	-- ================= CONTENT PAGES =================
L338		-- Search results are real rows borrowed from the other pages: borrow while on "Find",
L339		-- hand them back as soon as any other tab is opened.
L356	-- ================= TOGGLE BUTTON CREATOR =================
L364	-- Search registry: every row (toggle/slider/button) registers itself so the "Find" tab
L365	-- can borrow matching rows and give them back afterwards.
L454	-- ================= SLIDER CREATOR =================
L455	-- Horizontal drag slider. min/max define the value range; sliderKey indexes into `Sliders`.
L507		-- [4] làm mới UI theo Sliders hiện tại (min/max lấy từ closure)
L551	-- ================= ACTION BUTTON CREATOR =================
L552	-- One-shot button (not a toggle). The callback may return a string to flash as feedback.
L587	-- PAGE 1: Movement
L595	-- PAGE 2: Player
L601	-- (teleport slots + more Player-page rows are built at the end of the script)
L603	-- PAGE 3: Misc
L621	-- PAGE 4: Graphics / Performance
L675	-- ================= TOP BUTTON ACTIONS =================
L676	-- X now HIDES the menu instead of destroying it, so the floating "JH" button can
L677	-- bring it back. All running features (FPS boosts etc.) keep working either way.
L686	-- Floating popup button (separate ScreenGui so it stays visible when the menu is hidden)
L724	-- ================= GRAPHICS APPLY LOGIC =================
L725	-- Applied only when a toggle actually changes state, not every frame, to avoid wasted work.
L726	-- These settings work in ANY game since they touch client-global rendering/Lighting/workspace
L727	-- properties rather than anything game-specific.
L732		-- Iterates the whole workspace once per toggle flip (not per-frame) to reduce
L733		-- part/texture/decal rendering cost. Safe for any game since it only touches
L734		-- generic rendering properties, never gameplay logic.
L766	-- Disables the heaviest Lighting post-processing effects (Bloom, SunRays, DepthOfField,
L767	-- ColorCorrection blur-like effects). These run a full-screen shader pass every frame
L768	-- regardless of scene complexity, so turning them off is one of the biggest single FPS wins
L769	-- available client-side, in any game.
L790	-- Hides every other player's character model. In crowded servers, rendering other
L791	-- players (meshes, accessories, materials, animations) is often the single biggest
L792	-- FPS cost - bigger than map geometry. This only affects YOUR client's rendering,
L793	-- nobody else is impacted and nothing is sent to the server.
L816	-- Hide NPCs/Bots (client-side only): any Model with a Humanoid that is NOT a player
L817	-- character. It cannot kill bots on the server (the server still runs them), but it stops
L818	-- YOUR client from rendering/animating them, which is where most NPC-related FPS loss is.
L841			-- Stop animation playback on this client to save CPU
L867	-- Newly spawned NPCs get hidden automatically while the toggle is on
L879	-- Re-apply periodically so NPCs that restart animations or re-enable parts stay hidden
L898		-- Hide NPCs/Bots - removes the render + animation cost of every non-player character
L904		-- Low Graphics Mode: master switch - drops renderer quality + strips materials/decals workspace-wide
L915		-- Disable Shadows
L921		-- Flat Lighting (kills fog, a common FPS drain outdoors in any game)
L933		-- Reduce Render Distance (streaming target radius - works in any game with StreamingEnabled)
L943		-- Hide Particles/Trails/Beams: scans workspace once per toggle flip, not every frame
L962		-- Disable Post-Processing (Bloom/SunRays/DoF/Blur/ColorCorrection) - big single win
L968		-- Hide Other Players - usually the single biggest FPS win in crowded servers
L974		-- Reduce Resolution (mobile-focused): forces the lowest QualityLevel, which on most
L975		-- phones/tablets also lowers the internal render resolution scale (not just texture
L976		-- detail). There is no direct "set resolution %" API exposed to scripts - this is the
L977		-- closest legitimate lever available client-side.
L988	-- Also apply Low Graphics treatment to any parts/decals that stream in later
L1005	-- Keep newly spawned/respawned other-player characters hidden if the toggle is on
L1036	-- ================= MOBILE FLY CONTROLS =================
L1037	-- On touch devices there is no Space/Ctrl, so while Fly is on we show two hold-buttons
L1038	-- (UP / DOWN) on the right side of the screen. Horizontal movement uses the normal
L1039	-- on-screen joystick (see UpdateFly).
L1085	-- ================= FLY IMPLEMENTATION =================
L1086	-- Uses a BodyVelocity so it works consistently across games without touching
L1087	-- Humanoid states (keeps animations looking normal-ish and avoids fighting
L1088	-- server-side anti-noclip/anti-fly checks that watch CFrame teleporting instead).
L1114			-- keep a bit of momentum so leaving Fly isn't an abrupt stop
L1132		-- WASD relative to camera look direction
L1144		-- Mobile/gamepad: no WASD keys are held, so use the joystick direction instead
L1145		-- (Humanoid.MoveDirection is already camera-relative).
L1165	-- ================= HOVER (STAND STILL IN AIR) IMPLEMENTATION =================
L1166	-- Freezes the character at its current position in mid-air: a BodyVelocity with zero
L1167	-- velocity and infinite force cancels gravity and any drift. Fly takes priority - if Fly
L1168	-- is on, Hover is paused (Fly already holds you in place when no keys are pressed).
L1192	-- ================= SPEED CLIMB IMPLEMENTATION =================
L1193	-- Detects when the player is pressed against a surface roughly in front of them
L1194	-- (via a short raycast) while airborne, and adds upward velocity - mimics a fast
L1195	-- wall-climb without needing game-specific ladder/climb logic. Purely additive:
L1196	-- if there's nothing to climb, this does nothing.
L1218	-- Reset Fly's internal instance references on respawn - the old BodyVelocity/BodyGyro
L1219	-- get destroyed along with the old character, so stale references must be cleared or
L1220	-- Fly would silently stop working after dying once.
L1227	-- ================= EXTRA FEATURES (v3.2) =================
L1231	-- Anti-AFK: when Roblox reports the player as idle, send a harmless fake input
L1232	-- so the client is not disconnected for inactivity.
L1241	-- Hotkeys (ignored while typing in chat/text boxes)
L1248	-- v4.1: bang phim tat co the doi (Keybind editor o tab Set).
L1249	-- ResolveKeybind tra ve ten action cho 3 toggle ma code cu xu ly, nen hanh vi mac dinh
L1250	-- (F/H/N/Q/LeftShift/RightShift) van giuyen nguyen nhu truoc.
L1259	-- [7] cờ dùng chung: đang chờ gõ phím trong Keybind editor thì handler Menu phải bỏ qua
L1289	-- Fullbright: brighter ambient light, re-applied periodically because many games
L1290	-- reset Lighting on a day/night cycle.
L1314	-- Remove Clouds/Atmosphere: Terrain clouds are disabled, Atmosphere objects are
L1315	-- detached (and put back on restore), and sun/moon/stars are hidden.
L1355	-- Simplify Water: flat, non-reflective, non-animated terrain water
L1379	-- Mute All Game Sounds: sets every Sound in Workspace/SoundService to volume 0 and
L1380	-- remembers the original volume so it can be restored exactly.
L1411	-- ---------- v3.3 additions: logic ----------
L1415	-- Small toast message at the top of the screen
L1441	-- Dash: quick burst forward (Q key, on-screen button, or the Player-tab button)
L1480	-- Click Teleport: tap on touch devices, Ctrl+Click on PC. Drags (camera rotation) are ignored.
L1514	-- Teleport slots, player target, spectate
L1545	-- Rejoin / server hop
L1571		-- Fallback if the server list can't be fetched: let Roblox pick a server
L1576	-- Generic "disable Enabled on these classes, restore later" helper (FX + lights)
L1621	-- Distance Cull: parts farther than the slider distance from the camera are hidden (client-only).
L1622	-- Characters, terrain and huge parts (floors/baseplates) are never touched. The list is walked
L1623	-- in small batches so it never causes a frame hitch.
L1696	-- Battery Saver: one switch that turns on every lightweight-mode option, and puts each
L1697	-- one back to what it was before when switched off.
L1716	-- Per-frame driver for all the extras above
L1725		-- Gravity slider (only writes when the slider actually moved)
L1731		-- FOV slider (re-applied every frame while customised, since games often tween FOV)
L1743		-- On-screen UP/DOWN pad: only on touch devices, only while Fly is on
L1746		-- One-shot toggles: apply only when the switch actually changes
L1760		-- Light periodic sweep: Fullbright + keep sounds muted if the game changes volumes
L1766			-- Lag warning: FPS < 20 or ping > 300 for ~2s, at most one toast every 10s
L1782			-- Keep spectating locked on the target (follows respawns)
L1804		-- v3.3 toggles
L1824		-- Auto Low-GFX: if FPS stays under the threshold for 3s, flip Low Graphics Mode on.
L1825		-- One-shot (turns itself off afterwards) so it never fights a manual toggle.
L1840	-- ---------- v3.3 additions: UI rows (built last so every callback target exists) ----------
L1876	-- Player page: teleport slots + movement extras
L1923	-- Misc page: warnings, look & feel, saving, players, servers
L1980	-- ================= v4.0 EXTENSION MODULE =================
L1981	-- Everything new lives inside InstallV4() so it gets its own local-variable budget
L1982	-- (the main chunk is already close to Luau's 200-locals limit).
L1990		-- ---------- 1. new state / slider keys ----------
L2020		-- movement / camera / fun toggles are never auto-restored on the next launch
L2028		-- the save file was read before these keys existed, so read it again for them
L2043		-- ---------- 2. small UI helpers ----------
L2097		-- ---------- 3. scrolling tab bar + 6 new tabs ----------
L2130		-- ---------- 4. extra overlay GUIs (HUD, bars, crosshair) ----------
L2190		-- ---------- 5. UI ROWS ----------
L2191		-- Move page (Page1) extras
L2218		-- FPS page (Page4) extras
L2248				-- leaving Ultra Low runs Battery Saver's restore pass first; wait for it to finish
L2254		-- Cam page
L2284		-- HUD page
L2317		-- Light page
L2365		-- Util page
L2399		-- tiny safe calculator (no loadstring): + - * / ^ and parentheses
L2476		-- Fun page
L2510		-- UI page
L2533		-- ---------- 6. runtime state + logic ----------
L2572			-- zoom limits
L2580			-- lighting
L2610			-- overlays
L2616			-- UI look
L2627			-- music volume
L2630			-- stopwatch / timer / break reminder
L2650			-- hide far players
L2677			-- trail / aura (re-created after respawn)
L2711			-- HUD text
L2766		-- extra air jumps
L2781		-- join / leave alerts
L2789		-- camera: orbit / top-down / roll (runs right after Roblox's own camera update)
L2817		-- main driver
L2824			-- Sprint (the main loop adds SpeedBonus to WalkSpeed)
L2848			-- float platform
L2869			-- one-shot toggle edges (capture original values on, restore on off)
L2926			-- day/night cycle runs every frame (smooth)
L2931			-- rainbow border colour (read by the main loop)
L2934			-- slow tick (4x per second), protected so one bad frame can't spam errors
L2945		-- hide the pages we just created (Show also recolours the new tabs)
L2955	-- ================= v4.1 EXTENSION MODULE (InstallV5) =================
L2956	-- 50 tính năng còn thiếu của danh sách 150. Toàn bộ code mới nằm trong InstallV5()
L2957	-- (cùng kiểu InstallV4, gọi bằng pcall) để không vượt giới hạn 200 local của chunk
L2958	-- chính; nếu lỗi thì script v4.0 vẫn chạy bình thường.
L2960		-- ===== 0. services + tham chiếu trang đã có =====
L2963		-- trang đã có: tìm qua TabPageMap (key = tab, value = trang) -> không đụng code cũ
L2969		-- ===== 1. helper dùng chung =====
L2972		-- thêm tab mới giống mảng newTabDefs trong InstallV4
L2995		-- GUI overlay riêng của v4.1 (stamina, biểu đồ, minimap, bánh xe emote...)
L3003		-- ===== 2. nhật ký lỗi nội bộ (mục 140) =====
L3015		-- ===== 3. tooltip (mục 126) =====
L3038		-- ===== 4. helper copy / label / ô nhập (bản v4.1 vì bản của v4 nằm trong InstallV4) =====
L3092		-- ===== 5. vùng chạm GUI (dành cho touch / Free Cam) =====
L3107		-- ===== 6. nạp cấu hình đã lưu cho key mới (mục 132) =====
L3125		-- ===== 7. động lực chạy chung =====
L3131		-- ==================== ĐỢT A: Movement + Camera ====================
L3133			-- --- key mới ---
L3155			-- toggle di chuyển / camera không bao giờ tự bật lại ở lần vào sau
L3166			-- --- trạng thái nội đợt ---
L3188			-- ===== 17: tiêu stamina cho Sprint / Dash / Slide =====
L3195			-- ===== 14: Air Dash (lao trên không) =====
L3219			-- ===== 15: Slide (trượt) =====
L3247			-- thanh stamina: tạo khi bật, hủy khi tắt
L3253				-- [5] thanh stamina trên mobile nhích lên trên nút ảo jump của game
L3281			-- nút ảo mobile: Crouch / Slide / Air Dash (cao 46px >= 36px)
L3284				-- [9] vị trí có thể bị driver dịch trái khi FlyPad hiện (set lại mỗi frame ở dưới)
L3332			-- nút ảo mobile cho Free Cam (6 nút, cùng vị trí với MovePad)
L3385			-- ===== driver movement: chạy MỖI frame, sau driver v4.0, trước vòng lặp chính =====
L3397				-- ===== 17: thanh stamina =====
L3430				-- ===== SpeedBonus: CHỈ CỘNG thêm, không bao giờ ghi đè hum.WalkSpeed =====
L3453				-- nếu driver v4.0 không chạy (lỗi) thì tự reset, tránh cộng dồn mỗi frame
L3458				-- ===== 26: giới hạn tốc độ rơi =====
L3466				-- ===== 4: Hover cho phép đi ngang =====
L3482				-- ===== 9: Air Control =====
L3496				-- ===== 34: khi Free Cam bật thì nhân vật đứng yên =====
L3502				-- ===== 41 + 18 + 15: camera offset (lưu giá trị gốc, khôi phục khi tắt) =====
L3523				-- ===== nút ảo mobile =====
L3533				-- [9] FlyPad nằm ở (1,-16 / 0.55); MovePad/FreePad góc dưới phải phải dịch trái khi FlyPad hiện
L3542			-- ===== driver camera: chạy trong RenderStep sau camera của game (priority Camera+2) =====
L3547				-- ===== 34: Free Cam =====
L3581				-- ===== 36: Shift Lock (bản client: xoay nhân vật theo hướng camera khi di chuyển) =====
L3596				-- ===== 37 + 38: camera mượt + giảm rung màn hình =====
L3635			-- nhìn bằng chuột phải / kéo touch (chỉ khi Free Cam đang bật)
L3661			-- phím tắt đợt A (bỏ qua khi đang gõ chat / đang rebind)
L3662			-- [1] mọi phím của v4.1 yêu cầu States.Hotkeys VÀ States.ExtraHotkeys đều bật
L3683			-- ===== hàng UI đợt A =====
L3721			-- tooltip cho các row của đợt A (mục 126)
L3738			-- ===== TÍNH NĂNG MỚI: Ultimate ESP (highlight + tag tên/khoảng cách cho player & NPC) =====
L3739			-- client-only: chỉ tạo Highlight/BillboardGui local, không gửi gì lên server
L3746				-- gỡ sạch effect của 1 target (connection + instance)
L3760				-- gỡ toàn bộ khi tắt toggle (đúng quy tắc: Disconnect + Destroy)
L3768				-- target hop le: model co Humanoid va khong phai nhan vat minh
L3778				-- tạo Highlight + BillboardGui tên/khoảng cách cho 1 model
L3810						-- cập nhật tên + khoảng cách mỗi frame; tự gỡ khi model chết/respawn
L3824				-- gắn ESP cho 1 object nếu là target (player khác = xanh, NPC = đỏ)
L3831				-- toggle: quét hiện tại + theo dõi object mới (respawn/spawn)
L3854		-- ==================== ĐỢT B: HUD + Light + Perf + Util ====================
L3856			-- --- key mới ---
L3886			-- tạo / hủy 1 effect trong Lighting (giống EnsureEffect của v4.0)
L3902			-- ===== 103: gửi chat qua TextChatService (KHÔNG dùng Remote) =====
L3903			-- [6] toggle Quick Chat điều khiển thật: tắt thì mọi nút gửi chat/emote báo bật Quick Chat trước
L3921			-- [9] WidgetStack: gom các widget HUD trái vào 1 cột (UIListLayout) dưới nút JH/DASH,
L3922			-- hết chồng lên nhau; từng widget vẫn kéo được và nhớ vị trí trong phiên
L3937			-- đưa 1 widget vào stack (hoặc vị trí đã kéo trước đó); trả về frame để caller giữ tham chiếu
L3949				-- kéo được (chuột + touch); thả thì ghi nhớ vị trí và thoát khỏi stack
L3980			-- ===== 88 / 95: biểu đồ dạng thanh dọc =====
L3988				-- [9] vào WidgetStack thay vì đặt cứng
L4022			-- ===== 90: minimap đơn giản =====
L4058			-- ===== 92: hiển thị phím bấm =====
L4065				-- [9] Keystrokes chỉ dành cho PC: thiết bị touch tự tắt (không có bàn phím)
L4107			-- ===== 93: bộ đếm CPS =====
L4132			-- ===== 104: bánh xe emote =====
L4186			-- ===== 102: lịch sử clipboard =====
L4245			-- bọc Clip5 để mọi copy của v4.1 đều vào lịch sử
L4256			-- ===== 72: Sky preset =====
L4346			-- ===== 80: lưu / tải preset ánh sáng =====
L4403			-- ===== 56: giảm chi tiết mesh =====
L4430			-- ===== 63: đóng băng animation NPC ở xa =====
L4472			-- ===== 65: ẩn GUI nặng của game theo tên =====
L4512			-- một cặp connection duy nhất cho 3 tính năng bật theo toggle
L4543			-- ===== driver của đợt B =====
L4546				-- widget bật/tắt (tạo khi bật, Destroy khi tắt)
L4578				-- 56 / 63 / 65: bật = quét 1 lần + gắn connection; tắt = khôi phục
L4588				-- 92: hiện trạng thái phím mỗi frame
L4591				-- 93: CPS
L4606				-- 88: ping
L4618				-- 95: FPS (frames đã được đếm trong BDriver mỗi frame)
L4629				-- 90: minimap
L4655				-- 77: Sun Rays
L4667				-- 63: quét NPC định kỳ (4 lần/giây, chỉ danh sách NPC đã biết)
L4671			-- ===== hàng UI đợt B =====
L4731			-- tooltip đợt B
L4751		-- ==================== ĐỢT C: UI + Settings ====================
L4753			-- --- key mới (118, 122, 126, 129 + cài đặt) ---
L4760			-- tab Cài đặt mới (thứ 12, nằm cuối thanh tab cuộn)
L4763			-- nhớ phím mặc định TRƯỚC khi nạp file đã lưu (136)
L4767			-- ===== file lưu riêng của v4.1: yêu thích / keybind / ngôn ngữ / auto-start =====
L4778					-- [5] nạp kích thước menu đã lưu (mục 112)
L4802						-- [5] lưu kích thước menu đã kéo (mục 112)
L4810			-- [9] 138: AutoOn chỉ ghi States, việc áp dụng thật chuyển sang LateInit
L4811			-- (sau khi mọi State của cả 4 đợt đã được tạo, kể cả key đợt D)
L4828			-- ===== 118: Theme Sáng (đổi Background/Panel/Text chứ không chỉ accent) =====
L4872			-- ===== 122: icon cho từng tab =====
L4888			-- ===== 137: bảng dịch Việt/Anh (khớp với tên row đã RegisterSearch) =====
L4955				-- v4.1
L4982			-- ===== 137: áp dụng ngôn ngữ cho mọi row (giữ nguyên text gốc trong attribute) =====
L4996			-- force = true khi đổi ngôn ngữ; force = false chỉ sửa lại các row đang hiển thị bản gốc
L5010			-- ===== 126: tooltip giải thích (chuột = hover, touch = giữ 0.45s) =====
L5057			-- ===== 125: Yêu thích - gắn ngôi sao vào MỖI row đã đăng ký =====
L5073							-- ActionBtn: co nút lại, chừa 40px bên trái cho sao
L5077							-- SliderRow: dời label + track sang phải
L5083							-- ToggleBtn
L5113			-- ===== 129: hiệu ứng ripple khi bấm =====
L5170			-- ===== 130: responsive mobile/PC (chạy 4 lần/giây) =====
L5176				-- [5] tôn trọng kích thước người dùng đã kéo: scale chỉ thu khi menu vượt viewport
L5184				-- tab cao >= 36px trên mobile, trang trượt xuống cho khớp
L5192			-- ===== 136: trình chỉnh phím tắt =====
L5220					-- [7] chặn phím hệ thống nguy hiểm (Escape chỉ để hủy)
L5223					-- [7] chống trùng: phím đã dùng cho action khác thì tự hoán đổi
L5239			-- ===== 140: console/log lỗi nội bộ =====
L5270			-- ===== 125: danh sách Yêu thích =====
L5342			-- ===== 133: nhiều profile =====
L5383			-- ===== 135: reset tất cả về mặc định =====
L5423			-- ===== hàng UI đợt C (tab Set) =====
L5477			-- [1] tổng công tắc cho các phím của v4.1 (E/V/P/Z/T/Y/U); cho phép lưu vào file cài đặt
L5522			-- [5] mục 112 giờ LÀM ĐƯỢC: resize cửa sổ menu Jump Hub (không phải cửa sổ game)
L5619			-- [5] mục 112: tay nắm kéo góc dưới phải của Main (chuột + touch), 280x300..560x720
L5661			-- dịch thêm các row mới của v4.1
L5679			-- ===== driver đợt C =====
L5691				-- ActionBtn treen lay lai text goc Anh sau moi lan bam, sua lai 1s/lan
L5710		-- ==================== ĐỢT D: Audio + Fun ====================
L5712			-- --- key mới (141, 142, 144) ---
L5730			-- ===== 141: âm lượng tổng (nhân toàn bộ Sound/AudioEmitter với 1 hệ số) =====
L5733			-- [3] CHỈ xử lý Sound (AudioEmitter không có Volume); property access đều bọc pcall
L5756			-- ===== 142: tắt nhạc nền game (đoán theo tên Sound / SoundGroup) =====
L5788			-- ===== 144: âm click UI (thử nhiều ID, không tải được thì báo Không hỗ trợ) =====
L5827			-- kết nối theo toggle: master/music (sound mới) + click (nút mới)
L5875			-- ===== 103/149: gửi chat (bản riêng của đợt D, vì SendChat của đợt B nằm trong block khác) =====
L5876			-- [8] gộp logic gửi chat + emote vào 1 chỗ; ưu tiên Humanoid:PlayEmote trước khi gửi /e qua chat
L5891			-- [8] PlayEmote: ưu tiên Humanoid:PlayEmote (chạy ngay, không cần chat); không được mới gửi /e qua chat
L5899				-- PlayEmote không chạy (R6 / game không bật emote): fallback qua chat
L5905			-- ===== 150: easter egg (bàn phím + ô nhập cho mobile); [10] mã chữ đổi thành mã bí mật mới =====
L5937			-- [10] chỉ còn 1 mã chữ bí mật (không phân biệt hoa thường, bỏ khoảng trắng 2 đầu); mã cũ đã bỏ
L5947			-- phím tắt đợt D: emote wheel / dance / wave + dãy Konami (dãy Konami KHÔNG phụ thuộc Extra Hotkeys)
L5952				-- [1] phím emote yêu cầu Hotkeys + ExtraHotkeys như các phím khác
L5965			-- ===== hàng UI đợt D =====
L5988			-- ===== driver đợt D =====
L6002		-- ===== 8. vòng lặp của v4.1 =====
L6003		-- Kết nối Ở ĐÂY (sau InstallV4, trước vòng lặp chính) để driver v4.0 đặt SpeedBonus
L6004		-- trước, driver v4.1 cộng thêm sau, rồi vòng lặp chính mới ghi hum.WalkSpeed.
L6052	-- ================= FUNCTIONALITY LOOP =================
L6058	-- Using Heartbeat instead of RenderStepped: some executors/environments throttle or
L6059	-- block RenderStepped from firing for LocalScripts (especially injected/executor-run
L6060	-- scripts, as opposed to scripts placed directly in StarterPlayerScripts), which is
L6061	-- what caused every feature - FPS counter, toggles, tab switching animations, all of
L6062	-- which are driven from this single loop - to silently do nothing. Heartbeat runs on
L6063	-- the physics step instead of the render step and is far more consistently available.
L6092				-- NoClip turned off: give back collision to exactly the parts we disabled
L6099			-- Fly: create/destroy the BodyVelocity+BodyGyro pair only on state change
L6109			-- Hover: hold position in mid-air (paused while Fly is active)
L6120			-- Auto Walk now lives in its own PreSimulation connection below this loop
L6121			-- (see the comment there) - a Move() here, inside Heartbeat, was too late
L6122			-- to move the character.
L6124			-- Anti Fall Damage: cap the downward fall speed (skipped while Fly is on)
L6135			-- Auto Jump: triggers a jump automatically whenever grounded, on a short
L6136			-- interval so it doesn't spam ChangeState every single frame
L6146		-- FPS/ping counter (no blocking Wait())
L6160		-- Power Saver (formerly "Cap Frame Rate"): Roblox does not expose a script API to
L6161		-- force a hard framerate cap - RenderStepped firing less often does NOT stop the
L6162		-- engine from rendering frames underneath it. What this toggle actually does instead
L6163		-- is throttle the UI's OWN cosmetic work (glow animation, FPS-color updates) down to
L6164		-- ~10 updates/sec instead of every frame, freeing a small amount of CPU/battery on
L6165		-- weaker mobile devices. It won't raise your in-game FPS ceiling, but it reduces the
L6166		-- hub's own overhead to close to zero.
L6191	-- Auto Walk: keep moving forward relative to the camera.
L6192	-- It must be applied in PreSimulation (before the physics step), NOT Heartbeat:
L6193	-- Roblox's own PlayerModule writes the humanoid's move direction from a
L6194	-- RenderStepped callback (a zero vector whenever no movement key is held), and
L6195	-- Heartbeat fires AFTER physics - so a Move() issued there never affected the
L6196	-- current step and was overwritten by the next control-module update before the
L6197	-- next one. That is why the toggle used to do nothing. PreSimulation fires after
L6198	-- the control module and before physics, so our direction is the last one written.
