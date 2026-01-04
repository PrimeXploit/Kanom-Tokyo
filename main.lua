local SettingsPlace = {
    ["71793674075007"] = "https://raw.githubusercontent.com/PrimeXploit/script/main/script/kanom-tokyo.lua"
}

local SettingsGame = {
    ["6161049307"] = "https://raw.githubusercontent.com/PrimeXploit/script/main/script/pixel-blade.lua"
}

local PlaceId = tostring(game.PlaceId)
local GameId = tostring(game.GameId)
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local scriptUrl = SettingsPlace[PlaceId] or SettingsGame[GameId]

if scriptUrl then
    local success, err = pcall(function()
        local code = game:HttpGet(scriptUrl)
        if code and #code > 0 then
            loadstring(code)()
        else
            warn("Empty response from:", scriptUrl)
        end
    end)
    if not success then
        warn("Script error:", err)
    end
else
    Player:Kick("This script isn't supported yet")
end
