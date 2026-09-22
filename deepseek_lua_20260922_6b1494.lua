-- ============================================================
-- AUTO FULL CYCLE — FARM KENTANG → PANASIN → SELL HOMELESS
-- Speed 150 stud/s · Hop 15 stud · Loop Otomatis
-- ============================================================
if not game:IsLoaded() then game.Loaded:Wait() end

local Players    = game:GetService("Players")
local Workspace  = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CoreGui    = game:GetService("CoreGui")
local UIS        = game:GetService("UserInputService")
local RS         = game:GetService("ReplicatedStorage")

while not Players.LocalPlayer do task.wait(0.1) end
local LP = Players.LocalPlayer

local UI_Target = (gethui and gethui()) or CoreGui or LP:WaitForChild("PlayerGui")
local old = UI_Target:FindFirstChild("AutoFullCycle_UI")
if old then old:Destroy() end

local originalGravity = Workspace.Gravity

-- ============================================================
-- KOORDINAT
-- ============================================================
local BUY_LOC = Vector3.new(-759.197, 3.489, -194.846)

local CHIPS_COORDS = {
    A = Vector3.new(-478.83, 3.86, -438.92),
    B = Vector3.new(-461.69, 3.86, -461.25),
    C = Vector3.new(-461.69, 3.86, -472.88),
    D = Vector3.new(-462.75, 3.86, -521.94),
}

local CHIPS_POTS = {
    Vector3.new(-515.28, 3.86, -451.71),
    Vector3.new(-515.24, 3.86, -462.26),
    Vector3.new(-515.28, 3.86, -471.89),
    Vector3.new(-515.28, 3.86, -481.75),
    Vector3.new(-515.24, 3.86, -492.10),
    Vector3.new(-496.99, 3.86, -452.21),
    Vector3.new(-496.95, 3.86, -462.02),
    Vector3.new(-496.98, 3.86, -471.73),
    Vector3.new(-496.99, 3.86, -481.82),
    Vector3.new(-497.04, 3.86, -491.37),
}

local SC_HOMELESS = {
    Vector3.new(-315.35, 3.72,  -361.56),
    Vector3.new(-273.52, 3.85,  -211.32),
    Vector3.new(1102.42, 3.36,  527.05),
    Vector3.new(52.89,   3.72,  -425.36),
    Vector3.new(152.88,  3.73,  -210.08),
    Vector3.new(-522.75, -7.86, -165.08),
    Vector3.new(65.12,   3.73,  68.10),
    Vector3.new(26.04,   3.73,  217.89),
    Vector3.new(520.08,  3.87,  -295.52),
    Vector3.new(699.28,  3.72,  -427.05),
    Vector3.new(900.03,  3.94,  -283.12),
    Vector3.new(874.89,  3.73,  -63.02),
}

local SC_TUKAR = Vector3.new(-34.91, 4.56, -24.15)
local SC_COOK  = Vector3.new(-487.11, 3.86, -454.16)

local IDX_FLOUR  = 1
local IDX_POTATO = 2

local RE
pcall(function()
    RE = RS:WaitForChild("RemoteEvents", 5):WaitForChild("ReliableRemoteEvent", 5)
end)

local ST = {
    running     = false,
    pot         = 1,
    cycle       = 0,
    targetChips = 5,   -- default jumlah chips yang mau dimasak per siklus
}

-- ============================================================
-- TP SETTINGS
-- ============================================================
local MAX_SPEED = 150
local HOP_DIST  = 15
local MIN_DELAY = 0.04
local MAX_DELAY = 0.5

local DELAY = {
    afterTP      = 0.6,
    insertPotato = 2.0,
    cookProcess  = 2.0,
    insertFlour  = 2.0,
    potOpen      = 0.8,
    claimChips   = 1.5,
    panasinWait  = 1.8,
    sellWait     = 0.3,
    cookTime     = 60,
}

-- ============================================================
-- ANTI-AFK
-- ============================================================
task.spawn(function()
    local vu = game:GetService("VirtualUser")
    LP.Idled:Connect(function()
        vu:Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
        task.wait(1)
        vu:Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
    end)
end)

-- ============================================================
-- GHOST MODE
-- ============================================================
local modifiedParts = {}
local ghostConn = nil

local function startGhostMode()
    if ghostConn then return end
    ghostConn = RunService.Heartbeat:Connect(function()
        local char = LP.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        local hum = char:FindFirstChild("Humanoid")
        if hum and hum.Sit then return end
        local hrp = char.HumanoidRootPart

        local function processPart(part)
            if not part or not part:IsA("BasePart") or part:IsA("Terrain") then return end
            if part:IsDescendantOf(char) then return end
            if part:IsA("Seat") or part:IsA("VehicleSeat") or part.Name:lower():find("seat") then return end
            if not modifiedParts[part] then
                modifiedParts[part] = { CanCollide = part.CanCollide, CanTouch = part.CanTouch }
            end
            part.CanCollide = false
            part.CanTouch   = false
        end

        for _, part in ipairs(hrp:GetTouchingParts()) do processPart(part) end

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {char}
        for _, dir in ipairs({
            Vector3.new(0, -4, 0),
            hrp.CFrame.LookVector * 3.5,
            -hrp.CFrame.LookVector * 3.5,
            hrp.CFrame.RightVector * 3.5,
            -hrp.CFrame.RightVector * 3.5
        }) do
            local res = Workspace:Raycast(hrp.Position, dir, params)
            if res and res.Instance then processPart(res.Instance) end
        end
    end)
end

local function stopGhostMode()
    if ghostConn then ghostConn:Disconnect(); ghostConn = nil end
    for part, state in pairs(modifiedParts) do
        if part and part.Parent then
            part.CanCollide = state.CanCollide
            part.CanTouch   = state.CanTouch
        end
    end
    modifiedParts = {}
end

-- ============================================================
-- UNIVERSAL HOP TP (VEHICLE + CHARACTER)
-- ============================================================
local tpBusy = false

local function hopTP(targetPos)
    if tpBusy then return false, "Busy" end
    local char = LP.Character
    if not char then return false, "No character" end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false, "No humanoid / dead" end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false, "No HRP" end

    tpBusy = true
    startGhostMode()

    local seat = hum.SeatPart
    local vehicle = seat and seat:FindFirstAncestorOfClass("Model")
    local vRoot = vehicle and (vehicle.PrimaryPart or seat)

    if not vehicle then
        hum.PlatformStand = true
        Workspace.Gravity = 0
    end

    local startPos, rot, tempWeld
    local targetCFramePos = targetPos + Vector3.new(0, 3, 0)

    if vehicle and vRoot then
        pcall(function()
            tempWeld = Instance.new("WeldConstraint")
            tempWeld.Name = "TP_TempWeld"
            tempWeld.Part0 = hrp
            tempWeld.Part1 = seat
            tempWeld.Parent = hrp
        end)
        pcall(function()
            vRoot.AssemblyLinearVelocity  = Vector3.zero
            vRoot.AssemblyAngularVelocity = Vector3.zero
            hrp.AssemblyLinearVelocity    = Vector3.zero
            hrp.AssemblyAngularVelocity   = Vector3.zero
        end)
        task.wait(0.05)
        startPos = vRoot.Position
        rot = vRoot.CFrame.Rotation
    else
        startPos = hrp.Position
        rot = hrp.CFrame.Rotation
    end

    local totalDist = (targetCFramePos - startPos).Magnitude
    local hopCount  = math.max(1, math.ceil(totalDist / HOP_DIST))
    local hopDelay  = math.clamp(HOP_DIST / MAX_SPEED, MIN_DELAY, MAX_DELAY)

    for i = 1, hopCount do
        if not ST.running then break end
        local t = i / hopCount
        local stepPos = startPos:Lerp(targetCFramePos, t)

        if vehicle and vRoot then
            pcall(function() vehicle:PivotTo(CFrame.new(stepPos) * rot) end)
            pcall(function()
                if hrp.Parent and seat.Parent then
                    hrp.CFrame = seat.CFrame * CFrame.new(0, 1.5, 0)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end
                if vRoot.Parent then
                    vRoot.AssemblyLinearVelocity = Vector3.zero
                    vRoot.AssemblyAngularVelocity = Vector3.zero
                end
            end)
        else
            pcall(function()
                hrp.CFrame = CFrame.new(stepPos) * rot
                hrp.AssemblyLinearVelocity  = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
        end
        task.wait(hopDelay)
    end

    if vehicle and vRoot then
        pcall(function() vehicle:PivotTo(CFrame.new(targetCFramePos) * rot) end)
        task.wait(0.1)
        pcall(function()
            if hrp.Parent and seat.Parent then
                hrp.CFrame = seat.CFrame * CFrame.new(0, 1.5, 0)
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
        end)
        pcall(function()
            if tempWeld and tempWeld.Parent then tempWeld:Destroy() end
        end)
    else
        pcall(function()
            hrp.CFrame = CFrame.new(targetCFramePos) * rot
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
        Workspace.Gravity = originalGravity
        if hum then hum.PlatformStand = false end
    end

    stopGhostMode()
    tpBusy = false
    return true, "OK"
end

-- ============================================================
-- PROXIMITY PROMPT ROBUST
-- ============================================================
local function firePromptAt(pos, maxDist)
    maxDist = maxDist or 30
    local best, bestDist = nil, maxDist
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local parent = obj.Parent
            local pPos = nil
            if parent then
                if parent:IsA("BasePart") then pPos = parent.Position
                elseif parent:IsA("Attachment") then pPos = parent.WorldPosition
                elseif parent:IsA("Model") then
                    local rp = parent.PrimaryPart or parent:FindFirstChildOfClass("BasePart")
                    if rp then pPos = rp.Position end
                elseif parent:IsA("Folder") then
                    local rp = parent:FindFirstChildOfClass("BasePart")
                    if rp then pPos = rp.Position end
                end
            end
            if pPos then
                local d = (pos - pPos).Magnitude
                if d <= bestDist then
                    bestDist = d
                    best = obj
                end
            end
        end
    end
    if not best then return false end
    pcall(function()
        best.MaxActivationDistance = 9999
        best.RequiresLineOfSight = false
        best.HoldDuration = 0
    end)
    if fireproximityprompt then
        pcall(function() fireproximityprompt(best, 0) end)
    else
        pcall(function()
            best:InputHoldBegin()
            task.wait(0.05)
            best:InputHoldEnd()
        end)
    end
    return true
end

-- ============================================================
-- INVENTORY / TOOL HELPERS
-- ============================================================
local function getCount(name)
    local c = 0
    local bp = LP:FindFirstChild("Backpack")
    if bp then
        for _, v in pairs(bp:GetChildren()) do
            if v.Name == name then c = c + 1 end
        end
    end
    local char = LP.Character
    if char then
        for _, v in pairs(char:GetChildren()) do
            if v:IsA("Tool") and v.Name == name then c = c + 1 end
        end
    end
    return c
end

-- Cek kedua nama (Chips / Potato Chips) — ambil yang ada
local function countPotatoChips()
    local a = getCount("Chips")
    local b = getCount("Potato Chips")
    if a > 0 then return a end
    return b
end

local function equipTool(name)
    local char = LP.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    if char:FindFirstChild(name) then return true end
    hum:UnequipTools()
    task.wait(0.05)
    local bp = LP:FindFirstChild("Backpack")
    if not bp then return false end
    local tool = bp:FindFirstChild(name)
    if not tool then
        for _, v in pairs(bp:GetChildren()) do
            if v:IsA("Tool") and v.Name:lower():find(name:lower()) then
                tool = v; break
            end
        end
    end
    if tool then
        hum:EquipTool(tool)
        task.wait(0.15)
        return true
    end
    return false
end

-- ============================================================
-- AUTO BUY
-- ============================================================
local function fireBuyIndex(index)
    if not RE then return false end
    local ok = pcall(function()
        local buf = buffer.create(3)
        buffer.writeu8(buf, 0, 24)
        buffer.writeu8(buf, 1, 21)
        buffer.writeu8(buf, 2, index)
        RE:FireServer(buf)
    end)
    return ok
end

local function buyUntilEnough(index, itemName, target, maxAttempts)
    maxAttempts = maxAttempts or 40
    if getCount(itemName) >= target then return true end
    local attempt = 0
    while ST.running and attempt < maxAttempts do
        attempt = attempt + 1
        if not fireBuyIndex(index) then return false end
        local deadline = os.clock() + 2
        repeat task.wait(0.05) until getCount(itemName) >= target or os.clock() > deadline
        if getCount(itemName) >= target then return true end
        task.wait(0.1)
    end
    return getCount(itemName) >= target
end

-- ============================================================
-- WAIT HELPERS
-- ============================================================
local function waitUntilConsumed(toolName, timeout)
    timeout = timeout or 6
    local before = getCount(toolName)
    local t0 = os.clock()
    while ST.running and (os.clock() - t0) < timeout do
        if getCount(toolName) < before then return true end
        task.wait(0.08)
    end
    return false
end

-- ============================================================
-- FARM 1 SIKLUS (bikin 1 chip)
-- ============================================================
local function farmOneChip()
    -- Beli bahan kalau kurang
    if getCount("Potato") < 1 or getCount("Flour") < 1 then
        updateStatus("🛒 Beli bahan...", Color3.fromRGB(255, 200, 80))
        hopTP(BUY_LOC)
        if not ST.running then return false end
        task.wait(DELAY.afterTP)
        buyUntilEnough(IDX_POTATO, "Potato", 1, 40)
        if not ST.running then return false end
        buyUntilEnough(IDX_FLOUR, "Flour", 1, 40)
        if not ST.running then return false end
    end

    -- Step A
    hopTP(CHIPS_COORDS.A)
    if not ST.running then return false end
    task.wait(DELAY.afterTP)
    firePromptAt(CHIPS_COORDS.A, 8)
    task.wait(0.5)
    if not ST.running then return false end

    -- Step B — Insert Potato
    hopTP(CHIPS_COORDS.B)
    if not ST.running then return false end
    task.wait(DELAY.afterTP)
    equipTool("Potato")
    task.wait(0.25)
    firePromptAt(CHIPS_COORDS.B, 8)
    updateStatus("🥔 Kentang masuk plastik...", Color3.fromRGB(255, 200, 80))
    waitUntilConsumed("Potato", 6)
    task.wait(DELAY.insertPotato)
    if not ST.running then return false end

    -- Step C — Cook
    hopTP(CHIPS_COORDS.C)
    if not ST.running then return false end
    task.wait(DELAY.afterTP)
    firePromptAt(CHIPS_COORDS.C, 8)
    task.wait(DELAY.cookProcess)
    if not ST.running then return false end

    -- Step D — Insert Flour
    hopTP(CHIPS_COORDS.D)
    if not ST.running then return false end
    task.wait(DELAY.afterTP)
    equipTool("Flour")
    task.wait(0.25)
    firePromptAt(CHIPS_COORDS.D, 8)
    updateStatus("🍞 Flour masuk...", Color3.fromRGB(220, 180, 100))
    waitUntilConsumed("Flour", 6)
    task.wait(DELAY.insertFlour)
    if not ST.running then return false end

    -- Step E — Pot
    local pot = CHIPS_POTS[ST.pot]
    hopTP(pot)
    if not ST.running then return false end
    task.wait(DELAY.afterTP)
    firePromptAt(pot, 8)
    task.wait(DELAY.potOpen)
    if not ST.running then return false end

    -- Tunggu masak
    for i = 1, DELAY.cookTime do
        if not ST.running then return false end
        task.wait(1)
        if i % 5 == 0 then
            updateStatus(("🍟 Masak... %ds"):format(DELAY.cookTime - i), Color3.fromRGB(255, 160, 60))
        end
    end
    if not ST.running then return false end

    -- Claim
    updateStatus("🍟 Claim Chips!", Color3.fromRGB(0, 220, 100))
    hopTP(pot)
    if not ST.running then return false end
    task.wait(DELAY.afterTP)
    local before = countPotatoChips()
    firePromptAt(pot, 8)
    local t0 = os.clock()
    while ST.running and (os.clock() - t0) < 5 do
        if countPotatoChips() > before then break end
        task.wait(0.1)
    end
    task.wait(DELAY.claimChips)
    return true
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
local function doFullCycle()
    while ST.running do
        ST.cycle = ST.cycle + 1
        updateCycle(("Siklus #%d · Target %d chips"):format(ST.cycle, ST.targetChips))

        -- ============ FASE 1: FARM KENTANG ============
        local madeThisCycle = 0
        while ST.running and madeThisCycle < ST.targetChips do
            local have = countPotatoChips()
            updateStatus(("🥔 Farm chips %d/%d (stok: %d)..."):format(
                madeThisCycle + 1, ST.targetChips, have),
                Color3.fromRGB(80, 200, 255))
            updateCycle(("Siklus #%d · Farm %d/%d · Stok: %d"):format(
                ST.cycle, madeThisCycle + 1, ST.targetChips, have))

            local ok = farmOneChip()
            if not ok then break end
            madeThisCycle = madeThisCycle + 1
        end
        if not ST.running then break end

        -- ============ FASE 2: PANASIN ============
        local rawCount = countPotatoChips()
        if rawCount > 0 then
            updateStatus(("🔥 Panasin %d Chips → Hot..."):format(rawCount),
                Color3.fromRGB(255, 160, 60))
            updateCycle(("Siklus #%d · Panasin %d chips"):format(ST.cycle, rawCount))

            hopTP(SC_TUKAR)
            if not ST.running then break end
            task.wait(DELAY.afterTP)
            firePromptAt(SC_TUKAR, 30)
            task.wait(DELAY.panasinWait)

            -- Retry sekali kalau gagal
            if countPotatoChips() > 0 and ST.running then
                firePromptAt(SC_TUKAR, 30)
                task.wait(DELAY.panasinWait)
            end
        end
        if not ST.running then break end

        -- ============ FASE 3: SELL HOMELESS ============
        local hotCount = getCount("Hot Chips")
        if hotCount > 0 then
            updateStatus(("🏠 Jual %d Hot Chips..."):format(hotCount),
                Color3.fromRGB(0, 220, 100))

            equipTool("Hot Chips")
            task.wait(0.3)
            if not ST.running then break end

            local visits = math.min(hotCount, #SC_HOMELESS)
            for i = 1, visits do
                if not ST.running then break end
                updateStatus(("🏠 Homeless %d/%d..."):format(i, visits),
                    Color3.fromRGB(0, 220, 100))
                updateCycle(("Siklus #%d · Sell %d/%d · Sisa Hot: %d"):format(
                    ST.cycle, i, visits, getCount("Hot Chips")))

                local ok = hopTP(SC_HOMELESS[i])
                if ok then
                    task.wait(DELAY.sellWait)
                    if not LP.Character:FindFirstChild("Hot Chips") then
                        equipTool("Hot Chips")
                        task.wait(0.15)
                    end
                    firePromptAt(SC_HOMELESS[i], 30)
                    task.wait(0.25)
                end
            end

            -- Sisa hot chips → TP cook
            if ST.running and getCount("Hot Chips") > 0 then
                updateStatus("⚠ Sisa Hot → TP Chips Cook...", Color3.fromRGB(255, 160, 60))
                hopTP(SC_COOK)
                task.wait(0.5)
            end
        end
        if not ST.running then break end

        updateStatus(("✅ Siklus #%d selesai! Ulang lagi..."):format(ST.cycle),
            Color3.fromRGB(0, 220, 100))
        updateCycle("")
        task.wait(1.0)
    end

    ST.running = false
    refreshToggle()
    updateStatus("Dihentikan.", Color3.fromRGB(180, 60, 60))
    updateCycle("")
end

-- ============================================================
-- UI
-- ============================================================
local Gui = Instance.new("ScreenGui")
Gui.Name = "AutoFullCycle_UI"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.DisplayOrder = 9999
Gui.Parent = UI_Target

local Main = Instance.new("Frame", Gui)
Main.Size = UDim2.new(0, 260, 0, 420)
Main.Position = UDim2.new(0.05, 0, 0.15, 0)
Main.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
local mainStroke = Instance.new("UIStroke", Main)
mainStroke.Color = Color3.fromRGB(0, 200, 100)
mainStroke.Thickness = 1.5

local Header = Instance.new("Frame", Main)
Header.Size = UDim2.new(1, 0, 0, 34)
Header.BackgroundColor3 = Color3.fromRGB(10, 26, 16)
Header.BorderSizePixel = 0
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)
local hFix = Instance.new("Frame", Header)
hFix.Size = UDim2.new(1, 0, 0, 8)
hFix.Position = UDim2.new(0, 0, 1, -8)
hFix.BackgroundColor3 = Color3.fromRGB(10, 26, 16)
hFix.BorderSizePixel = 0

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(1, -40, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "🔁 AUTO FULL CYCLE"
Title.TextColor3 = Color3.fromRGB(100, 255, 180)
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Left

local CloseBtn = Instance.new("TextButton", Header)
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(1, -28, 0.5, -12)
CloseBtn.BackgroundColor3 = Color3.fromRGB(35, 12, 12)
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(220, 80, 80)
CloseBtn.Font = Enum.Font.GothamBlack
CloseBtn.TextSize = 16
CloseBtn.AutoButtonColor = false
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

local Content = Instance.new("Frame", Main)
Content.Size = UDim2.new(1, -20, 1, -44)
Content.Position = UDim2.new(0, 10, 0, 40)
Content.BackgroundTransparency = 1
local Layout = Instance.new("UIListLayout", Content)
Layout.Padding = UDim.new(0, 8)
Layout.SortOrder = Enum.SortOrder.LayoutOrder

-- Toggle
local ToggleBtn = Instance.new("TextButton", Content)
ToggleBtn.Size = UDim2.new(1, 0, 0, 40)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(35, 12, 12)
ToggleBtn.Text = "OFF"
ToggleBtn.TextColor3 = Color3.fromRGB(220, 80, 80)
ToggleBtn.Font = Enum.Font.GothamBlack
ToggleBtn.TextSize = 14
ToggleBtn.AutoButtonColor = false
ToggleBtn.LayoutOrder = 1
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 8)
local tStr = Instance.new("UIStroke", ToggleBtn)
tStr.Color = Color3.fromRGB(80, 25, 25)
tStr.Thickness = 1

-- ============================================================
-- SLIDER: JUMLAH MASAK
-- ============================================================
local SliderFrame = Instance.new("Frame", Content)
SliderFrame.Size = UDim2.new(1, 0, 0, 48)
SliderFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
SliderFrame.LayoutOrder = 2
Instance.new("UICorner", SliderFrame).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", SliderFrame).Color = Color3.fromRGB(40, 40, 50)

local SliderLabel = Instance.new("TextLabel", SliderFrame)
SliderLabel.Size = UDim2.new(1, -16, 0, 16)
SliderLabel.Position = UDim2.new(0, 10, 0, 4)
SliderLabel.BackgroundTransparency = 1
SliderLabel.Text = "Jumlah Masak: " .. ST.targetChips
SliderLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
SliderLabel.Font = Enum.Font.GothamBold
SliderLabel.TextSize = 11
SliderLabel.TextXAlignment = Enum.TextXAlignment.Left

local Track = Instance.new("Frame", SliderFrame)
Track.Size = UDim2.new(1, -20, 0, 6)
Track.Position = UDim2.new(0, 10, 0, 32)
Track.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
Track.BorderSizePixel = 0
Instance.new("UICorner", Track).CornerRadius = UDim.new(1, 0)

local Fill = Instance.new("Frame", Track)
Fill.Size = UDim2.new(0, 0, 1, 0)
Fill.BackgroundColor3 = Color3.fromRGB(80, 180, 255)
Fill.BorderSizePixel = 0
Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)

local Handle = Instance.new("TextButton", Track)
Handle.Size = UDim2.new(0, 16, 0, 16)
Handle.Position = UDim2.new(0, 0, 0.5, -8)
Handle.BackgroundColor3 = Color3.fromRGB(80, 180, 255)
Handle.Text = ""
Handle.AutoButtonColor = false
Instance.new("UICorner", Handle).CornerRadius = UDim.new(1, 0)

local SLIDER_MIN, SLIDER_MAX = 1, 100
local dragging = false

local function updateSliderVisual(value)
    value = math.clamp(math.floor(value + 0.5), SLIDER_MIN, SLIDER_MAX)
    local pct = (value - SLIDER_MIN) / (SLIDER_MAX - SLIDER_MIN)
    Fill.Size = UDim2.new(pct, 0, 1, 0)
    Handle.Position = UDim2.new(pct, -8, 0.5, -8)
    SliderLabel.Text = "Jumlah Masak: " .. value
    ST.targetChips = value
end

local function updateSliderFromX(x)
    local relX = math.clamp((x - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
    updateSliderVisual(SLIDER_MIN + (SLIDER_MAX - SLIDER_MIN) * relX)
end

Handle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
    end
end)

Track.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        updateSliderFromX(input.Position.X)
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
       or input.UserInputType == Enum.UserInputType.Touch) then
        updateSliderFromX(input.Position.X)
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

updateSliderVisual(ST.targetChips)

-- ============================================================
-- POT SELECTOR
-- ============================================================
local PotLabel = Instance.new("TextLabel", Content)
PotLabel.Size = UDim2.new(1, 0, 0, 14)
PotLabel.BackgroundTransparency = 1
PotLabel.Text = "Pilih Pot:"
PotLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
PotLabel.Font = Enum.Font.GothamBold
PotLabel.TextSize = 11
PotLabel.TextXAlignment = Enum.TextXAlignment.Left
PotLabel.LayoutOrder = 3

local PotGrid = Instance.new("Frame", Content)
PotGrid.Size = UDim2.new(1, 0, 0, 66)
PotGrid.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
PotGrid.LayoutOrder = 4
Instance.new("UICorner", PotGrid).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", PotGrid).Color = Color3.fromRGB(40, 40, 50)

local potBtns = {}
local function refreshPotBtns()
    for i, btn in ipairs(potBtns) do
        local sel = ST.pot == i
        btn.BackgroundColor3 = sel and Color3.fromRGB(20, 70, 130) or Color3.fromRGB(22, 22, 22)
        local s = btn:FindFirstChildOfClass("UIStroke")
        if s then s.Color = sel and Color3.fromRGB(80, 180, 255) or Color3.fromRGB(50, 50, 50) end
        local l = btn:FindFirstChildOfClass("TextLabel")
        if l then l.TextColor3 = sel and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 150) end
    end
end

for i = 1, 10 do
    local col = (i-1) % 5
    local row = math.floor((i-1) / 5)
    local pw = 1/5
    local pBtn = Instance.new("TextButton", PotGrid)
    pBtn.Size = UDim2.new(pw - 0.02, 0, 0, 24)
    pBtn.Position = UDim2.new(col*pw + 0.01, 0, 0, 8 + row*30)
    pBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    pBtn.Text = ""
    pBtn.AutoButtonColor = false
    Instance.new("UICorner", pBtn).CornerRadius = UDim.new(0, 6)
    local pbs = Instance.new("UIStroke", pBtn)
    pbs.Color = Color3.fromRGB(50, 50, 50)
    local pbl = Instance.new("TextLabel", pBtn)
    pbl.Size = UDim2.new(1, 0, 1, 0)
    pbl.BackgroundTransparency = 1
    pbl.Text = tostring(i)
    pbl.TextColor3 = Color3.fromRGB(150, 150, 150)
    pbl.Font = Enum.Font.GothamBlack
    pbl.TextSize = 12
    table.insert(potBtns, pBtn)
    local capI = i
    pBtn.MouseButton1Click:Connect(function()
        if ST.running then return end
        ST.pot = capI
        refreshPotBtns()
    end)
end
refreshPotBtns()

-- Info card
local InfoCard = Instance.new("Frame", Content)
InfoCard.Size = UDim2.new(1, 0, 0, 66)
InfoCard.BackgroundColor3 = Color3.fromRGB(10, 26, 16)
InfoCard.LayoutOrder = 5
Instance.new("UICorner", InfoCard).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", InfoCard).Color = Color3.fromRGB(20, 80, 50)

local infoTxt = Instance.new("TextLabel", InfoCard)
infoTxt.Size = UDim2.new(1, -12, 1, -8)
infoTxt.Position = UDim2.new(0, 6, 0, 4)
infoTxt.BackgroundTransparency = 1
infoTxt.TextXAlignment = Enum.TextXAlignment.Left
infoTxt.TextYAlignment = Enum.TextYAlignment.Top
infoTxt.TextColor3 = Color3.fromRGB(140, 220, 180)
infoTxt.Font = Enum.Font.Gotham
infoTxt.TextSize = 10
infoTxt.Text = "🔄 Flow: Farm → Panasin → Sell → Ulangi\n🚀 TP Hop 150 stud/s (tanpa respawn)\n⚙ Butuh kendaraan untuk TP"

-- Status
local StatusLabel = Instance.new("TextLabel", Content)
StatusLabel.Size = UDim2.new(1, 0, 0, 16)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: Idle"
StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextSize = 11
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.LayoutOrder = 6

local CycleLabel = Instance.new("TextLabel", Content)
CycleLabel.Size = UDim2.new(1, 0, 0, 16)
CycleLabel.BackgroundTransparency = 1
CycleLabel.Text = ""
CycleLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
CycleLabel.Font = Enum.Font.GothamBold
CycleLabel.TextSize = 11
CycleLabel.TextXAlignment = Enum.TextXAlignment.Left
CycleLabel.LayoutOrder = 7

function updateStatus(txt, col)
    StatusLabel.Text = txt
    if col then StatusLabel.TextColor3 = col end
end
function updateCycle(txt)
    CycleLabel.Text = txt or ""
end
function refreshToggle()
    local on = ST.running
    ToggleBtn.BackgroundColor3 = on and Color3.fromRGB(10, 45, 25) or Color3.fromRGB(35, 12, 12)
    ToggleBtn.TextColor3 = on and Color3.fromRGB(100, 255, 180) or Color3.fromRGB(220, 80, 80)
    ToggleBtn.Text = on and "🔁 ON · Sedang Berjalan" or "OFF"
    tStr.Color = on and Color3.fromRGB(30, 120, 70) or Color3.fromRGB(80, 25, 25)
end
refreshToggle()

ToggleBtn.MouseButton1Click:Connect(function()
    if not ST.running then
        ST.running = true
        ST.cycle = 0
        refreshToggle()
        updateStatus("Memulai full cycle...", Color3.fromRGB(100, 255, 180))
        task.spawn(function()
            local ok, err = pcall(doFullCycle)
            if not ok then
                warn("[AutoFullCycle] Error:", err)
                updateStatus("Error: " .. tostring(err), Color3.fromRGB(255, 80, 80))
            end
            ST.running = false
            refreshToggle()
            updateCycle("")
        end)
    else
        ST.running = false
        refreshToggle()
        updateStatus("Dihentikan manual.", Color3.fromRGB(180, 60, 60))
        updateCycle("")
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    ST.running = false
    Gui:Destroy()
end)

updateStatus("Idle · Atur jumlah masak lalu ON", Color3.fromRGB(150, 150, 150))
print("[AUTO FULL CYCLE] Loaded! Flow: Farm → Panasin → Sell → Ulang")