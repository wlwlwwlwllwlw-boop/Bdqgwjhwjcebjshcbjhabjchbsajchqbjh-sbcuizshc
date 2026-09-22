-- ================================================================
-- LENGER STORE — CARD SCAM ONLY v5 (FIXED COORD CLAIM)
-- Flow: Buy Fake ID → Apply → TP ke coord claim → Wait → Claim
--       → Swipe ATM → Repeat
-- ================================================================

if getgenv().LENGER_CARDSCAM_LOADED then
    pcall(function()
        if getgenv().LENGER_CARDSCAM_UI then getgenv().LENGER_CARDSCAM_UI:Destroy() end
    end)
end
getgenv().LENGER_CARDSCAM_LOADED = true

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local VIM     = game:GetService("VirtualInputManager")
local UIS     = game:GetService("UserInputService")
local LP      = Players.LocalPlayer

-- ================================================================
-- VEHICLE TP (FAST — 150 stud/s)
-- ================================================================
local MAX_SPEED = 150
local HOP_DIST  = 15
local MIN_DELAY = 0.04
local MAX_DELAY = 0.5
local tpBusy    = false

local function doVehicleTP(targetPos)
    if tpBusy then return false, "Sedang proses..." end

    local char = LP.Character
    if not char then return false, "Karakter belum spawn" end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false, "Humanoid tidak ada" end
    if hum.Health <= 0 then return false, "Kamu mati" end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false, "HRP tidak ada" end
    local seat = hum.SeatPart
    if not seat then return false, "Naik kendaraan dulu!" end
    local vehicle = seat:FindFirstAncestorOfClass("Model")
    if not vehicle then return false, "Vehicle tidak ditemukan!" end
    local vRoot = vehicle.PrimaryPart or seat
    if not vRoot then return false, "Vehicle root tidak ada" end

    tpBusy = true

    local tempWeld
    pcall(function()
        tempWeld = Instance.new("WeldConstraint")
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

    local startPos   = vRoot.Position
    local targetPosV = Vector3.new(targetPos.X, targetPos.Y + 3, targetPos.Z)
    local rot        = vRoot.CFrame.Rotation

    local totalDist = (targetPosV - startPos).Magnitude
    local hopCount  = math.max(1, math.ceil(totalDist / HOP_DIST))
    local hopDelay  = math.clamp(HOP_DIST / MAX_SPEED, MIN_DELAY, MAX_DELAY)

    for i = 1, hopCount do
        if not getgenv().CARD_SCAM_RUNNING then
            pcall(function() if tempWeld and tempWeld.Parent then tempWeld:Destroy() end end)
            tpBusy = false
            return false, "Cancelled"
        end

        local t = i / hopCount
        local stepPos = startPos:Lerp(targetPosV, t)

        pcall(function() vehicle:PivotTo(CFrame.new(stepPos) * rot) end)
        pcall(function()
            if hrp and hrp.Parent and seat and seat.Parent then
                hrp.CFrame = seat.CFrame * CFrame.new(0, 1.5, 0)
                hrp.AssemblyLinearVelocity  = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
            if vRoot and vRoot.Parent then
                vRoot.AssemblyLinearVelocity  = Vector3.zero
                vRoot.AssemblyAngularVelocity = Vector3.zero
            end
        end)

        task.wait(hopDelay)
    end

    pcall(function() vehicle:PivotTo(CFrame.new(targetPosV) * rot) end)
    task.wait(0.1)
    pcall(function()
        if hrp and hrp.Parent and seat and seat.Parent then
            hrp.CFrame = seat.CFrame * CFrame.new(0, 1.5, 0)
            hrp.AssemblyLinearVelocity  = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end)

    task.wait(0.1)
    pcall(function() if tempWeld and tempWeld.Parent then tempWeld:Destroy() end end)

    tpBusy = false
    return true, string.format("OK (%d hop)", hopCount)
end

-- ================================================================
-- KOORDINAT
-- ================================================================
local LOC_FakeID       = Vector3.new( 214.960, 1.857, -332.330)
local LOC_ApplyForCard = Vector3.new( -49.210, 4.000, -310.810)
local LOC_ClaimCard    = Vector3.new( -39.090, 5.392, -329.700)

-- ================================================================
-- HELPERS
-- ================================================================
local function hasItem(name)
    local bp = LP:FindFirstChild("Backpack")
    if bp and bp:FindFirstChild(name) then return true end
    local ch = LP.Character
    if ch and ch:FindFirstChild(name) then return true end
    return false
end

local function equipTool(name)
    local ch  = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    if ch then
        local t = ch:FindFirstChild(name)
        if t and t:IsA("Tool") then return true end
    end
    local bp = LP:FindFirstChild("Backpack")
    if bp then
        local t = bp:FindFirstChild(name)
        if t then
            pcall(function() hum:EquipTool(t) end)
            task.wait(0.25)
            return ch:FindFirstChild(name) ~= nil
        end
    end
    return false
end

local function unequipAll()
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum:UnequipTools() end) end
end

-- ================================================================
-- AUTO BUY FAKE ID
-- ================================================================
local function findFakeIDSellerPrompt()
    local folders = workspace:FindFirstChild("Folders")
    if not folders then return nil, "Folders tidak ditemukan" end
    local npcs = folders:FindFirstChild("NPCs")
    if not npcs then return nil, "NPCs tidak ditemukan" end
    local seller = npcs:FindFirstChild("FakeIDSeller")
    if not seller then return nil, "FakeIDSeller tidak ditemukan" end
    for _, d in ipairs(seller:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            return d, nil
        end
    end
    return nil, "Prompt tidak ditemukan"
end

local function getFakeIDCount()
    local c = 0
    local bp = LP:FindFirstChild("Backpack")
    if bp then
        for _, v in ipairs(bp:GetChildren()) do
            local n = v.Name:lower()
            if n:find("fake") and n:find("id") then c += 1 end
        end
    end
    local ch = LP.Character
    if ch then
        for _, v in ipairs(ch:GetChildren()) do
            if v:IsA("Tool") then
                local n = v.Name:lower()
                if n:find("fake") and n:find("id") then c += 1 end
            end
        end
    end
    return c
end

local function buyFakeID(maxAttempts)
    maxAttempts = maxAttempts or 12

    local prompt, err = findFakeIDSellerPrompt()
    if not prompt then return false, err end

    pcall(function()
        prompt.HoldDuration = 0
        prompt.RequiresLineOfSight = false
        prompt.MaxActivationDistance = 9e9
        prompt.Enabled = true
    end)

    local startCount = getFakeIDCount()

    for attempt = 1, maxAttempts do
        if not getgenv().CARD_SCAM_RUNNING then return false, "Cancelled" end
        pcall(function() fireproximityprompt(prompt) end)
        task.wait(0.4)
        if getFakeIDCount() > startCount then
            return true, "Fake ID didapat"
        end
    end
    return false, "Gagal beli Fake ID"
end

-- ================================================================
-- STEP 1 — BUY FAKE ID
-- ================================================================
local function step_BuyFakeID()
    if hasItem("Fake ID") then return true end
    setStatus("Step 1 · Buy Fake ID...", Color3.fromRGB(255,200,80))

    local ok, err = doVehicleTP(LOC_FakeID)
    if not ok then
        setStatus("TP FakeID gagal: " .. err, Color3.fromRGB(255,80,80))
        return false
    end
    task.wait(0.4)

    local okBuy, msg = buyFakeID(12)
    if okBuy then
        setStatus("Fake ID ✔", Color3.fromRGB(0,220,100))
        return true
    else
        setStatus("Fake ID gagal: " .. tostring(msg), Color3.fromRGB(255,80,80))
        return false
    end
end

-- ================================================================
-- STEP 2 — APPLY CARD
-- ================================================================
local function findBankTellerPrompt()
    local folders = workspace:FindFirstChild("Folders")
    if not folders then return nil end
    local npcs = folders:FindFirstChild("NPCs")
    if not npcs then return nil end
    local teller = npcs:FindFirstChild("Bank Teller")
    if not teller then return nil end
    local upper = teller:FindFirstChild("UpperTorso")
    local att = upper and upper:FindFirstChild("Attachment")
    return att and att:FindFirstChild("ProximityPrompt")
end

local function step_ApplyForCard()
    if not hasItem("Fake ID") then
        setStatus("Fake ID belum ada", Color3.fromRGB(255,80,80))
        return false
    end

    setStatus("Step 2 · Apply Card...", Color3.fromRGB(255,200,80))

    local ok, err = doVehicleTP(LOC_ApplyForCard)
    if not ok then
        setStatus("TP Bank gagal: " .. err, Color3.fromRGB(255,80,80))
        return false
    end
    task.wait(0.5)

    if not equipTool("Fake ID") then
        setStatus("Gagal equip Fake ID", Color3.fromRGB(255,80,80))
        return false
    end
    task.wait(0.3)

    local prompt = findBankTellerPrompt()
    if not prompt then
        setStatus("Bank Teller prompt tidak ada", Color3.fromRGB(255,80,80))
        return false
    end

    pcall(function()
        prompt.HoldDuration = 0
        prompt.RequiresLineOfSight = false
        prompt.MaxActivationDistance = 9e9
    end)

    local attempts = 0
    while hasItem("Fake ID") and attempts < 20 do
        if not getgenv().CARD_SCAM_RUNNING then return false end
        pcall(function() fireproximityprompt(prompt) end)
        task.wait(0.5)
        attempts += 1
    end

    unequipAll()

    if hasItem("Fake ID") then
        setStatus("Apply gagal", Color3.fromRGB(255,80,80))
        return false
    end

    setStatus("Apply Card ✔", Color3.fromRGB(0,220,100))
    return true
end

-- ================================================================
-- STEP 3 — WAIT APPROVAL
-- ================================================================
local function checkApprovalNotif()
    local mainGui = LP.PlayerGui:FindFirstChild("Main")
    local notif = mainGui and mainGui:FindFirstChild("BasicNotification")
    if not notif then return nil end
    if notif.TextTransparency > 0 then return nil end

    local lower = notif.Text:lower()

    if lower:find("not success") or lower:find("unsuccess")
       or lower:find("denied") or lower:find("reject") or lower:find("failed") then
        return false, notif.Text
    end

    if lower:find("successful") or lower:find("success")
       or lower:find("approved") or lower:find("accepted") then
        return true, notif.Text
    end

    return nil, notif.Text
end

local function step_WaitApproval(maxWait)
    maxWait = maxWait or 60
    setStatus("Step 3 · Tunggu approval...", Color3.fromRGB(255,200,80))

    local startT = tick()
    while tick() - startT < maxWait do
        if not getgenv().CARD_SCAM_RUNNING then return nil end
        local result, rawText = checkApprovalNotif()
        if result == true then
            setStatus("Approved ✔", Color3.fromRGB(0,220,100))
            task.wait(2)
            return true
        elseif result == false then
            setStatus("DITOLAK: " .. tostring(rawText), Color3.fromRGB(255,80,80))
            task.wait(2)
            return false
        end
        task.wait(0.4)
    end
    return nil
end

-- ================================================================
-- STEP 5 — CLAIM CARD @ FIXED COORD
-- ================================================================
local function findPromptNear(pos, radius)
    radius = radius or 15
    local bestPrompt, bestDist = nil, radius
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            local part = d.Parent
            local pPos
            if part:IsA("Attachment") then
                pPos = part.WorldPosition
            elseif part:IsA("BasePart") then
                pPos = part.Position
            elseif part:IsA("Model") then
                local rp = part.PrimaryPart or part:FindFirstChildOfClass("BasePart")
                if rp then pPos = rp.Position end
            end
            if pPos then
                local dist = (pPos - pos).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestPrompt = d
                end
            end
        end
    end
    return bestPrompt, bestDist
end

local function step_ClaimCard()
    if hasItem("Card") then return true end

    setStatus("Step 5 · TP ke coord claim...", Color3.fromRGB(255,200,80))

    -- TP ke koordinat fixed
    local ok, err = doVehicleTP(LOC_ClaimCard)
    if not ok then
        setStatus("TP claim gagal: " .. tostring(err), Color3.fromRGB(255,80,80))
        return false
    end

    -- Tunggu sampai benar-benar sampai & settle
    task.wait(1.5)

    -- Cari prompt terdekat dari koordinat claim
    setStatus("Cari prompt claim...", Color3.fromRGB(255,200,80))
    local prompt, dist = findPromptNear(LOC_ClaimCard, 20)

    if not prompt then
        setStatus("Prompt tidak ada di coord claim", Color3.fromRGB(255,80,80))
        return false
    end

    setStatus("Prompt dist " .. string.format("%.1f", dist), Color3.fromRGB(0,220,100))

    pcall(function()
        prompt.HoldDuration = 0
        prompt.RequiresLineOfSight = false
        prompt.MaxActivationDistance = 9e9
    end)

    -- Fire prompt sampai Card masuk
    for i = 1, 20 do
        if not getgenv().CARD_SCAM_RUNNING then return false end

        -- Re-TP tiap iterasi (kalau geser)
        doVehicleTP(LOC_ClaimCard)
        task.wait(0.5)
        pcall(function() fireproximityprompt(prompt) end)
        task.wait(0.6)

        if hasItem("Card") then
            setStatus("Card ✔", Color3.fromRGB(0,220,100))
            return true
        end
    end

    setStatus("Gagal claim Card", Color3.fromRGB(255,80,80))
    return false
end

-- ================================================================
-- STEP 6 — FIND ATM
-- ================================================================
local function findAvailableATM()
    local map = workspace:FindFirstChild("Map")
    local atms = map and map:FindFirstChild("ATMS")
    if not atms then return nil end
    for _, a in pairs(atms:GetChildren()) do
        local screen = a:FindFirstChild("ATMScreen")
        if screen and screen.Transparency == 0 then
            return a
        end
    end
    return nil
end

-- ================================================================
-- STEP 7 — SWIPE CARD
-- ================================================================
local function step_Swipe()
    setStatus("Step 6 · Cari ATM...", Color3.fromRGB(255,200,80))

    local atm
    for i = 1, 20 do
        if not getgenv().CARD_SCAM_RUNNING then return false end
        atm = findAvailableATM()
        if atm then break end
        task.wait(0.5)
    end

    if not atm then
        setStatus("ATM tidak tersedia", Color3.fromRGB(255,80,80))
        return false
    end

    local att = atm:FindFirstChild("Attachment")
    local prompt = att and att:FindFirstChild("ProximityPrompt")
    if not prompt then
        setStatus("ATM prompt tidak ada", Color3.fromRGB(255,80,80))
        return false
    end

    pcall(function()
        prompt.HoldDuration = 0
        prompt.RequiresLineOfSight = false
        prompt.MaxActivationDistance = 9e9
    end)

    setStatus("Step 7 · Buka ATM...", Color3.fromRGB(255,200,80))
    local oldATM = LP.PlayerGui:FindFirstChild("ATM")
    if oldATM then oldATM:Destroy() end

    for i = 1, 10 do
        if not getgenv().CARD_SCAM_RUNNING then return false end
        doVehicleTP(atm.Position)
        task.wait(0.4)
        pcall(function() fireproximityprompt(prompt) end)
        task.wait(0.4)
        if LP.PlayerGui:FindFirstChild("ATM") then break end
    end

    local atmGui = LP.PlayerGui:FindFirstChild("ATM")
    if not atmGui then
        setStatus("ATM gagal terbuka", Color3.fromRGB(255,80,80))
        return false
    end

    if not equipTool("Card") then
        setStatus("Gagal equip Card", Color3.fromRGB(255,80,80))
        return false
    end
    task.wait(0.4)

    local frame = atmGui:FindFirstChild("Frame")
    local swipeBtn = frame and frame:FindFirstChild("Swipe")
    if not swipeBtn then
        setStatus("Tombol Swipe tidak ada", Color3.fromRGB(255,80,80))
        return false
    end

    local clicked = false
    if replicatesignal then
        clicked = pcall(function() replicatesignal(swipeBtn.MouseButton1Click) end)
    end

    if not clicked then
        local pos = swipeBtn.AbsolutePosition
        local size = swipeBtn.AbsoluteSize
        if pos and size then
            VIM:SendMouseButtonEvent(pos.X + size.X/2, pos.Y + size.Y/2, 0, true, game, 0)
            task.wait(0.05)
            VIM:SendMouseButtonEvent(pos.X + size.X/2, pos.Y + size.Y/2, 0, false, game, 0)
        end
    end

    task.wait(0.6)
    unequipAll()
    setStatus("Card di-swipe ✔", Color3.fromRGB(0,220,100))
    return true
end

-- ================================================================
-- MAIN LOOP
-- ================================================================
getgenv().CARD_SCAM_RUNNING = false

local function cardScamLoop()
    local cycle = 0

    while getgenv().CARD_SCAM_RUNNING do
        cycle += 1
        updateUI_Cycle(cycle)
        setStatus("=== Cycle #" .. cycle .. " ===", Color3.fromRGB(120,180,255))

        -- Validasi kendaraan
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then
            setStatus("Mati/spawn... tunggu", Color3.fromRGB(255,80,80))
            LP.CharacterAdded:Wait():WaitForChild("HumanoidRootPart", 10)
            task.wait(1.5)
            if not getgenv().CARD_SCAM_RUNNING then break end
        end

        hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if not hum or not hum.SeatPart then
            setStatus("Naik kendaraan dulu!", Color3.fromRGB(255,80,80))
            task.wait(2)
            if not getgenv().CARD_SCAM_RUNNING then break end
            if not hum or not hum.SeatPart then
                task.wait(2)
                continue
            end
        end

        -- STEP 1: Buy Fake ID
        if not step_BuyFakeID() then
            if not getgenv().CARD_SCAM_RUNNING then break end
            setStatus("Buy FakeID gagal, retry", Color3.fromRGB(255,80,80))
            task.wait(2)
            continue
        end
        if not getgenv().CARD_SCAM_RUNNING then break end

        -- STEP 2: Apply Card
        if not step_ApplyForCard() then
            if not getgenv().CARD_SCAM_RUNNING then break end
            setStatus("Apply gagal, retry", Color3.fromRGB(255,80,80))
            task.wait(2)
            continue
        end
        if not getgenv().CARD_SCAM_RUNNING then break end

        -- STEP 3: Wait Approval
        local approvalResult = step_WaitApproval(60)
        if not getgenv().CARD_SCAM_RUNNING then break end

        if approvalResult == false then
            setStatus("Ditolak, retry cycle", Color3.fromRGB(255,80,80))
            task.wait(3)
            continue
        end

        -- STEP 4: Wait 35s
        if approvalResult == true then
            for i = 35, 1, -1 do
                if not getgenv().CARD_SCAM_RUNNING then break end
                setStatus("Step 4 · Waitlist " .. i .. "s...", Color3.fromRGB(0,220,100))
                task.wait(1)
            end
        else
            setStatus("Approval timeout, coba claim...", Color3.fromRGB(255,200,80))
            task.wait(5)
        end
        if not getgenv().CARD_SCAM_RUNNING then break end

        -- STEP 5: TP ke coord claim + claim
        local claimOK = false
        for attempt = 1, 3 do
            if not getgenv().CARD_SCAM_RUNNING then break end
            if step_ClaimCard() then
                claimOK = true
                break
            end
            if attempt < 3 then
                setStatus("Claim gagal, retry " .. attempt .. "/3", Color3.fromRGB(255,200,80))
                task.wait(4)
            end
        end
        if not getgenv().CARD_SCAM_RUNNING then break end

        if not claimOK then
            setStatus("Claim gagal, retry cycle", Color3.fromRGB(255,80,80))
            task.wait(3)
            continue
        end

        -- STEP 6+7: Find ATM + Swipe
        if not step_Swipe() then
            if not getgenv().CARD_SCAM_RUNNING then break end
            setStatus("Swipe gagal", Color3.fromRGB(255,80,80))
            task.wait(2)
        end
        if not getgenv().CARD_SCAM_RUNNING then break end

        setStatus("Cycle #" .. cycle .. " selesai!", Color3.fromRGB(0,220,100))
        task.wait(2.5)
    end

    setStatus("Stopped", Color3.fromRGB(255,80,80))
end

-- ================================================================
-- UI
-- ================================================================
for _, gui in ipairs(CoreGui:GetChildren()) do
    if gui.Name == "LENGER_CardScam_UI" then
        pcall(function() gui:Destroy() end)
    end
end

local Gui = Instance.new("ScreenGui")
Gui.Name = "LENGER_CardScam_UI"
Gui.ResetOnSpawn = false
Gui.DisplayOrder = 100
pcall(function() Gui.Parent = CoreGui end)
if not Gui.Parent then Gui.Parent = LP:WaitForChild("PlayerGui") end
getgenv().LENGER_CARDSCAM_UI = Gui

local Panel = Instance.new("Frame", Gui)
Panel.Size = UDim2.new(0, 260, 0, 250)
Panel.Position = UDim2.new(0.5, -130, 0.3, 0)
Panel.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
Panel.Active = true
Panel.BorderSizePixel = 0
Instance.new("UICorner", Panel).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", Panel).Color = Color3.fromRGB(40, 40, 40)

-- Draggable
do
    local dragging, dragStart, startPos
    Panel.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = inp.Position
            startPos = Panel.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - dragStart
            Panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                       startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

local Title = Instance.new("TextLabel", Panel)
Title.Size = UDim2.new(1, 0, 0, 32)
Title.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
Title.Text = "▣  CARD SCAM v5"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 12
Title.BorderSizePixel = 0
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 10)

local CloseBtn = Instance.new("TextButton", Panel)
CloseBtn.Size = UDim2.new(0, 22, 0, 22)
CloseBtn.Position = UDim2.new(1, -26, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(38, 10, 10)
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(220, 80, 80)
CloseBtn.Font = Enum.Font.GothamBlack
CloseBtn.TextSize = 16
CloseBtn.AutoButtonColor = false
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 5)
CloseBtn.MouseButton1Click:Connect(function()
    getgenv().CARD_SCAM_RUNNING = false
    pcall(function() Gui:Destroy() end)
end)

local InfoLbl = Instance.new("TextLabel", Panel)
InfoLbl.Size = UDim2.new(1, -16, 0, 28)
InfoLbl.Position = UDim2.new(0, 8, 0, 38)
InfoLbl.BackgroundTransparency = 1
InfoLbl.Text = "Naik kendaraan dulu sebelum START"
InfoLbl.TextColor3 = Color3.fromRGB(90, 90, 90)
InfoLbl.Font = Enum.Font.Gotham
InfoLbl.TextSize = 10
InfoLbl.TextWrapped = true
InfoLbl.TextXAlignment = Enum.TextXAlignment.Left
InfoLbl.TextYAlignment = Enum.TextYAlignment.Top

local ToggleBtn = Instance.new("TextButton", Panel)
ToggleBtn.Size = UDim2.new(1, -16, 0, 42)
ToggleBtn.Position = UDim2.new(0, 8, 0, 72)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(15, 40, 20)
ToggleBtn.Text = "▶  START CARD SCAM"
ToggleBtn.TextColor3 = Color3.fromRGB(0, 220, 100)
ToggleBtn.Font = Enum.Font.GothamBlack
ToggleBtn.TextSize = 13
ToggleBtn.AutoButtonColor = false
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 8)
local toggleStr = Instance.new("UIStroke", ToggleBtn)
toggleStr.Color = Color3.fromRGB(30, 100, 50)

local function refreshToggleBtn()
    local on = getgenv().CARD_SCAM_RUNNING
    if on then
        ToggleBtn.Text = "■  STOP CARD SCAM"
        ToggleBtn.TextColor3 = Color3.fromRGB(220, 80, 80)
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 15, 15)
        toggleStr.Color = Color3.fromRGB(100, 30, 30)
    else
        ToggleBtn.Text = "▶  START CARD SCAM"
        ToggleBtn.TextColor3 = Color3.fromRGB(0, 220, 100)
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(15, 40, 20)
        toggleStr.Color = Color3.fromRGB(30, 100, 50)
    end
end

ToggleBtn.MouseButton1Click:Connect(function()
    getgenv().CARD_SCAM_RUNNING = not getgenv().CARD_SCAM_RUNNING
    refreshToggleBtn()
    if getgenv().CARD_SCAM_RUNNING then
        task.spawn(cardScamLoop)
    end
end)

local CycleLbl = Instance.new("TextLabel", Panel)
CycleLbl.Size = UDim2.new(1, -16, 0, 16)
CycleLbl.Position = UDim2.new(0, 8, 0, 120)
CycleLbl.BackgroundTransparency = 1
CycleLbl.Text = "Cycle: 0"
CycleLbl.TextColor3 = Color3.fromRGB(150, 180, 220)
CycleLbl.Font = Enum.Font.GothamBlack
CycleLbl.TextSize = 11
CycleLbl.TextXAlignment = Enum.TextXAlignment.Left

function updateUI_Cycle(n)
    pcall(function() CycleLbl.Text = "Cycle: " .. n end)
end

local FlowCard = Instance.new("Frame", Panel)
FlowCard.Size = UDim2.new(1, -16, 0, 60)
FlowCard.Position = UDim2.new(0, 8, 0, 140)
FlowCard.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
FlowCard.BorderSizePixel = 0
Instance.new("UICorner", FlowCard).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", FlowCard).Color = Color3.fromRGB(30, 30, 30)

local flowTxt = Instance.new("TextLabel", FlowCard)
flowTxt.Size = UDim2.new(1, -12, 1, -8)
flowTxt.Position = UDim2.new(0, 6, 0, 4)
flowTxt.BackgroundTransparency = 1
flowTxt.Text = "1. Buy Fake ID\n2. Apply Card (Bank Teller)\n3. Wait Approval + 35s\n4. TP coord claim → Claim → Swipe ATM"
flowTxt.TextColor3 = Color3.fromRGB(100, 130, 170)
flowTxt.Font = Enum.Font.Gotham
flowTxt.TextSize = 10
flowTxt.TextXAlignment = Enum.TextXAlignment.Left
flowTxt.TextYAlignment = Enum.TextYAlignment.Top

local StatusLbl = Instance.new("TextLabel", Panel)
StatusLbl.Size = UDim2.new(1, -16, 0, 20)
StatusLbl.Position = UDim2.new(0, 8, 1, -24)
StatusLbl.BackgroundTransparency = 1
StatusLbl.Text = ""
StatusLbl.TextColor3 = Color3.fromRGB(0, 220, 100)
StatusLbl.Font = Enum.Font.GothamBlack
StatusLbl.TextSize = 11
StatusLbl.TextXAlignment = Enum.TextXAlignment.Left

function setStatus(txt, col)
    pcall(function()
        StatusLbl.Text = txt
        StatusLbl.TextColor3 = col or Color3.fromRGB(0, 220, 100)
    end)
end

refreshToggleBtn()

print("[LENGER] Card Scam v5 · Fixed coord claim · Loaded")