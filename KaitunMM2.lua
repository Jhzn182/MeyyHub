
local function mergeTables(t1, t2)
    if type(t1) ~= 'table' then
        return t2
    end
    
    local result = t2 or {}
    for key, value in pairs(t1) do
        if type(value) == 'table' then
            result[key] = mergeTables(value, result[key])
        elseif result[key] == nil then
            result[key] = value
        end
    end
    return result
end
local Config = mergeTables(defaultConfig, 
    getgenv and getgenv().Config or (_G.Config or {})
)
local Services = {
    CoreGui = game:GetService('CoreGui'),
    TeleportService = game:GetService('TeleportService'),
    Workspace = game:GetService('Workspace'),
    Lighting = game:GetService('Lighting'),
    ReplicatedStorage = game:GetService('ReplicatedStorage'),
    SoundService = game:GetService('SoundService'),
    RunService = game:GetService('RunService'),
    Players = game:GetService('Players'),
    TweenService = game:GetService('TweenService'),
    HttpService = game:GetService('HttpService'),
    StarterGui = game:GetService('StarterGui'),
}

local PlaceId = game.PlaceId
local GameVersion = 'v2.3.1\n'

-- State variables
local state = {
    isUsernameRevealed = false,
    godlyCount = 0,
    chromaCount = 0,
    totalItems = 0,
    hasChroma = false,
    sessionCoins = 0,
    cratesOpened = 0,
    tiersBought = 0,
    currentMap = nil,
    startTime = os.time(),
    isFarming = false,
    coinsEarned = 0,
    harvestCount = 0,
    plantedCount = 0,
    soldCount = 0,
    shovelsUsed = 0,
    seedPacksUsed = 0,
}

-- ==============================================
-- 4. GAME OBJECT REFERENCES
-- ==============================================

local LocalPlayer = Services.Players.LocalPlayer
local Workspace = Services.Workspace
local ReplicatedStorage = Services.ReplicatedStorage

-- Wait for game to load
repeat
    task.wait()
until game:IsLoaded() and LocalPlayer.Character and 
      LocalPlayer.Character:FindFirstChild('HumanoidRootPart') and 
      Workspace:FindFirstChild('Lobby')

-- Get game references
local PlayerCharacter = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = PlayerCharacter:WaitForChild('HumanoidRootPart')
local RoundTimerPart = Workspace:WaitForChild('RoundTimerPart')
local Remotes = ReplicatedStorage:WaitForChild('Remotes')
local Sync = ReplicatedStorage:WaitForChild('Database'):WaitForChild('Sync')
local Modules = ReplicatedStorage:WaitForChild('Modules')
local SharedServices = ReplicatedStorage:WaitForChild('SharedServices')

-- Module references
local LevelModule = require(Modules.LevelModule)
local EventInfoService = require(SharedServices.EventInfoService)
local ProfileData = require(Modules.ProfileData)

-- ==============================================
-- 5. WEAPON RARITY DATA
-- ==============================================

local WeaponRarity = {
    GodlyChroma = {
        "Chroma Boneblade", "Chroma Darkbringer", "Chroma Lightbringer",
        "Chroma Luger", "Chroma Shark", "Chroma Saw", "Chroma Slasher",
        "Chroma Tides", "Chroma Fang", "Chroma Heat", "Chroma Laser",
        "Chroma Nightblade", "Chroma Old Glory", "Chroma Seer",
        "Chroma Traveler's Axe", "Chroma Gemstone", "Chroma Ginger Luger",
        "Chroma Hallows Blade", "Chroma Vampire's Edge",
        "Elderwood Scythe", "Harvester", "Icebreaker", "Ice Piercer",
        "Jack", "Logchopper", "Makeshift", "Luger", "Darkbringer",
        "Lightbringer", "Boneblade", "Saw", "Tides", "Fang", "Heat",
        "Laser", "Nightblade", "Old Glory", "Seer", "Gemstone",
        "Ginger Luger", "Hallows Blade", "Vampire's Edge",
        "Battle Axe", "Battle Axe II"
    },
    AncientLegendary = {
        "Nebula", "Phantom", "Viper", "Shadow", "Frostbite",
        "Frostsaber", "Candy Swirl", "Lollipop", "Sugarcane",
        "Frost's Bite", "Ice Dragon", "Ghost", "Bat", "Spider",
        "Pumpkin", "Web", "Potion", "Cauldron", "Bone",
        "Snowflake", "Gingerbread", "Candy Cane", "Present",
        "Ornament", "Wreath", "Sword", "Axe"
    },
    Rare = {
        "Spider", "Bat", "Ghost", "Pumpkin", "Web", "Potion",
        "Cauldron", "Bone", "Sword", "Axe", "Knife", "Gun",
        "Bunny", "Chick", "Egg", "Heartblade", "Love Gun"
    },
    Uncommon = {
        "Snowflake", "Gingerbread", "Candy Cane", "Present",
        "Ornament", "Wreath", "Valentine's Knife", "Easter's Knife",
        "Halloween's Knife", "Christmas's Knife"
    },
    Common = {
        "Default Knife", "Default Gun", "Knife", "Gun"
    },
    Collectible = {
        "Cupid's Crossbow", "Valentine's Knife", "Heartblade", "Love Gun",
        "Easter's Knife", "Easter Gun", "Chick", "Bunny", "Egg",
        "Halloween's Knife", "Halloween Gun",
        "Christmas's Knife", "Christmas Gun",
        "Summer's Knife", "Summer Gun", "Winter's Edge"
    }
}

local function GetWeaponRarity(weaponName)
    for rarity, list in pairs(WeaponRarity) do
        for _, item in ipairs(list) do
            if string.lower(item) == string.lower(weaponName) then
                return rarity
            end
        end
    end
    return "Unknown"
end

local function GetWeaponColor(rarity)
    local colors = {
        GodlyChroma = Color3.fromRGB(255, 215, 0),     -- Gold
        AncientLegendary = Color3.fromRGB(255, 100, 0), -- Orange
        Rare = Color3.fromRGB(0, 100, 255),            -- Blue
        Uncommon = Color3.fromRGB(0, 255, 0),          -- Green
        Common = Color3.fromRGB(128, 128, 128),        -- Gray
        Collectible = Color3.fromRGB(255, 0, 255),     -- Purple
        Unknown = Color3.fromRGB(255, 255, 255)        -- White
    }
    return colors[rarity] or colors.Unknown
end

-- ==============================================
-- 6. KAITUN UI
-- ==============================================

local function CreateKaitunUI()
    local CoreGui = game:GetService("CoreGui")
    local TweenService = game:GetService("TweenService")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    
    local Theme = {
        Background = Color3.fromRGB(15, 15, 15),
        Darker = Color3.fromRGB(8, 8, 8),
        ContainerBg = Color3.fromHex("#525252"),
        ContainerTrans = 0.6,
        PillBack = Color3.fromRGB(20, 25, 30),
        Text = Color3.fromHex("#FFFFFF"),
        TextDim = Color3.fromHex("#808080"),
        Red = Color3.fromRGB(255, 60, 60),
        Green = Color3.fromRGB(130, 255, 100),
        Active = Color3.fromHex("#888888"),
        TextContrast = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHex("#808080")),
            ColorSequenceKeypoint.new(0.50, Color3.fromHex("#D3D3D3")),
            ColorSequenceKeypoint.new(1, Color3.fromHex("#000000"))
        }),
        TextGrad = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHex("#FFFFFF")), 
            ColorSequenceKeypoint.new(0.5, Color3.fromHex("#8A8A8A")), 
            ColorSequenceKeypoint.new(1, Color3.fromHex("#1A1A1A")) 
        }),
        RowStroke = Color3.fromHex("#FFFFFF"),
        RowStrokeGrad = ColorSequence.new({ 
            ColorSequenceKeypoint.new(0, Color3.fromHex("#FFFFFF")), 
            ColorSequenceKeypoint.new(0.5, Color3.fromHex("#555555")), 
            ColorSequenceKeypoint.new(1, Color3.fromHex("#54626F")) 
        }),
        StrokeGrad = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(0.25, Color3.fromRGB(20, 20, 20)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(0.75, Color3.fromRGB(20, 20, 20)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
        })
    }
    
    local UI_Elements = {}
    local StrokeGradients = {}
    local AnimatedGradients = {}
    local ValueLabels = {}
    
    local KaitunGui = Instance.new("ScreenGui")
    KaitunGui.Name = "HastyMM2"
    KaitunGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    KaitunGui.ResetOnSpawn = false
    
    if gethui then
        KaitunGui.Parent = gethui()
    else
        KaitunGui.Parent = CoreGui
    end
    
    -- Drag function
    local function MakeDraggable(topbar, object)
        local dragging, dragInput, dragStart, startPos
        
        local function update(input)
            local delta = input.Position - dragStart
            local newPos = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
            TweenService:Create(object, TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Position = newPos}):Play()
        end
        
        topbar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = object.Position
                
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
        
        topbar.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)
        
        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                update(input)
            end
        end)
    end
    
    -- Button effects
    local function CreateButtonEffects(button)
        local scale = Instance.new("UIScale")
        scale.Scale = 1
        scale.Parent = button
        
        button.MouseEnter:Connect(function()
            TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Scale = 1.05}):Play()
        end)
        
        button.MouseLeave:Connect(function()
            TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Scale = 1}):Play()
        end)
        
        button.MouseButton1Down:Connect(function()
            TweenService:Create(scale, TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Scale = 0.8}):Play()
        end)
        
        button.MouseButton1Up:Connect(function()
            local t1 = TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {Scale = 1.3})
            t1:Play()
            t1.Completed:Connect(function()
                TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {Scale = 1}):Play()
            end)
        end)
    end
    
    -- Apply text gradient
    local function ApplyTextGradient(obj, isContrast)
        obj.TextColor3 = Theme.Text
        local grad = Instance.new("UIGradient", obj)
        grad.Rotation = 90
        grad.Color = isContrast and Theme.TextContrast or Theme.TextGrad
        
        local shadow = Instance.new("UIStroke")
        shadow.Color = Theme.Darker
        shadow.Thickness = 0.5
        shadow.Transparency = 0
        shadow.Parent = obj
        
        return grad
    end
    
    -- Toggle Container
    local ToggleContainer = Instance.new("Frame")
    ToggleContainer.Name = "ToggleContainer"
    ToggleContainer.Size = UDim2.new(0, 60, 0, 30)
    ToggleContainer.Position = UDim2.new(0, 15, 0, 15)
    ToggleContainer.BackgroundColor3 = Theme.Darker
    ToggleContainer.BackgroundTransparency = 0.4
    ToggleContainer.BorderSizePixel = 0
    ToggleContainer.Parent = KaitunGui
    
    local ToggleCorner = Instance.new("UICorner")
    ToggleCorner.CornerRadius = UDim.new(1, 0)
    ToggleCorner.Parent = ToggleContainer
    
    local ToggleStroke = Instance.new("UIStroke")
    ToggleStroke.Color = Color3.fromRGB(255, 255, 255)
    ToggleStroke.Thickness = 1.5
    ToggleStroke.Parent = ToggleContainer
    
    local ToggleGrad = Instance.new("UIGradient")
    ToggleGrad.Color = Theme.StrokeGrad
    ToggleGrad.Parent = ToggleStroke
    table.insert(StrokeGradients, ToggleGrad)
    
    local ToggleBall = Instance.new("Frame")
    ToggleBall.Size = UDim2.new(0, 22, 0, 22)
    ToggleBall.Position = UDim2.new(0, 34, 0.5, -11)
    ToggleBall.BackgroundColor3 = Theme.Text
    ToggleBall.Parent = ToggleContainer
    Instance.new("UICorner", ToggleBall).CornerRadius = UDim.new(1, 0)
    
    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Size = UDim2.new(1, 0, 1, 0)
    ToggleBtn.BackgroundTransparency = 1
    ToggleBtn.Text = ""
    ToggleBtn.Parent = ToggleContainer
    MakeDraggable(ToggleContainer, ToggleContainer)
    
    -- Main Frame
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 520, 0, 420)
    MainFrame.Position = UDim2.new(0.5, -260, 0.5, -210)
    MainFrame.BackgroundColor3 = Theme.Background
    MainFrame.BackgroundTransparency = 0.4
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = false
    MainFrame.Parent = KaitunGui
    
    local MainGroup = Instance.new("CanvasGroup")
    MainGroup.Size = UDim2.new(1, 0, 1, 0)
    MainGroup.BackgroundTransparency = 1
    MainGroup.Parent = MainFrame
    
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 10)
    MainCorner.Parent = MainFrame
    
    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(255, 255, 255)
    MainStroke.Thickness = 1.5
    MainStroke.Parent = MainFrame
    
    local MainStrokeGrad = Instance.new("UIGradient")
    MainStrokeGrad.Color = Theme.StrokeGrad
    MainStrokeGrad.Parent = MainStroke
    table.insert(StrokeGradients, MainStrokeGrad)
    
    MakeDraggable(MainFrame, MainFrame)
    
    -- Header
    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Size = UDim2.new(1, 0, 0, 35)
    Header.Position = UDim2.new(0, 0, 0, 0)
    Header.BackgroundTransparency = 1
    Header.Parent = MainGroup
    
    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Size = UDim2.new(0, 250, 1, 0)
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "HASTY MM2 | COIN FARMER"
    Title.TextColor3 = Theme.Text
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 11
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Header
    ApplyTextGradient(Title, false)
    
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Name = "CloseBtn"
    CloseBtn.Size = UDim2.new(0, 20, 0, 20)
    CloseBtn.Position = UDim2.new(1, -25, 0.5, -10)
    CloseBtn.BackgroundTransparency = 1
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Theme.TextDim
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 12
    CloseBtn.Parent = Header
    CreateButtonEffects(CloseBtn)
    
    local HDivider = Instance.new("Frame")
    HDivider.Name = "HDivider"
    HDivider.Size = UDim2.new(1, -20, 0, 1)
    HDivider.Position = UDim2.new(0, 10, 0, 35)
    HDivider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    HDivider.BorderSizePixel = 0
    HDivider.Parent = MainGroup
    
    local HDivGrad = Instance.new("UIGradient")
    HDivGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.4),
        NumberSequenceKeypoint.new(1, 1)
    })
    HDivGrad.Parent = HDivider
    
    -- Body
    local Body = Instance.new("Frame")
    Body.Name = "Body"
    Body.Size = UDim2.new(1, 0, 1, -45)
    Body.Position = UDim2.new(0, 0, 0, 45)
    Body.BackgroundTransparency = 1
    Body.Parent = MainGroup
    
    local LeftCol = Instance.new("Frame")
    LeftCol.Name = "LeftCol"
    LeftCol.Size = UDim2.new(0.46, 0, 1, 0)
    LeftCol.Position = UDim2.new(0, 15, 0, 0)
    LeftCol.BackgroundTransparency = 1
    LeftCol.Parent = Body
    
    local RightCol = Instance.new("Frame")
    RightCol.Name = "RightCol"
    RightCol.Size = UDim2.new(0.46, 0, 1, 0)
    RightCol.Position = UDim2.new(0.5, 5, 0, 0)
    RightCol.BackgroundTransparency = 1
    RightCol.Parent = Body
    
    -- UI Building Functions
    local function CreateSectionLabel(parent, text, yPos)
        local Lbl = Instance.new("TextLabel")
        Lbl.Size = UDim2.new(1, 0, 0, 15)
        Lbl.Position = UDim2.new(0, 0, 0, yPos)
        Lbl.BackgroundTransparency = 1
        Lbl.Text = text
        Lbl.TextColor3 = Theme.TextDim
        Lbl.Font = Enum.Font.GothamBold
        Lbl.TextSize = 11
        Lbl.TextXAlignment = Enum.TextXAlignment.Left
        Lbl.Parent = parent
        return Lbl
    end
    
    local function CreateDataContainer(parent, yPos, itemsTable, rarityColors)
        local rowHeight = 22
        local padding = 10
        local containerHeight = (#itemsTable * rowHeight) + padding
        
        local Block = Instance.new("Frame")
        Block.Size = UDim2.new(1, 0, 0, containerHeight)
        Block.Position = UDim2.new(0, 0, 0, yPos)
        Block.BackgroundColor3 = Theme.ContainerBg
        Block.BackgroundTransparency = Theme.ContainerTrans
        Block.Parent = parent
        Instance.new("UICorner", Block).CornerRadius = UDim.new(0, 6)
        
        local Stroke = Instance.new("UIStroke", Block)
        Stroke.Color = Theme.RowStroke
        Stroke.Thickness = 1
        
        local StrokeGrad = Instance.new("UIGradient", Stroke)
        StrokeGrad.Color = Theme.RowStrokeGrad
        table.insert(AnimatedGradients, StrokeGrad)
        
        local returnedLabels = {}
        
        for i, data in ipairs(itemsTable) do
            local keyText = data[1]
            local defaultVal = data[2]
            local rarity = data[3]
            
            local Row = Instance.new("Frame")
            Row.Size = UDim2.new(1, -20, 0, rowHeight)
            Row.Position = UDim2.new(0, 10, 0, 5 + (i-1)*rowHeight)
            Row.BackgroundTransparency = 1
            Row.Parent = Block
            
            local KeyLbl = Instance.new("TextLabel")
            KeyLbl.Size = UDim2.new(0.5, 0, 1, 0)
            KeyLbl.Position = UDim2.new(0, 0, 0, 0)
            KeyLbl.BackgroundTransparency = 1
            KeyLbl.Text = keyText .. ":"
            KeyLbl.TextColor3 = Theme.TextDim
            KeyLbl.Font = Enum.Font.GothamBold
            KeyLbl.TextSize = 11
            KeyLbl.TextXAlignment = Enum.TextXAlignment.Left
            KeyLbl.Parent = Row
            
            local ValLbl = Instance.new("TextLabel")
            ValLbl.Size = UDim2.new(0.5, 0, 1, 0)
            ValLbl.Position = UDim2.new(0.5, 0, 0, 0)
            ValLbl.BackgroundTransparency = 1
            ValLbl.Text = defaultVal
            ValLbl.Font = Enum.Font.GothamBold
            ValLbl.TextSize = 12
            ValLbl.TextXAlignment = Enum.TextXAlignment.Right
            ValLbl.Parent = Row
            
            if rarity and rarityColors then
                ValLbl.TextColor3 = rarityColors[rarity] or Theme.Text
            else
                ApplyTextGradient(ValLbl, false)
            end
            
            ValueLabels[keyText] = ValLbl
            returnedLabels[keyText] = ValLbl
        end
        
        return Block, containerHeight
    end
    
    -- Build Left Column
    local leftY = 0
    CreateSectionLabel(LeftCol, "FARM STATUS", leftY)
    leftY = leftY + 20
    
    local TaskBlock = Instance.new("Frame")
    TaskBlock.Size = UDim2.new(1, 0, 0, 32)
    TaskBlock.Position = UDim2.new(0, 0, 0, leftY)
    TaskBlock.BackgroundColor3 = Theme.PillBack
    TaskBlock.BackgroundTransparency = 0.3
    TaskBlock.BorderSizePixel = 0
    TaskBlock.Parent = LeftCol
    Instance.new("UICorner", TaskBlock).CornerRadius = UDim.new(0, 8)
    leftY = leftY + 40
    
    local StatusDotFrame = Instance.new("Frame")
    StatusDotFrame.Size = UDim2.new(0, 16, 0, 16)
    StatusDotFrame.Position = UDim2.new(0, 10, 0.5, -8)
    StatusDotFrame.BackgroundTransparency = 1
    StatusDotFrame.Parent = TaskBlock
    
    local StatusDot = Instance.new("Frame")
    StatusDot.Size = UDim2.new(0, 6, 0, 6)
    StatusDot.Position = UDim2.new(0.5, -3, 0.5, -3)
    StatusDot.BackgroundColor3 = Theme.Green
    StatusDot.BorderSizePixel = 0
    StatusDot.Parent = StatusDotFrame
    Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)
    
    local StatusAction = Instance.new("TextLabel")
    StatusAction.Size = UDim2.new(1, -35, 1, 0)
    StatusAction.Position = UDim2.new(0, 30, 0, 0)
    StatusAction.BackgroundTransparency = 1
    StatusAction.Text = "Idle"
    StatusAction.TextColor3 = Theme.Text
    StatusAction.Font = Enum.Font.GothamBold
    StatusAction.TextSize = 12
    StatusAction.TextXAlignment = Enum.TextXAlignment.Left
    StatusAction.Parent = TaskBlock
    ValueLabels["CurrentTask"] = StatusAction
    
    local _, h_info = CreateDataContainer(LeftCol, leftY, {
        {"Mode", tostring(Config['Coin Farm Mode'])},
        {"CPU Saver", Config['CPU Saver'] and "ON" or "OFF"},
        {"Auto Open", Config['Auto Open'].Enabled and "ON" or "OFF"}
    })
    leftY = leftY + h_info + 10
    
    CreateSectionLabel(LeftCol, "SESSION STATS", leftY)
    leftY = leftY + 20
    
    local _, h_sess = CreateDataContainer(LeftCol, leftY, {
        {"Uptime", "00:00:00"},
        {"Coins Earned", "$0"},
        {"Rate", "$0/s"},
        {"Crates Opened", "0"},
        {"Tiers Bought", "0"}
    })
    
    -- Build Right Column - Weapon Inventory
    local rightY = 0
    CreateSectionLabel(RightCol, "WEAPON INVENTORY", rightY)
    rightY = rightY + 20
    
    local rarityColors = {
        GodlyChroma = Color3.fromRGB(255, 215, 0),
        AncientLegendary = Color3.fromRGB(255, 100, 0),
        Rare = Color3.fromRGB(0, 100, 255),
        Uncommon = Color3.fromRGB(0, 255, 0),
        Common = Color3.fromRGB(128, 128, 128),
        Collectible = Color3.fromRGB(255, 0, 255),
        Unknown = Color3.fromRGB(255, 255, 255)
    }
    
    local _, h_rarity = CreateDataContainer(RightCol, rightY, {
        {"Godly/Chroma", "0", "GodlyChroma"},
        {"Ancient/Legendary", "0", "AncientLegendary"},
        {"Rare", "0", "Rare"},
        {"Uncommon", "0", "Uncommon"},
        {"Common", "0", "Common"},
        {"Collectible", "0", "Collectible"},
        {"Total Weapons", "0", "Unknown"}
    }, rarityColors)
    rightY = rightY + h_rarity + 10
    
    CreateSectionLabel(RightCol, "PLAYER INFO", rightY)
    rightY = rightY + 20
    
    local _, h_player = CreateDataContainer(RightCol, rightY, {
        {"Level", "0"},
        {"Prestige", "0"},
        {"Coins", "0"},
        {"Role", "Unknown"}
    })
    
    -- Mini Weapon List
    local MiniUIContainer = Instance.new("Frame")
    MiniUIContainer.Name = "MiniWeaponsUI"
    MiniUIContainer.Size = UDim2.new(0, 200, 0, 300)
    MiniUIContainer.Position = UDim2.new(1, -220, 0, 15)
    MiniUIContainer.BackgroundTransparency = 1
    MiniUIContainer.ClipsDescendants = true
    MiniUIContainer.Parent = KaitunGui
    
    local MiniMain = Instance.new("Frame")
    MiniMain.Size = UDim2.new(1, -4, 1, -34)
    MiniMain.Position = UDim2.new(0, 2, 0, 32)
    MiniMain.BackgroundColor3 = Theme.Background
    MiniMain.BackgroundTransparency = 0.4
    MiniMain.BorderSizePixel = 0
    MiniMain.Parent = MiniUIContainer
    Instance.new("UICorner", MiniMain).CornerRadius = UDim.new(0, 8)
    
    local MiniStroke = Instance.new("UIStroke")
    MiniStroke.Color = Color3.fromRGB(255, 255, 255)
    MiniStroke.Thickness = 1.5
    MiniStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    MiniStroke.Parent = MiniMain
    local MiniStrokeGrad = Instance.new("UIGradient")
    MiniStrokeGrad.Color = Theme.StrokeGrad
    MiniStrokeGrad.Parent = MiniStroke
    table.insert(StrokeGradients, MiniStrokeGrad)
    
    local MiniHeader = Instance.new("Frame")
    MiniHeader.Size = UDim2.new(1, 0, 0, 30)
    MiniHeader.Position = UDim2.new(0, 0, 0, 0)
    MiniHeader.BackgroundColor3 = Theme.Darker
    MiniHeader.BackgroundTransparency = 0.2
    MiniHeader.Parent = MiniUIContainer
    Instance.new("UICorner", MiniHeader).CornerRadius = UDim.new(0, 8)
    
    local MiniTitle = Instance.new("TextLabel")
    MiniTitle.Size = UDim2.new(1, -35, 1, 0)
    MiniTitle.Position = UDim2.new(0, 10, 0, 0)
    MiniTitle.BackgroundTransparency = 1
    MiniTitle.Text = "WEAPONS LIST"
    MiniTitle.TextColor3 = Theme.Text
    MiniTitle.Font = Enum.Font.GothamBold
    MiniTitle.TextSize = 10
    MiniTitle.TextXAlignment = Enum.TextXAlignment.Left
    MiniTitle.Parent = MiniHeader
    ApplyTextGradient(MiniTitle, false)
    
    local MiniToggleBtn = Instance.new("TextButton")
    MiniToggleBtn.Size = UDim2.new(0, 20, 0, 20)
    MiniToggleBtn.Position = UDim2.new(1, -25, 0.5, -10)
    MiniToggleBtn.BackgroundTransparency = 1
    MiniToggleBtn.Text = "-"
    MiniToggleBtn.TextColor3 = Theme.TextDim
    MiniToggleBtn.Font = Enum.Font.GothamBold
    MiniToggleBtn.TextSize = 16
    MiniToggleBtn.Parent = MiniHeader
    CreateButtonEffects(MiniToggleBtn)
    
    local WeaponsScroll = Instance.new("ScrollingFrame")
    WeaponsScroll.Size = UDim2.new(1, -10, 1, -10)
    WeaponsScroll.Position = UDim2.new(0, 5, 0, 5)
    WeaponsScroll.BackgroundTransparency = 1
    WeaponsScroll.BorderSizePixel = 0
    WeaponsScroll.ScrollBarThickness = 2
    WeaponsScroll.ScrollBarImageColor3 = Theme.TextDim
    WeaponsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    WeaponsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    WeaponsScroll.Parent = MiniMain
    
    local WeaponListLayout = Instance.new("UIListLayout")
    WeaponListLayout.Parent = WeaponsScroll
    WeaponListLayout.Padding = UDim.new(0, 4)
    WeaponListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    local WeaponRows = {}
    local function AddWeaponRow(weaponName, count)
        local rarity = GetWeaponRarity(weaponName)
        local color = GetWeaponColor(rarity)
        
        local WRow = Instance.new("Frame")
        WRow.Size = UDim2.new(1, -8, 0, 20)
        WRow.BackgroundTransparency = 1
        WRow.Parent = WeaponsScroll
        
        local WName = Instance.new("TextLabel")
        WName.Size = UDim2.new(0.7, 0, 1, 0)
        WName.Position = UDim2.new(0, 5, 0, 0)
        WName.BackgroundTransparency = 1
        WName.Text = weaponName
        WName.TextColor3 = color
        WName.Font = Enum.Font.Gotham
        WName.TextSize = 10
        WName.TextXAlignment = Enum.TextXAlignment.Left
        WName.Parent = WRow
        
        local WVal = Instance.new("TextLabel")
        WVal.Size = UDim2.new(0.3, -5, 1, 0)
        WVal.Position = UDim2.new(0.7, 0, 0, 0)
        WVal.BackgroundTransparency = 1
        WVal.Text = tostring(count)
        WVal.Font = Enum.Font.GothamBold
        WVal.TextSize = 11
        WVal.TextXAlignment = Enum.TextXAlignment.Right
        WVal.Parent = WRow
        ApplyTextGradient(WVal, false)
        
        WeaponRows[weaponName] = {
            Row = WRow,
            CountLabel = WVal
        }
    end
    
    local WeaponInventory = {}
    local function UpdateWeaponInventory(ownedWeapons)
        for _, data in pairs(WeaponRows) do
            data.Row:Destroy()
        end
        WeaponRows = {}
        
        local counts = {
            GodlyChroma = 0,
            AncientLegendary = 0,
            Rare = 0,
            Uncommon = 0,
            Common = 0,
            Collectible = 0,
            Total = 0
        }
        
        local weaponCounts = {}
        for _, weapon in ipairs(ownedWeapons or {}) do
            weaponCounts[weapon] = (weaponCounts[weapon] or 0) + 1
            local rarity = GetWeaponRarity(weapon)
            if counts[rarity] ~= nil then
                counts[rarity] = counts[rarity] + 1
            end
            counts.Total = counts.Total + 1
        end
        
        local sortedWeapons = {}
        for weapon, count in pairs(weaponCounts) do
            table.insert(sortedWeapons, {name = weapon, count = count})
        end
        table.sort(sortedWeapons, function(a, b) return a.name < b.name end)
        
        for _, data in ipairs(sortedWeapons) do
            AddWeaponRow(data.name, data.count)
        end
        
        ValueLabels["Godly/Chroma"] = counts.GodlyChroma
        ValueLabels["Ancient/Legendary"] = counts.AncientLegendary
        ValueLabels["Rare"] = counts.Rare
        ValueLabels["Uncommon"] = counts.Uncommon
        ValueLabels["Common"] = counts.Common
        ValueLabels["Collectible"] = counts.Collectible
        ValueLabels["Total Weapons"] = counts.Total
        
        WeaponInventory = ownedWeapons or {}
    end
    
    -- Toggle UI
    local isMainVisible = true
    local function ToggleMainUI()
        isMainVisible = not isMainVisible
        if isMainVisible then
            MainFrame.Visible = true
            TweenService:Create(ToggleBall, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {Position = UDim2.new(0, 34, 0.5, -11)}):Play()
            TweenService:Create(ToggleContainer, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {BackgroundColor3 = Theme.Darker}):Play()
            TweenService:Create(MainGroup, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                GroupTransparency = 0
            }):Play()
            TweenService:Create(MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = UDim2.new(0.5, -260, 0.5, -210)
            }):Play()
        else
            TweenService:Create(ToggleBall, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {Position = UDim2.new(0, 4, 0.5, -11)}):Play()
            TweenService:Create(ToggleContainer, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {BackgroundColor3 = Theme.Active}):Play()
            local t = TweenService:Create(MainGroup, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                GroupTransparency = 1
            })
            TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, -260, 0.5, -190)
            }):Play()
            t:Play()
            t.Completed:Connect(function()
                if not isMainVisible then MainFrame.Visible = false end
            end)
        end
    end
    
    ToggleBtn.MouseButton1Click:Connect(ToggleMainUI)
    CloseBtn.MouseButton1Click:Connect(function()
        KaitunGui:Destroy()
    end)
    
    -- Mini toggle
    local isMiniOpen = true
    MiniToggleBtn.MouseButton1Click:Connect(function()
        isMiniOpen = not isMiniOpen
        if isMiniOpen then
            MiniToggleBtn.Text = "-"
            TweenService:Create(MiniMain, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 2, 0, 32)}):Play()
        else
            MiniToggleBtn.Text = "+"
            TweenService:Create(MiniMain, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Position = UDim2.new(0, 2, 0, -270)}):Play()
        end
    end)
    MakeDraggable(MiniHeader, MiniUIContainer)
    
    -- Animation loop
    local startTime = tick()
    RunService.RenderStepped:Connect(function(dt)
        local t = tick()
        for _, grad in ipairs(StrokeGradients) do
            grad.Rotation = (t * 100) % 360
        end
        
        local animatedOffset = Vector2.new(math.sin(t * 2) * 0.4, 0)
        for _, grad in ipairs(AnimatedGradients) do
            if grad and grad.Parent then
                grad.Offset = animatedOffset
            end
        end
        
        StatusDot.BackgroundTransparency = math.abs(math.sin(t * 4))
    end)
    
    -- API
    local api = {
        SetValue = function(key, val)
            local label = ValueLabels[key]
            if label then
                local t1 = TweenService:Create(label, TweenInfo.new(0.1), {TextTransparency = 1})
                t1:Play()
                t1.Completed:Wait()
                label.Text = tostring(val)
                TweenService:Create(label, TweenInfo.new(0.15), {TextTransparency = 0}):Play()
            end
        end,
        
        SetTask = function(taskText)
            if ValueLabels["CurrentTask"] then
                ValueLabels["CurrentTask"].Text = tostring(taskText)
            end
        end,
        
        UpdateWeapons = function(ownedWeapons)
            UpdateWeaponInventory(ownedWeapons or {})
        end,
        
        UpdateSession = function(earned, harvested, planted, sold, shovels, seedPacks)
            local uptime = os.time() - state.startTime
            local hours = math.floor(uptime / 3600)
            local minutes = math.floor((uptime % 3600) / 60)
            local seconds = math.floor(uptime % 60)
            
            ValueLabels["Uptime"] = string.format("%02d:%02d:%02d", hours, minutes, seconds)
            ValueLabels["Coins Earned"] = "$" .. tostring(earned or 0)
            ValueLabels["Rate"] = "$" .. string.format("%.1f", (earned or 0) / math.max(uptime, 1)) .. "/s"
            ValueLabels["Crates Opened"] = tostring(state.cratesOpened)
            ValueLabels["Tiers Bought"] = tostring(state.tiersBought)
        end,
        
        UpdatePlayerInfo = function(level, prestige, coins, role)
            ValueLabels["Level"] = tostring(level or 0)
            ValueLabels["Prestige"] = tostring(prestige or 0)
            ValueLabels["Coins"] = tostring(coins or 0)
            ValueLabels["Role"] = tostring(role or "Unknown")
        end,
        
        GetInventory = function()
            return WeaponInventory
        end
    }
    
    return api
end

-- ==============================================
-- 7. INITIALIZE UI
-- ==============================================

local UI = CreateKaitunUI()
UI:SetTask("Loading...")

-- ==============================================
-- 8. CRATE DATA
-- ==============================================

local godlyItems = {}
local chromaItems = {}

for _, crateData in pairs(require(Sync.MysteryBox)) do
    if crateData.Godly then
        if type(crateData.Godly) == 'string' then
            table.insert(godlyItems, crateData.Godly)
        end
    elseif crateData.GodlyTable then
        for _, item in pairs(crateData.GodlyTable) do
            table.insert(godlyItems, item)
        end
    end
    
    if crateData.ChromaTable then
        for _, item in pairs(crateData.ChromaTable) do
            table.insert(chromaItems, item)
        end
    end
end

-- ==============================================
-- 9. WEBHOOK FUNCTIONS
-- ==============================================

local headers = {
    ['Content-Type'] = 'application/json',
}

local function sendWebhook(url, data)
    local payload = {
        embeds = {{
            title = data.title,
            description = data.description,
            color = data.color,
            fields = data.fields,
            timestamp = data.timestamp,
            footer = { text = data.footer.text }
        }}
    }
    
    request({
        Url = url,
        Method = 'POST',
        Headers = headers,
        Body = Services.HttpService:JSONEncode(payload)
    })
end

local function sendWebhookWithMention(url, userID, data)
    local payload = {
        content = '<@' .. userID .. '>',
        embeds = {{
            title = data.title,
            description = data.description,
            color = data.color,
            fields = data.fields,
            timestamp = data.timestamp,
            footer = { text = data.footer.text }
        }}
    }
    
    request({
        Url = url,
        Method = 'POST',
        Headers = headers,
        Body = Services.HttpService:JSONEncode(payload)
    })
end

-- ==============================================
-- 10. CPU SAVER OPTIMIZATION
-- ==============================================

local function optimizePerformance()
    if not Config['CPU Saver'] then return end
    
    local startTime = tick()
    
    Workspace.Terrain.WaterReflectance = 0
    Workspace.Terrain.WaterTransparency = 1
    Workspace.Terrain.WaterWaveSize = 0
    Workspace.Terrain.WaterWaveSpeed = 0
    
    Services.Lighting.Brightness = 0
    Services.Lighting.GlobalShadows = false
    Services.Lighting.FogStart = 0
    Services.Lighting.FogEnd = math.huge
    Services.Lighting.ClockTime = 12
    Services.Lighting.Ambient = Color3.new(1, 1, 1)
    Services.Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    Services.Lighting.ExposureCompensation = 0
    Services.Lighting.ShadowSoftness = 0
    
    if sethiddenproperty then
        sethiddenproperty(Services.Lighting, 'Technology', Enum.Technology.Compatibility)
        sethiddenproperty(Workspace.Terrain, 'Decoration', false)
        sethiddenproperty(Workspace, 'StreamingEnabled', true)
        sethiddenproperty(Workspace, 'StreamingPauseMode', Enum.StreamingPauseMode.ClientPhysicsPause)
        sethiddenproperty(Services.Players, 'CharacterAutoLoads', false)
    end
    
    Services.SoundService.RespectFilteringEnabled = true
    Services.SoundService:SetListener(Enum.ListenerType.Camera)
    Services.SoundService.AmbientReverb = Enum.ReverbType.NoReverb
    
    game:SetAttribute('DataModelMeshStreaming', false)
    ReplicatedStorage:SetAttribute('ReplicateInstanceDestroy', false)
    Services.RunService:Set3dRenderingEnabled(false)
    settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    
    LocalPlayer.PlayerGui:Destroy()
    LocalPlayer.PlayerScripts:Destroy()
    
    pcall(function()
        Services.RunService:UnbindFromRenderStep('Humanoid')
        Services.RunService:UnbindFromRenderStep('Animation')
    end)
    
    local ignoreGui = {
        game:GetService('CorePackages'),
        game:GetService('Stats'),
        Services.Lighting,
        Services.CoreGui,
    }
    
    for _, gui in ipairs(ignoreGui) do
        for _, child in ipairs(gui:GetChildren()) do
            if child ~= KaitunGui then
                pcall(child.Destroy, child)
            end
        end
    end
    
    local function cleanupObject(obj)
        task.wait(0.5)
        
        if obj.Name == 'ThrowingKnife' or obj.Name == 'Firefly' or obj.Name == 'Footsteps' then
            obj:Destroy()
            return
        end
        
        if obj:FindFirstChild('HumanoidRootPart') then
            PlayerCharacter = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        end
        
        if obj:IsA('Model') and obj:FindFirstChild('HumanoidRootPart') and 
           obj.Name ~= LocalPlayer.Name and obj ~= PlayerCharacter then
            if Config['Coin Farm Mode'] == 1 or Config.Misc.FARM_MURDERER_SHERIF_WINS then
                for _, part in ipairs(obj:GetChildren()) do
                    if part:IsA('Part') and part.Name ~= 'HumanoidRootPart' then
                        part:Destroy()
                    end
                end
            else
                obj:Destroy()
            end
        end
    end
    
    for _, obj in ipairs(Workspace:GetChildren()) do
        cleanupObject(obj)
    end
    
    Workspace.ChildAdded:Connect(cleanupObject)
    
    for _, player in ipairs(Services.Players:GetPlayers()) do
        if player ~= LocalPlayer then
            player:Destroy()
        end
    end
    
    Services.Players.ChildAdded:Connect(function(player)
        if player ~= LocalPlayer then
            player:Destroy()
        end
    end)
    
    print('CPU Saver optimization completed. Took ' .. tick() - startTime .. ' seconds.')
end

-- ==============================================
-- 11. GAME OBJECT REFERENCES (Cont.)
-- ==============================================

-- Clean up unnecessary objects
Workspace:WaitForChild('Lobby'):Destroy()
Workspace:WaitForChild('WeaponDisplays'):Destroy()
Workspace:WaitForChild('PetContainer'):Destroy()
Workspace:WaitForChild('EffectLoader'):Destroy()
Workspace:WaitForChild('ServerStatus'):Destroy()
Workspace:WaitForChild('GameSettings'):Destroy()

-- Create safety parts
local safetyPart = Instance.new('Part')
safetyPart.Parent = Workspace
safetyPart.Size = Vector3.new(10, 1, 10)
safetyPart.Position = Vector3.new(0, 0, 0)
safetyPart.Anchored = true
safetyPart.Name = 'SafetyPart'
safetyPart.Transparency = 1

local lobbyPlatform = Instance.new('Part')
lobbyPlatform.Parent = Workspace
lobbyPlatform.Size = Vector3.new(100, 1, 100)
lobbyPlatform.Position = Vector3.new(-100, 136, 30)
lobbyPlatform.Anchored = true
lobbyPlatform.Name = 'LobbyPlatform'
lobbyPlatform.Transparency = 1

HumanoidRootPart.CFrame = safetyPart.CFrame + Vector3.new(0, 3, 0)

-- ==============================================
-- 12. UPDATE FUNCTIONS
-- ==============================================

local function updateTimeFarming()
    local elapsed = os.time() - state.startTime
    UI:SetValue("Uptime", string.format("%02d:%02d:%02d",
        math.floor(elapsed / 3600),
        math.floor(elapsed % 3600 / 60),
        elapsed % 60
    ))
end

local function isEventActive()
    return true
end

local function getCurrentCoins()
    return isEventActive() and 
           (ProfileData.Materials.Owned[EventInfoService.GetEventCurrency()] or 0) or 
           (ProfileData.Coins or 0)
end

local function updateStats()
    ProfileData = require(Modules.ProfileData)
    local playerData = Remotes.Gameplay.GetCurrentPlayerData:InvokeServer()
    
    -- Update level
    local level, xpNeeded = LevelModule.GetLevel(ProfileData.NewXP)
    UI:SetValue("Level", level .. " (" .. ProfileData.NewXP .. "/" .. xpNeeded .. ")")
    UI:SetValue("Prestige", LocalPlayer:GetAttribute('Prestige') or 0)
    
    -- Update coins
    local coins = getCurrentCoins()
    UI:SetValue("Coins", coins)
    
    -- Update weapon counts
    state.godlyCount = 0
    state.chromaCount = 0
    state.totalItems = 0
    
    local ownedWeapons = ProfileData.Weapons.Owned or {}
    local weaponList = {}
    for weapon, count in pairs(ownedWeapons) do
        weaponList[weapon] = count
        if table.find(godlyItems, weapon) then
            state.godlyCount = state.godlyCount + count
        elseif table.find(chromaItems, weapon) then
            state.chromaCount = state.chromaCount + count
        end
        state.totalItems = state.totalItems + count
    end
    
    -- Update weapon inventory in UI
    local weaponNames = {}
    for weapon, count in pairs(ownedWeapons) do
        for i = 1, count do
            table.insert(weaponNames, weapon)
        end
    end
    UI:UpdateWeapons(weaponNames)
    
    -- Update role
    if playerData and playerData[LocalPlayer.Name] then
        UI:SetValue("Role", playerData[LocalPlayer.Name].Role or 'Unknown')
    end
    
    -- Update session stats
    UI:UpdateSession(
        state.coinsEarned,
        state.harvestCount,
        state.plantedCount,
        state.soldCount,
        state.shovelsUsed,
        state.seedPacksUsed
    )
    
    -- Auto open crates
    if Config['Auto Open'].Enabled and isEventActive() and 
       (ProfileData.Materials.Owned[EventInfoService.GetEventCurrency()] or 0) >= 800 then
        
        local currency = EventInfoService:GetCurrentEvent() and 'BeachBalls2025' or 'Coins'
        local result = Remotes.Shop.OpenCrate:InvokeServer(
            Config['Auto Open'].Crate, 
            'MysteryBox', 
            currency
        )
        
        state.cratesOpened = state.cratesOpened + 1
        UI:SetValue("Crates Opened", state.cratesOpened)
        
        if result and Config.Webhook.URL:find('https://discord.com/api/webhooks') then
            local embed = {
                title = '',
                description = '',
                color = 65280,
                fields = {
                    { name = 'Item', value = tostring(result), inline = false },
                    { name = 'Username', value = LocalPlayer.Name, inline = false },
                    { name = 'Total Godlies', value = tostring(state.godlyCount), inline = true },
                    { name = 'Total Chromas', value = tostring(state.chromaCount), inline = true },
                },
                footer = { text = 'Hasty MM2 Coin Farmer' },
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            }
            
            if table.find(godlyItems, result) then
                embed.color = 16776960
                embed.title = 'Crate Opened with a Godly Item'
                embed.description = 'Congratulations! You received a rare Godly Item.'
                sendWebhookWithMention(Config.Webhook.URL, Config.Webhook.UserID, embed)
            elseif table.find(chromaItems, result) then
                embed.color = 16711935
                embed.title = 'Crate Opened with a Chroma Item'
                embed.description = 'Nice! You received an exclusive Chroma Item.'
                sendWebhookWithMention(Config.Webhook.URL, Config.Webhook.UserID, embed)
            elseif not Config.Webhook['Only Good Webhook'] then
                embed.title = 'Crate Opened with an Ordinary Item'
                embed.description = 'You received a normal item.'
                sendWebhook(Config.Webhook.URL, embed)
            end
        end
    end
    
    -- Auto prestige
    if Config.Other['Auto Prestige'] and level == 100 and LocalPlayer:GetAttribute('Prestige') < 10 then
        Remotes.Inventory.Prestige:FireServer()
        UI:SetValue("Prestige", LocalPlayer:GetAttribute('Prestige') or 0)
    end
    
    -- Auto battle pass
    if isEventActive() and Config.Event['Auto Do Battle Pass'] then
        local battlePass = EventInfoService:GetBattlePass()
        local eventData = ProfileData[EventInfoService:GetCurrentEvent().Title]
        
        if eventData then
            for tier, reward in pairs(battlePass.Rewards) do
                if tonumber(tier) <= eventData.CurrentTier and 
                   not eventData.ClaimedRewards[tier] and 
                   reward.ItemID ~= '' then
                    
                    task.wait(1)
                    EventInfoService:GetEventRemotes().ClaimBattlePassReward:FireServer(tonumber(tier))
                    
                    if tier == 25 and Config.Webhook.URL:find('https://discord.com/api/webhooks') then
                        local embed = {
                            title = 'Claimed Battle Pass Tier 25',
                            description = '',
                            color = 65280,
                            fields = {
                                { name = 'Item', value = 'Sunset', inline = false },
                                { name = 'Username', value = LocalPlayer.Name, inline = false },
                                { name = 'Total Godlies', value = tostring(state.godlyCount), inline = true },
                                { name = 'Total Chromas', value = tostring(state.chromaCount), inline = true },
                            },
                            footer = { text = 'Hasty MM2 Coin Farmer' },
                            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
                        }
                        sendWebhookWithMention(Config.Webhook.URL, Config.Webhook.UserID, embed)
                    end
                end
            end
            
            if tonumber(getCurrentCoins()) >= 800 then
                local tiersToBuy = math.floor(getCurrentCoins() / 800)
                Remotes.Events.Generic.BuyTiers:FireServer(tiersToBuy)
                state.tiersBought = state.tiersBought + tiersToBuy
                UI:SetValue("Tiers Bought", state.tiersBought)
            end
        end
    end
end

-- ==============================================
-- 13. FARMING FUNCTIONS
-- ==============================================

local function getHumanoidRootPart()
    local attempts = 0
    while attempts < 60 do
        PlayerCharacter = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local rootPart = PlayerCharacter:FindFirstChild('HumanoidRootPart')
        if rootPart then
            return rootPart
        end
        attempts = attempts + 1
        task.wait(1)
    end
    return nil
end

local function clearMapForCPU()
    if not state.currentMap then return end
    
    for _, child in ipairs(state.currentMap:GetChildren()) do
        if child:IsA('Model') and child.Name ~= 'CoinContainer' then
            child:Destroy()
        end
    end
end

local function makeMapInvisible()
    if not state.currentMap then return end
    
    for _, descendant in ipairs(state.currentMap:GetDescendants()) do
        if descendant and descendant:IsA('Part') then
            descendant.CanCollide = false
            descendant.Transparency = 0.5
        end
    end
end

local function isCoinSafe(coinPart)
    for _, player in ipairs(Services.Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local rootPart = getHumanoidRootPart()
            if rootPart and (rootPart.Position - coinPart.Position).Magnitude < 10 then
                return false
            end
        end
    end
    return true
end

local function collectCoins()
    local playerData = Remotes.Gameplay.GetCurrentPlayerData:InvokeServer()
    local coinsCollected = {}
    
    local rootPart = getHumanoidRootPart()
    if not rootPart then return nil end
    
    local coinContainer = state.currentMap:WaitForChild('CoinContainer')
    for _, coin in ipairs(coinContainer:GetChildren()) do
        if coin and coin.Parent and coin:IsA('Part') and coin.Name == 'Coin_Server' then
            if coin:GetAttribute('CoinID') ~= 'Egg' then
                if coin:FindFirstChild('CoinVisual') and Config['CPU Saver'] then
                    coin.CoinVisual:Destroy()
                end
                
                if (rootPart.Position - coin.Position).Magnitude <= 10 then
                    coin.Size = Vector3.new(0.5, 0.5, 0.5)
                    task.wait()
                    coin.Size = Vector3.new(10, 10, 10)
                    table.insert(coinsCollected, coin)
                end
            else
                coin:Destroy()
            end
        end
    end
    
    return coinsCollected
end

local function findNearestCoin()
    local playerData = Remotes.Gameplay.GetCurrentPlayerData:InvokeServer()
    
    if playerData and playerData[LocalPlayer.Name] and playerData[LocalPlayer.Name].Dead then
        return 'Dead'
    end
    
    if playerData and playerData[LocalPlayer.Name] and playerData[LocalPlayer.Name].Coins == 30 then
        return 'Full'
    end
    
    if Config['Coin Farm Mode'] == 1 then
        if not state.currentMap then return nil end
        
        local coinContainer = state.currentMap:WaitForChild('CoinContainer')
        local coins = {}
        
        for _, coin in ipairs(coinContainer:GetChildren()) do
            if coin and coin.Parent and coin:IsA('Part') and coin.Name == 'Coin_Server' then
                if coin:FindFirstChild('CoinVisual') and Config['CPU Saver'] then
                    coin.CoinVisual:Destroy()
                end
                coin.Size = Vector3.new(2, 2, 2)
                table.insert(coins, coin)
            end
        end
        
        table.sort(coins, function(a, b)
            local safeA = isCoinSafe(a)
            local safeB = isCoinSafe(b)
            if safeA == safeB then return false end
            return safeA and not safeB
        end)
        
        return coins[math.random(#coins)]
    end
    
    if Config['Coin Farm Mode'] == 2 then
        local rootPart = getHumanoidRootPart()
        if not rootPart or not state.currentMap then return nil end
        
        local coinContainer = state.currentMap:WaitForChild('CoinContainer')
        local nearestCoin = nil
        local nearestDistance = math.huge
        
        for _, coin in ipairs(coinContainer:GetChildren()) do
            if coin and coin.Parent and coin:IsA('Part') and coin.Name == 'Coin_Server' and 
               not coin:GetAttribute('Collected') then
                if coin:FindFirstChild('CoinVisual') and Config['CPU Saver'] then
                    coin.CoinVisual:Destroy()
                end
                
                local distance = (rootPart.Position - coin.Position).Magnitude
                if distance < nearestDistance then
                    nearestCoin = coin
                    nearestDistance = distance
                end
            end
        end
        
        return nearestCoin
    end
    
    return nil
end

local function farmMurdererSheriff()
    local playerData = Remotes.Gameplay.GetCurrentPlayerData:InvokeServer()
    
    if playerData and playerData[LocalPlayer.Name] then
        local role = playerData[LocalPlayer.Name].Role
        
        if role == 'Murderer' then
            for _, obj in ipairs(Workspace:GetChildren()) do
                if obj:IsA('Model') and obj:FindFirstChild('HumanoidRootPart') and 
                   obj.Name ~= LocalPlayer.Name and obj ~= PlayerCharacter then
                    local pos = obj.HumanoidRootPart.Position
                    LocalPlayer.Backpack:WaitForChild('Knife'):WaitForChild('Throw'):FireServer(
                        CFrame.new(pos),
                        pos + Vector3.new(0, 3, 0)
                    )
                end
            end
        elseif role == 'Sheriff' then
            for _, obj in ipairs(Workspace:GetChildren()) do
                if obj:IsA('Model') and obj:FindFirstChild('HumanoidRootPart') and 
                   obj.Name ~= LocalPlayer.Name and obj ~= PlayerCharacter and 
                   playerData[obj.Name].Role == 'Murderer' then
                    local pos = obj.HumanoidRootPart.Position
                    LocalPlayer.Backpack:WaitForChild('Knife'):WaitForChild('Throw'):FireServer(
                        CFrame.new(pos),
                        pos + Vector3.new(0, 3, 0)
                    )
                end
            end
        end
    end
end

-- ==============================================
-- 14. AUTO RESTART
-- ==============================================

task.spawn(function()
    if Config.Other['Auto Restart on Update'] then
        local latestVersion = game:HttpGet('https://raw.githubusercontent.com/Paule1248/mm2/refs/heads/main/version')
        
        while task.wait(600) do
            latestVersion = game:HttpGet('https://raw.githubusercontent.com/Paule1248/mm2/refs/heads/main/version')
            
            if latestVersion ~= GameVersion then
                local serversUrl = 'https://games.roblox.com/v1/games/' .. PlaceId .. '/servers/Public?sortOrder=Asc&limit=100'
                
                local success = pcall(function()
                    local function getServers(cursor)
                        return Services.HttpService:JSONDecode(
                            game:HttpGet(serversUrl .. (cursor and '&cursor=' .. cursor or ''))
                        )
                    end
                    
                    local cursor = nil
                    repeat
                        local response = getServers(cursor)
                        local server = response.data[1]
                        cursor = response.nextPageCursor
                        task.wait(1)
                    until server
                    
                    Services.TeleportService:TeleportToPlaceInstance(PlaceId, server.id, LocalPlayer)
                end)
                
                if not success then
                    Services.TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Services.Players.LocalPlayer)
                end
            end
        end
    end
end)

-- ==============================================
-- 15. MAIN FARMING LOOP
-- ==============================================

-- Start CPU saver if enabled
task.spawn(function()
    if Config['CPU Saver'] then
        while task.wait(5) do
            setfpscap(5)
        end
    end
end)

-- Start update loop
task.spawn(function()
    while true do
        updateTimeFarming()
        updateStats()
        task.wait(1)
    end
end)

-- Start performance optimization
task.spawn(optimizePerformance)

-- Map detection
Workspace.ChildAdded:Connect(function(map)
    if map:GetAttribute('MapID') then
        repeat
            task.wait()
        until map:FindFirstChild('CoinContainer')
        
        if map:FindFirstChild('CoinContainer') then
            print('Map found: ' .. map.Name)
            state.currentMap = map
            
            local coinContainer = map:FindFirstChild('CoinContainer')
            while state.currentMap and coinContainer and coinContainer.Parent == map do
                task.wait()
            end
            
            state.currentMap = nil
        end
    end
end)

-- Main farming loop
task.spawn(function()
    local playerData
    
    while true do
        if RoundTimerPart:GetAttribute('Time') ~= -1 and 
           not (playerData and playerData[LocalPlayer.Name] and playerData[LocalPlayer.Name].Dead) and
           (not playerData or playerData[LocalPlayer.Name]) then
            
            if Config['CPU Saver'] then
                clearMapForCPU()
            else
                makeMapInvisible()
            end
            
            local coinTarget = findNearestCoin()
            
            if type(coinTarget) ~= 'string' then
                if RoundTimerPart:GetAttribute('Time') ~= -1 then
                    if coinTarget and coinTarget.Position then
                        local targetPos = coinTarget.Position
                        UI:SetTask("Farming coins...")
                        
                        if Config['Coin Farm Mode'] == 1 then
                            safetyPart.Position = targetPos - Vector3.new(0, 10, 0)
                            HumanoidRootPart.CFrame = safetyPart.CFrame + Vector3.new(0, 3, 0)
                            
                            task.wait()
                            collectCoins()
                            task.wait(0.5)
                            state.coinsEarned = state.coinsEarned + 1
                            state.harvestCount = state.harvestCount + 1
                            
                            safetyPart.Position = Vector3.new(0, 100, 0)
                            HumanoidRootPart.CFrame = safetyPart.CFrame + Vector3.new(0, 3, 0)
                            task.wait(2.3)
                            
                        elseif Config['Coin Farm Mode'] == 2 then
                            local distance = (targetPos - HumanoidRootPart.Position - Vector3.new(0, 5, 0)).Magnitude
                            local estimatedTime = math.floor(distance / 20 * 10 + 0.5) / 10
                            
                            local tweenInfo = TweenInfo.new(
                                estimatedTime,
                                Enum.EasingStyle.Linear,
                                Enum.EasingDirection.InOut
                            )
                            
                            local rootTween = Services.TweenService:Create(
                                HumanoidRootPart,
                                tweenInfo,
                                { CFrame = CFrame.new(targetPos - Vector3.new(0, 7, 0)) }
                            )
                            
                            local partTween = Services.TweenService:Create(
                                safetyPart,
                                tweenInfo,
                                { CFrame = CFrame.new(targetPos - Vector3.new(0, 10, 0)) }
                            )
                            
                            if distance >= 100 then
                                safetyPart.Position = targetPos - Vector3.new(0, 10, 0)
                                HumanoidRootPart.CFrame = CFrame.new(targetPos)
                            else
                                rootTween:Play()
                                partTween:Play()
                                rootTween.Completed:Wait()
                            end
                            
                            collectCoins()
                            state.coinsEarned = state.coinsEarned + 1
                            state.harvestCount = state.harvestCount + 1
                            UI:SetTask("Coin collected!")
                        end
                        
                    else
                        UI:SetTask("Searching for coins...")
                        task.wait()
                    end
                end
            elseif coinTarget == 'Dead' then
                UI:SetTask("You are dead! Respawning...")
                
                repeat
                    task.wait(1)
                    playerData = Remotes.Gameplay.GetCurrentPlayerData:InvokeServer()
                    HumanoidRootPart = getHumanoidRootPart()
                until HumanoidRootPart
                
                UI:SetTask("Respawned!")
                safetyPart.Position = Vector3.new(0, 100, 0)
                
                for _ = 1, 3 do
                    HumanoidRootPart.CFrame = safetyPart.CFrame + Vector3.new(0, 3, 0)
                    task.wait(0.1)
                end
                
            elseif coinTarget == 'Full' and Config.Misc.FARM_MURDERER_SHERIF_WINS and 
                   (playerData[LocalPlayer.Name].Role == 'Murderer' or playerData[LocalPlayer.Name].Role == 'Sheriff') then
                UI:SetTask("Farming as " .. playerData[LocalPlayer.Name].Role)
                farmMurdererSheriff()
                
            elseif coinTarget == 'Full' then
                UI:SetTask("Coin inventory full! Teleporting...")
                safetyPart.Position = Vector3.new(0, 100, 0)
                
                for _ = 1, 3 do
                    HumanoidRootPart.CFrame = safetyPart.CFrame + Vector3.new(0, 3, 0)
                    task.wait()
                end
            else
                task.wait()
            end
        else
            -- Wait for new round
            UI:SetTask("Waiting for new round...")
            task.wait(0.5)
            
            HumanoidRootPart = getHumanoidRootPart()
            safetyPart.Position = Vector3.new(0, 100, 0)
            
            while true do
                playerData = Remotes.Gameplay.GetCurrentPlayerData:InvokeServer()
                HumanoidRootPart = getHumanoidRootPart()
                
                if HumanoidRootPart then
                    HumanoidRootPart.CFrame = safetyPart.CFrame + Vector3.new(0, 3, 0)
                end
                
                task.wait(1)
                
                if RoundTimerPart:GetAttribute('Time') ~= -1 and playerData and 
                   playerData[LocalPlayer.Name] and playerData[LocalPlayer.Name].Dead == false then
                    
                    task.wait(1)
                    HumanoidRootPart = getHumanoidRootPart()
                    
                    if HumanoidRootPart then
                        HumanoidRootPart.Anchored = false
                        for _ = 1, 3 do
                            HumanoidRootPart.CFrame = safetyPart.CFrame
                            task.wait(0.1)
                        end
                    end
                    
                    UI:SetTask("New round active! Farming...")
                    
                    if Config['CPU Saver'] then
                        clearMapForCPU()
                    end
                    
                    break
                end
            end
        end
    end
end)

print("Hasty MM2 Coin Farmer loaded successfully!")
print("Version: " .. GameVersion)
print("UI Integrated with Kaitun")
