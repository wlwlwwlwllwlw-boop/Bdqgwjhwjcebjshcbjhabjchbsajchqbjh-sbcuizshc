-- ================================================================
-- LENGER STORE — CARD SCAM v6 (AUTO CLAIM + TP PRE-WAIT)
-- Flow: Buy Fake ID → Apply → TP ke coord claim → Wait 35s
--       → Auto Claim (search + fallback) → Swipe ATM → Repeat
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
-- KONFIGURASI
-- ================================================================
local MAX_SPEED = 150
local HOP_DIST  = 15
local MIN_DELAY = 0.04
local MAX_DELAY = 0.5
local tpBusy    = false

-- ================================================================
-- VEHICLE TP (FAST)
-- ================================================================
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
local LOC_FakeID        = Vector3.new( 214.960, 1.857, -332.330)
local LOC_ApplyForCard  = Vector3.new( -49.210, 4.000, -310.810)
local CARD_FALLBACK_POS = Vector3.new( -39.090, 5.392, -329.700)

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
        if d:IsA("ProximityPrompt") then return d, nil end
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
-- AUTO CLAIM CARD (object search + fallback)
-- ================================================================
local function findCardPickup()
    local direct = workspace:FindFirstChild("CardPickup")
    if direct then return direct, "workspace.CardPickup" end

    local variants = {"Card Pickup", "Card_Pickup", "CardPickUp", "Cardpickup", "cardpickup"}
    for _, v in ipairs(variants) do
        local found = workspace:FindFirstChild(v)
        if found then return found, "workspace." .. v end
    end

    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("Folder") then
            local n = obj.Name:lower():gsub("[%s_]", "")
            if n == "cardpickup" then
                return obj, obj:GetFullName()
            end
        end
    end
    return nil, nil
end

local function getCardObjectPosition(card)
    if not card then return nil end
    if card:IsA("BasePart") then return card.Position end
    if card:IsA("Model") then
        local rp = card.PrimaryPart or card:FindFirstChildOfClass("BasePart")
        if rp then return rp.Position end
    end
    if card:IsA("Folder") then
        for _, c in pairs(card:GetChildren()) do
            if c:IsA("BasePart") then return c.Position end
        end
    end
    return nil
end

local function findCardPrompt(card)
    if not card then return nil end
    for _, d in ipairs(card:GetDescendants()) do
        if d:IsA("ProximityPrompt") then return d end
    end
    return nil
end

local function findPromptNear(pos, radius)
    radius = radius or 20
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

    setStatus("Step 5 · Cari CardPickup...", Color3.fromRGB(255,200,80))

    -- Tunggu CardPickup spawn (max 15s)
    local card, path
    for i = 1, 30 do
        if not getgenv().CARD_SCAM_RUNNING then return false end
        card, path = findCardPickup()
        if card then
            setStatus("CardPickup ada: " .. tostring(path):sub(-30), Color3.fromRGB(0,220,100))
            break
        end
        task.wait(0.5)
    end

    -- FALLBACK: koordinat hardcode
    if not card then
        setStatus("Gak ketemu, pakai fallback...", Color3.fromRGB(255,200,80))

        local ok, err = doVehicleTP(CARD_FALLBACK_POS)
        if not ok then
            setStatus("TP fallback gagal: " .. tostring(err), Color3.fromRGB(255,80,80))
            return false
        end
        task.wait(1)

        local bestPrompt, bestDist = findPromptNear(CARD_FALLBACK_POS, 20)

        if bestPrompt then
            setStatus("Prompt fallback (dist " .. string.format("%.1f", bestDist) .. ")", Color3.fromRGB(0,220,100))
            pcall(function()
                bestPrompt.HoldDuration = 0
                bestPrompt.RequiresLineOfSight = false
                bestPrompt.MaxActivationDistance = 9e9
            end)
            for i = 1, 20 do
                if not getgenv().CARD_SCAM_RUNNING then return false end
                pcall(function() fireproximityprompt(bestPrompt) end)
                task.wait(0.6)
                if hasItem("Card") then
                    setStatus("Card ✔ (fallback)", Color3.fromRGB(0,220,100))
                    return true
                end
            end
        end

        setStatus("Gagal claim (fallback juga gagal)", Color3.fromRGB(255,80,80))
        return false
    end

    -- Object ketemu
    local cardPos = getCardObjectPosition(card)
    if not cardPos then
        setStatus("CardPickup gak punya BasePart", Color3.fromRGB(255,80,80))
        return false
    end

    local prompt = findCardPrompt(card)
    if not prompt then
        setStatus("CardPickup gak ada Prompt", Color3.fromRGB(255,80,80))
        return false
    end

    pcall(function()
        prompt.HoldDuration = 0
        prompt.RequiresLineOfSight = false
        prompt.MaxActivationDistance = 9e9
    end)

    setStatus("TP ke CardPickup...", Color3.fromRGB(255,200,80))

    for i = 1, 20 do
        if not getgenv().CARD_SCAM_RUNNING then return false end

        local ok, err = doVehicleTP(cardPos)
        if not ok then
            setStatus("TP gagal: " .. tostring(err), Color3.fromRGB(255,80,80))
            task.wait(1)
        else
            task.wait(0.5)
            pcall(function() fireproximityprompt(prompt) end)
            task.wait(0.6)
        end

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

        -- ✅ STEP 4: TP KE COORD CLAIM SAMBIL NUNGGU WAITLIST
        setStatus("Step 4 · TP ke coord claim...", Color3.fromRGB(255,200,80))
        local tpOK, tpErr = doVehicleTP(CARD_FALLBACK_POS)
        if not tpOK then
            setStatus("TP coord gagal: " .. tostring(tpErr), Color3.fromRGB(255,80,80))
            -- tetep lanjut, nanti fallback di claim step
        end
        task.wait(0.5)
        if not getgenv().CARD_SCAM_RUNNING then break end

        -- Wait 35s waitlist (posisi udah di coord claim)
        if approvalResult == true then
            for i = 35, 1, -1 do
                if not getgenv().CARD_SCAM_RUNNING then break end
                setStatus("Step 4 · Waitlist " .. i .. "s (di coord claim)", Color3.fromRGB(0,220,100))
                task.wait(1)
            end
        else
            setStatus("Approval timeout, coba claim...", Color3.fromRGB(255,200,80))
            task.wait(5)
        end
        if not getgenv().CARD_SCAM_RUNNING then break end

        -- STEP 5: Auto Claim Card (search + fallback)
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
Panel.Size = UDim2.new(0, 260, 0, 290)
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
Title.Text = "▣  CARD SCAM v6"
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
flowTxt.Text = "1. Buy Fake ID\n2. Apply Card (Bank Teller)\n3. Wait + TP coord claim\n4. Auto Claim → Swipe ATM"
flowTxt.TextColor3 = Color3.fromRGB(100, 130, 170)
flowTxt.Font = Enum.Font.Gotham
flowTxt.TextSize = 10
flowTxt.TextXAlignment = Enum.TextXAlignment.Left
flowTxt.TextYAlignment = Enum.TextYAlignment.Top

-- Debug panel
local DebugLbl = Instance.new("TextLabel", Panel)
DebugLbl.Size = UDim2.new(1, -16, 0, 34)
DebugLbl.Position = UDim2.new(0, 8, 0, 206)
DebugLbl.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
DebugLbl.Text = "Debug: -"
DebugLbl.TextColor3 = Color3.fromRGB(120, 200, 255)
DebugLbl.Font = Enum.Font.Code
DebugLbl.TextSize = 9
DebugLbl.TextWrapped = true
DebugLbl.TextXAlignment = Enum.TextXAlignment.Left
DebugLbl.TextYAlignment = Enum.TextYAlignment.Top
Instance.new("UICorner", DebugLbl).CornerRadius = UDim.new(0, 4)
Instance.new("UIStroke", DebugLbl).Color = Color3.fromRGB(30, 50, 80)

local StatusLbl = Instance.new("TextLabel", Panel)
StatusLbl.Size = UDim2.new(1, -16, 0, 24)
StatusLbl.Position = UDim2.new(0, 8, 1, -28)
StatusLbl.BackgroundTransparency = 1
StatusLbl.Text = ""
StatusLbl.TextColor3 = Color3.fromRGB(0, 220, 100)
StatusLbl.Font = Enum.Font.GothamBlack
StatusLbl.TextSize = 10
StatusLbl.TextXAlignment = Enum.TextXAlignment.Left
StatusLbl.TextWrapped = true
StatusLbl.TextYAlignment = Enum.TextYAlignment.Top

function setStatus(txt, col)
    pcall(function()
        StatusLbl.Text = txt
        StatusLbl.TextColor3 = col or Color3.fromRGB(0, 220, 100)
    end)
end

refreshToggleBtn()

-- Debug loop
task.spawn(function()
    while Gui.Parent do
        pcall(function()
            local card, path = findCardPickup()
            local hasCard = hasItem("Card")
            local hasFakeID = hasItem("Fake ID")
            DebugLbl.Text = string.format(
                "Card:%s FakeID:%s Pickup:%s\n%s",
                hasCard and "✅" or "❌",
                hasFakeID and "✅" or "❌",
                card and "✅" or "❌",
                card and tostring(path):sub(-40) or "-"
            )
        end)
        task.wait(1)
    end
end)

print("[LENGER] Card Scam v6 loaded · Auto Claim + Pre-Wait TP")