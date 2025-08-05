local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('prime-kargo:server:StartJob', function(deliveryIndex)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    TriggerClientEvent('prime-kargo:client:JobStarted', src, deliveryIndex, Config.TeslimatAracSpawn)
end)

QBCore.Functions.CreateCallback('prime-kargo:server:TryPayDeposit', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb(false) return end
    if Player.PlayerData.money["cash"] >= 500 then
        Player.Functions.RemoveMoney('cash', 500)
        cb(true)
    else
        cb(false)
    end
end)

RegisterNetEvent('prime-kargo:server:ReturnDeposit', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    Player.Functions.AddMoney('cash', 500)
    TriggerClientEvent('QBCore:Notify', src, '500$ depoziton geri verildi!', 'success')
end)

RegisterNetEvent('prime-kargo:server:CompleteDelivery', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    -- Sadece rastgele ödül ver
    local taban = Config.TeslimatOdul.min
    local tavan = Config.TeslimatOdul.max
    local odul = math.random(taban, tavan)
    Player.Functions.AddMoney('cash', odul)
    TriggerClientEvent('QBCore:Notify', src, 'Teslimat için $'..odul..' kazandın!', 'success')
end)