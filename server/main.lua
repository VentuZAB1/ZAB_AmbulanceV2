local sharedConfig = require 'config.shared'

-- Debug helper function
local function debugPrint(...)
    if sharedConfig.deathUI.debug then
        print("DEBUG:", ...)
    end
end

-- Security and Anti-Cheat System
local playerCooldowns = {} -- Track player cooldowns
local playerSignals = {} -- Track player signal attempts
local suspiciousActivity = {} -- Track suspicious behavior

-- Rate limiting configuration
local RATE_LIMITS = {
    emsSignal = { maxAttempts = 3, windowMs = 60000 }, -- 3 signals per minute
    respawn = { maxAttempts = 1, windowMs = 30000 }, -- 1 respawn per 30 seconds
    patientRevived = { maxAttempts = 5, windowMs = 60000 }, -- 5 revivals per minute
    healPatient = { maxAttempts = 10, windowMs = 60000 }, -- 10 heals per minute
    revivePatient = { maxAttempts = 5, windowMs = 60000 } -- 5 revives per minute
}

-- Security validation functions
local function isRateLimited(src, eventType)
    local currentTime = os.time() * 1000
    local limits = RATE_LIMITS[eventType]

    if not limits then return false end

    if not playerCooldowns[src] then
        playerCooldowns[src] = {}
    end

    if not playerCooldowns[src][eventType] then
        playerCooldowns[src][eventType] = { attempts = 0, lastReset = currentTime }
    end

    local cooldown = playerCooldowns[src][eventType]

    -- Reset if window has passed
    if currentTime - cooldown.lastReset > limits.windowMs then
        cooldown.attempts = 0
        cooldown.lastReset = currentTime
    end

    -- Check if rate limited
    if cooldown.attempts >= limits.maxAttempts then
        return true
    end

    cooldown.attempts = cooldown.attempts + 1
    return false
end

local function validatePlayer(src, requireAlive)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then
        debugPrint("Security: Invalid player", src)
        return false, nil
    end

    if requireAlive and (player.PlayerData.metadata.isdead or player.PlayerData.metadata.inlaststand) then
        debugPrint("Security: Player", src, "is dead but should be alive")
        return false, player
    end

    return true, player
end

local function validateDistance(src, targetSrc, maxDistance)
    if not targetSrc or src == targetSrc then return false end

    local srcPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetSrc)

    if not srcPed or not targetPed then return false end

    local srcCoords = GetEntityCoords(srcPed)
    local targetCoords = GetEntityCoords(targetPed)

    local distance = #(srcCoords - targetCoords)
    return distance <= maxDistance
end

local function logSuspiciousActivity(src, event, reason)
    if not suspiciousActivity[src] then
        suspiciousActivity[src] = { count = 0, events = {} }
    end

    suspiciousActivity[src].count = suspiciousActivity[src].count + 1
    table.insert(suspiciousActivity[src].events, {
        event = event,
        reason = reason,
        timestamp = os.time()
    })

    debugPrint("SUSPICIOUS ACTIVITY:", src, event, reason)

    -- If too many suspicious activities, take action
    if suspiciousActivity[src].count >= 5 then
        debugPrint("CRITICAL: Player", src, "has triggered too many security violations")
        -- You can add additional actions here like kicking the player
    end
end

-- Clean up old data periodically
CreateThread(function()
    while true do
        Wait(300000) -- Every 5 minutes

        local currentTime = os.time()

        -- Clean up old cooldowns
        for src, cooldowns in pairs(playerCooldowns) do
            for eventType, cooldown in pairs(cooldowns) do
                if currentTime * 1000 - cooldown.lastReset > 300000 then -- 5 minutes
                    cooldowns[eventType] = nil
                end
            end
            if next(cooldowns) == nil then
                playerCooldowns[src] = nil
            end
        end

        -- Clean up old suspicious activity
        for src, activity in pairs(suspiciousActivity) do
            if currentTime - activity.events[#activity.events].timestamp > 3600 then -- 1 hour
                suspiciousActivity[src] = nil
            end
        end
    end
end)

---@alias source number

lib.callback.register('qbx_ambulancejob:server:getPlayerStatus', function(_, targetSrc)
	local medicalStatus = exports.qbx_medical:GetPlayerStatus(targetSrc)
	local player = exports.qbx_core:GetPlayer(targetSrc)

	-- Enhanced status with detailed injury information
	local enhancedStatus = {
		injuries = medicalStatus.injuries or {},
		bleedLevel = medicalStatus.bleedLevel or 0,
		bleedState = medicalStatus.bleedState or 'No bleeding',
		damageCauses = medicalStatus.damageCauses or {},
		-- Add more detailed injury descriptions
		detailedInjuries = {}
	}

	-- Create detailed injury descriptions based on damage causes
	if medicalStatus.damageCauses then
		for weaponHash, _ in pairs(medicalStatus.damageCauses) do
			local weaponData = exports.qbx_core:GetWeapons()[weaponHash]
			if weaponData then
				table.insert(enhancedStatus.detailedInjuries, {
					cause = weaponData.label or 'Unknown weapon',
					description = weaponData.damagereason or 'Sustained injuries'
				})
			end
		end
	end

	return enhancedStatus
end)

-- Helper function to send ox_lib notifications with configurable settings
local function sendConfigurableNotification(playerId, notificationKey, ...)
	local config = sharedConfig.deathUI.oxNotifications[notificationKey]
	if not config then
		debugPrint("Warning: No notification config found for key:", notificationKey)
		return
	end

	local notification = {
		title = config.title,
		description = config.description,
		type = config.type,
		position = config.position or "bottom-right",
		duration = config.duration or 5000
	}

	-- Format description if arguments provided
	if ... then
		notification.description = notification.description:format(...)
	end

	-- Add style if configured
	if config.style then
		notification.style = config.style
	end

	TriggerClientEvent('ox_lib:notify', playerId, notification)
end

local function alertAmbulance(src, text, useOxLib)
	local ped = GetPlayerPed(src)
	local coords = GetEntityCoords(ped)
	local players = exports.qbx_core:GetQBPlayers()
	for _, v in pairs(players) do
		if v.PlayerData.job.type == 'ems' and v.PlayerData.job.onduty then
			if useOxLib then
				-- Send ox_lib notification for EMS down alerts
				sendConfigurableNotification(v.PlayerData.source, 'emsDown', text)
			else
				-- Use the existing ambulance alert system
				TriggerClientEvent('hospital:client:ambulanceAlert', v.PlayerData.source, coords, text)
			end
		end
	end
end

local function registerArmory()
	for _, armory in pairs(sharedConfig.locations.armory) do
		exports.ox_inventory:RegisterShop(armory.shopType, armory)
	end
end

local function registerStashes()
    for _, stash in pairs(sharedConfig.locations.stash) do
        exports.ox_inventory:RegisterStash(stash.name, stash.label, stash.slots, stash.weight, stash.owner, stash.groups, stash.location)
    end
end

RegisterNetEvent('hospital:server:ambulanceAlert', function(text)
	if GetInvokingResource() then return end
	local src = source

	-- Security validation
	if isRateLimited(src, 'emsSignal') then
		logSuspiciousActivity(src, 'hospital:server:ambulanceAlert', 'Rate limited')
		return
	end

	local valid, player = validatePlayer(src, false)
	if not valid then
		logSuspiciousActivity(src, 'hospital:server:ambulanceAlert', 'Invalid player')
		return
	end

	alertAmbulance(src, text or locale('info.civ_down'))
end)

RegisterNetEvent('hospital:server:emergencyAlert', function()
	if GetInvokingResource() then return end
	local src = source

	-- Security validation
	if isRateLimited(src, 'emsSignal') then
		logSuspiciousActivity(src, 'hospital:server:emergencyAlert', 'Rate limited')
		return
	end

	local valid, player = validatePlayer(src, false)
	if not valid then
		logSuspiciousActivity(src, 'hospital:server:emergencyAlert', 'Invalid player')
		return
	end

	-- Use configurable EMS down notification with ox_lib
	alertAmbulance(src, player.PlayerData.charinfo.lastname, true)
end)

RegisterNetEvent('qbx_medical:server:onPlayerLaststand', function()
	if GetInvokingResource() then return end
	local src = source

	-- Security validation
	if isRateLimited(src, 'emsSignal') then
		logSuspiciousActivity(src, 'qbx_medical:server:onPlayerLaststand', 'Rate limited')
		return
	end

	local valid, player = validatePlayer(src, false)
	if not valid then
		logSuspiciousActivity(src, 'qbx_medical:server:onPlayerLaststand', 'Invalid player')
		return
	end

	alertAmbulance(src, locale('info.civ_down'))
end)

---@param playerId number
RegisterNetEvent('hospital:server:TreatWounds', function(playerId)
	if GetInvokingResource() then return end
	local src = source

	-- Security validation
	if isRateLimited(src, 'healPatient') then
		logSuspiciousActivity(src, 'hospital:server:TreatWounds', 'Rate limited')
		return
	end

	local valid, player = validatePlayer(src, true)
	if not valid then
		logSuspiciousActivity(src, 'hospital:server:TreatWounds', 'Invalid player')
		return
	end

	-- Validate target player
	local validTarget, targetPlayer = validatePlayer(playerId, false)
	if not validTarget then
		logSuspiciousActivity(src, 'hospital:server:TreatWounds', 'Invalid target player')
		return
	end

	-- Validate distance (must be within 3 meters)
	if not validateDistance(src, playerId, 3.0) then
		logSuspiciousActivity(src, 'hospital:server:TreatWounds', 'Distance validation failed')
		return
	end

	-- Validate EMS job
	if player.PlayerData.job.type ~= 'ems' then
		logSuspiciousActivity(src, 'hospital:server:TreatWounds', 'Not EMS worker')
		return
	end

	-- Check if player has bandage
	if exports.ox_inventory:Search(src, 'count', 'bandage') == 0 then
		logSuspiciousActivity(src, 'hospital:server:TreatWounds', 'No bandage in inventory')
		return
	end

	exports.ox_inventory:RemoveItem(src, 'bandage', 1)
	TriggerClientEvent('hospital:client:HealInjuries', targetPlayer.PlayerData.source, 'full')
end)

---@param playerId number
RegisterNetEvent('hospital:server:RevivePlayer', function(playerId)
	if GetInvokingResource() then return end
	local src = source

	-- Security validation
	if isRateLimited(src, 'revivePatient') then
		logSuspiciousActivity(src, 'hospital:server:RevivePlayer', 'Rate limited')
		return
	end

	local valid, player = validatePlayer(src, true)
	if not valid then
		logSuspiciousActivity(src, 'hospital:server:RevivePlayer', 'Invalid player')
		return
	end

	-- Validate target player
	local validTarget, targetPlayer = validatePlayer(playerId, false)
	if not validTarget then
		logSuspiciousActivity(src, 'hospital:server:RevivePlayer', 'Invalid target player')
		return
	end

	-- Validate distance (must be within 3 meters)
	if not validateDistance(src, playerId, 3.0) then
		logSuspiciousActivity(src, 'hospital:server:RevivePlayer', 'Distance validation failed')
		return
	end

	-- Check if player has firstaid
	if exports.ox_inventory:Search(src, 'count', 'firstaid') == 0 then
		logSuspiciousActivity(src, 'hospital:server:RevivePlayer', 'No firstaid in inventory')
		return
	end

	exports.ox_inventory:RemoveItem(src, 'firstaid', 1)
	TriggerClientEvent('qbx_medical:client:playerRevived', targetPlayer.PlayerData.source)
end)

---@param targetId number
RegisterNetEvent('hospital:server:UseFirstAid', function(targetId)
	if GetInvokingResource() then return end
	local src = source

	-- Security validation
	if isRateLimited(src, 'healPatient') then
		logSuspiciousActivity(src, 'hospital:server:UseFirstAid', 'Rate limited')
		return
	end

	local valid, player = validatePlayer(src, true)
	if not valid then
		logSuspiciousActivity(src, 'hospital:server:UseFirstAid', 'Invalid player')
		return
	end

	-- Validate target player
	local validTarget, targetPlayer = validatePlayer(targetId, false)
	if not validTarget then
		logSuspiciousActivity(src, 'hospital:server:UseFirstAid', 'Invalid target player')
		return
	end

	-- Validate distance (must be within 3 meters)
	if not validateDistance(src, targetId, 3.0) then
		logSuspiciousActivity(src, 'hospital:server:UseFirstAid', 'Distance validation failed')
		return
	end

	local canHelp = lib.callback.await('hospital:client:canHelp', targetId)
	if not canHelp then
		exports.qbx_core:Notify(src, locale('error.cant_help'), 'error')
		return
	end

	TriggerClientEvent('hospital:client:HelpPerson', src, targetId)
end)

lib.callback.register('qbx_ambulancejob:server:getNumDoctors', function()
	return exports.qbx_core:GetDutyCountType('ems')
end)

lib.callback.register('qbx_ambulancejob:server:getTargetStatus', function(source, targetId)
	local player = exports.qbx_core:GetPlayer(targetId)
	if not player then
		return { isDead = false, isLaststand = false }
	end

	return {
		isDead = player.PlayerData.metadata.isdead or false,
		isLaststand = player.PlayerData.metadata.inlaststand or false
	}
end)

lib.addCommand('911e', {
    help = locale('info.ems_report'),
    params = {
        {name = 'message', help = locale('info.message_sent'), type = 'longString', optional = true},
    }
}, function(source, args)
	-- Security validation
	if isRateLimited(source, 'emsSignal') then
		local rateLimitConfig = sharedConfig.deathUI.oxNotifications.rateLimited
		exports.qbx_core:Notify(source, rateLimitConfig.description, rateLimitConfig.type)
		return
	end

	local valid, player = validatePlayer(source, false)
	if not valid then
		return
	end

	local message = args.message or locale('info.civ_call')
	local ped = GetPlayerPed(source)
	local coords = GetEntityCoords(ped)
	local players = exports.qbx_core:GetQBPlayers()
	for _, v in pairs(players) do
		if v.PlayerData.job.type == 'ems' and v.PlayerData.job.onduty then
			TriggerClientEvent('hospital:client:ambulanceAlert', v.PlayerData.source, coords, message)
		end
	end
end)

---@param src number
---@param event string
local function triggerEventOnEmsPlayer(src, event)
	local player = exports.qbx_core:GetPlayer(src)
	if player.PlayerData.job.type ~= 'ems' then
		exports.qbx_core:Notify(src, locale('error.not_ems'), 'error')
		return
	end

	TriggerClientEvent(event, src)
end

lib.addCommand('status', {
    help = locale('info.check_health'),
}, function(source)
	triggerEventOnEmsPlayer(source, 'hospital:client:CheckStatus')
end)

lib.addCommand('heal', {
    help = locale('info.heal_player'),
}, function(source)
	triggerEventOnEmsPlayer(source, 'hospital:client:TreatWounds')
end)

lib.addCommand('revivep', {
    help = locale('info.revive_player'),
}, function(source)
	triggerEventOnEmsPlayer(source, 'hospital:client:RevivePlayer')
end)

-- Items
---@param src number
---@param item table
---@param event string
local function triggerItemEventOnPlayer(src, item, event)
	local player = exports.qbx_core:GetPlayer(src)
	if not player then return end

	if exports.ox_inventory:Search(src, 'count', item.name) == 0 then return end

	local removeItem = lib.callback.await(event, src)
	if not removeItem then return end

	exports.ox_inventory:RemoveItem(src, item.name, 1)
end

exports.qbx_core:CreateUseableItem('ifaks', function(source, item)
	triggerItemEventOnPlayer(source, item, 'hospital:client:UseIfaks')
end)

exports.qbx_core:CreateUseableItem('bandage', function(source, item)
	triggerItemEventOnPlayer(source, item, 'hospital:client:UseBandage')
end)

exports.qbx_core:CreateUseableItem('painkillers', function(source, item)
	triggerItemEventOnPlayer(source, item, 'hospital:client:UsePainkillers')
end)

exports.qbx_core:CreateUseableItem('firstaid', function(source, item)
	triggerItemEventOnPlayer(source, item, 'hospital:client:UseFirstAid')
end)

RegisterNetEvent('qbx_medical:server:playerDied', function()
	if GetInvokingResource() then return end
	local src = source

	-- Security validation
	if isRateLimited(src, 'emsSignal') then
		logSuspiciousActivity(src, 'qbx_medical:server:playerDied', 'Rate limited')
		return
	end

	local valid, player = validatePlayer(src, false)
	if not valid then
		logSuspiciousActivity(src, 'qbx_medical:server:playerDied', 'Invalid player')
		return
	end

	alertAmbulance(src, locale('info.civ_died'))
end)

---EMS worker heals patient with bandage and gets paid
---@param patientId number
RegisterNetEvent('hospital:server:EmsHealPatient', function(patientId)
	if GetInvokingResource() then return end
	local src = source

	-- Security validation
	if isRateLimited(src, 'healPatient') then
		logSuspiciousActivity(src, 'hospital:server:EmsHealPatient', 'Rate limited')
		return
	end

	local valid, emsPlayer = validatePlayer(src, true)
	if not valid then
		logSuspiciousActivity(src, 'hospital:server:EmsHealPatient', 'Invalid EMS player')
		return
	end

	-- Validate target player
	local validTarget, patient = validatePlayer(patientId, false)
	if not validTarget then
		logSuspiciousActivity(src, 'hospital:server:EmsHealPatient', 'Invalid patient')
		return
	end

	-- Validate distance (must be within 3 meters)
	if not validateDistance(src, patientId, 3.0) then
		logSuspiciousActivity(src, 'hospital:server:EmsHealPatient', 'Distance validation failed')
		return
	end

	-- Verify EMS worker
	if emsPlayer.PlayerData.job.type ~= 'ems' then
		logSuspiciousActivity(src, 'hospital:server:EmsHealPatient', 'Not EMS worker')
		return
	end

	-- Check if EMS has bandages
	if exports.ox_inventory:Search(src, 'count', 'bandage') == 0 then
		exports.qbx_core:Notify(src, 'You need bandages to heal the patient', 'error')
		return
	end

	-- Remove bandage from EMS worker
	exports.ox_inventory:RemoveItem(src, 'bandage', 1)

	-- Trigger client event to heal the patient (SetEntityHealth is client-side only!)
	local healAmount = sharedConfig.bandageHealAmount or 25 -- Default 25% if not configured
	TriggerClientEvent('hospital:client:HealPlayer', patientId, healAmount)

	-- Pay the EMS worker (KEEPING YOUR ORIGINAL EXPORT)
	exports.qbx_core:AddMoney(src, 'cash', sharedConfig.bandagePayment, 'EMS healing payment')

	-- Notify both players
	exports.qbx_core:Notify(src, ('Patient healed successfully! You earned $%d'):format(sharedConfig.bandagePayment), 'success')
	exports.qbx_core:Notify(patientId, 'You have been treated by a paramedic', 'success')
	
	debugPrint("EMS", src, "healed patient", patientId, "for", healAmount, "% health")
end)

---EMS worker revives patient with firstaid and gets paid
---@param patientId number
RegisterNetEvent('hospital:server:EmsRevivePatient', function(patientId)
	if GetInvokingResource() then return end
	local src = source

	-- Security validation
	if isRateLimited(src, 'revivePatient') then
		logSuspiciousActivity(src, 'hospital:server:EmsRevivePatient', 'Rate limited')
		return
	end

	local valid, emsPlayer = validatePlayer(src, true)
	if not valid then
		logSuspiciousActivity(src, 'hospital:server:EmsRevivePatient', 'Invalid EMS player')
		return
	end

	-- Validate target player
	local validTarget, patient = validatePlayer(patientId, false)
	if not validTarget then
		logSuspiciousActivity(src, 'hospital:server:EmsRevivePatient', 'Invalid patient')
		return
	end

	-- Validate distance (must be within 3 meters)
	if not validateDistance(src, patientId, 3.0) then
		logSuspiciousActivity(src, 'hospital:server:EmsRevivePatient', 'Distance validation failed')
		return
	end

	-- Verify EMS worker
	if emsPlayer.PlayerData.job.type ~= 'ems' then
		logSuspiciousActivity(src, 'hospital:server:EmsRevivePatient', 'Not EMS worker')
		return
	end

	-- Check if patient is actually dead or in laststand
	local patientPlayer = exports.qbx_core:GetPlayer(patientId)
	if not patientPlayer.PlayerData.metadata.isdead and not patientPlayer.PlayerData.metadata.inlaststand then
		exports.qbx_core:Notify(src, 'Patient is not unconscious', 'error')
		return
	end

	-- Check if EMS has firstaid
	if exports.ox_inventory:Search(src, 'count', 'firstaid') == 0 then
		exports.qbx_core:Notify(src, 'You need firstaid to revive the patient', 'error')
		return
	end

	-- Remove firstaid from EMS worker
	exports.ox_inventory:RemoveItem(src, 'firstaid', 1)

	-- Revive the patient using the proper medical system event
	TriggerClientEvent('qbx_medical:client:revive', patientId)
	
	-- Clear death metadata (KEEPING YOUR ORIGINAL CODE)
	patientPlayer.Functions.SetMetaData('isdead', false)
	patientPlayer.Functions.SetMetaData('inlaststand', false)

	-- Clear patient's signal if they have one
	if activeSignals and activeSignals[patientId] then
		-- Notify all EMS to remove blip
		for _, playerId in pairs(GetPlayers()) do
			local emsPlayerLoop = exports.qbx_core:GetPlayer(tonumber(playerId))
			if emsPlayerLoop and emsPlayerLoop.PlayerData.job.type == 'ems' then
				TriggerClientEvent('ambulance:client:removePatientBlip', tonumber(playerId), patientId)
			end
		end
		activeSignals[patientId] = nil
	end

	-- Pay the EMS worker (KEEPING YOUR ORIGINAL EXPORT)
	exports.qbx_core:AddMoney(src, 'cash', sharedConfig.firstaidPayment, 'EMS revival payment')

	-- Notify both players (KEEPING YOUR ORIGINAL NOTIFICATIONS)
	exports.qbx_core:Notify(src, 'Patient revived successfully. Payment: $' .. sharedConfig.firstaidPayment, 'success')
	exports.qbx_core:Notify(patientId, 'You have been revived by EMS', 'success')
	
	debugPrint("EMS", src, "revived patient", patientId)
end)

-- Death UI and EMS Signal System
local activeSignals = {} -- Store active patient signals

---Player sends EMS signal when dead
RegisterNetEvent('ambulance:server:sendEMSSignal', function()
	if GetInvokingResource() then return end
	local src = source

	-- Security validation
	if isRateLimited(src, 'emsSignal') then
		logSuspiciousActivity(src, 'ambulance:server:sendEMSSignal', 'Rate limited')
		local rateLimitConfig = sharedConfig.deathUI.oxNotifications.rateLimited
		exports.qbx_core:Notify(src, rateLimitConfig.description, rateLimitConfig.type)
		return
	end

	local valid, player = validatePlayer(src, false)
	if not valid then
		logSuspiciousActivity(src, 'ambulance:server:sendEMSSignal', 'Invalid player')
		return
	end

	-- Verify player is actually dead
	if not player.PlayerData.metadata.isdead then
		logSuspiciousActivity(src, 'ambulance:server:sendEMSSignal', 'Player not dead')
		return
	end

	debugPrint("Received EMS signal from player", src)

	-- Get player coordinates
	local playerPed = GetPlayerPed(src)
	local coords = GetEntityCoords(playerPed)
	local playerName = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname

	-- Store signal data
	activeSignals[src] = {
		playerId = src,
		playerName = playerName,
		coords = coords,
		timestamp = os.time()
	}

	-- Get all online EMS workers
	local emsPlayers = {}
	for _, playerId in pairs(GetPlayers()) do
		local emsPlayer = exports.qbx_core:GetPlayer(tonumber(playerId))
		if emsPlayer and emsPlayer.PlayerData.job.type == 'ems' and emsPlayer.PlayerData.job.onduty then
			table.insert(emsPlayers, tonumber(playerId))
		end
	end

	-- Send notification and blip to all EMS workers
	debugPrint("Found", #emsPlayers, "EMS workers online")
	if #emsPlayers > 0 then
		local notificationConfig = sharedConfig.deathUI.oxNotifications.emsAlert
		local notificationText = notificationConfig.description:format(playerName)
		debugPrint("Sending notification:", notificationText)

		for i = 1, #emsPlayers do
			local emsId = emsPlayers[i]
			debugPrint("Sending alert to EMS", emsId)

			-- Send ox_lib notification using configurable settings
			local notification = {
				title = notificationConfig.title,
				description = notificationText,
				type = notificationConfig.type,
				position = notificationConfig.position,
				duration = notificationConfig.duration
			}

			-- Add style if configured
			if notificationConfig.style then
				notification.style = notificationConfig.style
			end

			TriggerClientEvent('ox_lib:notify', emsId, notification)
			TriggerClientEvent('ambulance:client:playEMSAlert', emsId)

			-- Create flickering blip on map
			TriggerClientEvent('ambulance:client:createPatientBlip', emsId, src, playerName, coords)
		end

		local signalSentConfig = sharedConfig.deathUI.oxNotifications.signalSent
		exports.qbx_core:Notify(src, signalSentConfig.description, signalSentConfig.type)
	else
		debugPrint("No EMS workers online")
		local noEmsConfig = sharedConfig.deathUI.oxNotifications.noEmsOnline
		exports.qbx_core:Notify(src, noEmsConfig.description, noEmsConfig.type)
	end
end)

---Player respawns (clears their signal)
RegisterNetEvent('ambulance:server:respawnPlayer', function()
	if GetInvokingResource() then return end
	local src = source

	-- Security validation
	if isRateLimited(src, 'respawn') then
		logSuspiciousActivity(src, 'ambulance:server:respawnPlayer', 'Rate limited')
		return
	end

	local valid, player = validatePlayer(src, false)
	if not valid then
		logSuspiciousActivity(src, 'ambulance:server:respawnPlayer', 'Invalid player')
		return
	end

	-- Verify player is actually dead
	local player = exports.qbx_core:GetPlayer(src)
	if not player.PlayerData.metadata.isdead then
		logSuspiciousActivity(src, 'ambulance:server:respawnPlayer', 'Player not dead')
		return
	end

	-- Clear active signal
	if activeSignals[src] then
		-- Notify all EMS to remove blip
		for _, playerId in pairs(GetPlayers()) do
			local emsPlayer = exports.qbx_core:GetPlayer(tonumber(playerId))
			if emsPlayer and emsPlayer.PlayerData.job.type == 'ems' then
				TriggerClientEvent('ambulance:client:removePatientBlip', tonumber(playerId), src)
			end
		end

		activeSignals[src] = nil
	end

	-- Clear death state and trigger respawn
	if player then
		-- Clear death metadata
		player.Functions.SetMetaData('isdead', false)
		player.Functions.SetMetaData('inlaststand', false)

		-- Get all hospital beds from config
		local config = require 'config.shared'
		local allBeds = {}

		-- Collect all beds from all hospitals
		for hospitalName, hospitalData in pairs(config.locations.hospitals) do
			for _, bed in pairs(hospitalData.beds) do
				table.insert(allBeds, bed.coords)
			end
		end

		-- Select a random bed from all available hospital beds
		if #allBeds > 0 then
			local selectedBed = allBeds[math.random(#allBeds)]
			debugPrint("Selected bed from", #allBeds, "available beds:", selectedBed.x, selectedBed.y, selectedBed.z)

			-- Trigger respawn at selected hospital bed
			TriggerClientEvent('ambulance:client:respawnAtBed', src, selectedBed)
		else
			print("ERROR: No hospital beds found in config!")
			-- Fallback to default location
			TriggerClientEvent('ambulance:client:respawnAtBed', src, vec4(353.1, -584.6, 43.11, 152.08))
		end

		-- Clear all inventory items (as mentioned in UI warning)
		debugPrint("Clearing inventory for player", src)
		exports.ox_inventory:ClearInventory(src, false)

		-- Also clear any money (optional - you can comment this out if you want to keep money)
		-- player.Functions.SetMoney('cash', 0)
		-- player.Functions.SetMoney('bank', 0)

		exports.qbx_core:Notify(src, 'Респаунахте се в болницата', 'success')
	end
end)

---Player gets revived (clear their signal)
RegisterNetEvent('ambulance:server:patientRevived', function(patientId)
	if GetInvokingResource() then return end
	local src = source

	-- Security validation
	if isRateLimited(src, 'patientRevived') then
		logSuspiciousActivity(src, 'ambulance:server:patientRevived', 'Rate limited')
		return
	end

	local valid, player = validatePlayer(src, false)
	if not valid then
		logSuspiciousActivity(src, 'ambulance:server:patientRevived', 'Invalid player')
		return
	end

	-- Clear active signal for revived patient
	if activeSignals[patientId] then
		-- Notify all EMS to remove blip
		for _, playerId in pairs(GetPlayers()) do
			local emsPlayer = exports.qbx_core:GetPlayer(tonumber(playerId))
			if emsPlayer and emsPlayer.PlayerData.job.type == 'ems' then
				TriggerClientEvent('ambulance:client:removePatientBlip', tonumber(playerId), patientId)
			end
		end

		activeSignals[patientId] = nil
	end
end)

---Clean up signals when players disconnect
AddEventHandler('playerDropped', function(reason)
	local src = source

	if activeSignals[src] then
		-- Notify all EMS to remove blip
		for _, playerId in pairs(GetPlayers()) do
			local emsPlayer = exports.qbx_core:GetPlayer(tonumber(playerId))
			if emsPlayer and emsPlayer.PlayerData.job.type == 'ems' then
				TriggerClientEvent('ambulance:client:removePatientBlip', tonumber(playerId), src)
			end
		end

		activeSignals[src] = nil
	end

	-- Clean up security data
	playerCooldowns[src] = nil
	suspiciousActivity[src] = nil
end)

---Send existing signals to EMS when they come on duty
RegisterNetEvent('QBCore:Server:SetDuty', function(duty)
	local src = source
	local player = exports.qbx_core:GetPlayer(src)

	if player and player.PlayerData.job.type == 'ems' and duty then
		-- Send all active signals to the newly on-duty EMS
		for patientId, signalData in pairs(activeSignals) do
			-- Check if patient is still online and still dead
			local patientPlayer = exports.qbx_core:GetPlayer(patientId)
			if patientPlayer then
				TriggerClientEvent('ambulance:client:createPatientBlip', src, patientId, signalData.playerName, signalData.coords)
			else
				-- Clean up stale signal
				activeSignals[patientId] = nil
			end
		end
	end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    registerArmory()
    registerStashes()
end)
