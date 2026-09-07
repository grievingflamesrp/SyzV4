-- SYZV4 loader (patch kicks + load)
shared.VapeDeveloper = true
shared.vapereload = shared.vapereload or false

repeat task.wait() until game:IsLoaded()

-- ========== PATCH ALL KICKS ==========
local function patchFile(path)
	if not isfile(path) then return false end
	local src = readfile(path)
	if not (src:find("no longer supported") or src:find("lplr.Kick") or src:find("lplr:Kick")) then
		return false
	end

	src = src:gsub(
		"local kickThread = task%.spawn%(lplr%.Kick, lplr, 'Bedwars is no longer supported by Vape V4, thank you for 5 years of support ❤️'%)[%s\r\n]*if coroutine%.status%(kickThread%) ~= 'dead' then[%s\r\n]*game:Shutdown%(%)[%s\r\n]*end",
		"-- kick removed"
	)
	src = src:gsub("Bedwars is no longer supported by Vape V4, thank you for 5 years of support ❤️", "REMOVED")
	src = src:gsub("%-%-This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates%.\n", "")

	writefile(path, src)
	print("Patched:", path)
	return true
end

if isfolder("newvape/games") then
	for _, f in listfiles("newvape/games") do
		if isfile(f) and tostring(f):find("%.lua") then
			pcall(patchFile, f)
		end
	end
end

-- also patch current place file if present
pcall(patchFile, "newvape/games/" .. game.PlaceId .. ".lua")

-- ========== MAIN LOAD ==========
if shared.vape then
	pcall(function()
		shared.vape:Uninject()
	end)
end

local vape
local oldLoadstring = loadstring
local loadstring = function(...)
	local res, err = oldLoadstring(...)
	if err and vape then
		vape:CreateNotification("SYZV4", "Failed to load: " .. tostring(err), 30, "alert")
	end
	return res
end

local queue_on_teleport = queue_on_teleport or function() end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ""
end
local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService("Players"))

local function downloadFile(path, func)
	if isfile(path) then
		return (func or readfile)(path)
	end

	local commit = isfile("newvape/profiles/commit.txt") and readfile("newvape/profiles/commit.txt") or "main"
	local suc, res = pcall(function()
		return game:HttpGet(
			"https://raw.githubusercontent.com/7GrandDadPGN/VapeCompiled/"
				.. commit
				.. "/"
				.. select(1, path:gsub("newvape/", "")),
			true
		)
	end)

	if not suc or res == "404: Not Found" then
		error(res)
	end

	-- no watermark so it won't get auto-wiped
	writefile(path, res)

	-- if this is a game file, patch kick immediately
	if path:find("/games/") and path:find("%.lua") then
		pcall(patchFile, path)
	end

	return (func or readfile)(path)
end

local function finishLoading()
	vape.Init = nil
	vape:Load()

	task.spawn(function()
		repeat
			vape:Save()
			task.wait(10)
		until not vape.Loaded
	end)

	local teleportedServers
	vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
		if (not teleportedServers) and (not shared.VapeIndependent) then
			teleportedServers = true
			-- always rejoin with developer mode + this same loader flow
			local teleportScript = [[
				shared.vapereload = true
				shared.VapeDeveloper = true
				loadstring(readfile("newvape/main.lua"), "main")()
			]]
			vape:Save()
			queue_on_teleport(teleportScript)
		end
	end))

	task.delay(1, function()
		if vape and vape.CreateNotification then
			vape:CreateNotification("SYZV4", "SYZV4 Has loaded. Your access level is [ PRIVATE ]", 5)
		end
	end)
end

for _, folder in {
	"newvape",
	"newvape/games",
	"newvape/profiles",
	"newvape/assets",
	"newvape/libraries",
	"newvape/guis",
	"newvape/assets/new",
} do
	if not isfolder(folder) then
		makefolder(folder)
	end
end

if not isfile("newvape/profiles/gui.txt") then
	writefile("newvape/profiles/gui.txt", "new")
end

local gui = "new"
vape = loadstring(downloadFile("newvape/guis/" .. gui .. ".lua"), "gui")()
shared.vape = vape

if not shared.VapeIndependent then
	loadstring(downloadFile("newvape/games/universal.lua"), "universal")()

	local placePath = "newvape/games/" .. game.PlaceId .. ".lua"
	if isfile(placePath) then
		pcall(patchFile, placePath)
		loadstring(readfile(placePath), tostring(game.PlaceId))()
	else
		-- download once, patch, then load
		local ok = pcall(function()
			downloadFile(placePath)
		end)
		if ok and isfile(placePath) then
			pcall(patchFile, placePath)
			loadstring(readfile(placePath), tostring(game.PlaceId))()
		end
	end

	finishLoading()
else
	vape.Init = finishLoading
	return vape
end
