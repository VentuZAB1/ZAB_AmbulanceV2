local config = require 'config.client'
local sharedConfig = require 'config.shared'
local doctorCount = 0
local isDeadStateActive = false
local lastDoctorUpdate = GetGameTimer()

local function getDoctorCount()
    return lib.callback.await('qbx_ambulancejob:server:getNumDoctors')
end

local function displayRespawnText()
    -- Check if custom death UI is active and skip text display
    if sharedConfig.deathUI and sharedConfig.deathUI.enabled then
        return -- Don't show any respawn text when death UI is active
    end

    local deathTime = exports.qbx_medical:GetDeathTime()
    if deathTime > 0 and doctorCount > 0 then
        qbx.drawText2d({ text = locale('info.respawn_txt', math.ceil(deathTime)), coords = vec2(1.0, 1.44), scale = 0.6 })
    else
        qbx.drawText2d({
            text = locale('info.respawn_revive', exports.qbx_medical:GetRespawnHoldTimeDeprecated(), sharedConfig.checkInCost),
            coords = vec2(1.0, 1.44),
            scale = 0.6
        })
    end
end

---@param ped number
local function playDeadAnimation(ped)
    if IsInHospitalBed then
        if not IsEntityPlayingAnim(ped, InBedDict, InBedAnim, 3) then
            lib.playAnim(ped, InBedDict, InBedAnim, 1.0, 1.0, -1, 1, 0, false, false, false)
        end
    else
        exports.qbx_medical:PlayDeadAnimation()
    end
end

---@param ped number
local function handleDead(ped)
    if not IsInHospitalBed then
        displayRespawnText()
    end

    playDeadAnimation(ped)
end

---Player is able to send a notification to EMS there are any on duty
local function handleRequestingEms()
    -- Check if custom death UI is active and skip EMS request display
    if sharedConfig.deathUI and sharedConfig.deathUI.enabled then
        return -- Don't show EMS request when death UI is active
    end

    if not EmsNotified then
        qbx.drawText2d({ text = locale('info.request_help'), coords = vec2(1.0, 1.40), scale = 0.6 })
        if IsControlJustPressed(0, 47) then
            TriggerServerEvent('hospital:server:ambulanceAlert', locale('info.civ_down'))
            EmsNotified = true
        end
    else
        qbx.drawText2d({ text = locale('info.help_requested'), coords = vec2(1.0, 1.40), scale = 0.6 })
    end
end

local function handleLastStand()
    -- Check if custom death UI is active and skip laststand display
    if sharedConfig.deathUI and sharedConfig.deathUI.enabled then
        return -- Don't show laststand text when death UI is active
    end

    local laststandTime = exports.qbx_medical:GetLaststandTime()
    if laststandTime > config.laststandTimer or doctorCount == 0 then
        qbx.drawText2d({ text = locale('info.bleed_out', math.ceil(laststandTime)), coords = vec2(1.0, 1.44), scale = 0.6 })
    else
        qbx.drawText2d({ text = locale('info.bleed_out_help', math.ceil(laststandTime)), coords = vec2(1.0, 1.44), scale = 0.6 })
        handleRequestingEms()
    end
end

-- Initialize death state handler only after player is loaded
local function initializeDeathHandler()
    -- Handler for death state changes
    AddStateBagChangeHandler('qbx_medical:deathState', ('player:%s'):format(cache.serverId), function(bagName, key, value, reserved, replicated)
        local medicalConfig = require '@qbx_medical/config/shared'
        local isDead = (value == medicalConfig.deathState.DEAD)
        local inLaststand = (value == medicalConfig.deathState.LAST_STAND)

        if isDead or inLaststand then
            if not isDeadStateActive then
                isDeadStateActive = true
                -- Start the handler thread only when needed
                CreateThread(function()
                    while isDeadStateActive and (exports.qbx_medical:IsDead() or exports.qbx_medical:IsLaststand()) do
                        local currentIsDead = exports.qbx_medical:IsDead()
                        local currentInLaststand = exports.qbx_medical:IsLaststand()

                        if currentIsDead then
                            handleDead(cache.ped)
                        elseif currentInLaststand then
                            handleLastStand()
                        end

                        -- Update doctor count every 60 seconds
                        local currentTime = GetGameTimer()
                        if (currentTime - lastDoctorUpdate) > 60000 then
                            doctorCount = getDoctorCount()
                            lastDoctorUpdate = currentTime
                        end

                        Wait(500) -- Much less frequent than Wait(0)
                    end
                    isDeadStateActive = false
                end)
            end
        else
            isDeadStateActive = false
        end
    end)
    
    -- Get initial doctor count after player loads
    doctorCount = getDoctorCount()
end

-- Wait for player to be loaded before initializing
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    initializeDeathHandler()
end)
