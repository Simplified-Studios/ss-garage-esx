OutsideVehicles = {}

RegisterNetEvent('ss-garage:server:openGarage', function(garage)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local vehicles

    if Config.realisticGarages then
        vehicles = MySQL.query.await('SELECT * FROM owned_vehicles WHERE owner = ? AND parking = ?', { xPlayer.identifier, garage })
    else
        vehicles = MySQL.query.await('SELECT * FROM owned_vehicles WHERE owner = ?', { xPlayer.identifier })
    end
    
    if not vehicles[1] then
        xPlayer.showNotification("You don't have any vehicles in this garage")
        return
    end

    TriggerClientEvent('ss-garage:client:openGarage', source, vehicles, garage)
end)

RegisterNetEvent('ss-garage:server:checkPlayerForVeh', function(data)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local vehicle = MySQL.query.await('SELECT * FROM owned_vehicles WHERE owner = ? AND plate = ?', { xPlayer.identifier, data.plate })

    if not vehicle[1] then
        xPlayer.showNotification("You don't own this vehicle")
        return
    end

    if OutsideVehicles[vehicle[1].plate] and DoesEntityExist(OutsideVehicles[vehicle[1].plate].entity) then
        xPlayer.showNotification("You already have this vehicle out")
        return
    end

    TriggerClientEvent('ss-garage:client:takeOut', source, vehicle[1])
end)

ESX.RegisterServerCallback('ss-garages:server:spawnvehicle', function(source, cb, plate, vehicle, coords)
    local vehdata = MySQL.query.await('SELECT * FROM owned_vehicles WHERE plate = ?', { plate })
    ESX.OneSync.SpawnVehicle(vehicle, vector3(coords.x, coords.y, coords.z), coords.w, vehdata[1].vehicle, function(netid)
        local vehicle = NetworkGetEntityFromNetworkId(netid)
        Wait(300)
        SetVehicleNumberPlateText(vehicle, plate)
        TaskWarpPedIntoVehicle(GetPlayerPed(source), vehicle, -1)
        OutsideVehicles[plate] = { netID = netid, entity = vehicle }
        cb(netid, vehdata[1].vehicle, plate)
    end)
end)

ESX.RegisterServerCallback('esx_garage:checkVehicleOwner', function(source, cb, plate)
    local xPlayer = ESX.GetPlayerFromId(source)

	MySQL.query('SELECT COUNT(*) as count FROM `owned_vehicles` WHERE `owner` = @identifier AND `plate` = @plate',
	{
		['@identifier'] 	= xPlayer.identifier,
		['@plate']     		= plate
	}, function(result)

		if tonumber(result[1].count) > 0 then
			return cb(true)
		else
			return cb(false)
		end
	end)
end)

RegisterServerEvent('esx_garage:updateOwnedVehicle')
AddEventHandler('esx_garage:updateOwnedVehicle', function(stored, parking, Impound, data, spawn)
	local source = source
	local xPlayer  = ESX.GetPlayerFromId(source)
    MySQL.update('UPDATE owned_vehicles SET `stored` = @stored, `parking` = @parking, `pound` = @Impound, `vehicle` = @vehicle WHERE `plate` = @plate AND `owner` = @identifier',
    {
        ['@identifier'] = xPlayer.identifier,
        ['@vehicle'] 	= json.encode(data.vehicleProps),
        ['@plate'] 		= data.vehicleProps.plate,
        ['@stored']     = stored,
        ['@parking']    = parking,
        ['@Impound']    	= Impound
    })

    if stored then
        xPlayer.showNotification("Vehicle Stored")
    else 
        ESX.OneSync.SpawnVehicle(data.vehicleProps.model, spawn, data.spawnPoint.heading,data.vehicleProps, function(vehicle)
            local vehicle = NetworkGetEntityFromNetworkId(vehicle)
            Wait(300)
            TaskWarpPedIntoVehicle(GetPlayerPed(source), vehicle, -1)
        end)
    end
end)

RegisterNetEvent('ss-garage:server:swapVehicle', function(data)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local vehicle = MySQL.query.await('SELECT * FROM owned_vehicles WHERE owner = ? AND plate = ?', { xPlayer.identifier, data.vehicle.plate })

    if not vehicle[1] then
        xPlayer.showNotification("You don't own this vehicle")
        return
    end

    if OutsideVehicles[vehicle[1].plate] and DoesEntityExist(OutsideVehicles[vehicle[1].plate].entity) then
        xPlayer.showNotification("This vehicle is already out")
        return
    end

    xPlayer.showNotification("You swapped the vehicle to "..data.garage)
    exports['oxmysql']:execute('UPDATE owned_vehicles SET parking = ? WHERE plate = ?', { data.garage, data.vehicle.plate })
end)

RegisterNetEvent('ss-garage:server:transferVehicle', function(data)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local vehicle = MySQL.query.await('SELECT * FROM owned_vehicles WHERE owner = ? AND plate = ?', { xPlayer.identifier, data.vehicle.plate })

    if not vehicle[1] then
        xPlayer.showNotification("You don't own this vehicle")
        return
    end

    if OutsideVehicles[vehicle[1].plate] and DoesEntityExist(OutsideVehicles[vehicle[1].plate].entity) then
        xPlayer.showNotification("This vehicle is already out")
        return
    end

    local target = ESX.GetPlayerFromId(data.id)

    if not target then
        xPlayer.showNotification("This player is not online")
        return
    end

    exports['oxmysql']:execute('UPDATE owned_vehicles SET owner = ? WHERE plate = ?', { target.identifier, data.vehicle.plate })
    xPlayer.showNotification("You transferred the vehicle to "..target.name)
    target.showNotification("You received a vehicle from "..xPlayer.name)
end)