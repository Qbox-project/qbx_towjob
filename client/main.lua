local config = require 'config.client'
local sharedConfig = require 'config.shared'
local PlayerJob = {}
local JobsDone = 0
local NpcOn = false
local CurrentLocation = {}
local CurrentBlip = nil
local LastVehicle = 0
local VehicleSpawned = false
local selectedVeh = nil
local showMarker = false
local CurrentBlip2 = nil
local CurrentTow = nil
local drawDropOff = false

-- Functions

local function getRandomVehicleLocation()
    local randomVehicle = math.random(1, #sharedConfig.locations["towspots"])
    while randomVehicle == LastVehicle do
        Wait(10)
        randomVehicle = math.random(1, #sharedConfig.locations["towspots"])
    end
    return randomVehicle
end

local function drawDropOffMarker()
    CreateThread(function()
        while drawDropOff do
            DrawMarker(2, sharedConfig.locations["dropoff"].coords.x, sharedConfig.locations["dropoff"].coords.y, sharedConfig.locations["dropoff"].coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.15, 200, 0, 0, 222, false, false, 0, true, false, false, false)
            Wait(0)
        end
    end)
end

local function getVehicleInDirection(coordFrom, coordTo)
	local rayHandle = CastRayPointToPoint(coordFrom.x, coordFrom.y, coordFrom.z, coordTo.x, coordTo.y, coordTo.z, 10, cache.ped, 0)
	local _, _, _, _, vehicle = GetRaycastResult(rayHandle)
	return vehicle
end

local function isTowVehicle(vehicle)
    for k in pairs(config.vehicles) do
        if GetEntityModel(vehicle) == joaat(k) then
            return true
        end
    end
    return false
end

-- Old Menu Code (being removed)

local function MenuGarage()
    local towMenu = {}
    for k in pairs(config.vehicles) do
        towMenu[#towMenu + 1] = {
            title = config.vehicles[k],
            event = "qb-tow:client:TakeOutVehicle",
            args = {
                vehicle = k
            }
        }
    end

    lib.registerContext({
        id = 'tow_veh_menu',
        title = locale("menu.header"),
        options = towMenu
    })

    lib.showContext('tow_veh_menu')
end

local function CreateZone(type, number)
    local coords
    local heading
    local boxName
    local event
    local label
    local size

    if type == "main" then
        event = "qb-tow:client:PaySlip"
        label = locale("label.payslip")
        coords = sharedConfig.locations["main"].coords.xyz
        heading = sharedConfig.locations["main"].coords.w
        boxName = sharedConfig.locations["main"].label
        size = vec3(3, 3, 10)
    elseif type == "vehicle" then
        event = "qb-tow:client:Vehicle"
        label = locale("label.vehicle")
        coords = sharedConfig.locations["vehicle"].coords.xyz
        heading = sharedConfig.locations["vehicle"].coords.w
        boxName = sharedConfig.locations["vehicle"].label
        size = vec3(5, 5, 10)
    elseif type == "towspots" then
        event = "qb-tow:client:SpawnNPCVehicle"
        label = locale("label.npcz")
        coords = sharedConfig.locations[type][number].coords.xyz
        heading = sharedConfig.locations["towspots"][number].coords.w --[[@as number?]]
        boxName = sharedConfig.locations["towspots"][number].name
        size = vec3(50, 50, 10)
    end

    if config.useTarget and type == "main" then
        exports.ox_target:addBoxZone({
            name = boxName,
            coords = coords,
            size = size,
            rotation = heading,
            debug = config.debugPoly,
            options = {
                {
                    event = event,
                    label = label,
                    distance = 2,
                }
            }
        })
    else
        local zone = lib.zones.box({
            coords = coords,
            size = size,
            rotation = heading,
            debug = config.debugPoly,
            onEnter = function()
                TriggerEvent(event)
            end,
        })
        if type == "vehicle" then
            local zoneMark = lib.zones.box({
                coords = coords,
                size = vec3(20,20,10),
                rotation = heading,
                debug = config.debugPoly,
                onEnter = function()
                    TriggerEvent('qb-tow:client:ShowMarker', true)
                end,
                onExit = function()
                    TriggerEvent('qb-tow:client:ShowMarker', false)
                end
            })
            CurrentLocation.zoneCombo = zoneMark
        elseif type == "towspots" then
            CurrentLocation.zoneCombo = zone
        end
    end
end

local function deliverVehicle(vehicle)
    DeleteVehicle(vehicle)
    RemoveBlip(CurrentBlip2)
    JobsDone += 1
    VehicleSpawned = false
    exports.qbx_core:Notify(locale("mission.delivered_vehicle"), "success")
    exports.qbx_core:Notify(locale("mission.get_new_vehicle"))

    local randomLocation = getRandomVehicleLocation()
    CurrentLocation.x = sharedConfig.locations["towspots"][randomLocation].coords.x
    CurrentLocation.y = sharedConfig.locations["towspots"][randomLocation].coords.y
    CurrentLocation.z = sharedConfig.locations["towspots"][randomLocation].coords.z
    CurrentLocation.model = sharedConfig.locations["towspots"][randomLocation].model
    CurrentLocation.id = randomLocation
    CreateZone("towspots", randomLocation)

    CurrentBlip = AddBlipForCoord(CurrentLocation.x, CurrentLocation.y, CurrentLocation.z)
    SetBlipColour(CurrentBlip, 3)
    SetBlipRoute(CurrentBlip, true)
    SetBlipRouteColour(CurrentBlip, 3)
end

local function CreateElements()
    local TowBlip = AddBlipForCoord(sharedConfig.locations["main"].coords.x, sharedConfig.locations["main"].coords.y, sharedConfig.locations["main"].coords.z)
    SetBlipSprite(TowBlip, 477)
    SetBlipDisplay(TowBlip, 4)
    SetBlipScale(TowBlip, 0.6)
    SetBlipAsShortRange(TowBlip, true)
    SetBlipColour(TowBlip, 15)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(sharedConfig.locations["main"].label)
    EndTextCommandSetBlipName(TowBlip)

    local TowVehBlip = AddBlipForCoord(sharedConfig.locations["vehicle"].coords.x, sharedConfig.locations["vehicle"].coords.y, sharedConfig.locations["vehicle"].coords.z)
    SetBlipSprite(TowVehBlip, 326)
    SetBlipDisplay(TowVehBlip, 4)
    SetBlipScale(TowVehBlip, 0.6)
    SetBlipAsShortRange(TowVehBlip, true)
    SetBlipColour(TowVehBlip, 15)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(sharedConfig.locations["vehicle"].label)
    EndTextCommandSetBlipName(TowVehBlip)

    CreateZone("main")
    CreateZone("vehicle")
end
-- Events

RegisterNetEvent('qb-tow:client:SpawnVehicle', function()
    local vehicleInfo = selectedVeh
    local coords = sharedConfig.locations["vehicle"].coords
    local plate = "TOWR"..lib.string.random('1111')
    local netId = lib.callback.await('qb-tow:server:spawnVehicle', false, vehicleInfo, coords, true)
    local timeout = 100
    while not NetworkDoesEntityExistWithNetworkId(netId) and timeout > 0 do
        Wait(10)
        timeout -= 1
    end
    local veh = NetworkGetEntityFromNetworkId(netId)
    SetVehicleNumberPlateText(veh, plate)
    TriggerEvent("vehiclekeys:client:SetOwner", plate)
    SetVehicleEngineOn(veh, true, true, false)
    for i = 1, 9, 1 do
        SetVehicleExtra(veh, i, false)
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    if PlayerJob.name == "tow" then
        CreateElements()
    end
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerJob = JobInfo

    if PlayerJob.name == "tow" then
        CreateElements()
    end
end)

RegisterNetEvent('jobs:client:ToggleNpc', function()
    if QBX.PlayerData.job.name == "tow" then
        if CurrentTow then
            exports.qbx_core:Notify(locale("error.finish_work"), "error")
            return
        end
        NpcOn = not NpcOn
        if NpcOn then
            local randomLocation = getRandomVehicleLocation()
            CurrentLocation.x = sharedConfig.locations["towspots"][randomLocation].coords.x
            CurrentLocation.y = sharedConfig.locations["towspots"][randomLocation].coords.y
            CurrentLocation.z = sharedConfig.locations["towspots"][randomLocation].coords.z
            CurrentLocation.model = sharedConfig.locations["towspots"][randomLocation].model
            CurrentLocation.id = randomLocation
            CreateZone("towspots", randomLocation)

            CurrentBlip = AddBlipForCoord(CurrentLocation.x, CurrentLocation.y, CurrentLocation.z)
            SetBlipColour(CurrentBlip, 3)
            SetBlipRoute(CurrentBlip, true)
            SetBlipRouteColour(CurrentBlip, 3)
        else
            if DoesBlipExist(CurrentBlip) then
                RemoveBlip(CurrentBlip)
                CurrentLocation = {}
                CurrentBlip = nil
            end
            VehicleSpawned = false
        end
    end
end)

RegisterNetEvent('qb-tow:client:TowVehicle', function()
    local vehicle = cache.vehicle
    if isTowVehicle(vehicle) then
        if not CurrentTow then
            local coordA = GetEntityCoords(cache.ped)
            local coordB = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, -30.0, 0.0)
            local targetVehicle = getVehicleInDirection(coordA, coordB)

            if NpcOn and CurrentLocation then
                if GetEntityModel(targetVehicle) ~= joaat(CurrentLocation.model) then
                    exports.qbx_core:Notify(locale("error.vehicle_not_correct"), "error")
                    return
                end
            end

            if cache.vehicle then
                if vehicle ~= targetVehicle then
                    local towPos = GetEntityCoords(vehicle)
                    local targetPos = GetEntityCoords(targetVehicle)
                    if #(towPos - targetPos) < 11.0 then
                        if lib.progressBar({
                            duration = 5000,
                            label = locale("mission.towing_vehicle"),
                            useWhileDead = false,
                            canCancel = true,
                            disable = {
                                car = true,
                            },
                            anim = {
                                dict = 'mini@repair',
                                clip = 'fixing_a_ped'
                            },
                        }) then
                            StopAnimTask(cache.ped, "mini@repair", "fixing_a_ped", 1.0)
                            AttachEntityToEntity(targetVehicle, vehicle, GetEntityBoneIndexByName(vehicle, 'bodyshell'), 0.0, -1.5 + -0.85, 0.0 + 1.15, 0, 0, 0, true, true, false, true, 0, true)
                            FreezeEntityPosition(targetVehicle, true)
                            CurrentTow = targetVehicle
                            if NpcOn then
                                RemoveBlip(CurrentBlip)
                                exports.qbx_core:Notify(locale("mission.goto_depot"), "inform", 5000)
                                CurrentBlip2 = AddBlipForCoord(sharedConfig.locations["dropoff"].coords.x, sharedConfig.locations["dropoff"].coords.y, sharedConfig.locations["dropoff"].coords.z)
                                SetBlipColour(CurrentBlip2, 3)
                                SetBlipRoute(CurrentBlip2, true)
                                SetBlipRouteColour(CurrentBlip2, 3)
                                drawDropOff = true
                                drawDropOffMarker()
                                --remove zone
                                CurrentLocation.zoneCombo:remove()
                            end
                            exports.qbx_core:Notify(locale("mission.vehicle_towed"), "success")
                        else
                            StopAnimTask(cache.ped, "mini@repair", "fixing_a_ped", 1.0)
                            exports.qbx_core:Notify(locale("error.failed"), "error")
                        end
                    end
                end
            end
        else
            if lib.progressBar({
                duration = 5000,
                label = locale("mission.untowing_vehicle"),
                useWhileDead = false,
                canCancel = true,
                disable = {
                    car = true,
                },
                anim = {
                    dict = 'mini@repair',
                    clip = 'fixing_a_ped'
                },
            }) then
                StopAnimTask(cache.ped, "mini@repair", "fixing_a_ped", 1.0)
                FreezeEntityPosition(CurrentTow, false)
                Wait(250)
                AttachEntityToEntity(CurrentTow, vehicle, 20, -0.0, -15.0, 1.0, 0.0, 0.0, 0.0, false, false, false, false, 20, true)
                DetachEntity(CurrentTow, true, true)
                if NpcOn then
                    local targetPos = GetEntityCoords(CurrentTow)
                    if #(targetPos - vector3(sharedConfig.locations["vehicle"].coords.x, sharedConfig.locations["vehicle"].coords.y, sharedConfig.locations["vehicle"].coords.z)) < 25.0 then
                        deliverVehicle(CurrentTow)
                    end
                end
                RemoveBlip(CurrentBlip2)
                CurrentTow = nil
                drawDropOff = false
                exports.qbx_core:Notify(locale("mission.vehicle_takenoff"), "success")
            else
                StopAnimTask(cache.ped, "mini@repair", "fixing_a_ped", 1.0)
                exports.qbx_core:Notify(locale("error.failed"), "error")
            end
        end
    else
        exports.qbx_core:Notify(locale("error.not_towing_vehicle"), "error")
    end
end)

RegisterNetEvent('qb-tow:client:TakeOutVehicle', function(data)
    local coords = sharedConfig.locations["vehicle"].coords
    local ped = cache.ped
    local pos = GetEntityCoords(ped)
    if #(pos - coords.xyz) <= 5 then
        local vehicleInfo = data.vehicle
        TriggerServerEvent('qb-tow:server:DoBail', true, vehicleInfo)
        selectedVeh = vehicleInfo
    else
        exports.qbx_core:Notify(locale("error.too_far_away"), 'error')
    end
end)

RegisterNetEvent('qb-tow:client:Vehicle', function()
    local vehicle = cache.vehicle
    if not CurrentTow then
        if vehicle and isTowVehicle(vehicle) then
            DeleteVehicle(cache.vehicle)
            TriggerServerEvent('qb-tow:server:DoBail', false)
        else
            MenuGarage()
        end
    else
        exports.qbx_core:Notify(locale("error.finish_work"), "error")
    end
end)

RegisterNetEvent('qb-tow:client:PaySlip', function()
    if JobsDone > 0 then
        RemoveBlip(CurrentBlip)
        TriggerServerEvent("qb-tow:server:11101110", JobsDone)
        JobsDone = 0
        NpcOn = false
    else
        exports.qbx_core:Notify(locale("error.no_work_done"), "error")
    end
end)

RegisterNetEvent('qb-tow:client:SpawnNPCVehicle', function()
    if VehicleSpawned then return end
    local netId = lib.callback.await('qb-tow:server:spawnVehicle', false, CurrentLocation.model, vec3(CurrentLocation.x, CurrentLocation.y, CurrentLocation.z))
    local veh = NetToVeh(netId)
    SetVehicleFuelLevel(veh, 0.0)
    VehicleSpawned = true
end)

RegisterNetEvent('qb-tow:client:ShowMarker', function(active)
    if PlayerJob.name ~= "tow" then return end

    showMarker = active
end)

-- Threads

CreateThread(function()
    local sleep
    while true do
        sleep = 1000
        if showMarker then
            sleep = 0
            DrawMarker(2, sharedConfig.locations["vehicle"].coords.x, sharedConfig.locations["vehicle"].coords.y, sharedConfig.locations["vehicle"].coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.15, 200, 0, 0, 222, false, false, 0, true, false, false, false)
        end
        Wait(sleep)
    end
end)
