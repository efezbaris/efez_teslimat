local QBCore = exports['qb-core']:GetCoreObject()
local isOnDuty = false
local deliveryIndex = nil -- teslimat noktası
local teslimCount = 0 -- kaç kutu teslim edildi
local deliveryBlip = nil
local kargoVehicle = nil
local kargoNpc = nil
local hasBox = false
local boxProp = nil
local TESLIMAT_SAYISI = 5

local function AttachBoxProp()
    local ped = PlayerPedId()
    local propHash = `prop_cs_cardbox_01`
    RequestModel(propHash)
    while not HasModelLoaded(propHash) do Wait(10) end
    boxProp = CreateObject(propHash, GetEntityCoords(ped), true, true, true)
    AttachEntityToEntity(boxProp, ped, GetPedBoneIndex(ped, 57005), 0.25, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    RequestAnimDict('anim@heists@box_carry@')
    while not HasAnimDictLoaded('anim@heists@box_carry@') do Wait(10) end
    TaskPlayAnim(ped, 'anim@heists@box_carry@', 'idle', 8.0, 8.0, -1, 50, 0, false, false, false)
end

local function DetachBoxProp()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    if boxProp then
        DeleteEntity(boxProp)
        boxProp = nil
    end
end

-- Kargo alma noktası blip ve NPC
CreateThread(function()
    -- Blip
    local blip = AddBlipForCoord(Config.KargoAlmaNoktasi)
    SetBlipSprite(blip, 479)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, 5)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Kargo Görevi')
    EndTextCommandSetBlipName(blip)
    -- NPC
    RequestModel(`s_m_m_dockwork_01`)
    while not HasModelLoaded(`s_m_m_dockwork_01`) do Wait(10) end
    kargoNpc = CreatePed(4, `s_m_m_dockwork_01`, Config.KargoAlmaNoktasi.x, Config.KargoAlmaNoktasi.y, Config.KargoAlmaNoktasi.z-1, 90.0, false, true)
    FreezeEntityPosition(kargoNpc, true)
    SetEntityInvincible(kargoNpc, true)
    SetBlockingOfNonTemporaryEvents(kargoNpc, true)
    -- qb-target NPC teslim ve araç teslim
    exports['qb-target']:AddTargetEntity(kargoNpc, {
        options = {
            {
                event = 'prime-kargo:client:DeliverBox',
                icon = 'fas fa-box-open',
                label = 'Kargoyu Teslim Et',
                canInteract = function()
                    return hasBox and teslimCount < TESLIMAT_SAYISI
                end
            },
            {
                event = 'prime-kargo:client:ReturnVehicle',
                icon = 'fas fa-car',
                label = 'Aracı Teslim Et (500$ depozit geri)',
                canInteract = function()
                    return kargoVehicle ~= nil and DoesEntityExist(kargoVehicle)
                end
            },
            {
                event = 'prime-kargo:client:StartJob',
                icon = 'fas fa-box',
                label = 'Kargo Görevi Al',
                canInteract = function()
                    return not isOnDuty and not hasBox
                end
            },
        },
        distance = 2.0
    })
end)

RegisterNetEvent('prime-kargo:client:StartJob', function()
    if isOnDuty then
        QBCore.Functions.Notify('Zaten bir kargo görevin var!', 'error')
        return
    end
    deliveryIndex = math.random(1, #Config.TeslimatNoktalari)
    teslimCount = 0
    TriggerServerEvent('prime-kargo:server:StartJob', deliveryIndex)
end)

RegisterNetEvent('prime-kargo:client:JobStarted', function(deliveryIdx, spawnCoords)
    isOnDuty = true
    hasBox = false
    deliveryIndex = deliveryIdx
    teslimCount = 0
    QBCore.Functions.TriggerCallback('prime-kargo:server:TryPayDeposit', function(success)
        if not success then
            QBCore.Functions.Notify('Kargo aracı için yeterli paran yok! (500$)', 'error')
            isOnDuty = false
            deliveryIndex = nil
            teslimCount = 0
            return
        end
        QBCore.Functions.Notify('Kargo aracı için 500$ depozito ödendi.', 'primary', 7000)
        QBCore.Functions.SpawnVehicle(Config.KargoArac, function(vehicle)
            kargoVehicle = vehicle
            SetEntityAsMissionEntity(vehicle, true, true)
            -- Oyuncuyu araca bindirme kaldırıldı
            -- local playerPed = PlayerPedId()
            -- TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
            -- Araç anahtarını ver
            local vehicleProps = QBCore.Functions.GetVehicleProperties(vehicle)
            TriggerEvent("x-hotwire:give-keys", vehicle, vehicleProps.plate)
            -- Araçta qb-target ile kutu al ve kutu bırak
            exports['qb-target']:AddTargetEntity(vehicle, {
                options = {
                    {
                        event = 'prime-kargo:client:TakeBox',
                        icon = 'fas fa-box',
                        label = 'Kutu Al',
                        canInteract = function()
                            return isOnDuty and not hasBox and teslimCount < TESLIMAT_SAYISI
                        end
                    },
                    {
                        event = 'prime-kargo:client:DropBox',
                        icon = 'fas fa-box',
                        label = 'Kutu Bırak',
                        canInteract = function()
                            return isOnDuty and hasBox
                        end
                    },
                },
                distance = 2.0
            })
            -- Teslimat blip ve NPC
            local coords = Config.TeslimatNoktalari[deliveryIndex]
            deliveryBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(deliveryBlip, Config.TeslimatBlip.sprite)
            SetBlipColour(deliveryBlip, Config.TeslimatBlip.color)
            SetBlipScale(deliveryBlip, Config.TeslimatBlip.scale)
            SetBlipAsShortRange(deliveryBlip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(Config.TeslimatBlip.label)
            EndTextCommandSetBlipName(deliveryBlip)
            SetNewWaypoint(coords.x, coords.y)
            QBCore.Functions.Notify('Kargo aracı teslim edildi! Araca yaklaş ve kutu al, sonra haritada işaretli teslimat noktasına git.', 'primary', 10000)
            -- Teslimat NPC'si oluştur
            RequestModel(`s_m_m_dockwork_01`)
            while not HasModelLoaded(`s_m_m_dockwork_01`) do Wait(10) end
            local teslimNpc = CreatePed(4, `s_m_m_dockwork_01`, coords.x, coords.y, coords.z-1, 90.0, false, true)
            FreezeEntityPosition(teslimNpc, true)
            SetEntityInvincible(teslimNpc, true)
            SetBlockingOfNonTemporaryEvents(teslimNpc, true)
            exports['qb-target']:AddTargetEntity(teslimNpc, {
                options = {
                    {
                        event = 'prime-kargo:client:DeliverBox',
                        icon = 'fas fa-box-open',
                        label = 'Kargoyu Teslim Et',
                        canInteract = function()
                            return hasBox and teslimCount < TESLIMAT_SAYISI
                        end
                    },
                },
                distance = 2.0
            })
            RegisterNetEvent('prime-kargo:client:RemoveTeslimNpc', function()
                if teslimNpc then
                    DeleteEntity(teslimNpc)
                    teslimNpc = nil
                end
            end)
        end, spawnCoords, true)
    end)
end)

RegisterNetEvent('prime-kargo:client:TakeBox', function()
    if not isOnDuty or hasBox then return end
    if not kargoVehicle or not DoesEntityExist(kargoVehicle) then
        QBCore.Functions.Notify('Kargo aracı bulunamadı!', 'error')
        return
    end
    -- Bagaj pozisyonunu bul
    local trunkBone = GetEntityBoneIndexByName(kargoVehicle, 'boot')
    local trunkPos
    if trunkBone ~= -1 then
        trunkPos = GetWorldPositionOfEntityBone(kargoVehicle, trunkBone)
    else
        -- Eğer boot bone yoksa, aracın arka kısmını kullan
        local vehCoords = GetEntityCoords(kargoVehicle)
        local vehHeading = GetEntityHeading(kargoVehicle)
        local offset = GetOffsetFromEntityInWorldCoords(kargoVehicle, 0.0, -2.0, 0.0)
        trunkPos = offset
    end
    local playerPed = PlayerPedId()
    local playerPos = GetEntityCoords(playerPed)
    local dist = #(playerPos - trunkPos)
    if dist > 2.0 then
        QBCore.Functions.Notify('Kutu almak için aracın bagajına yaklaşmalısın!', 'error')
        return
    end
    -- Bagaj açık mı kontrol et
    local trunkDoorIndex = 5 -- genellikle 5 numara bagajdır
    local doorAngle = GetVehicleDoorAngleRatio(kargoVehicle, trunkDoorIndex)
    if doorAngle < 0.1 then
        QBCore.Functions.Notify('Önce aracın bagajını açmalısın!', 'error')
        return
    end
    hasBox = true
    AttachBoxProp()
    QBCore.Functions.Notify('Kutu alındı! Şimdi teslimat noktasına git ve NPC’ye teslim et.', 'success')
end)

RegisterNetEvent('prime-kargo:client:DeliverBox', function()
    if not isOnDuty or not hasBox then return end
    DetachBoxProp()
    hasBox = false
    teslimCount = teslimCount + 1
    QBCore.Functions.Notify('Kutu teslim edildi! ('..teslimCount..'/5)', 'success')
    if teslimCount < TESLIMAT_SAYISI then
        QBCore.Functions.Notify('Bir sonraki kutu için araca dönüp yeni kutu al!', 'primary', 7000)
    else
        -- Tüm kutular teslim edildi
        isOnDuty = false
        QBCore.Functions.Notify('Tüm kargoları teslim ettin! Aracı teslim etmek için depoya dön.', 'success', 10000)
        -- Depo noktası waypoint olarak işaretlensin
        SetNewWaypoint(Config.KargoAlmaNoktasi.x, Config.KargoAlmaNoktasi.y)
        QBCore.Functions.Notify('Depo haritada işaretlendi. Aracı teslim etmeyi unutma!', 'primary', 10000)
        TriggerServerEvent('prime-kargo:server:CompleteDelivery')
    end
    if deliveryBlip then RemoveBlip(deliveryBlip) deliveryBlip = nil end
end)

RegisterNetEvent('prime-kargo:client:ReturnVehicle', function()
    if hasBox or not kargoVehicle then return end
    DeleteEntity(kargoVehicle)
    kargoVehicle = nil
    isOnDuty = false
    deliveryIndex = nil
    teslimCount = 0
    QBCore.Functions.Notify('Aracı teslim ettin, 500$ depoziton geri verildi!', 'success')
    TriggerServerEvent('prime-kargo:server:ReturnDeposit')
end)

RegisterNetEvent('prime-kargo:client:DropBox', function()
    if not isOnDuty or not hasBox then return end
    DetachBoxProp()
    hasBox = false
    QBCore.Functions.Notify('Kutu araca geri bırakıldı.', 'primary')
end)