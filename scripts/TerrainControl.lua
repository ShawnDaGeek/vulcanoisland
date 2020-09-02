-- adapted by reallogger from the terrainControl.lua originally written by igor29381
-- purpose to add mud spec to all vehicles

TerrainControl = {}

function TerrainControl.prerequisitesPresent(specializations)
    return true
end

function TerrainControl.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", TerrainControl)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", TerrainControl)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", TerrainControl)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", TerrainControl)
    SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", TerrainControl)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", TerrainControl)
end

function TerrainControl.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "getMudIntensity", TerrainControl.getMudIntensity)
end

function TerrainControl:onPostLoad(savegame)
    local spec = self:DynamicMud_getSpecTable("wheels")

    if #spec.wheels > 0 then
        for c,wheel in pairs(spec.wheels) do
            if wheel.tireType ~= 4 then
                local psData = {}

                psData.psFile = "scripts/dirtPS/dirt2.i3d"
                psData.posX = wheel.positionX
                psData.posY = wheel.positionY-wheel.radius
                psData.posZ = wheel.positionZ
                psData.worldSpace = false

                wheel.dirt2ParticleSystems = {}
                ParticleUtil.loadParticleSystemFromData(psData, wheel.dirt2ParticleSystems, nil, false, nil, g_currentMission.baseDirectory, wheel.node)
                setScale(wheel.dirt2ParticleSystems.shape, wheel.radius, wheel.radius, wheel.radius)

                wheel.dirt3ParticleSystems = {}
                ParticleUtil.loadParticleSystemFromData(psData, wheel.dirt3ParticleSystems, nil, false, nil, g_currentMission.baseDirectory, wheel.node)
                setScale(wheel.dirt3ParticleSystems.shape, wheel.radius, wheel.radius, wheel.radius)

                wheel.enableDrift = false
                wheel.driftCoeff = 1
            end

            wheel.wasInMudS = false
            wheel.wasInMudC = false
            wheel.inMud = false
            wheel.lastRot,_,_ = getRotation(wheel.driveNode)
            wheel.realRadius = wheel.radius
            wheel.newRadius = wheel.radius

            local additionalWheelsWidth = 0

            if wheel.additionalWheels and #wheel.additionalWheels > 0 then
                for _,additionalWheel in pairs (wheel.additionalWheels) do
                    additionalWheelsWidth = additionalWheelsWidth + additionalWheel.width
                end
            end

            wheel.totalWidth = wheel.width + additionalWheelsWidth
            wheel.widthFactor = math.max(1, wheel.totalWidth * 2)
            wheel.minRadius = math.max(wheel.radius / 3, math.min(wheel.radius*wheel.totalWidth, wheel.radius * 0.8))
        end

        spec.movedDistance = 0
        spec.distanceToChange = math.random(2, 10) / 10
        spec.lineDamp = 0
    end
end

function TerrainControl:onLoad(savegame)
    self.spec_TerrainControl = self:DynamicMud_getSpecTable("TerrainControl")
end

function TerrainControl:onUpdate(dt)
    local spec = self:DynamicMud_getSpecTable("wheels")

    if #spec.wheels > 0 then
        local speed = spec:getLastSpeed(true)
        local enableChanges = false

        if spec.movedDistance then
            spec.movedDistance = spec.movedDistance + spec.lastMovedDistance

            if spec.movedDistance > spec.distanceToChange and speed > 0.5 then
                enableChanges = true
                spec.movedDistance = 0
                spec.distanceToChange = math.random(2, 10)/10
            end
        end

        if spec.isServer then
            local LineDamp = 0
            local dirtAmount = 0
            local mass = spec:getTotalMass()
            mass = mass / #spec.wheels

            for c = 1, #spec.wheels do
                local wheel = spec.wheels[c]

                if wheel.inMud then
                    wheel.wasInMudS = true

                    if wheel.tireTrackIndex then
                        g_currentMission.tireTrackSystem:cutTrack(wheel.tireTrackIndex)
                    end

                    local AxleSpeed = math.abs(getWheelShapeAxleSpeed(wheel.node, wheel.wheelShape))
                    self.dirtAmount = dirtAmount + ( (AxleSpeed / 6000) / #spec.wheels / 40 )

                    if spec.motor then
                        local damp = (speed / 200) / #spec.wheels
                        LineDamp = MathUtil.clamp(LineDamp + damp, 0.3, 0.8) / wheel.widthFactor
                    end

                    if enableChanges then
                        if wheel.tireType ~= 4 then
                            local frictionCoeff

                            if wheel.onMudBorder then
                                wheel.newRadius = math.max(wheel.realRadius - math.random(10, 20 + mass) / 100, wheel.minRadius)
                                wheel.driftCoeff = math.random(1, 5) / wheel.widthFactor
                                frictionCoeff = (math.random(40, 60) / 100) * wheel.widthFactor
                            else
                                wheel.newRadius = math.max(wheel.realRadius - math.random(20, 45 + mass) / 100, wheel.minRadius)
                                wheel.driftCoeff = math.random(1, 10) / wheel.widthFactor 
                                frictionCoeff = (math.random(30, 50) / 100) * wheel.widthFactor
                            end

                            local wx,wy,wz = getTranslation(wheel.driveNode)
                            addForce(spec.rootNode,wx * frictionCoeff, 0, 0, wx, wy, wz, true)
                            setWheelShapeTireFriction(wheel.node, wheel.wheelShape, wheel.maxLongStiffness, wheel.maxLatStiffness, wheel.maxLatStiffnessLoad, frictionCoeff * 2)

                        else
                            wheel.newRadius = wheel.realRadius - math.random(10, 20) / 300
                        end
                    end

                    if wheel.tireType ~= 4 then
                        wheel.enableDrift = (AxleSpeed > speed and AxleSpeed > 5)
                        if wheel.enableDrift then
                            wheel.newRadius = math.max(wheel.newRadius - 0.00001 * wheel.driftCoeff * dt, wheel.minRadius)
                        end
                    end

                    if AxleSpeed > 2 then
                        if wheel.radius < wheel.newRadius then
                            wheel.radius = math.min(wheel.radius + 0.0003 * dt, wheel.newRadius)
                            spec:updateWheelBase(wheel, true)
                        else
                            wheel.radius = math.max(wheel.radius - 0.0003 * dt, wheel.newRadius)
                            spec:updateWheelBase(wheel, true)
                        end
                    end
                end

                if wheel.wasInMudS and not wheel.inMud then
                    local AxleSpeed = math.abs(getWheelShapeAxleSpeed(wheel.node, wheel.wheelShape))

                    if AxleSpeed > 2 then
                        wheel.radius = math.min(wheel.radius + 0.001 * dt, wheel.realRadius)
                        spec:updateWheelBase(wheel, true)

                        if wheel.radius >= wheel.realRadius then
                            wheel.wasInMudS = false

                            if wheel.tireType ~= 4 then
                                setWheelShapeTireFriction(wheel.node, wheel.wheelShape, wheel.maxLongStiffness, wheel.maxLatStiffness, wheel.maxLatStiffnessLoad, wheel.tireGroundFrictionCoeff)
                            end
                        end
                    end
                end

                if wheel.realRadius and not wheel.inMud and not wheel.wasInMudS then
                    if enableChanges then
                        local x, y, z = getWorldTranslation(wheel.driveNode)
                        local bits = getDensityAtWorldPos(g_currentMission.terrainDetailId, x,y,z)
                        local _,bits2 = math.modf((bits - 2) / 4)

                        if bits == 0 and wheel.lastColor[4] < 0.8 then
                            wheel.newRadius = wheel.realRadius
                        end

                        if wheel.tireType ~= 4 then
                            if wheel.lastColor[4] > 0.8 then
                                if wheel.contact > 1 then
                                    local delta = 0.01-math.random(0, 2) / 100
                                    wheel.newRadius = wheel.realRadius - delta

                                    if spec.motor then LineDamp = LineDamp + (0.1 / #spec.wheels) / wheel.widthFactor end

                                else
                                    wheel.newRadius = wheel.realRadius
                                end
                            end

                            if bits > 0 then
                                wheel.newRadius = wheel.realRadius - (math.random(5, 9) / 100) / wheel.widthFactor
                                if spec.motor then LineDamp = LineDamp + (0.05 / #spec.wheels) / wheel.widthFactor end
                            end

                            if bits2 == 0 and not SpecializationUtil.hasSpecialization(Plough, spec.specializations) then
                                wheel.newRadius = MathUtil.clamp(wheel.realRadius-(math.random(15, 30) / 100) / wheel.widthFactor, wheel.realRadius / 3, wheel.realRadius)
                                if spec.motor then LineDamp = LineDamp + (0.1 / #spec.wheels) / wheel.widthFactor end
                            end

                        else
                            wheel.newRadius = wheel.realRadius

                            if bits > 0 then
                                wheel.newRadius = wheel.realRadius-math.random(3, 6) / 100
                                LineDamp = LineDamp + 0.05 / #spec.wheels
                            end

                            if bits2 == 0 then
                                wheel.newRadius = MathUtil.clamp(wheel.realRadius-math.random(5, 10) / 100, wheel.realRadius / 2, wheel.realRadius)
                                LineDamp = LineDamp + 0.075 / #spec.wheels
                            end
                        end
                    end

                    if wheel.radius > wheel.newRadius then
                        wheel.radius = math.max(wheel.radius - 0.00075 * dt, wheel.newRadius)
                        spec:updateWheelBase(wheel, true)

                    elseif wheel.radius < wheel.newRadius then
                        wheel.radius = math.min(wheel.radius + 0.00075 * dt, wheel.newRadius)
                        spec:updateWheelBase(wheel, true)
                    end
                end
            end

            if enableChanges and spec.lineDamp ~= LineDamp then
                setLinearDamping(spec.rootNode, LineDamp)
                spec.lineDamp = LineDamp
            end

            if dirtAmount > 0 and self.dirtAmount then
                spec.dirtAmount = math.min(spec.dirtAmount + dirtAmount, 1)

                if spec.attachedImplements ~= nil then
                    for i=1, #spec.attachedImplements do
                        local object = spec.attachedImplements[i].object
                        if object.dirtAmount then object.dirtAmount = math.min(object.dirtAmount + dirtAmount, 1) end
                    end
                end
            end
        end

        for c=1, #spec.wheels do
            local wheel = spec.wheels[c]
            if wheel.tireType ~= 4 then
                if wheel.inMud then
                    wheel.wasInMudC = true

                    local x,y,_ = getRotation(wheel.driveNode)
                    local forwardDirection = x < wheel.lastRot
                    wheel.lastRot = x

                    if (wheel.enableDrift and spec.isMotorStarted) or speed > 15 then
                        local dirtScale = 0.5 * g_currentMission.environment.groundWetness
                        
                        if wheel.alwaysMud then
                            dirtScale = 0.3
                        end

                        ParticleUtil.setEmitCountScale(wheel.dirt2ParticleSystems, dirtScale)
                        ParticleUtil.setEmitCountScale(wheel.dirt3ParticleSystems, dirtScale)
                        ParticleUtil.setEmittingState(wheel.dirt2ParticleSystems, not forwardDirection)
                        ParticleUtil.setEmittingState(wheel.dirt3ParticleSystems, forwardDirection)
                    else
                        ParticleUtil.setEmittingState(wheel.dirt2ParticleSystems, false)
                        ParticleUtil.setEmittingState(wheel.dirt3ParticleSystems, false)
                    end

                    setRotation(wheel.dirt2ParticleSystems.shape, math.rad(45), y, 0)
                    setRotation(wheel.dirt3ParticleSystems.shape, math.rad(45), y - math.rad(180), 0)
                end

                if wheel.wasInMudC and not wheel.inMud then
                    ParticleUtil.setEmittingState(wheel.dirt2ParticleSystems, false)
                    ParticleUtil.setEmittingState(wheel.dirt3ParticleSystems, false)
                    wheel.wasInMudC = false
                end
            end
        end
    end
end

function TerrainControl:onUpdateTick(dt)
    local spec = self:DynamicMud_getSpecTable("wheels")

    if spec:getLastSpeed(true) > 0 or spec:getIsActive() then
        if #spec.wheels > 0 then
            for c = 1, #spec.wheels do
                local wheel = spec.wheels[c]
                local wx,wy,wz = getWorldTranslation(wheel.driveNode)
                local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wx, 0, wz)
                local cx1 = wx + wheel.totalWidth / 3
                local cz1 = wz + wheel.totalWidth / 3
                local cx2 = wx - wheel.totalWidth / 3
                local cz2 = wz - wheel.totalWidth / 3

                if spec.isServer then
                    wheel.inMud = false
                    wheel.onMudBorder = false

                    if wheel.realRadius and wheel.contact == Wheels.WHEEL_GROUND_CONTACT and wy - wheel.radius-terrainHeight < 1 then
                        wheel = TerrainControl:checkMud(spec, wheel, cx1, cz1, cx2, cz1, cx2, cz2, DynamicMud.ALWAYS_MUD_CHANNEL)

                        if not wheel.inMud or not wheel.onMudBorder then
                            wheel = TerrainControl:checkMud(spec, wheel, cx1, cz1, cx2, cz1, cx2, cz2, DynamicMud.DYNAMIC_MUD_CHANNEL)
                        end
                    end
                end
            end
        end
    end
end

function TerrainControl:checkMud(spec, wheel, cx1, cz1, cx2, cz1, cx2, cz2, channel)
    local onMudBorder, inMud = TerrainControl.getMudIntensity(spec, cx1, cz1, cx2, cz1, cx2, cz2, channel)

    if onMudBorder or inMud then
        wheel.inMud = inMud
        wheel.onMudBorder = onMudBorder
        g_currentMission.tireTrackSystem:eraseParallelogram(cx1, cz1, cx2, cz1, cx2, cz2)

        if channel == DynamicMud.ALWAYS_MUD_CHANNEL then
            wheel.alwaysMud = true
        end
    end

    return wheel
end

function TerrainControl:onReadUpdateStream(streamId, timestamp, connection)
    local spec = self:DynamicMud_getSpecTable("wheels")

    if connection.isServer then
        for c=1, #spec.wheels do
            local wheel = spec.wheels[c]
            wheel.inMud = streamReadBool(streamId)
            wheel.enableDrift = streamReadBool(streamId)
        end
    end
end

function TerrainControl:onWriteUpdateStream(streamId, connection, dirtyMask)
    local spec = self:DynamicMud_getSpecTable("wheels")

    if not connection.isServer then
        for c=1, #spec.wheels do
            local wheel = spec.wheels[c]
            streamWriteBool(streamId, Utils.getNoNil(wheel.inMud, false))
            streamWriteBool(streamId, Utils.getNoNil(wheel.enableDrift, false))
        end
    end
end

function TerrainControl.getMudIntensity(spec, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, channel)
    if DynamicMud.modifierValue == nil or (channel == DynamicMud.DYNAMIC_MUD_CHANNEL and g_currentMission.environment.groundWetness == 0) then
        return false,false
    end

    local modifier = DynamicMud.modifierValue
    local filter = DynamicMud.filterType

    local terrainSize = DynamicMud.terrainSize
    modifier:setParallelogramUVCoords(startWorldX / terrainSize + 0.5, startWorldZ / terrainSize + 0.5, widthWorldX / terrainSize + 0.5, widthWorldZ / terrainSize + 0.5, heightWorldX / terrainSize + 0.5, heightWorldZ / terrainSize + 0.5, "ppp")
    filter:setValueCompareParams("equals", channel)
    local density, area, _ = modifier:executeGet(filter)

    if density <= 0 or area <= 0 then
        return false, false
    end

    local ret = density / area -- Calculate a percentage of the 'density'.

    return (ret <= 0.5), (ret > 0.5)
end