local PaymentTax = 15
local Bail = {}

RegisterNetEvent('qb-tow:server:DoBail', function(bool, vehInfo)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    local paymentMethod

    if not bool then
        if not Bail[Player.PlayerData.citizenid] then return end
        Player.Functions.AddMoney('bank', Bail[Player.PlayerData.citizenid], "tow-bail-paid")
        Bail[Player.PlayerData.citizenid] = nil
        TriggerClientEvent('ox_lib:notify', src, {description = Lang:t("success.refund_to_cash", { value = Config.BailPrice }), type = 'success'})
        return
    end

    if Player.PlayerData.money.cash < Config.BailPrice or Player.PlayerData.money.bank < Config.BailPrice then
        TriggerClientEvent('ox_lib:notify', src, {description = Lang:t("error.no_deposit", { value = Config.BailPrice }), type = 'error'})
        return
    end

    if Player.PlayerData.money.cash >= Config.BailPrice then
        paymentMethod = 'cash'
    else
        paymentMethod = 'bank'
    end

    Bail[Player.PlayerData.citizenid] = Config.BailPrice
    Player.Functions.RemoveMoney(paymentMethod, Config.BailPrice, "tow-paid-bail")
    TriggerClientEvent('ox_lib:notify', src, {description = Lang:t("success.paid_with_" .. paymentMethod, { value = Config.BailPrice }), type = 'success'})
    TriggerClientEvent('qb-tow:client:SpawnVehicle', src, vehInfo)
end)

RegisterNetEvent('qb-tow:server:nano', function(vehNetID)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    local targetVehicle = NetworkGetEntityFromNetworkId(vehNetID)
    if not Player then return end

    local playerPed = GetPlayerPed(src)
    local playerVehicle = GetVehiclePedIsIn(playerPed, true)
    local playerVehicleCoords = GetEntityCoords(playerVehicle)
    local targetVehicleCoords = GetEntityCoords(targetVehicle)
    local dist = #(playerVehicleCoords - targetVehicleCoords)
    if Player.PlayerData.job.name ~= "tow" or dist > 15.0 then
        return DropPlayer(src, Lang:t("info.skick"))
    end

    local chance = math.random(1, 100)
    if chance >= 26 then return end
    Player.Functions.AddItem("cryptostick", 1, false)
end)

RegisterNetEvent('qb-tow:server:11101110', function(drops)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    if not Player then return end

    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    if Player.PlayerData.job.name ~= "tow" or #(playerCoords - vec3(Config.Locations["main"].coords.x, Config.Locations["main"].coords.y, Config.Locations["main"].coords.z)) > 6.0 then
        return DropPlayer(src, Lang:t("info.skick"))
    end

    drops = tonumber(drops)
    local bonus = 0
    local DropPrice = math.random(150, 170)
    if drops > 5 then
        if drops > 20 then drops = 20 end
        bonus = math.ceil((DropPrice / 10) * ((3 * (drops / 5)) + 2))
    end
    local price = (DropPrice * drops) + bonus
    local taxAmount = math.ceil((price / 100) * PaymentTax)
    local payment = price - taxAmount

    Player.Functions.AddJobReputation(1)
    Player.Functions.AddMoney("bank", payment, "tow-salary")
    TriggerClientEvent('ox_lib:notify', src, {description = Lang:t("success.you_earned", { value = payment }), type = 'success'})
end)

lib.addCommand('npc', {
    help = Lang:t("info.toggle_npc"),
}, function(source)
    TriggerClientEvent("jobs:client:ToggleNpc", source)
end)

lib.addCommand('tow', {
    help = Lang:t("info.tow"),
}, function(source)
    local Player = exports.qbx_core:GetPlayer(source)
    if Player.PlayerData.job.name ~= "tow" and Player.PlayerData.job.name ~= "mechanic" then return end
    TriggerClientEvent("qb-tow:client:TowVehicle", source)
end)

lib.callback.register('qb-tow:server:spawnVehicle', function(source, model, coords, warp)
    local netId = SpawnVehicle(source, model, coords, warp)
    if not netId or netId == 0 then return end
    return netId
end)
