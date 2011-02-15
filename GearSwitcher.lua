local parent, ns = ...

-- The frame!
local gearSwitcher = CreateFrame("Frame")

-- Used to hold our set data, auto fills with saved data later
local sets = {}

-- Defaults to Fury with a subspec in Single-Minded Fury
local playerSpec = {"Fury", "Single-Minded Fury"}

-- Queue up changes if we enter into combat or are changing sets while in combat
local queue = {}

--[[
0 = ammo
1 = head
2 = neck
3 = shoulder
4 = shirt
5 = chest
6 = belt
7 = legs
8 = feet
9 = wrist
10 = gloves
11 = finger 1
12 = finger 2
13 = trinket 1
14 = trinket 2
15 = back
16 = main hand
17 = off hand
18 = ranged
19 = tabard
20 = first bag (the rightmost one)
21 = second bag
22 = third bag
23 = fourth bag (the leftmost one)
--]]

local invSlots = {
    [1] = "HeadSlot",
    [2] = "NeckSlot",
    [3] = "ShoulderSlot",
    [15] = "BackSlot",
    [5] = "ChestSlot",
    [9] = "WristSlot",
    [10] = "HandsSlot",
    [6] = "WaistSlot",
    [7] = "LegsSlot",
    [8] = "FeetSlot",
    [11] = "Finger0Slot",
    [12] = "Finger1Slot",
    [13] = "Trinket0Slot",
    [14] = "Trinket1Slot",
    [18] = "RangedSlot",
    [16] = "MainHandSlot",
    [17] = "SecondaryHandSlot"
}

-- PVP Zones
local PvPZoneNames = {
    -- Battlegrounds
    "Warsong Gulch",
    "Arathi Basin",
    "Twin Peaks",
    "The Battle for Gilneas",
    "Eye of the Storm",
    "Atlerac Valley",
    "Strand of the Ancients",
    "Isle of Conquest",

    -- Arenas
    "The Ring of Valor",
    "The Ruins of Lordaeron",
    "The Ring of Trials",
    "The Circle of Blood",
    "The Dalaran Arena",

    -- World PvP Zones
    "Tol Barad",    -- Cata
    "Wintergrasp",  -- WoTLK
}


-- Debugging
local function debug(message) DEFAULT_CHAT_FRAME:AddMessage(message) end



local function CheckPvPStatus(currentZone)
    for _, zone in pairs(PvPZoneNames) do
        if zone == currentZone then
            return true
        end
    end

    if UnitIsPVP("player") then
        return true
    end

    return false
end




-- Returns a table of currently equipped gear as {[slot] = itemLink}
local function GetEquipped()
    local gear = {}

    for slotID, slot in pairs(invSlots) do
        if CursorHasItem() then ClearCursor() end

        -- Pickup the slot
        PickupInventoryItem(slotID)

        if CursorHasItem() then
            ClearCursor()

            gear[slot] = GetInventoryItemLink("player", slotID)
        else
            ClearCursor()
        end
    end

    return gear
end






-- Checks to see if we've got an updated gear item.
-- We return if we have queue'd gear chagnes that need to be updated in our equipment sets.
local function CheckForUpdates(stance, change_weapons)
    local equipped = GetEquipped()
    local gearUpdate = false
    local weaponUpdate = false

    for slotID, slot in pairs(invSlots) do
        if slot == "MainHandSlot" or slot == "SecondaryHandSlot" then
            if equipped[slot] and equipped[slot] ~= "" then
                if sets[stance]["Gear"][slot] == "" and equipped[slot] ~= "" then
                    sets[stance]["Gear"][slot] = equipped[slot]
                    weaponUpdate = true
                else
                    local statsEquipped = GetItemStats(equipped[slot])
                    local statsSet      = GetItemStats(sets[stance]["Gear"][slot])

                    if change_weapons or (statsSet["ITEM_MOD_STRENGTH_SHORT"] < statsEquipped["ITEM_MOD_STRENGTH_SHORT"]) then
                        sets[stance]["Gear"][slot] = equipped[slot]
                        weaponUpdate = true
                    end
                end
            end
        else
            if sets[0][slot] == "" then
                sets[0][slot] = equipped[slot]
                gearUpdate = true
            elseif sets[0][slot] ~= equipped[slot] then
                local statsEquipped = GetItemStats(equipped[slot])
                local statsSet      = GetItemStats(sets[0][slot])

                if statsSet["ITEM_MOD_RESILIENCE_RATING_SHORT"] < statsEquipped["ITEM_MOD_RESILIENCE_RATING_SHORT"] then
                    sets[0][slot] = equipped[slot]
                    gearUpdate = true
                end
            end
        end
    end

    return weaponUpdate, gearUpdate
end




-- Check if our Equipment Name exists
local function CheckEquipmentName(name)
    for index = 1, GetNumEquipmentSets() do
        if name == select(1, GetEquipmentSetInfo(index)) then
            return true
        end
    end
    return false
end




-- Update our EquipmentManager set
local function UpdateEquipmentManager(setID)
    -- Break out if we are in combat as we can't use EquipItemByName in combat.
    if InCombatLockdown() then
        table.concat(queue, setID)
        gearSwitcher:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    if setID > 0 and setID <= 3 then
        local setName = sets[setID]["SetName"]

        -- Used to make sure we are overwriting the right set.
        if CheckEquipmentName(setName) then
            UseEquipmentSet(setName)
        end

        -- Equip our weapons.
        if sets[setID]["Gear"]["MainHandSlot"] ~= "" then
            EquipItemByName(sets[setID]["Gear"]["MainHandSlot"])
        end

        if sets[setID]["Gear"]["SecondaryHandSlot"] ~= "" then
            EquipItemByName(sets[setID]["Gear"]["SecondaryHandSlot"])
        end

        SaveEquipmentSet(setName, 1)
    elseif setID == 0 then
        local setName
        for stance = 1, 3 do
            setName = sets[stance]["SetName"]

            -- Check if our set already exists and equip it so we don't overwrite previous weapon sets.
            if CheckEquipmentName(setName) then
                UseEquipmentSet(setName)
            end

            -- Equip our armor, no matter if it's already equiped or not
            for _, slot in pairs(invSlots) do
                if slot ~= "MainHandSlot" and slot ~= "SecondarySlotHand" then
                    EquipItemByName(sets[setID][slot])
                end
            end

            -- Save the set over the top of the previous set.
            SaveEquipmentSet(setName, 1)
        end
    end
end




-- Sets our players primary spec as well as sets the subspec for fury's Titan Grip or Single-Minded Fury
local function SetSpec()
    for tab = 1, GetNumTalentTabs() do
        if select(5, GetTalentTabInfo(tab)) >= 31 then
            local name = select(2, GetTalentTabInfo(tab))

            if name == "Fury" then
                playerSpec = {name, select(5, GetTalentInfo(tab, 20)) == 1 and GetTalentInfo(tab, 20) or (select(5, GetTalentInfo(tab, 21)) == 1 and GetTalentInfo(tab, 21) or "")}
            else
                playerSpec = {name, ""}
            end
        end
    end
end




-- Default set table
local function DefaultSet()
    return {
        [0] = {
            ["HeadSlot"] = "",
            ["NeckSlot"] = "",
            ["ShoulderSlot"] = "",
            ["BackSlot"] = "",
            ["ChestSlot"] = "",
            ["WristSlot"] = "",
            ["HandsSlot"] = "",
            ["WaistSlot"] = "",
            ["LegsSlot"] = "",
            ["FeetSlot"] = "",
            ["Finger0Slot"] = "",
            ["Finger1Slot"] = "",
            ["Trinket0Slot"] = "",
            ["Trinket1Slot"] = "",
            ["RangedSlot"] = "",
        },
        [1] = {
            ["SetName"] = "PvP Arms",
            ["Gear"] = {
                ["MainHandSlot"] = "",
            }
        },
        [2] = {
            ["SetName"] = "PvP Protection",
            ["Gear"] = {
                ["MainHandSlot"] = "",
                ["SecondaryHandSlot"] = "",
            }
        },
        [3] = {
            ["SetName"] = "PvP Fury",
            ["Gear"] = {
                ["MainHandSlot"] = "",
                ["SecondaryHandSlot"] = "",
            }
        },
    }
end





------------------
-- Event Handler
------------------

-- Admin stuff related to loading and saving the database.
gearSwitcher:RegisterEvent("ADDON_LOADED")
gearSwitcher:RegisterEvent("PLAYER_LOGOUT")

-- The actual meat of the addong that switches the gear
gearSwitcher:RegisterEvent("UPDATE_SHAPESHIFT_FORM")

-- Used to update spec details
gearSwitcher:RegisterEvent("PLAYER_ENTERING_WORLD")
gearSwitcher:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
gearSwitcher:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...

        if name == "GearSwitcher" then
            if not gearDB or gearDB == {} or gearDB == nil then
                sets = DefaultSet()
            else
                sets = gearDB
            end
        end
    elseif event == "PLAYER_LOGOUT" then
        gearDB = sets
    elseif event == "UPDATE_SHAPESHIFT_FORM" then
        -- Make sure that the weapon switching is only going to happen for pvp zones.
        if not CheckPvPStatus(GetRealZoneText()) then return end

        local stance = GetShapeshiftForm()
        local set

        if sets and sets[stance] then
            local name, subspec = unpack(playerSpec)
            local mainhand, secondaryhand

            if name == "Fury" then
                if (stance == 1 or stance == 3) then
                    set = sets[3]["SetName"]
                else
                    set = sets[2]["SetName"]
                end
            elseif name == "Arms" then
                if (stance == 1 or stance == 3) then
                    set = sets[1]["SetName"]
                else
                    set = sets[2]["SetName"]
                end
            else
                set = sets[2]["SetName"]
            end

            if CheckEquipmentName(set) then
                UseEquipmentSet(set)
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        SetSpec()
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
end)





------------------
-- SLASH COMMAND
------------------
local function handleSlash (msg)
    if msg == "reset" then
        sets = DefaultSet()

        for index = 1, GetNumEquipmentSets() do
            for stance = 1, 3 do
                if GetEquipmentSetInfo(index) == sets[stance]["SetName"] then
                    DeleteEquipmentSet(sets[stance]["SetName"])
                end
            end
        end
        return
    end

    local activeSpec    = GetActiveTalentGroup()
    -- Used to hold which spec is primary.
    local stance        = GetShapeshiftForm()
    local updateWeapons = msg:sub(3, 6) == "true" and true or false

    SetSpec()

    local name, subspec = unpack(playerSpec)

    if msg:sub(1, 1) == "1" then
        stance = 1
        name = "Arms"
    elseif msg:sub(1, 1) == "2" then
        stance = 2
        name = "Protection"
    elseif msg:sub(1, 1) == "3" then
        stance = 3
        name = "Fury"
    else
        if not sets or sets == nil or sets == {} then
            sets = DefaultSet()
        end
        
        sets = DefaultSet()
        return
    end

    -- Check our current equipped gear against our saved set gear to see if we need to update
    local weaponUpdated, gearUpdated = CheckForUpdates(stance, updateWeapons)

    if weaponUpdated then
        UpdateEquipmentManager(stance)
    end

    if gearUpdated then
        UpdateEquipmentManager(0)
    end
end

SLASH_GEARSWITCHER1 = '/gearset'
SlashCmdList.GEARSWITCHER = handleSlash
