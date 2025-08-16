local sharedConfig = require 'config.shared'
InBedDict = 'anim@gangops@morgue@table@'
InBedAnim = 'body_search'
IsInHospitalBed = false
HealAnimDict = 'amb@medic@standing@kneel@base'
HealAnim = 'base'
EmsNotified = false
CanLeaveBed = true
OnPainKillers = false

---Notifies EMS of a injury at a location
---@param coords vector3
---@param text string
RegisterNetEvent('hospital:client:ambulanceAlert', function(coords, text)
    if GetInvokingResource() then return end
    local streets = qbx.getStreetName(coords)
    exports.qbx_core:Notify(locale('text.alert'), 'inform', nil, text .. ' | ' .. streets.main .. ' ' .. streets.cross)
    PlaySound(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', false, 0, true)
    local transG = 250
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    local blip2 = AddBlipForCoord(coords.x, coords.y, coords.z)
    local blipText = locale('info.ems_alert', text)
    SetBlipSprite(blip, 153)
    SetBlipSprite(blip2, 161)
    SetBlipColour(blip, 1)
    SetBlipColour(blip2, 1)
    SetBlipDisplay(blip, 4)
    SetBlipDisplay(blip2, 8)
    SetBlipAlpha(blip, transG)
    SetBlipAlpha(blip2, transG)
    SetBlipScale(blip, 0.8)
    SetBlipScale(blip2, 2.0)
    SetBlipAsShortRange(blip, false)
    SetBlipAsShortRange(blip2, false)
    PulseBlip(blip2)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(blipText)
    EndTextCommandSetBlipName(blip)
    while transG ~= 0 do
        Wait(720)
        transG -= 1
        SetBlipAlpha(blip, transG)
        SetBlipAlpha(blip2, transG)
        if transG == 0 then
            RemoveBlip(blip)
            return
        end
    end
end)

---Revives player, healing all injuries
---Intended to be called from client or server.
RegisterNetEvent('hospital:client:Revive', function()
    if IsInHospitalBed then
        lib.playAnim(cache.ped, InBedDict, InBedAnim, 8.0, 1.0, -1, 1, 0, false, false, false)
        TriggerEvent('qbx_medical:client:playerRevived')
        CanLeaveBed = true
    end

    EmsNotified = false
end)

RegisterNetEvent('qbx_medical:client:playerRevived', function()
    EmsNotified = false
end)

---Sends player phone email with hospital bill.
---@param amount number
RegisterNetEvent('hospital:client:SendBillEmail', function(amount)
    if GetInvokingResource() then return end
    SetTimeout(math.random(2500, 4000), function()
        local charInfo = QBX.PlayerData.charinfo
        local gender = charInfo.gender == 1 and locale('info.mrs') or locale('info.mr')
        TriggerServerEvent('qb-phone:server:sendNewMail', {
            sender = locale('mail.sender'),
            subject = locale('mail.subject'),
            message = locale('mail.message', gender, charInfo.lastname, amount),
            button = {}
        })
    end)
end)

---Sets blips for stations on map
CreateThread(function()
    for _, station in pairs(sharedConfig.locations.stations) do
        local blip = AddBlipForCoord(station.coords.x, station.coords.y, station.coords.z)
        SetBlipSprite(blip, 61)
        SetBlipAsShortRange(blip, true)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, 25)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(station.label)
        EndTextCommandSetBlipName(blip)
    end
end)

function GetClosestPlayer()
    return lib.getClosestPlayer(GetEntityCoords(cache.ped), 5.0, false)
end

---Revive patient with firstaid (EMS workers get paid)
---@param playerId number
local function revivePatientWithFirstaid(playerId)
    local hasFirstaid = exports.ox_inventory:Search('count', 'firstaid') > 0
    if not hasFirstaid then
        exports.qbx_core:Notify('You need firstaid to revive the patient', 'error')
        return
    end

    if lib.progressCircle({
        duration = 8000,
        position = 'bottom',
        label = 'Reviving patient with firstaid...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = false,
            combat = true,
            mouse = false,
        },
        anim = {
            dict = 'amb@medic@standing@kneel@base',
            clip = 'base',
            flag = 1,
        },
    })
    then
        TriggerServerEvent('hospital:server:EmsRevivePatient', playerId)
        exports.qbx_core:Notify('Patient revived successfully', 'success')
    else
        exports.qbx_core:Notify('Revival cancelled', 'error')
    end
end

---Heal patient with bandage (EMS workers get paid)
---@param playerId number
local function healPatientWithBandage(playerId)
    local hasBandage = exports.ox_inventory:Search('count', 'bandage') > 0
    if not hasBandage then
        exports.qbx_core:Notify('You need bandages to heal the patient', 'error')
        return
    end

    if lib.progressCircle({
        duration = 6000,
        position = 'bottom',
        label = 'Treating patient with bandages...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = false,
            combat = true,
            mouse = false,
        },
        anim = {
            dict = 'amb@medic@standing@kneel@base',
            clip = 'base',
            flag = 1,
        },
    })
    then
        TriggerServerEvent('hospital:server:EmsHealPatient', playerId)
        exports.qbx_core:Notify('Patient treated successfully', 'success')
    else
        exports.qbx_core:Notify('Treatment cancelled', 'error')
    end
end

-- Forward declarations
local showPatientMenu
local showInjuryMenu

---Patient examination menu for EMS workers
---@param playerId number
showPatientMenu = function(playerId)
    local targetPed = GetPlayerPed(GetPlayerFromServerId(playerId))

    -- Get player status from medical system
    local status = lib.callback.await('qbx_ambulancejob:server:getPlayerStatus', false, playerId)

    -- Check if target player is dead/unconscious using server callback
    local targetStatus = lib.callback.await('qbx_ambulancejob:server:getTargetStatus', false, playerId)
    local isDead = targetStatus.isDead or false
    local isLaststand = targetStatus.isLaststand or false

    -- Fix health display for dead/unconscious players
    local healthPercentage = 0
    if not isDead and not isLaststand then
        local playerHealth = GetEntityHealth(targetPed)
        local actualHealth = math.max(0, playerHealth - 100)
        healthPercentage = math.floor(actualHealth)
    end

    -- Determine patient status
    local patientStatus = "Patient Conscious"
    local statusIcon = 'fas fa-heartbeat'
    if isDead then
        patientStatus = "Patient Dead"
        statusIcon = 'fas fa-skull'
    elseif isLaststand then
        patientStatus = "Patient Unconscious"
        statusIcon = 'fas fa-bed'
    elseif healthPercentage < 50 then
        patientStatus = "Patient Injured"
        statusIcon = 'fas fa-user-injured'
    end

    local menuOptions = {
        {
            title = '🔍 Patient Status: ' .. patientStatus,
            description = 'Current patient condition',
            icon = statusIcon
        },
        {
            title = '🩺 Check for Injuries',
            description = 'Check if the patient has any fractures or injuries',
            icon = 'fas fa-user-injured',
            onSelect = function()
                showInjuryMenu(playerId, status)
            end
        },
        {
            title = '💚 Patient Health: ' .. healthPercentage .. '%',
            description = 'Current health status',
            icon = 'fas fa-heart'
        }
    }

    -- Show appropriate treatment options based on patient condition
    if not isDead and not isLaststand then
        -- Patient is conscious - show heal option
        local hasBandage = exports.ox_inventory:Search('count', 'bandage') > 0
        if hasBandage then
            menuOptions[#menuOptions + 1] = {
                title = '🩹 Heal Patient',
                description = 'Use bandages to heal patient\'s wounds',
                icon = 'fas fa-medkit',
                onSelect = function()
                    lib.hideContext()
                    healPatientWithBandage(playerId)
                end
            }
        end
    else
        -- Patient is dead or unconscious - show revive option
        local hasFirstaid = exports.ox_inventory:Search('count', 'firstaid') > 0
        if hasFirstaid then
            menuOptions[#menuOptions + 1] = {
                title = '💉 Revive Patient',
                description = 'Use firstaid to revive the patient',
                icon = 'fas fa-heartbeat',
                onSelect = function()
                    lib.hideContext()
                    revivePatientWithFirstaid(playerId)
                end
            }
        end
    end

    lib.registerContext({
        id = 'patient_examination_menu',
        title = 'CHECK PATIENT MENU',
        options = menuOptions
    })

    lib.showContext('patient_examination_menu')
end

---Show detailed injury examination menu
---@param playerId number
---@param status table
showInjuryMenu = function(playerId, status)
    local injuryOptions = {}

    -- Show basic injuries from medical system
    if #status.injuries > 0 then
        for i = 1, #status.injuries do
            injuryOptions[#injuryOptions + 1] = {
                title = '🦴 Fracture: ' .. status.injuries[i],
                description = 'Bone fracture detected',
                icon = 'fas fa-bone'
            }
        end
    end

    -- Show detailed damage causes (weapons, impacts, etc.)
    if status.detailedInjuries and #status.detailedInjuries > 0 then
        for i = 1, #status.detailedInjuries do
            local injury = status.detailedInjuries[i]
            injuryOptions[#injuryOptions + 1] = {
                title = '⚠️ Trauma: ' .. injury.cause,
                description = injury.description,
                icon = 'fas fa-exclamation-triangle'
            }
        end
    end

    -- Show bleeding status
    if status.bleedLevel > 0 then
        injuryOptions[#injuryOptions + 1] = {
            title = '🩸 Bleeding: ' .. status.bleedState,
            description = 'Active bleeding detected - requires immediate attention',
            icon = 'fas fa-tint'
        }
    end

    -- If no injuries found
    if #injuryOptions == 0 then
        injuryOptions[#injuryOptions + 1] = {
            title = '✅ No Injuries Detected',
            description = 'Patient appears to be in good condition',
            icon = 'fas fa-check-circle'
        }
    end

    -- Add back button
    injuryOptions[#injuryOptions + 1] = {
        title = '← Back to Patient Menu',
        description = 'Return to main examination menu',
        icon = 'fas fa-arrow-left',
        onSelect = function()
            showPatientMenu(playerId)
        end
    }

    lib.registerContext({
        id = 'injury_examination_menu',
        title = 'INJURY EXAMINATION',
        options = injuryOptions
    })

    lib.showContext('injury_examination_menu')
end

---Create ox_target for patient examination
local function setupPatientTarget()
    exports.ox_target:addGlobalPlayer({
        {
            icon = 'fas fa-user-md',
            label = 'Examine Patient',
            canInteract = function(entity, distance, coords, name, bone)
                return QBX.PlayerData.job.type == 'ems' and QBX.PlayerData.job.onduty and distance < 2.0
            end,
            onSelect = function(data)
                local playerId = GetPlayerServerId(NetworkGetEntityOwner(data.entity))
                showPatientMenu(playerId)
            end,
        }
    })
end

-- Setup target once when resource starts or player loads
local targetSetup = false

CreateThread(function()
    if not targetSetup then
        setupPatientTarget()
        targetSetup = true
    end
end)

-- Update target system when player job changes (instant response)
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    -- Target system will automatically check canInteract function in real-time
    -- QBX.PlayerData.job is updated automatically by core
end)

-- Also handle when player goes on/off duty
RegisterNetEvent('QBCore:Client:SetDuty', function(duty)
    -- Target system will automatically check canInteract function in real-time
    -- QBX.PlayerData.job.onduty is updated automatically by core
end)

-- Handle player data updates for instant target response
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    -- Ensure target system is ready when player loads (only if not already set up)
    if not targetSetup then
        setupPatientTarget()
        targetSetup = true
    end
end)

function OnKeyPress(cb)
    if IsControlJustPressed(0, 38) then
        lib.hideTextUI()
        cb()
    end
end
