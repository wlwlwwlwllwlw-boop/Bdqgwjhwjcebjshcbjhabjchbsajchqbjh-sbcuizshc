-- ============================================
-- WANZZ PROJECT - POTATO ONLY (UPDATE 4245)
-- REMOTE: ReliableRemoteEvent
-- VEHICLE TP SYSTEM (FAST)
-- ============================================

if getgenv().WANZZ_POTATO_LOADED then return end
getgenv().WANZZ_POTATO_LOADED = true

local LoadStart = os.clock()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- ============================================
-- FIND REMOTE (AUTO DETECT)
-- ============================================

local RemoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
local Remote = nil

if RemoteEvents then
    Remote = RemoteEvents:FindFirstChild("ReliableRemoteEvent")
    if not Remote then
        Remote = RemoteEvents:FindFirstChild("RPC")
    end
    if not Remote then
        Remote = RemoteEvents:FindFirstChild("UnreliableRemoteEvent")
    end
end

if Remote then
    print("✅ Remote Found: " .. Remote.Name)
else
    print("⚠️ Remote Not Found!")
end

-- ============================================
-- KONFIGURASI
-- ============================================

local Configuration = {
    Main_Settings = {
        ["Autofarming"] = false,
        ["Auto Anti Death"] = true,
        ["Auto Rejoiner"] = true,
    },
    Statistics = {
        ["Times Rejoined"] = 0,
        ["Runtime"] = 0,
        ["Cash Made"] = 0,
        ["Chips Fed"] = 0,
        ["Potato Cooked"] = 0,
    },
    State = {
        ["Status"] = "Idle",
        ["RespawnPending"] = false,
    },
}

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

local function GetHumanoid()
    local c = Player.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function EquipTool(tool)
    local h = GetHumanoid()
    if h and tool then 
        pcall(function() h:EquipTool(tool) end)
    end
end

local function UnequipTools()
    local h = GetHumanoid()
    if h then 
        pcall(function() h:UnequipTools() end)
    end
end

local function GetCurrentCashAmount()
    local ok, n = pcall(function()
        local moneyText = PlayerGui:FindFirstChild("Main")
        if moneyText then
            moneyText = moneyText:FindFirstChild("Money")
            if moneyText then
                moneyText = moneyText:FindFirstChild("Amount")
                if moneyText then
                    return tonumber((moneyText.Text:gsub("%D+", ""))) or 0
                end
            end
        end
        return 0
    end)
    return (ok and n) or 0
end

local function GetCommaValue(n)
    local s = tostring(math.floor(n))
    while true do
        local result, count = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        s = result
        if count == 0 then break end
    end
    return s
end

local function FormatRuntime(seconds)
    return string.format("%02d:%02d:%02d",
        math.floor(seconds / 3600),
        math.floor((seconds % 3600) / 60),
        seconds % 60
    )
end

local function WaitForReady()
    repeat task.wait() until Configuration.Main_Settings["Autofarming"]
end

-- ============================================
-- LOCATIONS
-- ============================================

local Locations = {
    SafeZone      = Vector3.new(-478.840, 24.000,  389.200),
    HotChipsMan   = Vector3.new( -41.000,  3.000,  -25.000),
    BuyPotato     = Vector3.new(-759.197, 3.489, -194.846),
    Healing       = Vector3.new(-769.000,  6.000,  654.000),
    Clipboard     = Vector3.new(-477.803, 4.855, -435.559),
    PotatoCutter  = Vector3.new(-456.320,  3.870, -466.840),
    PlasticBagLab = Vector3.new(-456.280,  3.654, -472.670),
    FlourBowl     = Vector3.new(-494.640,  3.579, -518.580),
}

-- ============================================
-- VEHICLE TP SYSTEM (FAST)
-- ============================================

local MAX_SPEED = 150
local HOP_DIST = 15
local MIN_DELAY = 0.04
local MAX_DELAY = 0.5

local tpBusy = false

local function VehicleTeleport(targetPosition)
    if tpBusy then return false end

    local char = Player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    if hum.Health <= 0 then return false end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local seat = hum.SeatPart
    if not seat then 
        Configuration.State["Status"] = "[TP] Not on vehicle!"
        return false 
    end

    local vehicle = seat:FindFirstAncestorOfClass("Model")
    if not vehicle then return false end

    local vRoot = vehicle.PrimaryPart or seat
    if not vRoot then return false end

    tpBusy = true

    local tempWeld
    pcall(function()
        tempWeld = Instance.new("WeldConstraint")
        tempWeld.Name = "TP_TempWeld"
        tempWeld.Part0 = hrp
        tempWeld.Part1 = seat
        tempWeld.Parent = hrp
    end)

    pcall(function()
        vRoot.AssemblyLinearVelocity = Vector3.zero
        vRoot.AssemblyAngularVelocity = Vector3.zero
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)

    task.wait(0.05)

    local startPos = vRoot.Position
    local targetPos = targetPosition + Vector3.new(0, 3, 0)
    local rot = vRoot.CFrame.Rotation

    local totalDist = (targetPos - startPos).Magnitude
    local hopCount = math.max(1, math.ceil(totalDist / HOP_DIST))
    local hopDelay = math.clamp(HOP_DIST / MAX_SPEED, MIN_DELAY, MAX_DELAY)

    for i = 1, hopCount do
        local t = i / hopCount
        local stepPos = startPos:Lerp(targetPos, t)

        pcall(function()
            vehicle:PivotTo(CFrame.new(stepPos) * rot)
        end)

        pcall(function()
            if hrp and hrp.Parent and seat and seat.Parent then
                hrp.CFrame = seat.CFrame * CFrame.new(0, 1.5, 0)
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
            if vRoot and vRoot.Parent then
                vRoot.AssemblyLinearVelocity = Vector3.zero
                vRoot.AssemblyAngularVelocity = Vector3.zero
            end
        end)

        task.wait(hopDelay)
    end

    pcall(function()
        vehicle:PivotTo(CFrame.new(targetPos) * rot)
    end)
    task.wait(0.1)

    pcall(function()
        if hrp and hrp.Parent and seat and seat.Parent then
            hrp.CFrame = seat.CFrame * CFrame.new(0, 1.5, 0)
        end
    end)

    task.wait(0.05)
    pcall(function()
        if tempWeld and tempWeld.Parent then
            tempWeld:Destroy()
        end
    end)

    tpBusy = false
    return true
end

-- ============================================
-- SPAWN & SIT ON BIKE
-- ============================================

local function SpawnAndSitOnBike()
    local BikeName = string.format("%s's Car", Player.Name)
    local ExistingBike = Workspace:FindFirstChild(BikeName)

    if ExistingBike and ExistingBike:FindFirstChild("DriveSeat") and ExistingBike.DriveSeat.Occupant then
        Configuration.State["Status"] = "[BIKE] Already on bike"
        return true
    end

    Configuration.State["Status"] = "[BIKE] Spawning bike..."
    local Bike = Workspace:FindFirstChild(BikeName)

    if not Bike then
        if Remote then
            pcall(function()
                Remote:FireServer(buffer.fromstring("\001"), "Spawn", "DirtBike")
            end)
        end
        local SpawnStart = os.clock()
        repeat task.wait(0.1) until Workspace:FindFirstChild(BikeName) or (os.clock() - SpawnStart) > 4
        Bike = Workspace:FindFirstChild(BikeName)
    end

    if not Bike then
        Configuration.State["Status"] = "[BIKE] Bike not found!"
        return false
    end

    local DriveSeat = Bike:WaitForChild("DriveSeat")

    UnequipTools()
    Configuration.State["RespawnPending"] = true

    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = CFrame.new(67^2, 10^10, 67^2)
    end

    Player.CharacterAdded:Wait()
    local Character = Player.Character
    hrp = Character:WaitForChild("HumanoidRootPart")

    local TargetCFrame = DriveSeat.CFrame * CFrame.new(3, 1, 0)
    task.wait(2)
    for _ = 1, 5 do
        if hrp then hrp.CFrame = TargetCFrame end
        task.wait(0.05)
    end
    task.wait(2.5)

    local Prompt = DriveSeat:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not Prompt then
        local Attachment = DriveSeat:FindFirstChild("Attachment")
        if Attachment then Prompt = Attachment:FindFirstChild("ProximityPrompt") end
    end

    if Prompt then
        pcall(function()
            Prompt.HoldDuration = 0
            Prompt.RequiresLineOfSight = false
            Prompt.MaxActivationDistance = 9e9
        end)
        fireproximityprompt(Prompt)
    end

    task.wait(1)
    Configuration.State["RespawnPending"] = false
    Configuration.State["Status"] = "[BIKE] Sitting on bike!"
    return true
end

-- ============================================
-- POTATO CHIPS FUNCTIONS
-- ============================================

local Labatory = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Locations") and Workspace.Map.Locations:FindFirstChild("The Laboratory")
local AvailablePot, PotPrompt, PotTimer

local function ScavengeInventory()
    UnequipTools()
    local Backpack = Player:FindFirstChild("Backpack")
    if not Backpack then return 0, 0 end

    local Potato, Flour = 0, 0
    for _, Object in next, Backpack:GetChildren() do
        if Object.Name == "Potato" then Potato = Potato + 1 end
        if Object.Name == "Flour" then Flour = Flour + 1 end
    end
    return Potato, Flour
end

local function PurchasePotatoIngredients()
    WaitForReady()
    local Potato, Flour = ScavengeInventory()
    if Potato >= 1 and Flour >= 1 then
        return true
    end
    local StoreRemote = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if StoreRemote then
        StoreRemote = StoreRemote:FindFirstChild("StorePurchase")
    end
    if not StoreRemote then return false end
    
    Configuration.State["Status"] = "[POTATO] Buying ingredients."
    VehicleTeleport(Locations.BuyPotato)
    task.wait(0.5)
    if Flour < 1 then 
        pcall(function() StoreRemote:FireServer("Flour") end)
        task.wait(0.5)
    end
    if Potato < 1 then 
        pcall(function() StoreRemote:FireServer("Potato") end)
        task.wait(0.5)
    end
    return true
end

local function StartPotatoJob()
    WaitForReady()
    if not Labatory then return false end

    local Prompts = Labatory:FindFirstChild("Prompts")
    if not Prompts then return false end

    local Clipboard = Prompts:FindFirstChild("Clipboard")
    if not Clipboard then return false end

    local ClipboardPrompt = Clipboard:FindFirstChild("ProximityPrompt")
    if ClipboardPrompt then
        pcall(function()
            ClipboardPrompt.MaxActivationDistance = 9e9
        end)
    end

    VehicleTeleport(Locations.Clipboard)
    Configuration.State["Status"] = "[POTATO] Claiming task."
    task.wait(0.5)
    local Attempts = 0
    repeat
        WaitForReady()
        VehicleTeleport(Locations.Clipboard)
        task.wait(0.25)
        if ClipboardPrompt then
            fireproximityprompt(ClipboardPrompt)
        end
        task.wait(0.5)
        Attempts = Attempts + 1
        if Attempts > 20 then break end
    until PlayerGui:FindFirstChild("Main") and PlayerGui.Main:FindFirstChild("TaskUpdate") and PlayerGui.Main.TaskUpdate:FindFirstChild("TextLabel") and PlayerGui.Main.TaskUpdate.TextLabel.Text:match("Task:")
    return true
end

local function CutPotato()
    WaitForReady()
    if not Labatory then return false end

    local CuttingBoards = Labatory:FindFirstChild("Cutting Boards")
    if not CuttingBoards then return false end

    local PotatoCutterModel = CuttingBoards:FindFirstChild("Potato Cutter")
    if not PotatoCutterModel then return false end

    local Model = PotatoCutterModel:FindFirstChild("Model")
    if not Model then return false end

    local Union = Model:FindFirstChild("Union")
    if not Union then return false end

    local CutterPrompt = Union:FindFirstChild("Attachment")
    if CutterPrompt then
        CutterPrompt = CutterPrompt:FindFirstChild("ProximityPrompt")
    end

    if CutterPrompt then
        pcall(function()
            CutterPrompt.MaxActivationDistance = 9e9
        end)
    end

    Configuration.State["Status"] = "[POTATO] Cutting potato."
    local Safety = 0
    repeat
        WaitForReady()
        VehicleTeleport(Locations.PotatoCutter)
        local potato = Player:FindFirstChild("Backpack") and Player.Backpack:FindFirstChild("Potato")
        if potato then
            EquipTool(potato)
        end
        task.wait(0.25)
        if CutterPrompt then
            fireproximityprompt(CutterPrompt)
        end
        task.wait(0.5)
        UnequipTools()
        task.wait(0.25)
        Safety = Safety + 1
        if Safety > 25 then break end
    until not (Player:FindFirstChild("Backpack") and Player.Backpack:FindFirstChild("Potato"))
    return true
end

local function BagPotato()
    WaitForReady()
    if not Labatory then return false end

    local Prompts = Labatory:FindFirstChild("Prompts")
    if not Prompts then return false end

    local PlasticBag = Prompts:FindFirstChild("Plastic Bag")
    if not PlasticBag then return false end

    local BagPrompt = PlasticBag:FindFirstChild("Attachment")
    if BagPrompt then
        BagPrompt = BagPrompt:FindFirstChild("ProximityPrompt")
    end

    if BagPrompt then
        pcall(function()
            BagPrompt.MaxActivationDistance = 9e9
        end)
    end

    Configuration.State["Status"] = "[POTATO] Bagging potato."
    if Player:FindFirstChild("Backpack") and Player.Backpack:FindFirstChild("Potato") then
        return true
    end
    local Safety = 0
    repeat
        WaitForReady()
        VehicleTeleport(Locations.PlasticBagLab)
        task.wait(0.25)
        if BagPrompt then
            fireproximityprompt(BagPrompt)
        end
        task.wait(0.5)
        Safety = Safety + 1
        if Safety >= 20 then break end
    until PlayerGui:FindFirstChild("Main") and PlayerGui.Main:FindFirstChild("TaskUpdate") and PlayerGui.Main.TaskUpdate:FindFirstChild("TextLabel") and PlayerGui.Main.TaskUpdate.TextLabel.Text:match("Head")
    return true
end

local function MixFlourAndPotato()
    WaitForReady()
    if not Labatory then return false end

    local Bowls = Labatory:FindFirstChild("Bowls")
    if not Bowls then return false end

    local Bowl = Bowls:FindFirstChildOfClass("UnionOperation")
    if not Bowl then return false end

    local BowlPrompt = Bowl:FindFirstChild("ProximityPrompt")
    if BowlPrompt then
        pcall(function()
            BowlPrompt.MaxActivationDistance = 9e9
        end)
    end

    Configuration.State["Status"] = "[POTATO] Mixing flour and potato."
    local Safety = 0
    repeat
        WaitForReady()
        VehicleTeleport(Locations.FlourBowl)
        task.wait(0.25)
        local flour = Player:FindFirstChild("Backpack") and Player.Backpack:FindFirstChild("Flour")
        if flour then
            EquipTool(flour)
        end
        task.wait(0.25)
        if BowlPrompt then
            fireproximityprompt(BowlPrompt)
        end
        task.wait(0.5)
        UnequipTools()
        Safety = Safety + 1
        if Safety >= 20 then break end
    until not (Player:FindFirstChild("Backpack") and Player.Backpack:FindFirstChild("Flour"))
    task.wait(3.5)
    return true
end

local function CookPotatoChips()
    WaitForReady()
    if not Labatory then return false end

    Configuration.State["Status"] = "[POTATO] Starting cook."
    AvailablePot = nil

    local Pots = Labatory:FindFirstChild("Pots")
    if not Pots then return false end

    for _, Object in next, Pots:GetChildren() do
        if AvailablePot then break end
        if Object:IsA("UnionOperation") then
            local Safety = 0
            repeat
                WaitForReady()
                VehicleTeleport(Object.Position)
                local prompt = Object:FindFirstChild("ProximityPrompt")
                if prompt then
                    fireproximityprompt(prompt)
                end
                task.wait(0.05)
                Safety = Safety + 1
                if Safety > 130 then break end
            until PlayerGui:FindFirstChild("Main") and PlayerGui.Main:FindFirstChild("BasicNotification") and PlayerGui.Main.BasicNotification.TextTransparency == 0

            local Notif = PlayerGui:FindFirstChild("Main")
            if Notif then
                Notif = Notif:FindFirstChild("BasicNotification")
                if Notif then
                    Notif = Notif.Text
                    if Notif == "This pot is in use." then
                        repeat task.wait() until PlayerGui.Main.BasicNotification.TextTransparency == 1
                    elseif Notif == "You have 120 seconds to retrieve your product out of the pot when its done." then
                        AvailablePot = Object
                        local Timer = Object:FindFirstChild("Timer")
                        if Timer then
                            PotTimer = Timer:FindFirstChild("TextLabel")
                        end
                        PotPrompt = Object:FindFirstChild("ProximityPrompt")
                    end
                end
            end
        end
    end
    return AvailablePot ~= nil
end

-- ============================================
-- CLAIM POTATO & FEED HOMELESS
-- ============================================

local function ClaimPotatoChipsAndSell()
    WaitForReady()
    Configuration.State["Status"] = "[POTATO] Waiting for cook..."
    VehicleTeleport(Locations.SafeZone)

    local waitTime = 0
    repeat 
        task.wait(1)
        waitTime = waitTime + 1
        if waitTime > 130 then break end
    until PotTimer and PotTimer.Text == "0"

    Configuration.State["Status"] = "[POTATO] Claiming from pot."
    local claimAttempts = 0
    repeat
        WaitForReady()
        VehicleTeleport(AvailablePot.Position)
        if PotPrompt then
            fireproximityprompt(PotPrompt)
        end
        task.wait(0.5)
        claimAttempts = claimAttempts + 1
        if claimAttempts > 20 then break end
    until Player:FindFirstChild("Backpack") and Player.Backpack:FindFirstChild("Potato Chips")

    Configuration.State["Status"] = "[POTATO] Converting to hot chips."
    local convertAttempts = 0
    repeat 
        WaitForReady() 
        VehicleTeleport(Locations.HotChipsMan) 
        task.wait(0.05)
        convertAttempts = convertAttempts + 1
        if convertAttempts > 20 then break end
    until Workspace:FindFirstChild("Folders") and Workspace.Folders:FindFirstChild("NPCs") and Workspace.Folders.NPCs:FindFirstChild("Poor Guy")

    local PoorGuy = Workspace:FindFirstChild("Folders") and Workspace.Folders:FindFirstChild("NPCs") and Workspace.Folders.NPCs:FindFirstChild("Poor Guy")
    if not PoorGuy then return false end

    local PoorGuyPrompt = PoorGuy:FindFirstChild("UpperTorso")
    if PoorGuyPrompt then
        PoorGuyPrompt = PoorGuyPrompt:FindFirstChild("ProximityPrompt")
    end

    local hotChipsAttempts = 0
    repeat
        WaitForReady()
        VehicleTeleport(Locations.HotChipsMan)
        if PoorGuyPrompt then
            pcall(function()
                PoorGuyPrompt.MaxActivationDistance = 50
                PoorGuyPrompt.HoldDuration = 0
            end)
            fireproximityprompt(PoorGuyPrompt)
        end
        UnequipTools()
        task.wait(0.05)
        hotChipsAttempts = hotChipsAttempts + 1
        if hotChipsAttempts > 20 then break end
    until Player:FindFirstChild("Backpack") and Player.Backpack:FindFirstChild("Hot Chips")

    task.wait(2)

    Configuration.State["Status"] = "[POTATO] Feeding homeless..."

    local HomelessList = Workspace:FindFirstChild("Folders")
    if HomelessList then
        HomelessList = HomelessList:FindFirstChild("HomelessPeople")
    end

    if not HomelessList then
        Configuration.State["Status"] = "[ERROR] HomelessPeople not found!"
        return false
    end

    local AllHomeless = {}
    for _, obj in pairs(HomelessList:GetChildren()) do
        if obj:IsA("Model") then
            table.insert(AllHomeless, obj)
        end
    end

    if #AllHomeless == 0 then
        Configuration.State["Status"] = "[ERROR] No homeless!"
        return false
    end

    for _, homeless in pairs(AllHomeless) do
        local backpack = Player:FindFirstChild("Backpack")
        if not backpack then break end

        local hotChips = backpack:FindFirstChild("Hot Chips")
        if not hotChips then break end

        local torso = homeless:FindFirstChild("UpperTorso")
        if not torso then torso = homeless:FindFirstChild("Torso") end
        if not torso then torso = homeless:FindFirstChild("HumanoidRootPart") end

        if torso then
            local prompt = torso:FindFirstChild("ProximityPrompt")
            if not prompt then
                local att = torso:FindFirstChild("Attachment")
                if att then
                    prompt = att:FindFirstChild("ProximityPrompt")
                end
            end

            if prompt then
                pcall(function()
                    prompt.MaxActivationDistance = 50
                    prompt.HoldDuration = 0
                end)

                VehicleTeleport(torso.Position)
                task.wait(0.5)

                EquipTool(hotChips)
                task.wait(0.3)

                fireproximityprompt(prompt)
                task.wait(0.5)

                UnequipTools()
                task.wait(0.2)

                Configuration.Statistics["Chips Fed"] = Configuration.Statistics["Chips Fed"] + 1

                local checkBackpack = Player:FindFirstChild("Backpack")
                if checkBackpack then
                    local remaining = checkBackpack:FindFirstChild("Hot Chips")
                    if not remaining then break end
                end
            end
        end
        task.wait(0.3)
    end

    Configuration.State["Status"] = "[POTATO] Done! Chips Fed: " .. Configuration.Statistics["Chips Fed"]
    return true
end

-- ============================================
-- MAIN POTATO CONTROLLER
-- ============================================

local AutofarmRunning = false

local function MainPotatoController()
    if AutofarmRunning then return end
    AutofarmRunning = true

    while Configuration.Main_Settings["Autofarming"] do
        WaitForReady()

        if not SpawnAndSitOnBike() then
            task.wait(5)
            continue
        end

        PurchasePotatoIngredients()
        StartPotatoJob()
        CutPotato()
        BagPotato()
        MixFlourAndPotato()
        CookPotatoChips()
        ClaimPotatoChipsAndSell()

        Configuration.Statistics["Potato Cooked"] = Configuration.Statistics["Potato Cooked"] + 1

        AvailablePot = nil
        PotPrompt = nil
        PotTimer = nil
    end

    AutofarmRunning = false
end

-- ============================================
-- REJOIN
-- ============================================

local function DoRejoin()
    if not Configuration.Main_Settings["Auto Rejoiner"] then return end
    Configuration.Main_Settings["Autofarming"] = false
    Configuration.Statistics["Times Rejoined"] = Configuration.Statistics["Times Rejoined"] + 1
    TeleportService:Teleport(10179538382)
end

-- ============================================
-- UI
-- ============================================

local function CreateUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "WANZZ_POTATO"
    sg.ResetOnSpawn = false
    sg.Parent = PlayerGui

    local f = Instance.new("Frame")
    f.Size = UDim2.new(0, 300, 0, 380)
    f.Position = UDim2.new(0.5, -150, 0.5, -190)
    f.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
    f.BorderSizePixel = 0
    f.Parent = sg

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 14)
    c.Parent = f

    local h = Instance.new("Frame")
    h.Size = UDim2.new(1, 0, 0, 40)
    h.BackgroundColor3 = Color3.fromRGB(80, 40, 20)
    h.BorderSizePixel = 0
    h.Parent = f

    local hc = Instance.new("UICorner")
    hc.CornerRadius = UDim.new(0, 14)
    hc.Parent = h

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -60, 1, 0)
    t.Position = UDim2.new(0, 12, 0, 0)
    t.BackgroundTransparency = 1
    t.Text = "🍟 POTATO FARM ONLY"
    t.TextColor3 = Color3.fromRGB(255, 180, 100)
    t.TextSize = 14
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Font = Enum.Font.GothamBold
    t.Parent = h

    local x = Instance.new("TextButton")
    x.Size = UDim2.new(0, 30, 0, 30)
    x.Position = UDim2.new(1, -38, 0, 5)
    x.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
    x.BorderSizePixel = 0
    x.Text = "✕"
    x.TextColor3 = Color3.fromRGB(255, 100, 100)
    x.TextSize = 14
    x.Font = Enum.Font.GothamBold
    x.Parent = h

    local xc = Instance.new("UICorner")
    xc.CornerRadius = UDim.new(0, 8)
    xc.Parent = x

    local s = Instance.new("ScrollingFrame")
    s.Size = UDim2.new(1, 0, 1, -40)
    s.Position = UDim2.new(0, 0, 0, 40)
    s.BackgroundTransparency = 1
    s.BorderSizePixel = 0
    s.ScrollBarThickness = 3
    s.ScrollBarImageColor3 = Color3.fromRGB(150, 100, 70)
    s.CanvasSize = UDim2.new(0, 0, 0, 450)
    s.Parent = f

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = s

    local function Sec(txt)
        local sec = Instance.new("Frame")
        sec.Size = UDim2.new(1, -20, 0, 24)
        sec.BackgroundColor3 = Color3.fromRGB(40, 25, 15)
        sec.BorderSizePixel = 0
        sec.Parent = s
        local sc = Instance.new("UICorner")
        sc.CornerRadius = UDim.new(0, 8)
        sc.Parent = sec
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -10, 1, 0)
        l.Position = UDim2.new(0, 12, 0, 0)
        l.BackgroundTransparency = 1
        l.Text = "◆ " .. txt
        l.TextColor3 = Color3.fromRGB(255, 200, 150)
        l.TextSize = 12
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Font = Enum.Font.GothamSemibold
        l.Parent = sec
    end

    local function Tog(txt, def, cb)
        local fr = Instance.new("Frame")
        fr.Size = UDim2.new(1, -20, 0, 30)
        fr.BackgroundColor3 = Color3.fromRGB(25, 18, 15)
        fr.BorderSizePixel = 0
        fr.Parent = s
        local fc = Instance.new("UICorner")
        fc.CornerRadius = UDim.new(0, 8)
        fc.Parent = fr
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(0.5, -10, 1, 0)
        l.Position = UDim2.new(0, 12, 0, 0)
        l.BackgroundTransparency = 1
        l.Text = txt
        l.TextColor3 = Color3.fromRGB(230, 220, 210)
        l.TextSize = 12
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Font = Enum.Font.Gotham
        l.Parent = fr
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 44, 0, 22)
        b.Position = UDim2.new(1, -52, 0.5, -11)
        b.BackgroundColor3 = def and Color3.fromRGB(255, 140, 60) or Color3.fromRGB(80, 70, 70)
        b.BorderSizePixel = 0
        b.Text = def and "ON" or "OFF"
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.TextSize = 10
        b.Font = Enum.Font.GothamBold
        b.Parent = fr
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 11)
        bc.Parent = b
        local on = def
        b.MouseButton1Click:Connect(function()
            on = not on
            b.BackgroundColor3 = on and Color3.fromRGB(255, 140, 60) or Color3.fromRGB(80, 70, 70)
            b.Text = on and "ON" or "OFF"
            if cb then cb(on) end
        end)
    end

    local function Btn(txt, cb)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -20, 0, 30)
        b.BackgroundColor3 = Color3.fromRGB(60, 40, 25)
        b.BorderSizePixel = 0
        b.Text = txt
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.TextSize = 12
        b.Font = Enum.Font.GothamSemibold
        b.Parent = s
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 8)
        bc.Parent = b
        b.MouseButton1Click:Connect(function()
            pcall(cb)
        end)
    end

    local function Lab(txt, col)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -20, 0, 20)
        l.BackgroundTransparency = 1
        l.Text = txt
        l.TextColor3 = col or Color3.fromRGB(200, 195, 220)
        l.TextSize = 11
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Font = Enum.Font.Gotham
        l.Parent = s
        return l
    end

    Sec("MAIN SETTINGS")
    Tog("▶ Autofarming Potato", false, function(v)
        Configuration.Main_Settings["Autofarming"] = v
        if v then
            task.spawn(function()
                if not SpawnAndSitOnBike() then
                    Configuration.Main_Settings["Autofarming"] = false
                    return
                end
                MainPotatoController()
            end)
        end
    end)
    Tog("🛡️ Anti Death", true, function(v) Configuration.Main_Settings["Auto Anti Death"] = v end)
    Tog("🔄 Auto Rejoiner", true, function(v) Configuration.Main_Settings["Auto Rejoiner"] = v end)

    Sec("STATUS")
    local st = Lab("📌 Status: Idle", Color3.fromRGB(255, 180, 100))
    local rt = Lab("⏰ Runtime: 00:00:00")
    local ca = Lab("💰 Cash: $0")
    local ch = Lab("🍟 Chips Fed: 0")
    local po = Lab("🥔 Potato Cooked: 0")
    local rj = Lab("🔄 Times Rejoined: 0")

    Sec("ACTIONS")
    Btn("🛒 Spawn DirtBike ($35K)", function()
        if Remote then
            pcall(function()
                Remote:FireServer(buffer.fromstring("\001"), "Purchase", "DirtBike")
            end)
        end
    end)
    Btn("🔄 Rejoin Game", DoRejoin)

    x.MouseButton1Click:Connect(function() sg:Destroy() end)

    local drag = false
    local dx, dy = 0, 0
    h.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true
            dx = i.Position.X
            dy = i.Position.Y
        end
    end)
    h.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
            local ex = i.Position.X - dx
            local ey = i.Position.Y - dy
            f.Position = UDim2.new(0.5, -150 + ex, 0.5, -190 + ey)
        end
    end)
    h.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = false
        end
    end)

    task.spawn(function()
        local StartTime = os.clock()
        task.wait(2)
        local StartCash = GetCurrentCashAmount()
        while task.wait(1) do
            local Elapsed = math.floor(os.clock() - StartTime)
            Configuration.Statistics["Runtime"] = Elapsed
            Configuration.Statistics["Cash Made"] = GetCurrentCashAmount() - StartCash

            st.Text = "📌 Status: " .. Configuration.State["Status"]
            rt.Text = "⏰ Runtime: " .. FormatRuntime(Elapsed)
            ca.Text = "💰 Cash: $" .. GetCommaValue(GetCurrentCashAmount())
            ch.Text = "🍟 Chips Fed: " .. Configuration.Statistics["Chips Fed"]
            po.Text = "🥔 Potato Cooked: " .. Configuration.Statistics["Potato Cooked"]
            rj.Text = "🔄 Times Rejoined: " .. Configuration.Statistics["Times Rejoined"]
        end
    end)
end

-- ============================================
-- RUN
-- ============================================

task.wait(1)
CreateUI()

print("========================================")
print("  ✅ POTATO FARM LOADED (UPDATE 4245)")
print("  ✅ Remote: " .. (Remote and Remote.Name or "NOT FOUND"))
print("  ✅ VEHICLE TP SYSTEM (FAST)")
print(string.format("  ✅ Loaded in: %.4f seconds", os.clock() - LoadStart))
print("========================================")