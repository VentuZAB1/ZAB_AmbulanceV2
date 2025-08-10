-- EMS Alert and Blip System
local activePatientBlips = {} -- Store patient blips: [playerId] = blipData

-- EMS Alert Sound
RegisterNetEvent('ambulance:client:playEMSAlert', function()
    -- Play EMS alert beep sound
    PlaySoundFrontend(-1, "TIMER_STOP", "HUD_MINI_GAME_SOUNDSET", true)

    -- Play additional alert sound
    CreateThread(function()
        Wait(500)
        PlaySoundFrontend(-1, "CHECKPOINT_NORMAL", "HUD_MINI_GAME_SOUNDSET", true)
    end)
end)

-- Create Patient Blip
RegisterNetEvent('ambulance:client:createPatientBlip', function(patientId, patientName, coords)
    -- Remove existing blip if exists
    if activePatientBlips[patientId] then
        RemoveBlip(activePatientBlips[patientId].blip)
    end

    -- Create new blip
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 153) -- Dead body icon
    SetBlipColour(blip, 1) -- Red color
    SetBlipScale(blip, 1.0)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName("🚑 " .. patientName)
    EndTextCommandSetBlipName(blip)

    -- Store blip data
    activePatientBlips[patientId] = {
        blip = blip,
        patientName = patientName,
        coords = coords,
        originalColour = 1,
        flickerState = false
    }

    -- Start flickering animation
    CreateThread(function()
        while activePatientBlips[patientId] do
            if DoesBlipExist(activePatientBlips[patientId].blip) then
                local blipData = activePatientBlips[patientId]

                if blipData.flickerState then
                    SetBlipColour(blipData.blip, 1) -- Red
                    SetBlipAlpha(blipData.blip, 255)
                else
                    SetBlipColour(blipData.blip, 1) -- Red
                    SetBlipAlpha(blipData.blip, 100) -- Dimmed
                end

                blipData.flickerState = not blipData.flickerState

                -- Pulse the blip for extra attention
                PulseBlip(blipData.blip)

                Wait(1000) -- Flicker every second
            else
                break
            end
        end
    end)
end)

-- Remove Patient Blip
RegisterNetEvent('ambulance:client:removePatientBlip', function(patientId)
    if activePatientBlips[patientId] then
        if DoesBlipExist(activePatientBlips[patientId].blip) then
            RemoveBlip(activePatientBlips[patientId].blip)
        end
        activePatientBlips[patientId] = nil
    end
end)

-- Clean up blips on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for patientId, blipData in pairs(activePatientBlips) do
            if DoesBlipExist(blipData.blip) then
                RemoveBlip(blipData.blip)
            end
        end
        activePatientBlips = {}
    end
end)

-- Update blip positions if patient moves (for unconscious players)
CreateThread(function()
    while true do
        Wait(5000) -- Update every 5 seconds

        for patientId, blipData in pairs(activePatientBlips) do
            local player = GetPlayerFromServerId(patientId)
            if player ~= -1 then
                local playerPed = GetPlayerPed(player)
                local newCoords = GetEntityCoords(playerPed)

                -- Update blip position if player moved significantly
                local distance = #(vec3(blipData.coords.x, blipData.coords.y, blipData.coords.z) - newCoords)
                if distance > 10.0 then
                    blipData.coords = {x = newCoords.x, y = newCoords.y, z = newCoords.z}
                    SetBlipCoords(blipData.blip, newCoords.x, newCoords.y, newCoords.z)
                end
            else
                -- Patient is no longer online, remove blip
                if DoesBlipExist(blipData.blip) then
                    RemoveBlip(blipData.blip)
                end
                activePatientBlips[patientId] = nil
            end
        end
    end
end)

-- Auto-remove blips for players who are no longer dead
CreateThread(function()
    while true do
        Wait(10000) -- Check every 10 seconds

        for patientId, blipData in pairs(activePatientBlips) do
            local player = GetPlayerFromServerId(patientId)
            if player ~= -1 then
                local playerPed = GetPlayerPed(player)

                -- Check if player is still dead/unconscious
                if not IsPedDeadOrDying(playerPed, true) and GetEntityHealth(playerPed) > 0 then
                    -- Player is alive, remove blip
                    if DoesBlipExist(blipData.blip) then
                        RemoveBlip(blipData.blip)
                    end
                    activePatientBlips[patientId] = nil

                    -- Notify server to clean up
                    TriggerServerEvent('ambulance:server:patientRevived', patientId)
                end
            end
        end
    end
end)

-- Exports
exports('getActivePatientBlips', function()
    return activePatientBlips
end)

exports('removePatientBlip', function(patientId)
    TriggerEvent('ambulance:client:removePatientBlip', patientId)
end)
