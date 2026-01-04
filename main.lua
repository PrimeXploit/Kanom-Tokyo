local SettingsPlace = {
    ["71793674075007"] = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/PrimeXploit/script/refs/heads/main/script/kanom-tokyo.lua"))()'
}

local SettingsGame = {
    ["6161049307"] = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/PrimeXploit/script/refs/heads/main/script/pixel-blade.lua"))()'
}

local PlaceId = tostring(game.PlaceId)
local GameId = tostring(game.GameId)
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local scriptToRun = SettingsPlace[PlaceId] or SettingsGame[GameId]

if scriptToRun then
    loadstring(scriptToRun)()
else
    Player:Kick("This script isn't supported yet")
end
