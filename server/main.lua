local config = require 'config.server'
local sharedConfig = require 'config.shared'
local Bail = {}

RegisterNetEvent('qb-tow:server:DoBail', function(bool, vehInfo)
    local Player = exports.qbx_core:GetPlayer(source)
    local paymentMethod

    if not bool then
        if not Bail[Player.PlayerData.citizenid] then return end
        Player.Functions.AddMoney('bank', Bail[Player.PlayerData.citizenid], "tow-bail-paid")
        Bail[Player.PlayerData.citizenid] = nil
        exports.qbx_core:Notify(source, locale("success.refund_to_cash", config.bailPrice), 'success')
        return
    end

    if Player.PlayerData.money.cash < config.bailPrice or Player.PlayerData.money.bank < config.bailPrice then
        exports.qbx_core:Notify(source, locale("error.no_deposit", config.bailPrice), 'error')
        return
    end

    if Player.PlayerData.money.cash >= config.bailPrice then
        paymentMethod = 'cash'
    else
        paymentMethod = 'bank'
    end

    Bail[Player.PlayerData.citizenid] = config.bailPrice
    Player.Functions.RemoveMoney(paymentMethod, config.bailPrice, "tow-paid-bail")
    exports.qbx_core:Notify(source, locale("success.paid_with_" .. paymentMethod, config.bailPrice), 'success')
    TriggerClientEvent('qb-tow:client:SpawnVehicle', source, vehInfo)
end)

RegisterNetEvent('qb-tow:server:11101110', function(drops)
    local Player = exports.qbx_core:GetPlayer(source)
    if not Player then return end

    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)
    if Player.PlayerData.job.name ~= "tow" or #(playerCoords - vec3(sharedConfig.locations["main"].coords.x, sharedConfig.locations["main"].coords.y, sharedConfig.locations["main"].coords.z)) > 6.0 then
        return DropPlayer(source, locale("info.skick"))
    end

    drops = tonumber(drops)
    local bonus = 0
    local DropPrice = math.random(150, 170)
    if drops > 5 then
        if drops > 20 then drops = 20 end
        bonus = math.ceil((DropPrice / 10) * ((3 * (drops / 5)) + 2))
    end
    local price = (DropPrice * drops) + bonus
    local taxAmount = math.ceil((price / 100) * config.paymentTax)
    local payment = price - taxAmount

    Player.Functions.AddJobReputation(1)
    Player.Functions.AddMoney("bank", payment, "tow-salary")
    exports.qbx_core:Notify(source, locale("success.you_earned", payment), 'success')
end)

lib.addCommand('npc', {
    help = locale("info.toggle_npc"),
}, function(source)
    TriggerClientEvent("jobs:client:ToggleNpc", source)
end)

lib.addCommand('tow', {
    help = locale("info.tow"),
}, function(source)
    local Player = exports.qbx_core:GetPlayer(source)
    if Player.PlayerData.job.name ~= "tow" and Player.PlayerData.job.name ~= "mechanic" then return end
    TriggerClientEvent("qb-tow:client:TowVehicle", source)
end)

lib.callback.register('qb-tow:server:spawnVehicle', function(source, model, coords, warp)
    local warpPed = warp and GetPlayerPed(source)
    local netId = qbx.spawnVehicle({model = model, spawnSource = coords, warp = warpPed})
    if not netId or netId == 0 then return end
    return netId
end)
