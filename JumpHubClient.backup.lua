-- Jump Hub v4.0 (v3.3 + Cam/HUD/Light/Util/Fun/UI tabs, scrolling tab bar, movement + FPS extras)
-- Pure client-side LocalScript. No remotes, no server dependency, no admin/kick code.

print("[JumpHub] script started")

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Player = Players.LocalPlayer
print("[JumpHub] services + LocalPlayer OK")

-- Cache original settings so "Restore Graphics" can undo everything cleanly.
-- Wrapped in pcall: some executors/games block settings() or certain properties,
-- and an unhandled error here would kill the whole script before the UI is even built.
local OriginalGraphics = {
	FogEnd = Lighting.FogEnd,
	FogStart = Lighting.FogStart,
	GlobalShadows = Lighting.GlobalShadows,
	Brightness = Lighting.Brightness,
	QualityLevel = Enum.QualityLevel.Automatic,
	StreamingTargetRadius = 1024,
}

pcall(function()
	OriginalGraphics.QualityLevel = settings().Rendering.QualityLevel
end)
pcall(function()
	OriginalGraphics.StreamingTargetRadius = workspace.StreamingTargetRadius
end)
print("[JumpHub] OriginalGraphics cached OK")

-- ================= THEME =================
local Theme = {
	Background = Color3.fromRGB(18, 18, 24),
	Panel      = Color3.fromRGB(24, 24, 32),
	Accent     = Color3.fromRGB(140, 80, 255),   -- neon purple
	AccentAlt  = Color3.fromRGB(70, 180, 255),   -- neon blue
	Text       = Color3.fromRGB(235, 235, 245),
	SubText    = Color3.fromRGB(150, 150, 165),
	On         = Color3.fromRGB(90, 220, 160),
	Off        = Color3.fromRGB(60, 60, 72),
	Danger     = Color3.fromRGB(255, 80, 100),
}

local function tween(obj, props, time)
	TweenService:Create(obj, TweenInfo.new(time or 0.18, Enum.EasingStyle.Quad), props):Play()
end

-- ================= STATE =================
local States = {
	InfiniteJump = false, DoubleJump = false, NoClip = false, Spin = false,
	AutoJump = false, Fly = false, SpeedClimb = false, HoverAir = false,
	-- Graphics / performance toggles
	LowGraphics = false, HideParticles = false, DisableShadows = false,
	ReduceRenderDistance = false, FlatLighting = false,
	DisablePostFX = false, HideOtherPlayers = false,
	ReduceResolution = false, CapFrameRate = false,
	HideNPCs = false,
	-- v3.2 extras
	AntiAFK = false, Fullbright = false, RemoveSky = false, SimplifyWater = false,
	MuteSounds = false, AutoLowGFX = false, Hotkeys = true,
	-- v3.3
	AutoWalk = false, AntiFall = false, ClickTP = false, DashButton = false,
	LagWarn = false, DistanceCull = false, RemoveFX = false, LightsOff = false,
	BatterySaver = false,
}

local OriginalGravity = workspace.Gravity
local OriginalFOV = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70

-- Slider-driven values (not simple on/off)
local Sliders = {
	WalkSpeed = 16,   -- Roblox default
	JumpPower = 50,   -- Roblox default
	FlySpeed = 50,
	Gravity = math.floor(OriginalGravity + 0.5),
	FOV = math.floor(OriginalFOV + 0.5),
	AutoFPS = 30,     -- Auto Low-GFX trigger threshold
	DashPower = 120,
	CullDist = 200,   -- Distance Cull radius (studs)
}
local DefaultGravity, DefaultFOV = Sliders.Gravity, Sliders.FOV

-- ================= SAVED SETTINGS / THEMES =================
-- Saving needs an executor that exposes writefile/readfile; if it doesn't, everything
-- below silently does nothing and the hub just uses its defaults.
local HttpService = game:GetService("HttpService")
local SETTINGS_FILE = "JumpHub_Settings.json"

local Themes = {
	{Name = "Purple", Accent = Color3.fromRGB(140, 80, 255), AccentAlt = Color3.fromRGB(70, 180, 255)},
	{Name = "Red",    Accent = Color3.fromRGB(255, 70, 90),  AccentAlt = Color3.fromRGB(255, 170, 70)},
	{Name = "Green",  Accent = Color3.fromRGB(60, 220, 140), AccentAlt = Color3.fromRGB(70, 200, 255)},
	{Name = "Gold",   Accent = Color3.fromRGB(255, 190, 60), AccentAlt = Color3.fromRGB(255, 120, 60)},
}
local ThemeIndex, MenuScale = 1, 1

-- Movement-type toggles are never auto-restored (you don't want to spawn mid-spin or flying)
local SaveExclude = {
	Fly = true, HoverAir = true, NoClip = true, Spin = true, AutoWalk = true,
	AutoJump = true, ClickTP = true, BatterySaver = true,
}

pcall(function()
	if typeof(isfile) == "function" and typeof(readfile) == "function" and isfile(SETTINGS_FILE) then
		local data = HttpService:JSONDecode(readfile(SETTINGS_FILE))
		for k, v in pairs(data.States or {}) do
			if States[k] ~= nil and type(v) == "boolean" and not SaveExclude[k] then States[k] = v end
		end
		for k, v in pairs(data.Sliders or {}) do
			if Sliders[k] ~= nil and type(v) == "number" then Sliders[k] = v end
		end
		if type(data.ThemeIndex) == "number" and Themes[data.ThemeIndex] then ThemeIndex = data.ThemeIndex end
		if type(data.MenuScale) == "number" then MenuScale = math.clamp(data.MenuScale, 0.7, 1.3) end
	end
end)
Theme.Accent = Themes[ThemeIndex].Accent
Theme.AccentAlt = Themes[ThemeIndex].AccentAlt

local function SaveSettings()
	if typeof(writefile) ~= "function" then return "Executor can't save" end
	local data = {States = {}, Sliders = {}, ThemeIndex = ThemeIndex, MenuScale = MenuScale}
	for k, v in pairs(States) do
		if not SaveExclude[k] then data.States[k] = v end
	end
	for k, v in pairs(Sliders) do data.Sliders[k] = v end
	local ok = pcall(function() writefile(SETTINGS_FILE, HttpService:JSONEncode(data)) end)
	return ok and "Settings saved!" or "Save failed"
end

local function DeleteSettings()
	if typeof(isfile) == "function" and typeof(delfile) == "function" and isfile(SETTINGS_FILE) then
		local ok = pcall(function() delfile(SETTINGS_FILE) end)
		return ok and "Saved settings deleted" or "Delete failed"
	end
	return "Nothing to delete"
end

local Minimized = false
local JumpCount = 0
local ParticleCache = {} -- remembers which ParticleEmitters/Trails/Beams we disabled, to restore them

-- ================= GUI ROOT =================
-- WaitForChild + explicit .Parent assignment (rather than Instance.new's second-arg shorthand)
-- since some executors/environments handle the shorthand inconsistently, which can
-- silently fail to parent the GUI and make it look like "nothing happened".
local PlayerGui = Player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "JumpHub"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 1000 -- render above the host game's own UI so nothing overlaps into our panel
gui.Parent = PlayerGui

local Main = Instance.new("Frame", gui)
Main.Size = UDim2.new(0, 320, 0, 380)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.Position = UDim2.new(0.5, 0, 0.45, 0)
Main.BackgroundColor3 = Theme.Background
Main.Active = true
Main.Draggable = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)
local MainScale = Instance.new("UIScale", Main)
MainScale.Scale = MenuScale

local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Color = Theme.Accent
MainStroke.Thickness = 1.5
MainStroke.Transparency = 0.3

-- ================= TOP BAR =================
local Top = Instance.new("Frame", Main)
Top.Size = UDim2.new(1, 0, 0, 40)
Top.BackgroundColor3 = Theme.Panel
Instance.new("UICorner", Top).CornerRadius = UDim.new(0, 12)

-- mask the bottom corners of Top so it looks flush with Main
local TopMask = Instance.new("Frame", Top)
TopMask.Size = UDim2.new(1, 0, 0, 12)
TopMask.Position = UDim2.new(0, 0, 1, -12)
TopMask.BackgroundColor3 = Theme.Panel
TopMask.BorderSizePixel = 0
TopMask.ZIndex = 0

local AccentBar = Instance.new("Frame", Top)
AccentBar.Size = UDim2.new(0, 4, 0.6, 0)
AccentBar.Position = UDim2.new(0, 10, 0.2, 0)
AccentBar.BackgroundColor3 = Theme.Accent
Instance.new("UICorner", AccentBar).CornerRadius = UDim.new(1, 0)

local Title = Instance.new("TextLabel", Top)
Title.Size = UDim2.new(1, -150, 0, 20)
Title.Position = UDim2.new(0, 22, 0, 2)
Title.Text = "Jump Hub"
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.TextColor3 = Theme.Text

local SubTitle = Instance.new("TextLabel", Top)
SubTitle.Size = UDim2.new(1, -150, 0, 14)
SubTitle.Position = UDim2.new(0, 22, 0, 20)
SubTitle.Text = "FPS: -- | -- ms"
SubTitle.TextXAlignment = Enum.TextXAlignment.Left
SubTitle.BackgroundTransparency = 1
SubTitle.Font = Enum.Font.Gotham
SubTitle.TextSize = 11
SubTitle.TextColor3 = Theme.SubText

local function TopBtn(txt, x, color)
	local b = Instance.new("TextButton", Top)
	b.Size = UDim2.new(0, 30, 0, 30)
	b.Position = UDim2.new(1, x, 0.5, -15)
	b.Text = txt
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.TextColor3 = Theme.Text
	b.BackgroundColor3 = Theme.Off
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)

	-- Hover feedback (MouseEnter/Leave) only fires for mouse users - on touch devices
	-- there's no hover state, so InputBegan/InputEnded give the same visual feedback
	-- for a finger tap as MouseEnter/Leave gives a cursor, ensuring taps feel responsive.
	local restColor = Theme.Off
	local hoverColor = color or Theme.Accent

	b.MouseEnter:Connect(function() tween(b, {BackgroundColor3 = hoverColor}, 0.12) end)
	b.MouseLeave:Connect(function() tween(b, {BackgroundColor3 = restColor}, 0.12) end)

	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			tween(b, {BackgroundColor3 = hoverColor}, 0.08)
		end
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			tween(b, {BackgroundColor3 = restColor}, 0.15)
		end
	end)

	return b
end

-- Using plain ASCII-safe characters instead of "-"/"X": some mobile fonts/executors
-- fail to render those glyphs and show a blank box instead, which is what made these
-- buttons look "broken" even though the click handlers underneath were working fine.
local MinBtn = TopBtn("-", -66, Theme.AccentAlt)
local CloseBtn = TopBtn("X", -32, Theme.Danger)

-- ================= TAB BAR (horizontal, restored from the earlier working version) =================
local TabBar = Instance.new("Frame", Main)
TabBar.Size = UDim2.new(1, -20, 0, 34)
TabBar.Position = UDim2.new(0, 10, 0, 50)
TabBar.BackgroundTransparency = 1

local TabList = Instance.new("UIListLayout", TabBar)
TabList.FillDirection = Enum.FillDirection.Horizontal
TabList.Padding = UDim.new(0, 6)
TabList.SortOrder = Enum.SortOrder.LayoutOrder

-- Plain emoji-free text labels for tabs - simplest possible version to rule out
-- any icon/image loading logic as a source of trouble.
local function CreateTab(name, order)
	local b = Instance.new("TextButton")
	b.Text = name
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 11
	b.TextColor3 = Theme.SubText
	b.BackgroundColor3 = Theme.Panel
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.LayoutOrder = order
	b.Parent = TabBar
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	return b
end

-- 5 tabs: Move, Player, Misc, FPS, Find (search)
local Tab1 = CreateTab("Move", 1)
local Tab2 = CreateTab("Player", 2)
local Tab3 = CreateTab("Misc", 3)
local Tab4 = CreateTab("FPS", 4)
local Tab5 = CreateTab("Find", 5)
print("[JumpHub] 5 tabs created")

local AllTabs = {Tab1, Tab2, Tab3, Tab4, Tab5}
for _, t in ipairs(AllTabs) do
	t.Size = UDim2.new(1 / #AllTabs, -5, 1, 0)
end

-- ================= CONTENT PAGES =================
local function NewPage()
	local f = Instance.new("ScrollingFrame")
	f.Size = UDim2.new(1, -20, 1, -96)
	f.Position = UDim2.new(0, 10, 0, 92)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.ScrollBarThickness = 3
	f.ScrollBarImageColor3 = Theme.Accent
	f.CanvasSize = UDim2.new(0, 0, 0, 0)
	f.AutomaticCanvasSize = Enum.AutomaticSize.Y
	f.Parent = Main

	local layout = Instance.new("UIListLayout", f)
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	return f
end

local Page1, Page2, Page3, Page4, Page5 = NewPage(), NewPage(), NewPage(), NewPage(), NewPage()
local Pages = {Page1, Page2, Page3, Page4, Page5}
local TabPageMap = {[Tab1] = Page1, [Tab2] = Page2, [Tab3] = Page3, [Tab4] = Page4, [Tab5] = Page5}
print("[JumpHub] 5 pages created OK")

local CurrentPage = Page1
local RunSearch, RestoreSearchRows -- assigned once the search registry exists (below)

local function Show(target)
	CurrentPage = target
	for _, p in ipairs(Pages) do p.Visible = (p == target) end
	for tab, page in pairs(TabPageMap) do
		local active = (page == target)
		tween(tab, {BackgroundColor3 = active and Theme.Accent or Theme.Panel})
		tab.TextColor3 = active and Theme.Text or Theme.SubText
	end
	-- Search results are real rows borrowed from the other pages: borrow while on "Find",
	-- hand them back as soon as any other tab is opened.
	if target == Page5 then
		if RunSearch then RunSearch() end
	elseif RestoreSearchRows then
		RestoreSearchRows()
	end
end

for tab, page in pairs(TabPageMap) do
	tab.MouseButton1Click:Connect(function()
		print("[JumpHub] tab clicked:", tab.Text)
		Show(page)
	end)
end
Show(Page1)
print("[JumpHub] UI fully built, Show(Page1) called")

-- ================= TOGGLE BUTTON CREATOR =================
local ToggleRefreshers = {} -- stateKey -> refresh function, so Restore/reset buttons can sync switch visuals
local BatteryPrev = {}     -- values remembered by Battery Saver so turning it off restores them

-- Search registry: every row (toggle/slider/button) registers itself so the "Find" tab
-- can borrow matching rows and give them back afterwards.
local SearchRegistry = {}
local function RegisterSearch(row, name, home)
	table.insert(SearchRegistry, {row = row, name = tostring(name):lower(), home = home})
end

local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(1, 0, 0, 36)
SearchBox.LayoutOrder = -100
SearchBox.BackgroundColor3 = Theme.Panel
SearchBox.BorderSizePixel = 0
SearchBox.PlaceholderText = "Type a feature name..."
SearchBox.PlaceholderColor3 = Theme.SubText
SearchBox.Text = ""
SearchBox.ClearTextOnFocus = false
SearchBox.Font = Enum.Font.GothamMedium
SearchBox.TextSize = 13
SearchBox.TextColor3 = Theme.Text
SearchBox.Parent = Page5
Instance.new("UICorner", SearchBox).CornerRadius = UDim.new(0, 8)

RestoreSearchRows = function()
	for _, e in ipairs(SearchRegistry) do
		if e.row.Parent ~= e.home then e.row.Parent = e.home end
	end
end

RunSearch = function()
	local q = SearchBox.Text:lower()
	for _, e in ipairs(SearchRegistry) do
		local hit = q ~= "" and e.name:find(q, 1, true) ~= nil
		local target = hit and Page5 or e.home
		if e.row.Parent ~= target then e.row.Parent = target end
	end
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
	if CurrentPage == Page5 then RunSearch() end
end)

local function ToggleBtn(parent, label, stateKey, order)
	local row = Instance.new("Frame", parent)
	row.Size = UDim2.new(1, 0, 0, 40)
	row.BackgroundColor3 = Theme.Panel
	row.LayoutOrder = order
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

	local lbl = Instance.new("TextLabel", row)
	lbl.Size = UDim2.new(1, -70, 1, 0)
	lbl.Position = UDim2.new(0, 14, 0, 0)
	lbl.Text = label
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextSize = 13
	lbl.TextColor3 = Theme.Text
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.BackgroundTransparency = 1

	local switch = Instance.new("TextButton", row)
	switch.Size = UDim2.new(0, 46, 0, 24)
	switch.Position = UDim2.new(1, -58, 0.5, -12)
	switch.Text = ""
	switch.BackgroundColor3 = Theme.Off
	switch.BorderSizePixel = 0
	switch.AutoButtonColor = false
	Instance.new("UICorner", switch).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame", switch)
	knob.Size = UDim2.new(0, 18, 0, 18)
	knob.Position = UDim2.new(0, 3, 0.5, -9)
	knob.BackgroundColor3 = Theme.Text
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local function refresh()
		local on = States[stateKey]
		tween(switch, {BackgroundColor3 = on and Theme.Accent or Theme.Off})
		tween(knob, {Position = on and UDim2.new(0, 25, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)})
	end

	switch.MouseButton1Click:Connect(function()
		States[stateKey] = not States[stateKey]
		refresh()
	end)

	refresh()
	ToggleRefreshers[stateKey] = refresh
	RegisterSearch(row, label, parent)
	return row
end

-- ================= SLIDER CREATOR =================
-- Horizontal drag slider. min/max define the value range; sliderKey indexes into `Sliders`.
local function SliderRow(parent, label, sliderKey, min, max, order)
	local row = Instance.new("Frame", parent)
	Sliders[sliderKey] = math.clamp(Sliders[sliderKey], min, max) -- saved values can be out of range
	row.Size = UDim2.new(1, 0, 0, 58)
	row.BackgroundColor3 = Theme.Panel
	row.LayoutOrder = order
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

	local lbl = Instance.new("TextLabel", row)
	lbl.Size = UDim2.new(1, -70, 0, 24)
	lbl.Position = UDim2.new(0, 14, 0, 4)
	lbl.Text = label
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextSize = 13
	lbl.TextColor3 = Theme.Text
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.BackgroundTransparency = 1

	local valueLbl = Instance.new("TextLabel", row)
	valueLbl.Size = UDim2.new(0, 60, 0, 24)
	valueLbl.Position = UDim2.new(1, -70, 0, 4)
	valueLbl.Text = tostring(Sliders[sliderKey])
	valueLbl.Font = Enum.Font.GothamBold
	valueLbl.TextSize = 13
	valueLbl.TextColor3 = Theme.AccentAlt
	valueLbl.TextXAlignment = Enum.TextXAlignment.Right
	valueLbl.BackgroundTransparency = 1

	local track = Instance.new("Frame", row)
	track.Size = UDim2.new(1, -28, 0, 6)
	track.Position = UDim2.new(0, 14, 0, 38)
	track.BackgroundColor3 = Theme.Off
	track.BorderSizePixel = 0
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	local fill = Instance.new("Frame", track)
	fill.BackgroundColor3 = Theme.Accent
	fill.BorderSizePixel = 0
	fill.Size = UDim2.new((Sliders[sliderKey] - min) / (max - min), 0, 1, 0)
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame", track)
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new((Sliders[sliderKey] - min) / (max - min), 0, 0.5, 0)
	knob.BackgroundColor3 = Theme.Text
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
	local knobStroke = Instance.new("UIStroke", knob)
	knobStroke.Color = Theme.Accent
	knobStroke.Thickness = 2

	local dragging = false

	local function setFromAlpha(alpha)
		alpha = math.clamp(alpha, 0, 1)
		local value = math.floor(min + (max - min) * alpha + 0.5)
		Sliders[sliderKey] = value
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		valueLbl.Text = tostring(value)
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			local alpha = (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
			setFromAlpha(alpha)
		end
	end)

	UIS.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local alpha = (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
			setFromAlpha(alpha)
		end
	end)

	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	RegisterSearch(row, label, parent)
	return row
end

-- ================= ACTION BUTTON CREATOR =================
-- One-shot button (not a toggle). The callback may return a string to flash as feedback.
local function ActionBtn(parent, text, order, callback)
	local row = Instance.new("Frame", parent)
	row.Size = UDim2.new(1, 0, 0, 40)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order

	local b = Instance.new("TextButton", row)
	b.Size = UDim2.new(1, 0, 1, 0)
	b.Text = text
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 13
	b.TextColor3 = Theme.Text
	b.BackgroundColor3 = Theme.Panel
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)

	b.MouseButton1Click:Connect(function()
		tween(b, {BackgroundColor3 = Theme.Accent}, 0.08)
		task.delay(0.15, function()
			if b.Parent then tween(b, {BackgroundColor3 = Theme.Panel}, 0.2) end
		end)
		local ok, msg = pcall(callback)
		if ok and type(msg) == "string" then
			b.Text = msg
			task.delay(1.2, function()
				if b.Parent then b.Text = text end
			end)
		end
	end)
	RegisterSearch(row, text, parent)
	return row
end

-- PAGE 1: Movement
ToggleBtn(Page1, "Infinite Jump", "InfiniteJump", 1)
ToggleBtn(Page1, "Double Jump", "DoubleJump", 2)
ToggleBtn(Page1, "Auto Jump", "AutoJump", 3)
SliderRow(Page1, "Jump Power", "JumpPower", 50, 250, 4)
SliderRow(Page1, "Walk Speed", "WalkSpeed", 16, 200, 5)
SliderRow(Page1, "Gravity", "Gravity", 0, math.max(400, Sliders.Gravity), 6)

-- PAGE 2: Player
ToggleBtn(Page2, "No Clip", "NoClip", 1)
ToggleBtn(Page2, "Fly", "Fly", 2)
SliderRow(Page2, "Fly Speed", "FlySpeed", 20, 150, 3)
ToggleBtn(Page2, "Speed Climb", "SpeedClimb", 4)
ToggleBtn(Page2, "Hover (Stand in Air)", "HoverAir", 5)
-- (teleport slots + more Player-page rows are built at the end of the script)

-- PAGE 3: Misc
ToggleBtn(Page3, "Spin", "Spin", 1)
ToggleBtn(Page3, "Anti-AFK", "AntiAFK", 2)
ToggleBtn(Page3, "Fullbright", "Fullbright", 3)
SliderRow(Page3, "Field of View", "FOV", 40, 120, 4)
ToggleBtn(Page3, "Hotkeys", "Hotkeys", 5)
do
	local hint = Instance.new("TextLabel", Page3)
	hint.Size = UDim2.new(1, 0, 0, 40)
	hint.LayoutOrder = 6
	hint.BackgroundTransparency = 1
	hint.Text = "Hotkeys: F = Fly | H = Hover | N = NoClip | Q = Dash | RightShift = Hide/Show menu"
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 11
	hint.TextWrapped = true
	hint.TextColor3 = Theme.SubText
end

-- PAGE 4: Graphics / Performance
ToggleBtn(Page4, "Low Graphics Mode", "LowGraphics", 1)
ToggleBtn(Page4, "Disable Shadows", "DisableShadows", 2)
ToggleBtn(Page4, "Hide Particles/Trails", "HideParticles", 3)
ToggleBtn(Page4, "Reduce Render Distance", "ReduceRenderDistance", 4)
ToggleBtn(Page4, "Flat Lighting (no fog)", "FlatLighting", 5)
ToggleBtn(Page4, "Disable Post-Processing", "DisablePostFX", 6)
ToggleBtn(Page4, "Hide Other Players", "HideOtherPlayers", 7)
ToggleBtn(Page4, "Reduce Resolution (Mobile)", "ReduceResolution", 8)
ToggleBtn(Page4, "Cap Frame Rate (30)", "CapFrameRate", 9)
ToggleBtn(Page4, "Hide NPCs/Bots (Anti-Lag)", "HideNPCs", 10)
ToggleBtn(Page4, "Auto Low-GFX when FPS is low", "AutoLowGFX", 11)
SliderRow(Page4, "Auto Threshold (FPS)", "AutoFPS", 15, 60, 12)
ToggleBtn(Page4, "Remove Clouds/Atmosphere", "RemoveSky", 13)
ToggleBtn(Page4, "Simplify Water", "SimplifyWater", 14)
ToggleBtn(Page4, "Mute All Game Sounds", "MuteSounds", 15)
ToggleBtn(Page4, "Battery Saver (all-in-one)", "BatterySaver", 0)
ToggleBtn(Page4, "Distance Cull (hide far parts)", "DistanceCull", 16)
SliderRow(Page4, "Cull Distance (studs)", "CullDist", 50, 500, 17)
ToggleBtn(Page4, "Remove Fire/Smoke/Sparkles", "RemoveFX", 18)
ToggleBtn(Page4, "Disable Dynamic Lights", "LightsOff", 19)

do
	local restoreRow = Instance.new("Frame", Page4)
	restoreRow.Size = UDim2.new(1, 0, 0, 36)
	restoreRow.BackgroundTransparency = 1
	restoreRow.LayoutOrder = 99

	local restoreBtn = Instance.new("TextButton", restoreRow)
	restoreBtn.Size = UDim2.new(1, 0, 1, 0)
	restoreBtn.Text = "Restore Default Graphics"
	restoreBtn.Font = Enum.Font.GothamBold
	restoreBtn.TextSize = 13
	restoreBtn.TextColor3 = Theme.Text
	restoreBtn.BackgroundColor3 = Theme.AccentAlt
	restoreBtn.BorderSizePixel = 0
	restoreBtn.AutoButtonColor = false
	Instance.new("UICorner", restoreBtn).CornerRadius = UDim.new(0, 8)

	restoreBtn.MouseButton1Click:Connect(function()
		table.clear(BatteryPrev)
		for _, key in ipairs({
			"LowGraphics", "DisableShadows", "HideParticles",
			"ReduceRenderDistance", "FlatLighting", "DisablePostFX", "HideOtherPlayers",
			"ReduceResolution", "CapFrameRate", "HideNPCs",
			"Fullbright", "RemoveSky", "SimplifyWater", "MuteSounds",
			"DistanceCull", "RemoveFX", "LightsOff", "BatterySaver",
		}) do
			States[key] = false
			if ToggleRefreshers[key] then ToggleRefreshers[key]() end
		end
	end)
end

-- ================= TOP BUTTON ACTIONS =================
-- X now HIDES the menu instead of destroying it, so the floating "JH" button can
-- bring it back. All running features (FPS boosts etc.) keep working either way.
local function SetMenuVisible(v)
	Main.Visible = v
end

CloseBtn.MouseButton1Click:Connect(function()
	SetMenuVisible(false)
end)

-- Floating popup button (separate ScreenGui so it stays visible when the menu is hidden)
local ToggleGui = Instance.new("ScreenGui")
ToggleGui.Name = "JumpHubToggle"
ToggleGui.ResetOnSpawn = false
ToggleGui.DisplayOrder = 1001
ToggleGui.Parent = PlayerGui

local FloatBtn = Instance.new("TextButton")
FloatBtn.Size = UDim2.new(0, 44, 0, 44)
FloatBtn.Position = UDim2.new(0, 12, 0.35, 0)
FloatBtn.Text = "JH"
FloatBtn.Font = Enum.Font.GothamBold
FloatBtn.TextSize = 14
FloatBtn.TextColor3 = Theme.Text
FloatBtn.BackgroundColor3 = Theme.Panel
FloatBtn.BackgroundTransparency = 0.15
FloatBtn.BorderSizePixel = 0
FloatBtn.AutoButtonColor = false
FloatBtn.Active = true
FloatBtn.Draggable = true
FloatBtn.Parent = ToggleGui
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(1, 0)
local FloatStroke = Instance.new("UIStroke", FloatBtn)
FloatStroke.Color = Theme.Accent
FloatStroke.Thickness = 2

FloatBtn.MouseButton1Click:Connect(function()
	SetMenuVisible(not Main.Visible)
end)

MinBtn.MouseButton1Click:Connect(function()
	Minimized = not Minimized
	TabBar.Visible = not Minimized
	for _, p in ipairs(Pages) do p.Visible = false end
	if not Minimized then Show(Page1) end
	tween(Main, {Size = Minimized and UDim2.new(0, 320, 0, 42) or UDim2.new(0, 320, 0, 380)}, 0.22)
end)

-- ================= GRAPHICS APPLY LOGIC =================
-- Applied only when a toggle actually changes state, not every frame, to avoid wasted work.
-- These settings work in ANY game since they touch client-global rendering/Lighting/workspace
-- properties rather than anything game-specific.
local LastGraphicsState = {}
local HiddenPlayerCache = {} -- BasePart -> original LocalTransparencyModifier owner tracking

local function ScanAndSetInstanceGraphics(lowGraphics)
	-- Iterates the whole workspace once per toggle flip (not per-frame) to reduce
	-- part/texture/decal rendering cost. Safe for any game since it only touches
	-- generic rendering properties, never gameplay logic.
	for _, v in ipairs(workspace:GetDescendants()) do
		if v:IsA("BasePart") then
			if lowGraphics then
				if v.Material ~= Enum.Material.SmoothPlastic and v:GetAttribute("_JH_OrigMaterial") == nil then
					v:SetAttribute("_JH_OrigMaterial", v.Material.Name)
					v.Material = Enum.Material.SmoothPlastic
				end
			else
				local orig = v:GetAttribute("_JH_OrigMaterial")
				if orig then
					v.Material = Enum.Material[orig]
					v:SetAttribute("_JH_OrigMaterial", nil)
				end
			end
		elseif v:IsA("Decal") or v:IsA("Texture") then
			if lowGraphics then
				if v:GetAttribute("_JH_OrigTransparency") == nil then
					v:SetAttribute("_JH_OrigTransparency", v.Transparency)
					v.Transparency = 1
				end
			else
				local orig = v:GetAttribute("_JH_OrigTransparency")
				if orig ~= nil then
					v.Transparency = orig
					v:SetAttribute("_JH_OrigTransparency", nil)
				end
			end
		end
	end
end

-- Disables the heaviest Lighting post-processing effects (Bloom, SunRays, DepthOfField,
-- ColorCorrection blur-like effects). These run a full-screen shader pass every frame
-- regardless of scene complexity, so turning them off is one of the biggest single FPS wins
-- available client-side, in any game.
local function SetPostProcessingEnabled(enabled)
	for _, v in ipairs(Lighting:GetChildren()) do
		if v:IsA("BloomEffect") or v:IsA("SunRaysEffect") or v:IsA("DepthOfFieldEffect")
			or v:IsA("BlurEffect") or v:IsA("ColorCorrectionEffect") then
			if not enabled then
				if v:GetAttribute("_JH_WasEnabled") == nil then
					v:SetAttribute("_JH_WasEnabled", v.Enabled)
				end
				v.Enabled = false
			else
				local was = v:GetAttribute("_JH_WasEnabled")
				if was ~= nil then
					v.Enabled = was
					v:SetAttribute("_JH_WasEnabled", nil)
				end
			end
		end
	end
end

-- Hides every other player's character model. In crowded servers, rendering other
-- players (meshes, accessories, materials, animations) is often the single biggest
-- FPS cost - bigger than map geometry. This only affects YOUR client's rendering,
-- nobody else is impacted and nothing is sent to the server.
local function SetOtherPlayersVisible(visible)
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= Player then
			local char = plr.Character
			if char then
				for _, v in ipairs(char:GetDescendants()) do
					if v:IsA("BasePart") or v:IsA("Decal") then
						if not visible then
							if v:GetAttribute("_JH_OrigTransparency") == nil then
								v:SetAttribute("_JH_OrigTransparency", v.Transparency)
							end
							v.LocalTransparencyModifier = 1
						else
							v.LocalTransparencyModifier = 0
						end
					end
				end
			end
		end
	end
end

-- Hide NPCs/Bots (client-side only): any Model with a Humanoid that is NOT a player
-- character. It cannot kill bots on the server (the server still runs them), but it stops
-- YOUR client from rendering/animating them, which is where most NPC-related FPS loss is.
local NPCCache = {} -- Model -> true for every NPC we've hidden

local function IsNPC(model)
	if not model:IsA("Model") then return false end
	if not model:FindFirstChildOfClass("Humanoid") then return false end
	return Players:GetPlayerFromCharacter(model) == nil
end

local function SetNPCHidden(model, hidden)
	for _, v in ipairs(model:GetDescendants()) do
		if v:IsA("BasePart") or v:IsA("Decal") then
			v.LocalTransparencyModifier = hidden and 1 or 0
		elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then
			if hidden then
				if v.Enabled then v:SetAttribute("_JH_NPCWasEnabled", true); v.Enabled = false end
			elseif v:GetAttribute("_JH_NPCWasEnabled") then
				v.Enabled = true
				v:SetAttribute("_JH_NPCWasEnabled", nil)
			end
		end
	end
	if hidden then
		-- Stop animation playback on this client to save CPU
		local animator = model:FindFirstChildWhichIsA("Animator", true)
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				pcall(function() track:Stop(0) end)
			end
		end
	end
end

local function SetAllNPCsHidden(hidden)
	if hidden then
		for _, v in ipairs(workspace:GetDescendants()) do
			if v:IsA("Humanoid") and v.Parent and IsNPC(v.Parent) then
				NPCCache[v.Parent] = true
				SetNPCHidden(v.Parent, true)
			end
		end
	else
		for model in pairs(NPCCache) do
			if model and model.Parent then SetNPCHidden(model, false) end
		end
		table.clear(NPCCache)
	end
end

-- Newly spawned NPCs get hidden automatically while the toggle is on
workspace.DescendantAdded:Connect(function(v)
	if not States.HideNPCs or not v:IsA("Humanoid") then return end
	task.defer(function()
		local model = v.Parent
		if model and IsNPC(model) then
			NPCCache[model] = true
			SetNPCHidden(model, true)
		end
	end)
end)

-- Re-apply periodically so NPCs that restart animations or re-enable parts stay hidden
local lastNPCSweep = 0
local function SweepNPCs()
	if not States.HideNPCs then return end
	local now = tick()
	if now - lastNPCSweep < 1 then return end
	lastNPCSweep = now
	for model in pairs(NPCCache) do
		if model and model.Parent then
			SetNPCHidden(model, true)
		else
			NPCCache[model] = nil
		end
	end
end

local function ApplyGraphicsSettings()
	SweepNPCs()

	-- Hide NPCs/Bots - removes the render + animation cost of every non-player character
	if States.HideNPCs ~= LastGraphicsState.HideNPCs then
		task.spawn(SetAllNPCsHidden, States.HideNPCs)
		LastGraphicsState.HideNPCs = States.HideNPCs
	end

	-- Low Graphics Mode: master switch - drops renderer quality + strips materials/decals workspace-wide
	if States.LowGraphics ~= LastGraphicsState.LowGraphics then
		pcall(function()
			settings().Rendering.QualityLevel = States.LowGraphics
				and Enum.QualityLevel.Level01
				or OriginalGraphics.QualityLevel
		end)
		task.spawn(ScanAndSetInstanceGraphics, States.LowGraphics)
		LastGraphicsState.LowGraphics = States.LowGraphics
	end

	-- Disable Shadows
	if States.DisableShadows ~= LastGraphicsState.DisableShadows then
		Lighting.GlobalShadows = not States.DisableShadows and OriginalGraphics.GlobalShadows or false
		LastGraphicsState.DisableShadows = States.DisableShadows
	end

	-- Flat Lighting (kills fog, a common FPS drain outdoors in any game)
	if States.FlatLighting ~= LastGraphicsState.FlatLighting then
		if States.FlatLighting then
			Lighting.FogEnd = 100000
			Lighting.FogStart = 0
		else
			Lighting.FogEnd = OriginalGraphics.FogEnd
			Lighting.FogStart = OriginalGraphics.FogStart
		end
		LastGraphicsState.FlatLighting = States.FlatLighting
	end

	-- Reduce Render Distance (streaming target radius - works in any game with StreamingEnabled)
	if States.ReduceRenderDistance ~= LastGraphicsState.ReduceRenderDistance then
		pcall(function()
			workspace.StreamingTargetRadius = States.ReduceRenderDistance
				and 128
				or OriginalGraphics.StreamingTargetRadius
		end)
		LastGraphicsState.ReduceRenderDistance = States.ReduceRenderDistance
	end

	-- Hide Particles/Trails/Beams: scans workspace once per toggle flip, not every frame
	if States.HideParticles ~= LastGraphicsState.HideParticles then
		if States.HideParticles then
			table.clear(ParticleCache)
			for _, v in ipairs(workspace:GetDescendants()) do
				if (v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")) and v.Enabled then
					ParticleCache[v] = true
					v.Enabled = false
				end
			end
		else
			for v in pairs(ParticleCache) do
				if v and v.Parent then v.Enabled = true end
			end
			table.clear(ParticleCache)
		end
		LastGraphicsState.HideParticles = States.HideParticles
	end

	-- Disable Post-Processing (Bloom/SunRays/DoF/Blur/ColorCorrection) - big single win
	if States.DisablePostFX ~= LastGraphicsState.DisablePostFX then
		SetPostProcessingEnabled(not States.DisablePostFX)
		LastGraphicsState.DisablePostFX = States.DisablePostFX
	end

	-- Hide Other Players - usually the single biggest FPS win in crowded servers
	if States.HideOtherPlayers ~= LastGraphicsState.HideOtherPlayers then
		SetOtherPlayersVisible(not States.HideOtherPlayers)
		LastGraphicsState.HideOtherPlayers = States.HideOtherPlayers
	end

	-- Reduce Resolution (mobile-focused): forces the lowest QualityLevel, which on most
	-- phones/tablets also lowers the internal render resolution scale (not just texture
	-- detail). There is no direct "set resolution %" API exposed to scripts - this is the
	-- closest legitimate lever available client-side.
	if States.ReduceResolution ~= LastGraphicsState.ReduceResolution then
		pcall(function()
			settings().Rendering.QualityLevel = States.ReduceResolution
				and Enum.QualityLevel.Level01
				or (States.LowGraphics and Enum.QualityLevel.Level01 or OriginalGraphics.QualityLevel)
		end)
		LastGraphicsState.ReduceResolution = States.ReduceResolution
	end
end

-- Also apply Low Graphics treatment to any parts/decals that stream in later
workspace.DescendantAdded:Connect(function(v)
	if not States.LowGraphics then return end
	task.defer(function()
		if v:IsA("BasePart") and v:GetAttribute("_JH_OrigMaterial") == nil then
			v:SetAttribute("_JH_OrigMaterial", v.Material.Name)
			v.Material = Enum.Material.SmoothPlastic
		elseif (v:IsA("Decal") or v:IsA("Texture")) and v:GetAttribute("_JH_OrigTransparency") == nil then
			v:SetAttribute("_JH_OrigTransparency", v.Transparency)
			v.Transparency = 1
		elseif States.HideParticles and (v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam")) and v.Enabled then
			ParticleCache[v] = true
			v.Enabled = false
		end
	end)
end)

-- Keep newly spawned/respawned other-player characters hidden if the toggle is on
Players.PlayerAdded:Connect(function(plr)
	if plr == Player then return end
	plr.CharacterAdded:Connect(function(char)
		if States.HideOtherPlayers then
			task.defer(function()
				for _, v in ipairs(char:GetDescendants()) do
					if v:IsA("BasePart") or v:IsA("Decal") then
						v.LocalTransparencyModifier = 1
					end
				end
			end)
		end
	end)
end)
for _, plr in ipairs(Players:GetPlayers()) do
	if plr ~= Player then
		plr.CharacterAdded:Connect(function(char)
			if States.HideOtherPlayers then
				task.defer(function()
					for _, v in ipairs(char:GetDescendants()) do
						if v:IsA("BasePart") or v:IsA("Decal") then
							v.LocalTransparencyModifier = 1
						end
					end
				end)
			end
		end)
	end
end

-- ================= MOBILE FLY CONTROLS =================
-- On touch devices there is no Space/Ctrl, so while Fly is on we show two hold-buttons
-- (UP / DOWN) on the right side of the screen. Horizontal movement uses the normal
-- on-screen joystick (see UpdateFly).
local FlyUpHeld, FlyDownHeld = false, false

local FlyPad = Instance.new("Frame")
FlyPad.Name = "FlyPad"
FlyPad.Size = UDim2.new(0, 64, 0, 132)
FlyPad.AnchorPoint = Vector2.new(1, 0.5)
FlyPad.Position = UDim2.new(1, -16, 0.55, 0)
FlyPad.BackgroundTransparency = 1
FlyPad.Visible = false
FlyPad.Parent = gui

local function PadBtn(text, y, setHeld)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 62)
	b.Position = UDim2.new(0, 0, 0, y)
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = Theme.Text
	b.BackgroundColor3 = Theme.Panel
	b.BackgroundTransparency = 0.2
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 12)
	local st = Instance.new("UIStroke", b)
	st.Color = Theme.Accent
	st.Thickness = 1.5
	b.Parent = FlyPad

	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setHeld(true)
			tween(b, {BackgroundColor3 = Theme.Accent}, 0.08)
		end
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setHeld(false)
			tween(b, {BackgroundColor3 = Theme.Panel}, 0.15)
		end
	end)
end
PadBtn("UP", 0, function(v) FlyUpHeld = v end)
PadBtn("DOWN", 70, function(v) FlyDownHeld = v end)

-- ================= FLY IMPLEMENTATION =================
-- Uses a BodyVelocity so it works consistently across games without touching
-- Humanoid states (keeps animations looking normal-ish and avoids fighting
-- server-side anti-noclip/anti-fly checks that watch CFrame teleporting instead).
local FlyBodyVelocity = nil
local FlyGyro = nil

local function EnableFly(char)
	if FlyBodyVelocity then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	FlyBodyVelocity = Instance.new("BodyVelocity")
	FlyBodyVelocity.MaxForce = Vector3.new(1, 1, 1) * math.huge
	FlyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
	FlyBodyVelocity.Parent = root

	FlyGyro = Instance.new("BodyGyro")
	FlyGyro.MaxTorque = Vector3.new(1, 1, 1) * math.huge
	FlyGyro.P = 3000
	FlyGyro.CFrame = root.CFrame
	FlyGyro.Parent = root

	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.PlatformStand = false end
end

local function DisableFly()
	if FlyBodyVelocity then
		-- keep a bit of momentum so leaving Fly isn't an abrupt stop
		local root = FlyBodyVelocity.Parent
		local keep = FlyBodyVelocity.Velocity
		FlyBodyVelocity:Destroy()
		FlyBodyVelocity = nil
		if root and root.Parent then root.AssemblyLinearVelocity = keep * 0.35 end
	end
	if FlyGyro then FlyGyro:Destroy(); FlyGyro = nil end
	FlyUpHeld, FlyDownHeld = false, false
end

local function UpdateFly(char, dt)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not FlyBodyVelocity then return end

	local cam = workspace.CurrentCamera
	local moveDir = Vector3.new(0, 0, 0)

	-- WASD relative to camera look direction
	local flatLook = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
	if flatLook.Magnitude > 0 then flatLook = flatLook.Unit end
	local flatRight = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z)
	if flatRight.Magnitude > 0 then flatRight = flatRight.Unit end

	if UIS:IsKeyDown(Enum.KeyCode.W) then moveDir += flatLook end
	if UIS:IsKeyDown(Enum.KeyCode.S) then moveDir -= flatLook end
	if UIS:IsKeyDown(Enum.KeyCode.A) then moveDir -= flatRight end
	if UIS:IsKeyDown(Enum.KeyCode.D) then moveDir += flatRight end
	local hum = char:FindFirstChildOfClass("Humanoid")

	-- Mobile/gamepad: no WASD keys are held, so use the joystick direction instead
	-- (Humanoid.MoveDirection is already camera-relative).
	if moveDir.Magnitude == 0 and hum and hum.MoveDirection.Magnitude > 0 then
		moveDir += Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z)
	end

	if UIS:IsKeyDown(Enum.KeyCode.Space) or FlyUpHeld or (hum and hum.Jump) then
		moveDir += Vector3.new(0, 1, 0)
	end
	if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or FlyDownHeld then
		moveDir -= Vector3.new(0, 1, 0)
	end

	if moveDir.Magnitude > 0 then
		moveDir = moveDir.Unit
	end

	FlyBodyVelocity.Velocity = moveDir * Sliders.FlySpeed
	FlyGyro.CFrame = CFrame.new(root.Position, root.Position + cam.CFrame.LookVector)
end

-- ================= HOVER (STAND STILL IN AIR) IMPLEMENTATION =================
-- Freezes the character at its current position in mid-air: a BodyVelocity with zero
-- velocity and infinite force cancels gravity and any drift. Fly takes priority - if Fly
-- is on, Hover is paused (Fly already holds you in place when no keys are pressed).
local HoverBodyVelocity = nil

local function EnableHover(char)
	if HoverBodyVelocity and HoverBodyVelocity.Parent then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	HoverBodyVelocity = Instance.new("BodyVelocity")
	HoverBodyVelocity.Name = "_JH_Hover"
	HoverBodyVelocity.MaxForce = Vector3.new(1, 1, 1) * math.huge
	HoverBodyVelocity.Velocity = Vector3.new(0, 0, 0)
	HoverBodyVelocity.Parent = root

	root.AssemblyLinearVelocity = Vector3.new(0, 0, 0) -- stop instantly, no leftover momentum
end

local function DisableHover()
	if HoverBodyVelocity then
		HoverBodyVelocity:Destroy()
		HoverBodyVelocity = nil
	end
end

-- ================= SPEED CLIMB IMPLEMENTATION =================
-- Detects when the player is pressed against a surface roughly in front of them
-- (via a short raycast) while airborne, and adds upward velocity - mimics a fast
-- wall-climb without needing game-specific ladder/climb logic. Purely additive:
-- if there's nothing to climb, this does nothing.
local function UpdateSpeedClimb(char)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end
	if hum.FloorMaterial ~= Enum.Material.Air then return end -- only assist mid-air/against walls

	local lookDir = root.CFrame.LookVector
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {char}

	local result = workspace:Raycast(root.Position, lookDir * 3, rayParams)
	if result then
		root.AssemblyLinearVelocity = Vector3.new(
			root.AssemblyLinearVelocity.X,
			Sliders.WalkSpeed, -- climb speed scales with your walk speed setting
			root.AssemblyLinearVelocity.Z
		)
	end
end

-- Reset Fly's internal instance references on respawn - the old BodyVelocity/BodyGyro
-- get destroyed along with the old character, so stale references must be cleared or
-- Fly would silently stop working after dying once.
Player.CharacterAdded:Connect(function()
	FlyBodyVelocity = nil
	FlyGyro = nil
	HoverBodyVelocity = nil
end)

-- ================= EXTRA FEATURES (v3.2) =================
local SoundService = game:GetService("SoundService")
local okVU, VirtualUser = pcall(function() return game:GetService("VirtualUser") end)

-- Anti-AFK: when Roblox reports the player as idle, send a harmless fake input
-- so the client is not disconnected for inactivity.
Player.Idled:Connect(function()
	if not States.AntiAFK or not okVU then return end
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new(0, 0))
	end)
end)

-- Hotkeys (ignored while typing in chat/text boxes)
local HotkeyMap = {
	[Enum.KeyCode.F] = "Fly",
	[Enum.KeyCode.H] = "HoverAir",
	[Enum.KeyCode.N] = "NoClip",
}

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

	if input.KeyCode == Enum.KeyCode.RightShift then
		Main.Visible = not Main.Visible
		return
	end

	if not States.Hotkeys then return end
	local key = HotkeyMap[input.KeyCode]
	if key then
		States[key] = not States[key]
		if ToggleRefreshers[key] then ToggleRefreshers[key]() end
	end
end)

-- Fullbright: brighter ambient light, re-applied periodically because many games
-- reset Lighting on a day/night cycle.
local FullbrightOrig = nil
local FullbrightColor = Color3.fromRGB(178, 178, 178)

local function ApplyFullbright()
	if States.Fullbright then
		if not FullbrightOrig then
			FullbrightOrig = {
				Brightness = Lighting.Brightness,
				Ambient = Lighting.Ambient,
				OutdoorAmbient = Lighting.OutdoorAmbient,
			}
		end
		if Lighting.Brightness ~= 2 then Lighting.Brightness = 2 end
		if Lighting.Ambient ~= FullbrightColor then Lighting.Ambient = FullbrightColor end
		if Lighting.OutdoorAmbient ~= FullbrightColor then Lighting.OutdoorAmbient = FullbrightColor end
	elseif FullbrightOrig then
		Lighting.Brightness = FullbrightOrig.Brightness
		Lighting.Ambient = FullbrightOrig.Ambient
		Lighting.OutdoorAmbient = FullbrightOrig.OutdoorAmbient
		FullbrightOrig = nil
	end
end

-- Remove Clouds/Atmosphere: Terrain clouds are disabled, Atmosphere objects are
-- detached (and put back on restore), and sun/moon/stars are hidden.
local SkyCache = nil

local function SetSkyRemoved(removed)
	if removed then
		if SkyCache then return end
		SkyCache = {clouds = {}, atmos = {}, skies = {}}
		pcall(function()
			for _, c in ipairs(workspace.Terrain:GetChildren()) do
				if c:IsA("Clouds") then
					SkyCache.clouds[c] = c.Enabled
					c.Enabled = false
				end
			end
		end)
		for _, v in ipairs(Lighting:GetChildren()) do
			if v:IsA("Atmosphere") then
				table.insert(SkyCache.atmos, v)
				v.Parent = nil
			elseif v:IsA("Sky") then
				SkyCache.skies[v] = {v.CelestialBodiesShown, v.StarCount}
				v.CelestialBodiesShown = false
				v.StarCount = 0
			end
		end
	elseif SkyCache then
		for c, was in pairs(SkyCache.clouds) do
			if c and c.Parent then c.Enabled = was end
		end
		for _, a in ipairs(SkyCache.atmos) do a.Parent = Lighting end
		for sky, orig in pairs(SkyCache.skies) do
			if sky and sky.Parent then
				sky.CelestialBodiesShown = orig[1]
				sky.StarCount = orig[2]
			end
		end
		SkyCache = nil
	end
end

-- Simplify Water: flat, non-reflective, non-animated terrain water
local WaterOrig = nil

local function SetWaterSimple(simple)
	pcall(function()
		local t = workspace.Terrain
		if simple then
			if not WaterOrig then
				WaterOrig = {
					WaterWaveSize = t.WaterWaveSize,
					WaterWaveSpeed = t.WaterWaveSpeed,
					WaterReflectance = t.WaterReflectance,
				}
			end
			t.WaterWaveSize = 0
			t.WaterWaveSpeed = 0
			t.WaterReflectance = 0
		elseif WaterOrig then
			for k, v in pairs(WaterOrig) do t[k] = v end
			WaterOrig = nil
		end
	end)
end

-- Mute All Game Sounds: sets every Sound in Workspace/SoundService to volume 0 and
-- remembers the original volume so it can be restored exactly.
local SoundCache = {}

local function MuteSound(s)
	if s:IsA("Sound") then
		if SoundCache[s] == nil then SoundCache[s] = s.Volume end
		if s.Volume ~= 0 then s.Volume = 0 end
	end
end

local function SetSoundsMuted(muted)
	if muted then
		for _, root in ipairs({workspace, SoundService}) do
			for _, v in ipairs(root:GetDescendants()) do MuteSound(v) end
		end
	else
		for s, vol in pairs(SoundCache) do
			if s and s.Parent then s.Volume = vol end
		end
		table.clear(SoundCache)
	end
end

local function OnSoundAdded(v)
	if States.MuteSounds and v:IsA("Sound") then
		task.defer(MuteSound, v)
	end
end
workspace.DescendantAdded:Connect(OnSoundAdded)
SoundService.DescendantAdded:Connect(OnSoundAdded)

-- ---------- v3.3 additions: logic ----------
local TeleportService = game:GetService("TeleportService")
local NoClipCache = {} -- parts whose CanCollide NoClip switched off (restored when NoClip ends)

-- Small toast message at the top of the screen
local NotifyLabel = Instance.new("TextLabel")
NotifyLabel.Size = UDim2.new(0, 280, 0, 30)
NotifyLabel.AnchorPoint = Vector2.new(0.5, 0)
NotifyLabel.Position = UDim2.new(0.5, 0, 0, 8)
NotifyLabel.BackgroundColor3 = Theme.Panel
NotifyLabel.BackgroundTransparency = 0.1
NotifyLabel.Font = Enum.Font.GothamMedium
NotifyLabel.TextSize = 13
NotifyLabel.TextColor3 = Theme.Text
NotifyLabel.Visible = false
NotifyLabel.Parent = ToggleGui
Instance.new("UICorner", NotifyLabel).CornerRadius = UDim.new(0, 8)

local notifyToken = 0
local function Notify(text, color)
	notifyToken += 1
	local my = notifyToken
	NotifyLabel.Text = text
	NotifyLabel.TextColor3 = color or Theme.Text
	NotifyLabel.Visible = true
	task.delay(3, function()
		if notifyToken == my then NotifyLabel.Visible = false end
	end)
end

-- Dash: quick burst forward (Q key, on-screen button, or the Player-tab button)
local function DoDash()
	local char = Player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then return end
	root.AssemblyLinearVelocity = flat.Unit * Sliders.DashPower + Vector3.new(0, 25, 0)
end

local DashFloat = Instance.new("TextButton")
DashFloat.Size = UDim2.new(0, 44, 0, 44)
DashFloat.Position = UDim2.new(0, 12, 0.35, 54)
DashFloat.Text = "DASH"
DashFloat.Font = Enum.Font.GothamBold
DashFloat.TextSize = 10
DashFloat.TextColor3 = Theme.Text
DashFloat.BackgroundColor3 = Theme.Panel
DashFloat.BackgroundTransparency = 0.15
DashFloat.BorderSizePixel = 0
DashFloat.AutoButtonColor = false
DashFloat.Active = true
DashFloat.Draggable = true
DashFloat.Visible = false
DashFloat.Parent = ToggleGui
Instance.new("UICorner", DashFloat).CornerRadius = UDim.new(1, 0)
local DashStroke = Instance.new("UIStroke", DashFloat)
DashStroke.Color = Theme.AccentAlt
DashStroke.Thickness = 2
DashFloat.MouseButton1Click:Connect(DoDash)

UIS.InputBegan:Connect(function(input, processed)
	if processed or not States.Hotkeys then return end
	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Q then
		DoDash()
	end
end)

-- Click Teleport: tap on touch devices, Ctrl+Click on PC. Drags (camera rotation) are ignored.
local TapStart = {}

UIS.InputBegan:Connect(function(input, processed)
	if processed or not States.ClickTP then return end
	local t = input.UserInputType
	if t == Enum.UserInputType.Touch or (t == Enum.UserInputType.MouseButton1 and UIS:IsKeyDown(Enum.KeyCode.LeftControl)) then
		TapStart[input] = {pos = input.Position, time = tick()}
	end
end)

UIS.InputEnded:Connect(function(input)
	local info = TapStart[input]
	if not info then return end
	TapStart[input] = nil
	if not States.ClickTP then return end
	if tick() - info.time > 0.35 then return end
	if (input.Position - info.pos).Magnitude > 12 then return end

	local char = Player.Character
	local cam = workspace.CurrentCamera
	if not char or not cam then return end

	local ray = cam:ScreenPointToRay(input.Position.X, input.Position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char}
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
	if hit then
		local pivot = char:GetPivot()
		char:PivotTo(pivot - pivot.Position + (hit.Position + Vector3.new(0, 4, 0)))
	end
end)

-- Teleport slots, player target, spectate
local SavedSlots = {}
local ActiveSlot = 1
local TargetPlayer = nil
local Spectating = false

local function StopSpectate()
	Spectating = false
	local cam = workspace.CurrentCamera
	local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
	if cam and hum then cam.CameraSubject = hum end
end

local function PickNextPlayer()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= Player then table.insert(list, p) end
	end
	table.sort(list, function(a, b) return a.Name:lower() < b.Name:lower() end)
	if #list == 0 then
		TargetPlayer = nil
		return nil
	end
	local idx = 0
	for i, p in ipairs(list) do
		if p == TargetPlayer then idx = i end
	end
	TargetPlayer = list[(idx % #list) + 1]
	return TargetPlayer
end

-- Rejoin / server hop
local function Rejoin()
	local ok = pcall(function()
		if #Players:GetPlayers() <= 1 then
			TeleportService:Teleport(game.PlaceId, Player)
		else
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Player)
		end
	end)
	return ok and "Rejoining..." or "Rejoin failed"
end

local function ServerHop()
	local ok = pcall(function()
		local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
		local data = HttpService:JSONDecode(game:HttpGet(url))
		local candidates = {}
		for _, sv in ipairs(data.data or {}) do
			if sv.id ~= game.JobId and (sv.playing or 0) < (sv.maxPlayers or 0) then
				table.insert(candidates, sv.id)
			end
		end
		if #candidates == 0 then error("no servers") end
		TeleportService:TeleportToPlaceInstance(game.PlaceId, candidates[math.random(#candidates)], Player)
	end)
	if ok then return "Hopping..." end
	-- Fallback if the server list can't be fetched: let Roblox pick a server
	local ok2 = pcall(function() TeleportService:Teleport(game.PlaceId, Player) end)
	return ok2 and "Hopping (random)..." or "Hop failed"
end

-- Generic "disable Enabled on these classes, restore later" helper (FX + lights)
local function MakeSwitcher(classes)
	local cache = {}
	local api = {}
	local function matches(v)
		for _, c in ipairs(classes) do
			if v:IsA(c) then return true end
		end
		return false
	end
	function api.set(on)
		if on then
			for _, v in ipairs(workspace:GetDescendants()) do
				if matches(v) and v.Enabled then
					cache[v] = true
					v.Enabled = false
				end
			end
		else
			for v in pairs(cache) do
				if v and v.Parent then v.Enabled = true end
			end
			table.clear(cache)
		end
	end
	function api.added(v)
		if matches(v) and v.Enabled then
			cache[v] = true
			v.Enabled = false
		end
	end
	return api
end

local FXSwitch = MakeSwitcher({"Fire", "Smoke", "Sparkles"})
local LightSwitch = MakeSwitcher({"PointLight", "SpotLight", "SurfaceLight"})

workspace.DescendantAdded:Connect(function(v)
	if not (States.RemoveFX or States.LightsOff) then return end
	task.defer(function()
		if States.RemoveFX then FXSwitch.added(v) end
		if States.LightsOff then LightSwitch.added(v) end
	end)
end)

-- Distance Cull: parts farther than the slider distance from the camera are hidden (client-only).
-- Characters, terrain and huge parts (floors/baseplates) are never touched. The list is walked
-- in small batches so it never causes a frame hitch.
local CullParts, CullHidden, CullCursor, CullActive = {}, {}, 1, false

local function CullEligible(v)
	if not v:IsA("BasePart") or v:IsA("Terrain") then return false end
	local m = v:FindFirstAncestorOfClass("Model")
	if m and m:FindFirstChildOfClass("Humanoid") then return false end
	local sz = v.Size
	return math.max(sz.X, sz.Y, sz.Z) < 80
end

local function StartCull()
	table.clear(CullParts)
	table.clear(CullHidden)
	CullCursor = 1
	CullActive = true
	local count = 0
	for _, v in ipairs(workspace:GetDescendants()) do
		if not CullActive then return end
		if CullEligible(v) then table.insert(CullParts, v) end
		count += 1
		if count % 2000 == 0 then task.wait() end
	end
end

local function StopCull()
	CullActive = false
	for v in pairs(CullHidden) do
		if v and v.Parent then v.LocalTransparencyModifier = 0 end
	end
	table.clear(CullHidden)
	table.clear(CullParts)
end

workspace.DescendantAdded:Connect(function(v)
	if not CullActive then return end
	task.defer(function()
		if CullActive and CullEligible(v) then table.insert(CullParts, v) end
	end)
end)

local function UpdateCull()
	if not CullActive then return end
	local cam = workspace.CurrentCamera
	local n = #CullParts
	if not cam or n == 0 then return end
	local camPos = cam.CFrame.Position
	local limit = Sliders.CullDist
	for _ = 1, 600 do
		if CullCursor > n then
			CullCursor = 1
			break
		end
		local part = CullParts[CullCursor]
		if not part.Parent then
			CullParts[CullCursor] = CullParts[n]
			CullParts[n] = nil
			n -= 1
			CullHidden[part] = nil
		else
			local far = (part.Position - camPos).Magnitude > limit
			if far and not CullHidden[part] then
				CullHidden[part] = true
				part.LocalTransparencyModifier = 1
			elseif not far and CullHidden[part] then
				CullHidden[part] = nil
				part.LocalTransparencyModifier = 0
			end
			CullCursor += 1
		end
	end
end

-- Battery Saver: one switch that turns on every lightweight-mode option, and puts each
-- one back to what it was before when switched off.
local BatteryKeys = {
	"LowGraphics", "DisableShadows", "HideParticles", "FlatLighting", "DisablePostFX",
	"ReduceResolution", "CapFrameRate", "RemoveFX", "SimplifyWater", "RemoveSky",
}

local function ApplyBatterySaver(on)
	for _, k in ipairs(BatteryKeys) do
		if on then
			if BatteryPrev[k] == nil then BatteryPrev[k] = States[k] end
			States[k] = true
		else
			States[k] = BatteryPrev[k] or false
		end
		if ToggleRefreshers[k] then ToggleRefreshers[k]() end
	end
	if not on then table.clear(BatteryPrev) end
end

-- Per-frame driver for all the extras above
local ExtraLast = {BatterySaver = false}
local lagBad, lastLagNotify = 0, 0
local lowFpsTimer = 0
local lastExtraSweep = 0
local LastGravity = DefaultGravity -- (a loaded/saved gravity value gets applied on the first frame)
local FOVCustom = false

local function ApplyExtras(dt, fps)
	-- Gravity slider (only writes when the slider actually moved)
	if Sliders.Gravity ~= LastGravity then
		LastGravity = Sliders.Gravity
		workspace.Gravity = (Sliders.Gravity == DefaultGravity) and OriginalGravity or Sliders.Gravity
	end

	-- FOV slider (re-applied every frame while customised, since games often tween FOV)
	local cam = workspace.CurrentCamera
	if cam then
		if Sliders.FOV ~= DefaultFOV then
			FOVCustom = true
			if cam.FieldOfView ~= Sliders.FOV then cam.FieldOfView = Sliders.FOV end
		elseif FOVCustom then
			FOVCustom = false
			cam.FieldOfView = OriginalFOV
		end
	end

	-- On-screen UP/DOWN pad: only on touch devices, only while Fly is on
	FlyPad.Visible = States.Fly and UIS.TouchEnabled

	-- One-shot toggles: apply only when the switch actually changes
	if States.RemoveSky ~= ExtraLast.RemoveSky then
		ExtraLast.RemoveSky = States.RemoveSky
		SetSkyRemoved(States.RemoveSky)
	end
	if States.SimplifyWater ~= ExtraLast.SimplifyWater then
		ExtraLast.SimplifyWater = States.SimplifyWater
		SetWaterSimple(States.SimplifyWater)
	end
	if States.MuteSounds ~= ExtraLast.MuteSounds then
		ExtraLast.MuteSounds = States.MuteSounds
		task.spawn(SetSoundsMuted, States.MuteSounds)
	end

	-- Light periodic sweep: Fullbright + keep sounds muted if the game changes volumes
	local now = tick()
	if now - lastExtraSweep >= 0.5 then
		lastExtraSweep = now
		ApplyFullbright()

		-- Lag warning: FPS < 20 or ping > 300 for ~2s, at most one toast every 10s
		if States.LagWarn then
			local okP, ping = pcall(function()
				return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
			end)
			local bad = (fps > 0 and fps < 20) or (okP and ping > 300)
			lagBad = bad and (lagBad + 1) or 0
			if lagBad >= 4 and now - lastLagNotify > 10 then
				lastLagNotify = now
				lagBad = 0
				Notify(("Lag! FPS %d | Ping %s ms"):format(fps, okP and tostring(math.floor(ping)) or "--"), Theme.Danger)
			end
		else
			lagBad = 0
		end

		-- Keep spectating locked on the target (follows respawns)
		if Spectating then
			local cam = workspace.CurrentCamera
			local th = TargetPlayer and TargetPlayer.Character and TargetPlayer.Character:FindFirstChildOfClass("Humanoid")
			if not TargetPlayer or not TargetPlayer.Parent then
				StopSpectate()
			elseif cam and th and cam.CameraSubject ~= th then
				cam.CameraSubject = th
			end
		end

		if States.MuteSounds then
			for s in pairs(SoundCache) do
				if s and s.Parent then
					if s.Volume ~= 0 then s.Volume = 0 end
				else
					SoundCache[s] = nil
				end
			end
		end
	end

	-- v3.3 toggles
	if States.RemoveFX ~= ExtraLast.RemoveFX then
		ExtraLast.RemoveFX = States.RemoveFX
		task.spawn(FXSwitch.set, States.RemoveFX)
	end
	if States.LightsOff ~= ExtraLast.LightsOff then
		ExtraLast.LightsOff = States.LightsOff
		task.spawn(LightSwitch.set, States.LightsOff)
	end
	if States.DistanceCull ~= ExtraLast.DistanceCull then
		ExtraLast.DistanceCull = States.DistanceCull
		if States.DistanceCull then task.spawn(StartCull) else StopCull() end
	end
	if States.BatterySaver ~= ExtraLast.BatterySaver then
		ExtraLast.BatterySaver = States.BatterySaver
		ApplyBatterySaver(States.BatterySaver)
	end
	UpdateCull()
	DashFloat.Visible = States.DashButton

	-- Auto Low-GFX: if FPS stays under the threshold for 3s, flip Low Graphics Mode on.
	-- One-shot (turns itself off afterwards) so it never fights a manual toggle.
	if States.AutoLowGFX and not States.LowGraphics and fps > 0 and fps < Sliders.AutoFPS then
		lowFpsTimer += dt
		if lowFpsTimer >= 3 then
			lowFpsTimer = 0
			States.LowGraphics = true
			States.AutoLowGFX = false
			if ToggleRefreshers.LowGraphics then ToggleRefreshers.LowGraphics() end
			if ToggleRefreshers.AutoLowGFX then ToggleRefreshers.AutoLowGFX() end
		end
	else
		lowFpsTimer = 0
	end
end

-- ---------- v3.3 additions: UI rows (built last so every callback target exists) ----------
local function ApplyTheme(idx)
	local new = Themes[idx]
	local oldA, oldB = Theme.Accent, Theme.AccentAlt
	Theme.Accent, Theme.AccentAlt = new.Accent, new.AccentAlt

	local function map(c)
		if c == oldA then return new.Accent end
		if c == oldB then return new.AccentAlt end
		return nil
	end

	for _, root in ipairs({gui, ToggleGui}) do
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("UIStroke") then
				local n = map(d.Color)
				if n then d.Color = n end
			elseif d:IsA("GuiObject") then
				local n = map(d.BackgroundColor3)
				if n then d.BackgroundColor3 = n end
				if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
					n = map(d.TextColor3)
					if n then d.TextColor3 = n end
				end
				if d:IsA("ScrollingFrame") then
					n = map(d.ScrollBarImageColor3)
					if n then d.ScrollBarImageColor3 = n end
				end
			end
		end
	end

	for _, refresh in pairs(ToggleRefreshers) do refresh() end
	Show(CurrentPage)
end

-- Player page: teleport slots + movement extras
local SlotRow
SlotRow = ActionBtn(Page2, "Slot: 1 (tap to change)", 6, function()
	ActiveSlot = ActiveSlot % 3 + 1
	local b = SlotRow and SlotRow:FindFirstChildOfClass("TextButton")
	if b then b.Text = ("Slot: %d (tap to change)"):format(ActiveSlot) end
end)

ActionBtn(Page2, "Save Position to Slot", 7, function()
	local char = Player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return "No character" end
	SavedSlots[ActiveSlot] = root.CFrame
	return ("Saved to slot %d!"):format(ActiveSlot)
end)

ActionBtn(Page2, "Teleport to Slot", 8, function()
	local char = Player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return "No character" end
	local cf = SavedSlots[ActiveSlot]
	if not cf then return ("Slot %d is empty"):format(ActiveSlot) end
	char:PivotTo(cf)
	root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	return "Teleported!"
end)

ToggleBtn(Page2, "Auto Walk (forward)", "AutoWalk", 9)
ToggleBtn(Page2, "Anti Fall Damage", "AntiFall", 10)
ToggleBtn(Page2, "Click Teleport (tap / Ctrl+Click)", "ClickTP", 11)
ToggleBtn(Page2, "Dash Button (on screen)", "DashButton", 12)
SliderRow(Page2, "Dash Power", "DashPower", 50, 300, 13)
ActionBtn(Page2, "Dash Forward (Q)", 14, function() DoDash() end)

-- Misc page: warnings, look & feel, saving, players, servers
ToggleBtn(Page3, "Lag Warning", "LagWarn", 7)

ActionBtn(Page3, "Change Theme", 8, function()
	ThemeIndex = ThemeIndex % #Themes + 1
	ApplyTheme(ThemeIndex)
	return "Theme: " .. Themes[ThemeIndex].Name
end)

local MenuScales = {0.8, 1, 1.2}
local MenuScaleNames = {"Small", "Normal", "Large"}
ActionBtn(Page3, "Menu Size", 9, function()
	local idx = 2
	for i, sv in ipairs(MenuScales) do
		if math.abs(sv - MenuScale) < 0.01 then idx = i end
	end
	idx = idx % #MenuScales + 1
	MenuScale = MenuScales[idx]
	MainScale.Scale = MenuScale
	return "Size: " .. MenuScaleNames[idx]
end)

ActionBtn(Page3, "Save Settings", 10, SaveSettings)
ActionBtn(Page3, "Delete Saved Settings", 11, DeleteSettings)

local TargetRow
TargetRow = ActionBtn(Page3, "Target: (tap to pick a player)", 12, function()
	local b = TargetRow and TargetRow:FindFirstChildOfClass("TextButton")
	local p = PickNextPlayer()
	if b then b.Text = p and ("Target: " .. p.DisplayName) or "No other players" end
end)

ActionBtn(Page3, "Teleport to Target", 13, function()
	if not TargetPlayer or not TargetPlayer.Character then return "No target" end
	local tr = TargetPlayer.Character:FindFirstChild("HumanoidRootPart")
	local char = Player.Character
	if not tr or not char then return "Unavailable" end
	char:PivotTo(tr.CFrame * CFrame.new(0, 0, 4))
	return "Teleported!"
end)

ActionBtn(Page3, "Spectate Target (tap again to stop)", 14, function()
	if Spectating then
		StopSpectate()
		return "Stopped"
	end
	local th = TargetPlayer and TargetPlayer.Character and TargetPlayer.Character:FindFirstChildOfClass("Humanoid")
	local cam = workspace.CurrentCamera
	if not th or not cam then return "No target" end
	Spectating = true
	cam.CameraSubject = th
	return "Spectating..."
end)

ActionBtn(Page3, "Rejoin Server", 15, Rejoin)
ActionBtn(Page3, "Server Hop", 16, ServerHop)

-- ================= v4.0 EXTENSION MODULE =================
-- Everything new lives inside InstallV4() so it gets its own local-variable budget
-- (the main chunk is already close to Luau's 200-locals limit).
local SpeedBonus = 0      -- added to WalkSpeed by the main loop (Sprint)
local RainbowColor = nil  -- when set, the main loop uses it for the glowing border (Rainbow UI)

local function InstallV4()
	local StarterGui = game:GetService("StarterGui")
	local SoundService = game:GetService("SoundService")

	-- ---------- 1. new state / slider keys ----------
	local newStates = {
		BunnyHop = false, Sprint = false, Glide = false, FloatPlat = false,
		CustomZoom = false, FirstPerson = false, OrbitCam = false, TopDownCam = false,
		CinemaBars = false, Crosshair = false,
		HUDCoords = false, HUDSpeed = false, HUDHeight = false, HUDSession = false,
		HUDClock = false, HUDPlayers = false, HUDHealth = false, HUDMemory = false,
		HUDCompass = false, HUDNearby = false,
		TimeLock = false, DayCycle = false, CustomBright = false, CustomExposure = false,
		CustomFog = false, OwnBloom = false, OwnColor = false, OwnBlur = false,
		BreakRemind = false, JoinAlerts = false, HideFarPlayers = false,
		CharTrail = false, CharAura = false, RainbowUI = false,
	}
	for k, v in pairs(newStates) do
		if States[k] == nil then States[k] = v end
	end

	local newSliders = {
		SprintBoost = 16, ExtraJumps = 0, GlideFall = 12,
		MaxZoom = 128, MinZoom = 0, CamRoll = 0, OrbitSpeed = 30, TopHeight = 80,
		TimeOfDay = 14, CycleSpeed = 10, Brightness = 2, ExposureX10 = 0, FogEndCustom = 1000,
		BloomInt = 10, Saturation = 0, Contrast = 0, BlurSize = 8,
		BreakMin = 30, TimerMin = 5, HideFarDist = 150,
		MusicVol = 50, AccR = 140, AccG = 80, AccB = 255, UITrans = 0,
		MenuPct = math.floor(MenuScale * 100 + 0.5),
	}
	for k, v in pairs(newSliders) do
		if Sliders[k] == nil then Sliders[k] = v end
	end

	-- movement / camera / fun toggles are never auto-restored on the next launch
	for _, k in ipairs({
		"BunnyHop", "Glide", "FloatPlat", "OrbitCam", "TopDownCam", "FirstPerson",
		"CharTrail", "CharAura", "RainbowUI", "TimeLock", "DayCycle",
	}) do
		SaveExclude[k] = true
	end

	-- the save file was read before these keys existed, so read it again for them
	pcall(function()
		if typeof(isfile) == "function" and typeof(readfile) == "function" and isfile(SETTINGS_FILE) then
			local data = HttpService:JSONDecode(readfile(SETTINGS_FILE))
			for k in pairs(newStates) do
				local v = data.States and data.States[k]
				if type(v) == "boolean" and not SaveExclude[k] then States[k] = v end
			end
			for k in pairs(newSliders) do
				local v = data.Sliders and data.Sliders[k]
				if type(v) == "number" then Sliders[k] = v end
			end
		end
	end)

	-- ---------- 2. small UI helpers ----------
	local function Clip(text)
		if typeof(setclipboard) == "function" then
			local ok = pcall(setclipboard, text)
			if ok then return "Copied!" end
		end
		Notify(text)
		return "No clipboard (see toast)"
	end

	local function InfoLabel(parent, order, text, height)
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, 0, 0, height or 36)
		l.LayoutOrder = order
		l.BackgroundColor3 = Theme.Panel
		l.BorderSizePixel = 0
		l.Text = text
		l.Font = Enum.Font.Gotham
		l.TextSize = 12
		l.TextColor3 = Theme.SubText
		l.TextWrapped = true
		l.Parent = parent
		Instance.new("UICorner", l).CornerRadius = UDim.new(0, 8)
		return l
	end

	local function TextRow(parent, order, placeholder, height, multiline, onSubmit)
		local box = Instance.new("TextBox")
		box.Size = UDim2.new(1, 0, 0, height or 36)
		box.LayoutOrder = order
		box.BackgroundColor3 = Theme.Panel
		box.BorderSizePixel = 0
		box.PlaceholderText = placeholder
		box.PlaceholderColor3 = Theme.SubText
		box.Text = ""
		box.ClearTextOnFocus = false
		box.Font = Enum.Font.GothamMedium
		box.TextSize = 13
		box.TextColor3 = Theme.Text
		box.TextWrapped = multiline == true
		box.MultiLine = multiline == true
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
		box.Parent = parent
		Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)
		local pad = Instance.new("UIPadding", box)
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingTop = UDim.new(0, multiline and 6 or 0)
		if onSubmit then
			box.FocusLost:Connect(function(enter) onSubmit(box, enter) end)
		end
		return box
	end

	-- ---------- 3. scrolling tab bar + 6 new tabs ----------
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, 0)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 2
	scroll.ScrollBarImageColor3 = Theme.Accent
	scroll.ScrollingDirection = Enum.ScrollingDirection.X
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	scroll.Parent = TabBar
	TabList.Parent = scroll
	for _, t in ipairs(AllTabs) do
		t.Parent = scroll
		t.Size = UDim2.new(0, 58, 1, -6)
	end

	local PageCam, PageHUD, PageLight, PageUtil, PageFun, PageUI =
		NewPage(), NewPage(), NewPage(), NewPage(), NewPage(), NewPage()
	local newTabDefs = {
		{"Cam", 6, PageCam}, {"HUD", 7, PageHUD}, {"Light", 8, PageLight},
		{"Util", 9, PageUtil}, {"Fun", 10, PageFun}, {"UI", 11, PageUI},
	}
	for _, def in ipairs(newTabDefs) do
		local tab = CreateTab(def[1], def[2])
		tab.Parent = scroll
		tab.Size = UDim2.new(0, 58, 1, -6)
		table.insert(AllTabs, tab)
		table.insert(Pages, def[3])
		TabPageMap[tab] = def[3]
		tab.MouseButton1Click:Connect(function() Show(def[3]) end)
	end

	-- ---------- 4. extra overlay GUIs (HUD, bars, crosshair) ----------
	local HUDGui = Instance.new("ScreenGui")
	HUDGui.Name = "JumpHubHUD"
	HUDGui.ResetOnSpawn = false
	HUDGui.DisplayOrder = 999
	HUDGui.Parent = PlayerGui

	local HUDLabel = Instance.new("TextLabel")
	HUDLabel.AutomaticSize = Enum.AutomaticSize.XY
	HUDLabel.Size = UDim2.new(0, 0, 0, 0)
	HUDLabel.AnchorPoint = Vector2.new(1, 0)
	HUDLabel.Position = UDim2.new(1, -12, 0, 60)
	HUDLabel.BackgroundColor3 = Theme.Background
	HUDLabel.BackgroundTransparency = 0.35
	HUDLabel.BorderSizePixel = 0
	HUDLabel.Font = Enum.Font.GothamMedium
	HUDLabel.TextSize = 12
	HUDLabel.TextColor3 = Theme.Text
	HUDLabel.TextXAlignment = Enum.TextXAlignment.Left
	HUDLabel.Text = ""
	HUDLabel.Visible = false
	HUDLabel.Active = true
	HUDLabel.Draggable = true
	HUDLabel.Parent = HUDGui
	Instance.new("UICorner", HUDLabel).CornerRadius = UDim.new(0, 8)
	local hudPad = Instance.new("UIPadding", HUDLabel)
	hudPad.PaddingLeft, hudPad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	hudPad.PaddingTop, hudPad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)

	local Overlay = Instance.new("ScreenGui")
	Overlay.Name = "JumpHubOverlay"
	Overlay.ResetOnSpawn = false
	Overlay.IgnoreGuiInset = true
	Overlay.DisplayOrder = 998
	Overlay.Parent = PlayerGui

	local BarTop = Instance.new("Frame")
	BarTop.Size = UDim2.new(1, 0, 0.11, 0)
	BarTop.BackgroundColor3 = Color3.new(0, 0, 0)
	BarTop.BorderSizePixel = 0
	BarTop.Visible = false
	BarTop.Parent = Overlay
	local BarBottom = Instance.new("Frame")
	BarBottom.Size = UDim2.new(1, 0, 0.11, 0)
	BarBottom.AnchorPoint = Vector2.new(0, 1)
	BarBottom.Position = UDim2.new(0, 0, 1, 0)
	BarBottom.BackgroundColor3 = Color3.new(0, 0, 0)
	BarBottom.BorderSizePixel = 0
	BarBottom.Visible = false
	BarBottom.Parent = Overlay
	local CrossDot = Instance.new("Frame")
	CrossDot.Size = UDim2.new(0, 5, 0, 5)
	CrossDot.AnchorPoint = Vector2.new(0.5, 0.5)
	CrossDot.Position = UDim2.new(0.5, 0, 0.5, 0)
	CrossDot.BackgroundColor3 = Theme.Accent
	CrossDot.BorderSizePixel = 0
	CrossDot.Visible = false
	CrossDot.Parent = Overlay
	Instance.new("UICorner", CrossDot).CornerRadius = UDim.new(1, 0)

	-- ---------- 5. UI ROWS ----------
	-- Move page (Page1) extras
	ToggleBtn(Page1, "Bunny Hop (hold Jump)", "BunnyHop", 7)
	ToggleBtn(Page1, "Sprint (hold Left Shift)", "Sprint", 8)
	SliderRow(Page1, "Sprint Boost", "SprintBoost", 4, 60, 9)
	SliderRow(Page1, "Extra Air Jumps", "ExtraJumps", 0, 5, 10)
	ToggleBtn(Page1, "Glide (hold Jump in air)", "Glide", 11)
	SliderRow(Page1, "Glide Fall Speed", "GlideFall", 3, 40, 12)
	ToggleBtn(Page1, "Float Platform", "FloatPlat", 13)
	ActionBtn(Page1, "Go To Spawn", 14, function()
		local char = Player.Character
		if not char then return "No character" end
		local sp = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		if not sp then return "No spawn found" end
		char:PivotTo(sp.CFrame + Vector3.new(0, 5, 0))
		return "Teleported!"
	end)
	ActionBtn(Page1, "Sit / Stand", 15, function()
		local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
		if not hum then return "No character" end
		hum.Sit = not hum.Sit
	end)
	ActionBtn(Page1, "Reset Character", 16, function()
		local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
		if not hum then return "No character" end
		hum.Health = 0
	end)

	-- FPS page (Page4) extras
	ToggleBtn(Page4, "Hide Far Players", "HideFarPlayers", 20)
	SliderRow(Page4, "Far Player Distance", "HideFarDist", 30, 500, 21)
	do
		local PresetKeys = {
			"DisableShadows", "HideParticles", "DisablePostFX", "LowGraphics",
			"FlatLighting", "RemoveFX", "SimplifyWater", "BatterySaver",
		}
		local Presets = {
			{Name = "Normal", Keys = {}},
			{Name = "Light", Keys = {"DisableShadows", "HideParticles", "DisablePostFX"}},
			{Name = "Low", Keys = {"DisableShadows", "HideParticles", "DisablePostFX",
				"LowGraphics", "FlatLighting", "RemoveFX", "SimplifyWater"}},
			{Name = "Ultra Low", Keys = {"BatterySaver"}},
		}
		local presetIdx = 1
		ActionBtn(Page4, "Quality Preset (tap to cycle)", 22, function()
			presetIdx = presetIdx % #Presets + 1
			local p = Presets[presetIdx]
			local wasBattery = States.BatterySaver
			for _, k in ipairs(PresetKeys) do
				States[k] = false
				if ToggleRefreshers[k] then ToggleRefreshers[k]() end
			end
			local function applyKeys()
				for _, k in ipairs(p.Keys) do
					States[k] = true
					if ToggleRefreshers[k] then ToggleRefreshers[k]() end
				end
			end
			-- leaving Ultra Low runs Battery Saver's restore pass first; wait for it to finish
			if wasBattery then task.delay(0.35, applyKeys) else applyKeys() end
			return "Preset: " .. p.Name
		end)
	end

	-- Cam page
	ToggleBtn(PageCam, "Custom Zoom Limits", "CustomZoom", 1)
	SliderRow(PageCam, "Max Zoom", "MaxZoom", 10, 1000, 2)
	SliderRow(PageCam, "Min Zoom", "MinZoom", 0, 50, 3)
	ToggleBtn(PageCam, "Lock First Person", "FirstPerson", 4)
	SliderRow(PageCam, "Camera Roll (deg)", "CamRoll", -45, 45, 5)
	ToggleBtn(PageCam, "Orbit Camera", "OrbitCam", 6)
	SliderRow(PageCam, "Orbit Speed", "OrbitSpeed", 5, 120, 7)
	ToggleBtn(PageCam, "Top-Down View", "TopDownCam", 8)
	SliderRow(PageCam, "Top-Down Height", "TopHeight", 20, 300, 9)
	ToggleBtn(PageCam, "Cinematic Bars", "CinemaBars", 10)
	ToggleBtn(PageCam, "Crosshair", "Crosshair", 11)
	ActionBtn(PageCam, "Screenshot Mode (hides UI 5s)", 12, function()
		local prev = {}
		for _, t in ipairs(Enum.CoreGuiType:GetEnumItems()) do
			if t ~= Enum.CoreGuiType.All then
				pcall(function() prev[t] = StarterGui:GetCoreGuiEnabled(t) end)
			end
		end
		gui.Enabled, ToggleGui.Enabled, HUDGui.Enabled, Overlay.Enabled = false, false, false, false
		pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
		task.delay(5, function()
			gui.Enabled, ToggleGui.Enabled, HUDGui.Enabled, Overlay.Enabled = true, true, true, true
			for t, v in pairs(prev) do
				pcall(function() StarterGui:SetCoreGuiEnabled(t, v) end)
			end
		end)
		return "Hidden for 5s..."
	end)

	-- HUD page
	ToggleBtn(PageHUD, "Coordinates (XYZ)", "HUDCoords", 1)
	ToggleBtn(PageHUD, "Speed", "HUDSpeed", 2)
	ToggleBtn(PageHUD, "Height", "HUDHeight", 3)
	ToggleBtn(PageHUD, "Session Time", "HUDSession", 4)
	ToggleBtn(PageHUD, "Real Clock", "HUDClock", 5)
	ToggleBtn(PageHUD, "Players in Server", "HUDPlayers", 6)
	ToggleBtn(PageHUD, "Health", "HUDHealth", 7)
	ToggleBtn(PageHUD, "Memory Usage", "HUDMemory", 8)
	ToggleBtn(PageHUD, "Compass", "HUDCompass", 9)
	ToggleBtn(PageHUD, "Nearby Players (distance)", "HUDNearby", 10)
	ActionBtn(PageHUD, "Copy My Position", 11, function()
		local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
		if not root then return "No character" end
		local p = root.Position
		return Clip(("%.1f, %.1f, %.1f"):format(p.X, p.Y, p.Z))
	end)
	ActionBtn(PageHUD, "Copy Server ID (JobId)", 12, function()
		return Clip(game.JobId ~= "" and game.JobId or "(Studio: no JobId)")
	end)
	ActionBtn(PageHUD, "Copy Place ID", 13, function()
		return Clip(tostring(game.PlaceId))
	end)
	ActionBtn(PageHUD, "Copy Debug Info", 14, function()
		local on = {}
		for k, v in pairs(States) do
			if v == true then table.insert(on, k) end
		end
		table.sort(on)
		return Clip(("JumpHub v4.0 | Place %s | Job %s | Players %d | ON: %s")
			:format(tostring(game.PlaceId), game.JobId, #Players:GetPlayers(), table.concat(on, ",")))
	end)

	-- Light page
	ToggleBtn(PageLight, "Lock Time of Day", "TimeLock", 1)
	SliderRow(PageLight, "Time of Day (hour)", "TimeOfDay", 0, 24, 2)
	ToggleBtn(PageLight, "Auto Day/Night Cycle", "DayCycle", 3)
	SliderRow(PageLight, "Cycle Speed (hours/min)", "CycleSpeed", 1, 120, 4)
	ToggleBtn(PageLight, "Custom Brightness", "CustomBright", 5)
	SliderRow(PageLight, "Brightness", "Brightness", 0, 10, 6)
	ToggleBtn(PageLight, "Custom Exposure", "CustomExposure", 7)
	SliderRow(PageLight, "Exposure (x10)", "ExposureX10", -30, 30, 8)
	ToggleBtn(PageLight, "Custom Fog Distance", "CustomFog", 9)
	SliderRow(PageLight, "Fog End (studs)", "FogEndCustom", 100, 5000, 10)
	ToggleBtn(PageLight, "Bloom Glow", "OwnBloom", 11)
	SliderRow(PageLight, "Bloom Intensity (x10)", "BloomInt", 1, 40, 12)
	ToggleBtn(PageLight, "Color Boost", "OwnColor", 13)
	SliderRow(PageLight, "Saturation", "Saturation", -100, 100, 14)
	SliderRow(PageLight, "Contrast", "Contrast", -50, 100, 15)
	ToggleBtn(PageLight, "Blur", "OwnBlur", 16)
	SliderRow(PageLight, "Blur Size", "BlurSize", 1, 40, 17)
	local LightOrig = {
		ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness,
		Exposure = Lighting.ExposureCompensation, FogEnd = Lighting.FogEnd,
		FogStart = Lighting.FogStart, Ambient = Lighting.Ambient,
		Outdoor = Lighting.OutdoorAmbient,
	}
	do
		local AmbientPresets = {
			{"Warm", Color3.fromRGB(255, 200, 150)},
			{"Cool", Color3.fromRGB(150, 190, 255)},
			{"Pink", Color3.fromRGB(255, 170, 220)},
			{"Green", Color3.fromRGB(170, 255, 190)},
			{"Dark", Color3.fromRGB(25, 25, 35)},
		}
		local ambIdx = 0
		ActionBtn(PageLight, "Ambient Color (tap to cycle)", 18, function()
			ambIdx = ambIdx % #AmbientPresets + 1
			local p = AmbientPresets[ambIdx]
			Lighting.Ambient = p[2]
			Lighting.OutdoorAmbient = p[2]
			return "Ambient: " .. p[1]
		end)
		ActionBtn(PageLight, "Reset Ambient Color", 19, function()
			ambIdx = 0
			Lighting.Ambient = LightOrig.Ambient
			Lighting.OutdoorAmbient = LightOrig.Outdoor
			return "Ambient reset"
		end)
	end

	-- Util page
	ToggleBtn(PageUtil, "Break Reminder", "BreakRemind", 1)
	SliderRow(PageUtil, "Remind Every (min)", "BreakMin", 5, 120, 2)
	ToggleBtn(PageUtil, "Join / Leave Alerts", "JoinAlerts", 3)

	local swRunning, swStart, swElapsed = false, 0, 0
	local SwLabel = InfoLabel(PageUtil, 4, "Stopwatch: 00:00.0", 32)
	ActionBtn(PageUtil, "Stopwatch Start / Stop", 5, function()
		if swRunning then
			swElapsed += tick() - swStart
			swRunning = false
			return "Stopped"
		end
		swStart = tick()
		swRunning = true
		return "Running"
	end)
	ActionBtn(PageUtil, "Stopwatch Reset", 6, function()
		swRunning, swElapsed = false, 0
		return "Reset"
	end)

	local timerEnd = nil
	SliderRow(PageUtil, "Countdown (min)", "TimerMin", 1, 60, 7)
	local TimerLabel = InfoLabel(PageUtil, 8, "Timer: idle", 32)
	ActionBtn(PageUtil, "Countdown Start / Stop", 9, function()
		if timerEnd then
			timerEnd = nil
			return "Stopped"
		end
		timerEnd = tick() + Sliders.TimerMin * 60
		return "Started"
	end)

	-- tiny safe calculator (no loadstring): + - * / ^ and parentheses
	local function Calc(src)
		src = src:gsub("%s+", "")
		local pos = 1
		local expr
		local function peek() return src:sub(pos, pos) end
		local function primary()
			if peek() == "(" then
				pos += 1
				local v = expr()
				if peek() ~= ")" then error("missing )") end
				pos += 1
				return v
			end
			local num = src:match("^%d*%.?%d+", pos)
			if not num then error("bad number") end
			pos += #num
			return tonumber(num)
		end
		local function power()
			if peek() == "-" then
				pos += 1
				return -power()
			end
			local base = primary()
			if peek() == "^" then
				pos += 1
				return base ^ power()
			end
			return base
		end
		local function term()
			local v = power()
			while true do
				local c = peek()
				if c == "*" then pos += 1; v = v * power()
				elseif c == "/" then pos += 1; v = v / power()
				else break end
			end
			return v
		end
		expr = function()
			local v = term()
			while true do
				local c = peek()
				if c == "+" then pos += 1; v = v + term()
				elseif c == "-" then pos += 1; v = v - term()
				else break end
			end
			return v
		end
		local v = expr()
		if pos <= #src then error("unexpected " .. peek()) end
		return v
	end

	local CalcResult = InfoLabel(PageUtil, 11, "Result: -", 30)
	TextRow(PageUtil, 10, "Calculator: e.g. (12+8)*3/2", 36, false, function(box)
		if box.Text == "" then return end
		local ok, v = pcall(Calc, box.Text)
		CalcResult.Text = ok and ("Result: " .. tostring(v)) or "Result: invalid expression"
	end)
	TextRow(PageUtil, 12, "Notes (kept until you close the game)", 90, true, nil)
	TextRow(PageUtil, 13, "Find player by name -> sets Target", 36, false, function(box)
		local q = box.Text:lower()
		if q == "" then return end
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= Player and (p.Name:lower():sub(1, #q) == q or p.DisplayName:lower():sub(1, #q) == q) then
				TargetPlayer = p
				Notify("Target: " .. p.DisplayName, Theme.On)
				box.Text = ""
				return
			end
		end
		Notify("No player found", Theme.Danger)
	end)

	-- Fun page
	local MusicSound
	local MusicBox = TextRow(PageFun, 1, "Sound ID (numbers only)", 36, false, nil)
	ActionBtn(PageFun, "Play Music", 2, function()
		local id = MusicBox.Text:match("%d+")
		if not id then return "Enter a Sound ID" end
		if not MusicSound then
			MusicSound = Instance.new("Sound")
			MusicSound.Name = "JH_Music"
			MusicSound.Looped = true
			MusicSound.Parent = SoundService
		end
		MusicSound.SoundId = "rbxassetid://" .. id
		MusicSound.Volume = Sliders.MusicVol / 100
		MusicSound:Play()
		return "Playing"
	end)
	ActionBtn(PageFun, "Stop Music", 3, function()
		if MusicSound then MusicSound:Stop() end
		return "Stopped"
	end)
	SliderRow(PageFun, "Music Volume", "MusicVol", 0, 100, 4)
	ToggleBtn(PageFun, "Character Trail", "CharTrail", 5)
	ToggleBtn(PageFun, "Particle Aura", "CharAura", 6)
	ActionBtn(PageFun, "Random Body Color (respawn undoes)", 7, function()
		local char = Player.Character
		if not char then return "No character" end
		local c = Color3.fromHSV(math.random(), 0.7, 1)
		for _, v in ipairs(char:GetChildren()) do
			if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then v.Color = c end
		end
		return "Colored!"
	end)

	-- UI page
	table.insert(Themes, {Name = "Ocean", Accent = Color3.fromRGB(40, 150, 255), AccentAlt = Color3.fromRGB(80, 240, 220)})
	table.insert(Themes, {Name = "Pink", Accent = Color3.fromRGB(255, 90, 180), AccentAlt = Color3.fromRGB(190, 120, 255)})
	table.insert(Themes, {Name = "Mono", Accent = Color3.fromRGB(200, 200, 210), AccentAlt = Color3.fromRGB(120, 120, 135)})
	table.insert(Themes, {Name = "Custom", Accent = Color3.fromRGB(140, 80, 255), AccentAlt = Color3.fromRGB(70, 180, 255)})
	local customIdx = #Themes

	ToggleBtn(PageUI, "Rainbow Border", "RainbowUI", 1)
	SliderRow(PageUI, "Menu Transparency %", "UITrans", 0, 60, 2)
	SliderRow(PageUI, "Menu Size %", "MenuPct", 70, 130, 3)
	SliderRow(PageUI, "Custom Accent: Red", "AccR", 0, 255, 4)
	SliderRow(PageUI, "Custom Accent: Green", "AccG", 0, 255, 5)
	SliderRow(PageUI, "Custom Accent: Blue", "AccB", 0, 255, 6)
	ActionBtn(PageUI, "Apply Custom Accent", 7, function()
		local c = Color3.fromRGB(Sliders.AccR, Sliders.AccG, Sliders.AccB)
		local h, s, v = c:ToHSV()
		Themes[customIdx].Accent = c
		Themes[customIdx].AccentAlt = Color3.fromHSV((h + 0.12) % 1, s, v)
		ThemeIndex = customIdx
		ApplyTheme(customIdx)
		return "Custom theme applied"
	end)
	InfoLabel(PageUI, 8, "Jump Hub v4.0. Use 'Change Theme' on the Misc tab to cycle all themes (including Custom). Swipe the tab bar sideways to see all tabs.", 56)

	-- ---------- 6. runtime state + logic ----------
	local Prev = {}
	local function Edge(key, v)
		local old = Prev[key] or false
		Prev[key] = v
		return old ~= v
	end

	local JH = {}
	local ExtraUsed = 0
	local sessionStart = tick()
	local lastBreak = tick()
	local lastSlow = 0
	local FarHidden = {}
	local ZoomOrig = {Max = Player.CameraMaxZoomDistance, Min = Player.CameraMinZoomDistance}
	local warned = false
	local orbitAngle = 0

	local function EnsureEffect(class, name, enabled)
		local e = Lighting:FindFirstChild(name)
		if enabled then
			if not e then
				e = Instance.new(class)
				e.Name = name
				e.Parent = Lighting
			end
			return e
		elseif e then
			e:Destroy()
		end
		return nil
	end

	local function CompassName(deg)
		local names = {"N", "NE", "E", "SE", "S", "SW", "W", "NW"}
		return names[(math.floor((deg + 22.5) / 45) % 8) + 1]
	end

	local function SlowTick(now, char, hum, root)
		-- zoom limits
		if States.CustomZoom then
			pcall(function()
				Player.CameraMaxZoomDistance = Sliders.MaxZoom
				Player.CameraMinZoomDistance = math.min(Sliders.MinZoom, Sliders.MaxZoom)
			end)
		end

		-- lighting
		if States.TimeLock then Lighting.ClockTime = Sliders.TimeOfDay end
		if States.CustomBright then Lighting.Brightness = Sliders.Brightness end
		if States.CustomExposure then Lighting.ExposureCompensation = Sliders.ExposureX10 / 10 end
		if States.CustomFog then
			Lighting.FogStart = 0
			Lighting.FogEnd = Sliders.FogEndCustom
		end
		if States.OwnBloom then
			local e = EnsureEffect("BloomEffect", "JH_Bloom", true)
			e.Intensity = Sliders.BloomInt / 10
			e.Size = 24
			e.Threshold = 1
		else
			EnsureEffect("BloomEffect", "JH_Bloom", false)
		end
		if States.OwnColor then
			local e = EnsureEffect("ColorCorrectionEffect", "JH_Color", true)
			e.Saturation = Sliders.Saturation / 100
			e.Contrast = Sliders.Contrast / 100
		else
			EnsureEffect("ColorCorrectionEffect", "JH_Color", false)
		end
		if States.OwnBlur then
			local e = EnsureEffect("BlurEffect", "JH_Blur", true)
			e.Size = Sliders.BlurSize
		else
			EnsureEffect("BlurEffect", "JH_Blur", false)
		end

		-- overlays
		BarTop.Visible = States.CinemaBars
		BarBottom.Visible = States.CinemaBars
		CrossDot.Visible = States.Crosshair
		CrossDot.BackgroundColor3 = Theme.Accent

		-- UI look
		if Prev.MenuPct ~= Sliders.MenuPct then
			Prev.MenuPct = Sliders.MenuPct
			MenuScale = Sliders.MenuPct / 100
			MainScale.Scale = MenuScale
		end
		if Prev.UITrans ~= Sliders.UITrans then
			Prev.UITrans = Sliders.UITrans
			Main.BackgroundTransparency = Sliders.UITrans / 100
		end

		-- music volume
		if MusicSound then MusicSound.Volume = Sliders.MusicVol / 100 end

		-- stopwatch / timer / break reminder
		local sw = swElapsed + (swRunning and (now - swStart) or 0)
		SwLabel.Text = ("Stopwatch: %02d:%04.1f"):format(math.floor(sw / 60), sw % 60)
		if timerEnd then
			local left = timerEnd - now
			if left <= 0 then
				timerEnd = nil
				TimerLabel.Text = "Timer: done!"
				Notify("Countdown finished!", Theme.On)
			else
				TimerLabel.Text = ("Timer: %02d:%02d"):format(math.floor(left / 60), math.floor(left % 60))
			end
		else
			TimerLabel.Text = "Timer: idle"
		end
		if States.BreakRemind and now - lastBreak >= Sliders.BreakMin * 60 then
			lastBreak = now
			Notify("Time for a short break!", Theme.AccentAlt)
		end

		-- hide far players
		for c in pairs(FarHidden) do
			if not c.Parent then FarHidden[c] = nil end
		end
		if States.HideFarPlayers and root then
			for _, plr in ipairs(Players:GetPlayers()) do
				local pc = plr ~= Player and plr.Character
				local r = pc and pc:FindFirstChild("HumanoidRootPart")
				if r then
					local far = (r.Position - root.Position).Magnitude > Sliders.HideFarDist
					if far and not FarHidden[pc] then
						FarHidden[pc] = true
						for _, v in ipairs(pc:GetDescendants()) do
							if v:IsA("BasePart") then v.LocalTransparencyModifier = 1 end
						end
					elseif not far and FarHidden[pc] then
						FarHidden[pc] = nil
						if not States.HideOtherPlayers then
							for _, v in ipairs(pc:GetDescendants()) do
								if v:IsA("BasePart") then v.LocalTransparencyModifier = 0 end
							end
						end
					end
				end
			end
		end

		-- trail / aura (re-created after respawn)
		if States.CharTrail and root then
			if JH.TrailRoot ~= root or not (JH.Trail and JH.Trail.Parent) then
				for _, o in ipairs(JH.TrailObjs or {}) do o:Destroy() end
				local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
				a0.Position, a1.Position = Vector3.new(0, 1, 0), Vector3.new(0, -1, 0)
				a0.Parent, a1.Parent = root, root
				local tr = Instance.new("Trail")
				tr.Attachment0, tr.Attachment1 = a0, a1
				tr.Lifetime = 0.6
				tr.LightEmission = 1
				tr.Color = ColorSequence.new(Theme.Accent, Theme.AccentAlt)
				tr.Transparency = NumberSequence.new(0.2, 1)
				tr.Parent = root
				JH.Trail, JH.TrailRoot, JH.TrailObjs = tr, root, {a0, a1, tr}
			end
		end
		if States.CharAura and root then
			if JH.AuraRoot ~= root or not (JH.Aura and JH.Aura.Parent) then
				if JH.Aura then JH.Aura:Destroy() end
				local pe = Instance.new("ParticleEmitter")
				pe.Rate = 25
				pe.Lifetime = NumberRange.new(0.8, 1.4)
				pe.Speed = NumberRange.new(1, 3)
				pe.SpreadAngle = Vector2.new(180, 180)
				pe.Size = NumberSequence.new(0.5, 0)
				pe.Color = ColorSequence.new(Theme.Accent, Theme.AccentAlt)
				pe.LightEmission = 1
				pe.Transparency = NumberSequence.new(0.2, 1)
				pe.Parent = root
				JH.Aura, JH.AuraRoot = pe, root
			end
		end

		-- HUD text
		local lines = {}
		if States.HUDCoords and root then
			local p = root.Position
			table.insert(lines, ("XYZ: %d, %d, %d"):format(math.floor(p.X), math.floor(p.Y), math.floor(p.Z)))
		end
		if States.HUDSpeed and root then
			local v = root.AssemblyLinearVelocity
			table.insert(lines, ("Speed: %.1f"):format(Vector3.new(v.X, 0, v.Z).Magnitude))
		end
		if States.HUDHeight and root then
			table.insert(lines, ("Height: %d"):format(math.floor(root.Position.Y)))
		end
		if States.HUDSession then
			local s = math.floor(now - sessionStart)
			table.insert(lines, ("Session: %d:%02d:%02d"):format(math.floor(s / 3600), math.floor(s / 60) % 60, s % 60))
		end
		if States.HUDClock then
			table.insert(lines, "Time: " .. os.date("%H:%M:%S"))
		end
		if States.HUDPlayers then
			table.insert(lines, ("Players: %d/%d"):format(#Players:GetPlayers(), Players.MaxPlayers))
		end
		if States.HUDHealth and hum then
			table.insert(lines, ("Health: %d/%d"):format(math.floor(hum.Health), math.floor(hum.MaxHealth)))
		end
		if States.HUDMemory then
			local ok, mb = pcall(function() return Stats:GetTotalMemoryUsageMb() end)
			if ok then table.insert(lines, ("Memory: %d MB"):format(math.floor(mb))) end
		end
		if States.HUDCompass then
			local cam = workspace.CurrentCamera
			if cam then
				local look = cam.CFrame.LookVector
				local deg = math.deg(math.atan2(look.X, -look.Z)) % 360
				table.insert(lines, ("Facing: %s (%d)"):format(CompassName(deg), math.floor(deg)))
			end
		end
		if States.HUDNearby and root then
			local list = {}
			for _, plr in ipairs(Players:GetPlayers()) do
				local r = plr ~= Player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
				if r then
					table.insert(list, {name = plr.DisplayName, d = (r.Position - root.Position).Magnitude})
				end
			end
			table.sort(list, function(a, b) return a.d < b.d end)
			for i = 1, math.min(3, #list) do
				table.insert(lines, ("%s: %d studs"):format(list[i].name, math.floor(list[i].d)))
			end
		end
		HUDLabel.Visible = #lines > 0
		HUDLabel.Text = table.concat(lines, "\n")
	end

	-- extra air jumps
	UIS.JumpRequest:Connect(function()
		if Sliders.ExtraJumps <= 0 then return end
		local char = Player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not hum or not root then return end
		if hum.FloorMaterial == Enum.Material.Air and ExtraUsed < Sliders.ExtraJumps then
			ExtraUsed += 1
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v.X, Sliders.JumpPower, v.Z)
		end
	end)

	-- join / leave alerts
	Players.PlayerAdded:Connect(function(p)
		if States.JoinAlerts then Notify(p.DisplayName .. " joined", Theme.On) end
	end)
	Players.PlayerRemoving:Connect(function(p)
		if States.JoinAlerts then Notify(p.DisplayName .. " left", Theme.Danger) end
	end)

	-- camera: orbit / top-down / roll (runs right after Roblox's own camera update)
	local CamScripted = false
	RunService:BindToRenderStep("JumpHubCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local cam = workspace.CurrentCamera
		if not cam then return end
		local char = Player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local wantScript = States.OrbitCam or States.TopDownCam
		if wantScript and root then
			CamScripted = true
			cam.CameraType = Enum.CameraType.Scriptable
			local p = root.Position
			if States.OrbitCam then
				orbitAngle += math.rad(Sliders.OrbitSpeed) * dt
				local offset = Vector3.new(math.cos(orbitAngle) * 18, 6, math.sin(orbitAngle) * 18)
				cam.CFrame = CFrame.lookAt(p + offset, p + Vector3.new(0, 2, 0))
			else
				cam.CFrame = CFrame.lookAt(p + Vector3.new(0, Sliders.TopHeight, 0), p, Vector3.new(0, 0, -1))
			end
		elseif CamScripted then
			CamScripted = false
			cam.CameraType = Enum.CameraType.Custom
		end
		if Sliders.CamRoll ~= 0 then
			cam.CFrame = cam.CFrame * CFrame.Angles(0, 0, math.rad(Sliders.CamRoll))
		end
	end)

	-- main driver
	RunService.Heartbeat:Connect(function(dt)
		local now = tick()
		local char = Player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")

		-- Sprint (the main loop adds SpeedBonus to WalkSpeed)
		local bonus = 0
		if States.Sprint and hum then
			local held = UIS:IsKeyDown(Enum.KeyCode.LeftShift) or (UIS.TouchEnabled and not UIS.KeyboardEnabled)
			if held then bonus = Sliders.SprintBoost end
		end
		SpeedBonus = bonus

		if hum and root then
			local air = hum.FloorMaterial == Enum.Material.Air
			if not air then ExtraUsed = 0 end

			if States.BunnyHop and not air and (UIS:IsKeyDown(Enum.KeyCode.Space) or hum.Jump) then
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
			end

			if States.Glide and air and not States.Fly and UIS:IsKeyDown(Enum.KeyCode.Space) then
				local v = root.AssemblyLinearVelocity
				if v.Y < -Sliders.GlideFall then
					root.AssemblyLinearVelocity = Vector3.new(v.X, -Sliders.GlideFall, v.Z)
				end
			end
		end

		-- float platform
		if States.FloatPlat and root then
			if not (JH.Plat and JH.Plat.Parent) then
				local feet = root.Position.Y - (root.Size.Y / 2 + (hum and hum.HipHeight or 2))
				JH.PlatY = feet - 0.3
				local p = Instance.new("Part")
				p.Name = "JH_Platform"
				p.Size = Vector3.new(8, 0.6, 8)
				p.Anchored = true
				p.Material = Enum.Material.Neon
				p.Color = Theme.Accent
				p.Transparency = 0.5
				p.Parent = workspace
				JH.Plat = p
			end
			JH.Plat.Position = Vector3.new(root.Position.X, JH.PlatY, root.Position.Z)
		elseif JH.Plat then
			JH.Plat:Destroy()
			JH.Plat = nil
		end

		-- one-shot toggle edges (capture original values on, restore on off)
		if Edge("CustomZoom", States.CustomZoom) then
			if States.CustomZoom then
				ZoomOrig.Max, ZoomOrig.Min = Player.CameraMaxZoomDistance, Player.CameraMinZoomDistance
			else
				pcall(function()
					Player.CameraMaxZoomDistance = ZoomOrig.Max
					Player.CameraMinZoomDistance = ZoomOrig.Min
				end)
			end
		end
		if Edge("FirstPerson", States.FirstPerson) then
			pcall(function()
				Player.CameraMode = States.FirstPerson and Enum.CameraMode.LockFirstPerson or Enum.CameraMode.Classic
			end)
		end
		if Edge("TimeLock", States.TimeLock) then
			if States.TimeLock then LightOrig.ClockTime = Lighting.ClockTime
			else Lighting.ClockTime = LightOrig.ClockTime end
		end
		if Edge("CustomBright", States.CustomBright) then
			if States.CustomBright then LightOrig.Brightness = Lighting.Brightness
			else Lighting.Brightness = LightOrig.Brightness end
		end
		if Edge("CustomExposure", States.CustomExposure) then
			if States.CustomExposure then LightOrig.Exposure = Lighting.ExposureCompensation
			else Lighting.ExposureCompensation = LightOrig.Exposure end
		end
		if Edge("CustomFog", States.CustomFog) then
			if States.CustomFog then
				LightOrig.FogEnd, LightOrig.FogStart = Lighting.FogEnd, Lighting.FogStart
			else
				Lighting.FogEnd, Lighting.FogStart = LightOrig.FogEnd, LightOrig.FogStart
			end
		end
		if Edge("BreakRemind", States.BreakRemind) and States.BreakRemind then
			lastBreak = now
		end
		if Edge("CharTrail", States.CharTrail) and not States.CharTrail then
			for _, o in ipairs(JH.TrailObjs or {}) do o:Destroy() end
			JH.Trail, JH.TrailRoot, JH.TrailObjs = nil, nil, nil
		end
		if Edge("CharAura", States.CharAura) and not States.CharAura then
			if JH.Aura then JH.Aura:Destroy() end
			JH.Aura, JH.AuraRoot = nil, nil
		end
		if Edge("HideFarPlayers", States.HideFarPlayers) and not States.HideFarPlayers then
			for c in pairs(FarHidden) do
				if c.Parent and not States.HideOtherPlayers then
					for _, v in ipairs(c:GetDescendants()) do
						if v:IsA("BasePart") then v.LocalTransparencyModifier = 0 end
					end
				end
			end
			table.clear(FarHidden)
		end

		-- day/night cycle runs every frame (smooth)
		if States.DayCycle and not States.TimeLock then
			Lighting.ClockTime = (Lighting.ClockTime + dt * Sliders.CycleSpeed / 60) % 24
		end

		-- rainbow border colour (read by the main loop)
		RainbowColor = States.RainbowUI and Color3.fromHSV((now * 0.15) % 1, 0.75, 1) or nil

		-- slow tick (4x per second), protected so one bad frame can't spam errors
		if now - lastSlow >= 0.25 then
			lastSlow = now
			local ok, err = pcall(SlowTick, now, char, hum, root)
			if not ok and not warned then
				warned = true
				warn("[JumpHub] v4 tick error: " .. tostring(err))
			end
		end
	end)

	-- hide the pages we just created (Show also recolours the new tabs)
	Show(CurrentPage)
	print("[JumpHub] v4 extension installed")
end

local okV4, errV4 = pcall(InstallV4)
if not okV4 then
	warn("[JumpHub] v4 extension failed to load: " .. tostring(errV4))
end

-- ================= FUNCTIONALITY LOOP =================
local fpsAccum, fpsFrames, fpsTimer = 0, 0, 0
local lastHeavyUpdate = 0
local autoJumpTimer = 0
local heartbeatConfirmed = false

-- Using Heartbeat instead of RenderStepped: some executors/environments throttle or
-- block RenderStepped from firing for LocalScripts (especially injected/executor-run
-- scripts, as opposed to scripts placed directly in StarterPlayerScripts), which is
-- what caused every feature - FPS counter, toggles, tab switching animations, all of
-- which are driven from this single loop - to silently do nothing. Heartbeat runs on
-- the physics step instead of the render step and is far more consistently available.
print("[JumpHub] about to connect Heartbeat...")
RunService.Heartbeat:Connect(function(dt)
	if not heartbeatConfirmed then
		heartbeatConfirmed = true
		print("[JumpHub] Heartbeat IS firing, loop is alive")
	end

	ApplyGraphicsSettings()

	local char = Player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")

	if hum then
		hum.WalkSpeed = math.max(0, Sliders.WalkSpeed + SpeedBonus)
		hum.JumpPower = Sliders.JumpPower

		if States.Spin then
			char:PivotTo(char:GetPivot() * CFrame.Angles(0, 0.1, 0))
		end

		if States.NoClip then
			for _, v in ipairs(char:GetDescendants()) do
				if v:IsA("BasePart") and v.CanCollide then
					NoClipCache[v] = true
					v.CanCollide = false
				end
			end
		elseif next(NoClipCache) ~= nil then
			-- NoClip turned off: give back collision to exactly the parts we disabled
			for part in pairs(NoClipCache) do
				if part and part.Parent then part.CanCollide = true end
			end
			table.clear(NoClipCache)
		end

		-- Fly: create/destroy the BodyVelocity+BodyGyro pair only on state change
		if States.Fly and not FlyBodyVelocity then
			EnableFly(char)
		elseif not States.Fly and FlyBodyVelocity then
			DisableFly()
		end
		if States.Fly then
			UpdateFly(char, dt)
		end

		-- Hover: hold position in mid-air (paused while Fly is active)
		if States.HoverAir and not States.Fly then
			EnableHover(char)
		else
			DisableHover()
		end

		if States.SpeedClimb then
			UpdateSpeedClimb(char)
		end

		-- Auto Walk: keep moving forward relative to the camera
		if States.AutoWalk then
			hum:Move(Vector3.new(0, 0, -1), true)
		end

		-- Anti Fall Damage: cap the downward fall speed (skipped while Fly is on)
		if States.AntiFall and not States.Fly then
			local root = char:FindFirstChild("HumanoidRootPart")
			if root and hum.FloorMaterial == Enum.Material.Air then
				local v = root.AssemblyLinearVelocity
				if v.Y < -50 then
					root.AssemblyLinearVelocity = Vector3.new(v.X, -50, v.Z)
				end
			end
		end

		-- Auto Jump: triggers a jump automatically whenever grounded, on a short
		-- interval so it doesn't spam ChangeState every single frame
		if States.AutoJump then
			autoJumpTimer += dt
			if autoJumpTimer >= 0.15 and hum.FloorMaterial ~= Enum.Material.Air then
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
				autoJumpTimer = 0
			end
		end
	end

	-- FPS/ping counter (no blocking Wait())
	fpsFrames += 1
	fpsTimer += dt
	if fpsTimer >= 0.5 then
		fpsAccum = math.floor(fpsFrames / fpsTimer)
		fpsFrames, fpsTimer = 0, 0
	end

	ApplyExtras(dt, fpsAccum)

	local pingOk, ping = pcall(function()
		return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
	end)

	-- Power Saver (formerly "Cap Frame Rate"): Roblox does not expose a script API to
	-- force a hard framerate cap - RenderStepped firing less often does NOT stop the
	-- engine from rendering frames underneath it. What this toggle actually does instead
	-- is throttle the UI's OWN cosmetic work (glow animation, FPS-color updates) down to
	-- ~10 updates/sec instead of every frame, freeing a small amount of CPU/battery on
	-- weaker mobile devices. It won't raise your in-game FPS ceiling, but it reduces the
	-- hub's own overhead to close to zero.
	local heavyUpdateInterval = States.CapFrameRate and 0.1 or 0
	local now = tick()
	local shouldUpdateCosmetics = (now - lastHeavyUpdate) >= heavyUpdateInterval

	if shouldUpdateCosmetics then
		lastHeavyUpdate = now

		if not Minimized then
			local accentColor = RainbowColor or Theme.Accent:Lerp(Theme.AccentAlt, (math.sin(now) + 1) / 2)
			MainStroke.Color = accentColor
			AccentBar.BackgroundColor3 = accentColor
		end

		local fpsColor = Theme.On
		if fpsAccum > 0 and fpsAccum < 20 then
			fpsColor = Theme.Danger
		elseif fpsAccum > 0 and fpsAccum < 40 then
			fpsColor = Color3.fromRGB(255, 200, 90)
		end
		SubTitle.TextColor3 = fpsColor
		SubTitle.Text = ("FPS: %d | %sms"):format(fpsAccum, pingOk and tostring(ping) or "--")
	end
end)

UIS.JumpRequest:Connect(function()
	local char = Player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	if States.InfiniteJump then
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
	end

	if States.DoubleJump and JumpCount < 2 then
		JumpCount += 1
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

RunService.Stepped:Connect(function()
	local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
	if hum and hum.FloorMaterial ~= Enum.Material.Air then
		JumpCount = 0
	end
end)