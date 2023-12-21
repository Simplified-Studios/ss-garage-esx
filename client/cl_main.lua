RegisterNetEvent('ss-garage:client:openGarage', function(data, garage)
    local vehicles = {}
    for k,v in pairs(data) do
        vehicles[#vehicles +1 ] = {
            model = GetDisplayNameFromVehicleModel(json.decode(v.vehicle).model),
            plate = v.plate,
            props = v.vehicle,
            stored = v.stored,
            impounded = v.pund,
            fuel = Round(json.decode(v.vehicle).fuelLevel, 1) or 100,
            engine = Round(json.decode(v.vehicle).engineHealth, 1) / 10 or 1000,
            body = Round(json.decode(v.vehicle).bodyHealth, 1) / 10 or 1000,
        }
        TriggerServerEvent('ss-garage:server:checkVehicleState', v.vehicle)
    end
    SendNUIMessage({
        type = "open",
        vehicles = vehicles,
        garages = Config.Garages,
        garageindex = garage,
    })
    SetNuiFocus(true, true)
end)

RegisterNetEvent('ss-garage:client:takeOut', function(data)
    local location = GetSpawnPoint(LastMarker)
    if not location then return end
    local vehdata = json.decode(data.vehicle)
    ESX.TriggerServerCallback('ss-garages:server:spawnvehicle', function(netId, properties, vehPlate)
        while not NetworkDoesNetworkIdExist(netId) do Wait(10) end
        local veh = NetworkGetEntityFromNetworkId(netId)
        SetVehicleProperties(veh, properties)
        doCarDamage(veh, {engine = vehdata.engineHealth, fuel = vehdata.fuelLevel, body = vehdata.bodyHealth}, properties)
        SetVehicleEngineOn(veh, true, true, false)
    end, data.plate, vehdata.model, location)
end)

RegisterNUICallback('takeOut', function(data, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent('ss-garage:server:checkPlayerForVeh', data.vehicle)
    cb('ok')
end)

RegisterNUICallback('transfer', function(data, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent('ss-garage:server:transferVehicle', data)
    cb('ok')
end)

RegisterNUICallback('swap', function(data, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent('ss-garage:server:swapVehicle', data)
    cb('ok')
end)

RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

local garageZones = {}
local blips = {}
CreateThread(function()
    for index, garage in pairs(Config.Garages) do
        if garage.showBlip then
            blips[index] = AddBlipForCoord(garage.takeVehicle)
            SetBlipSprite(blips[index], garage.blipNumber)
            SetBlipDisplay(blips[index], 4)
            SetBlipScale(blips[index], 0.7)
            SetBlipColour(blips[index], garage.blipColor)
            SetBlipAsShortRange(blips[index], true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(garage.blipName)
            EndTextCommandSetBlipName(blips[index])
        end
    end
end)

AddEventHandler('esx_garage:hasEnteredMarker', function(name, part)
    if part == 'takeVehicle' then
        local isInVehicle = IsPedInAnyVehicle(ESX.PlayerData.ped, false)
        local garage = Config.Garages[name]
        thisGarage = garage

        if isInVehicle then
            ESX.TextUI("Press ~INPUT_CONTEXT~ to ~y~park~s~ your vehicle")
        else
            ESX.TextUI("Press ~INPUT_CONTEXT~ to ~y~take out~s~ a vehicle")
        end
    end
end)

AddEventHandler('esx_garage:hasExitedMarker', function()
    thisGarage = nil
    thisPound = nil
    ESX.HideUI()
    TriggerEvent('esx_garage:closemenu')
end)

-- Display markers
CreateThread(function()
    while true do
        local sleep = 1000
        local playerPed = ESX.PlayerData.ped
        local coords = GetEntityCoords(playerPed)
        local inVehicle = IsPedInAnyVehicle(playerPed, false)

        for k, v in pairs(Config.Garages) do
            if (#(coords - vector3(v.takeVehicle.x, v.takeVehicle.y, v.takeVehicle.z)) < 10) then
                sleep = 0
                break
            end
        end
        if sleep == 0 then
            nearMarker = true
        else
            nearMarker = false
        end
        Wait(sleep)
    end
end)

-- Enter / Exit marker events (parking)
CreateThread(function()
    while true do
        if nearMarker then
            local playerPed = ESX.PlayerData.ped
            local coords = GetEntityCoords(playerPed)
            local isInMarker = false
            local currentMarker = nil
            local currentPart = nil

            for k, v in pairs(Config.Garages) do
                if (#(coords - vector3(v.takeVehicle.x, v.takeVehicle.y, v.takeVehicle.z)) < 10) then
                    isInMarker = true
                    currentMarker = k
                    currentPart = 'takeVehicle'
                    local isInVehicle = IsPedInAnyVehicle(playerPed, false)

                    if not isInVehicle then
                        if IsControlJustReleased(0, 38) then
                            TriggerServerEvent('ss-garage:server:openGarage', currentMarker)
                        end
                    end
                    if isInVehicle then
                        if IsControlJustReleased(0, 38) then
                            local vehicle = GetVehiclePedIsIn(playerPed, false)
                            local vehicleProps = GetVehicleProperties(vehicle)
                            ESX.TriggerServerCallback('esx_garage:checkVehicleOwner', function(owner)
                                if owner then
                                    ESX.Game.DeleteVehicle(vehicle)
                                    TriggerServerEvent('esx_garage:updateOwnedVehicle', true, currentMarker, nil, {vehicleProps = vehicleProps})
                                else
                                    ESX.ShowNotification("this isn't ur vehicle", 'error')
                                end
                            end, vehicleProps.plate)
                        end
                    end
                    break
                end
            end

            if isInMarker and not HasAlreadyEnteredMarker or
                (isInMarker and (LastMarker ~= currentMarker or LastPart ~= currentPart)) then

                if LastMarker ~= currentMarker or LastPart ~= currentPart then
                    TriggerEvent('esx_garage:hasExitedMarker')
                end

                HasAlreadyEnteredMarker = true
                LastMarker = currentMarker
                LastPart = currentPart

                TriggerEvent('esx_garage:hasEnteredMarker', currentMarker, currentPart)
            end

            if not isInMarker and HasAlreadyEnteredMarker then
                HasAlreadyEnteredMarker = false

                TriggerEvent('esx_garage:hasExitedMarker')
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)
