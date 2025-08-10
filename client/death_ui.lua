-- Death UI Client Logic
local sharedConfig = require 'config.shared'
local deathUIConfig = sharedConfig.deathUI

-- Get config
local config = require 'config.shared'
local isDebugEnabled = config.deathUI.debug

-- Debug print function
local function debugPrint(...)
    if isDebugEnabled then
        print("DEBUG:", ...)
    end
end

debugPrint("Death UI script loaded successfully")

local isDeathUIVisible = false
local deathTimer = 0
local isRespawnPhase = false
local isHoldingRespawn = false
local respawnHoldTime = 0
local signalSent = false
local lastSignalTime = 0
local signalCooldown = 60000 -- 60 seconds in milliseconds
local spamCooldown = 5000 -- 5 seconds in milliseconds
local lastSpamNotification = 0

-- NUI Callbacks (sendEMSSignal handled directly in key controls now)

RegisterNUICallback('startRespawnHold', function(data, cb)
    if isRespawnPhase and not isHoldingRespawn then
        isHoldingRespawn = true
        respawnHoldTime = 0

        SendNUIMessage({
            action = 'startRespawn',
            holdTime = deathUIConfig.respawnHoldTime
        })

        -- Start progress tracking
        CreateThread(function()
            while isHoldingRespawn and respawnHoldTime < deathUIConfig.respawnHoldTime do
                Wait(100)
                respawnHoldTime = respawnHoldTime + 0.1
            end
        end)
    end
    cb('ok')
end)

RegisterNUICallback('stopRespawnHold', function(data, cb)
    isHoldingRespawn = false
    respawnHoldTime = 0

    SendNUIMessage({
        action = 'stopRespawn'
    })
    cb('ok')
end)

RegisterNUICallback('respawnPlayer', function(data, cb)
    if isRespawnPhase and isHoldingRespawn then
        TriggerServerEvent('ambulance:server:respawnPlayer')
        hideDeathUI()
    end
    cb('ok')
end)

RegisterNUICallback('timerExpired', function(data, cb)
    isRespawnPhase = true
    debugPrint("Timer expired, respawn phase activated")
    cb('ok')
end)

-- Death UI Functions
local function showDeathUI()
    if not deathUIConfig.enabled then return end
    if isDeathUIVisible then return end -- Prevent multiple calls

    debugPrint("Showing death UI - resetting all states")
    isDeathUIVisible = true
    deathTimer = deathUIConfig.deathTimer
    isRespawnPhase = false -- CRITICAL: Always start with respawn DISABLED
    isHoldingRespawn = false
    signalSent = false
    -- Reset signal cooldown on new death
    lastSignalTime = 0
    lastSpamNotification = 0

    -- Force death animation with persistent flags (never ends until manually stopped)
    local ped = PlayerPedId()
    lib.requestAnimDict('dead')
    TaskPlayAnim(ped, 'dead', 'dead_a', 8.0, -8.0, -1, 1|2|16|32, 0, false, false, false)
    -- Animation flags: 1=repeat, 2=stop on last frame, 16=not interrupted by movement, 32=not interrupted by damage

    SetNuiFocus(false, false) -- No NUI focus needed, handle keys in Lua

    SendNUIMessage({
        action = 'showDeathUI',
        config = deathUIConfig
    })

    -- Start death timer backup (in case NUI fails)
    CreateThread(function()
        local timerMs = deathUIConfig.deathTimer * 1000 -- Convert to milliseconds
        debugPrint("Death timer backup started, waiting", deathUIConfig.deathTimer, "seconds...")
        Wait(timerMs)
        debugPrint("Timer completed - isDeathUIVisible:", isDeathUIVisible, "isRespawnPhase:", isRespawnPhase)
        if isDeathUIVisible and not isRespawnPhase then
            debugPrint("Lua timer backup - enabling respawn phase")
            isRespawnPhase = true
        end
    end)

        -- No need for animation monitoring - death animation is now persistent with proper flags
end

function hideDeathUI()
    isDeathUIVisible = false
    isRespawnPhase = false
    isHoldingRespawn = false
    signalSent = false

    -- Stop the persistent death animation when revived
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    debugPrint("Death animation cleared - player revived/respawned")

    SetNuiFocus(false, false)

    SendNUIMessage({
        action = 'hideDeathUI'
    })
end

-- Control Disabling (runs at 60 FPS only when dead)
CreateThread(function()
    while true do
        if isDeathUIVisible then
            Wait(0) -- Need to run every frame to disable controls properly
            -- Disable movement and action controls but allow camera and keyboard
            DisableControlAction(0, 30, true)  -- Move Left/Right
            DisableControlAction(0, 31, true)  -- Move Forward/Back
            DisableControlAction(0, 21, true)  -- Sprint
            DisableControlAction(0, 22, true)  -- Jump
            DisableControlAction(0, 23, true)  -- Enter Vehicle
            DisableControlAction(0, 75, true)  -- Exit Vehicle
            DisableControlAction(0, 24, true)  -- Attack
            DisableControlAction(0, 25, true)  -- Aim
            DisableControlAction(0, 44, true)  -- Cover
            DisableControlAction(0, 37, true)  -- Select Weapon
            DisableControlAction(0, 140, true) -- Melee Attack Light
            DisableControlAction(0, 141, true) -- Melee Attack Heavy
            DisableControlAction(0, 142, true) -- Melee Attack Alternate
            DisableControlAction(0, 143, true) -- Melee Block
            DisableControlAction(0, 263, true) -- Melee Attack 1
            DisableControlAction(0, 264, true) -- Melee Attack 2

            -- Allow ESC key for pause menu/map
            EnableControlAction(0, 27, true)   -- Phone
            EnableControlAction(0, 200, true)  -- Pause Menu (ESC key)
            EnableControlAction(0, 199, true)  -- Pause Menu Alternate
            EnableControlAction(0, 167, true)  -- Phone menu
            EnableControlAction(0, 177, true)  -- Cancel
        else
            Wait(1000) -- When not dead, check less frequently
        end
    end
end)

-- Key Input Handling (smart polling for G key with cooldown optimization)
CreateThread(function()
    while true do
        if isDeathUIVisible then
            local currentTime = GetGameTimer()
            local timeSinceLastSignal = currentTime - lastSignalTime

            -- If we're in cooldown period, check less frequently to save performance
            if timeSinceLastSignal < signalCooldown then
                Wait(1000) -- Check every second during cooldown
            else
                Wait(0) -- Check every frame when signal is available
            end

            -- Check for signal key (G) - works during any phase
            if IsControlJustPressed(0, 47) then -- G key
                currentTime = GetGameTimer()

                -- Check if player is spamming (prevent spam notifications)
                if currentTime - lastSpamNotification < spamCooldown then
                    goto continue -- Don't show any notification if spamming
                end

                -- Check if still on cooldown
                if currentTime - lastSignalTime < signalCooldown then
                    local remainingTime = math.ceil((signalCooldown - (currentTime - lastSignalTime)) / 1000)
                    exports.qbx_core:Notify('COOLDOWN - ' .. remainingTime .. ' seconds left till you can request help again...', 'error')
                    lastSpamNotification = currentTime
                    goto continue
                end

                -- Send signal
                                        debugPrint("G key pressed, sending EMS signal")
                lastSignalTime = currentTime
                lastSpamNotification = currentTime
                TriggerServerEvent('ambulance:server:sendEMSSignal')

                SendNUIMessage({
                    action = 'signalSent'
                })
                debugPrint("Signal sent to server and NUI")

                -- After sending signal, we can wait longer since cooldown is active
                Wait(1000) -- Wait 1 second after sending signal before checking again
            end

            ::continue::
        else
            Wait(1000) -- Check less frequently when death UI is not visible
        end
    end
end)

-- ESC and Respawn Key Handling (less frequent polling)
CreateThread(function()
    while true do
        if isDeathUIVisible then
            Wait(50) -- Check every 50ms for ESC and respawn keys

            -- Check for ESC key to hide/show UI
            if IsControlJustPressed(0, 200) then -- ESC key
                SendNUIMessage({
                    action = 'toggleUIVisibility',
                    visible = false
                })
            elseif IsControlJustReleased(0, 200) then -- ESC key released
                SendNUIMessage({
                    action = 'toggleUIVisibility',
                    visible = true
                })
            end

            -- Check for respawn key (E) during respawn phase
            -- Debug: Always check what phase we're in
            if IsControlJustPressed(0, 38) then -- E key just pressed
                debugPrint("E pressed - isRespawnPhase:", isRespawnPhase, "isDeathUIVisible:", isDeathUIVisible)
            end

            if isRespawnPhase then
                if IsControlPressed(0, 38) then -- E key
                    debugPrint("E key pressed, isRespawnPhase:", isRespawnPhase, "timer expired:", true)
                    if not isHoldingRespawn then
                        debugPrint("Starting hold progress")
                        SendNUIMessage({
                            action = 'startHoldProgress'
                        })
                        isHoldingRespawn = true
                        respawnHoldTime = GetGameTimer()
                    end

                    -- Update hold progress
                    local currentTime = GetGameTimer()
                    local holdDuration = currentTime - respawnHoldTime
                    local progress = math.min(holdDuration / (deathUIConfig.respawnHoldTime * 1000), 1.0)

                    debugPrint("Sending hold progress - duration:", holdDuration, "progress:", progress, "total:", deathUIConfig.respawnHoldTime)

                    SendNUIMessage({
                        action = 'updateHoldProgress',
                        progress = progress,
                        totalTime = deathUIConfig.respawnHoldTime
                    })

                    -- Check if held long enough
                    if holdDuration >= (deathUIConfig.respawnHoldTime * 1000) then
                        TriggerServerEvent('ambulance:server:respawnPlayer')
                        hideDeathUI()
                    end
                elseif isHoldingRespawn then
                    -- Key released, stop respawn
                    isHoldingRespawn = false
                    SendNUIMessage({
                        action = 'stopHoldProgress'
                    })
                end
            end
        else
            Wait(2000) -- Check every 2 seconds when death UI is not visible
        end
    end
end)

-- Events
RegisterNetEvent('ambulance:client:showDeathUI', function()
    showDeathUI()
end)

RegisterNetEvent('ambulance:client:hideDeathUI', function()
    hideDeathUI()
end)

-- Handle respawn at specific hospital bed
RegisterNetEvent('ambulance:client:respawnAtBed', function(bedCoords)
    debugPrint("Respawning at bed:", bedCoords.x, bedCoords.y, bedCoords.z, bedCoords.w)

    -- Reset player state
    local ped = PlayerPedId()
    SetEntityHealth(ped, 200) -- Full health
    SetPedArmour(ped, 0) -- No armor

    -- Clear any death animations
    ClearPedTasks(ped)

    -- Teleport to bed
    SetEntityCoords(ped, bedCoords.x, bedCoords.y, bedCoords.z, false, false, false, true)
    SetEntityHeading(ped, bedCoords.w)

    -- Force player to get out of any death state
    NetworkResurrectLocalPlayer(bedCoords.x, bedCoords.y, bedCoords.z + 0.5, bedCoords.w, true, false)

    -- Clear death state in medical system
    TriggerEvent('qbx_medical:client:resetHealthHud')
    TriggerServerEvent('qbx_medical:server:killPlayer', false) -- Set alive

    debugPrint("Player respawned successfully at hospital bed")
end)

-- Signal sending is handled directly in the control loop above

-- Hook into medical system death events
RegisterNetEvent('qbx_medical:client:onPlayerKilled', function()
    -- Show death UI when player dies (only if not already showing)
    CreateThread(function()
        Wait(2000) -- Wait a moment for death animation to start
        if exports.qbx_medical:IsDead() and not isDeathUIVisible then
            debugPrint("Player killed - showing death UI")
            showDeathUI()
        else
            debugPrint("Player killed but UI already visible or player not dead")
        end
    end)
end)

RegisterNetEvent('qbx_medical:client:playerRevived', function()
    -- Hide death UI when player is revived
    if isDeathUIVisible then
        hideDeathUI()
        -- Clean up signal
        TriggerServerEvent('ambulance:server:patientRevived', GetPlayerServerId(PlayerId()))
    end
end)

-- Check for death state changes and maintain death animation
CreateThread(function()
    local wasDead = false

    while true do
        local checkInterval = isDeathUIVisible and 500 or 2000 -- Check more frequently when dead
        Wait(checkInterval)

        local isDead = exports.qbx_medical:IsDead()

        if isDead and not wasDead then
            -- Player just died (only if not already showing death UI)
            if not isDeathUIVisible then
                debugPrint("Death state change detected - starting death UI")
                CreateThread(function()
                    Wait(2000) -- Wait for death animation
                    if exports.qbx_medical:IsDead() and deathUIConfig.enabled and not isDeathUIVisible then
                        showDeathUI()
                    end
                end)
            else
                debugPrint("Player died again but UI already showing")
            end
        elseif not isDead and wasDead then
            -- Player just revived
            debugPrint("Revival state change detected")
            if isDeathUIVisible then
                hideDeathUI()
                TriggerServerEvent('ambulance:server:patientRevived', GetPlayerServerId(PlayerId()))
            end
        end

        -- Death animation is now persistent with proper flags - no monitoring needed

        wasDead = isDead
    end
end)

-- Debug command to manually activate respawn phase (only works if debug is enabled)
RegisterCommand('forcerespawn', function()
    if not isDebugEnabled then
        exports.qbx_core:Notify('Debug mode must be enabled to use this command', 'error')
        return
    end

    debugPrint("/forcerespawn command executed")
    debugPrint("isDeathUIVisible =", isDeathUIVisible)
    debugPrint("isRespawnPhase =", isRespawnPhase)

    if isDeathUIVisible then
        debugPrint("Manually forcing respawn phase")
        isRespawnPhase = true
        exports.qbx_core:Notify('Respawn phase activated for testing', 'success')
    else
        exports.qbx_core:Notify('You must be dead to use this command', 'error')
    end
end, false)

-- Simple debug command to check script status
RegisterCommand('debugdeath', function()
    print("========== DEATH UI DEBUG ==========")
    print("Script is running: YES")
    print("isDeathUIVisible:", isDeathUIVisible)
    print("isRespawnPhase:", isRespawnPhase)
    print("isHoldingRespawn:", isHoldingRespawn)
    print("deathUIConfig.enabled:", deathUIConfig.enabled)
    print("Debug mode enabled:", isDebugEnabled)
    print("=====================================")
    exports.qbx_core:Notify('Debug info printed to F8 console', 'inform')
end, false)

-- Exports
exports('showDeathUI', showDeathUI)
exports('hideDeathUI', hideDeathUI)
exports('isDeathUIVisible', function() return isDeathUIVisible end)
exports('getConfig', function() return sharedConfig end)
