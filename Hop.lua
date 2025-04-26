-- Services
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

-- Variables
--> Game
local PlaceId = game.PlaceId

--> File
local Folder = "ADV-ServerHop"
local Place = Folder .. `/{PlaceId}`
local Code = Place .. "/Script.txt"
local Joined = Place .. "/JoinedServers.json"
local ServerList = Place .. "/ServerList.json"
local LastUpdated = Place .. "/LastUpdated.txt"

return function(Proxies: { [number]: string }, Code: string | nil)
	-- Functions
	--> JSON
	local Decode = function(Json)
		local Success, Result = pcall(function()
			return HttpService:JSONDecode(Json)
		end)

		if Success then
			return Result
		end
	end

	local Encode = function(Json)
		local Success, Result = pcall(function()
			return HttpService:JSONEncode(Json)
		end)

		if Success then
			return Result
		end
	end

	--> Servers
	local ProxyIndex = 1
	local TotalProxies = #Proxies
	local GetNextProxy = function()
		local Proxy = Proxies[ProxyIndex]
		ProxyIndex = ProxyIndex + 1

		if ProxyIndex > TotalProxies then
			ProxyIndex = 1
		end

		return Proxy
	end

	local CreateServerList = function()
		local Servers = {}
		local ServerCount = 0
		local Cursor = ""

		repeat
			task.wait(5)
			local Proxy = GetNextProxy() .. Cursor
			local Request = game:HttpGet(Proxy)
			local Decoded = Decode(Request)

			print(`| 🔎 Request has been sent to {Proxy}`)
			print(`| ✅ Received the information - {Decoded}`)
			print(
				`| 📝 JSON character count - {typeof(Request) == "string" and #Request or "DID NOT RECEIVE STRING?"}`
			)

			if Decoded and Decoded.data then
				print(`🗄️ Server{ServerCount + 1} has been received`)
				Cursor = Decoded.nextPageCursor

				for _, Server in next, Decoded.data do
					table.insert(Servers, Server)
				end

				ServerCount += 1
			end
		until ServerCount == 10

		print(`✅ Got {#Servers} servers, now writing.`)
		writefile(Joined, "[]")
		writefile(LastUpdated, tostring(tick() + 1800))
		writefile(ServerList, Encode(Servers))
	end

	local UpdateJoined = function(JobId)
		local Old = Decode(readfile(Joined))

		if not Old then
			print("❌ Decoding the joined servers list failed, so instead we'll just make it an empty table.")
			print(`❌ Joined server list info: {Joined}`)
			Old = {}
		end

		table.insert(Old, JobId)
		writefile(Joined, Encode(Old))
	end

	local TeleportToServer
	TeleportToServer = function()
		local ServerList = readfile(ServerList)
		local JoinedServers = readfile(Joined)
		local Servers = Decode(ServerList)
		local Joined = Decode(JoinedServers)

		if Servers then
			local ChosenServer
			print(`🧮 Decoded {#Servers} servers`)

			repeat
				task.wait()
				local Chosen = Servers[math.random(1, #Servers)]

				if Servers and not Joined[Chosen.id] and Chosen.playing >= 3 then
					ChosenServer = Chosen
				end
			until ChosenServer

			local JobId = ChosenServer.id
			local Playing = ChosenServer.playing
			local Max = ChosenServer.maxPlayers

			print("🎲 Server has been chosen")
			print(`🚀 Teleporting to another server - {JobId} ({Playing}/{Max})`)

			UpdateJoined(ChosenServer.id)
			TeleportService:TeleportToPlaceInstance(PlaceId, JobId)
		end
	end

	--> Files
	local CreateFiles = function()
		if not isfolder(Folder) then
			makefolder(Folder)
		end

		makefolder(Place)
		writefile(Code, "")
		writefile(Joined, "[]")
		writefile(ServerList, "[]")
		writefile(LastUpdated, "")
	end

	-- Main
	--> Connections
	TeleportService.TeleportInitFailed:Connect(function(Player, Result, Error)
		warn(`🚨 Error occured teleporting, reason: {Error}`)
		TeleportToServer()
	end)

	--> Checks
	if not isfolder(Folder) or not isfolder(Place) then
		print("📂 Creating files")
		CreateFiles()
	end

	local LastUpdated = tonumber(readfile(LastUpdated))
	if not LastUpdated or LastUpdated < tick() then
		StarterGui:SetCore("DevConsoleVisible", true)
		CreateServerList()
	else
		print("✅ Serverlist up to date, time left:", LastUpdated - tick())
	end

	loadstring(readfile(Code))()
	TeleportToServer()
end
