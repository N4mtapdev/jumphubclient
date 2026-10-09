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
L1910	-- Misc page: warnings, look & feel, saving, players, servers
L1967	-- ================= v4.0 EXTENSION MODULE =================
L1968	-- Everything new lives inside InstallV4() so it gets its own local-variable budget
L1969	-- (the main chunk is already close to Luau's 200-locals limit).
L1977		-- ---------- 1. new state / slider keys ----------
L2007		-- movement / camera / fun toggles are never auto-restored on the next launch
L2015		-- the save file was read before these keys existed, so read it again for them
L2030		-- ---------- 2. small UI helpers ----------
L2084		-- ---------- 3. scrolling tab bar + 6 new tabs ----------
L2117		-- ---------- 4. extra overlay GUIs (HUD, bars, crosshair) ----------
L2177		-- ---------- 5. UI ROWS ----------
L2178		-- Move page (Page1) extras
L2205		-- FPS page (Page4) extras
L2235				-- leaving Ultra Low runs Battery Saver's restore pass first; wait for it to finish
L2241		-- Cam page
L2271		-- HUD page
L2304		-- Light page
L2352		-- Util page
L2386		-- tiny safe calculator (no loadstring): + - * / ^ and parentheses
L2463		-- Fun page
L2497		-- UI page
L2520		-- ---------- 6. runtime state + logic ----------
L2559			-- zoom limits
L2567			-- lighting
L2597			-- overlays
L2603			-- UI look
L2614			-- music volume
L2617			-- stopwatch / timer / break reminder
L2637			-- hide far players
L2664			-- trail / aura (re-created after respawn)
L2698			-- HUD text
L2753		-- extra air jumps
L2768		-- join / leave alerts
L2776		-- camera: orbit / top-down / roll (runs right after Roblox's own camera update)
L2804		-- main driver
L2811			-- Sprint (the main loop adds SpeedBonus to WalkSpeed)
L2835			-- float platform
L2856			-- one-shot toggle edges (capture original values on, restore on off)
L2913			-- day/night cycle runs every frame (smooth)
L2918			-- rainbow border colour (read by the main loop)
L2921			-- slow tick (4x per second), protected so one bad frame can't spam errors
L2932		-- hide the pages we just created (Show also recolours the new tabs)
L2942	-- ================= v4.1 EXTENSION MODULE (InstallV5) =================
L2943	-- 50 tính năng còn thiếu của danh sách 150. Toàn bộ code mới nằm trong InstallV5()
L2944	-- (cùng kiểu InstallV4, gọi bằng pcall) để không vượt giới hạn 200 local của chunk
L2945	-- chính; nếu lỗi thì script v4.0 vẫn chạy bình thường.
L2947		-- ===== 0. services + tham chiếu trang đã có =====
L2950		-- trang đã có: tìm qua TabPageMap (key = tab, value = trang) -> không đụng code cũ
L2956		-- ===== 1. helper dùng chung =====
L2959		-- thêm tab mới giống mảng newTabDefs trong InstallV4
L2982		-- GUI overlay riêng của v4.1 (stamina, biểu đồ, minimap, bánh xe emote...)
L2990		-- ===== 2. nhật ký lỗi nội bộ (mục 140) =====
L3002		-- ===== 3. tooltip (mục 126) =====
L3025		-- ===== 4. helper copy / label / ô nhập (bản v4.1 vì bản của v4 nằm trong InstallV4) =====
L3079		-- ===== 5. vùng chạm GUI (dành cho touch / Free Cam) =====
L3094		-- ===== 6. nạp cấu hình đã lưu cho key mới (mục 132) =====
L3112		-- ===== 7. động lực chạy chung =====
L3118		-- ==================== ĐỢT A: Movement + Camera ====================
L3120			-- --- key mới ---
L3142			-- toggle di chuyển / camera không bao giờ tự bật lại ở lần vào sau
L3153			-- --- trạng thái nội đợt ---
L3175			-- ===== 17: tiêu stamina cho Sprint / Dash / Slide =====
L3182			-- ===== 14: Air Dash (lao trên không) =====
L3206			-- ===== 15: Slide (trượt) =====
L3234			-- thanh stamina: tạo khi bật, hủy khi tắt
L3240				-- [5] thanh stamina trên mobile nhích lên trên nút ảo jump của game
L3268			-- nút ảo mobile: Crouch / Slide / Air Dash (cao 46px >= 36px)
L3271				-- [9] vị trí có thể bị driver dịch trái khi FlyPad hiện (set lại mỗi frame ở dưới)
L3319			-- nút ảo mobile cho Free Cam (6 nút, cùng vị trí với MovePad)
L3372			-- ===== driver movement: chạy MỖI frame, sau driver v4.0, trước vòng lặp chính =====
L3384				-- ===== 17: thanh stamina =====
L3417				-- ===== SpeedBonus: CHỈ CỘNG thêm, không bao giờ ghi đè hum.WalkSpeed =====
L3440				-- nếu driver v4.0 không chạy (lỗi) thì tự reset, tránh cộng dồn mỗi frame
L3445				-- ===== 26: giới hạn tốc độ rơi =====
L3453				-- ===== 4: Hover cho phép đi ngang =====
L3469				-- ===== 9: Air Control =====
L3483				-- ===== 34: khi Free Cam bật thì nhân vật đứng yên =====
L3489				-- ===== 41 + 18 + 15: camera offset (lưu giá trị gốc, khôi phục khi tắt) =====
L3510				-- ===== nút ảo mobile =====
L3520				-- [9] FlyPad nằm ở (1,-16 / 0.55); MovePad/FreePad góc dưới phải phải dịch trái khi FlyPad hiện
L3529			-- ===== driver camera: chạy trong RenderStep sau camera của game (priority Camera+2) =====
L3534				-- ===== 34: Free Cam =====
L3568				-- ===== 36: Shift Lock (bản client: xoay nhân vật theo hướng camera khi di chuyển) =====
L3583				-- ===== 37 + 38: camera mượt + giảm rung màn hình =====
L3622			-- nhìn bằng chuột phải / kéo touch (chỉ khi Free Cam đang bật)
L3648			-- phím tắt đợt A (bỏ qua khi đang gõ chat / đang rebind)
L3649			-- [1] mọi phím của v4.1 yêu cầu States.Hotkeys VÀ States.ExtraHotkeys đều bật
L3670			-- ===== hàng UI đợt A =====
L3708			-- tooltip cho các row của đợt A (mục 126)
L3725			-- ===== TÍNH NĂNG MỚI: Ultimate ESP (highlight + tag tên/khoảng cách cho player & NPC) =====
L3726			-- client-only: chỉ tạo Highlight/BillboardGui local, không gửi gì lên server
L3733				-- gỡ sạch effect của 1 target (connection + instance)
L3747				-- gỡ toàn bộ khi tắt toggle (đúng quy tắc: Disconnect + Destroy)
L3755				-- target hop le: model co Humanoid va khong phai nhan vat minh
L3765				-- tạo Highlight + BillboardGui tên/khoảng cách cho 1 model
L3797						-- cập nhật tên + khoảng cách mỗi frame; tự gỡ khi model chết/respawn
L3811				-- gắn ESP cho 1 object nếu là target (player khác = xanh, NPC = đỏ)
L3818				-- toggle: quét hiện tại + theo dõi object mới (respawn/spawn)
L3841		-- ==================== ĐỢT B: HUD + Light + Perf + Util ====================
L3843			-- --- key mới ---
L3873			-- tạo / hủy 1 effect trong Lighting (giống EnsureEffect của v4.0)
L3889			-- ===== 103: gửi chat qua TextChatService (KHÔNG dùng Remote) =====
L3890			-- [6] toggle Quick Chat điều khiển thật: tắt thì mọi nút gửi chat/emote báo bật Quick Chat trước
L3908			-- [9] WidgetStack: gom các widget HUD trái vào 1 cột (UIListLayout) dưới nút JH/DASH,
L3909			-- hết chồng lên nhau; từng widget vẫn kéo được và nhớ vị trí trong phiên
L3924			-- đưa 1 widget vào stack (hoặc vị trí đã kéo trước đó); trả về frame để caller giữ tham chiếu
L3936				-- kéo được (chuột + touch); thả thì ghi nhớ vị trí và thoát khỏi stack
L3967			-- ===== 88 / 95: biểu đồ dạng thanh dọc =====
L3975				-- [9] vào WidgetStack thay vì đặt cứng
L4009			-- ===== 90: minimap đơn giản =====
L4045			-- ===== 92: hiển thị phím bấm =====
L4052				-- [9] Keystrokes chỉ dành cho PC: thiết bị touch tự tắt (không có bàn phím)
L4094			-- ===== 93: bộ đếm CPS =====
L4119			-- ===== 104: bánh xe emote =====
L4173			-- ===== 102: lịch sử clipboard =====
L4232			-- bọc Clip5 để mọi copy của v4.1 đều vào lịch sử
L4243			-- ===== 72: Sky preset =====
L4333			-- ===== 80: lưu / tải preset ánh sáng =====
L4390			-- ===== 56: giảm chi tiết mesh =====
L4417			-- ===== 63: đóng băng animation NPC ở xa =====
L4459			-- ===== 65: ẩn GUI nặng của game theo tên =====
L4499			-- một cặp connection duy nhất cho 3 tính năng bật theo toggle
L4530			-- ===== driver của đợt B =====
L4533				-- widget bật/tắt (tạo khi bật, Destroy khi tắt)
L4565				-- 56 / 63 / 65: bật = quét 1 lần + gắn connection; tắt = khôi phục
L4575				-- 92: hiện trạng thái phím mỗi frame
L4578				-- 93: CPS
L4593				-- 88: ping
L4605				-- 95: FPS (frames đã được đếm trong BDriver mỗi frame)
L4616				-- 90: minimap
L4642				-- 77: Sun Rays
L4654				-- 63: quét NPC định kỳ (4 lần/giây, chỉ danh sách NPC đã biết)
L4658			-- ===== hàng UI đợt B =====
L4718			-- tooltip đợt B
L4738		-- ==================== ĐỢT C: UI + Settings ====================
L4740			-- --- key mới (118, 122, 126, 129 + cài đặt) ---
L4747			-- tab Cài đặt mới (thứ 12, nằm cuối thanh tab cuộn)
L4750			-- nhớ phím mặc định TRƯỚC khi nạp file đã lưu (136)
L4754			-- ===== file lưu riêng của v4.1: yêu thích / keybind / ngôn ngữ / auto-start =====
L4765					-- [5] nạp kích thước menu đã lưu (mục 112)
L4789						-- [5] lưu kích thước menu đã kéo (mục 112)
L4797			-- [9] 138: AutoOn chỉ ghi States, việc áp dụng thật chuyển sang LateInit
L4798			-- (sau khi mọi State của cả 4 đợt đã được tạo, kể cả key đợt D)
L4815			-- ===== 118: Theme Sáng (đổi Background/Panel/Text chứ không chỉ accent) =====
L4859			-- ===== 122: icon cho từng tab =====
L4875			-- ===== 137: bảng dịch Việt/Anh (khớp với tên row đã RegisterSearch) =====
L4942				-- v4.1
L4969			-- ===== 137: áp dụng ngôn ngữ cho mọi row (giữ nguyên text gốc trong attribute) =====
L4983			-- force = true khi đổi ngôn ngữ; force = false chỉ sửa lại các row đang hiển thị bản gốc
L4997			-- ===== 126: tooltip giải thích (chuột = hover, touch = giữ 0.45s) =====
L5044			-- ===== 125: Yêu thích - gắn ngôi sao vào MỖI row đã đăng ký =====
L5060							-- ActionBtn: co nút lại, chừa 40px bên trái cho sao
L5064							-- SliderRow: dời label + track sang phải
L5070							-- ToggleBtn
L5100			-- ===== 129: hiệu ứng ripple khi bấm =====
L5157			-- ===== 130: responsive mobile/PC (chạy 4 lần/giây) =====
L5163				-- [5] tôn trọng kích thước người dùng đã kéo: scale chỉ thu khi menu vượt viewport
L5171				-- tab cao >= 36px trên mobile, trang trượt xuống cho khớp
L5179			-- ===== 136: trình chỉnh phím tắt =====
L5207					-- [7] chặn phím hệ thống nguy hiểm (Escape chỉ để hủy)
L5210					-- [7] chống trùng: phím đã dùng cho action khác thì tự hoán đổi
L5226			-- ===== 140: console/log lỗi nội bộ =====
L5257			-- ===== 125: danh sách Yêu thích =====
L5329			-- ===== 133: nhiều profile =====
L5370			-- ===== 135: reset tất cả về mặc định =====
L5410			-- ===== hàng UI đợt C (tab Set) =====
L5464			-- [1] tổng công tắc cho các phím của v4.1 (E/V/P/Z/T/Y/U); cho phép lưu vào file cài đặt
L5509			-- [5] mục 112 giờ LÀM ĐƯỢC: resize cửa sổ menu Jump Hub (không phải cửa sổ game)
L5606			-- [5] mục 112: tay nắm kéo góc dưới phải của Main (chuột + touch), 280x300..560x720
L5648			-- dịch thêm các row mới của v4.1
L5666			-- ===== driver đợt C =====
L5678				-- ActionBtn treen lay lai text goc Anh sau moi lan bam, sua lai 1s/lan
L5697		-- ==================== ĐỢT D: Audio + Fun ====================
L5699			-- --- key mới (141, 142, 144) ---
L5717			-- ===== 141: âm lượng tổng (nhân toàn bộ Sound/AudioEmitter với 1 hệ số) =====
L5720			-- [3] CHỈ xử lý Sound (AudioEmitter không có Volume); property access đều bọc pcall
L5743			-- ===== 142: tắt nhạc nền game (đoán theo tên Sound / SoundGroup) =====
L5775			-- ===== 144: âm click UI (thử nhiều ID, không tải được thì báo Không hỗ trợ) =====
L5814			-- kết nối theo toggle: master/music (sound mới) + click (nút mới)
L5862			-- ===== 103/149: gửi chat (bản riêng của đợt D, vì SendChat của đợt B nằm trong block khác) =====
L5863			-- [8] gộp logic gửi chat + emote vào 1 chỗ; ưu tiên Humanoid:PlayEmote trước khi gửi /e qua chat
L5878			-- [8] PlayEmote: ưu tiên Humanoid:PlayEmote (chạy ngay, không cần chat); không được mới gửi /e qua chat
L5886				-- PlayEmote không chạy (R6 / game không bật emote): fallback qua chat
L5892			-- ===== 150: easter egg (bàn phím + ô nhập cho mobile); [10] mã chữ đổi thành mã bí mật mới =====
L5924			-- [10] chỉ còn 1 mã chữ bí mật (không phân biệt hoa thường, bỏ khoảng trắng 2 đầu); mã cũ đã bỏ
L5934			-- phím tắt đợt D: emote wheel / dance / wave + dãy Konami (dãy Konami KHÔNG phụ thuộc Extra Hotkeys)
L5939				-- [1] phím emote yêu cầu Hotkeys + ExtraHotkeys như các phím khác
L5952			-- ===== hàng UI đợt D =====
L5975			-- ===== driver đợt D =====
L5989		-- ===== 8. vòng lặp của v4.1 =====
L5990		-- Kết nối Ở ĐÂY (sau InstallV4, trước vòng lặp chính) để driver v4.0 đặt SpeedBonus
L5991		-- trước, driver v4.1 cộng thêm sau, rồi vòng lặp chính mới ghi hum.WalkSpeed.
L6039	-- ================= FUNCTIONALITY LOOP =================
L6045	-- Using Heartbeat instead of RenderStepped: some executors/environments throttle or
L6046	-- block RenderStepped from firing for LocalScripts (especially injected/executor-run
L6047	-- scripts, as opposed to scripts placed directly in StarterPlayerScripts), which is
L6048	-- what caused every feature - FPS counter, toggles, tab switching animations, all of
L6049	-- which are driven from this single loop - to silently do nothing. Heartbeat runs on
L6050	-- the physics step instead of the render step and is far more consistently available.
L6079				-- NoClip turned off: give back collision to exactly the parts we disabled
L6086			-- Fly: create/destroy the BodyVelocity+BodyGyro pair only on state change
L6096			-- Hover: hold position in mid-air (paused while Fly is active)
L6107			-- Auto Walk: keep moving forward relative to the camera
L6112			-- Anti Fall Damage: cap the downward fall speed (skipped while Fly is on)
L6123			-- Auto Jump: triggers a jump automatically whenever grounded, on a short
L6124			-- interval so it doesn't spam ChangeState every single frame
L6134		-- FPS/ping counter (no blocking Wait())
L6148		-- Power Saver (formerly "Cap Frame Rate"): Roblox does not expose a script API to
L6149		-- force a hard framerate cap - RenderStepped firing less often does NOT stop the
L6150		-- engine from rendering frames underneath it. What this toggle actually does instead
L6151		-- is throttle the UI's OWN cosmetic work (glow animation, FPS-color updates) down to
L6152		-- ~10 updates/sec instead of every frame, freeing a small amount of CPU/battery on
L6153		-- weaker mobile devices. It won't raise your in-game FPS ceiling, but it reduces the
L6154		-- hub's own overhead to close to zero.
