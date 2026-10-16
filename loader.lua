-- Clan Roller | Roblox Lua | Fluent UI | Demon Slayer RPG
-- Whitelist removed, worker auth removed, reporter removed

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local RS = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local UIS = game:GetService("UserInputService")

local Sync = RS:WaitForChild("Remotes"):WaitForChild("Sync")
local Async = RS:WaitForChild("Remotes"):WaitForChild("Async")
local Bridge = RS:WaitForChild("Remotes"):WaitForChild("Bridge")
local HttpService = game:GetService("HttpService")
local req = request or http_request or syn and syn.request

-- FILL: ganti dengan webhook Discord kamu sendiri
local WEBHOOK_URL = "https://discord.com/api/webhooks/1412635607829581834/vBAe1WPf_2DSfZx3GPqaqtc2FdYnWVO4LThDDfkxAJfzcfKyZcWHKL0QnTKxK-aPXkdp"

local queueteleport = queue_on_teleport
    or (syn and syn.queue_on_teleport)
    or (fluxus and fluxus.queue_on_teleport)
    or (electron and electron.queue_on_teleport)
    or (sentinel and sentinel.queue_on_teleport)

local fields = {"Eyes", "Hair", "Skin", "Mouth", "Nose", "Clothes", "FacialHair", "Scar1", "Scar2"}
local running = false
local rollCount = 0
local currentFamilyRolls = 0
local familyRollsDetected = false
local TARGET_CLAN = "Kamado"
local CLAN_RESTRICTION = "Kamado"
local AutoRestore = TeleportService:GetTeleportSetting("ClanAutoRestore") or false

local savedCount = TeleportService:GetTeleportSetting("ClanRollCount")
local savedClan = TeleportService:GetTeleportSetting("ClanRollerTarget")
local wasActiveRolling = TeleportService:GetTeleportSetting("ClanRollerActive")

-- hanya restore state kalau ini memang auto-resume dari rejoin aktif
if wasActiveRolling == true then
    if savedCount then rollCount = savedCount end
    if CLAN_RESTRICTION == "Any" and savedClan then TARGET_CLAN = savedClan end
else
    -- fresh execute — bersihkan sisa state sesi lama
    TeleportService:SetTeleportSetting("ClanRollerActive", false)
    TeleportService:SetTeleportSetting("ClanRollCount", 0)
    TeleportService:SetTeleportSetting("ClanRollerTarget", nil)
    rollCount = 0
end

Bridge.OnClientEvent:Connect(function(key, value)
    if key == "FamilyRolls" then
        currentFamilyRolls = tonumber(value) or 0
        familyRollsDetected = true
        print("FamilyRolls updated: " .. currentFamilyRolls)
    end
end)

local function getFamilyRolls()
    return currentFamilyRolls
end

local function notify(msg)
    Fluent:Notify({
        Title = "Clan Roller",
        Content = msg,
        Duration = 5
    })
end

local function sendWebhook(status, clanResult)
    local isSuccess = (clanResult == TARGET_CLAN)
    local data = {
        ["content"] = isSuccess and "@everyone TARGET CLAN FOUND!" or "",
        ["allowed_mentions"] = { ["parse"] = {"everyone"} },
        ["embeds"] = {{
            ["title"] = "Clan Roller Log",
            ["color"] = isSuccess and 65280 or 16711680,
            ["fields"] = {
                { ["name"] = "Player", ["value"] = LocalPlayer.Name, ["inline"] = true },
                { ["name"] = "Target Clan", ["value"] = TARGET_CLAN, ["inline"] = true },
                { ["name"] = "Rolls Used", ["value"] = tostring(rollCount), ["inline"] = true },
                { ["name"] = "Result Clan", ["value"] = clanResult or "Unknown", ["inline"] = true },
                { ["name"] = "Status", ["value"] = status, ["inline"] = true }
            },
            ["footer"] = { ["text"] = "Clan Roller" }
        }}
    }
    local json = HttpService:JSONEncode(data)
    pcall(function()
        if req then
            req({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = json })
        end
    end)
end

local function poison()
    for _, field in ipairs(fields) do
        pcall(function() Sync:InvokeServer("Character", "Customization", field, workspace) end)
        task.wait(0.05)
    end
    print("Rollbacked!")
end

local function restore()
    local idRestores = {
        {"Eyes", 1}, {"Hair", 1}, {"Mouth", 1}, {"Nose", 1},
        {"Clothes", 1}, {"Facial Hair", 0}, {"TrueScar1", 0}, {"TrueScar2", 0},
    }
    for _, r in ipairs(idRestores) do
        pcall(function() Async:FireServer("Character", "Customization", r[1], r[2]) end)
        task.wait(0.1)
    end
    local colorRestores = { {"Skin", Color3.fromRGB(200, 160, 120)} }
    for _, r in ipairs(colorRestores) do
        pcall(function() Sync:InvokeServer("Character", "Customization", r[1], r[2]) end)
        task.wait(0.1)
    end
    print("Save!")
end

local function queueSelf()
    if queueteleport then
        TeleportService:SetTeleportSetting("ClanRollCount", rollCount)
        TeleportService:SetTeleportSetting("ClanRollerTarget", TARGET_CLAN)
        TeleportService:SetTeleportSetting("ClanRollerActive", true)
        TeleportService:SetTeleportSetting("ClanAutoRestore", AutoRestore)
        -- Re-queue script dari sumber kamu sendiri
        -- FILL: ganti URL dengan raw URL script kamu (pastebin/github raw)
        queueteleport([[
            repeat task.wait() until game:IsLoaded()
            task.wait(3)
            loadstring(game:HttpGet("https://raw.githubusercontent.com/farhatsarcasm/FarhatRoller/main/loader.lua"))()
        ]])
    end
end

local function rejoin()
    queueSelf()
    task.wait(0.5)
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end

local function doRoll()
    local gotClan = false
    local clanResult = ""
    local conn
    conn = Bridge.OnClientEvent:Connect(function(key, value)
        if key == "LastName" then
            clanResult = tostring(value)
            gotClan = true
        end
    end)
    pcall(function() Sync:InvokeServer("Character", "Customization", "LastName") end)
    local waited = 0
    repeat
        task.wait(0.1)
        waited = waited + 0.1
    until gotClan or waited >= 2
    conn:Disconnect()
    return clanResult, gotClan
end

local function startRoller()
    running = true
    notify("Starting... Target: " .. TARGET_CLAN)
    print("Attempting first roll - target: " .. TARGET_CLAN)

    local firstResult = ""
    local firstSuccess = false
    local firstRollAttempts = 0

    while not firstSuccess and running do
        firstRollAttempts = firstRollAttempts + 1
        if firstRollAttempts > 10 then
            notify("First roll failed 10 times - rejoining...")
            print("First roll stuck - rejoining...")
            sendWebhook("FAILED REJOINING", "NO RESPONSE")
            rejoin()
            return
        end
        print("Attempting first roll (" .. firstRollAttempts .. "/10)...")
        poison()
        task.wait(0.5)
        familyRollsDetected = false
        local result, gotClan = doRoll()
        local waited = 0
        repeat
            task.wait(0.1)
            waited = waited + 0.1
        until familyRollsDetected or waited >= 2
        if gotClan and result ~= "" then
            firstResult = result
            firstSuccess = true
            rollCount = rollCount + 1
            print("First roll successful! Result: " .. firstResult)
            sendWebhook("FIRST ROLL", firstResult)
        else
            print("First roll failed (" .. firstRollAttempts .. "/10) - retrying...")
            notify("First roll no response (" .. firstRollAttempts .. "/10) - retrying...")
            task.wait(0.8)
        end
    end

    if not running then return end

    local remainingRolls = getFamilyRolls()
    local ROLLS_PER_SESSION = remainingRolls + 1

    notify("Hunting: " .. TARGET_CLAN .. " | Rolls this session: " .. ROLLS_PER_SESSION .. " | Total: " .. rollCount)
    print("-----------------------------------")
    print("  AUTO CLAN ROLLER")
    print("  Target: " .. TARGET_CLAN)
    print("  Rolls this session: " .. ROLLS_PER_SESSION)
    print("  Total rolls so far: " .. rollCount)
    print("-----------------------------------")

    if firstResult == TARGET_CLAN then
        sendWebhook("SUCCESS", TARGET_CLAN)
        running = false
        TeleportService:SetTeleportSetting("ClanRollerActive", false)
        TeleportService:SetTeleportSetting("ClanRollCount", 0)
        if AutoRestore then
            restore()
            task.wait(1)
            notify("GOT " .. TARGET_CLAN .. " after " .. rollCount .. " rolls! Rejoining in 3s to save!")
            print("TARGET FOUND: " .. TARGET_CLAN .. " - auto restored, rejoining in 3s...")
            task.wait(3)
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        else
            notify("GOT " .. TARGET_CLAN .. " after " .. rollCount .. " rolls! Save manually then leave!")
            print("TARGET FOUND: " .. TARGET_CLAN .. " - save manually then leave!")
        end
        return
    else
        notify("First roll: " .. firstResult .. " - " .. remainingRolls .. " rolls left")
        print("First roll wrong: " .. firstResult)
    end

    while running do
        local foundThisSession = false
        local sessionRoll = 1

        while sessionRoll < ROLLS_PER_SESSION and running do
            sessionRoll = sessionRoll + 1
            rollCount = rollCount + 1
            print("Roll #" .. rollCount .. " (session roll " .. sessionRoll .. "/" .. ROLLS_PER_SESSION .. ") - Rollbacking...")
            poison()
            task.wait(0.5)
            local rollsBefore = getFamilyRolls()
            local clanResult, gotClan = doRoll()
            local rollsAfter = getFamilyRolls()
            local rollActuallyHappened = rollsAfter < rollsBefore
            print("Result: " .. (clanResult ~= "" and clanResult or "NO RESPONSE"))
            sendWebhook("ROLL", clanResult ~= "" and clanResult or "NO RESPONSE")
            print("FamilyRolls: " .. rollsBefore .. " -> " .. rollsAfter)
            if not rollActuallyHappened and not gotClan then
                notify("Roll didn't register - rejoining...")
                print("Roll didn't register - rejoining...")
                sendWebhook("FAILED REJOINING", "Roll didn't Register")
                rejoin()
                return
            elseif clanResult == TARGET_CLAN then
                sendWebhook("SUCCESS", TARGET_CLAN)
                running = false
                foundThisSession = true
                TeleportService:SetTeleportSetting("ClanRollerActive", false)
                TeleportService:SetTeleportSetting("ClanRollCount", 0)
                if AutoRestore then
                    restore()
                    task.wait(1)
                    notify("GOT " .. TARGET_CLAN .. " after " .. rollCount .. " rolls! Rejoining in 3s to save!")
                    print("TARGET FOUND: " .. TARGET_CLAN .. " - auto save, rejoining in 3s...")
                    task.wait(3)
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                else
                    notify("GOT " .. TARGET_CLAN .. " after " .. rollCount .. " rolls! Save manually then leave!")
                    print("TARGET FOUND: " .. TARGET_CLAN .. " - save manually then leave!")
                end
                break
            elseif not gotClan then
                notify("No Bridge response - retrying...")
                print("No clan response, retrying...")
                sessionRoll = sessionRoll - 1
                rollCount = rollCount - 1
                task.wait(0.5)
            else
                notify("Got " .. clanResult .. " (" .. sessionRoll .. "/" .. ROLLS_PER_SESSION .. ") - " .. rollsAfter .. " left")
                print("Wrong clan: " .. clanResult)
                task.wait(0.5)
            end
        end

        if not foundThisSession and running then
            sendWebhook("FAILED", "No more Rolls rejoining")
            notify("All rolls used - rejoining for rollback...")
            print("Session rolls exhausted - rejoining...")
            task.wait(1)
            rejoin()
            break
        end
    end
end

local Window = Fluent:CreateWindow({
    Title = "Clan Roller",
    SubTitle = "by kindmops",
    TabWidth = 160,
    Size = UDim2.fromOffset(480, 400),
    Acrylic = true,
    Theme = "Amethyst",
})

local Tabs = {
    Character = Window:AddTab({ Title = "Character", Icon = "user" })
}

if CLAN_RESTRICTION == "Any" then
    Tabs.Character:AddParagraph({
        Title = "Clan Roller",
        Content = "Select your desired clan then press Start. Press B anytime to stop."
    })

    local ClanDropdown = Tabs.Character:AddDropdown("ClanSelect", {
        Title = "Select Target Clan",
        Description = "Choose the clan you want to roll",
        Values = {
            "Kanroji", "Iguro", "Agatsuma", "Hashibira", "Kocho", "Ubuyashiki",
            "Rengoku", "Tokito", "Haganezuka", "Shinazugawa", "Tomioka", "Himejima",
            "Kamado",
        },
        Multi = false,
        Default = TARGET_CLAN,
    })

    TARGET_CLAN = ClanDropdown.Value or TARGET_CLAN

    ClanDropdown:OnChanged(function(value)
        TARGET_CLAN = value
        print("Target clan set to: " .. TARGET_CLAN)
    end)
else
    Tabs.Character:AddParagraph({
        Title = "Locked Clan Roller",
        Content = "Locked to: " .. TARGET_CLAN
    })
end

Tabs.Character:AddParagraph({
    Title = "Clan Tiers",
    Content = "Rare: Kanroji, Iguro, Agatsuma, Hashibira, Kocho, Ubuyashiki\nEpic: Rengoku, Tokito, Haganezuka, Shinazugawa, Tomioka, Himejima\nLegendary: Kamado"
})

Tabs.Character:AddButton({
    Title = "Already have target clan",
    Description = "Skip rolling — save current clan and rejoin",
    Callback = function()
        if running then
            notify("Stop the roller first.")
            return
        end
        notify("Saving " .. TARGET_CLAN .. "...")
        restore()
        task.wait(1)
        if AutoRestore then
            notify("Saved! Rejoining in 3s...")
            task.wait(3)
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        else
            notify("Saved! Leave manually to lock it in.")
        end
    end
})

Tabs.Character:AddButton({
    Title = "Start Roller",
    Description = "Starts rolling for your selected clan",
    Callback = function()
        if running then
            notify("Roller is already running! Press B to stop.")
            return
        end
        sendWebhook("STARTED", "Started Roller")
        task.spawn(startRoller)
    end
})

Tabs.Character:AddButton({
    Title = "Stop Roller",
    Description = "Stops the roller",
    Callback = function()
        if not running then
            notify("Roller is not running.")
            return
        end
        running = false
        TeleportService:SetTeleportSetting("ClanRollerActive", false)
        TeleportService:SetTeleportSetting("ClanRollCount", 0)
        notify("Roller stopped!")
        print("Stopped by user after " .. rollCount .. " total rolls")
    end
})

Tabs.Character:AddToggle("AutoRestoreToggle", {
    Title = "Auto Save",
    Description = "Automatically save clan and rejoin when target clan is found",
    Default = AutoRestore,
    Callback = function(value)
        AutoRestore = value
        TeleportService:SetTeleportSetting("ClanAutoRestore", value)
    end
})

Tabs.Character:AddButton({
    Title = "Save",
    Description = "Manually save the current clan",
    Callback = function()
        restore()
        notify("Saved!")
        print("Manually saved")
    end
})

Tabs.Character:AddButton({
    Title = "Rollback Manually",
    Description = "Manually rollback to prevent saving",
    Callback = function()
        poison()
        notify("Rollbacked - leaving now will rollback!")
        print("Rollback manually")
    end
})

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.B then
        if not running then return end
        sendWebhook("STOPPED", "User Stopped")
        running = false
        TeleportService:SetTeleportSetting("ClanRollerActive", false)
        TeleportService:SetTeleportSetting("ClanRollCount", 0)
        notify("Roller stopped!")
        print("Stopped by user after " .. rollCount .. " total rolls")
    end
end)

if wasActiveRolling == true then
    notify("Resuming previous session - rolling for " .. TARGET_CLAN)
    print("Auto resuming for: " .. TARGET_CLAN .. " | Rolls so far: " .. rollCount)
    task.wait(1)
    task.spawn(startRoller)
end

Window:SelectTab(1)
Fluent:Notify({
    Title = "Clan Roller",
    Content = "Loaded! Select your clan and press Start.",
    Duration = 5
})
