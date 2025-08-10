local sharedConfig = require 'config.shared'

-- Debug helper function
local function debugPrint(...)
    if sharedConfig.deathUI.debug then
        print("DEBUG:", ...)
    end
end

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

local function alertAmbulance(src, text)
	local ped = GetPlayerPed(src)
	local coords = GetEntityCoords(ped)
	local players = exports.qbx_core:GetQBPlayers()
	for _, v in pairs(players) do
		if v.PlayerData.job.type == 'ems' and v.PlayerData.job.onduty then
			TriggerClientEvent('hospital:client:ambulanceAlert', v.PlayerData.source, coords, text)
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
	alertAmbulance(src, text or locale('info.civ_down'))
end)

RegisterNetEvent('hospital:server:emergencyAlert', function()
	if GetInvokingResource() then return end
	local src = source
	local player = exports.qbx_core:GetPlayer(src)
	alertAmbulance(src, locale('info.ems_down', player.PlayerData.charinfo.lastname))
end)

RegisterNetEvent('qbx_medical:server:onPlayerLaststand', function()
	if GetInvokingResource() then return end
	local src = source
	alertAmbulance(src, locale('info.civ_down'))
end)

---@param playerId number
RegisterNetEvent('hospital:server:TreatWounds', function(playerId)
	if GetInvokingResource() then return end
	local src = source
	local player = exports.qbx_core:GetPlayer(src)
	local patient = exports.qbx_core:GetPlayer(playerId)
	if player.PlayerData.job.type ~= 'ems' or not patient then return end

	exports.ox_inventory:RemoveItem(src, 'bandage', 1)
	TriggerClientEvent('hospital:client:HealInjuries', patient.PlayerData.source, 'full')
end)

---@param playerId number
RegisterNetEvent('hospital:server:RevivePlayer', function(playerId)
	if GetInvokingResource() then return end
	local player = exports.qbx_core:GetPlayer(source)
	local patient = exports.qbx_core:GetPlayer(playerId)

	if not patient then return end

	exports.ox_inventory:RemoveItem(player.PlayerData.source, 'firstaid', 1)
	TriggerClientEvent('qbx_medical:client:playerRevived', patient.PlayerData.source)
end)

---@param targetId number
RegisterNetEvent('hospital:server:UseFirstAid', function(targetId)
	if GetInvokingResource() then return end
	local src = source
	local target = exports.qbx_core:GetPlayer(targetId)
	if not target then return end

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
	alertAmbulance(src, locale('info.civ_died'))
end)

---EMS worker heals patient with bandage and gets paid
---@param patientId number
RegisterNetEvent('hospital:server:EmsHealPatient', function(patientId)
	if GetInvokingResource() then return end
	local src = source
	local emsPlayer = exports.qbx_core:GetPlayer(src)
	local patient = exports.qbx_core:GetPlayer(patientId)

	-- Verify EMS worker
	if not emsPlayer or emsPlayer.PlayerData.job.type ~= 'ems' then
		return
	end

	-- Verify patient exists
	if not patient then
		exports.qbx_core:Notify(src, 'Patient not found', 'error')
		return
	end

	-- Check if EMS has bandages
	if exports.ox_inventory:Search(src, 'count', 'bandage') == 0 then
		exports.qbx_core:Notify(src, 'You need bandages to heal the patient', 'error')
		return
	end

	-- Remove bandage from EMS worker
	exports.ox_inventory:RemoveItem(src, 'bandage', 1)

	-- Calculate healing amount (25% of max health)
	local currentHealth = GetEntityHealth(GetPlayerPed(patientId))
	local maxHealth = 200 -- Standard max health
	local healAmount = math.floor(maxHealth * (sharedConfig.bandageHealAmount / 100))
	local newHealth = math.min(currentHealth + healAmount, maxHealth)

	-- Heal the patient
	SetEntityHealth(GetPlayerPed(patientId), newHealth)
	TriggerClientEvent('qbx_medical:client:heal', patientId, 'partial')

	-- Pay the EMS worker
	emsPlayer.Functions.AddMoney('cash', sharedConfig.bandagePayment, 'ems-patient-heal')

	-- Notify both players
	exports.qbx_core:Notify(src, ('Patient healed successfully! You earned $%d'):format(sharedConfig.bandagePayment), 'success')
	exports.qbx_core:Notify(patientId, 'You have been treated by a paramedic', 'success')
end)

---EMS worker revives patient with firstaid and gets paid
---@param patientId number
RegisterNetEvent('hospital:server:EmsRevivePatient', function(patientId)
	if GetInvokingResource() then return end
	local src = source
	local emsPlayer = exports.qbx_core:GetPlayer(src)
	local patient = exports.qbx_core:GetPlayer(patientId)

	-- Verify EMS worker
	if not emsPlayer or emsPlayer.PlayerData.job.type ~= 'ems' then
		return
	end

	-- Verify patient exists
	if not patient then
		exports.qbx_core:Notify(src, 'Patient not found', 'error')
		return
	end

	-- Check if EMS has firstaid
	if exports.ox_inventory:Search(src, 'count', 'firstaid') == 0 then
		exports.qbx_core:Notify(src, 'You need firstaid to revive the patient', 'error')
		return
	end

	-- Remove firstaid from EMS worker
	exports.ox_inventory:RemoveItem(src, 'firstaid', 1)

	-- Revive the patient
	TriggerClientEvent('qbx_medical:client:playerRevived', patientId)

	-- Pay the EMS worker
	emsPlayer.Functions.AddMoney('cash', sharedConfig.firstaidPayment, 'ems-patient-revival')

	-- Notify both players
	exports.qbx_core:Notify(src, ('Patient revived successfully! You earned $%d'):format(sharedConfig.firstaidPayment), 'success')
	exports.qbx_core:Notify(patientId, 'You have been revived by a paramedic', 'success')
end)

-- Death UI and EMS Signal System
local activeSignals = {} -- Store active patient signals

---Player sends EMS signal when dead
RegisterNetEvent('ambulance:server:sendEMSSignal', function()
	if GetInvokingResource() then return end
	local src = source
	local player = exports.qbx_core:GetPlayer(src)

	debugPrint("Received EMS signal from player", src)
	if not player then
		debugPrint("Player not found")
		return
	end

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
		local notificationText = sharedConfig.deathUI.texts.emsNotification:format(playerName)
		debugPrint("Sending notification:", notificationText)

		for i = 1, #emsPlayers do
			local emsId = emsPlayers[i]
			debugPrint("Sending alert to EMS", emsId)

			-- Send ox_lib notification
			TriggerClientEvent('ox_lib:notify', emsId, {
				title = 'EMS ALERT',
				description = notificationText,
				type = 'inform',
				position = 'bottom-right',
				duration = 8000,
				style = {
					backgroundColor = '#8b45c1',
					color = '#ffffff',
					['.description'] = {
						color = '#ffffff'
					}
				}
			})
			TriggerClientEvent('ambulance:client:playEMSAlert', emsId)

			-- Create flickering blip on map
			TriggerClientEvent('ambulance:client:createPatientBlip', emsId, src, playerName, coords)
		end
		exports.qbx_core:Notify(src, 'Сигнал изпратен към EMS служителите', 'success')
	else
		debugPrint("No EMS workers online")
		exports.qbx_core:Notify(src, 'Няма налични EMS служители', 'error')
	end
end)

---Player respawns (clears their signal)
RegisterNetEvent('ambulance:server:respawnPlayer', function()
	if GetInvokingResource() then return end
	local src = source

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
	local player = exports.qbx_core:GetPlayer(src)
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

---EMS heals patient with bandage (gets paid)
RegisterNetEvent('hospital:server:EmsHealPatient', function(patientId)
	if GetInvokingResource() then return end
	local src = source
	local emsPlayer = exports.qbx_core:GetPlayer(src)
	local patient = exports.qbx_core:GetPlayer(patientId)

	debugPrint("EMS", src, "healing patient", patientId, "with bandage")

	if not emsPlayer or not patient then
		debugPrint("Player not found - EMS:", emsPlayer ~= nil, "Patient:", patient ~= nil)
		return
	end

	-- Check if EMS worker
	if emsPlayer.PlayerData.job.type ~= 'ems' then
		debugPrint("Player", src, "is not EMS worker")
		return
	end

	-- Remove bandage from EMS inventory
	if not exports.ox_inventory:RemoveItem(src, 'bandage', 1) then
		exports.qbx_core:Notify(src, 'You need a bandage to heal the patient', 'error')
		return
	end

	-- Heal the patient
	local patientPed = GetPlayerPed(patientId)
	local currentHealth = GetEntityHealth(patientPed)
	local newHealth = math.min(200, currentHealth + (sharedConfig.bandageHealAmount * 2)) -- Convert percentage to health points

	SetEntityHealth(patientPed, newHealth)
	TriggerClientEvent('qbx_medical:client:onPlayerHeal', patientId, newHealth)

	-- Pay EMS worker
	exports.qbx_core:AddMoney(src, 'cash', sharedConfig.bandagePayment, 'EMS healing payment')

	-- Notifications
	exports.qbx_core:Notify(src, 'Patient healed successfully. Payment: $' .. sharedConfig.bandagePayment, 'success')
	exports.qbx_core:Notify(patientId, 'You have been treated by EMS', 'success')

	debugPrint("EMS", src, "received $" .. sharedConfig.bandagePayment, "for healing patient", patientId)
end)

---EMS revives patient with firstaid (gets paid)
RegisterNetEvent('hospital:server:EmsRevivePatient', function(patientId)
	if GetInvokingResource() then return end
	local src = source
	local emsPlayer = exports.qbx_core:GetPlayer(src)
	local patient = exports.qbx_core:GetPlayer(patientId)

	debugPrint("EMS", src, "reviving patient", patientId, "with firstaid")

	if not emsPlayer or not patient then
		debugPrint("Player not found - EMS:", emsPlayer ~= nil, "Patient:", patient ~= nil)
		return
	end

	-- Check if EMS worker
	if emsPlayer.PlayerData.job.type ~= 'ems' then
		debugPrint("Player", src, "is not EMS worker")
		return
	end

	-- Check if patient is actually dead
	if not exports.qbx_medical:IsDead(patientId) then
		exports.qbx_core:Notify(src, 'Patient is not dead', 'error')
		return
	end

	-- Remove firstaid from EMS inventory
	if not exports.ox_inventory:RemoveItem(src, 'firstaid', 1) then
		exports.qbx_core:Notify(src, 'You need firstaid to revive the patient', 'error')
		return
	end

	-- Revive the patient
	TriggerClientEvent('qbx_medical:client:revive', patientId)

	-- Clear patient's signal if they have one
	if activeSignals[patientId] then
		-- Notify all EMS to remove blip
		for _, playerId in pairs(GetPlayers()) do
			local emsPlayerLoop = exports.qbx_core:GetPlayer(tonumber(playerId))
			if emsPlayerLoop and emsPlayerLoop.PlayerData.job.type == 'ems' then
				TriggerClientEvent('ambulance:client:removePatientBlip', tonumber(playerId), patientId)
			end
		end
		activeSignals[patientId] = nil
	end

	-- Pay EMS worker
	exports.qbx_core:AddMoney(src, 'cash', sharedConfig.firstaidPayment, 'EMS revival payment')

	-- Notifications
	exports.qbx_core:Notify(src, 'Patient revived successfully. Payment: $' .. sharedConfig.firstaidPayment, 'success')
	exports.qbx_core:Notify(patientId, 'You have been revived by EMS', 'success')

	debugPrint("EMS", src, "received $" .. sharedConfig.firstaidPayment, "for reviving patient", patientId)
end)

---Player gets revived (clear their signal)
RegisterNetEvent('ambulance:server:patientRevived', function(patientId)
	if GetInvokingResource() then return end

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