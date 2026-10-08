-- Jump Hub v4.1 (v4.0 + 50 tinh nang con thieu: Movement/Camera/Perf/Light/HUD/Util/UI/Settings/Audio/Fun)
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

-- v4.1: bang phim tat co the doi (Keybind editor o tab Set).
-- ResolveKeybind tra ve ten action cho 3 toggle ma code cu xu ly, nen hanh vi mac dinh
-- (F/H/N/Q/LeftShift/RightShift) van giuyen nguyen nhu truoc.
local KeyBinds = {
	Fly = Enum.KeyCode.F, Hover = Enum.KeyCode.H, NoClip = Enum.KeyCode.N,
	Dash = Enum.KeyCode.Q, Sprint = Enum.KeyCode.LeftShift, Menu = Enum.KeyCode.RightShift,
	Crouch = Enum.KeyCode.C, Slide = Enum.KeyCode.V, AirDash = Enum.KeyCode.E,
	FreeCam = Enum.KeyCode.P, ShiftLock = Enum.KeyCode.Z, EmoteWheel = Enum.KeyCode.T,
	EmoteDance = Enum.KeyCode.Y, EmoteWave = Enum.KeyCode.U,
}

local function ResolveKeybind(code)
	for action, kc in pairs(KeyBinds) do
		if kc == code and (action == "Fly" or action == "Hover" or action == "NoClip") then
			return action
		end
	end
	return nil
end

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

	if input.KeyCode == KeyBinds.Menu then
		Main.Visible = not Main.Visible
		return
	end

	if not States.Hotkeys then return end
	local key = ResolveKeybind(input.KeyCode)
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
	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == KeyBinds.Dash then
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
		return Clip(("JumpHub v4.1 | Place %s | Job %s | Players %d | ON: %s")
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
	InfoLabel(PageUI, 8, "Jump Hub v4.1. Use 'Change Theme' on the Misc tab to cycle all themes (including Custom). Swipe the tab bar sideways to see all tabs.", 56)

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
			local held = UIS:IsKeyDown(KeyBinds.Sprint) or (UIS.TouchEnabled and not UIS.KeyboardEnabled)
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

-- ================= v4.1 EXTENSION MODULE (InstallV5) =================
-- 50 tính năng còn thiếu của danh sách 150. Toàn bộ code mới nằm trong InstallV5()
-- (cùng kiểu InstallV4, gọi bằng pcall) để không vượt giới hạn 200 local của chunk
-- chính; nếu lỗi thì script v4.0 vẫn chạy bình thường.
local function InstallV5()
	-- ===== 0. services + tham chiếu trang đã có =====
	local TextChatService = game:GetService("TextChatService")

	-- trang đã có: tìm qua TabPageMap (key = tab, value = trang) -> không đụng code cũ
	local P = {}
	for tab, page in pairs(TabPageMap) do
		P[tab.Text] = page
	end

	-- ===== 1. helper dùng chung =====
	local scrollTab = TabBar:FindFirstChildOfClass("ScrollingFrame")

	-- thêm tab mới giống mảng newTabDefs trong InstallV4
	local function AddTab(name, order)
		local tab = CreateTab(name, order)
		local page = NewPage()
		if scrollTab then
			tab.Parent = scrollTab
			tab.Size = UDim2.new(0, 58, 1, -6)
		else
			tab.Parent = TabBar
			tab.Size = UDim2.new(1 / (#AllTabs + 1), -5, 1, 0)
		end
		table.insert(AllTabs, tab)
		table.insert(Pages, page)
		TabPageMap[tab] = page
		P[name] = page
		tab.MouseButton1Click:Connect(function() Show(page) end)
		return page
	end

	local function Pg(name)
		return P[name] or Page1
	end

	-- GUI overlay riêng của v4.1 (stamina, biểu đồ, minimap, bánh xe emote...)
	local V5Gui = Instance.new("ScreenGui")
	V5Gui.Name = "JumpHubV5"
	V5Gui.ResetOnSpawn = false
	V5Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	V5Gui.DisplayOrder = 997
	V5Gui.Parent = PlayerGui

	-- ===== 2. nhật ký lỗi nội bộ (mục 140) =====
	local LogLines, LogSeen = {}, {}
	local LogRefresh = nil
	local function Log(msg)
		msg = tostring(msg)
		if LogSeen[msg] then return end -- tránh spam cùng 1 lỗi mỗi frame
		LogSeen[msg] = true
		table.insert(LogLines, 1, os.date("%H:%M:%S") .. "  " .. msg)
		if #LogLines > 120 then table.remove(LogLines) end
		if LogRefresh then pcall(LogRefresh) end
	end

	-- ===== 3. tooltip (mục 126) =====
	local Tips = {} -- { ["tên row"] = "giải thích" }
	local TipBox = Instance.new("TextLabel")
	TipBox.Size = UDim2.new(0, 260, 0, 0)
	TipBox.AutomaticSize = Enum.AutomaticSize.Y
	TipBox.BackgroundColor3 = Theme.Background
	TipBox.BackgroundTransparency = 0.05
	TipBox.BorderSizePixel = 0
	TipBox.Font = Enum.Font.Gotham
	TipBox.TextSize = 12
	TipBox.TextColor3 = Theme.SubText
	TipBox.TextWrapped = true
	TipBox.TextXAlignment = Enum.TextXAlignment.Left
	TipBox.Visible = false
	TipBox.ZIndex = 50
	TipBox.Parent = V5Gui
	Instance.new("UICorner", TipBox).CornerRadius = UDim.new(0, 8)
	do
		local pad = Instance.new("UIPadding", TipBox)
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	end

	-- ===== 4. helper copy / label / ô nhập (bản v4.1 vì bản của v4 nằm trong InstallV4) =====
	local function Clip5(text)
		if typeof(setclipboard) == "function" then
			local ok = pcall(setclipboard, text)
			if ok then return "Copied!" end
		end
		Notify(text)
		return "No clipboard (see toast)"
	end

	local function Info5(parent, order, text, height)
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

	local function Row5(parent, order, placeholder, height, multiline, onSubmit)
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

	-- ===== 5. vùng chạm GUI (dành cho touch / Free Cam) =====
	local UIBoxes = {}
	local function IsOnOurUI(x, y)
		for _, box in ipairs(UIBoxes) do
			if box and box.Parent and box.Visible then
				local p, s = box.AbsolutePosition, box.AbsoluteSize
				if x >= p.X and x <= p.X + s.X and y >= p.Y and y <= p.Y + s.Y then
					return true
				end
			end
		end
		return false
	end
	table.insert(UIBoxes, Main)

	-- ===== 6. nạp cấu hình đã lưu cho key mới (mục 132) =====
	local function LoadKeys(states, sliders)
		pcall(function()
			if typeof(isfile) ~= "function" or typeof(readfile) ~= "function" then return end
			if not isfile(SETTINGS_FILE) then return end
			local data = HttpService:JSONDecode(readfile(SETTINGS_FILE))
			for k in pairs(states or {}) do
				local v = data.States and data.States[k]
				if type(v) == "boolean" and not SaveExclude[k] then States[k] = v end
			end
			for k in pairs(sliders or {}) do
				local v = data.Sliders and data.Sliders[k]
				if type(v) == "number" then Sliders[k] = v end
			end
		end)
	end

	-- ===== 7. động lực chạy chung =====
	local Drivers, CamDrivers, Slows, LateInit = {}, {}, {}, {}
	local ctx = {now = 0, dt = 0, char = nil, hum = nil, root = nil, cam = nil}
	local RebindActive = false -- Keybind editor đang chờ gõ phím (mục 136)
	local FavRefresh = nil     -- làm mới danh sách Yêu thích (mục 125)

	-- ==================== ĐỢT A: Movement + Camera ====================
	do
		-- --- key mới ---
		local AStates = {
			HoverMove = false, AirCtl = false, AirDash = false, Slide = false,
			StaminaOn = false, CrouchOn = false, ClimbSpeedOn = false,
			FallCap = false, SwimSpeedOn = false,
			FreeCam = false, ShiftLock = false, CamSmooth = false,
			CamShakeDamp = false, CamOffset = false,
		}
		for k, v in pairs(AStates) do
			if States[k] == nil then States[k] = v end
		end

		local ASliders = {
			AirCtlPct = 50, AirDashPow = 120, SlideSpeed = 60, SlideTime = 2,
			CrouchPct = 45, ClimbSpeed = 40, MaxFall = 70, SwimSpeed = 30,
			SpinRate = 10, FreeSpeed = 60, CamOffY = 0, CamOffX = 0,
			SmoothPct = 45, ShakePct = 55,
		}
		for k, v in pairs(ASliders) do
			if Sliders[k] == nil then Sliders[k] = v end
		end

		-- toggle di chuyển / camera không bao giờ tự bật lại ở lần vào sau
		for _, k in ipairs({
			"HoverMove", "AirCtl", "AirDash", "Slide", "CrouchOn", "ClimbSpeedOn",
			"FallCap", "SwimSpeedOn", "FreeCam", "ShiftLock", "CamSmooth",
			"CamShakeDamp", "CamOffset",
		}) do
			SaveExclude[k] = true
		end
		LoadKeys(AStates, ASliders) -- đọc lại file cho key của đợt này

		-- --- trạng thái nội đợt ---
		local prev = {}
		local function edge(k, v)
			local old = prev[k] or false
			prev[k] = v
			return old ~= v
		end

		local holdCrouch = false -- giữ nút ảo Crouch trên mobile
		local slideEnd, slideCD = 0, 0
		local dashCD = 0
		local stamina, stDelay, exhausted = 100, 0, false
		local lastSB = 0
		local offChar, offSaved, offApplied = nil, nil, false
		local shiftSaved = nil
		local smoothPrev, shakePrev = nil, nil
		local lookHeld, touchLook = false, nil
		local camYaw, camPitch = 0, 0
		local lookDX, lookDY = 0, 0
		local freeHold = {fwd = false, back = false, left = false, right = false, up = false, down = false}
		local movePad, freePad, stGui = nil, nil, nil

		-- ===== 17: tiêu stamina cho Sprint / Dash / Slide =====
		local function Spend(n)
			if not States.StaminaOn then return end
			stamina = math.max(0, stamina - n)
			stDelay = 0.8
		end

		-- ===== 14: Air Dash (lao trên không) =====
		local function DoAirDash()
			if not States.AirDash then return "Air Dash is off" end
			local hum, root, now = ctx.hum, ctx.root, ctx.now
			if not hum or not root then return "No character" end
			if now < dashCD then return "Wait..." end
			if hum.FloorMaterial ~= Enum.Material.Air then return "Air only" end
			if States.StaminaOn and exhausted then return "No stamina" end
			dashCD = now + 1.2
			Spend(25)
			local cam = workspace.CurrentCamera
			local look = (cam and cam.CFrame.LookVector) or root.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude < 0.05 then flat = Vector3.new(0, 0, -1) end
			flat = flat.Unit
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(
				flat.X * Sliders.AirDashPow,
				math.max(v.Y * 0.2, 6),
				flat.Z * Sliders.AirDashPow
			)
			return "Air dash!"
		end

		-- ===== 15: Slide (trượt) =====
		local function StartSlide()
			if not States.Slide then return "Slide is off" end
			local hum, root, now = ctx.hum, ctx.root, ctx.now
			if not hum or not root then return "No character" end
			if now < slideCD then return "Wait..." end
			if hum.FloorMaterial == Enum.Material.Air then return "Ground only" end
			if hum.MoveDirection.Magnitude < 0.05 then return "Move first" end
			if States.StaminaOn and exhausted then return "No stamina" end
			slideEnd = now + math.max(1, Sliders.SlideTime)
			slideCD = slideEnd + 0.6
			Spend(15)
			local md = hum.MoveDirection
			local dir = Vector3.new(md.X, 0, md.Z)
			if dir.Magnitude < 0.05 then
				dir = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
			end
			if dir.Magnitude < 0.05 then return "No direction" end
			dir = dir.Unit
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(
				dir.X * Sliders.SlideSpeed,
				math.min(v.Y, 0),
				dir.Z * Sliders.SlideSpeed
			)
			return "Sliding!"
		end

		-- thanh stamina: tạo khi bật, hủy khi tắt
		local function buildStamina()
			if stGui then return end
			local bar = Instance.new("Frame")
			bar.Size = UDim2.new(0, 260, 0, 16)
			bar.AnchorPoint = Vector2.new(0.5, 1)
			bar.Position = UDim2.new(0.5, 0, 1, -34)
			bar.BackgroundColor3 = Theme.Background
			bar.BackgroundTransparency = 0.25
			bar.BorderSizePixel = 0
			bar.Parent = V5Gui
			Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
			local fill = Instance.new("Frame", bar)
			fill.Size = UDim2.new(math.clamp(stamina / 100, 0, 1), 0, 1, 0)
			fill.BackgroundColor3 = Theme.On
			fill.BorderSizePixel = 0
			Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
			local lbl = Instance.new("TextLabel", bar)
			lbl.Size = UDim2.new(1, 0, 1, 0)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.GothamBold
			lbl.TextSize = 11
			lbl.TextColor3 = Theme.Text
			lbl.Text = "Stamina 100"
			stGui = {bar = bar, fill = fill, lbl = lbl}
		end
		local function killStamina()
			if stGui then
				stGui.bar:Destroy()
				stGui = nil
			end
		end

		-- nút ảo mobile: Crouch / Slide / Air Dash (cao 46px >= 36px)
		local function buildMovePad()
			if movePad then return end
			local pad = Instance.new("Frame")
			pad.Size = UDim2.new(0, 150, 0, 154)
			pad.AnchorPoint = Vector2.new(1, 1)
			pad.Position = UDim2.new(1, -16, 1, -16)
			pad.BackgroundColor3 = Theme.Background
			pad.BackgroundTransparency = 0.35
			pad.BorderSizePixel = 0
			pad.Parent = V5Gui
			Instance.new("UICorner", pad).CornerRadius = UDim.new(0, 12)
			local function mk(text, y, press, release)
				local b = Instance.new("TextButton", pad)
				b.Size = UDim2.new(1, -12, 0, 46)
				b.Position = UDim2.new(0, 6, 0, y)
				b.Text = text
				b.Font = Enum.Font.GothamBold
				b.TextSize = 13
				b.TextColor3 = Theme.Text
				b.BackgroundColor3 = Theme.Panel
				b.BorderSizePixel = 0
				b.AutoButtonColor = false
				Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
				b.InputBegan:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
						press()
						tween(b, {BackgroundColor3 = Theme.Accent}, 0.08)
					end
				end)
				b.InputEnded:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
						if release then release() end
						tween(b, {BackgroundColor3 = Theme.Panel}, 0.15)
					end
				end)
			end
			mk("CROUCH", 6, function() holdCrouch = true end, function() holdCrouch = false end)
			mk("SLIDE", 54, function() StartSlide() end)
			mk("AIR DASH", 102, function() DoAirDash() end)
			movePad = pad
			table.insert(UIBoxes, pad)
		end
		local function killMovePad()
			if movePad then
				movePad:Destroy()
				movePad = nil
			end
		end

		-- nút ảo mobile cho Free Cam (6 nút, cùng vị trí với MovePad)
		local function buildFreePad()
			if freePad then return end
			local pad = Instance.new("Frame")
			pad.Size = UDim2.new(0, 150, 0, 154)
			pad.AnchorPoint = Vector2.new(1, 1)
			pad.Position = UDim2.new(1, -16, 1, -16)
			pad.BackgroundColor3 = Theme.Background
			pad.BackgroundTransparency = 0.35
			pad.BorderSizePixel = 0
			pad.Parent = V5Gui
			Instance.new("UICorner", pad).CornerRadius = UDim.new(0, 12)
			local defs = {
				{"FWD", 6, 6, "fwd"}, {"UP", 77, 6, "up"},
				{"BACK", 6, 54, "back"}, {"DOWN", 77, 54, "down"},
				{"LEFT", 6, 102, "left"}, {"RIGHT", 77, 102, "right"},
			}
			for _, d in ipairs(defs) do
				local keyName = d[4] -- local riêng mỗi vòng để closure không lấy nhầm
				local b = Instance.new("TextButton", pad)
				b.Size = UDim2.new(0, 67, 0, 46)
				b.Position = UDim2.new(0, d[2], 0, d[3])
				b.Text = d[1]
				b.Font = Enum.Font.GothamBold
				b.TextSize = 12
				b.TextColor3 = Theme.Text
				b.BackgroundColor3 = Theme.Panel
				b.BorderSizePixel = 0
				b.AutoButtonColor = false
				Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
				b.InputBegan:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
						freeHold[keyName] = true
						tween(b, {BackgroundColor3 = Theme.Accent}, 0.08)
					end
				end)
				b.InputEnded:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
						freeHold[keyName] = false
						tween(b, {BackgroundColor3 = Theme.Panel}, 0.15)
					end
				end)
			end
			freePad = pad
			table.insert(UIBoxes, pad)
		end
		local function killFreePad()
			if freePad then
				freePad:Destroy()
				freePad = nil
			end
		end

		-- ===== driver movement: chạy MỖI frame, sau driver v4.0, trước vòng lặp chính =====
		local function MoveDriver(dt, c)
			local hum, root = c.hum, c.root
			if not hum or not root then return end
			local now = c.now

			local crouchHeld = States.CrouchOn and (holdCrouch or UIS:IsKeyDown(KeyBinds.Crouch))
			local sprintHeld = States.Sprint and (UIS:IsKeyDown(KeyBinds.Sprint) or (UIS.TouchEnabled and not UIS.KeyboardEnabled))
			local onGround = hum.FloorMaterial ~= Enum.Material.Air
			local sliding = now < slideEnd
			if sliding and not onGround then slideEnd = 0; sliding = false end

			-- ===== 17: thanh stamina =====
			if States.StaminaOn then
				if sprintHeld and hum.MoveDirection.Magnitude > 0.05 then
					stamina = stamina - 16 * dt
					stDelay = 0.6
				end
				stDelay = stDelay - dt
				if stDelay <= 0 then stamina = math.min(100, stamina + 24 * dt) end
				if stamina < 0 then stamina = 0 end
				if exhausted then
					if stamina >= 25 then exhausted = false end
				elseif stamina <= 0 then
					exhausted = true
					Notify("Out of stamina!", Theme.Danger)
				end
			else
				stamina, stDelay, exhausted = 100, 0, false
			end
			if edge("staminaUI", States.StaminaOn) then
				if States.StaminaOn then buildStamina() else killStamina() end
			end
			if stGui then
				stGui.fill.Size = UDim2.new(math.clamp(stamina / 100, 0, 1), 0, 1, 0)
				if exhausted then
					stGui.fill.BackgroundColor3 = Theme.Danger
				elseif stamina < 30 then
					stGui.fill.BackgroundColor3 = Color3.fromRGB(255, 200, 90)
				else
					stGui.fill.BackgroundColor3 = Theme.On
				end
				stGui.lbl.Text = "Stamina " .. math.floor(stamina + 0.5)
			end

			-- ===== SpeedBonus: CHỈ CỘNG thêm, không bao giờ ghi đè hum.WalkSpeed =====
			local adj = 0
			if crouchHeld and not sliding then -- 18: cúi người
				adj = adj + Sliders.WalkSpeed * (Sliders.CrouchPct / 100 - 1)
			end
			if sliding then -- 15: giữ tốc độ khi đang trượt
				adj = adj + (Sliders.SlideSpeed - Sliders.WalkSpeed)
			end
			if States.ClimbSpeedOn then -- 19: tốc độ leo
				local okS, st = pcall(function() return hum:GetState() end)
				if okS and (st == Enum.HumanoidStateType.Climbing or hum.FloorMaterial == Enum.Material.Truss) then
					adj = adj + (Sliders.ClimbSpeed - Sliders.WalkSpeed)
				end
			end
			if States.SwimSpeedOn then -- 27: tốc độ bơi
				local okS, st = pcall(function() return hum:GetState() end)
				if okS and st == Enum.HumanoidStateType.Swimming then
					adj = adj + (Sliders.SwimSpeed - Sliders.WalkSpeed)
				end
			end
			if States.StaminaOn and exhausted and sprintHeld then
				SpeedBonus = 0 -- hết stamina: hủy bonus Sprint của v4.0
			end
			-- nếu driver v4.0 không chạy (lỗi) thì tự reset, tránh cộng dồn mỗi frame
			if adj ~= 0 and SpeedBonus == lastSB then SpeedBonus = 0 end
			SpeedBonus = SpeedBonus + adj
			lastSB = SpeedBonus

			-- ===== 26: giới hạn tốc độ rơi =====
			if States.FallCap then
				local v = root.AssemblyLinearVelocity
				if v.Y < -Sliders.MaxFall then
					root.AssemblyLinearVelocity = Vector3.new(v.X, -Sliders.MaxFall, v.Z)
				end
			end

			-- ===== 4: Hover cho phép đi ngang =====
			local wantHover = States.HoverAir and States.HoverMove and not States.Fly
			local hv = root:FindFirstChild("_JH_Hover")
			if edge("hovermove", wantHover) and not wantHover and hv then
				hv.Velocity = Vector3.new(0, 0, 0) -- tắt: trả lại trạng thái đứng yên
			end
			if wantHover and hv then
				local md = hum.MoveDirection
				local flat = Vector3.new(md.X, 0, md.Z)
				if flat.Magnitude > 0.05 then
					hv.Velocity = flat.Unit * Sliders.WalkSpeed
				else
					hv.Velocity = Vector3.new(0, 0, 0)
				end
			end

			-- ===== 9: Air Control =====
			if States.AirCtl and not onGround and not States.Fly then
				local md = hum.MoveDirection
				local flat = Vector3.new(md.X, 0, md.Z)
				if flat.Magnitude > 0.05 then
					local v = root.AssemblyLinearVelocity
					local cur = Vector3.new(v.X, 0, v.Z)
					local want = flat.Unit * Sliders.WalkSpeed
					local a = math.clamp((Sliders.AirCtlPct / 100) * dt * 4, 0, 1)
					local nf = cur:Lerp(want, a)
					root.AssemblyLinearVelocity = Vector3.new(nf.X, v.Y, nf.Z)
				end
			end

			-- ===== 34: khi Free Cam bật thì nhân vật đứng yên =====
			if States.FreeCam then
				hum:Move(Vector3.new(0, 0, 0))
				hum.Jump = false
			end

			-- ===== 41 + 18 + 15: camera offset (lưu giá trị gốc, khôi phục khi tắt) =====
			if offChar ~= hum then -- respawn: humanoid mới, bỏ offset cũ
				offChar, offSaved, offApplied = hum, nil, false
			end
			local extraY = 0
			if sliding then extraY = extraY - 1.6 end
			if crouchHeld and not sliding then extraY = extraY - 1.2 end
			local baseX = States.CamOffset and Sliders.CamOffX or 0
			local baseY = States.CamOffset and Sliders.CamOffY or 0
			local wantOff = Vector3.new(baseX, baseY + extraY, 0)
			if wantOff.Magnitude > 0.001 then
				if not offApplied then
					offSaved = hum.CameraOffset
					offApplied = true
				end
				if hum.CameraOffset ~= wantOff then hum.CameraOffset = wantOff end
			elseif offApplied then
				if offSaved then hum.CameraOffset = offSaved end
				offSaved, offApplied = nil, false
			end

			-- ===== nút ảo mobile =====
			local touch = UIS.TouchEnabled
			local wantMove = touch and (States.CrouchOn or States.Slide or States.AirDash)
			local wantFree = touch and States.FreeCam
			if edge("padMove", wantMove) then
				if wantMove then buildMovePad() else killMovePad() end
			end
			if edge("padFree", wantFree) then
				if wantFree then buildFreePad() else killFreePad() end
			end
			if movePad then movePad.Visible = wantMove and not wantFree end
			if freePad then freePad.Visible = wantFree end
		end

		-- ===== driver camera: chạy trong RenderStep sau camera của game (priority Camera+2) =====
		local function CamDriver(dt, c)
			local cam = c.cam
			if not cam then return end

			-- ===== 34: Free Cam =====
			if edge("freecam", States.FreeCam) then
				if States.FreeCam then
					local rx, ry = cam.CFrame:ToEulerAnglesYXZ()
					camPitch, camYaw = rx, ry
				else
					lookHeld, touchLook = false, nil
					lookDX, lookDY = 0, 0
					for k in pairs(freeHold) do freeHold[k] = false end
					pcall(function() cam.CameraType = Enum.CameraType.Custom end)
				end
			end
			if States.FreeCam then
				pcall(function() cam.CameraType = Enum.CameraType.Scriptable end)
				if lookDX ~= 0 or lookDY ~= 0 then
					camYaw = camYaw - lookDX * 0.004
					camPitch = math.clamp(camPitch - lookDY * 0.004, -1.5, 1.5)
					lookDX, lookDY = 0, 0
				end
				local base = CFrame.new(cam.CFrame.Position)
					* CFrame.Angles(0, camYaw, 0)
					* CFrame.Angles(camPitch, 0, 0)
				local move = Vector3.new(0, 0, 0)
				local fwd, right = base.LookVector, base.RightVector
				if UIS:IsKeyDown(Enum.KeyCode.W) or freeHold.fwd then move = move + fwd end
				if UIS:IsKeyDown(Enum.KeyCode.S) or freeHold.back then move = move - fwd end
				if UIS:IsKeyDown(Enum.KeyCode.A) or freeHold.left then move = move - right end
				if UIS:IsKeyDown(Enum.KeyCode.D) or freeHold.right then move = move + right end
				if UIS:IsKeyDown(Enum.KeyCode.Space) or freeHold.up then move = move + Vector3.new(0, 1, 0) end
				if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or freeHold.down then move = move - Vector3.new(0, 1, 0) end
				if move.Magnitude > 0 then move = move.Unit end
				cam.CFrame = base + move * Sliders.FreeSpeed * dt
			end

			-- ===== 36: Shift Lock (bản client: xoay nhân vật theo hướng camera khi di chuyển) =====
			if States.ShiftLock and c.hum and c.root then
				if shiftSaved == nil then shiftSaved = c.hum.AutoRotate end
				c.hum.AutoRotate = false
				if c.hum.MoveDirection.Magnitude > 0.05 then
					local flat = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
					if flat.Magnitude > 0.05 then
						c.root.CFrame = CFrame.lookAt(c.root.Position, c.root.Position + flat.Unit * 4)
					end
				end
			elseif shiftSaved ~= nil and c.hum then
				c.hum.AutoRotate = shiftSaved
				shiftSaved = nil
			end

			-- ===== 37 + 38: camera mượt + giảm rung màn hình =====
			if States.FreeCam then
				smoothPrev, shakePrev = nil, nil
			else
				if States.CamSmooth then -- 37: đánh mượt góc nhìn (dạng low-pass)
					local target = cam.CFrame
					if smoothPrev then
						local dot = math.clamp(smoothPrev.LookVector:Dot(target.LookVector), -1, 1)
						local ang = math.deg(math.acos(dot))
						local sr = (ang > 50) and target or smoothPrev:Lerp(target, Sliders.SmoothPct / 100)
						cam.CFrame = CFrame.new(target.Position) * (sr - sr.Position)
					end
					smoothPrev = cam.CFrame
				else
					smoothPrev = nil
				end
				if States.CamShakeDamp then -- 38: chặn rung tần suất cao (xem CHANGELOG)
					local target = cam.CFrame
					if shakePrev then
						local dot = math.clamp(shakePrev.LookVector:Dot(target.LookVector), -1, 1)
						local ang = math.deg(math.acos(dot))
						local dp = (shakePrev.Position - target.Position).Magnitude
						local sr
						if ang > 45 or dp > 25 then
							sr = target -- di chuyển lớn = thao tác thật -> bắt kịp ngay
						else
							sr = shakePrev:Lerp(target, Sliders.ShakePct / 100)
						end
						cam.CFrame = CFrame.new(sr.Position) * (sr - sr.Position)
						shakePrev = cam.CFrame
					else
						shakePrev = target
					end
				else
					shakePrev = nil
				end
			end
		end

		-- nhìn bằng chuột phải / kéo touch (chỉ khi Free Cam đang bật)
		UIS.InputBegan:Connect(function(input)
			if not States.FreeCam then return end
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				lookHeld = true
			elseif input.UserInputType == Enum.UserInputType.Touch then
				if not IsOnOurUI(input.Position.X, input.Position.Y) then
					touchLook = input
				end
			end
		end)
		UIS.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton2 then lookHeld = false end
			if input.UserInputType == Enum.UserInputType.Touch and touchLook == input then touchLook = nil end
		end)
		UIS.InputChanged:Connect(function(input)
			if not States.FreeCam then return end
			if input.UserInputType == Enum.UserInputType.MouseMovement and lookHeld then
				lookDX = lookDX + input.Delta.X
				lookDY = lookDY + input.Delta.Y
			elseif input.UserInputType == Enum.UserInputType.Touch and touchLook == input then
				lookDX = lookDX + input.Delta.X
				lookDY = lookDY + input.Delta.Y
			end
		end)

		-- phím tắt đợt A (bỏ qua khi đang gõ chat / đang rebind)
		UIS.InputBegan:Connect(function(input, processed)
			if RebindActive or processed then return end
			if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
			if not States.Hotkeys then return end
			local code = input.KeyCode
			if code == KeyBinds.AirDash then
				Notify(DoAirDash(), Theme.AccentAlt)
			elseif code == KeyBinds.Slide then
				Notify(StartSlide(), Theme.AccentAlt)
			elseif code == KeyBinds.FreeCam then
				States.FreeCam = not States.FreeCam
				if ToggleRefreshers.FreeCam then ToggleRefreshers.FreeCam() end
				Notify("Free Cam: " .. (States.FreeCam and "ON" or "OFF"), Theme.Accent)
			elseif code == KeyBinds.ShiftLock then
				States.ShiftLock = not States.ShiftLock
				if ToggleRefreshers.ShiftLock then ToggleRefreshers.ShiftLock() end
				Notify("Shift Lock: " .. (States.ShiftLock and "ON" or "OFF"), Theme.Accent)
			end
		end)

		-- ===== hàng UI đợt A =====
		local M, C, Mi = Pg("Move"), Pg("Cam"), Pg("Misc")
		Info5(M, 19, "Phím: C cúi người | V trượt | E air dash | P free cam | Z shift lock | T emote wheel (đổi trong tab Set). Trên mobile hãy bật feature rồi dùng nút ảo góc phải.", 44)
		ToggleBtn(M, "Hover Moves Sideways", "HoverMove", 20)
		ToggleBtn(M, "Air Control", "AirCtl", 21)
		SliderRow(M, "Air Control %", "AirCtlPct", 0, 100, 22)
		ToggleBtn(M, "Air Dash", "AirDash", 23)
		SliderRow(M, "Air Dash Power", "AirDashPow", 30, 300, 24)
		ActionBtn(M, "Air Dash Now", 25, function() return DoAirDash() end)
		ToggleBtn(M, "Slide", "Slide", 26)
		SliderRow(M, "Slide Speed", "SlideSpeed", 16, 200, 27)
		SliderRow(M, "Slide Time (s)", "SlideTime", 1, 5, 28)
		ActionBtn(M, "Slide Now", 29, function() return StartSlide() end)
		ToggleBtn(M, "Stamina Bar (Sprint/Dash/Slide)", "StaminaOn", 30)
		ToggleBtn(M, "Crouch (hold key)", "CrouchOn", 31)
		SliderRow(M, "Crouch Speed %", "CrouchPct", 10, 90, 32)
		ToggleBtn(M, "Climb Speed", "ClimbSpeedOn", 33)
		SliderRow(M, "Climb Speed", "ClimbSpeed", 16, 100, 34)
		ToggleBtn(M, "Limit Fall Speed", "FallCap", 35)
		SliderRow(M, "Max Fall Speed", "MaxFall", 20, 200, 36)
		ToggleBtn(M, "Swim Speed", "SwimSpeedOn", 37)
		SliderRow(M, "Swim Speed", "SwimSpeed", 16, 100, 38)

		ToggleBtn(C, "Free Cam", "FreeCam", 20)
		SliderRow(C, "Free Cam Speed", "FreeSpeed", 10, 300, 21)
		ToggleBtn(C, "Shift Lock (client)", "ShiftLock", 22)
		ToggleBtn(C, "Camera Smoothing", "CamSmooth", 23)
		SliderRow(C, "Smoothing % (nhỏ = mượt)", "SmoothPct", 5, 95, 24)
		ToggleBtn(C, "Reduce Camera Shake", "CamShakeDamp", 25)
		SliderRow(C, "Shake Damping %", "ShakePct", 10, 95, 26)
		ToggleBtn(C, "Camera Offset", "CamOffset", 27)
		SliderRow(C, "Camera Offset Up", "CamOffY", -10, 10, 28)
		SliderRow(C, "Camera Offset Side", "CamOffX", -8, 8, 29)
		Info5(C, 30, "Free Cam: WASD di chuyển, Space lên, Ctrl xuống, giữ chuột phải (hoặc kéo màn hình trên mobile) để nhìn. Shift Lock là bản mô phỏng phía client.", 44)

		SliderRow(Mi, "Spin Speed (10 = mặc định)", "SpinRate", 0, 60, 20)

		-- tooltip cho các row của đợt A (mục 126)
		Tips["hover moves sideways"] = "Cho phép Hover bay ngang khi di chuyển; tắt lại thì đứng yên y như cũ."
		Tips["air control"] = "Tăng độ kiểm soát khi đang trên không: giữ phím chuyển hướng thì nhân vật bám theo nhanh hơn."
		Tips["air dash"] = "Lao đi trên không theo hướng nhìn (phím E hoặc nút AIR DASH). Có cooldown và tốn stamina."
		Tips["slide"] = "Trượt nhanh trên mặt đất theo hướng di chuyển (phím V). Hết giờ hoặc nhảy lên là hết trượt."
		Tips["stamina bar (sprint/dash/slide)"] = "Thanh thể lực dưới màn hình; hết stamina thì sprint/dash/slide bị chặn đến khi hồi lại."
		Tips["crouch (hold key)"] = "Giữ phím C (hoặc nút CROUCH) để đi chậm lại + hạ camera một chút."
		Tips["climb speed"] = "Đổi tốc độ leo thang / dây thừng (chỉ áp dụng khi đang leo)."
		Tips["limit fall speed"] = "Giới hạn tốc độ rơi tối đa để khỏi " .. "lao xuống quá nhanh."
		Tips["swim speed"] = "Đổi tốc độ bơi (chỉ áp dụng khi trạng thái Swimming)."
		Tips["free cam"] = "Camera tự do: nhân vật đứng yên, bạn bay camera quanh map bằng WASD + Space/Ctrl."
		Tips["shift lock (client)"] = "Mô phỏng Shift Lock phía client: nhân vật tự xoay theo hướng camera khi di chuyển. Roblox không có API shift lock chính thức nên đây là bản thay thế."
		Tips["camera smoothing"] = "Làm mượt thao tác quay camera (low-pass). Tắt ngay nếu thấy camera bị trễ."
		Tips["reduce camera shake"] = "Giảm rung/tung camera do game tạo ra bằng cách lọc dao động tần suất cao. Không tắt được 100% vì Roblox không có API tắt shake."
		Tips["camera offset"] = "Đẩy camera sang ngang / lên xuống so với nhân vật (không đổi góc nhìn zoom)."
		Tips["spin speed (10 = mặc định)"] = "Tốc độ quay của tính năng Spin ở tab Misc; 10 = 0.1 rad/khung hình như bản cũ."

		table.insert(Drivers, MoveDriver)
		table.insert(CamDrivers, CamDriver)
	end

	-- ==================== ĐỢT B: HUD + Light + Perf + Util ====================
	do
		-- --- key mới ---
		local BStates = {
			HUDPing = false, HUDFPS = false, HUDMini = false, HUDKeys = false, HUDCPS = false,
			OwnSunRays = false, LowMesh = false, FarAnim = false, HideGameGUI = false,
			ClipHistory = false, ChatQuick = false, EmoteWheel = false,
		}
		for k, v in pairs(BStates) do
			if States[k] == nil then States[k] = v end
		end
		local BSliders = {MiniRange = 150, FarAnimDist = 120, SunInt = 10}
		for k, v in pairs(BSliders) do
			if Sliders[k] == nil then Sliders[k] = v end
		end
		SaveExclude.EmoteWheel = true -- không tự bật lại bánh xe emote ở lần vào sau
		LoadKeys(BStates, BSliders)

		local prevB = {}
		local function edgeB(k, v)
			local old = prevB[k] or false
			prevB[k] = v
			return old ~= v
		end

		local pingG, fpsG, miniG, keysUi, cpsLbl, wheel, clipPanel = nil, nil, nil, nil, nil, nil, nil
		local clickTimes = {}
		local inpConn, worldConn, pgConn = nil, nil, nil
		local npcSet, frozenTracks = {}, {}
		local frames = 0
		local lastFpsT = 0
		local pingVals, fpsVals = {}, {}

		-- tạo / hủy 1 effect trong Lighting (giống EnsureEffect của v4.0)
		local function ensureFx(class, name, on)
			local e = Lighting:FindFirstChild(name)
			if on then
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

		-- ===== 103: gửi chat qua TextChatService (KHÔNG dùng Remote) =====
		local function SendChat(text)
			if type(text) ~= "string" or text == "" then return "Enter text" end
			if #text > 200 then text = text:sub(1, 200) end
			local ok, err = pcall(function()
				if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
					error("legacy chat")
				end
				local tc = TextChatService:FindFirstChild("TextChannels")
				local ch = tc and tc:FindFirstChild("RBXGeneral")
				if not ch then error("no RBXGeneral") end
				ch:SendAsync(text)
			end)
			if not ok then Log("chat: " .. tostring(err)) end
			return ok and "Sent!" or "Không hỗ trợ"
		end

		-- ===== 88 / 95: biểu đồ dạng thanh dọc =====
		local function buildGraph(title, y, color)
			local f = Instance.new("Frame")
			f.Size = UDim2.new(0, 164, 0, 70)
			f.Position = UDim2.new(0, 16, 0, y)
			f.BackgroundColor3 = Theme.Background
			f.BackgroundTransparency = 0.3
			f.BorderSizePixel = 0
			f.Parent = V5Gui
			Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
			local lbl = Instance.new("TextLabel", f)
			lbl.Size = UDim2.new(1, -8, 0, 16)
			lbl.Position = UDim2.new(0, 6, 0, 2)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.GothamBold
			lbl.TextSize = 11
			lbl.TextColor3 = Theme.Text
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Text = title
			local bars = {}
			for i = 1, 40 do
				local b = Instance.new("Frame", f)
				b.AnchorPoint = Vector2.new(0, 1)
				b.Size = UDim2.new(0, 3, 0, 2)
				b.Position = UDim2.new(0, 4 + (i - 1) * 4, 1, -4)
				b.BackgroundColor3 = color
				b.BorderSizePixel = 0
				bars[i] = b
			end
			return {frame = f, label = lbl, bars = bars}
		end

		local function drawGraph(g, vals, maxV)
			if not g then return end
			for i = 1, 40 do
				local v = vals[i] or 0
				local h = math.clamp(v / maxV, 0, 1) * 46
				g.bars[i].Size = UDim2.new(0, 3, 0, math.max(2, h))
			end
		end

		-- ===== 90: minimap đơn giản =====
		local function buildMini()
			if miniG then return end
			local f = Instance.new("Frame")
			f.Size = UDim2.new(0, 140, 0, 140)
			f.Position = UDim2.new(0, 16, 0, 156)
			f.BackgroundColor3 = Theme.Background
			f.BackgroundTransparency = 0.3
			f.BorderSizePixel = 0
			f.Parent = V5Gui
			Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
			local st = Instance.new("UIStroke", f)
			st.Color = Theme.Accent
			st.Thickness = 1.5
			local me = Instance.new("Frame", f)
			me.AnchorPoint = Vector2.new(0.5, 0.5)
			me.Position = UDim2.new(0.5, 0, 0.5, 0)
			me.Size = UDim2.new(0, 8, 0, 8)
			me.BackgroundColor3 = Theme.AccentAlt
			me.BorderSizePixel = 0
			Instance.new("UICorner", me).CornerRadius = UDim.new(1, 0)
			local dots = {}
			for i = 1, 24 do
				local d = Instance.new("Frame", f)
				d.AnchorPoint = Vector2.new(0.5, 0.5)
				d.Position = UDim2.new(0.5, 0, 0.5, 0)
				d.Size = UDim2.new(0, 7, 0, 7)
				d.BackgroundColor3 = Theme.Danger
				d.BorderSizePixel = 0
				d.Visible = false
				Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
				dots[i] = d
			end
			miniG = {frame = f, dots = dots}
		end

		-- ===== 92: hiển thị phím bấm =====
		local keyMap = {
			W = Enum.KeyCode.W, A = Enum.KeyCode.A, S = Enum.KeyCode.S,
			D = Enum.KeyCode.D, SPACE = Enum.KeyCode.Space,
		}
		local function buildKeys()
			if keysUi then return end
			local f = Instance.new("Frame")
			f.Size = UDim2.new(0, 150, 0, 136)
			f.AnchorPoint = Vector2.new(0, 1)
			f.Position = UDim2.new(0, 16, 1, -16)
			f.BackgroundTransparency = 1
			f.Parent = V5Gui
			local boxes = {}
			local function key(name, x, y, w, h)
				local b = Instance.new("TextButton", f)
				b.Size = UDim2.new(0, w, 0, h)
				b.Position = UDim2.new(0, x, 0, y)
				b.Text = name
				b.Font = Enum.Font.GothamBold
				b.TextSize = 13
				b.TextColor3 = Theme.Text
				b.BackgroundColor3 = Theme.Panel
				b.BackgroundTransparency = 0.15
				b.BorderSizePixel = 0
				b.AutoButtonColor = false
				b.Active = false
				Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
				boxes[name] = b
			end
			key("W", 50, 4, 40, 40)
			key("A", 6, 48, 40, 40)
			key("S", 50, 48, 40, 40)
			key("D", 94, 48, 40, 40)
			key("SPACE", 6, 92, 128, 36)
			keysUi = {frame = f, boxes = boxes}
		end

		local function refreshKeys()
			if not keysUi then return end
			for name, b in pairs(keysUi.boxes) do
				local kc = keyMap[name]
				local down = kc and UIS:IsKeyDown(kc)
				b.BackgroundColor3 = down and Theme.Accent or Theme.Panel
			end
		end

		-- ===== 93: bộ đếm CPS =====
		local function buildCPS()
			if cpsLbl then return end
			local f = Instance.new("Frame")
			f.Size = UDim2.new(0, 140, 0, 34)
			f.AnchorPoint = Vector2.new(0, 1)
			f.Position = UDim2.new(0, 16, 1, -158)
			f.BackgroundColor3 = Theme.Background
			f.BackgroundTransparency = 0.3
			f.BorderSizePixel = 0
			f.Parent = V5Gui
			Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
			local lbl = Instance.new("TextLabel", f)
			lbl.Size = UDim2.new(1, -12, 1, 0)
			lbl.Position = UDim2.new(0, 8, 0, 0)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.GothamBold
			lbl.TextSize = 13
			lbl.TextColor3 = Theme.Text
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Text = "CPS: 0"
			cpsLbl = {frame = f, label = lbl}
		end

		-- ===== 104: bánh xe emote =====
		local emoteDefs = {
			{"Wave", "wave"}, {"Point", "point"}, {"Cheer", "cheer"},
			{"Laugh", "laugh"}, {"Dance", "dance"}, {"Dance 2", "dance2"},
		}
		local function buildWheel()
			if wheel then return end
			local f = Instance.new("Frame")
			f.Size = UDim2.new(0, 224, 0, 224)
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.new(0.5, 0, 0.55, 0)
			f.BackgroundTransparency = 1
			f.Parent = V5Gui
			for i, d in ipairs(emoteDefs) do
				local cmd = d[2] -- local riêng mỗi vòng (closure)
				local angle = (i - 1) / #emoteDefs * math.pi * 2 - math.pi / 2
				local b = Instance.new("TextButton", f)
				b.AnchorPoint = Vector2.new(0.5, 0.5)
				b.Size = UDim2.new(0, 58, 0, 58)
				b.Position = UDim2.new(0.5, math.cos(angle) * 80, 0.5, math.sin(angle) * 80)
				b.Text = d[1]
				b.Font = Enum.Font.GothamBold
				b.TextSize = 12
				b.TextColor3 = Theme.Text
				b.BackgroundColor3 = Theme.Panel
				b.BorderSizePixel = 0
				b.AutoButtonColor = false
				Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
				local st = Instance.new("UIStroke", b)
				st.Color = Theme.Accent
				b.MouseButton1Click:Connect(function()
					Notify(SendChat("/e " .. cmd), Theme.On)
				end)
			end
			local c = Instance.new("TextButton", f)
			c.AnchorPoint = Vector2.new(0.5, 0.5)
			c.Position = UDim2.new(0.5, 0, 0.5, 0)
			c.Size = UDim2.new(0, 64, 0, 64)
			c.Text = "X"
			c.Font = Enum.Font.GothamBold
			c.TextSize = 16
			c.TextColor3 = Theme.Text
			c.BackgroundColor3 = Theme.Danger
			c.BorderSizePixel = 0
			c.AutoButtonColor = false
			Instance.new("UICorner", c).CornerRadius = UDim.new(1, 0)
			c.MouseButton1Click:Connect(function()
				States.EmoteWheel = false
				if ToggleRefreshers.EmoteWheel then ToggleRefreshers.EmoteWheel() end
			end)
			wheel = f
			table.insert(UIBoxes, f)
		end

		-- ===== 102: lịch sử clipboard =====
		local clipHist = {}
		local function refreshClipUI()
			if not clipPanel then return end
			for _, ch in ipairs(clipPanel:GetChildren()) do
				if not ch:IsA("UIListLayout") then ch:Destroy() end
			end
			if #clipHist == 0 then
				local l = Instance.new("TextLabel", clipPanel)
				l.Size = UDim2.new(1, -6, 0, 30)
				l.LayoutOrder = 1
				l.BackgroundTransparency = 1
				l.Font = Enum.Font.Gotham
				l.TextSize = 12
				l.TextColor3 = Theme.SubText
				l.Text = "(trống - copy gì đó từ tính năng khác sẽ hiện ở đây)"
				return
			end
			for i, txt in ipairs(clipHist) do
				local full = tostring(txt)
				local b = Instance.new("TextButton", clipPanel)
				b.Size = UDim2.new(1, -6, 0, 30)
				b.LayoutOrder = i
				b.Font = Enum.Font.Gotham
				b.TextSize = 12
				b.TextColor3 = Theme.Text
				b.BackgroundColor3 = Theme.Background
				b.BorderSizePixel = 0
				b.AutoButtonColor = false
				b.TextXAlignment = Enum.TextXAlignment.Left
				local oneLine = string.gsub(full, "\n", " ")
				if #oneLine > 54 then oneLine = oneLine:sub(1, 54) .. "..." end
				b.Text = "  " .. oneLine
				Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
				b.MouseButton1Click:Connect(function()
					Clip5(full) -- bấm để copy lại mục này
				end)
			end
		end
		local function buildClipPanel()
			if clipPanel then return end
			local sf = Instance.new("ScrollingFrame")
			sf.Size = UDim2.new(1, 0, 0, 130)
			sf.LayoutOrder = 21
			sf.BackgroundColor3 = Theme.Panel
			sf.BorderSizePixel = 0
			sf.ScrollBarThickness = 3
			sf.ScrollBarImageColor3 = Theme.Accent
			sf.CanvasSize = UDim2.new(0, 0, 0, 0)
			sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
			sf.Parent = Pg("Util")
			Instance.new("UICorner", sf).CornerRadius = UDim.new(0, 8)
			local layout = Instance.new("UIListLayout", sf)
			layout.Padding = UDim.new(0, 4)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			clipPanel = sf
			refreshClipUI()
		end

		-- bọc Clip5 để mọi copy của v4.1 đều vào lịch sử
		local rawClip5 = Clip5
		Clip5 = function(text)
			if clipHist[1] ~= tostring(text) then
				table.insert(clipHist, 1, tostring(text))
				if #clipHist > 30 then table.remove(clipHist) end
				refreshClipUI()
			end
			return rawClip5(text)
		end

		-- ===== 72: Sky preset =====
		local SkySaved, SkyCreated, skyIdx = nil, nil, 0
		local SkyPresets = {
			{
				name = "Clear Blue",
				box = {
					"rbxasset://textures/sky/sky512_bk.tex", "rbxasset://textures/sky/sky512_dn.tex",
					"rbxasset://textures/sky/sky512_ft.tex", "rbxasset://textures/sky/sky512_lf.tex",
					"rbxasset://textures/sky/sky512_rt.tex", "rbxasset://textures/sky/sky512_up.tex",
				},
				clock = 13, amb = Color3.fromRGB(150, 165, 190), bright = 3,
			},
			{name = "Sunset", clock = 17.6, amb = Color3.fromRGB(255, 165, 110), bright = 2, fog = 4000},
			{name = "Night", clock = 0, amb = Color3.fromRGB(45, 50, 80), bright = 1, star = 6000},
			{name = "Foggy", clock = 9, amb = Color3.fromRGB(190, 190, 195), bright = 2, fog = 450,
				atmo = {density = 0.55, haze = 3, color = Color3.fromRGB(200, 200, 210)}},
			{name = "Dark Red", clock = 21, amb = Color3.fromRGB(120, 40, 45), bright = 1.5, star = 3000},
		}
		local function saveSky()
			if SkySaved then return end
			local s = Lighting:FindFirstChildOfClass("Sky")
			SkySaved = {
				clock = Lighting.ClockTime, amb = Lighting.Ambient, out = Lighting.OutdoorAmbient,
				bright = Lighting.Brightness, fogE = Lighting.FogEnd, fogS = Lighting.FogStart,
				obj = s,
			}
			if s then
				SkySaved.props = {
					Bk = s.SkyboxBk, Dn = s.SkyboxDn, Ft = s.SkyboxFt,
					Lf = s.SkyboxLf, Rt = s.SkyboxRt, Up = s.SkyboxUp,
					star = s.StarCount, bodies = s.CelestialBodiesShown,
				}
			end
		end
		local function resetSky()
			if not SkySaved then return false end
			Lighting.ClockTime = SkySaved.clock
			Lighting.Ambient = SkySaved.amb
			Lighting.OutdoorAmbient = SkySaved.out
			Lighting.Brightness = SkySaved.bright
			Lighting.FogEnd = SkySaved.fogE
			Lighting.FogStart = SkySaved.fogS
			if SkySaved.props and SkySaved.obj and SkySaved.obj.Parent then
				local p, s = SkySaved.props, SkySaved.obj
				s.SkyboxBk, s.SkyboxDn, s.SkyboxFt = p.Bk, p.Dn, p.Ft
				s.SkyboxLf, s.SkyboxRt, s.SkyboxUp = p.Lf, p.Rt, p.Up
				s.StarCount = p.star
				s.CelestialBodiesShown = p.bodies
			end
			if SkyCreated then SkyCreated:Destroy(); SkyCreated = nil end
			local a = Lighting:FindFirstChild("JH_SkyAtmos")
			if a then a:Destroy() end
			SkySaved = nil
			return true
		end
		local function applySkyPreset()
			saveSky()
			skyIdx = skyIdx % #SkyPresets + 1
			local p = SkyPresets[skyIdx]
			if p.clock then Lighting.ClockTime = p.clock end
			if p.amb then
				Lighting.Ambient = p.amb
				Lighting.OutdoorAmbient = p.amb
			end
			if p.bright then Lighting.Brightness = p.bright end
			if p.fog then Lighting.FogStart = 0; Lighting.FogEnd = p.fog end
			local s = Lighting:FindFirstChildOfClass("Sky")
			if p.box then
				if not s then
					s = Instance.new("Sky")
					s.Name = "JH_Sky"
					s.Parent = Lighting
					SkyCreated = s
				end
				s.SkyboxBk, s.SkyboxDn, s.SkyboxFt = p.box[1], p.box[2], p.box[3]
				s.SkyboxLf, s.SkyboxRt, s.SkyboxUp = p.box[4], p.box[5], p.box[6]
			end
			if p.star and s then
				s.StarCount = p.star
				s.CelestialBodiesShown = true
			end
			local a = ensureFx("Atmosphere", "JH_SkyAtmos", p.atmo ~= nil)
			if a and p.atmo then
				a.Density = p.atmo.density
				a.Haze = p.atmo.haze
				a.Color = p.atmo.color
			end
			return p.name
		end

		-- ===== 80: lưu / tải preset ánh sáng =====
		local LIGHT_FILE = "JumpHub_LightPreset.json"
		local function c2t(c) return {r = c.R, g = c.G, b = c.B} end
		local function t2c(t)
			return Color3.fromRGB(
				math.floor((t.r or 1) * 255 + 0.5),
				math.floor((t.g or 1) * 255 + 0.5),
				math.floor((t.b or 1) * 255 + 0.5)
			)
		end
		local LightKeys = {
			"TimeLock", "DayCycle", "CustomBright", "CustomExposure", "CustomFog",
			"OwnBloom", "OwnColor", "OwnBlur", "OwnSunRays", "Fullbright",
		}
		local LightSliderKeys = {
			"TimeOfDay", "CycleSpeed", "Brightness", "ExposureX10", "FogEndCustom",
			"BloomInt", "Saturation", "Contrast", "BlurSize", "SunInt",
		}
		local function saveLightPreset()
			if typeof(writefile) ~= "function" then return "Không hỗ trợ" end
			local snap = {
				clock = Lighting.ClockTime, bright = Lighting.Brightness,
				amb = c2t(Lighting.Ambient), out = c2t(Lighting.OutdoorAmbient),
				fogS = Lighting.FogStart, fogE = Lighting.FogEnd,
				expo = Lighting.ExposureCompensation,
				States = {}, Sliders = {},
			}
			for _, k in ipairs(LightKeys) do snap.States[k] = States[k] == true end
			for _, k in ipairs(LightSliderKeys) do snap.Sliders[k] = Sliders[k] or 0 end
			local ok = pcall(function() writefile(LIGHT_FILE, HttpService:JSONEncode(snap)) end)
			return ok and "Light preset saved!" or "Save failed"
		end
		local function loadLightPreset()
			if typeof(readfile) ~= "function" or not isfile(LIGHT_FILE) then return "No saved preset" end
			local ok, snap = pcall(function() return HttpService:JSONDecode(readfile(LIGHT_FILE)) end)
			if not ok or type(snap) ~= "table" then return "Load failed" end
			Lighting.ClockTime = tonumber(snap.clock) or Lighting.ClockTime
			Lighting.Brightness = tonumber(snap.bright) or Lighting.Brightness
			if type(snap.amb) == "table" then Lighting.Ambient = t2c(snap.amb) end
			if type(snap.out) == "table" then Lighting.OutdoorAmbient = t2c(snap.out) end
			Lighting.FogStart = tonumber(snap.fogS) or Lighting.FogStart
			Lighting.FogEnd = tonumber(snap.fogE) or Lighting.FogEnd
			Lighting.ExposureCompensation = tonumber(snap.expo) or Lighting.ExposureCompensation
			for _, k in ipairs(LightKeys) do
				if type(snap.States) == "table" and type(snap.States[k]) == "boolean" then
					States[k] = snap.States[k]
					if ToggleRefreshers[k] then ToggleRefreshers[k]() end
				end
			end
			for _, k in ipairs(LightSliderKeys) do
				if type(snap.Sliders) == "table" and type(snap.Sliders[k]) == "number" then
					Sliders[k] = snap.Sliders[k]
				end
			end
			return "Light preset loaded!"
		end

		-- ===== 56: giảm chi tiết mesh =====
		local function applyMesh(v)
			if not v:IsA("MeshPart") then return end
			if v:GetAttribute("_JH_OrigFid") == nil then
				v:SetAttribute("_JH_OrigFid", v.RenderFidelity.Name)
				pcall(function() v.RenderFidelity = Enum.RenderFidelity.Performance end)
			end
		end
		local function setLowMesh(on)
			if on then
				local n = 0
				for _, v in ipairs(workspace:GetDescendants()) do
					applyMesh(v)
					n += 1
					if n % 1500 == 0 then task.wait() end -- chia nhỏ để không gây khựng frame
				end
			else
				for _, v in ipairs(workspace:GetDescendants()) do
					local orig = v:GetAttribute("_JH_OrigFid")
					if orig then
						pcall(function() v.RenderFidelity = Enum.RenderFidelity[orig] end)
						v:SetAttribute("_JH_OrigFid", nil)
					end
				end
			end
		end

		-- ===== 63: đóng băng animation NPC ở xa =====
		local function scanNpcs()
			local n = 0
			for _, v in ipairs(workspace:GetDescendants()) do
				if v:IsA("Humanoid") and v.Parent and Players:GetPlayerFromCharacter(v.Parent) == nil then
					npcSet[v.Parent] = true
				end
				n += 1
				if n % 1500 == 0 then task.wait() end
			end
		end
		local function restoreFarAnim()
			for t in pairs(frozenTracks) do
				if t.Parent then pcall(function() t:AdjustSpeed(1) end) end
			end
			table.clear(frozenTracks)
			table.clear(npcSet)
		end
		local function sweepFarAnim(root)
			local dist = Sliders.FarAnimDist
			for model in pairs(npcSet) do
				if not model or not model.Parent then
					npcSet[model] = nil
				else
					local hrp = model:FindFirstChild("HumanoidRootPart")
					local far = hrp ~= nil and (hrp.Position - root.Position).Magnitude > dist
					local animator = model:FindFirstChildWhichIsA("Animator", true)
					if animator then
						for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
							if far and not frozenTracks[track] then
								frozenTracks[track] = true
								pcall(function() track:AdjustSpeed(0) end)
							elseif not far and frozenTracks[track] then
								frozenTracks[track] = nil
								pcall(function() track:AdjustSpeed(1) end)
							end
						end
					end
				end
			end
		end

		-- ===== 65: ẩn GUI nặng của game theo tên =====
		local guiPatterns = {}
		local ourGuis = {
			JumpHub = true, JumpHubToggle = true, JumpHubHUD = true,
			JumpHubOverlay = true, JumpHubV5 = true,
		}
		local function parsePatterns(txt)
			guiPatterns = {}
			for w in tostring(txt):gmatch("[^,;]+") do
				w = w:match("^%s*(.-)%s*$"):lower()
				if w ~= "" then table.insert(guiPatterns, w) end
			end
		end
		local function hideOneGui(g)
			if not g:IsA("ScreenGui") or ourGuis[g.Name] then return end
			if #guiPatterns == 0 then return end
			local n = g.Name:lower()
			for _, p in ipairs(guiPatterns) do
				if n:find(p, 1, true) then
					if g.Enabled then
						g:SetAttribute("_JH_GuiWasOn", true)
						g.Enabled = false
					end
					return
				end
			end
		end
		local function setHideGuis(on)
			if on then
				for _, g in ipairs(PlayerGui:GetChildren()) do hideOneGui(g) end
			else
				for _, g in ipairs(PlayerGui:GetChildren()) do
					if g:GetAttribute("_JH_GuiWasOn") then
						g.Enabled = true
						g:SetAttribute("_JH_GuiWasOn", nil)
					end
				end
			end
		end

		-- một cặp connection duy nhất cho 3 tính năng bật theo toggle
		local function onDesc(v)
			if States.LowMesh then applyMesh(v) end
			if States.HideGameGUI and v:IsA("ScreenGui") then hideOneGui(v) end
			if States.FarAnim and v:IsA("Humanoid") and v.Parent and Players:GetPlayerFromCharacter(v.Parent) == nil then
				npcSet[v.Parent] = true
			end
		end
		local function syncConns()
			local want = States.LowMesh or States.HideGameGUI or States.FarAnim
			if want and not worldConn then
				worldConn = workspace.DescendantAdded:Connect(onDesc)
				pgConn = PlayerGui.DescendantAdded:Connect(onDesc)
			elseif not want and worldConn then
				worldConn:Disconnect(); worldConn = nil
				pgConn:Disconnect(); pgConn = nil
			end
			local wantInp = States.HUDCPS or States.HUDKeys
			if wantInp and not inpConn then
				inpConn = UIS.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1
						or input.UserInputType == Enum.UserInputType.Touch then
						table.insert(clickTimes, tick())
					end
				end)
			elseif not wantInp and inpConn then
				inpConn:Disconnect(); inpConn = nil
				table.clear(clickTimes)
			end
		end

		-- ===== driver của đợt B =====
		local function BDriver(dt, c)
			-- widget bật/tắt (tạo khi bật, Destroy khi tắt)
			if edgeB("ping", States.HUDPing) then
				if States.HUDPing then pingG = buildGraph("PING (ms)", 8, Theme.AccentAlt)
				elseif pingG then pingG.frame:Destroy(); pingG = nil end
			end
			if edgeB("fps", States.HUDFPS) then
				if States.HUDFPS then fpsG = buildGraph("FPS", 80, Theme.On)
				elseif fpsG then fpsG.frame:Destroy(); fpsG = nil end
			end
			if edgeB("mini", States.HUDMini) then
				if States.HUDMini then buildMini()
				elseif miniG then miniG.frame:Destroy(); miniG = nil end
			end
			if edgeB("keys", States.HUDKeys) then
				if States.HUDKeys then buildKeys()
				elseif keysUi then keysUi.frame:Destroy(); keysUi = nil end
			end
			if edgeB("cps", States.HUDCPS) then
				if States.HUDCPS then buildCPS()
				elseif cpsLbl then cpsLbl.frame:Destroy(); cpsLbl = nil end
			end
			if edgeB("wheel", States.EmoteWheel) then
				if States.EmoteWheel then buildWheel()
				elseif wheel then wheel:Destroy(); wheel = nil end
			end
			if edgeB("clip", States.ClipHistory) then
				if States.ClipHistory then buildClipPanel()
				elseif clipPanel then clipPanel:Destroy(); clipPanel = nil end
			end

			-- 56 / 63 / 65: bật = quét 1 lần + gắn connection; tắt = khôi phục
			if edgeB("lowmesh", States.LowMesh) then task.spawn(setLowMesh, States.LowMesh) end
			if edgeB("faranim", States.FarAnim) then
				if States.FarAnim then task.spawn(scanNpcs) else restoreFarAnim() end
			end
			if edgeB("hidegui", States.HideGameGUI) then
				setHideGuis(States.HideGameGUI)
			end
			syncConns()

			-- 92: hiện trạng thái phím mỗi frame
			if keysUi then refreshKeys() end

			-- 93: CPS
			if cpsLbl then
				local cutoff = tick() - 1
				for i = #clickTimes, 1, -1 do
					if clickTimes[i] < cutoff then table.remove(clickTimes, i) end
				end
				cpsLbl.label.Text = "CPS: " .. #clickTimes
			end
		end

		local function BSlow(now, c)
			frames += 1
			local elapsed = now - lastFpsT
			lastFpsT = now

			-- 88: ping
			if pingG then
				local ok, ms = pcall(function()
					return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
				end)
				local v = ok and math.floor(ms) or 0
				pingVals[#pingVals + 1] = v
				if #pingVals > 40 then table.remove(pingVals, 1) end
				pingG.label.Text = "PING " .. v .. " ms"
				drawGraph(pingG, pingVals, 300)
			end

			-- 95: FPS
			if fpsG then
				local fps = 0
				if elapsed > 0 then fps = math.floor(frames / elapsed + 0.5) end
				frames = 0
				fpsVals[#fpsVals + 1] = fps
				if #fpsVals > 40 then table.remove(fpsVals, 1) end
				fpsG.label.Text = "FPS " .. fps
				drawGraph(fpsG, fpsVals, 120)
			else
				frames = 0
			end

			-- 90: minimap
			if miniG and c.root then
				local yaw = 0
				if c.cam then
					local _, ry = c.cam.CFrame:ToEulerAnglesYXZ()
					yaw = ry
				end
				local ca, sa = math.cos(yaw), math.sin(yaw)
				local myPos = c.root.Position
				local scale = 64 / math.max(20, Sliders.MiniRange)
				local n = 0
				for _, plr in ipairs(Players:GetPlayers()) do
					local r = plr ~= Player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
					if r and n < 24 then
						local dx, dz = r.Position.X - myPos.X, r.Position.Z - myPos.Z
						local rx = dx * ca - dz * sa
						local rz = dx * sa + dz * ca
						n = n + 1
						local d = miniG.dots[n]
						d.Visible = true
						d.Position = UDim2.new(0.5, math.clamp(rx * scale, -64, 64), 0.5, math.clamp(rz * scale, -64, 64))
					end
				end
				for i = n + 1, 24 do miniG.dots[i].Visible = false end
			end

			-- 77: Sun Rays
			if States.OwnSunRays then
				local e = ensureFx("SunRaysEffect", "JH_SunRays", true)
				if e then
					e.Intensity = Sliders.SunInt / 10
					e.Spread = 8
					e.Size = 1.2
				end
			elseif Lighting:FindFirstChild("JH_SunRays") then
				ensureFx("SunRaysEffect", "JH_SunRays", false)
			end

			-- 63: quét NPC định kỳ (4 lần/giây, chỉ danh sách NPC đã biết)
			if States.FarAnim and c.root then sweepFarAnim(c.root) end
		end

		-- ===== hàng UI đợt B =====
		local H, L, F, U, FN = Pg("HUD"), Pg("Light"), Pg("FPS"), Pg("Util"), Pg("Fun")

		ToggleBtn(H, "Ping Graph", "HUDPing", 20)
		ToggleBtn(H, "FPS Graph", "HUDFPS", 21)
		ToggleBtn(H, "Minimap", "HUDMini", 22)
		SliderRow(H, "Minimap Range (studs)", "MiniRange", 30, 500, 23)
		ToggleBtn(H, "Keystrokes (WASD)", "HUDKeys", 24)
		ToggleBtn(H, "CPS Counter", "HUDCPS", 25)

		ActionBtn(L, "Sky Preset (tap to cycle)", 30, function()
			return "Sky: " .. applySkyPreset()
		end)
		ActionBtn(L, "Reset Sky / Lighting", 31, function()
			return resetSky() and "Sky reset" or "Nothing to reset"
		end)
		ToggleBtn(L, "Sun Rays", "OwnSunRays", 32)
		SliderRow(L, "Sun Rays Intensity (x10)", "SunInt", 1, 30, 33)
		ActionBtn(L, "Save Light Preset", 34, saveLightPreset)
		ActionBtn(L, "Load Light Preset", 35, loadLightPreset)

		ToggleBtn(F, "Reduce Mesh Detail (RenderFidelity)", "LowMesh", 30)
		ToggleBtn(F, "Freeze Far NPC Animations", "FarAnim", 31)
		SliderRow(F, "Far Animation Distance", "FarAnimDist", 20, 300, 32)
		ToggleBtn(F, "Hide Game GUIs by Name", "HideGameGUI", 33)
		do
			local guiBox = Row5(F, 34, "tên GUI, phân cách bằng dấu phẩy...", 36, false, function(box)
				parsePatterns(box.Text)
				if States.HideGameGUI then
					setHideGuis(false)
					setHideGuis(true)
				end
				Notify("Đã cập nhật danh sách GUI", Theme.On)
			end)
			guiBox.Text = "leaderboard, stats, shop"
			parsePatterns(guiBox.Text)
		end

		ToggleBtn(U, "Clipboard History", "ClipHistory", 20)
		ActionBtn(U, "Copy Whole History", 22, function()
			if #clipHist == 0 then return "History empty" end
			return Clip5(table.concat(clipHist, "\n"))
		end)
		ToggleBtn(U, "Quick Chat (TextChatService)", "ChatQuick", 23)
		do
			local chatBox = Row5(U, 24, "Gõ mẫu tin nhắn / lệnh (vd: /e dance)...", 36, false, nil)
			ActionBtn(U, "Send to Chat", 25, function()
				return SendChat(chatBox.Text)
			end)
			Info5(U, 26, "Dùng TextChatService chính thức của Roblox (tự lọc ký tự xấu). Game dùng chat cũ (legacy) sẽ báo Không hỗ trợ.", 44)
		end

		ToggleBtn(FN, "Emote Wheel", "EmoteWheel", 20)
		ActionBtn(FN, "Emote: Wave", 21, function() return SendChat("/e wave") end)
		ActionBtn(FN, "Emote: Dance", 22, function() return SendChat("/e dance") end)

		-- tooltip đợt B
		Tips["ping graph"] = "Biểu đồ ping 40 mẫu gần nhất (mỗi mẫu 0.25 giây)."
		Tips["fps graph"] = "Biểu đồ FPS theo thời gian, tự cập nhật 4 lần/giây."
		Tips["minimap"] = "Bản đồ nhỏ hiển thị người chơi xung quanh, xoay theo hướng camera."
		Tips["keystrokes (wasd)"] = "Hiện W/A/S/D + Space đang được nhấn (test phím trên PC)."
		Tips["cps counter"] = "Đếm số lần bấm chuột trái / chạm màn hình trong 1 giây qua lại."
		Tips["sky preset (tap to cycle)"] = "Đổi bầu trời + thời tiết: Clear Blue (skybox Roblox mặc định), Sunset, Night, Foggy, Dark Red. Bấm Reset Sky để về như cũ."
		Tips["sun rays"] = "Bật tia nắng mặt trời (SunRaysEffect) riêng của hub, không đụng effect của game."
		Tips["save light preset"] = "Lưu toàn bộ cài đặt ánh sáng vào file; Load để áp dụng lại. Cần executor có writefile."
		Tips["reduce mesh detail (renderfidelity)"] = "Đổi RenderFidelity của MeshPart sang Performance (mờ hơn nhưng nhanh hơn). Tắt sẽ khôi phục đúng giá trị cũ."
		Tips["freeze far npc animations"] = "Dừng animation của NPC/monster ở xa hơn khoảng cách để giảm CPU; lại gần là tự chạy lại."
		Tips["hide game guis by name"] = "Ẩn các ScreenGui của game khớp tên bạn nhập (vd: leaderboard, shop). Tắt toggle là hiện lại ngay."
		Tips["clipboard history"] = "Ghi lại các bản copy của v4.1 (copy vị trí, JobId, mã...) để dùng lại; bấm 1 mục là copy lại."
		Tips["quick chat (textchatservice)"] = "Gửi tin nhắn qua TextChatService:SendAsync - API chính thức, không dùng RemoteEvent."
		Tips["emote wheel"] = "Bánh xe 6 emote ở giữa màn hình; gửi lệnh /e qua chat. Phím tắt T."

		table.insert(Drivers, BDriver)
		table.insert(Slows, BSlow)
	end

	-- ==================== ĐỢT C: UI + Settings ====================
	do
		-- --- key mới (118, 122, 126, 129 + cài đặt) ---
		local CStates = {LightUI = false, TabIcons = false, Tooltips = true, Ripple = false}
		for k, v in pairs(CStates) do
			if States[k] == nil then States[k] = v end
		end
		LoadKeys(CStates, nil)

		-- tab Cài đặt mới (thứ 12, nằm cuối thanh tab cuộn)
		local PageSet = AddTab("Set", 12)

		-- nhớ phím mặc định TRƯỚC khi nạp file đã lưu (136)
		local DefaultKeyBinds = {}
		for a, kc in pairs(KeyBinds) do DefaultKeyBinds[a] = kc end

		-- ===== file lưu riêng của v4.1: yêu thích / keybind / ngôn ngữ / auto-start =====
		local V5FILE = "JumpHub_V5.json"
		local Favorites, AutoOn, Lang = {}, {}, "en"
		local function loadV5()
			pcall(function()
				if typeof(isfile) ~= "function" or typeof(readfile) ~= "function" then return end
				if not isfile(V5FILE) then return end
				local d = HttpService:JSONDecode(readfile(V5FILE))
				if type(d.Favorites) == "table" then Favorites = d.Favorites end
				if type(d.AutoOn) == "table" then AutoOn = d.AutoOn end
				if type(d.Lang) == "string" then Lang = d.Lang end
				if type(d.KeyBinds) == "table" then
					for action, code in pairs(d.KeyBinds) do
						if KeyBinds[action] ~= nil and type(code) == "string" then
							local ok, kc = pcall(function() return Enum.KeyCode[code] end)
							if ok and kc ~= nil then KeyBinds[action] = kc end
						end
					end
				end
			end)
		end
		local function saveV5()
			if typeof(writefile) ~= "function" then return "Khong ho tro (can writefile)" end
			local kb = {}
			for action, kc in pairs(KeyBinds) do kb[action] = kc.Name end
			local ok = pcall(function()
				writefile(V5FILE, HttpService:JSONEncode({
					Favorites = Favorites, AutoOn = AutoOn, Lang = Lang, KeyBinds = kb,
				}))
			end)
			return ok and "Da luu!" or "Save failed"
		end
		loadV5()

		-- 138: tự bật các tính năng đã chọn ngay khi vào game
		for _, k in ipairs(AutoOn) do
			if States[k] ~= nil then States[k] = true end
		end

		local prevC = {}
		local function edgeC(k, v)
			local old = prevC[k] or false
			prevC[k] = v
			return old ~= v
		end

		-- ===== 118: Theme Sáng (đổi Background/Panel/Text chứ không chỉ accent) =====
		local DarkPal = {
			Background = Color3.fromRGB(18, 18, 24), Panel = Color3.fromRGB(24, 24, 32),
			Text = Color3.fromRGB(235, 235, 245), SubText = Color3.fromRGB(150, 150, 165),
			Off = Color3.fromRGB(60, 60, 72),
		}
		local LightPal = {
			Background = Color3.fromRGB(233, 235, 241), Panel = Color3.fromRGB(255, 255, 255),
			Text = Color3.fromRGB(26, 27, 33), SubText = Color3.fromRGB(96, 99, 112),
			Off = Color3.fromRGB(202, 205, 216),
		}
		local function SetLightUI(on)
			local from = on and DarkPal or LightPal
			local to = on and LightPal or DarkPal
			local function map(c)
				for k, v in pairs(from) do
					if v == c then return to[k] end
				end
				return nil
			end
			local roots = {gui, ToggleGui, V5Gui}
			for _, n in ipairs({"JumpHubHUD", "JumpHubOverlay"}) do
				local g = PlayerGui:FindFirstChild(n)
				if g then table.insert(roots, g) end
			end
			for _, root in ipairs(roots) do
				for _, d in ipairs(root:GetDescendants()) do
					if d:IsA("GuiObject") then
						local n2 = map(d.BackgroundColor3)
						if n2 then d.BackgroundColor3 = n2 end
						if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
							n2 = map(d.TextColor3)
							if n2 then d.TextColor3 = n2 end
						end
						if d:IsA("TextBox") then
							n2 = map(d.PlaceholderColor3)
							if n2 then d.PlaceholderColor3 = n2 end
						end
					end
				end
			end
			for k, v in pairs(to) do Theme[k] = v end
		end

		-- ===== 122: icon cho từng tab =====
		local tabBase = {}
		local IconMap = {
			Move = "▶", Player = "●", Misc = "◆", FPS = "▲", Find = "○",
			Cam = "◎", HUD = "▤", Light = "◐", Util = "▩", Fun = "★",
			UI = "■", Set = "▦",
		}
		local function SetTabIcons(on)
			for _, t in ipairs(AllTabs) do
				if not tabBase[t] then tabBase[t] = t.Text end
				local base = tabBase[t]
				local icon = IconMap[base]
				t.Text = (on and icon) and (icon .. " " .. base) or base
			end
		end

		-- ===== 137: bảng dịch Việt/Anh (khớp với tên row đã RegisterSearch) =====
		local LangVI = {
			["infinite jump"] = "Nhảy vô hạn", ["double jump"] = "Nhảy đôi",
			["auto jump"] = "Tự nhảy", ["jump power"] = "Lực nhảy",
			["walk speed"] = "Tốc độ đi", ["gravity"] = "Trọng lực",
			["no clip"] = "Đi xuyên tường", ["fly"] = "Bay",
			["fly speed"] = "Tốc độ bay", ["speed climb"] = "Leo tường nhanh",
			["hover (stand in air)"] = "Đứng yên trên không", ["spin"] = "Quay người",
			["anti-afk"] = "Chống AFK", ["fullbright"] = "Sáng toàn bộ",
			["field of view"] = "Góc nhìn (FOV)", ["hotkeys"] = "Phím tắt",
			["low graphics mode"] = "Đồ họa thấp", ["disable shadows"] = "Tắt bóng",
			["hide particles/trails"] = "Ẩn hạt/đuôi", ["reduce render distance"] = "Giảm tầm nhìn",
			["flat lighting (no fog)"] = "Sáng phẳng (không sương)", ["disable post-processing"] = "Tắt hiệu ứng hậu kỳ",
			["hide other players"] = "Ẩn người chơi khác", ["reduce resolution (mobile)"] = "Giảm độ phân giải (mobile)",
			["cap frame rate (30)"] = "Hạn chế cập nhật UI (30)", ["hide npcs/bots (anti-lag)"] = "Ẩn NPC/bot (chống lag)",
			["auto low-gfx when fps is low"] = "Tự giảm GFX khi FPS thấp", ["auto threshold (fps)"] = "Ngưỡng FPS",
			["remove clouds/atmosphere"] = "Tắt mây/khí quyển", ["simplify water"] = "Đơn giản hóa nước",
			["mute all game sounds"] = "Tắt mọi âm thanh game", ["battery saver (all-in-one)"] = "Tiết kiệm pin (tất cả trong 1)",
			["distance cull (hide far parts)"] = "Ẩn vật thể xa", ["cull distance (studs)"] = "Khoảng cách ẩn",
			["remove fire/smoke/sparkles"] = "Tắt lửa/khói/lửa tia", ["disable dynamic lights"] = "Tắt đèn động",
			["bunny hop (hold jump)"] = "Nhảy liên tục (giữ Space)",			["sprint (hold left shift)"] = "Chạy nhanh (giữ Shift)",
			["glide (hold jump in air)"] = "Lướt (giữ Space khi rơi)", ["glide fall speed"] = "Tốc độ rơi khi lướt",
			["sprint boost"] = "Tốc độ cộng thêm khi sprint", ["extra air jumps"] = "Số nhảy thêm trên không",
			["float platform"] = "Bàn đạp trên không", ["anti fall damage"] = "Chống rơi tử vong",
			["click teleport (tap / ctrl+click)"] = "Dịch chuyển bằng cách bấm", ["dash button (on screen)"] = "Nút Dash trên màn hình",
			["dash power"] = "Lực dash", ["dash forward (q)"] = "Dash tới trước (Q)",
			["lag warning"] = "Cảnh báo lag", ["change theme"] = "Đổi màu chủ đề",
			["menu size"] = "Kích thước menu", ["save settings"] = "Lưu cài đặt",
			["delete saved settings"] = "Xóa cài đặt đã lưu", ["rejoin server"] = "Vào lại server",
			["server hop"] = "Chuyển server", ["go to spawn"] = "Về chỗ spawn",
			["sit / stand"] = "Ngồi / đứng", ["reset character"] = "Đặt lại nhân vật",
			["slot: 1 (tap to change)"] = "Ô 1 (bấm để đổi)", ["save position to slot"] = "Lưu vị trí vào ô",
			["teleport to slot"] = "Dịch chuyển tới ô", ["auto walk (forward)"] = "Đi tự động (tới trước)",
			["quality preset (tap to cycle)"] = "Mẫu chất lượng (bấm để đổi)", ["hide far players"] = "Ẩn người chơi ở xa",
			["far player distance"] = "Khoảng cách ẩn người chơi",
			["custom zoom limits"] = "Giới hạn zoom", ["max zoom"] = "Zoom tối đa", ["min zoom"] = "Zoom tối thiểu",
			["lock first person"] = "Khóa góc nhìn thứ nhất", ["camera roll (deg)"] = "Nghiêng camera (độ)",
			["orbit camera"] = "Camera quay quanh", ["orbit speed"] = "Tốc độ quay",
			["top-down view"] = "Nhìn từ trên xuống", ["top-down height"] = "Độ cao nhìn xuống",
			["cinematic bars"] = "Thanh điện ảnh", ["crosshair"] = "Ngắm tâm",
			["screenshot mode (hides ui 5s)"] = "Chụp màn hình (ẩn UI 5s)",
			["coordinates (xyz)"] = "Toạ độ (XYZ)", ["speed"] = "Tốc độ", ["height"] = "Độ cao",
			["session time"] = "Thời gian phiên", ["real clock"] = "Đồng hồ thật",
			["players in server"] = "Số người trong server", ["health"] = "Máu",
			["memory usage"] = "Bộ nhớ", ["compass"] = "La bàn", ["nearby players (distance)"] = "Người chơi gần (cách xa)",
			["copy my position"] = "Copy vị trí của tôi", ["copy server id (jobid)"] = "Copy Server ID",
			["copy place id"] = "Copy Place ID", ["copy debug info"] = "Copy thông tin gỡ lỗi",
			["lock time of day"] = "Khóa giờ trong game", ["time of day (hour)"] = "Giờ trong ngày",
			["auto day/night cycle"] = "Chu kỳ ngày/đêm tự động", ["cycle speed (hours/min)"] = "Tốc độ chu kỳ (giờ/phút)",
			["custom brightness"] = "Độ sáng tùy chỉnh", ["brightness"] = "Độ sáng",
			["custom exposure"] = "Độ phơi sáng", ["exposure (x10)"] = "Phơi sáng (x10)",
			["custom fog distance"] = "Khoảng cách sương", ["fog end (studs)"] = "Sương kết thúc",
			["bloom glow"] = "Hiệu ứng sáng ngập", ["bloom intensity (x10)"] = "Cường độ bloom (x10)",
			["color boost"] = "Tăng màu", ["saturation"] = "Độ bão hòa", ["contrast"] = "Tương phản",
			["blur"] = "Mờ", ["blur size"] = "Độ mờ", ["ambient color (tap to cycle)"] = "Màu môi trường (bấm để đổi)",
			["reset ambient color"] = "Đặt lại màu môi trường",
			["break reminder"] = "Nhắc nghỉ giải lao", ["remind every (min)"] = "Nhắc sau (phút)",
			["join / leave alerts"] = "Thông báo vào/ra", ["stopwatch start / stop"] = "Bấm giờ: Bắt đầu/Dừng",
			["stopwatch reset"] = "Bấm giờ: Đặt lại", ["countdown (min)"] = "Đếm ngược (phút)",
			["countdown start / stop"] = "Đếm ngược: Bắt đầu/Dừng",
			["rainbow border"] = "Viền cầu vồng", ["menu transparency %"] = "Độ trong suốt menu %",
			["menu size %"] = "Kích thước menu %", ["custom accent: red"] = "Màu nhấn: Đỏ",
			["custom accent: green"] = "Màu nhấn: Xanh lá", ["custom accent: blue"] = "Màu nhấn: Xanh dương",
			["apply custom accent"] = "Áp màu nhấn tùy chọn",
			["character trail"] = "Đuôi theo nhân vật", ["particle aura"] = "Hào quang hạt",
			["random body color (respawn undoes)"] = "Màu ngẫu nhiên (respawn về lại)",
			["play music"] = "Phát nhạc", ["stop music"] = "Dừng nhạc", ["music volume"] = "Âm lượng nhạc",
			-- v4.1
			["hover moves sideways"] = "Hover đi ngang được", ["air control"] = "Điều khiển trên không",
			["air control %"] = "Điều khiển trên không %", ["air dash"] = "Lao trên không",
			["air dash power"] = "Lực air dash", ["air dash now"] = "Lao ngay",
			["slide"] = "Trượt", ["slide speed"] = "Tốc độ trượt", ["slide time (s)"] = "Thời gian trượt (giây)",
			["slide now"] = "Trượt ngay", ["stamina bar (sprint/dash/slide)"] = "Thanh thể lực",
			["crouch (hold key)"] = "Cúi người (giữ phím)", ["crouch speed %"] = "Tốc độ cúi %",
			["climb speed"] = "Tốc độ leo", ["limit fall speed"] = "Giới hạn tốc độ rơi",
			["max fall speed"] = "Tốc độ rơi tối đa", ["swim speed"] = "Tốc độ bơi",
			["free cam"] = "Camera tự do", ["free cam speed"] = "Tốc độ camera tự do",
			["shift lock (client)"] = "Shift Lock (client)", ["camera smoothing"] = "Camera mượt",
			["smoothing % (nhỏ = mượt)"] = "Độ mượt % (nhỏ = mượt)", ["reduce camera shake"] = "Giảm rung camera",
			["shake damping %"] = "Mức chống rung %", ["camera offset"] = "Độ lệch camera",
			["camera offset up"] = "Camera lên", ["camera offset side"] = "Camera sang ngang",
			["ping graph"] = "Biểu đồ ping", ["fps graph"] = "Biểu đồ FPS", ["minimap"] = "Bản đồ nhỏ",
			["minimap range (studs)"] = "Bán kính bản đồ", ["keystrokes (wasd)"] = "Hiện phím bấm",
			["cps counter"] = "Bộ đếm CPS", ["sky preset (tap to cycle)"] = "Mẫu bầu trời (bấm để đổi)",
			["reset sky / lighting"] = "Đặt lại bầu trời/ánh sáng", ["sun rays"] = "Tia nắng mặt trời",
			["sun rays intensity (x10)"] = "Cường độ tia nắng (x10)", ["save light preset"] = "Lưu mẫu ánh sáng",
			["load light preset"] = "Tải mẫu ánh sáng",
			["reduce mesh detail (renderfidelity)"] = "Giảm chi tiết mesh", ["freeze far npc animations"] = "Dừng animation NPC ở xa",
			["far animation distance"] = "Khoảng cách dừng animation", ["hide game guis by name"] = "Ẩn GUI game theo tên",
			["clipboard history"] = "Lịch sử clipboard", ["copy whole history"] = "Copy toàn bộ lịch sử",
			["quick chat (textchatservice)"] = "Chat nhanh", ["send to chat"] = "Gửi tin nhắn",
			["emote wheel"] = "Bánh xe emote", ["emote: wave"] = "Emote: Vẫy tay", ["emote: dance"] = "Emote: Nhảy",
		}

		-- ===== 137: áp dụng ngôn ngữ cho mọi row (giữ nguyên text gốc trong attribute) =====
		local function primaryEl(row)
			local lbl = row:FindFirstChildOfClass("TextLabel")
			if lbl then return lbl end
			return row:FindFirstChildOfClass("TextButton")
		end
		local function captureOriginals()
			for _, e in ipairs(SearchRegistry) do
				local el = primaryEl(e.row)
				if el and not el:GetAttribute("_JH_Orig") then
					el:SetAttribute("_JH_Orig", el.Text)
				end
			end
		end
		-- force = true khi đổi ngôn ngữ; force = false chỉ sửa lại các row đang hiển thị bản gốc
		local function ApplyLang(force)
			for _, e in ipairs(SearchRegistry) do
				local el = primaryEl(e.row)
				local orig = el and el:GetAttribute("_JH_Orig")
				if el and orig then
					local want = (Lang == "vi" and LangVI[e.name]) or orig
					if force or el.Text == orig then
						if el.Text ~= want then el.Text = want end
					end
				end
			end
		end

		-- ===== 126: tooltip giải thích (chuột = hover, touch = giữ 0.45s) =====
		local tipRow = nil
		local function showTip(row, name)
			if not States.Tooltips then return end
			local tip = Tips[name]
			if not tip then return end
			TipBox.Text = tip
			TipBox.Visible = true
			task.defer(function()
				if not TipBox.Visible then return end
				local rs = row.AbsolutePosition
				local vs = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
					or Vector2.new(1024, 768)
				local h = TipBox.AbsoluteSize.Y
				local y = rs.Y + row.AbsoluteSize.Y + 4
				if y + h + 8 > vs.Y then y = rs.Y - h - 4 end
				if y < 4 then y = 4 end
				TipBox.Position = UDim2.new(0, math.clamp(rs.X, 4, math.max(4, vs.X - 268)), 0, y)
			end)
		end
		local function hideTip()
			TipBox.Visible = false
		end
		local function attachTips()
			for _, e in ipairs(SearchRegistry) do
				local row = e.row
				if not row:GetAttribute("_JH_TipA") then
					row:SetAttribute("_JH_TipA", true)
					row.MouseEnter:Connect(function() showTip(row, e.name) end)
					row.MouseLeave:Connect(hideTip)
					row.InputBegan:Connect(function(input)
						if input.UserInputType ~= Enum.UserInputType.Touch then return end
						tipRow = row
						task.delay(0.45, function()
							if tipRow == row then showTip(row, e.name) end
						end)
						task.delay(3.2, function()
							if tipRow == row then hideTip() end
						end)
					end)
					row.InputEnded:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.Touch then tipRow = nil end
					end)
				end
			end
		end

		-- ===== 125: Yêu thích - gắn ngôi sao vào MỖI row đã đăng ký =====
		local function starIdx(name)
			for i, f in ipairs(Favorites) do
				if f == name then return i end
			end
			return nil
		end
		local function attachStars()
			for _, e in ipairs(SearchRegistry) do
				local row = e.row
				if not row:GetAttribute("_JH_Star") then
					row:SetAttribute("_JH_Star", true)
					local lbl = row:FindFirstChildOfClass("TextLabel")
					local btn = row:FindFirstChildOfClass("TextButton")
					local track = (not btn) and row:FindFirstChildWhichIsA("Frame") or nil
					if btn and not lbl then
						-- ActionBtn: co nút lại, chừa 40px bên trái cho sao
						btn.Position = UDim2.new(0, 40, 0, 0)
						btn.Size = UDim2.new(1, -40, 1, 0)
					elseif lbl and track then
						-- SliderRow: dời label + track sang phải
						lbl.Position = UDim2.new(0, 40, 0, 4)
						lbl.Size = UDim2.new(1, -110, 0, 24)
						track.Position = UDim2.new(0, 40, 0, 38)
						track.Size = UDim2.new(1, -54, 0, 6)
					elseif lbl then
						-- ToggleBtn
						lbl.Position = UDim2.new(0, 40, 0, 0)
						lbl.Size = UDim2.new(1, -98, 1, 0)
					end
					local star = Instance.new("TextButton", row)
					star.Size = UDim2.new(0, 36, 0, 36)
					star.Position = UDim2.new(0, 2, 0.5, -18)
					star.Font = Enum.Font.GothamBold
					star.TextSize = 18
					star.BackgroundTransparency = 1
					star.BorderSizePixel = 0
					star.AutoButtonColor = false
					star.ZIndex = 3
					local fav = starIdx(e.name) ~= nil
					star.Text = fav and "★" or "☆"
					star.TextColor3 = fav and Theme.AccentAlt or Theme.SubText
					star.MouseButton1Click:Connect(function()
						local idx = starIdx(e.name)
						if idx then table.remove(Favorites, idx)
						else table.insert(Favorites, e.name) end
						local nowFav = starIdx(e.name) ~= nil
						star.Text = nowFav and "★" or "☆"
						star.TextColor3 = nowFav and Theme.AccentAlt or Theme.SubText
						saveV5()
						if FavRefresh then FavRefresh() end
					end)
				end
			end
		end

		-- ===== 129: hiệu ứng ripple khi bấm =====
		local rippleConns, activeRips, ripConn = {}, {}, nil
		local function spawnRipple(b, x, y)
			local r = Instance.new("Frame")
			r.AnchorPoint = Vector2.new(0.5, 0.5)
			r.Position = UDim2.new(0, x, 0, y)
			r.Size = UDim2.new(0, 6, 0, 6)
			r.BackgroundColor3 = Theme.Accent
			r.BackgroundTransparency = 0.55
			r.BorderSizePixel = 0
			r.ZIndex = 2
			r.Parent = b
			Instance.new("UICorner", r).CornerRadius = UDim.new(1, 0)
			local d = math.max(b.AbsoluteSize.X, b.AbsoluteSize.Y) * 2.2
			tween(r, {Size = UDim2.new(0, d, 0, d), BackgroundTransparency = 1}, 0.45)
			activeRips[r] = true
			task.delay(0.5, function()
				activeRips[r] = nil
				if r and r.Parent then r:Destroy() end
			end)
		end
		local function attachRipple(b)
			if b:GetAttribute("_JH_Rip") then return end
			b:SetAttribute("_JH_Rip", true)
			local cn = b.InputBegan:Connect(function(input)
				if not States.Ripple then return end
				local t = input.UserInputType
				if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
					spawnRipple(b, input.Position.X - b.AbsolutePosition.X, input.Position.Y - b.AbsolutePosition.Y)
				end
			end)
			table.insert(rippleConns, {b = b, cn = cn})
		end
		local function setRipple(on)
			if on then
				for _, b in ipairs(PlayerGui:GetDescendants()) do
					if b:IsA("TextButton") then attachRipple(b) end
				end
				if not ripConn then
					ripConn = PlayerGui.DescendantAdded:Connect(function(v)
						if v:IsA("TextButton") then attachRipple(v) end
					end)
				end
			else
				if ripConn then ripConn:Disconnect(); ripConn = nil end
				for _, e in ipairs(rippleConns) do
					e.cn:Disconnect()
					if e.b and e.b.Parent then e.b:SetAttribute("_JH_Rip", nil) end
				end
				table.clear(rippleConns)
				for r in pairs(activeRips) do
					if r and r.Parent then r:Destroy() end
				end
				table.clear(activeRips)
			end
		end

		-- ===== 130: responsive mobile/PC (chạy 4 lần/giây) =====
		local respKey = ""
		local function ApplyResponsive()
			local cam = workspace.CurrentCamera
			local vs = (cam and cam.ViewportSize) or Vector2.new(1024, 768)
			local touch = UIS.TouchEnabled
			-- thu nhỏ menu vừa màn hình bé (không đổi Size của Main để không mất hiệu ứng minimize)
			local factor = math.clamp(math.min(1, (vs.Y - 16) / 384, (vs.X - 16) / 340), 0.55, 1)
			MainScale.Scale = MenuScale * factor
			local key = tostring(math.floor(vs.X)) .. "x" .. tostring(math.floor(vs.Y)) .. ":" .. tostring(touch)
			if key == respKey then return end
			respKey = key
			-- tab cao >= 36px trên mobile, trang trượt xuống cho khớp
			TabBar.Size = UDim2.new(1, -20, 0, touch and 42 or 34)
			for _, p in ipairs(Pages) do
				p.Position = UDim2.new(0, 10, 0, touch and 100 or 92)
				p.Size = UDim2.new(1, -20, 1, -(touch and 104 or 96))
			end
		end

		-- ===== 136: trình chỉnh phím tắt =====
		local bindRows = {}
		local function refreshBindRows()
			for action, el in pairs(bindRows) do
				local kc = KeyBinds[action]
				el.Text = action .. ": " .. (kc and kc.Name or "?")
			end
		end
		local function startRebind(action, el)
			if RebindActive then return end
			RebindActive = true
			local wasHot = States.Hotkeys
			States.Hotkeys = false -- tạm khóa để code v4.0 không bắt phím trong lúc chờ
			if ToggleRefreshers.Hotkeys then ToggleRefreshers.Hotkeys() end
			el.Text = action .. ": [nhan phim moi... Esc de huy]"
			local cn
			cn = UIS.InputBegan:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
				cn:Disconnect()
				RebindActive = false
				States.Hotkeys = wasHot
				if ToggleRefreshers.Hotkeys then ToggleRefreshers.Hotkeys() end
				if input.KeyCode == Enum.KeyCode.Escape then
					Notify("Da huy", Theme.SubText)
				else
					KeyBinds[action] = input.KeyCode
					saveV5()
					Notify(action .. " -> " .. input.KeyCode.Name, Theme.On)
				end
				refreshBindRows()
			end)
		end

		-- ===== 140: console/log lỗi nội bộ =====
		local logScroll = nil
		local function refreshLog()
			if not logScroll then return end
			for _, ch in ipairs(logScroll:GetChildren()) do
				if not ch:IsA("UIListLayout") then ch:Destroy() end
			end
			local function mkLabel(text, order)
				local l = Instance.new("TextLabel", logScroll)
				l.Size = UDim2.new(1, -6, 0, 0)
				l.AutomaticSize = Enum.AutomaticSize.Y
				l.LayoutOrder = order
				l.BackgroundTransparency = 1
				l.Font = Enum.Font.Gotham
				l.TextSize = 11
				l.TextColor3 = Theme.SubText
				l.TextWrapped = true
				l.TextXAlignment = Enum.TextXAlignment.Left
				l.Text = text
				return l
			end
			if #LogLines == 0 then
				mkLabel("(chua co loi nao - loi noi bo cua v4.1 se hien o day)", 1)
				return
			end
			for i, line in ipairs(LogLines) do
				mkLabel(line, i)
			end
		end
		LogRefresh = refreshLog

		-- ===== 125: danh sách Yêu thích =====
		local favList = Instance.new("ScrollingFrame")
		favList.Size = UDim2.new(1, 0, 0, 140)
		favList.LayoutOrder = 11
		favList.BackgroundColor3 = Theme.Panel
		favList.BorderSizePixel = 0
		favList.ScrollBarThickness = 3
		favList.ScrollBarImageColor3 = Theme.Accent
		favList.CanvasSize = UDim2.new(0, 0, 0, 0)
		favList.AutomaticCanvasSize = Enum.AutomaticSize.Y
		favList.Parent = PageSet
		Instance.new("UICorner", favList).CornerRadius = UDim.new(0, 8)
		do
			local lay = Instance.new("UIListLayout", favList)
			lay.Padding = UDim.new(0, 4)
			lay.SortOrder = Enum.SortOrder.LayoutOrder
		end
		local function refreshFavList()
			for _, ch in ipairs(favList:GetChildren()) do
				if not ch:IsA("UIListLayout") then ch:Destroy() end
			end
			if #Favorites == 0 then
				local l = Instance.new("TextLabel", favList)
				l.Size = UDim2.new(1, -6, 0, 30)
				l.LayoutOrder = 1
				l.BackgroundTransparency = 1
				l.Font = Enum.Font.Gotham
				l.TextSize = 12
				l.TextColor3 = Theme.SubText
				l.Text = "(chua co yeu thich - bam ngoi sao o bat ky hang nao de ghim)"
				return
			end
			for i, name in ipairs(Favorites) do
				local target = name
				local b = Instance.new("TextButton", favList)
				b.Size = UDim2.new(1, -6, 0, 34)
				b.LayoutOrder = i
				b.Font = Enum.Font.GothamMedium
				b.TextSize = 13
				b.TextColor3 = Theme.Text
				b.BackgroundColor3 = Theme.Background
				b.BorderSizePixel = 0
				b.AutoButtonColor = false
				b.TextXAlignment = Enum.TextXAlignment.Left
				b.Text = "  * " .. target
				Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
				b.MouseButton1Click:Connect(function()
					for _, e in ipairs(SearchRegistry) do
						if e.name == target and e.row.Parent then
							Show(e.home)
							task.delay(0.05, function()
								pcall(function()
									local y = e.row.AbsolutePosition.Y - e.home.AbsolutePosition.Y
									e.home.CanvasPosition = Vector2.new(0, math.max(0, e.home.CanvasPosition.Y + y - 20))
								end)
								pcall(function()
									local st = Instance.new("UIStroke", e.row)
									st.Color = Theme.AccentAlt
									st.Thickness = 2
									task.delay(1.2, function()
										if st and st.Parent then st:Destroy() end
									end)
								end)
							end)
							break
						end
					end
				end)
			end
		end
		FavRefresh = refreshFavList

		-- ===== 133: nhiều profile =====
		local PROF_FILE = "JumpHub_Profiles.json"
		local function loadProfilesFile()
			local out = {}
			pcall(function()
				if typeof(isfile) == "function" and typeof(readfile) == "function" and isfile(PROF_FILE) then
					local d = HttpService:JSONDecode(readfile(PROF_FILE))
					if type(d) == "table" then out = d end
				end
			end)
			return out
		end
		local function writeProfilesFile(t)
			if typeof(writefile) ~= "function" then return "Khong ho tro (can writefile)" end
			local ok = pcall(function() writefile(PROF_FILE, HttpService:JSONEncode(t)) end)
			return ok and "Da luu!" or "Save failed"
		end
		local function snapshotBundle()
			local b = {States = {}, Sliders = {}}
			for k, v in pairs(States) do b.States[k] = v end
			for k, v in pairs(Sliders) do b.Sliders[k] = v end
			b.ThemeIndex = ThemeIndex
			return b
		end
		local function applyBundle(b)
			local n = 0
			for k, v in pairs(b.States or {}) do
				if States[k] ~= nil and type(v) == "boolean" then States[k] = v; n += 1 end
			end
			for k, v in pairs(b.Sliders or {}) do
				if Sliders[k] ~= nil and type(v) == "number" then Sliders[k] = v; n += 1 end
			end
			if type(b.ThemeIndex) == "number" and Themes[b.ThemeIndex] then
				ThemeIndex = b.ThemeIndex
				ApplyTheme(ThemeIndex)
			end
			for _, r in pairs(ToggleRefreshers) do r() end
			return n
		end

		-- ===== 135: reset tất cả về mặc định =====
		local DefaultSliders = {
			WalkSpeed = 16, JumpPower = 50, FlySpeed = 50, AutoFPS = 30, DashPower = 120,
			CullDist = 200, SprintBoost = 16, ExtraJumps = 0, GlideFall = 12,
			MaxZoom = 128, MinZoom = 0, CamRoll = 0, OrbitSpeed = 30, TopHeight = 80,
			TimeOfDay = 14, CycleSpeed = 10, Brightness = 2, ExposureX10 = 0,
			FogEndCustom = 1000, BloomInt = 10, Saturation = 0, Contrast = 0,
			BlurSize = 8, BreakMin = 30, TimerMin = 5, HideFarDist = 150,
			MusicVol = 50, AccR = 140, AccG = 80, AccB = 255, UITrans = 0, MenuPct = 100,
			AirCtlPct = 50, AirDashPow = 120, SlideSpeed = 60, SlideTime = 2,
			CrouchPct = 45, ClimbSpeed = 40, MaxFall = 70, SwimSpeed = 30,
			SpinRate = 10, FreeSpeed = 60, CamOffY = 0, CamOffX = 0,
			SmoothPct = 45, ShakePct = 55, MiniRange = 150, FarAnimDist = 120, SunInt = 10,
		}
		local function resetAll()
			for k in pairs(States) do States[k] = false end
			States.Hotkeys = true
			States.Tooltips = true
			for k, v in pairs(DefaultSliders) do Sliders[k] = v end
			Sliders.Gravity, Sliders.FOV = DefaultGravity, DefaultFOV
			table.clear(Favorites)
			table.clear(AutoOn)
			Lang = "en"
			for a, kc in pairs(DefaultKeyBinds) do KeyBinds[a] = kc end
			ThemeIndex, MenuScale = 1, 1
			ApplyTheme(1)
			DeleteSettings()
			pcall(function()
				if typeof(delfile) == "function" and isfile(V5FILE) then delfile(V5FILE) end
			end)
			for _, r in pairs(ToggleRefreshers) do r() end
			saveV5()
			refreshBindRows()
			refreshFavList()
			refreshLog()
			ApplyLang(true)
			return "Da reset ve mac dinh!"
		end

		-- ===== hàng UI đợt C (tab Set) =====
		Info5(PageSet, 1, "Jump Hub v4.1 - 50 tinh nang moi nam trong InstallV5 (pcall); neu loi thi phan v4.0 van chay binh thuong.", 40)
		do
			local ver = Instance.new("ScrollingFrame")
			ver.Size = UDim2.new(1, 0, 0, 150)
			ver.LayoutOrder = 2
			ver.BackgroundColor3 = Theme.Panel
			ver.BorderSizePixel = 0
			ver.ScrollBarThickness = 3
			ver.ScrollBarImageColor3 = Theme.Accent
			ver.CanvasSize = UDim2.new(0, 0, 0, 0)
			ver.AutomaticCanvasSize = Enum.AutomaticSize.Y
			ver.Parent = PageSet
			Instance.new("UICorner", ver).CornerRadius = UDim.new(0, 8)
			local lay = Instance.new("UIListLayout", ver)
			lay.Padding = UDim.new(0, 3)
			lay.SortOrder = Enum.SortOrder.LayoutOrder
			local lines = {
				"v4.1 Movement: Hover di ngang, Air Control, Air Dash, Slide, Stamina, Crouch, Climb/Swim/Fall speed, Spin slider",
				"v4.1 Camera: Free Cam, Shift Lock (client), Camera Smoothing, Reduce Shake, Camera Offset",
				"v4.1 Hieu nang: giam chi tiet mesh, dong bang animation NPC xa, an GUI game theo ten",
				"v4.1 Anh sang: Sky preset, Sun Rays, luu/tai preset anh sang",
				"v4.1 HUD: bieu do ping, bieu do FPS, minimap, keystrokes, bo dem CPS",
				"v4.1 Tien ich: lich su clipboard, chat nhanh (TextChatService), banh xe emote",
				"v4.1 Giao dien: theme sang, icon tab, danh sach yeu thich, tooltip, ripple, responsive",
				"v4.1 Can dat: tai cau hinh khi vao game, nhieu profile, xuat/nhap chuoi, reset, keybind editor, Viet/Anh, auto-start, log loi",
				"v4.1 Am thanh/Vui: am luong tong, tat nhac nen game, am click UI, phim tat emote, Konami",
				"KHONG KHA THI - muc 112: doi kich thuoc cua so game. Roblox khong co API cho script.",
				"KHONG KHA THI 100% - muc 38: tat rung man hinh. Chi giam duoc bang bo loc (xem tooltip).",
			}
			for i, line in ipairs(lines) do
				local l = Instance.new("TextLabel", ver)
				l.Size = UDim2.new(1, -8, 0, 0)
				l.AutomaticSize = Enum.AutomaticSize.Y
				l.LayoutOrder = i
				l.BackgroundTransparency = 1
				l.Font = Enum.Font.Gotham
				l.TextSize = 11
				l.TextColor3 = Theme.SubText
				l.TextWrapped = true
				l.TextXAlignment = Enum.TextXAlignment.Left
				l.Text = line
			end
		end
		ActionBtn(PageSet, "Fit Menu to Screen", 4, function()
			respKey = ""
			ApplyResponsive()
			return "Da fit man hinh!"
		end)
		ToggleBtn(PageSet, "Light Theme", "LightUI", 5)
		ToggleBtn(PageSet, "Tab Icons", "TabIcons", 6)
		ToggleBtn(PageSet, "Tooltips", "Tooltips", 7)
		ToggleBtn(PageSet, "Ripple Effect", "Ripple", 8)
		ActionBtn(PageSet, "Language: Tieng Viet / English", 9, function()
			Lang = (Lang == "vi") and "en" or "vi"
			ApplyLang(true)
			return "Lang: " .. Lang .. " | " .. saveV5()
		end)
		Info5(PageSet, 10, "Yeu thich (125): bam ngoi sao o trai moi hang de ghim; bam ten o day de nhay toi tinh nang do.", 36)

		local profBox = Row5(PageSet, 13, "Ten profile (vd: pvp)...", 36, false, nil)
		local function profName()
			return (profBox.Text:gsub("^%s+", ""):gsub("%s+$", ""))
		end
		ActionBtn(PageSet, "Save Profile", 14, function()
			local name = profName()
			if name == "" then return "Nhap ten profile truoc" end
			local ps = loadProfilesFile()
			ps[name] = snapshotBundle()
			return name .. ": " .. writeProfilesFile(ps)
		end)
		ActionBtn(PageSet, "Load Profile", 15, function()
			local name = profName()
			if name == "" then return "Nhap ten profile truoc" end
			local ps = loadProfilesFile()
			if type(ps[name]) ~= "table" then return "Khong co profile '" .. name .. "'" end
			return ("Da nap %d gia tri"):format(applyBundle(ps[name]))
		end)
		ActionBtn(PageSet, "Delete Profile", 16, function()
			local name = profName()
			if name == "" then return "Nhap ten profile truoc" end
			local ps = loadProfilesFile()
			if ps[name] == nil then return "Khong co profile '" .. name .. "'" end
			ps[name] = nil
			return "Da xoa: " .. writeProfilesFile(ps)
		end)

		ActionBtn(PageSet, "Export Settings (copy)", 18, function()
			return Clip5(HttpService:JSONEncode(snapshotBundle()))
		end)
		local importBox = Row5(PageSet, 19, "Dan chuoi cau hinh vao day...", 36, false, nil)
		ActionBtn(PageSet, "Import Settings (paste)", 20, function()
			local ok, data = pcall(function() return HttpService:JSONDecode(importBox.Text) end)
			if not ok or type(data) ~= "table" then return "Chuoi khong hop le" end
			return ("Da ap %d gia tri"):format(applyBundle(data))
		end)
		ActionBtn(PageSet, "Reset ALL to Defaults", 21, resetAll)
		local autoLbl = Info5(PageSet, 24, "", 36)
		local function autoText()
			return ("Auto-Start (138) dang luu %d tinh nang; tai khoan moi vao game se tu bat chung."):format(#AutoOn)
		end
		autoLbl.Text = autoText()
		ActionBtn(PageSet, "Save ON Features as Auto-Start", 22, function()
			local list = {}
			for k, v in pairs(States) do
				if v == true then table.insert(list, k) end
			end
			AutoOn = list
			autoLbl.Text = autoText()
			return ("Da ghi %d tinh nang | %s"):format(#list, saveV5())
		end)
		ActionBtn(PageSet, "Clear Auto-Start", 23, function()
			table.clear(AutoOn)
			autoLbl.Text = autoText()
			return saveV5()
		end)

		Info5(PageSet, 26, "Keybind editor (136): bam vao dong roi nhan phim moi, Esc de huy. Luu vao JumpHub_V5.json.", 44)
		do
			local bindOrder = {
				"Fly", "Hover", "NoClip", "Dash", "Sprint", "Menu", "Crouch",
				"Slide", "AirDash", "FreeCam", "ShiftLock", "EmoteWheel", "EmoteDance", "EmoteWave",
			}
			for i, action in ipairs(bindOrder) do
				local kc = KeyBinds[action]
				local row = Instance.new("TextButton", PageSet)
				row.Size = UDim2.new(1, 0, 0, 36)
				row.LayoutOrder = 26 + i
				row.Text = action .. ": " .. (kc and kc.Name or "?")
				row.Font = Enum.Font.GothamMedium
				row.TextSize = 13
				row.TextColor3 = Theme.Text
				row.BackgroundColor3 = Theme.Panel
				row.BorderSizePixel = 0
				row.AutoButtonColor = false
				Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
				bindRows[action] = row
				RegisterSearch(row, "Keybind: " .. action, PageSet)
				row.MouseButton1Click:Connect(function() startRebind(action, row) end)
			end
		end
		ActionBtn(PageSet, "Reset Keybinds", 42, function()
			for a, kc in pairs(DefaultKeyBinds) do KeyBinds[a] = kc end
			refreshBindRows()
			return saveV5()
		end)

		Info5(PageSet, 44, "Log noi bo (140): moi loi bi bat boi pcall trong v4.1 deu ghi o day (khong can mo F9).", 36)
		logScroll = Instance.new("ScrollingFrame")
		logScroll.Size = UDim2.new(1, 0, 0, 150)
		logScroll.LayoutOrder = 45
		logScroll.BackgroundColor3 = Theme.Panel
		logScroll.BorderSizePixel = 0
		logScroll.ScrollBarThickness = 3
		logScroll.ScrollBarImageColor3 = Theme.Accent
		logScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		logScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		logScroll.Parent = PageSet
		Instance.new("UICorner", logScroll).CornerRadius = UDim.new(0, 8)
		do
			local lay = Instance.new("UIListLayout", logScroll)
			lay.Padding = UDim.new(0, 3)
			lay.SortOrder = Enum.SortOrder.LayoutOrder
		end
		refreshLog()
		ActionBtn(PageSet, "Refresh Log", 46, function()
			refreshLog()
			return #LogLines .. " dong"
		end)
		ActionBtn(PageSet, "Clear Log", 47, function()
			table.clear(LogLines)
			table.clear(LogSeen)
			refreshLog()
			return "Da xoa log"
		end)
		Info5(PageSet, 49, "MUC 112 - DOI KICH THUOC CUA SO GAME: KHONG KHA THI. Roblox khong cung cap API cho script doi kich thuoc cua so/viewport (chi Roblox moi lam duoc). Thay vao do dung 'Menu Size %' + 'Fit Menu to Screen' de doi kich thuoc menu Jump Hub.", 76)

		-- dịch thêm các row mới của v4.1
		LangVI["light theme"] = "Theme Sáng"
		LangVI["tab icons"] = "Icon tab"
		LangVI["tooltips"] = "Tooltip giải thích"
		LangVI["ripple effect"] = "Hiệu ứng ripple"
		LangVI["fit menu to screen"] = "Vừa màn hình"
		LangVI["save profile"] = "Lưu profile"
		LangVI["load profile"] = "Tải profile"
		LangVI["delete profile"] = "Xóa profile"
		LangVI["export settings (copy)"] = "Xuất cấu hình (copy)"
		LangVI["import settings (paste)"] = "Nhập cấu hình (dán)"
		LangVI["reset all to defaults"] = "Reset tất cả về mặc định"
		LangVI["save on features as auto-start"] = "Lưu tính năng đang BẬT làm Auto-Start"
		LangVI["clear auto-start"] = "Xóa Auto-Start"
		LangVI["reset keybinds"] = "Đặt lại phím tắt"
		LangVI["refresh log"] = "Tải lại log"
		LangVI["clear log"] = "Xóa log"

		-- ===== driver đợt C =====
		local function CDriver(dt, c)
			if edgeC("lightui", States.LightUI) then SetLightUI(States.LightUI) end
			if edgeC("tabicons", States.TabIcons) then SetTabIcons(States.TabIcons) end
			if edgeC("ripple", States.Ripple) then setRipple(States.Ripple) end
		end
		table.insert(Drivers, CDriver)

		local langTick = 0
		table.insert(Slows, function(now, c)
			ApplyResponsive()
			langTick += 1
			-- ActionBtn treen lay lai text goc Anh sau moi lan bam, sua lai 1s/lan
			if langTick % 4 == 0 and Lang == "vi" then ApplyLang(false) end
		end)

		table.insert(LateInit, function()
			captureOriginals()
			ApplyResponsive()
			setRipple(States.Ripple)
			if States.LightUI then SetLightUI(true) end
			if States.TabIcons then SetTabIcons(true) end
			ApplyLang(true)
			refreshBindRows()
			refreshFavList()
			refreshLog()
			attachTips()
			attachStars()
		end)
	end

	-- ==================== ĐỢT D: Audio + Fun ====================
	do
		-- --- key mới (141, 142, 144) ---
		local DStates = {MasterVol = false, MuteMusic = false, ClickSound = false}
		for k, v in pairs(DStates) do
			if States[k] == nil then States[k] = v end
		end
		local DSliders = {MasterPct = 60}
		for k, v in pairs(DSliders) do
			if Sliders[k] == nil then Sliders[k] = v end
		end
		LoadKeys(DStates, DSliders)

		local prevD = {}
		local function edgeD(k, v)
			local old = prevD[k] or false
			prevD[k] = v
			return old ~= v
		end

		-- ===== 141: âm lượng tổng (nhân toàn bộ Sound/AudioEmitter với 1 hệ số) =====
		local volCache = {}
		local lastMasterPct = -1
		local function masterTouch(s)
			if volCache[s] == nil then volCache[s] = s.Volume end -- lưu giá trị gốc
			s.Volume = volCache[s] * (Sliders.MasterPct / 100)
		end
		local function applyMaster(on)
			if on then
				for _, root in ipairs({workspace, SoundService}) do
					for _, v in ipairs(root:GetDescendants()) do
						if v:IsA("Sound") or v:IsA("AudioEmitter") then masterTouch(v) end
					end
				end
			else
				for s, orig in pairs(volCache) do
					if s and s.Parent then s.Volume = orig end -- khôi phục đúng giá trị cũ
				end
				table.clear(volCache)
			end
		end

		-- ===== 142: tắt nhạc nền game (đoán theo tên Sound / SoundGroup) =====
		local musicWords = {"music", "bgm", "theme", "soundtrack", "background"}
		local musicCache = {}
		local function isMusic(s)
			if not s:IsA("Sound") then return false end
			local n = s.Name:lower()
			local grp = s:FindFirstAncestorOfClass("SoundGroup")
			local gn = grp and grp.Name:lower() or ""
			for _, w in ipairs(musicWords) do
				if n:find(w, 1, true) or gn:find(w, 1, true) then return true end
			end
			return false
		end
		local function musicTouch(s)
			if musicCache[s] == nil then musicCache[s] = s.Volume end
			s.Volume = 0
		end
		local function setMuteMusic(on)
			if on then
				for _, root in ipairs({workspace, SoundService}) do
					for _, v in ipairs(root:GetDescendants()) do
						if isMusic(v) then musicTouch(v) end
					end
				end
			else
				for s, orig in pairs(musicCache) do
					if s and s.Parent then s.Volume = orig end
				end
				table.clear(musicCache)
			end
		end

		-- ===== 144: âm click UI (thử nhiều ID, không tải được thì báo Không hỗ trợ) =====
		local clickSound = nil
		local function setClickSound(on)
			if on then
				if clickSound then return end
				task.spawn(function()
					local ids = {
						"rbxasset://sounds/electronicpingshort.wav",
						"rbxasset://sounds/button.wav",
						"rbxasset://sounds/uuhhh.mp3",
					}
					for _, id in ipairs(ids) do
						local s = Instance.new("Sound")
						s.Name = "JH_Click"
						s.SoundId = id
						s.Volume = 0.5
						s.Parent = SoundService
						local t0 = tick()
						while tick() - t0 < 0.8 and not s.IsLoaded do task.wait(0.1) end
						if s.IsLoaded then
							clickSound = s
							Notify("UI click sound: ON", Theme.On)
							return
						end
						s:Destroy()
					end
					clickSound = nil
					States.ClickSound = false
					if ToggleRefreshers.ClickSound then ToggleRefreshers.ClickSound() end
					Notify("Không hỗ trợ: không tải được âm click", Theme.Danger)
				end)
			else
				if clickSound then
					clickSound:Destroy()
					clickSound = nil
				end
			end
		end

		-- kết nối theo toggle: master/music (sound mới) + click (nút mới)
		local dConn1, dConn2, clickConn = nil, nil, nil
		local clickConns = {}
		local function onSoundAdded(v)
			if States.MasterVol and (v:IsA("Sound") or v:IsA("AudioEmitter")) then masterTouch(v) end
			if States.MuteMusic and isMusic(v) then musicTouch(v) end
		end
		local function attachClick(b)
			if b:GetAttribute("_JH_Click") then return end
			b:SetAttribute("_JH_Click", true)
			local cn = b.InputBegan:Connect(function(input)
				if not States.ClickSound or not clickSound then return end
				local t = input.UserInputType
				if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
					pcall(function()
						clickSound:Stop()
						clickSound:Play()
					end)
				end
			end)
			table.insert(clickConns, {b = b, cn = cn})
		end
		local function syncDConns()
			local wantSnd = States.MasterVol or States.MuteMusic
			if wantSnd and not dConn1 then
				dConn1 = workspace.DescendantAdded:Connect(onSoundAdded)
				dConn2 = SoundService.DescendantAdded:Connect(onSoundAdded)
			elseif not wantSnd and dConn1 then
				dConn1:Disconnect(); dConn1 = nil
				dConn2:Disconnect(); dConn2 = nil
			end
			if States.ClickSound and not clickConn then
				for _, b in ipairs(PlayerGui:GetDescendants()) do
					if b:IsA("TextButton") then attachClick(b) end
				end
				clickConn = PlayerGui.DescendantAdded:Connect(function(v)
					if v:IsA("TextButton") then attachClick(v) end
				end)
			elseif not States.ClickSound and clickConn then
				clickConn:Disconnect(); clickConn = nil
				for _, e in ipairs(clickConns) do
					e.cn:Disconnect()
					if e.b and e.b.Parent then e.b:SetAttribute("_JH_Click", nil) end
				end
				table.clear(clickConns)
			end
		end

		-- ===== 103/149: gửi chat (bản riêng của đợt D, vì SendChat của đợt B nằm trong block khác) =====
		local function SendChatD(text)
			if type(text) ~= "string" or text == "" then return "Enter text" end
			local ok, err = pcall(function()
				if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then error("legacy chat") end
				local tc = TextChatService:FindFirstChild("TextChannels")
				local ch = tc and tc:FindFirstChild("RBXGeneral")
				if not ch then error("no RBXGeneral") end
				ch:SendAsync(text)
			end)
			if not ok then Log("chatD: " .. tostring(err)) end
			return ok and "Sent!" or "Không hỗ trợ"
		end

		-- ===== 150: easter egg Konami (bàn phím + ô nhập cho mobile) =====
		local KonamiSeq = {
			Enum.KeyCode.Up, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Down,
			Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Left, Enum.KeyCode.Right,
			Enum.KeyCode.B, Enum.KeyCode.A,
		}
		local konamiPos = 0
		local function konamiFire()
			Notify("KONAMI!!! Rainbow + Trail trong 30 giây", Theme.Accent)
			if clickSound then pcall(function() clickSound:Stop(); clickSound:Play() end) end
			local prevRainbow, prevTrail = States.RainbowUI, States.CharTrail
			States.RainbowUI, States.CharTrail = true, true
			if ToggleRefreshers.RainbowUI then ToggleRefreshers.RainbowUI() end
			if ToggleRefreshers.CharTrail then ToggleRefreshers.CharTrail() end
			task.delay(30, function() -- trả lại trạng thái cũ sau 30 giây
				States.RainbowUI, States.CharTrail = prevRainbow, prevTrail
				if ToggleRefreshers.RainbowUI then ToggleRefreshers.RainbowUI() end
				if ToggleRefreshers.CharTrail then ToggleRefreshers.CharTrail() end
			end)
		end
		local function konamiKey(code)
			local expected = KonamiSeq[konamiPos + 1]
			if code == expected then
				konamiPos += 1
				if konamiPos >= #KonamiSeq then
					konamiPos = 0
					konamiFire()
				end
			else
				konamiPos = (code == KonamiSeq[1]) and 1 or 0
			end
		end
		local function konamiText(txt)
			local s = tostring(txt):upper():gsub("%s+", "")
			if s == "KONAMI" or s == "UUDDLRLRBA" then
				konamiFire()
				return true
			end
			return false
		end

		-- phím tắt đợt D: emote wheel / dance / wave + dãy Konami
		UIS.InputBegan:Connect(function(input, processed)
			if RebindActive then return end
			if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
			if not processed then konamiKey(input.KeyCode) end
			if processed or not States.Hotkeys then return end
			local code = input.KeyCode
			if code == KeyBinds.EmoteWheel then
				States.EmoteWheel = not States.EmoteWheel
				if ToggleRefreshers.EmoteWheel then ToggleRefreshers.EmoteWheel() end
			elseif code == KeyBinds.EmoteDance then
				Notify(SendChatD("/e dance"), Theme.On)
			elseif code == KeyBinds.EmoteWave then
				Notify(SendChatD("/e wave"), Theme.On)
			end
		end)

		-- ===== hàng UI đợt D =====
		local FN = Pg("Fun")
		ToggleBtn(FN, "Master Volume", "MasterVol", 30)
		SliderRow(FN, "Master Volume %", "MasterPct", 0, 100, 31)
		ToggleBtn(FN, "Mute Game Music", "MuteMusic", 32)
		ToggleBtn(FN, "UI Click Sound", "ClickSound", 33)
		Info5(FN, 34, "Phím: T = emote wheel, Y = dance, U = wave (đổi ở tab Set). Easter egg: ^ ^ v v < > < > B A hoặc gõ KONAMI / UUDDLRLRBA bên dưới.", 46)
		do
			local eggBox = Row5(FN, 35, "Nhập mã bí mật (vd: UUDDLRLRBA)...", 36, false, nil)
			ActionBtn(FN, "Submit Code", 36, function()
				if konamiText(eggBox.Text) then
					eggBox.Text = ""
					return "KONAMI!"
				end
				return "Mã không đúng..."
			end)
		end

		Tips["master volume"] = "Âm lượng tổng: nhân toàn bộ Sound/AudioEmitter với % bạn chọn. Cần bật toggle trước; tắt sẽ trả lại đúng âm lượng gốc."
		Tips["mute game music"] = "Tắt nhạc nền của game: đoán theo tên Sound/SoundGroup chứa music, bgm, theme, soundtrack, background."
		Tips["ui click sound"] = "Phát âm khi bấm nút của Jump Hub. Nếu executor/game không nạp được file âm thanh sẽ báo Không hỗ trợ."
		Tips["submit code"] = "Nhập mã cho mobile (bàn phím gõ được KONAMI hoặc UUDDLRLRBA)."

		-- ===== driver đợt D =====
		local function DDriver(dt, c)
			local pctChanged = States.MasterVol and lastMasterPct ~= Sliders.MasterPct
			if edgeD("master", States.MasterVol) or pctChanged then
				lastMasterPct = Sliders.MasterPct
				applyMaster(States.MasterVol)
			end
			if edgeD("music", States.MuteMusic) then setMuteMusic(States.MuteMusic) end
			if edgeD("click", States.ClickSound) then setClickSound(States.ClickSound) end
			syncDConns()
		end
		table.insert(Drivers, DDriver)
	end

	-- ===== 8. vòng lặp của v4.1 =====
	-- Kết nối Ở ĐÂY (sau InstallV4, trước vòng lặp chính) để driver v4.0 đặt SpeedBonus
	-- trước, driver v4.1 cộng thêm sau, rồi vòng lặp chính mới ghi hum.WalkSpeed.
	local lastSlow5 = 0
	local function RefreshCtx(dt)
		ctx.dt = dt
		ctx.now = tick()
		ctx.char = Player.Character
		ctx.hum = ctx.char and ctx.char:FindFirstChildOfClass("Humanoid")
		ctx.root = ctx.char and ctx.char:FindFirstChild("HumanoidRootPart")
		ctx.cam = workspace.CurrentCamera
	end

	RunService.Heartbeat:Connect(function(dt)
		RefreshCtx(dt)
		for _, fn in ipairs(Drivers) do
			local ok, err = pcall(fn, dt, ctx)
			if not ok then Log("frame: " .. tostring(err)) end
		end
		if ctx.now - lastSlow5 >= 0.25 then
			lastSlow5 = ctx.now
			for _, fn in ipairs(Slows) do
				local ok, err = pcall(fn, ctx.now, ctx)
				if not ok then Log("slow: " .. tostring(err)) end
			end
		end
	end)

	RunService:BindToRenderStep("JumpHubV5Cam", Enum.RenderPriority.Camera.Value + 2, function(dt)
		RefreshCtx(dt)
		for _, fn in ipairs(CamDrivers) do
			local ok, err = pcall(fn, dt, ctx)
			if not ok then Log("cam: " .. tostring(err)) end
		end
	end)

	for _, fn in ipairs(LateInit) do
		local ok, err = pcall(fn)
		if not ok then Log("init: " .. tostring(err)) end
	end

	Show(CurrentPage)
	print("[JumpHub] v4.1 extension installed")
end

local okV5, errV5 = pcall(InstallV5)
if not okV5 then
	warn("[JumpHub] v4.1 extension failed to load: " .. tostring(errV5))
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
			char:PivotTo(char:GetPivot() * CFrame.Angles(0, (Sliders.SpinRate or 10) / 100, 0))
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