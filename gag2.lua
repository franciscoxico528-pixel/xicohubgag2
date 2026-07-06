--Created At Jun 13, 2026 - 10:00 AM, Done At Jun 20, 2026 - 16:00 PM 
-- https://discord.gg/EkTN3D2RSt
-- Script Will be have some bug , u can fix this 
getgenv().Config = getgenv().Config or {
    ["Auto Harvest"] = true,
    ["Auto Plant"] = true,
    ["Auto Sell"] = true,
    ["Auto Buy Seed"] = true,
    ["Auto Buy Gear"] = true,
    ["Auto Use Gear"] = true,
    ["Auto Expand Garden"] = true,
    ["Black Screen"] = false,
    ["FPS Cap"] = 60,
    ["Auto Set FPS"] = true, -- Enable if webrb / disable if emulator
    ["Auto Shovel"] = true,
    ["Auto Catch Pet"] = true,
    ["Auto Equip Pets"] = true,
    ["Auto Optimize Pets"] = true,
    ["Auto Upgrade Pet Slots"] = true,
    ["Auto Tutorial"] = true,
    ["Auto Redeem Codes"] = true,
    ["Codes To Redeem"] = {
        "TEAMGREENBEAN",
    },
    ["Auto Pickup Mutation Seeds"] = true,
    ["Teleport To Seed Packs"] = true,
    ["Auto Plant Mutation Seeds"] = false,
    ["Sell After"] = 30,
    ["Mutation Seeds To Plant"] = {},
    ["Gear To Buy"] = {},
    ["BUY_PET"] = {
        ["Monkey"] = 99,
        ["Bee"] = 99,
        ["BlackDragon"] = 99,
        ["GoldenDragonfly"] = 99,
        ["Unicorn"] = 99,
        ["Raccoon"] = 99,
        ["IceSerpent"] = 99,
        ["Robin"] = 5,
        ["Deer"] = 5,
    },
    ["EQUIP_PET"] = { -- {"Name", Amount to Equip, Priority}
        {"Unicorn", 5, 1},
        {"GoldenDragonfly", 10, 2},
        {"Robin", 5, 3},
        {"Deer", 5, 4},
    },
    ["BUY_GEAR"] = { -- ["Name"] = Amount
        ["Super Watering Can"] = 9999,
        ["Super Sprinkler"] = 9999,
    },
    ["USE_SPRINKLER"] = {
        "Super Sprinkler",
        "Legendary Sprinkler",
        "Rare Sprinkler",
        "Uncommon Sprinkler",
        "Common Sprinkler",
    },
    ["COLLECT_PLANT_IF_MUTATED"] = { "Bamboo", "Mushroom", "Green Bean" },
    ["EXPAND_PLOT"] = 1, -- 1 = Expand 1 plot, 2 = Expand 2 plots, 3 = Expand 3 plots, etc.
    ["MAX_PET_SLOTS"] = 0, -- 0 = Max 3 slots, 1 = Max 4 slots, 2 = Max 5 slots, etc.
    ["Pet Catch Webhook"] = {
        Enabled = true,
        Url = "",
        Note = "Gag2",
        Mention = "@everyone Found: ",
    },
    ["Seed Pack Webhook"] = {
        Enabled = true,
        Url = "",
        Note = "Gag2",
    },
    ["Seeds To Plant"] = {
        ["Carrot"] = 15,["Strawberry"] = 15,["Blueberry"] = 15,["Tulip"] = 15,["Tomato"] = 15,["Apple"] = 15,["Corn"] = 15,["Bamboo"]=30,["Mushroom"]=30,
        ["Cactus"] = 30,["Pineapple"] = 30,["Green Bean"] = 30,["Banana"] = 30,["Grape"] = 30,["Coconut"] = 30,["Mango"] = 30,
        ["Dragon Fruit"] = 30,["Acorn"] = 30,["Cherry"] = 30,["Sunflower"] = 30,
    },
    ["Buy Seeds"] = {},
    ["Auto Send Mail"] = true,
    ["Mail To Send"] = {
        ["LawrenceLittle66"] = {
            Note = "gift",
            Items = { -- ["Name"] = Amount , if Amount = 0 then send all items
                "Golden Dragonfly",
                "Unicorn",
                "Raccoon",
            },
        },
    },
}

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local Config = getgenv().Config
local SeedsToPlant = Config["Seeds To Plant"] or {}
local GearToBuy = Config["Gear To Buy"] or {}
local PetsToCatch = Config["Pets To Catch"] or {}
local PetsToEquip = Config["Pets To Equip"] or {}
local BuyPet = Config["BUY_PET"] or {}
local EquipPet = Config["EQUIP_PET"] or {}
local BuyGear = Config["BUY_GEAR"] or {}
local UseSprinkler = Config["USE_SPRINKLER"] or {}
local CollectIfMutated = Config["COLLECT_PLANT_IF_MUTATED"] or {}
local ExpandLimit = Config["EXPAND_PLOT"]
local MaxPetSlots = Config["MAX_PET_SLOTS"]
local BuySeeds = {}

local function refreshBuySeeds()
    table.clear(BuySeeds)
    local list = Config["Buy Seeds"] or {}
    for key, value in list do
        if type(key) == "number" then
            BuySeeds[value] = true
        else
            BuySeeds[key] = true
        end
    end
end

refreshBuySeeds()

local COOLDOWN = {
    Harvest = 0.02,
    Plant = 0.5,
    Buy = 0.3,
    Expand = 8,
    Sell = 1,
    Shovel = 0.35,
    Gear = 0.55,
    PetCatch = 1.5,
    PetEquip = 1.2,
    PetOptimize = 60,
    PetSlotUpgrade = 5,
    Cache = 2,
    Loop = 0.5,
    HarvestLoop = 0.05,
    PetCatchLoop = 0.35,
    PickupLoop = 0.3,
    Pickup = 0.35,
    ReturnPlot = 2,
    ReturnPlotLoop = 0.4,
    Mail = 2,
}

local MAIL_MIN_SHECKLES = 1000
local TUTORIAL_COMPLETE_MIN_SHECKLES = 10
local MIN_PLANTS_SAFE = 100

local TP_DISTANCE = 25
local VirtualUser = game:GetService("VirtualUser")

local lastCooldownCleanup = 0
local COOLDOWN_CLEANUP_INTERVAL = 300
local COOLDOWN_MAX_AGE = 600

local function cleanupCooldowns()
    local now = os.clock()
    if now - lastCooldownCleanup < COOLDOWN_CLEANUP_INTERVAL then return end
    lastCooldownCleanup = now

    if petCatchCooldown then
        for key, time in pairs(petCatchCooldown) do
            if now - time > COOLDOWN_MAX_AGE then
                petCatchCooldown[key] = nil
            end
        end
    end
end

local AUTO_BUY_USE_GEAR = Config["BUY_GEAR"]

local WATERING_CAN_PRIORITY = { "Super Watering Can", "Common Watering Can" }
local SPRINKLER_PRIORITY = UseSprinkler

local function waitUntil(label, fn, timeout)
    timeout = timeout or 90
    local t = os.clock() + timeout
    while not fn() and os.clock() < t do
        task.wait(0.2)
    end
    return fn()
end

waitUntil("Character", function()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart") ~= nil
end, 120)
LocalPlayer:SetAttribute("LoadingScreenActive", false)
LocalPlayer:SetAttribute("LoadingScreenDone", true)
local char = LocalPlayer.Character
if char then
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.Anchored = false
    end
end
local menu = workspace:FindFirstChild("LoadingScreenMenu")
if menu then
    menu:Destroy()
end

waitUntil("DataLoaded", function()
    return CollectionService:HasTag(LocalPlayer, "DataLoaded")
end, 120)

waitUntil("PlotId", function()
    return LocalPlayer:GetAttribute("PlotId") ~= nil
end, 120)
if Config["Auto Set FPS"] then
task.spawn(function()
    while true do
        setfpscap(Config["FPS Cap"])
        if getgenv().Config["Black Screen"] then
            game:GetService("Lighting").ExposureCompensation = -math.huge
        else
            game:GetService("Lighting").ExposureCompensation = 0
        end
        task.wait(30)
    end
end)
end
pcall(function()
    LocalPlayer:SetAttribute("AntiAfkIdleOverride", 999999999)
end)
task.spawn(function()
    while true do
        pcall(function()
            LocalPlayer:SetAttribute("AntiAfkIdleOverride", 999999999)
        end)
        VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
        task.wait(30)
    end
end)

game:GetService("Players").LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)
local PlayerState = require(ReplicatedStorage.ClientModules:WaitForChild("PlayerStateClient"))
local PlayerReplica = PlayerState:WaitForLocalReplica(30)

local Shared = ReplicatedStorage:WaitForChild("SharedModules")
local SeedData = require(Shared:WaitForChild("SeedData"))
local SeedShopFlags = require(Shared.Flags:WaitForChild("SeedShopFlags"))
local GearShopData = require(Shared:WaitForChild("GearShopData"))
local GearShopFlags = require(Shared.Flags:WaitForChild("GearShopFlags"))
local GardenFlags = require(Shared.Flags:WaitForChild("GardenFlags"))
local FruitValueCalc = require(Shared:WaitForChild("FruitValueCalc"))
local ExpansionPrices = require(ReplicatedStorage.SharedData:WaitForChild("ExpansionPrices"))
local PetSizes = require(ReplicatedStorage.SharedData:WaitForChild("PetSizes"))
local PetData = require(ReplicatedStorage.SharedData:WaitForChild("PetData"))
local PetTypes = require(ReplicatedStorage.SharedData:WaitForChild("PetTypes"))
local PetSlotPrices = require(ReplicatedStorage.SharedData:WaitForChild("PetSlotPrices"))

local SeedDataByName = {}
for _, info in ipairs(SeedData) do
    SeedDataByName[info.SeedName] = info
end

local StockItems = ReplicatedStorage:WaitForChild("StockValues"):WaitForChild("SeedShop"):WaitForChild("Items")
local GearStockItems = ReplicatedStorage:WaitForChild("StockValues"):WaitForChild("GearShop"):WaitForChild("Items")

local GearDataByName = {}
for _, info in ipairs(GearShopData.Data) do
    GearDataByName[info.ItemName] = info
end

local RakeController = require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Controllers"):WaitForChild("RakeController"))
local PlayerPlot = RakeController.GetPlayerPlot()

local savedPlotCenter = nil
local savedPlotSize = Vector3.new(44, 1, 44)
local savedPlantPositions = {}

local function cachePlantPositions(plot)
    table.clear(savedPlantPositions)
    if not plot then return end
    local visual = plot:FindFirstChild("Visual")
    if not visual then return end
    for _, col in visual:GetChildren() do
        if col.Name:match("^PlantAreaColumn") then
            for _, part in col:GetChildren() do
                if part:IsA("BasePart") then
                    savedPlantPositions[#savedPlantPositions + 1] = part.Position
                end
            end
        end
    end
end

if PlayerPlot then
    local psr = PlayerPlot:FindFirstChild("PlotSizeReference")
    if psr and psr:IsA("BasePart") then
        savedPlotCenter = psr.Position
        savedPlotSize = psr.Size
    else
        savedPlotCenter = PlayerPlot:GetPivot().Position
    end
    cachePlantPositions(PlayerPlot)
end

local function refreshPlayerPlot()
    local cur = RakeController.GetPlayerPlot()
    if cur and cur ~= PlayerPlot then
        PlayerPlot = cur
        local psr = cur:FindFirstChild("PlotSizeReference")
        if psr and psr:IsA("BasePart") then
            savedPlotCenter = psr.Position
            savedPlotSize = psr.Size
        else
            savedPlotCenter = cur:GetPivot().Position
        end
        cachePlantPositions(cur)
        refreshPlantAreas()
    end
end

getgenv().Networking = require(Shared:WaitForChild("Networking"))
local Net = getgenv().Networking

task.spawn(function() Net.Garden.RequestGardens:Fire() end)

local myUserId = LocalPlayer.UserId
local trackedPlants = {}
local lastSyncTime = 0

local function getPlantSeedName(plantData)
    if type(plantData) ~= "table" then return nil end
    return plantData.PlantName or plantData.plantName
        or plantData.seedName or plantData.SeedName or plantData.Seed
        or plantData.seed or plantData.Name or plantData.name
end

local function hookGardenRemote(name, fn)
    local ok, remote = pcall(function() return Net.Garden[name] end)
    if ok and remote and remote.OnClientEvent then
        remote.OnClientEvent:Connect(fn)
    end
end

hookGardenRemote("PlantAdded", function(userId, plantId, data)
    if userId ~= myUserId then return end
    if type(data) ~= "table" then return end
    trackedPlants[plantId] = data
end)

hookGardenRemote("PlantRemoved", function(userId, plantId)
    if userId ~= myUserId then return end
    trackedPlants[plantId] = nil
end)

hookGardenRemote("FruitAdded", function(userId, plantId, fruitId, data)
    if userId ~= myUserId then return end
    if not trackedPlants[plantId] then trackedPlants[plantId] = { Fruits = {} } end
    if not trackedPlants[plantId].Fruits then trackedPlants[plantId].Fruits = {} end
    trackedPlants[plantId].Fruits[fruitId] = data
end)

hookGardenRemote("FruitRemoved", function(userId, plantId, fruitId)
    if userId ~= myUserId then return end
    local p = trackedPlants[plantId]
    if p and p.Fruits then p.Fruits[fruitId] = nil end
end)

pcall(function()
    Net.Garden.SyncAllGardens.OnClientEvent:Connect(function(gardensData)
        local myUid = myUserId
        for uid, gardenInfo in pairs(gardensData) do
            local userId = tonumber(uid) or uid
            if userId == myUid and gardenInfo.Plants then
                trackedPlants = gardenInfo.Plants
                local count = 0
                for _ in pairs(trackedPlants) do count += 1 end
            end
        end
    end)
end)

getgenv().Debug = { plants = 0, fruits = 0, fires = 0, cycles = 0, lastCycle = 0 }

local firedSet = {}
local HARVEST_BATCH = 5

local function shouldCollectPlant(plantData)
    local seedName = getPlantSeedName(plantData)
    if not seedName then return true end
    for _, name in ipairs(CollectIfMutated) do
        if name == seedName then
            local mutation = plantData.Mutation
            return mutation ~= nil and mutation ~= "" and mutation ~= "Normal"
        end
    end
    return true
end

task.spawn(function()
    while true do
        local ok = pcall(function()
        local t = os.clock()
        local p, f, n = 0, 0, 0

        for plantId, plantData in pairs(trackedPlants) do
            if type(plantData) ~= "table" then continue end
            p += 1
            local plantAge = plantData.Age or 0
            local plantMaxAge = plantData.MaxAge or 0
            local plantReady = plantMaxAge <= 0 or plantAge >= plantMaxAge
            local fruits = plantData.Fruits
            if type(fruits) == "table" then
                for fruitId, fruitData in pairs(fruits) do
                    if type(fruitData) == "table" then
                        local fruitAge = fruitData.Age or 0
                        local fruitMaxAge = fruitData.MaxAge or 0
                        if fruitMaxAge <= 0 or fruitAge >= fruitMaxAge then
                            local key = plantId .. "|" .. fruitId
                            if not firedSet[key] and n < HARVEST_BATCH and shouldCollectPlant(plantData) then
                                pcall(function()
                                    Net.Garden.CollectFruit:Fire(plantId, fruitId)
                                end)
                                firedSet[key] = os.clock()
                                f += 1
                                n += 1
                            end
                        end
                    end
                end
            end
            if plantReady and shouldCollectPlant(plantData) then
                local key = plantId .. "|_plant"
                if not firedSet[key] and n < HARVEST_BATCH then
                    pcall(function()
                        Net.Garden.CollectFruit:Fire(plantId, "")
                    end)
                    firedSet[key] = os.clock()
                    n += 1
                end
            end
        end

        local now = os.clock()
        for key, time in pairs(firedSet) do
            if now - time > 30 then firedSet[key] = nil end
        end

        pcall(function() Net.Garden.RequestGardens:Fire() end)
        Debug.plants = p
        Debug.fruits = f
        Debug.fires = Debug.fires + n
        Debug.cycles += 1
        Debug.lastCycle = math.floor((os.clock() - t) * 1000)
        end)
        if not ok then
            warn("[Harvest] Error in harvest loop")
        end
        task.wait()
    end
end)

local plantAreas = {}
local plantSpotIndex = 0

local function refreshPlantAreas()
    table.clear(plantAreas)
    if #savedPlantPositions > 0 then
        for _, pos in savedPlantPositions do
            plantAreas[#plantAreas + 1] = pos
        end
        return
    end
    if not savedPlotCenter then return end
    local step = 4
    local halfX = savedPlotSize.X / 2 - 2
    local halfZ = savedPlotSize.Z / 2 - 2
    for x = -halfX, halfX, step do
        for z = -halfZ, halfZ, step do
            plantAreas[#plantAreas + 1] = Vector3.new(
                savedPlotCenter.X + x,
                savedPlotCenter.Y,
                savedPlotCenter.Z + z
            )
        end
    end
end
refreshPlantAreas()

local function countGardenPlants()
    local count = 0
    for _ in pairs(trackedPlants) do count += 1 end
    return count
end

local function isMutationSeedName(seedName)
    if type(seedName) ~= "string" or seedName == "" then return false end
    local lower = string.lower(seedName)
    return lower == "rainbow" or lower == "gold" or lower == "golden"
end

local function isBuySeed(seedName)
    if isMutationSeedName(seedName) then return false end
    if not seedName or BuySeeds[seedName] ~= true then return false end
    return countGardenPlants() >= MIN_PLANTS_SAFE
end

local MapFolder = nil
local WildPetFolder = nil
local WildPetSpawns = nil
local SeedPackSpawns = nil
local TeleportsFolder = nil
local GardensFolder = nil
local PlotSizeReference = nil

local RARITY_PRIORITY = {
    Secret = 1, Super = 2, Mythic = 3, Legendary = 4,
    Epic = 5, Rare = 6, Uncommon = 7, Common = 8,
}

local lastSellTime, lastSellTry = 0, 0
local lastPlantTime, lastBuyTime, lastBuyGearTime, lastExpandTime, lastShovelTime, lastGearTime, lastPetCatchTime, lastPetEquipTime, lastPetOptimizeTime, lastPetSlotUpgradeTime, lastPickupTime, lastReturnPlotTime, lastMailTime, lastTutorialCompleteTime = 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
local lastCacheTime = 0
local sellInterval = Config["Sell After"] or 30

local cachedPlants, cachedTools = {}, {}
local plantDataCache = {}
local petCatchCooldown = {}
local petsToCatchList = {}
local petsToEquipList = {}
local isCatchingPet = false
local isPickingUpSeed = false
local isSendingMail = false
local isDeployingPet = false

local API = {}

local function bootstrapShared()
function API.normalizeMutationTag(tag)
    if type(tag) ~= "string" or tag == "" then return nil end
    local lower = string.lower(string.gsub(tag, "^%s*(.-)%s*$", "%1"))
    if lower == "rainbow" then return "Rainbow" end
    if lower == "gold" or lower == "golden" then return "Gold" end
    return tag
end

function API.normalizePetName(name)
    return string.lower(string.gsub(name or "", "^%s*(.-)%s*$", "%1"))
end

function API.getPetDisplayName(species, size)
    if not species then return "" end
    local ok, display = pcall(PetData.GetDisplayName, species, size)
    if ok and type(display) == "string" then return display end
    ok, display = pcall(PetData.GetSpeciesDisplayName, species)
    if ok and type(display) == "string" then return display end
    return species
end

function API.matchesTargetName(species, size, targetName)
    local targetNorm = API.normalizePetName(targetName)
    local display = API.normalizePetName(API.getPetDisplayName(species, size))
    local speciesNorm = API.normalizePetName(API.getPetDisplayName(species, nil))
    if display == targetNorm or speciesNorm == targetNorm then return true end
    return string.find(display, targetNorm, 1, true) ~= nil
        or string.find(speciesNorm, targetNorm, 1, true) ~= nil
end

function API.mailPetNameMatches(species, size, targetName)
    return API.matchesTargetName(species, size, targetName) or species == targetName
end
end

local function bootstrapGarden()


local cachedSheckles = 0
local function getSheckles()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    local shecklesObj = leaderstats and leaderstats:FindFirstChild("Sheckles")
    if shecklesObj then
        cachedSheckles = shecklesObj.Value
        return cachedSheckles
    end
    if PlayerReplica and PlayerReplica.Data then
        local val = PlayerReplica.Data.Sheckles
        if type(val) == "number" then
            cachedSheckles = val
            return cachedSheckles
        end
    end
    return cachedSheckles
end

local function listenSheckles()
    task.spawn(function()
        task.wait(1)
        local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
        if leaderstats then
            local shecklesObj = leaderstats:FindFirstChild("Sheckles")
            if shecklesObj then
                shecklesObj.Changed:Connect(function(v)
                    cachedSheckles = v
                end)
                cachedSheckles = shecklesObj.Value
            end
        end
    end)
end
listenSheckles()

local function refreshSeedCache()
    if os.clock() - lastCacheTime < COOLDOWN.Cache then return end
    lastCacheTime = os.clock()

    table.clear(cachedPlants)
    table.clear(cachedTools)

    getgenv().plants = {}

    for _, plantData in pairs(trackedPlants) do
        local seedName = getPlantSeedName(plantData)
        if seedName then
            cachedPlants[seedName] = (cachedPlants[seedName] or 0) + 1
            getgenv().plants[seedName] = (getgenv().plants[seedName] or 0) + 1
        end
    end

    local function scan(container)
        if not container then return end
        for _, item in container:GetChildren() do
            if item:IsA("Tool") then
                local seedName = item:GetAttribute("SeedTool")
                if seedName then
                    cachedTools[seedName] = (cachedTools[seedName] or 0) + 1
                end
            end
        end
    end
    scan(LocalPlayer.Character)
    scan(LocalPlayer:FindFirstChild("Backpack"))
end

local function countSeedOwned(seedName)
    local total = 0
    for _, plantData in pairs(trackedPlants) do
        if getPlantSeedName(plantData) == seedName then
            total += 1
        end
    end
    local function scan(container)
        if not container then return end
        for _, item in container:GetChildren() do
            if item:IsA("Tool") and item:GetAttribute("SeedTool") == seedName then
                total += 1
            end
        end
    end
    scan(LocalPlayer.Character)
    scan(LocalPlayer:FindFirstChild("Backpack"))
    return total
end

local function getSeedTotal(seedName)
    refreshSeedCache()
    return (cachedPlants[seedName] or 0) + (cachedTools[seedName] or 0)
end

local function needsMoreSeed(seedName)
    local limit = SeedsToPlant[seedName]
    if not limit then return false end
    return countSeedOwned(seedName) < limit
end

local function hasReachedSeedLimit(seedName)
    local limit = SeedsToPlant[seedName]
    if not limit then return true end
    return countSeedOwned(seedName) >= limit
end

local function getSeedPrice(seedName)
    local info = SeedDataByName[seedName]
    if not info then return math.huge end
    local overrides = SeedShopFlags.PriceOverrides:Get()
    return overrides[seedName] or info.PurchasePrice
end

local function getGearPrice(gearName)
    local info = GearDataByName[gearName]
    if not info then return math.huge end
    local overrides = GearShopFlags.PriceOverrides:Get()
    return overrides[gearName] or info.Cost or math.huge
end

local function getGearStock(gearName)
    local stock = GearStockItems:FindFirstChild(gearName)
    local maxStock = stock and stock.Value or 0
    local purchased = 0
    if PlayerReplica and PlayerReplica.Data and PlayerReplica.Data.PurchasedThisRestock then
        purchased = (PlayerReplica.Data.PurchasedThisRestock.Gears or {})[gearName] or 0
    end
    return math.max(maxStock - purchased, 0)
end

local function getGearRarity(gearName)
    local info = GearDataByName[gearName]
    return info and info.Rarity or "Common"
end
local function getRarityRank(rarity)
    return RARITY_PRIORITY[rarity] or 99
end

local function compareGearPriority(gearA, gearB)
    local ra = getRarityRank(getGearRarity(gearA))
    local rb = getRarityRank(getGearRarity(gearB))
    if ra ~= rb then return ra < rb end
    local pa, pb = getGearPrice(gearA), getGearPrice(gearB)
    if pa ~= pb then return pa > pb end
    return gearA < gearB
end

local function getSeedStock(seedName)
    local stock = StockItems:FindFirstChild(seedName)
    local maxStock = stock and stock.Value or 0
    local purchased = 0
    if PlayerReplica and PlayerReplica.Data and PlayerReplica.Data.PurchasedThisRestock then
        purchased = (PlayerReplica.Data.PurchasedThisRestock.Seeds or {})[seedName] or 0
    end
    return math.max(maxStock - purchased, 0)
end

local function getFruitCount()
    return LocalPlayer:GetAttribute("FruitCount") or 0
end

local function getMaxFruitCapacity()
    return LocalPlayer:GetAttribute("MaxFruitCapacity") or 100
end

local function isInventoryFull()
    return getFruitCount() >= getMaxFruitCapacity()
end

local function getAge(model)
    return model:GetAttribute("Age") or model:GetAttribute("CurrentAge") or 0
end

local function getModelPosition(model)
    if not model then return nil end
    if model.PrimaryPart then
        return model.PrimaryPart.Position
    end
    local part = model:FindFirstChildWhichIsA("BasePart", true)
    if part then return part.Position end
    return model:GetPivot().Position
end

local function equipTool(tool)
    if not tool then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and tool.Parent ~= char then
        hum:EquipTool(tool)
        task.wait(0.08)
    end
end

local function findGearTool(attrName, priorityList)
    local found = {}
    local function scan(container)
        if not container then return end
        for _, item in container:GetChildren() do
            if item:IsA("Tool") then
                local name = item:GetAttribute(attrName)
                if name then
                    found[name] = item
                end
            end
        end
    end
    scan(LocalPlayer.Character)
    scan(LocalPlayer:FindFirstChild("Backpack"))
    for _, name in priorityList do
        local tool = found[name]
        if tool then return tool, name end
    end
end

local function estimateFruitValue(plant, fruitModel)
    local seedName = plant:GetAttribute("SeedName")
    if not seedName then return 0 end
    local size = (fruitModel and fruitModel:GetAttribute("SizeMultiplier")) or plant:GetAttribute("SizeMultiplier") or 1
    local mutation = (fruitModel and fruitModel:GetAttribute("Mutation")) or plant:GetAttribute("Mutation")
    local decay = fruitModel and fruitModel:GetAttribute("DecayAlpha")
    local ok, value = pcall(FruitValueCalc, seedName, size, mutation, LocalPlayer, decay)
    if ok and type(value) == "number" then return value end
    return 0
end

local function getGrowthRemaining(model)
    local maxAge = model:GetAttribute("MaxAge")
    if not maxAge then return 0 end
    return math.max(maxAge - getAge(model), 0)
end

local function isStillGrowing(model)
    local maxAge = model:GetAttribute("MaxAge")
    if not maxAge then return false end
    return getAge(model) < maxAge
end

local function findPlantAreaPosition(nearPos)
    if #plantAreas == 0 then
        refreshPlantAreas()
    end
    if #plantAreas == 0 or not nearPos then return nil end

    local bestPos, bestDist
    for _, pos in plantAreas do
        local flatDist = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(nearPos.X, 0, nearPos.Z)).Magnitude
        if not bestDist or flatDist < bestDist then
            bestPos = pos
            bestDist = flatDist
        end
    end

    return bestPos
end

local function isTooCloseToSprinkler(position)
    return false
end

local function isTooCloseToSprinkler(position)
    return false
end

local function collectGrowingTargets()
    local targets = {}
    for plantId, plantData in pairs(trackedPlants) do
        if type(plantData) ~= "table" then continue end
        local age = plantData.Age or 0
        local maxAge = plantData.MaxAge or 0
        if maxAge > 0 and age < maxAge then
            local positions = plantData.Positions or plantData.Position
            local pos = nil
            if type(positions) == "table" then
                local x = positions.PosX or positions.X
                local y = positions.PosY or positions.Y
                local z = positions.PosZ or positions.Z
                if x and y and z then
                    pos = Vector3.new(x, y, z)
                else
                    local p = positions.Position or positions.Pos or positions
                    if type(p) == "table" then
                        x = p.X or p.x or p[1]
                        y = p.Y or p.y or p[2]
                        z = p.Z or p.z or p[3]
                        if x and y and z then
                            pos = Vector3.new(x, y, z)
                        end
                    end
                end
            elseif type(positions) == "userdata" then
                pos = positions
            end
            if pos then
                targets[#targets + 1] = {
                    plantId = plantId,
                    seedName = getPlantSeedName(plantData),
                    position = pos,
                    age = age,
                    maxAge = maxAge,
                }
            end
        end
    end
    return targets
end

local function tryBuyGearFromList(list)
    table.sort(list, compareGearPriority)
    for _, gearName in list do
        if getGearStock(gearName) <= 0 then continue end
        if getSheckles() < getGearPrice(gearName) then continue end
        lastBuyGearTime = os.clock()
        Net.GearShop.PurchaseGear:Fire(gearName)
        return true
    end
    return false
end

local function tryBuyGear()
    if os.clock() - lastBuyGearTime < COOLDOWN.Buy then return end

    if Config["Auto Use Gear"] ~= false then
        if tryBuyGearFromList(table.clone(AUTO_BUY_USE_GEAR)) then return end
    end

    if Config["Auto Buy Gear"] == false then return end
    local customList = {}
    for gearName, amount in BuyGear do
        if type(gearName) == "string" and type(amount) == "number" then
            customList[#customList + 1] = gearName
        end
    end
    if #customList == 0 then return end
    tryBuyGearFromList(customList)
end

local function getPlotCenterCFrame()
    if savedPlotCenter then
        return CFrame.new(savedPlotCenter) + Vector3.new(0, 3, 0)
    end
    return nil
end

local function getGearHomePosition()
    local center = getPlotCenterCFrame()
    if center then return center.Position end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position or Vector3.zero
end

local function getMaxPlotRadius()
    if savedPlotSize then
        return math.max(savedPlotSize.X, savedPlotSize.Z) * 0.55 + 20
    end
    return 70
end

local function isTooFarFromPlot(position)
    if not position or not savedPlotCenter then return false end
    local flatDist = (Vector3.new(position.X, 0, position.Z) - Vector3.new(savedPlotCenter.X, 0, savedPlotCenter.Z)).Magnitude
    return flatDist > getMaxPlotRadius()
end

local function isGearTargetTooFar(position)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not position then return true end
    local flatDist = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude
    return flatDist > TP_DISTANCE
end

local function getGearStandCFrame(groundPos)
    return CFrame.new(groundPos + Vector3.new(0, 3, 0))
end

local function tryUseGear()
    if Config["Auto Use Gear"] == false or not PlayerPlot then return end
    local plotId = LocalPlayer:GetAttribute("PlotId")
    if not plotId then return end
    if os.clock() - lastGearTime < COOLDOWN.Gear then return end

    local targets = collectGrowingTargets()
    if #targets == 0 then return end

    local target = targets[1]
    local placePos = findPlantAreaPosition(target.position)
    if not placePos then return end

    local canTool, canName = findGearTool("WateringCan", WATERING_CAN_PRIORITY)
    local sprinklerTool, sprinklerName = findGearTool("Sprinkler", SPRINKLER_PRIORITY)
    local willUseCan = canTool ~= nil and canName ~= nil
    local willUseSprinkler = sprinklerTool ~= nil and sprinklerName ~= nil and not isTooCloseToSprinkler(placePos)

    if not willUseCan and not willUseSprinkler then return end

    local needTp = isGearTargetTooFar(placePos)
    local homePos = needTp and getGearHomePosition() or nil

    if needTp then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = getGearStandCFrame(placePos)
        end
        task.wait(0.05)
    end

    local used = false
    if willUseCan then
        equipTool(canTool)
        Net.WateringCan.UseWateringCan:Fire(placePos - Vector3.new(0, 0.3, 0), canName, canTool)
        used = true
        task.wait(0.55)
    end

    if willUseSprinkler then
        equipTool(sprinklerTool)
        Net.Place.PlaceSprinkler:Fire(placePos, sprinklerName, sprinklerTool, plotId)
        used = true
    end

    if needTp and homePos then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(homePos)
        end
    end

    if used then
        lastGearTime = os.clock()
    end
end

local function trySellAll()
    if Config["Auto Sell"] == false then return false end
    local now = os.clock()
    if now - lastSellTry < COOLDOWN.Sell then return false end
    lastSellTry = now

    local ok1, preview = pcall(function() return Net.NPCS.PreviewSellAll:Fire() end)
    if not ok1 or not preview or (preview.FruitCount or 0) <= 0 then return false end
    local ok2, result = pcall(function() return Net.NPCS.SellAll:Fire() end)
    return result and result.Success == true
end

local function shouldSell()
    if Config["Auto Sell"] == false then return false end
    if getFruitCount() <= 0 then return false end
    if isInventoryFull() then return true end
    return os.clock() - lastSellTime >= sellInterval
end

local function doSell()
    if trySellAll() then
        lastSellTime = os.clock()
        return true
    end
    return false
end

local function getSeedRarity(seedName)
    local info = SeedDataByName[seedName]
    return info and info.Rarity or "Common"
end


local sortedSeedsCache, sortedSeedsCacheTime = nil, 0

local function compareSeedPriority(seedA, seedB)
    local ra = getRarityRank(getSeedRarity(seedA))
    local rb = getRarityRank(getSeedRarity(seedB))
    if ra ~= rb then return ra < rb end
    local pa, pb = getSeedPrice(seedA), getSeedPrice(seedB)
    if pa ~= pb then return pa > pb end
    return seedA < seedB
end

local function getSortedSeeds()
    if sortedSeedsCache and os.clock() - sortedSeedsCacheTime < 5 then
        return sortedSeedsCache
    end
    local seen = {}
    local list = {}
    for seedName in SeedsToPlant do
        if not seen[seedName] then
            seen[seedName] = true
            list[#list + 1] = seedName
        end
    end
    for seedName in BuySeeds do
        if not seen[seedName] then
            seen[seedName] = true
            list[#list + 1] = seedName
        end
    end
    table.sort(list, compareSeedPriority)
    sortedSeedsCache = list
    sortedSeedsCacheTime = os.clock()
    return list
end

local function tryBuySeed()
    if Config["Auto Buy Seed"] == false then return end
    if os.clock() - lastBuyTime < COOLDOWN.Buy then return end

    local sheckles = getSheckles()
    for _, seedName in getSortedSeeds() do
        local limit = SeedsToPlant[seedName]
        if limit then
            local owned = countSeedOwned(seedName)
            if owned >= limit then continue end
        end
        if getSeedStock(seedName) <= 0 then continue end
        local price = getSeedPrice(seedName)
        if sheckles < price then continue end
        print("[Buy Seed] Buying " .. seedName .. " for " .. price .. " sheckles")
        lastBuyTime = os.clock()
        Net.SeedShop.PurchaseSeed:Fire(seedName)
        lastCacheTime = 0
        return
    end
end

local function findShovelTool()
    local function scan(container)
        if not container then return end
        for _, item in container:GetChildren() do
            if item:IsA("Tool") and item:GetAttribute("Shovel") then
                return item, item:GetAttribute("Shovel")
            end
        end
    end
    local tool, name = scan(LocalPlayer.Character)
    if tool then return tool, name end
    return scan(LocalPlayer:FindFirstChild("Backpack"))
end

local function pickShovelTarget(list, limit)
    if #list <= limit then return nil end
    table.sort(list, function(a, b)
        local ma = a.mutation == "Rainbow" and 3 or (a.mutation == "Gold" and 2 or 1)
        local mb = b.mutation == "Rainbow" and 3 or (b.mutation == "Gold" and 2 or 1)
        if ma ~= mb then return ma < mb end
        return getRarityRank(getSeedRarity(a.seedName)) > getRarityRank(getSeedRarity(b.seedName))
    end)
    return list[1]
end

local function findShovelTool()
    local function scan(container)
        if not container then return end
        for _, item in container:GetChildren() do
            if item:IsA("Tool") and item:GetAttribute("Shovel") then
                return item, item:GetAttribute("Shovel")
            end
        end
    end
    local tool, shovel = scan(LocalPlayer.Character)
    if tool then return tool, shovel end
    return scan(LocalPlayer:FindFirstChild("Backpack"))
end

local function tryShovelExcess()
    if Config["Auto Shovel"] == false then return end
    if os.clock() - lastShovelTime < COOLDOWN.Shovel then return end

    local plantCount = 0
    for _ in pairs(trackedPlants) do plantCount += 1 end
    if plantCount == 0 then return end

    refreshSeedCache()

    local target
    for seedName, limit in SeedsToPlant do
        local list = {}
        for plantId, plantData in pairs(trackedPlants) do
            if getPlantSeedName(plantData) == seedName then
                list[#list + 1] = {
                    plantId = plantId,
                    seedName = seedName,
                    mutation = plantData.Mutation or "Normal",
                }
            end
        end
        target = pickShovelTarget(list, limit)
        if target then break end
    end

    if not target then return end

    local shovelTool, shovelName = findShovelTool()
    if not shovelTool or not shovelName then return end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and shovelTool.Parent ~= char then
        hum:EquipTool(shovelTool)
        task.wait(0.1)
    end

    lastShovelTime = os.clock()
    lastCacheTime = 0
    Net.Shovel.UseShovel:Fire(target.plantId, "", shovelName, shovelTool)
end

local function tryExpandGarden()
    if Config["Auto Expand Garden"] == false then return end
    if os.clock() - lastExpandTime < COOLDOWN.Expand then return end

    local owned = (PlayerReplica and PlayerReplica.Data and PlayerReplica.Data.OwnedExpansions) or 1
    local maxExpand = ExpandLimit
    if type(maxExpand) == "number" and (owned - 1) >= maxExpand then return end

    local nextInfo = ExpansionPrices[owned + 1]
    if not nextInfo then return end

    local overrides = GardenFlags.ExpansionPriceOverrides:Get()
    local price = overrides[tostring(owned + 1)] or nextInfo.Price
    if getSheckles() < price then return end

    lastExpandTime = os.clock()
    Net.Actions.ExpandGarden:Fire()
end

local function getMutationSeedPriority()
    local list = Config["Mutation Seeds To Plant"]
    if type(list) ~= "table" or #list == 0 then
        return { "Rainbow", "Gold" }
    end
    return list
end

local function getMutationRank(mutation)
    mutation = API.normalizeMutationTag(mutation)
    if mutation == "Rainbow" then return 1 end
    if mutation == "Gold" then return 2 end
    return nil
end

local function getToolMutationRank(tool)
    if not tool then return nil end
    local rank = getMutationRank(tool:GetAttribute("Mutation"))
    if rank then return rank end
    local seedTool = tool:GetAttribute("SeedTool")
    if seedTool == "Rainbow" then return 1 end
    if seedTool == "Gold" then return 2 end
    return getMutationRank(seedTool)
end

local function isPositionOnMyPlot(position)
    if not PlayerPlot or not position then return false end
    if #plantAreas == 0 then refreshPlantAreas() end
    for _, area in plantAreas do
        local localPos = area.CFrame:PointToObjectSpace(position)
        if math.abs(localPos.X) <= area.Size.X * 0.5 and math.abs(localPos.Z) <= area.Size.Z * 0.5 then
            return true
        end
    end
    return false
end

local function getSeedSpawnPrompt(spawn)
    if not spawn then return nil end
    local prompt = spawn:FindFirstChild("ProximityPrompt")
    if prompt and prompt:IsA("ProximityPrompt") then
        return prompt
    end
    return spawn:FindFirstChildWhichIsA("ProximityPrompt", true)
end

local function fireProximityPrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then return false end
    local fireFn = fireproximityprompt or rawget(getgenv(), "fireproximityprompt")
    if typeof(fireFn) == "function" then
        local ok = pcall(fireFn, prompt, prompt.HoldDuration)
        if ok then return true end
        ok = pcall(fireFn, prompt)
        if ok then return true end
    end
    local ok = pcall(function()
        prompt:InputHoldBegin()
        if prompt.HoldDuration > 0 then
            task.wait(prompt.HoldDuration + 0.05)
        end
        prompt:InputHoldEnd()
    end)
    return ok
end

local function tpToGarden(hrp)
    if not hrp or not hrp.Parent then return end
    local centerCf = getPlotCenterCFrame()
    if centerCf then
        hrp.CFrame = centerCf
    end
end

local TWEEN_STEP = 30
local TWEEN_SPEED = 55

local function tweenTo(pos)
    local c = LocalPlayer.Character
    if not c then return false end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    local hum = c:FindFirstChild("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return false end
    local targetPos = pos + Vector3.new(0, 3, 0)
    local startPos = hrp.Position
    local dist = (targetPos - startPos).Magnitude
    if dist <= 5 then return true end
    local nc
    nc = game:GetService("RunService").Heartbeat:Connect(function()
        local ch = LocalPlayer.Character
        if not ch then if nc then nc:Disconnect() end; return end
        for _, v in ch:GetDescendants() do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
    end)
    if hum then hum.Sit = false end
    local steps = math.ceil(dist / TWEEN_STEP)
    local current = startPos
    for i = 1, steps do
        local t = i / steps
        local nextPos = startPos:Lerp(targetPos, t)
        local segDist = (nextPos - current).Magnitude
        if segDist < 1 then continue end
        local path = Instance.new("Part")
        path.Name = "Gag2TweenStep"
        path.Size = Vector3.new(2, 1, 2)
        path.Transparency = 1
        path.CanCollide = false
        path.Anchored = true
        path.CFrame = CFrame.new(current)
        path.Parent = workspace
        local dur = math.max(segDist / TWEEN_SPEED, 0.05)
        local tw = game:GetService("TweenService"):Create(path,
            TweenInfo.new(dur, Enum.EasingStyle.Linear),
            { CFrame = CFrame.new(nextPos) }
        )
        tw:Play()
        while tw.PlaybackState ~= Enum.PlaybackState.Completed do
            task.wait()
            local ch = LocalPlayer.Character
            local h = ch and ch:FindFirstChild("HumanoidRootPart")
            if h and path.Parent then
                h.CFrame = path.CFrame
            end
        end
        pcall(function() path:Destroy() end)
        current = nextPos
        local ch = LocalPlayer.Character
        local h = ch and ch:FindFirstChild("HumanoidRootPart")
        if h then h.CFrame = CFrame.new(current) end
    end
    if nc then nc:Disconnect() end
    return true
end

local function getSeedPackFolder()
    if SeedPackSpawns then return SeedPackSpawns end
    local map = workspace:FindFirstChild("Map")
    if map then
        return map:FindFirstChild("SeedPackSpawnServerLocations")
    end
    return nil
end

local function getSpawnPosition(spawn)
    if spawn:IsA("BasePart") then
        return spawn.Position
    end
    if spawn:IsA("Model") then
        return spawn:GetPivot().Position
    end
    return nil
end

local function collectMutationSeedSpawns()
    local folder = getSeedPackFolder()
    if not folder then return {} end

    local candidates = {}
    for _, spawn in folder:GetChildren() do
        local isRainbow = spawn:GetAttribute("RainbowSeed") == true
        local isGold = spawn:GetAttribute("GoldSeed") == true
        if isRainbow or isGold then
            local prompt = getSeedSpawnPrompt(spawn)
            if prompt then
                local pos = getSpawnPosition(spawn)
                if pos then
                    candidates[#candidates + 1] = {
                        spawn = spawn,
                        prompt = prompt,
                        position = pos,
                        rank = isRainbow and 1 or 2,
                    }
                end
            end
        end
    end

    table.sort(candidates, function(a, b)
        return a.rank < b.rank
    end)
    return candidates
end

local function findMutationSeedTool()
    local bestTool, bestName, bestRank

    local function consider(item)
        if not item:IsA("Tool") then return end
        local seedName = item:GetAttribute("SeedTool")
        if type(seedName) ~= "string" or seedName == "" then return end
        local rank = getToolMutationRank(item)
        if not rank then return end
        if not bestRank or rank < bestRank then
            bestTool = item
            bestName = seedName
            bestRank = rank
        end
    end

    local function scan(container)
        if not container then return end
        for _, item in container:GetChildren() do
            consider(item)
        end
    end

    scan(LocalPlayer.Character)
    scan(LocalPlayer:FindFirstChild("Backpack"))
    return bestTool, bestName
end

local function tryPickupMutationSeeds()
    if Config["Auto Pickup Mutation Seeds"] == false then return end

    local folder = getSeedPackFolder()
    if not folder then return end

    for _, spawn in folder:GetChildren() do
        local isRainbow = spawn:GetAttribute("RainbowSeed") == true
        local isGold = spawn:GetAttribute("GoldSeed") == true
        if not (isRainbow or isGold) then continue end

        local targetPos = getSpawnPosition(spawn)
        if not targetPos then continue end

        tweenTo(targetPos)
        task.wait(0.2)

        local prompt = spawn:FindFirstChild("ProximityPrompt") or spawn:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then
            fireProximityPrompt(prompt)
            local seedType = isRainbow and "Rainbow" or "Gold"
            print("[SeedPack] Collected " .. seedType .. " Seed")
            pcall(getgenv().sendSeedPackWebhook, seedType)
            lastCacheTime = 0
        end
    end

    isPickingUpSeed = false
    if API.tryPlant then API.tryPlant() end
end

local function findSeedTool()
    if Config["Auto Plant Mutation Seeds"] ~= false then
        local mutationTool, mutationName = findMutationSeedTool()
        if mutationTool then return mutationTool, mutationName end
    end

    refreshSeedCache()
    for _, seedName in getSortedSeeds() do
        if isBuySeed(seedName) then continue end
        if not needsMoreSeed(seedName) then continue end

        local function scan(container)
            if not container then return end
            for _, item in container:GetChildren() do
                if item:IsA("Tool") and item:GetAttribute("SeedTool") == seedName then
                    return item, seedName
                end
            end
        end

        local tool, name = scan(LocalPlayer.Character)
        if tool then return tool, name end
        tool, name = scan(LocalPlayer:FindFirstChild("Backpack"))
        if tool then return tool, name end
    end
end

local function randomPointOnPart(part)
    local size = part.Size
    local rx = (math.random() - 0.5) * size.X * 0.8
    local rz = (math.random() - 0.5) * size.Z * 0.8
    return (part.CFrame * CFrame.new(rx, size.Y * 0.5, rz)).Position
end

local function tryPlant()
    if Config["Auto Plant"] == false then return end
    if os.clock() - lastPlantTime < COOLDOWN.Plant then return end

    if #plantAreas == 0 then
        refreshPlantAreas()
        if #plantAreas == 0 then
            warn("[Plant] plantAreas empty, PlayerPlot:", PlayerPlot, "saved:", savedPlotCenter)
            return
        end
    end

    local tool, seedName = findSeedTool()
    if not tool or not seedName then return end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if hum and tool.Parent ~= char then
        hum:EquipTool(tool)
        task.wait(0.1)
    end

    local plantPos = plantAreas[(plantSpotIndex - 1) % #plantAreas + 1]
    if hrp then
        local flatDist = (Vector3.new(plantPos.X, 0, plantPos.Z) - Vector3.new(hrp.Position.X, 0, hrp.Position.Z)).Magnitude
        if flatDist > TP_DISTANCE then
            hrp.CFrame = CFrame.new(plantPos + Vector3.new(0, 3, 0))
            task.wait(0.05)
        end
    end

    lastPlantTime = os.clock()
    lastCacheTime = 0
    plantSpotIndex += 1
    Net.Plant.PlantSeed:Fire(plantPos, seedName, tool)
end

local function findSeedToolByName(seedName)
    local function scan(container)
        if not container then return end
        for _, item in container:GetChildren() do
            if item:IsA("Tool") and item:GetAttribute("SeedTool") == seedName then
                return item
            end
        end
    end
    return scan(LocalPlayer.Character) or scan(LocalPlayer:FindFirstChild("Backpack"))
end

local function tryReturnIfKnockedAway()
    if isCatchingPet or isPickingUpSeed then return end
    if os.clock() - lastReturnPlotTime < COOLDOWN.ReturnPlot then return end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not isTooFarFromPlot(hrp.Position) then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = false
    end
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    tpToGarden(hrp)
    lastReturnPlotTime = os.clock()
end

local function trySimpleTutorial()
    if Config["Auto Tutorial"] == false then return end
    if countGardenPlants() > 0 then return end
    lastTutorialCompleteTime = os.clock()
    pcall(function() Net.Tutorial.Complete:Fire() end)
end

local function getTotalPlantCount()
    return countGardenPlants()
end

local function tryCompleteTutorial()
    if os.clock() - lastTutorialCompleteTime < 5 then return end

    lastTutorialCompleteTime = os.clock()
    Net.Tutorial.Complete:Fire()
end

local function trimCode(code)
    if type(code) ~= "string" then return "" end
    return string.gsub(code, "^%s*(.-)%s*$", "%1")
end

local function getCodesToRedeem()
    local list = Config["Codes To Redeem"] or {}
    local codes = {}
    for key, value in list do
        if type(key) == "number" then
            local code = trimCode(value)
            if code ~= "" then codes[#codes + 1] = code end
        elseif type(key) == "string" then
            local code = trimCode(key)
            if code ~= "" then codes[#codes + 1] = code end
        end
    end
    return codes
end

local function redeemCodesOnce()
    if Config["Auto Redeem Codes"] == false then return end

    local codes = getCodesToRedeem()
    for i, code in codes do
        Net.Settings.SubmitCode:Fire(code)
        if i < #codes then
            task.wait(0.5)
        end
    end
end

API.tryPlant = tryPlant
API.trySellAll = trySellAll
API.shouldSell = shouldSell
API.doSell = doSell
API.tryBuySeed = tryBuySeed
API.tryBuyGear = tryBuyGear
API.tryUseGear = tryUseGear
API.tryShovelExcess = tryShovelExcess
API.tryExpandGarden = tryExpandGarden
API.tryPickupMutationSeeds = tryPickupMutationSeeds
API.getPlotCenterCFrame = getPlotCenterCFrame
API.tryReturnIfKnockedAway = tryReturnIfKnockedAway
API.trySimpleTutorial = trySimpleTutorial
API.tryCompleteTutorial = tryCompleteTutorial
API.redeemCodesOnce = redeemCodesOnce
API.getSheckles = getSheckles
API.getTotalPlantCount = getTotalPlantCount
end

local function bootstrapMail()

local function getInventoryCount(category, itemKey)
    if not PlayerReplica or not PlayerReplica.Data then return 0 end
    local inventory = PlayerReplica.Data.Inventory
    if type(inventory) ~= "table" then return 0 end
    local bucket = inventory[category]
    if type(bucket) ~= "table" then return 0 end
    local amount = bucket[itemKey]
    if type(amount) == "number" then return amount end
    return 0
end

local MAIL_GIFT_CATEGORIES = {
    "Seeds",
    "Sprinklers",
    "WateringCans",
    "Mushrooms",
    "Gnomes",
    "Raccoons",
    "Crates",
    "SeedPacks",
    "Trowels",
    "Props",
    "Flashbangs",
    "EmptyPots",
    "Pets",
    "HarvestedFruits",
}

local function resolveMailSendCount(owned, amount)
    if type(amount) == "number" and amount > 0 then
        if owned < amount then return 0 end
        return amount
    end
    return owned
end

local function parseMailItemQuery(query)
    if type(query) ~= "string" then return query, nil end
    local base, tag = string.match(query, "^(.-)%s*%[([^%]]+)%]$")
    if base then
        base = string.gsub(base, "^%s*(.-)%s*$", "%1")
        tag = string.gsub(tag, "^%s*(.-)%s*$", "%1")
        return base, API.normalizeMutationTag(tag)
    end
    return query, nil
end

local function mailEntryMatchesName(category, key, entry, itemName, wantMutation)
    if category == "Pets" and type(entry) == "table" then
        return entry.Name == itemName or API.mailPetNameMatches(entry.Name, entry.Size, itemName)
    end

    if category == "HarvestedFruits" and type(entry) == "table" then
        local fruitName = entry.FruitName or entry.Name
        if fruitName ~= itemName then
            local mutation = entry.Mutation
            if mutation and mutation ~= "" then
                if string.format("%s [%s]", fruitName, mutation) ~= itemName then
                    return false
                end
            else
                return false
            end
        end
        if wantMutation then
            return API.normalizeMutationTag(entry.Mutation) == wantMutation
        end
        return wantMutation == nil
    end

    if category == "Seeds" then
        if wantMutation then
            return key == wantMutation or API.normalizeMutationTag(key) == wantMutation
        end
        return key == itemName
    end

    if key == itemName then
        return wantMutation == nil
    end

    return false
end

local function getMailInventoryOwned(category, key, entry)
    if category == "Pets" or category == "HarvestedFruits" then
        if type(entry) ~= "table" then return 0 end
        if entry.Id == nil then return 0 end
        if category == "Pets" and entry.Equipped == true then return 0 end
        return 1
    end
    if type(entry) == "number" and entry > 0 then return entry end
    return 0
end

local function resolveMailItems(itemQuery, amount, forcedCategory)
    local results = {}
    local itemName, wantMutation = parseMailItemQuery(itemQuery)
    if type(itemName) ~= "string" or itemName == "" then return results end

    local inventory = PlayerReplica and PlayerReplica.Data and PlayerReplica.Data.Inventory
    if type(inventory) ~= "table" then return results end

    local categoriesToScan = forcedCategory and { forcedCategory } or MAIL_GIFT_CATEGORIES

    for _, category in categoriesToScan do
        local bucket = inventory[category]
        if type(bucket) ~= "table" then continue end

        if category == "Pets" then
            for key, entry in bucket do
                if not mailEntryMatchesName(category, key, entry, itemName, nil) then continue end
                local owned = getMailInventoryOwned(category, key, entry)
                if owned <= 0 then continue end

                results[#results + 1] = {
                    Category = category,
                    ItemKey = key,
                    Count = 1,
                }
                if type(amount) == "number" and amount > 0 and #results >= amount then
                    return results
                end
            end
            if #results > 0 or forcedCategory == "Pets" then
                return results
            end
        elseif category == "HarvestedFruits" then
            for key, entry in bucket do
                if not mailEntryMatchesName(category, key, entry, itemName, wantMutation) then continue end
                local owned = getMailInventoryOwned(category, key, entry)
                if owned <= 0 then continue end

                results[#results + 1] = {
                    Category = category,
                    ItemKey = key,
                    Count = 1,
                }
                if type(amount) == "number" and amount > 0 and #results >= amount then
                    return results
                end
            end
            if #results > 0 or forcedCategory == "HarvestedFruits" then
                return results
            end
        else
            if category == "Seeds" and wantMutation and itemName ~= "Rainbow" and itemName ~= "Gold" then
                continue
            end

            local lookupName = itemName
            if category == "Seeds" then
                if wantMutation then
                    lookupName = wantMutation
                elseif itemName == "Rainbow" or itemName == "Gold" then
                    lookupName = itemName
                end
            end
            local entry = bucket[lookupName]
            local owned = getMailInventoryOwned(category, lookupName, entry)
            if owned > 0 then
                local sendCount = resolveMailSendCount(owned, amount)
                if sendCount > 0 then
                    results[#results + 1] = {
                        Category = category,
                        ItemKey = lookupName,
                        Count = sendCount,
                    }
                end
                return results
            end
        end
    end

    return results
end

local MAIL_MAX_PER_GIFT = 20
local MAIL_SEND_GAP = 1.6

local function mergeMailBatchEntry(batch, entry)
    for _, existing in batch do
        if existing.Category == entry.Category and existing.ItemKey == entry.ItemKey then
            existing.Count = (existing.Count or 1) + (entry.Count or 1)
            return
        end
    end
    batch[#batch + 1] = entry
end

local function splitMailBatch(batch, maxTotal)
    local chunks = {}
    local current = {}
    local currentTotal = 0

    for _, item in batch do
        local remaining = item.Count or 1
        while remaining > 0 do
            if currentTotal >= maxTotal then
                chunks[#chunks + 1] = current
                current = {}
                currentTotal = 0
            end

            local space = maxTotal - currentTotal
            local take = math.min(remaining, space)
            current[#current + 1] = {
                Category = item.Category,
                ItemKey = item.ItemKey,
                Count = take,
            }
            currentTotal += take
            remaining -= take
        end
    end

    if #current > 0 then
        chunks[#chunks + 1] = current
    end

    return chunks
end

local function lookupMailUserId(username)
    if type(username) ~= "string" or username == "" then return nil end
    username = string.gsub(username, "^%s*@?(.-)%s*$", "%1")
    if username == "" then return nil end

    local ok, userId = pcall(function()
        return Net.Mailbox.LookupPlayer:Fire(username)
    end)
    if not ok or type(userId) ~= "number" or userId <= 0 then return nil end
    return userId
end

local function sendMailBatch(userId, batch, note)
    if type(userId) ~= "number" or #batch == 0 then return false, "empty batch" end

    local ok, success, message = pcall(function()
        return Net.Mailbox.SendBatch:Fire(userId, batch, note or "")
    end)
    if not ok then
        return false, tostring(success)
    end
    if success ~= true then
        return false, (type(message) == "string" and message ~= "" and message) or "send rejected"
    end
    return true, message
end

local function buildMailBatchFromItems(itemsTable, optionalCategory)
    local batch = {}
    if type(itemsTable) ~= "table" then return batch end

    for key, value in itemsTable do
        local itemKey, amount, forcedCategory

        if type(key) == "number" and type(value) == "string" then
            itemKey = value
            amount = nil
            forcedCategory = optionalCategory
        elseif type(key) == "string" then
            itemKey = key
            forcedCategory = optionalCategory
            if type(value) == "number" then
                amount = value
            elseif type(value) == "table" then
                itemKey = value.Item or value.ItemKey or value.item or key
                amount = value.Count or value.Amount or value.amount
                forcedCategory = value.Category or value.category or optionalCategory
                local mutation = value.Mutation or value.mutation
                if mutation and type(itemKey) == "string" and not string.find(itemKey, "%[", 1, true) then
                    local cat = forcedCategory or value.Category or value.category
                    if cat ~= "Pets" then
                        itemKey = string.format("%s [%s]", itemKey, mutation)
                    end
                end
            else
                amount = nil
            end
        else
            continue
        end

        if type(itemKey) ~= "string" or itemKey == "" then continue end

        local items = resolveMailItems(itemKey, amount, forcedCategory)
        for _, item in items do
            mergeMailBatchEntry(batch, item)
        end
    end

    return batch
end

local function buildMailBatch(entry)
    local optionalCategory = entry.Category or entry.category
    local items = entry.Items or entry.items

    if type(items) == "table" then
        return buildMailBatchFromItems(items, optionalCategory)
    end

    local itemKey = entry.Item or entry.ItemKey or entry.item
    if type(itemKey) ~= "string" or itemKey == "" then
        return {}
    end

    return resolveMailItems(itemKey, entry.Count or entry.Amount or entry.amount, optionalCategory)
end

local function trySendMail()
    local mailConfig = getgenv().Config
    if mailConfig["Auto Send Mail"] == false then return end
    if isSendingMail then return end
    if os.clock() - lastMailTime < COOLDOWN.Mail then return end

    if API.tryCompleteTutorial then
        API.tryCompleteTutorial()
    end

    local sheckles = API.getSheckles and API.getSheckles() or 0
    if sheckles < MAIL_MIN_SHECKLES then return end

    local plantCount = API.getTotalPlantCount and API.getTotalPlantCount() or 0
    if plantCount < MIN_PLANTS_SAFE then return end

    local list = mailConfig["Mail To Send"]
    if type(list) ~= "table" then return end

    for key, entry in list do
        if type(entry) ~= "table" then continue end

        local username
        if type(key) == "string" then
            username = key
        else
            username = entry.Username or entry.username
        end

        local note = entry.Note or entry.note or ""
        if type(username) ~= "string" or username == "" then continue end

        local batch = buildMailBatch(entry)
        if #batch == 0 then continue end

        local userId = lookupMailUserId(username)
        if not userId then
            warn("[Gag2 Mail] Not Found:", username)
            continue
        end

        local chunks = splitMailBatch(batch, MAIL_MAX_PER_GIFT)
        isSendingMail = true
        lastMailTime = os.clock()

        task.spawn(function()
            local sent = 0
            for i, chunk in chunks do
                local ok, err = sendMailBatch(userId, chunk, note)
                if ok then
                    sent += 1
                    local totalCount = 0
                    for _, item in chunk do
                        totalCount += item.Count or 1
                    end
                    print(string.format("[Gag2 Mail] Send %d item -> %s (batch %d/%d)", totalCount, username, i, #chunks))
                else
                    warn(string.format("[Gag2 Mail] Failed Send -> %s: %s", username, tostring(err)))
                    break
                end
                if i < #chunks then
                    task.wait(MAIL_SEND_GAP)
                end
            end
            if sent > 0 then
                lastCacheTime = 0
            end
            isSendingMail = false
        end)
        return
    end
end

API.trySendMail = trySendMail
end

local function bootstrapPets()

local function parsePetConfigList(configList)
    local parsed = {}
    for key, value in configList do
        local name, limit

        if type(key) == "number" and type(value) == "string" then
            name = value
            limit = nil
        elseif type(key) == "string" then
            name = key
            if type(value) == "number" and value > 0 then
                limit = math.floor(value)
            elseif type(value) == "table" then
                name = value.Pet or value.Name or value.Item or key
                local amount = value.Count or value.Limit or value.Amount or value.amount
                if type(amount) == "number" and amount > 0 then
                    limit = math.floor(amount)
                end
            else
                limit = nil
            end
        else
            continue
        end

        if type(name) ~= "string" or name == "" then continue end
        parsed[#parsed + 1] = { name = name, limit = limit }
    end
    return parsed
end

local function refreshPetsToCatchList()
    table.clear(petsToCatchList)
    for petName, amount in BuyPet do
        if type(petName) == "string" then
            local limit = (type(amount) == "number" and amount > 0) and amount or nil
            petsToCatchList[#petsToCatchList + 1] = { name = petName, limit = limit }
        end
    end
end

local function refreshPetsToEquipList()
    table.clear(petsToEquipList)

    if #EquipPet > 0 then
        local sorted = {}
        for _, entry in ipairs(EquipPet) do
            if type(entry) == "table" and #entry >= 2 then
                sorted[#sorted + 1] = {
                    name = entry[1],
                    limit = entry[2],
                    priority = entry[3] or 999,
                }
            end
        end
        table.sort(sorted, function(a, b) return a.priority < b.priority end)
        for _, entry in ipairs(sorted) do
            petsToEquipList[#petsToEquipList + 1] = entry
        end
        return
    end
end

refreshPetsToCatchList()
refreshPetsToEquipList()

local function httpRequest(options)
    local fn = syn and syn.request or http and http.request or request
    if not fn then return nil end
    return fn(options)
end

local function extractAssetId(value)
    if type(value) == "number" and value > 0 then
        return math.floor(value)
    end
    if type(value) ~= "string" or value == "" then
        return nil
    end
    local id = string.match(value, "rbxassetid://(%d+)") or string.match(value, "(%d+)")
    return id and tonumber(id) or nil
end

local function resolvePetSpeciesKey(species)
    if type(species) ~= "string" or species == "" then return nil end
    if type(PetData[species]) == "table" then return species end

    local compact = string.gsub(species, "%s+", "")
    if type(PetData[compact]) == "table" then return compact end

    for key, spec in PetData do
        if type(spec) == "table" and spec.DisplayName == species then
            return key
        end
    end

    return species
end

local function getPetIconAssetId(species)
    local key = resolvePetSpeciesKey(species)
    if not key then return nil end
    local spec = PetData[key]
    if type(spec) ~= "table" then return nil end
    return extractAssetId(spec.Image or spec.IconId or spec.Icon or spec.iconId)
end

local function getPetImageUrl(assetId)
    assetId = tonumber(assetId)
    if not assetId or assetId <= 0 then return nil end

    local thumbUrl = "https://thumbnails.roblox.com/v1/assets?assetIds=" .. assetId
        .. "&returnPolicy=PlaceHolder&size=420x420&format=png"

    local response = httpRequest({
        Url = thumbUrl,
        Method = "GET",
        Headers = {
            ["Content-Type"] = "application/json",
        },
    })
    if response and response.StatusCode == 200 then
        local ok, responseData = pcall(HttpService.JSONDecode, HttpService, response.Body)
        if ok and type(responseData) == "table" then
            local data = responseData.data
            if type(data) == "table" and data[1] and data[1].imageUrl then
                return data[1].imageUrl
            end
        end
    end

    local ok, body = pcall(HttpService.GetAsync, HttpService, thumbUrl)
    if ok and type(body) == "string" and body ~= "" then
        local decodedOk, responseData = pcall(HttpService.JSONDecode, HttpService, body)
        if decodedOk and type(responseData) == "table" then
            local data = responseData.data
            if type(data) == "table" and data[1] and data[1].imageUrl then
                return data[1].imageUrl
            end
        end
    end

    return "https://www.roblox.com/asset-thumbnail/image?assetId="
        .. assetId .. "&width=420&height=420&format=png"
end

local function getPetRarity(species)
    local key = resolvePetSpeciesKey(species)
    if not key then return "Common" end
    local spec = PetData[key]
    if type(spec) == "table" and type(spec.Rarity) == "string" then
        return spec.Rarity
    end
    return "Common"
end

local function formatWebhookNumber(value)
    value = tonumber(value) or 0
    if value >= 1e9 then
        local v = value / 1e9
        return (v == math.floor(v) and string.format("%dB", v) or string.format("%gB", v))
    end
    if value >= 1e6 then
        local v = value / 1e6
        return (v == math.floor(v) and string.format("%dM", v) or string.format("%gM", v))
    end
    if value >= 1e3 then
        local v = value / 1e3
        return (v == math.floor(v) and string.format("%dK", v) or string.format("%gK", v))
    end
    return tostring(math.floor(value))
end

local function buildCaughtPetLabel(info)
    local label = info.displayName or info.species or "Unknown"
    if info.type == PetTypes.Rainbow or info.rainbow == true then
        label = "Rainbow " .. label
    end
    if type(info.size) == "string" and info.size ~= "" and info.size ~= "Normal" then
        label = label .. " [" .. info.size .. "]"
    end
    return label
end

local function sendPetCatchWebhook(info)
    local webhookCfg = Config["Pet Catch Webhook"]
    if type(webhookCfg) ~= "table" or webhookCfg.Enabled == false then return end
    local url = webhookCfg.Url
    if type(url) ~= "string" or url == "" then return end

    local petName = buildCaughtPetLabel(info)
    local rarity = getPetRarity(info.species)
    local imageUrl = getPetImageUrl(getPetIconAssetId(info.species))
    local sheckles = API.getSheckles and API.getSheckles() or 0
    local mention = webhookCfg.Mention
    local content = type(mention) == "string" and mention ~= "" and (mention .. petName) or nil

    local embed = {
        title = "Grow A Garden 2",
        color = 0x09FFF8,
        fields = {
            {
                name = "Username:",
                value = "Account: ||" .. LocalPlayer.Name .. "||\nSheckles: " .. formatWebhookNumber(sheckles),
            },
            {
                name = "Pet:",
                value = "```\n" .. petName .. "```",
            },
            {
                name = "Rarity:",
                value = "```\n" .. rarity .. "```",
            },
            {
                name = "Mutation:",
                value = "```\n" .. (info.size or "Normal") .. "```",
            },
        },
        footer = {
            text = webhookCfg.Note or "Gag2",
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }

    if imageUrl then
        embed.thumbnail = { url = imageUrl }
    end

    local payload = {
        username = "Pet Webhook",
        embeds = { embed },
    }
    if content then
        payload.content = content
    end

    pcall(function()
        httpRequest({
            Url = url,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
            },
            Body = HttpService:JSONEncode(payload),
        })
    end)
end

getgenv().sendSeedPackWebhook = function(seedType)
    local wh = Config["Seed Pack Webhook"]
    if type(wh) ~= "table" or wh.Enabled == false then return end
    local url = wh.Url
    if type(url) ~= "string" or url == "" then return end

    local sheckles = API.getSheckles and API.getSheckles() or 0
    local embed = {
        title = "Grow A Garden 2",
        color = 0xFFD700,
        fields = {
            {
                name = "Username:",
                value = "Account: ||" .. LocalPlayer.Name .. "||\nSheckles: " .. formatWebhookNumber(sheckles),
                inline = false,
            },
            {
                name = "Seed Pack:",
                value = "```\n" .. seedType .. " Seed```",
                inline = false,
            },
        },
        footer = { text = wh.Note or "Gag2" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }

    local payload = {
        username = "Seed Pack Webhook",
        embeds = { embed },
    }

    pcall(function()
        httpRequest({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload),
        })
    end)
end

local function getPetSizeRank(size)
    local normalized = PetSizes.Normalize(size)
    if normalized == "Huge" then return 3 end
    if normalized == "Big" then return 2 end
    return 1
end

local function getMaxEquippedPets()
    local max = LocalPlayer:GetAttribute("MaxEquippedPets")
    if type(max) == "number" and max > 0 then return math.floor(max) end
    return PetSlotPrices.BaseMax or 3
end

local function getPetsBucket()
    if not PlayerReplica or not PlayerReplica.Data then return nil end
    local inventory = PlayerReplica.Data.Inventory
    if type(inventory) ~= "table" then return nil end
    local bucket = inventory.Pets
    if type(bucket) ~= "table" then return nil end
    return bucket
end

local function getCountBasedPetOwned(species)
    local bucket = getPetsBucket()
    if not bucket or type(species) ~= "string" then return 0 end
    local amount = bucket[species]
    if type(amount) == "number" and amount > 0 then return amount end
    return 0
end

local function resolveCountBasedSpeciesKey(targetName)
    local bucket = getPetsBucket()
    if not bucket or type(targetName) ~= "string" then return targetName end
    if getCountBasedPetOwned(targetName) > 0 then return targetName end
    for key, entry in bucket do
        if type(key) == "string" and type(entry) == "number" and entry > 0 then
            if API.matchesTargetName(key, nil, targetName) then
                return key
            end
        end
    end
    return targetName
end

local ownedPetsCache = nil
local ownedPetsCacheTime = 0
local OWNED_PETS_CACHE_TTL = 1

local function getAllOwnedPets()
    local now = os.clock()
    if ownedPetsCache and now - ownedPetsCacheTime < OWNED_PETS_CACHE_TTL then
        return ownedPetsCache
    end

    local pets = {}
    local bucket = getPetsBucket()
    if not bucket then return pets end

    for key, entry in bucket do
        if type(entry) == "table" and type(entry.Name) == "string" then
            pets[#pets + 1] = {
                Id = entry.Id or key,
                Name = entry.Name,
                Type = entry.Type,
                Size = entry.Size,
                Equipped = entry.Equipped == true,
                CountBased = false,
            }
        end
    end
    ownedPetsCache = pets
    ownedPetsCacheTime = now
    return pets
end

local function getOwnedPetCount(targetName)
    local count = 0
    for _, pet in getAllOwnedPets() do
        if API.matchesTargetName(pet.Name, pet.Size, targetName) then
            count += 1
        end
    end
    if count > 0 then return count end

    if not PlayerReplica or not PlayerReplica.Data then return 0 end
    local bucket = PlayerReplica.Data.Inventory and PlayerReplica.Data.Inventory.Pets
    if type(bucket) ~= "table" then return 0 end
    return tonumber(bucket[targetName]) or 0
end

local function matchesEquipTarget(petName, petSize)
    for _, entry in petsToEquipList do
        if API.matchesTargetName(petName, petSize, entry.name) then
            return true, entry
        end
    end
    return false
end

local function getPetCatchLimit(targetName)
    for _, entry in petsToCatchList do
        if entry.name == targetName or API.matchesTargetName(entry.name, nil, targetName) then
            return entry.limit
        end
    end
    return nil
end

local function needsMorePet(targetName)
    local limit = getPetCatchLimit(targetName)
    if type(limit) ~= "number" then return true end
    return getOwnedPetCount(targetName) < limit
end

local function getPetEquipListPriority(petName, petSize)
    for i, entry in petsToEquipList do
        if API.matchesTargetName(petName, petSize, entry.name) then
            return i
        end
    end
    return 9999
end

local function getPetPowerScore(pet)
    local listPri = getPetEquipListPriority(pet.Name, pet.Size)
    local typeScore = (pet.Type == PetTypes.Rainbow) and 1000 or 0
    local sizeScore = getPetSizeRank(pet.Size) * 100
    return -listPri * 1000000 + typeScore + sizeScore
end

local function getEquippedPetEntries()
    local ok, list = pcall(function()
        return Net.Pets.GetEquippedPets:Fire()
    end)
    if not ok or type(list) ~= "table" then return {} end

    local entries = {}
    for _, pet in list do
        if type(pet) == "table" and (type(pet.Id) == "string" or type(pet.Name) == "string") then
            entries[#entries + 1] = pet
        end
    end
    return entries
end

local function getDeployedPetIds()
    local ids = {}
    for _, pet in getEquippedPetEntries() do
        if type(pet.Id) == "string" then
            ids[pet.Id] = true
        end
    end
    return ids
end

local function isIdPetAvailable(pet)
    if pet.Equipped == true then return false end
    local deployed = getDeployedPetIds()
    return not deployed[pet.Id]
end

local function getEquippedPetMap()
    local equipped = {}
    local count = 0
    for _, pet in getEquippedPetEntries() do
        if type(pet.Name) == "string" then
            equipped[pet.Name] = true
            count += 1
        end
    end
    return equipped, count
end

local function getEquippedCountForTarget(targetName)
    local count = 0
    for _, pet in getEquippedPetEntries() do
        if API.matchesTargetName(pet.Name, pet.Size, targetName) then
            count += 1
        end
    end
    return count
end

local function hasUnequippedTarget(targetName)
    for _, pet in getAllOwnedPets() do
        if isIdPetAvailable(pet) and API.matchesTargetName(pet.Name, pet.Size, targetName) then
            return true
        end
    end

    local speciesKey = resolveCountBasedSpeciesKey(targetName)
    local owned = getCountBasedPetOwned(speciesKey)
    if owned <= 0 then return false end

    return getEquippedCountForTarget(speciesKey) < owned
end

local function shouldPriorityEquip(entry)
    local targetName = entry.name
    local limit = entry.limit
    local equipped = getEquippedCountForTarget(targetName)

    if type(limit) == "number" then
        if equipped >= limit then return false end
    elseif equipped > 0 then
        return false
    end

    return hasUnequippedTarget(targetName)
end

local function getDeployedPetForSpecies(speciesKey)
    for _, pet in getEquippedPetEntries() do
        if API.matchesTargetName(pet.Name, pet.Size, speciesKey) then
            return pet
        end
    end
    return nil
end

local function isPetIdDeployed(petId)
    if type(petId) ~= "string" or petId == "" then return false end
    for _, pet in getEquippedPetEntries() do
        if pet.Id == petId then return true end
    end
    return false
end

local function getPetScoreById(petId)
    for _, pet in getAllOwnedPets() do
        if pet.Id == petId then
            return getPetPowerScore(pet)
        end
    end
    return nil
end

local function shouldDeployPet(petName, petId)
    local speciesKey = resolveCountBasedSpeciesKey(petName)

    if petId and isPetIdDeployed(petId) then
        return false
    end

    local deployed = getDeployedPetForSpecies(speciesKey)
    if not deployed then
        return true
    end

    local newScore
    if petId then
        newScore = getPetScoreById(petId)
    else
        newScore = getPetPowerScore({ Name = speciesKey, Type = nil, Size = nil })
    end
    if type(newScore) ~= "number" then return false end

    local deployedScore = getPetPowerScore({
        Name = deployed.Name,
        Type = deployed.Type,
        Size = deployed.Size,
    })
    return newScore > deployedScore
end

local function findBestUpgrade(minScore)
    minScore = minScore or -math.huge
    local best, bestScore = nil, minScore

    for _, pet in getAllOwnedPets() do
        if isIdPetAvailable(pet) and matchesEquipTarget(pet.Name, pet.Size) then
            local score = getPetPowerScore(pet)
            if score > bestScore then
                bestScore = score
                best = {
                    Name = pet.Name,
                    Id = pet.Id,
                    Type = pet.Type,
                    Size = pet.Size,
                    score = score,
                    countBased = false,
                }
            end
        end
    end

    local bucket = getPetsBucket()
    if bucket then
        for key, entry in bucket do
            if type(key) == "string" and type(entry) == "number" and entry > 0 then
                local inList, equipEntry = matchesEquipTarget(key, nil)
                if not inList then continue end

                local limit = equipEntry and equipEntry.limit
                local maxEquip = type(limit) == "number" and limit or 1
                if getEquippedCountForTarget(key) >= maxEquip then continue end
                if getDeployedPetForSpecies(key) then continue end

                local score = getPetPowerScore({ Name = key, Type = nil, Size = nil })
                if score > bestScore then
                    bestScore = score
                    best = {
                        Name = key,
                        score = score,
                        countBased = true,
                    }
                end
            end
        end
    end

    return best, bestScore
end

local function findDeployPetId(petName)
    local speciesKey = resolveCountBasedSpeciesKey(petName)
    local bestId, bestScore = nil, -math.huge

    for _, pet in getAllOwnedPets() do
        if isIdPetAvailable(pet) and API.matchesTargetName(pet.Name, pet.Size, speciesKey) then
            local score = getPetPowerScore(pet)
            if score > bestScore then
                bestScore = score
                bestId = pet.Id
            end
        end
    end

    return bestId, speciesKey
end

local function findPetTool(petId, speciesKey)
    local function matchesTool(tool)
        if not tool:IsA("Tool") then return false end
        local toolPet = tool:GetAttribute("Pet")
        local toolId = tool:GetAttribute("PetId")
        if toolPet == nil and toolId == nil then return false end
        if petId and type(toolId) == "string" and toolId == petId then return true end
        if speciesKey and type(toolPet) == "string" and API.matchesTargetName(toolPet, tool:GetAttribute("PetSize"), speciesKey) then
            return true
        end
        return false
    end

    local function scan(container)
        if not container then return nil end
        for _, item in container:GetChildren() do
            if matchesTool(item) then return item end
        end
        return nil
    end

    local char = LocalPlayer.Character
    return scan(char) or scan(LocalPlayer:FindFirstChild("Backpack"))
end

local function deployPetFollower(speciesKey, petId)
    if not shouldDeployPet(speciesKey, petId) then return end

    local deadline = os.clock() + 5
    local tool = nil

    while os.clock() < deadline do
        tool = findPetTool(petId, speciesKey)
        if tool then break end
        task.wait(0.1)
    end

    local toggleId = petId
    if tool then
        local waited = os.clock() + 1.5
        while os.clock() < waited do
            local toolId = tool:GetAttribute("PetId")
            if type(toolId) == "string" and toolId ~= "" then
                toggleId = toolId
                break
            end
            task.wait(0.1)
        end

        local char = LocalPlayer.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if humanoid and tool.Parent ~= char then
            humanoid:EquipTool(tool)
            task.wait(0.35)
        end

        local toolId = tool:GetAttribute("PetId")
        if type(toolId) == "string" and toolId ~= "" then
            toggleId = toolId
            tool:Activate()
            task.wait(0.2)
        end
    end

    if type(toggleId) ~= "string" or toggleId == "" then
        toggleId = speciesKey
    end

    if isPetIdDeployed(toggleId) then return end
    local deployed = getDeployedPetForSpecies(speciesKey)
    if deployed and (not petId or deployed.Id == petId) then return end

    Net.Pets.RequestToggleFollower:Fire(toggleId)
    ownedPetsCache = nil

    task.wait(0.25)
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if humanoid then
    end
end

local function requestEquipPet(petName, petId)
    if isDeployingPet then return end
    if not shouldDeployPet(petName, petId) then return end

    local deployId, speciesKey = petId, resolveCountBasedSpeciesKey(petName)
    if not deployId then
        deployId = findDeployPetId(petName)
    end

    isDeployingPet = true
    Net.Pets.RequestEquipByName:Fire(speciesKey)
    ownedPetsCache = nil

    task.spawn(function()
        deployPetFollower(speciesKey, deployId)
        isDeployingPet = false
    end)
end

local function tryEquipPetsInOrder()
    if Config["Auto Equip Pets"] == false then return end
    if isDeployingPet then return end
    if #petsToEquipList == 0 then return end
    if os.clock() - lastPetEquipTime < COOLDOWN.PetEquip then return end

    local _, equippedCount = getEquippedPetMap()
    if equippedCount >= getMaxEquippedPets() then return end

    for _, entry in petsToEquipList do
        if not shouldPriorityEquip(entry) then continue end

        local deployId = findDeployPetId(entry.name)
        if not shouldDeployPet(entry.name, deployId) then continue end

        lastPetEquipTime = os.clock()
        requestEquipPet(entry.name, deployId)
        return
    end
end

local function tryOptimizeEquippedPets()
    if Config["Auto Optimize Pets"] == false then return end
    if isDeployingPet then return end
    if os.clock() - lastPetOptimizeTime < COOLDOWN.PetOptimize then return end
    if os.clock() - lastPetEquipTime < COOLDOWN.PetEquip then return end

    lastPetOptimizeTime = os.clock()

    local maxSlots = getMaxEquippedPets()
    local equippedEntries = getEquippedPetEntries()

    if #equippedEntries == 0 then
        tryEquipPetsInOrder()
        return
    end

    if #equippedEntries < maxSlots then
        tryEquipPetsInOrder()
        return
    end

    local equippedScored = {}
    for _, pet in equippedEntries do
        equippedScored[#equippedScored + 1] = {
            id = pet.Id,
            name = pet.Name,
            type = pet.Type,
            size = pet.Size,
            score = getPetPowerScore({
                Name = pet.Name,
                Type = pet.Type,
                Size = pet.Size,
            }),
        }
    end

    table.sort(equippedScored, function(a, b)
        return a.score < b.score
    end)

    local worst = equippedScored[1]
    if not worst then return end

    local upgrade, upgradeScore = findBestUpgrade(worst.score)
    if not upgrade or upgradeScore <= worst.score then return end

    lastPetEquipTime = os.clock()

    if worst.id then
        Net.Pets.RequestUnequip:Fire(worst.id)
        ownedPetsCache = nil
    elseif worst.name then
        Net.Pets.RequestUnequipByName:Fire(worst.name)
        ownedPetsCache = nil
    else
        return
    end

    task.delay(0.45, function()
        requestEquipPet(upgrade.Name, upgrade.Id)
    end)
end

local function tryUpgradePetSlots()
    if Config["Auto Upgrade Pet Slots"] == false then return end
    if os.clock() - lastPetSlotUpgradeTime < COOLDOWN.PetSlotUpgrade then return end

    local maxSlots = getMaxEquippedPets()
    if maxSlots >= PetSlotPrices.AbsoluteMax then return end
    if type(MaxPetSlots) == "number" and maxSlots >= MaxPetSlots then return end

    local price = PetSlotPrices.GetNextPrice(maxSlots)
    if type(price) ~= "number" then return end

    local sheckles = API.getSheckles and API.getSheckles() or 0
    if sheckles < price then return end

    lastPetSlotUpgradeTime = os.clock()
    Net.Pets.RequestPurchasePetSlot:Fire()
end

local function resolveRefPartFromModel(model)
    if not model or not model:IsA("Model") or not WildPetFolder then return nil end
    local refName = string.match(model.Name, "^WildPet_.-_(.+)$")
    if not refName then return nil end
    local ref = WildPetFolder:FindFirstChild(refName)
    if ref and ref:IsA("BasePart") then return ref end
    return nil
end

local function getModelRoot(model)
    return model.PrimaryPart or model:FindFirstChild("RootPart") or model:FindFirstChildWhichIsA("BasePart")
end

local function isRefTameable(refPart)
    if not refPart or not refPart:IsA("BasePart") or not refPart.Parent then return false end
    local ownerId = refPart:GetAttribute("OwnerUserId")
    if ownerId == LocalPlayer.UserId then return false end
    if type(ownerId) == "number" and ownerId ~= 0 then return false end
    local price = refPart:GetAttribute("Price")
    if type(price) == "number" and (API.getSheckles and API.getSheckles() or 0) < price then return false end
    return true
end

local function pickBestWildPet(candidates)
    table.sort(candidates, function(a, b)
        if a.rainbow ~= b.rainbow then return a.rainbow end
        if a.sizeRank ~= b.sizeRank then return a.sizeRank > b.sizeRank end
        return a.price < b.price
    end)
    return candidates[1]
end

local function returnToPlot(hrp, savedPos)
    if not hrp or not hrp.Parent then return end
    local centerCf = API.getPlotCenterCFrame()
    if centerCf then
        hrp.CFrame = centerCf
    else
        hrp.CFrame = savedPos
    end
end

local function tryCatchPet()
    if Config["Auto Catch Pet"] == false then return end
    if isCatchingPet then return end
    if os.clock() - lastPetCatchTime < COOLDOWN.PetCatch then return end
    if not WildPetSpawns then return end

    if #petsToCatchList > 0 then
        for _, model in WildPetSpawns:GetChildren() do
            if not model:IsA("Model") then continue end
            local species = model:GetAttribute("PetName")
            local size = model:GetAttribute("PetSize")
            local wanted = false
            for _, entry in petsToCatchList do
                if API.matchesTargetName(species, size, entry.name) then
                    wanted = true
                    break
                end
            end
            if not wanted then model:Destroy() end
        end
    end

    if #petsToCatchList == 0 then return end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for _, entry in petsToCatchList do
        local petName = entry.name
        if not needsMorePet(petName) then continue end

        local candidates = {}

        for _, model in WildPetSpawns:GetChildren() do
            if not model:IsA("Model") then continue end
            local species = model:GetAttribute("PetName")
            local size = model:GetAttribute("PetSize")
            if not API.matchesTargetName(species, size, petName) then continue end

            local ref = resolveRefPartFromModel(model)
            if not ref or not isRefTameable(ref) then continue end

            candidates[#candidates + 1] = {
                ref = ref,
                model = model,
                sizeRank = getPetSizeRank(model:GetAttribute("PetSize")),
                rainbow = model:GetAttribute("PetType") == "Rainbow",
                price = ref:GetAttribute("Price") or 0,
            }
        end

        if #candidates > 0 then
            local best = pickBestWildPet(candidates)
            local ref = best.ref
            local model = best.model
            if not ref or not ref.Parent or not model then return end

            local key = tostring(ref)
            local now = os.clock()
            if petCatchCooldown[key] and now - petCatchCooldown[key] < COOLDOWN.PetCatch then return end

            petCatchCooldown[key] = now
            lastPetCatchTime = now
            isCatchingPet = true

            local species = model:GetAttribute("PetName")
            local petSize = model:GetAttribute("PetSize")
            local petType = model:GetAttribute("PetType")
            local catchInfo = {
                species = species,
                size = petSize,
                type = petType,
                rainbow = petType == "Rainbow",
                displayName = API.getPetDisplayName(species, petSize),
            }

            task.spawn(function()
                local savedPos = hrp.CFrame
                local root = getModelRoot(model)
                if root then
                    hrp.CFrame = CFrame.new(root.Position + Vector3.new(0, 3, 0))
                end
                task.wait(0.35)

                local tameDone = false
                local resultConn
                if Net.Pets.WildPetTameResult and Net.Pets.WildPetTameResult.OnClientEvent then
                    resultConn = Net.Pets.WildPetTameResult.OnClientEvent:Connect(function(_, userId)
                        if userId == LocalPlayer.UserId then
                            tameDone = true
                        end
                    end)
                end

                Net.Pets.WildPetTame:Fire(ref)

                local deadline = os.clock() + 2.5
                while not tameDone and os.clock() < deadline do
                    task.wait(0.1)
                end

                if resultConn then
                    resultConn:Disconnect()
                end

                if tameDone then
                    ownedPetsCache = nil
                    sendPetCatchWebhook(catchInfo)
                end

                task.wait(0.2)
                returnToPlot(hrp, savedPos)
                isCatchingPet = false
            end)
            return
        end
    end
end

API.tryCatchPet = tryCatchPet
API.tryEquipPetsInOrder = tryEquipPetsInOrder
API.tryOptimizeEquippedPets = tryOptimizeEquippedPets
API.tryUpgradePetSlots = tryUpgradePetSlots
local function getEquippedPetCount()
    local _, count = getEquippedPetMap()
    return count
end
API.getEquippedPetCount = getEquippedPetCount
API.getMaxEquippedPets = getMaxEquippedPets
end

bootstrapShared()
bootstrapGarden()
bootstrapMail()
bootstrapPets()

task.spawn(function()
    task.wait(0.5)
    API.redeemCodesOnce()
end)

local function bootstrapStatsUI()
    local Lighting = game:GetService("Lighting")
    local blur = Lighting:FindFirstChild("Gag2StatsBlur")
    if not blur then
        blur = Instance.new("BlurEffect"); blur.Name = "Gag2StatsBlur"
        blur.Size = 12; blur.Parent = Lighting
    end

    local guiParent = game:GetService("CoreGui")
    if typeof(gethui) == "function" then
        local ok, h = pcall(gethui); if ok and h then guiParent = h end
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "Gag2Stats"; gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true; gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    gui.DisplayOrder = 9999; gui.Parent = guiParent
    pcall(function() syn.protect_gui(gui) end)

    local root = Instance.new("Frame")
    root.Name = "Root"; root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = UDim2.fromScale(0.5, 0.5); root.Size = UDim2.fromScale(1, 1)
    root.BackgroundTransparency = 1; root.BorderSizePixel = 0; root.Parent = gui

    local uiScale = Instance.new("UIScale"); uiScale.Parent = root

    local panel = Instance.new("Frame")
    panel.Name = "Panel"; panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.new(0, 360, 0, 0); panel.AutomaticSize = Enum.AutomaticSize.Y
    panel.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
    panel.BackgroundTransparency = 0.25; panel.BorderSizePixel = 0; panel.Parent = root

    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke", panel)
    stroke.Color = Color3.fromRGB(255, 255, 255); stroke.Transparency = 0.75; stroke.Thickness = 1

    local pad = Instance.new("UIPadding", panel)
    pad.PaddingTop = UDim.new(0, 8); pad.PaddingBottom = UDim.new(0, 8)
    pad.PaddingLeft = UDim.new(0, 12); pad.PaddingRight = UDim.new(0, 12)

    local layout = Instance.new("UIListLayout", panel)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center; layout.Padding = UDim.new(0, 2)

    local function mkLabel(order, size, color)
        local l = Instance.new("TextLabel")
        l.LayoutOrder = order; l.Size = UDim2.new(1, 0, 0, 20)
        l.BackgroundTransparency = 1; l.Font = Enum.Font.SourceSansBold
        l.TextSize = size; l.TextColor3 = color or Color3.fromRGB(255, 255, 255)
        l.TextStrokeTransparency = 0.35; l.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        l.TextXAlignment = Enum.TextXAlignment.Center; l.TextYAlignment = Enum.TextYAlignment.Center
        l.RichText = true; l.ZIndex = 2; l.Parent = panel
        return l
    end

    local lblMoney  = mkLabel(1, 20); local lblPets  = mkLabel(2, 20)
    local lblPlants = mkLabel(3, 20); local lblFruit = mkLabel(4, 20)
    local lblRainbow = mkLabel(5, 20, Color3.fromRGB(190, 120, 255))
    local lblGold    = mkLabel(6, 20, Color3.fromRGB(255, 215, 0))
    local lblPhase  = mkLabel(7, 16, Color3.fromRGB(150, 160, 180))

    local SharedModules = ReplicatedStorage:FindFirstChild("SharedModules")
    local TimeCycleData = SharedModules and SharedModules:FindFirstChild("TimeCycleData") and require(SharedModules.TimeCycleData)
    local phases, nightPhase, CYCLE_LEN, SERVER_OFFSET, moonQueue = {}, nil, 0, nil, {}

    if TimeCycleData and TimeCycleData.Data then
        for name, data in pairs(TimeCycleData.Data) do
            table.insert(phases, { Name = name, Weathers = data.Weathers, Duration = data.Lasts, Order = data.StartOrder })
        end
        table.sort(phases, function(a, b) return a.Order < b.Order end)
        for _, p in ipairs(phases) do
            CYCLE_LEN = CYCLE_LEN + (tonumber(p.Duration) or 0)
            if p.Name == "Night" then nightPhase = p end
        end
        if CYCLE_LEN <= 0 then CYCLE_LEN = 600 end

        do -- calibrate offset
            local samples = {}
            for i = 1, 5 do
                local t1, s, t2 = os.time(), workspace:GetServerTimeNow(), os.time()
                if t1 == t2 then samples[#samples+1] = t1 - s end
                task.wait(0.05)
            end
            if #samples > 0 then
                local sum = 0; for _, v in ipairs(samples) do sum = sum + v end
                SERVER_OFFSET = math.round(sum / #samples)
            else
                SERVER_OFFSET = math.round(os.time() - workspace:GetServerTimeNow())
            end
        end
    end

    local function pickMoon(seed)
        if not nightPhase then return "Moon" end
        local rng = Random.new(seed); local total = 0
        for _, w in pairs(nightPhase.Weathers) do total = total + (w.Chance or 0) end
        if total <= 0 then return "Moon" end
        local roll = rng:NextNumber() * total; local acc = 0
        for name, w in pairs(nightPhase.Weathers) do
            acc = acc + (w.Chance or 0)
            if roll <= acc then return name end
        end
        for name in pairs(nightPhase.Weathers) do return name end
        return "Moon"
    end

    local function fmt(sec)
        sec = math.max(0, math.floor(sec + 0.5))
        local h = math.floor(sec / 3600); local mn = math.floor((sec % 3600) / 60); local s = sec % 60
        if h > 0 then return string.format("%dh %02dm %02ds", h, mn, s) end
        if mn > 0 then return string.format("%dm %02ds", mn, s) end
        return string.format("%ds", s)
    end

    local function abbrev(amount)
        amount = math.floor(tonumber(amount) or 0)
        if amount >= 1000000000 then local v = math.floor(amount/1000000000*10+0.5)/10; return (v==math.floor(v) and string.format("%dB",v) or string.format("%gB",v)) end
        if amount >= 1000000 then local v = math.floor(amount/1000000*10+0.5)/10; return (v==math.floor(v) and string.format("%dM",v) or string.format("%gM",v)) end
        if amount >= 1000 then local v = math.floor(amount/1000*10+0.5)/10; return (v==math.floor(v) and string.format("%dK",v) or string.format("%gK",v)) end
        return tostring(amount)
    end

    local function updateScale()
        local cam = workspace.CurrentCamera; if not cam then return end
        local base = math.min(cam.ViewportSize.X, cam.ViewportSize.Y) / 720
        uiScale.Scale = math.clamp(base, 0.7, 2)
    end
    local cam = workspace.CurrentCamera or workspace:WaitForChild("Camera")
    cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale); updateScale()

    task.spawn(function()
        local sched, now, phaseEnd = {}, 0, 0
        while gui.Parent do
            local money = API.getSheckles and API.getSheckles() or 0
            local equipped = API.getEquippedPetCount and API.getEquippedPetCount() or 0
            local maxPets = API.getMaxEquippedPets and API.getMaxEquippedPets() or 0
            local plants = API.getTotalPlantCount and API.getTotalPlantCount() or 0
            local fruit = LocalPlayer:GetAttribute("FruitCount") or 0

            local folder = SeedPackSpawns
            if not folder then
                local map = workspace:FindFirstChild("Map")
                if map then folder = map:FindFirstChild("SeedPackSpawnServerLocations") end
            end
            local rainbowPack, goldPack = false, false
            if folder then
                for _, sp in folder:GetChildren() do
                    if sp:GetAttribute("RainbowSeed") == true then
                        local p = sp:FindFirstChildWhichIsA("ProximityPrompt", true)
                        if p and p.Parent then rainbowPack = true end
                    elseif sp:GetAttribute("GoldSeed") == true then
                        local p = sp:FindFirstChildWhichIsA("ProximityPrompt", true)
                        if p and p.Parent then goldPack = true end
                    end
                end
            end

            local phase = workspace:GetAttribute("ActivePhase")
            local weather = workspace:GetAttribute("ActiveWeather")
            local phaseEndT = workspace:GetAttribute("PhaseDuration")

            if SERVER_OFFSET and nightPhase and phase and phaseEndT then
                now = workspace:GetServerTimeNow()
                phaseEnd = phaseEndT
                table.clear(moonQueue)
                local ci; for i, p in ipairs(phases) do if p.Name == phase then ci = i end end
                if ci then
                    if phase == "Night" then
                        local startT = phaseEnd - nightPhase.Duration
                        local moon = pickMoon(math.floor((startT + SERVER_OFFSET) / CYCLE_LEN) * 1000 + ci)
                        moonQueue[1] = { start = startT, moon = moon, away = startT - now, current = true }
                    end
                    local t = phaseEnd; local idx = ci; local guard = 0
                    while #moonQueue < 50 and guard < 5000 do
                        guard = guard + 1; idx = idx + 1
                        if idx > #phases then idx = 1 end
                        local p = phases[idx]
                        if p.Name == "Night" then
                            local moon = pickMoon(math.floor((t + SERVER_OFFSET) / CYCLE_LEN) * 1000 + idx)
                            moonQueue[#moonQueue+1] = { start = t, moon = moon, away = t - now }
                        end
                        t = t + p.Duration
                    end
                end
            end

            local function firstMoon(key)
                for _, n in ipairs(moonQueue) do if n.moon == key and (n.away or 0) > 0 then return n end end
            end

            local rainbowMoon = firstMoon("Rainbow Moon") or firstMoon("Rainbow")
            local goldMoon = firstMoon("Goldmoon")
            local isRainbowNow = phase == "Night" and moonQueue[1] and (moonQueue[1].moon == "Rainbow Moon" or moonQueue[1].moon == "Rainbow")
            local isGoldNow = phase == "Night" and moonQueue[1] and moonQueue[1].moon == "Goldmoon"

            lblMoney.Text = "Sheckles: " .. abbrev(money)
            lblPets.Text = string.format("Pets: %d / %d", equipped, maxPets)
            lblPlants.Text = "Plants: " .. tostring(plants)
            lblFruit.Text = "Fruits: " .. tostring(fruit)

            if rainbowPack then
                lblRainbow.Text = "🌈 Rainbow: Available +"
                lblRainbow.TextColor3 = Color3.fromRGB(255, 50, 255)
            elseif isRainbowNow then
                lblRainbow.Text = "🌈 Rainbow Moon active"
                lblRainbow.TextColor3 = Color3.fromRGB(200, 100, 200)
            elseif rainbowMoon then
                lblRainbow.Text = string.format("🌈 Rainbow Moon: %s", fmt(rainbowMoon.away))
                lblRainbow.TextColor3 = Color3.fromRGB(190, 120, 255)
            else
                lblRainbow.Text = "🌈 Rainbow Moon: --"
                lblRainbow.TextColor3 = Color3.fromRGB(120, 120, 120)
            end

            if goldPack then
                lblGold.Text = "🌟 Gold: Available +"
                lblGold.TextColor3 = Color3.fromRGB(255, 215, 0)
            elseif isGoldNow then
                lblGold.Text = "🌟 Goldmoon active"
                lblGold.TextColor3 = Color3.fromRGB(200, 180, 100)
            elseif goldMoon then
                lblGold.Text = string.format("🌟 Goldmoon: %s", fmt(goldMoon.away))
                lblGold.TextColor3 = Color3.fromRGB(255, 215, 0)
            else
                lblGold.Text = "🌟 Goldmoon: --"
                lblGold.TextColor3 = Color3.fromRGB(120, 120, 120)
            end

            local phaseRemain = math.max(0, phaseEnd - now)
            lblPhase.Text = string.format("%s | %s", phase or "--", fmt(phaseRemain))

            task.wait(0.5)
        end
    end)
end

bootstrapStatsUI()

task.spawn(function()
    local trackedCounts = {}
    local bp = LocalPlayer:FindFirstChild("Backpack")
    local char = LocalPlayer.Character

    local function checkSeedTool(item, isNew)
        if not item:IsA("Tool") then return end
        local seed = item:GetAttribute("SeedTool")
        if seed == "Rainbow" or seed == "Gold" then
            local count = item:GetAttribute("Count") or 0
            local prev = trackedCounts[seed] or 0
            trackedCounts[seed] = count
            if isNew and count > prev then
                pcall(getgenv().sendSeedPackWebhook, seed)
            end
            item.AttributeChanged:Connect(function(attr)
                if attr == "Count" then
                    local newCount = item:GetAttribute("Count") or 0
                    local oldPrev = trackedCounts[seed] or 0
                    trackedCounts[seed] = newCount
                    if newCount > oldPrev then
                        print("[SeedPack] " .. seed .. " count increased to " .. newCount)
                        pcall(getgenv().sendSeedPackWebhook, seed)
                    end
                end
            end)
            item.AncestryChanged:Connect(function()
                trackedCounts[seed] = nil
            end)
        end
    end

    if bp then
        bp.ChildAdded:Connect(function(item) checkSeedTool(item, true) end)
        for _, item in ipairs(bp:GetChildren()) do checkSeedTool(item, false) end
    end
    if char then
        char.ChildAdded:Connect(function(item) checkSeedTool(item, true) end)
        for _, item in ipairs(char:GetChildren()) do checkSeedTool(item, false) end
    end

    LocalPlayer.CharacterAdded:Connect(function(newChar)
        char = newChar
        newChar.ChildAdded:Connect(function(item) checkSeedTool(item, true) end)
        for _, item in ipairs(newChar:GetChildren()) do checkSeedTool(item, false) end
    end)
    LocalPlayer.ChildAdded:Connect(function(child)
        if child.Name == "Backpack" then
            bp = child
            child.ChildAdded:Connect(function(item) checkSeedTool(item, true) end)
            for _, item in ipairs(child:GetChildren()) do checkSeedTool(item, false) end
        end
    end)
end)

local function setupWorkspaceCleaner()
    local player = LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    local cleanerConns = {}
    local function connectCleaner(signal, fn)
        local conn = signal:Connect(fn)
        cleanerConns[#cleanerConns + 1] = conn
        return conn
    end

    local function hideGui()
        for _, ui in ipairs(playerGui:GetDescendants()) do
            if ui:IsA("ScreenGui") then
                ui.Enabled = false
            elseif ui:IsA("GuiObject") then
                ui.Visible = false
            end
        end
    end

    local FLOOR_NAME = "Gag2Floor"
    local FLOOR_DROP = 3.5
    local floorPart
    local function ensureFloor()
        if floorPart and floorPart.Parent == workspace then return floorPart end
        floorPart = Instance.new("Part")
        floorPart.Name = FLOOR_NAME
        floorPart.Size = Vector3.new(60, 1, 60)
        floorPart.Anchored = true
        floorPart.CanCollide = true
        floorPart.CanQuery = false
        floorPart.CanTouch = false
        floorPart.CastShadow = false
        floorPart.Transparency = 1
        floorPart.Parent = workspace
        return floorPart
    end

    local function updateFloor()
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local f = ensureFloor()
        f.Position = Vector3.new(hrp.Position.X, hrp.Position.Y - FLOOR_DROP, hrp.Position.Z)
    end

    local function teleportHome()
        local centerCf = API.getPlotCenterCFrame and API.getPlotCenterCFrame()
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and centerCf then
            hrp.CFrame = centerCf
        end
    end

    local function stripCharacter(char)
        char = char or player.Character
        if not char then return end
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("Accessory") or d:IsA("Decal") or d:IsA("Shirt")
               or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("Texture") then
                d:Destroy()
            elseif d:IsA("BasePart") then
                d.Transparency = 1
                d.CastShadow = false
            elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
                   or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
                d.Enabled = false
            end
        end
    end

    hideGui()
    stripCharacter()
    teleportHome()
    ensureFloor()
    updateFloor()


    local savedCol1, savedCol2
    if PlayerPlot then
        local visual = PlayerPlot:FindFirstChild("Visual")
        if visual then
            savedCol1 = visual:FindFirstChild("PlantAreaColumn1")
            savedCol2 = visual:FindFirstChild("PlantAreaColumn2")
            if savedCol1 then savedCol1.Parent = nil end
            if savedCol2 then savedCol2.Parent = nil end
        end
    end

    local map = workspace:FindFirstChild("Map")
    SeedPackSpawns = map and map:FindFirstChild("SeedPackSpawnServerLocations")
    WildPetFolder = map and map:FindFirstChild("WildPetRef")
    WildPetSpawns = map and map:FindFirstChild("WildPetSpawns")
    local seedPackClient = map and map:FindFirstChild("SeedPackSpawnClient")
    if SeedPackSpawns then SeedPackSpawns.Parent = nil end
    if WildPetFolder then WildPetFolder.Parent = nil end
    if WildPetSpawns then WildPetSpawns.Parent = nil end
    if seedPackClient then seedPackClient.Parent = nil end

    local lpChar = player.Character
    for _, v in ipairs(workspace:GetChildren()) do
        if v:IsA("Terrain") or v:IsA("Camera") or v == floorPart or v.Name == FLOOR_NAME then
            continue
        end
        if lpChar and (v == lpChar or v:IsDescendantOf(lpChar)) then continue end
        if v:IsA("Model") and v:FindFirstChild("Humanoid") then
            local owner = v:FindFirstChild("Humanoid") and v.Humanoid:FindFirstChild("Parent")
            if owner and owner.Value and owner.Value == player then continue end
        end
        v:Destroy()
    end

    if SeedPackSpawns or WildPetFolder or WildPetSpawns or seedPackClient then
        local newMap = Instance.new("Folder")
        newMap.Name = "Map"
        newMap.Parent = workspace
        if SeedPackSpawns then SeedPackSpawns.Parent = newMap end
        if WildPetFolder then WildPetFolder.Parent = newMap end
        if WildPetSpawns then WildPetSpawns.Parent = newMap end
        if seedPackClient then seedPackClient.Parent = newMap end
    end
    if savedCol1 then savedCol1.Parent = workspace end
    if savedCol2 then savedCol2.Parent = workspace end

    for _, child in ipairs(game.Players.LocalPlayer:GetChildren()) do
        if child:IsA("LuaSourceContainer") or child:IsA("PlayerGui") then
            child:Destroy()
        end
    end
    workspace.Camera:ClearAllChildren()
    workspace.Terrain:ClearAllChildren()
    local pg = player:FindFirstChildOfClass("PlayerGui")
    game:GetService("Lighting"):ClearAllChildren()
    game:GetService("ReplicatedFirst"):ClearAllChildren()
    game:GetService("Players").LocalPlayer.PlayerScripts:ClearAllChildren()
    workspace.ChildAdded:Connect(function(v)
        if v:IsA("Terrain") or v:IsA("Camera") or v == floorPart or v.Name == FLOOR_NAME then
            return
        end
        if v.Name == "Map" then
            local keepSet = {}
            if WildPetFolder then keepSet[WildPetFolder] = true end
            if WildPetSpawns then keepSet[WildPetSpawns] = true end
            if SeedPackSpawns then keepSet[SeedPackSpawns] = true end
            local sc = v:FindFirstChild("SeedPackSpawnClient")
            if sc then keepSet[sc] = true end
            for _, d in ipairs(v:GetDescendants()) do
                if keepSet[d] then continue end
                local inKeep = false
                for keep in pairs(keepSet) do
                    if d:IsDescendantOf(keep) then inKeep = true break end
                end
                if not inKeep then d:Destroy() end
            end
        elseif v.Name == "Gardens" then
            task.delay(2, function()
                refreshPlayerPlot()
                if not PlayerPlot then return end
                local visual = PlayerPlot:FindFirstChild("Visual")
                if not visual then return end
                local keepCols = {}
                local c1 = visual:FindFirstChild("PlantAreaColumn1")
                local c2 = visual:FindFirstChild("PlantAreaColumn2")
                if c1 then keepCols[c1] = true end
                if c2 then keepCols[c2] = true end
                for _, d in ipairs(v:GetDescendants()) do
                    local isKept = false
                    for col in pairs(keepCols) do
                        if d == col or d:IsDescendantOf(col) then
                            isKept = true
                            break
                        end
                    end
                    if not isKept then
                        d:Destroy()
                    end
                end
            end)
        else
            v:Destroy()
        end
    end)
    workspace.Camera.ChildAdded:Connect(function(v)
        if v:IsA("Terrain") or v:IsA("Camera") or v == floorPart or v.Name == FLOOR_NAME then
            return
        end
        v:Destroy()
    end)
    workspace.Terrain.ChildAdded:Connect(function(v)
        if v:IsA("Terrain") or v:IsA("Camera") or v == floorPart or v.Name == FLOOR_NAME then
            return
        end
        v:Destroy()
    end)
    if pg then
        pg.ChildAdded:Connect(function(c)
            c:Destroy()
        end)
    end

    connectCleaner(game:GetService("RunService").Heartbeat, function()
        updateFloor()
    end)



    connectCleaner(player.CharacterAdded, function(char)
        task.spawn(function()
            char:WaitForChild("HumanoidRootPart", 10)
            task.wait(0.2)
            stripCharacter(char)
            ensureFloor()
            teleportHome()
            updateFloor()
        end)
    end)

    local Players = game:GetService("Players")
    for _, p in ipairs(Players:GetChildren()) do
        if p ~= player then p:Destroy() end
    end
    connectCleaner(Players.PlayerAdded, function(p)
        if p ~= player then p:Destroy() end
    end)

    if getgenv().Gag2PlantsCleanerDisconnect then
        for _, conn in ipairs(getgenv().Gag2PlantsCleanerDisconnect) do
            conn:Disconnect()
        end
    end
    getgenv().Gag2PlantsCleanerDisconnect = cleanerConns
end

setupWorkspaceCleaner()

if Net.Pets.WildPetTameResult and Net.Pets.WildPetTameResult.OnClientEvent then
    Net.Pets.WildPetTameResult.OnClientEvent:Connect(function(_, userId)
        if userId == LocalPlayer.UserId then
            task.delay(0.8, API.tryEquipPetsInOrder)
        end
    end)
end

API.trySimpleTutorial()

API.doSell()
lastSellTime = os.clock()

task.spawn(function()
    while true do
        API.tryCatchPet()
        API.tryEquipPetsInOrder()
        API.tryOptimizeEquippedPets()
        API.tryUpgradePetSlots()
        task.wait(0.35)
    end
end)

task.spawn(function()
    while true do
        API.tryPickupMutationSeeds()
        task.wait(0.2)
    end
end)

task.spawn(function()
    while true do
        API.tryReturnIfKnockedAway()
        task.wait(0.4)
    end
end)

while true do
    if not savedPlotCenter then
        refreshPlayerPlot()
    end
    if API.shouldSell() then
        API.doSell()
    end
    API.tryExpandGarden()
    API.tryBuySeed()
    API.tryBuyGear()
    API.tryCompleteTutorial()
    API.trySendMail()
    API.tryUseGear()
    API.tryShovelExcess()
    API.tryPlant()
    task.wait(0.5)
end
