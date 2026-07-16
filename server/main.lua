local config = require 'config.server'
local sharedConfig = require 'config.shared'
local Bail = {}
local activeJobs = {}
local completedJobs = {}

local function isTowDriver(player)
    return player and player.PlayerData.job.name == 'tow'
end

local function isAllowedTowTruck(model)
    if type(model) ~= 'string' then return false end
    for i = 1, #config.allowedVehicleModels do
        if model:lower() == config.allowedVehicleModels[i]:lower() then return true end
    end
    return false
end

local function getCoords(coords)
    if type(coords) ~= 'table' and type(coords) ~= 'vector3' and type(coords) ~= 'vector4' then return end
    local x = tonumber(coords.x or coords[1])
    local y = tonumber(coords.y or coords[2])
    local z = tonumber(coords.z or coords[3])
    if not x or not y or not z then return end
    return vec3(x, y, z)
end

local function getTowspot(model, coords)
    if type(model) ~= 'string' then return end
    for index, towspot in ipairs(sharedConfig.locations.towspots) do
        if model:lower() == towspot.model:lower() and #(coords - towspot.coords) <= 5.0 then
            return index, towspot
        end
    end
end

RegisterNetEvent('qb-tow:server:DoBail', function(takeBail, vehInfo)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not isTowDriver(player) or type(takeBail) ~= 'boolean' then return end

    local ped = GetPlayerPed(src)
    if ped == 0 or #(GetEntityCoords(ped) - sharedConfig.locations.vehicle.coords.xyz) > 8.0 then return end

    local citizenid = player.PlayerData.citizenid
    if not takeBail then
        if not Bail[citizenid] then return end
        player.Functions.AddMoney('bank', Bail[citizenid], 'tow-bail-paid')
        Bail[citizenid] = nil
        TriggerClientEvent('ox_lib:notify', src, {
            id = 'bail_pay',
            title = 'Job Payment',
            description = locale('success.refund_to_cash', config.bailPrice),
            showDuration = true,
            position = 'center-right',
            icon = 'check',
            iconColor = '#49c530'
        })
        return
    end

    if Bail[citizenid] or not isAllowedTowTruck(vehInfo) then return end

    local paymentMethod
    if player.PlayerData.money.cash >= config.bailPrice then
        paymentMethod = 'cash'
    elseif player.PlayerData.money.bank >= config.bailPrice then
        paymentMethod = 'bank'
    else
        TriggerClientEvent('ox_lib:notify', src, {
            id = 'tow_pay',
            title = 'Job Payment',
            description = locale('error.no_deposit', config.bailPrice),
            showDuration = true,
            position = 'center-right',
            icon = 'ban',
            iconColor = '#C53030'
        })
        return
    end

    if not player.Functions.RemoveMoney(paymentMethod, config.bailPrice, 'tow-paid-bail') then return end
    Bail[citizenid] = config.bailPrice
    TriggerClientEvent('ox_lib:notify', src, {
        id = 'bail_pay',
        title = 'Job Payment',
        description = locale('success.paid_with_' .. paymentMethod, config.bailPrice),
        showDuration = true,
        position = 'center-right',
        icon = 'check',
        iconColor = '#49c530'
    })
    TriggerClientEvent('qb-tow:client:SpawnVehicle', src)
end)

RegisterNetEvent('qb-tow:server:11101110', function()
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local drops = completedJobs[src] or 0
    if not isTowDriver(player) or drops < 1 then return end

    local playerPed = GetPlayerPed(src)
    if playerPed == 0 or #(GetEntityCoords(playerPed) - sharedConfig.locations.main.coords.xyz) > 6.0 then return end

    completedJobs[src] = nil
    drops = math.min(drops, 20)
    local bonus = 0
    local dropPrice = math.random(150, 170)
    if drops > 5 then
        bonus = math.ceil((dropPrice / 10) * ((3 * (drops / 5)) + 2))
    end
    local price = (dropPrice * drops) + bonus
    local payment = price - math.ceil((price / 100) * config.paymentTax)

    player.Functions.AddJobReputation(1)
    player.Functions.AddMoney('bank', payment, 'tow-salary')
    TriggerClientEvent('ox_lib:notify', src, {
        id = 'tow_pay',
        title = 'Job Payment',
        description = locale('success.you_earned', payment),
        showDuration = true,
        position = 'center-right',
        icon = 'check',
        iconColor = '#49c530'
    })
end)

lib.addCommand('npc', {help = locale('info.toggle_npc')}, function(source)
    TriggerClientEvent('jobs:client:ToggleNpc', source)
end)

lib.addCommand('tow', {help = locale('info.tow')}, function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player or player.PlayerData.job.name ~= 'tow' and player.PlayerData.job.name ~= 'mechanic' then return end
    TriggerClientEvent('qb-tow:client:TowVehicle', source)
end)

lib.callback.register('qb-tow:server:spawnVehicle', function(source, model, coords, warp)
    local player = exports.qbx_core:GetPlayer(source)
    local spawnCoords = getCoords(coords)
    if not isTowDriver(player) or not spawnCoords then return end

    if warp then
        if warp ~= true or not Bail[player.PlayerData.citizenid] or not isAllowedTowTruck(model) then return end
        if #(spawnCoords - sharedConfig.locations.vehicle.coords.xyz) > 5.0 then return end

        local netId = qbx.spawnVehicle({model = model, spawnSource = sharedConfig.locations.vehicle.coords, warp = GetPlayerPed(source)})
        return netId
    end

    local activeJob = activeJobs[source]
    if activeJob then
        local activeVehicle = NetworkGetEntityFromNetworkId(activeJob.netId)
        if activeJob.expiresAt > os.time() and DoesEntityExist(activeVehicle) then return end
        activeJobs[source] = nil
    end
    local towspotIndex, towspot = getTowspot(model, spawnCoords)
    if not towspot or #(GetEntityCoords(GetPlayerPed(source)) - towspot.coords) > 60.0 then return end

    local netId, vehicle = qbx.spawnVehicle({model = towspot.model, spawnSource = towspot.coords})
    if not netId or netId == 0 or not vehicle or vehicle == 0 then return end

    local tripDistance = #(towspot.coords - sharedConfig.locations.dropoff.coords)
    activeJobs[source] = {
        netId = netId,
        model = towspot.model,
        towspot = towspotIndex,
        earliestCompletion = os.time() + math.max(30, math.floor(tripDistance / 40)),
        expiresAt = os.time() + 1800,
    }
    return netId
end)

lib.callback.register('qb-tow:server:completeTow', function(source, netId)
    local player = exports.qbx_core:GetPlayer(source)
    local job = activeJobs[source]
    if not isTowDriver(player) or not job or math.type(netId) ~= 'integer' or netId ~= job.netId then return false end
    if os.time() < job.earliestCompletion then return false end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    local ped = GetPlayerPed(source)
    if not DoesEntityExist(vehicle) or ped == 0 then return false end
    if GetEntityModel(vehicle) ~= joaat(job.model) then return false end
    if #(GetEntityCoords(vehicle) - sharedConfig.locations.dropoff.coords) > 25.0 then return false end
    if #(GetEntityCoords(ped) - sharedConfig.locations.dropoff.coords) > 30.0 then return false end

    activeJobs[source] = nil
    completedJobs[source] = (completedJobs[source] or 0) + 1
    DeleteEntity(vehicle)
    return true
end)

AddEventHandler('playerDropped', function()
    activeJobs[source] = nil
    completedJobs[source] = nil
end)
