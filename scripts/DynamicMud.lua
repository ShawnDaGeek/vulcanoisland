----------------------------------------------------------------------------------------------------
-- DYNAMIC MUD SCRIPT
----------------------------------------------------------------------------------------------------
-- Purpose: To add mud to maps
-- Author:  reallogger
--
-- Copyright (c) Realismus Modding, 2019
----------------------------------------------------------------------------------------------------

DynamicMud = {}

local directory = g_currentModDirectory
local modName = g_currentModName

DynamicMud.FIRST_CHANNEL = 0
DynamicMud.NUM_CHANNELS = 2

DynamicMud.ALWAYS_MUD_CHANNEL = 1
DynamicMud.DYNAMIC_MUD_CHANNEL = 2

DynamicMud.map = 0


function DynamicMud:loadMap(name)
end

function DynamicMud:loadSavegame()
end

function DynamicMud:saveSavegame()
end

function DynamicMud:update(dt)
end

function DynamicMud:mouseEvent(posX, posY, isDown, isUp, button)
end

function DynamicMud:keyEvent(unicode, sym, modifier, isDown)
end

function DynamicMud:draw()
end

function DynamicMud:delete()
end

function DynamicMud:deleteMap()
end

function DynamicMud.onTerrainLoaded()
    local xmlFilename = Utils.getFilename(g_currentMission.missionInfo.mapXMLFilename, g_currentMission.baseDirectory)
    local xmlFile = loadXMLFile("mapXML", xmlFilename)

    if xmlFile ~= 0 then
        local relativePath = getXMLString(xmlFile, "map.mud.density#filename")

        if relativePath ~= nil then
            local path = Utils.getFilename(relativePath, g_currentMission.baseDirectory)
            DynamicMud.map = createBitVectorMap("mud")
            loadBitVectorMapFromFile(DynamicMud.map, path, DynamicMud.NUM_CHANNELS)
        end

        delete(xmlFile)
    end

    DynamicMud.terrainSize = g_currentMission.terrainSize

    if DynamicMud.map ~= 0 then
        DynamicMud.modifierValue = DensityMapModifier:new(DynamicMud.map, DynamicMud.FIRST_CHANNEL, DynamicMud.NUM_CHANNELS)
        DynamicMud.filterType = DensityMapFilter:new(DynamicMud.map, DynamicMud.FIRST_CHANNEL, DynamicMud.NUM_CHANNELS)
    end
end

function DynamicMud.installSpecializations()
    g_specializationManager:addSpecialization("TerrainControl", "TerrainControl", Utils.getFilename("scripts/TerrainControl.lua", directory), nil)

    for typeName, typeEntry in pairs(g_vehicleTypeManager:getVehicleTypes()) do
        if SpecializationUtil.hasSpecialization(Wheels, typeEntry.specializations) then
            g_vehicleTypeManager:addSpecialization(typeName, modName .. ".TerrainControl")
        end
    end

     Washable.updateDirtAmount = Utils.overwrittenFunction(Washable.updateDirtAmount, DynamicMud.inj_updateDirtAmount)
end

function DynamicMud.inj_updateDirtAmount(vehicle, superFunc, nodeData, dt)

    local change = superFunc(vehicle, nodeData, dt)

    if vehicle.dirtAmount ~= nil then
        change = change + vehicle.dirtAmount
    end

    return change
end

function Vehicle:DynamicMud_getSpecTable(name)
    local spec = self["spec_" .. modName .. "." .. name]
    if spec ~= nil then
        return spec
    end

    return self["spec_" .. name]
end

addModEventListener(DynamicMud)

FSBaseMission.initTerrain = Utils.appendedFunction(FSBaseMission.initTerrain, DynamicMud.onTerrainLoaded)
VehicleTypeManager.validateVehicleTypes = Utils.prependedFunction(VehicleTypeManager.validateVehicleTypes, DynamicMud.installSpecializations)