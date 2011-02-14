local parent, ns = ...

local gearSwitcher = CreateFrame("Frame")

local sets = {}
local playerSpec = {"Fury", "Single-Minded Fury"}

local function debug(message) DEFAULT_CHAT_FRAME:AddMessage(message) end

-- Here we equip our mainhand and secondaryhand weapons
local function equipItems(mainhand, secondaryhand)
    if mainhand then
        EquipItemByName(mainhand, GetInventorySlotInfo("MainHandSlot"))
    end

    if secondaryhand then
        EquipItemByName(secondaryhand, GetInventorySlotInfo("SecondaryHandSlot"))
    end
end

-- Set our playerSpec value
local function setSpec()
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

local function clearSets()
    return {
        [1] = {
            ["MainHandSlot"] = "",
        },
        [2] = {
            ["MainHandSlot"] = "",
            ["SecondaryHandSlot"] = "",
        },
        [3] = {
            ["Titan's Grip"] = {
                ["MainHandSlot"] = "",
                ["SecondaryHandSlot"] = "",
            },
            ["Single-Minded Fury"] = {
                ["MainHandSlot"] = "",
                ["SecondaryHandSlot"] = "",
            },
        },
    }
end

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
                sets = clearSets()
            else
                sets = gearDB
            end
        end
    elseif event == "PLAYER_LOGOUT" then
        gearDB = sets
    elseif event == "UPDATE_SHAPESHIFT_FORM" then
        -- Make sure that the weapon switching is only going to happen for pvp zones.
        --if select(2, IsInInstance()) ~= "pvp" then return end

        local stance = GetShapeshiftForm()

        if sets and sets[stance] then
            local name, subspec = unpack(playerSpec)
            local mainhand, secondaryhand

            if name == "Fury" then
                if (stance == 1 or stance == 3) and subspec ~= "" then
                    mainhand = sets[3][subspec]["MainHandSlot"]
                    secondaryhand = sets[3][subspec]["SecondaryHandSlot"]
                else
                    mainhand = sets[2]["MainHandSlot"]
                    secondaryhand = sets[2]["SecondaryHandSlot"]                    
                end
            elseif name == "Arms" then
                if (stance == 1 or stance == 3) then
                    mainhand = sets[1]["MainHandSlot"]
                    secondaryhand = nil
                else
                    mainhand = sets[2]["MainHandSlot"]
                    secondaryhand = sets[2]["SecondaryHandSlot"]
                end
            else
                mainhand = sets[2]["MainHandSlot"]
                secondaryhand = sets[2]["SecondaryHandSlot"]
            end

            equipItems(mainhand, secondaryhand)
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        setSpec()
    end
end)

local function handleSlash (msg)
    local activeSpec    = GetActiveTalentGroup()
    -- Used to hold which spec is primary.
    local mainhand      = GetItemInfo(GetInventoryItemID("player", GetInventorySlotInfo("MainHandSlot"))) or nil
    local secondaryhand = OffhandHasWeapon() and GetItemInfo(GetInventoryItemID("player", GetInventorySlotInfo("SecondaryHandSlot"))) or nil
    local stance        = GetShapeshiftForm()

    setSpec()

    local name, subspec = unpack(playerSpec)

    if msg == "1" then
        stance = 1
        name = "Arms"
    elseif msg == "2" then
        stance = 2
        name = "Proection"
    elseif msg == "3" then
        stance = 3
        name = "Fury"
    else
        -- Popup message about making educated guess on stance #
        return
    end

    if not sets or sets == nil or sets == {} then
        sets = clearSets()
    end

    if name == "Arms" then
        sets[stance]["MainHandSlot"] = mainhand
    elseif name == "Fury" then
        if subspec == "" then return end

        sets[stance][subspec]["MainHandSlot"] = mainhand
        sets[stance][subspec]["SecondaryHandSlot"] = secondaryhand
    elseif name == "Proection" then
        sets[stance]["MainHandSlot"] = mainhand
        sets[stance]["SecondaryHandSlot"] = secondaryhand
    end
end

SLASH_GEARSWITCHER1 = '/gearset'
SlashCmdList.GEARSWITCHER = handleSlash
