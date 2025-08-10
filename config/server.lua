return {
    doctorCallCooldown = 1, -- Time in minutes for cooldown between doctors calls
    wipeInvOnRespawn = true, -- Enable to disable removing all items from player on respawn
    depositSociety = function(society, amount)
        -- Use QBox society system (if available) or disable society deposits
        if GetResourceState('qbx_management') == 'started' then
            exports.qbx_management:AddMoney(society, amount)
        else
            -- Fallback: Could implement alternative society system or disable
            print('Society deposit not available - QBox management not found')
        end
    end
}