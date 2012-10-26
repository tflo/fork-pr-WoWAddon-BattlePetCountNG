
local addon_name, addon = ...

local LPJ = LibStub("LibPetJournal-2.0")
local L = LibStub("AceLocale-3.0"):GetLocale("BattlePetCount")

local is5_1 = not not C_PetJournal.GetNumCollectedInfo

--
--
--

local function SubTip(t)
    if t.X_BPC then
        t.X_BPC:Show()
        return t.X_BPC
    end
    
    local subtip = CreateFrame("FRAME", nil, t)
    subtip:SetPoint("TOPLEFT", t, "BOTTOMLEFT")
    subtip:SetPoint("TOPRIGHT", t, "BOTTOMRIGHT")
    
    subtip:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background", 
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
        tile = true, tileSize = 16, edgeSize = 16, 
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    subtip:SetBackdropColor(0,0,0,1)
    
    subtip.Text = subtip:CreateFontString(nil, "ARTWORK")
    subtip.Text:SetFontObject(GameTooltipTextSmall)
    subtip.Text:SetWordWrap(true)
    subtip.Text:SetPoint("TOPLEFT", subtip, 8, -8)
    subtip.Text:SetWidth(220)
    
    t.X_BPC = subtip
    return subtip
end

local function HideSubTip(t)
    if t.X_BPC then
        t.X_BPC:Hide()
    end
end

local BuildOwnedListS, BuildOwnedListC
do
    local tmp = {}
    local function BuildOwnedList(p_sp, p_c)
        wipe(tmp)

        for iv,petid in LPJ:IteratePetIDs() do
            local _, speciesID, customName, level, name, creatureID
            if is5_1 then
                speciesID, customName, level, _, _, _, _, name, _, _, creatureID = C_PetJournal.GetPetInfoByPetID(petid)
            else
                speciesID, customName, level, _, _, _, name, _, _, creatureID = C_PetJournal.GetPetInfoByPetID(petid)
            end
            
            if (p_sp and speciesID == p_sp) or (p_c and creatureID == p_c) then
                local _, _, _, _, quality = C_PetJournal.GetPetStats(petid)
                
                tinsert(tmp, format("|cff%02x%02x%02x%s|r (L%d)",
                            ITEM_QUALITY_COLORS[quality-1].r*255,
                            ITEM_QUALITY_COLORS[quality-1].g*255,
                            ITEM_QUALITY_COLORS[quality-1].b*255,
                            customName or name, tostring(level)))
            end
        end
        
        if #tmp > 0 then
            return table.concat(tmp, ", ")
        end
    end
    
    function BuildOwnedListS(speciesid)
        return BuildOwnedList(speciesid, nil)
    end
    
    function BuildOwnedListC(creatureid)
        return BuildOwnedList(nil, creatureid)
    end
end

local function OwnedListOrNot(ownedlist)
    if ownedlist then
        return format("%s %s", L["YOU_OWN_COLON"], ownedlist)
    else
        return L["YOU_DONT_OWN"]
    end
end

local ShortOwnedList
do
    local tmp = {}
    
    function ShortOwnedList(speciesID)
        wipe(tmp)
        
        for _, petID in LPJ:IteratePetIDs() do
            local sid, _, level = C_PetJournal.GetPetInfoByPetID(petID)
            if sid == speciesID then
                local _, _, _, _, quality = C_PetJournal.GetPetStats(petID)
                
                tinsert(tmp, format("|cff%02x%02x%02xL%d|r",
                        ITEM_QUALITY_COLORS[quality-1].r*255,
                        ITEM_QUALITY_COLORS[quality-1].g*255,
                        ITEM_QUALITY_COLORS[quality-1].b*255,
                        level))
            end
        end
        
        if #tmp > 0 then
            return format("%s: %s", L["OWNED"], table.concat(tmp, "/"))
        else
            return format("|cffee3333%s|r", L["UNOWNED"])
        end
    end
end

local function PlayersBest(speciesID)
    local maxquality = -1
    local maxlevel = -1
    for iv,petid in LPJ:IteratePetIDs() do
        local sid, _, level = C_PetJournal.GetPetInfoByPetID(petid)
        if sid == speciesID then
            local _, _, _, _, quality = C_PetJournal.GetPetStats(petid)
            if maxquality < quality then
                maxquality = quality
            end
            if maxlevel < level then
                maxlevel = level
            end
        end
    end
    
    if maxquality == -1 then
        return nil
    end
    return maxquality, maxlevel
end

--
-- BattlePetTooltipTemplate
--

hooksecurefunc("BattlePetTooltipTemplate_SetBattlePet", function(self, data)
    if not addon.db.profile.enableCageTip then
        return HideSubTip(self)
    end

    local subtip = SubTip(self)
    subtip.Text:SetText(OwnedListOrNot(BuildOwnedListS(self.speciesID)))
    subtip:SetHeight(subtip.Text:GetHeight()+16)
end)

--
-- PetBattleUnitTooltip
--

hooksecurefunc("PetBattleUnitTooltip_UpdateForUnit", function(self, petOwner, petIndex)
    if not addon.db.profile.enableBattleTip then
        return HideSubTip(self)
    end

    local subtip = SubTip(self)
    local speciesID = C_PetBattles.GetPetSpeciesID(petOwner, petIndex)
    subtip.Text:SetText(OwnedListOrNot(BuildOwnedListS(speciesID)))
    subtip:SetHeight(subtip.Text:GetHeight()+16)
end)

if not is5_1 then
    hooksecurefunc("PetBattleUnitFrame_UpdateDisplay", function(self)
        local quality = C_PetBattles.GetBreedQuality(self.petOwner, self.petIndex)
        if self.Name then
            self.Name:SetVertexColor(ITEM_QUALITY_COLORS[quality-1].r,
                                    ITEM_QUALITY_COLORS[quality-1].g,
                                    ITEM_QUALITY_COLORS[quality-1].b)
        end
    end)
end


--
-- GameTooltip
--


local function AlterGameTooltip(self)
    if not addon.db then
        return
    end
    
    if self.GetUnit and addon.db.profile.enableCreatureTip then
        local _, unit = self:GetUnit()
        if unit then
            if UnitIsWildBattlePet(unit) then
                local creatureID = tonumber(strsub(UnitGUID(unit),7,10), 16)
                self:AddLine(OwnedListOrNot(BuildOwnedListC(creatureID)))
                self:Show()
            end
            return
        end
    end
    
    if self.GetItem and addon.db.profile.enableItemTip then
        local _, link = self:GetItem()
        if link then
            local _, _, itemid = strfind(link, "|Hitem:(%d+):")
            if itemid then
                local speciesID = addon.Item2Species[tonumber(itemid)]
                if speciesID then
                    if not addon.db.profile.itemTipIncludesAll then
                        local _, _, _, _, _, _, _, canBattle = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
                        if not canBattle then
                            return
                        end
                    end
                    self:AddLine(OwnedListOrNot(BuildOwnedListS(speciesID)))
                    self:Show()
                end
            end
            return
        end
    end
end

GameTooltip:HookScript("OnShow", function(self)
    self = self or GameTooltip -- work around someone not playing nicely
    AlterGameTooltip(self)
end)

ItemRefTooltip:HookScript("OnShow", function(self)
    self = self or ItemRefTooltip -- work around someone not playing nicely
    AlterGameTooltip(self)
end)

local function sub_PetName(line)
    local name = line
    local start, stop = strfind(line, "|t")
    if start then
        name = strsub(line, stop+1)
    end
    local _, _, subname = strfind(name, "|c%x%x%x%x%x%x%x%x([^|]+)|r")
    if subname then
        name = subname
    end
    
    for _,speciesID in LPJ:IterateSpeciesIDs() do
        local s_name = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
        if s_name == name then
            return format("%s (%s)", line, ShortOwnedList(speciesID))          
        end
    end

    return line
end

local lastMinimapTooltip
GameTooltip:HookScript("OnUpdate", function(self)
    if addon.db and not addon.db.profile.enableMinimapTip then
        return
    elseif self:GetOwner() ~= Minimap then
        return
    end
    
    local text = GameTooltipTextLeft1:GetText()
    if text ~= lastMinimapTooltip then
        text = string.gsub(text, "([^\n]+)", sub_PetName)
        GameTooltipTextLeft1:SetText(text)
        lastMinimapTooltip = text
        self:Show()
    end
end)
