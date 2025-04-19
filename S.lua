return function(Information: {
	WebhookUrl: string,
})

	if not game:IsLoaded() then
		print("⏰ Waiting for the game to load")
		game.Loaded:Wait()
	end

    task.wait(2)

	-- Services
	local TeleportService = game:GetService("TeleportService")
	local Players = game:GetService("Players")
	local HttpService = game:GetService("HttpService")
	local Workspace = game:GetService("Workspace")
	local StarterGui = game:GetService("StarterGui")
	local TestService = game:GetService("TestService")

	-- Variables
	--> Settings
	local WebhookUrl = Information.WebhookUrl
    local Settings = {
		Eggs = { "rainbow-egg", "void-egg", "nightmare-egg", "event-1", "event-2", "event-3", "man-egg" }, -- Add "Any" if you don't want specific eggs
		Chests = { "royal-chest" }, -- Add "Any" if you don't want specific chests
		IgnoreMultiplier = { "man-egg", "event-3" }, -- Only use this on rare EGGS
		Ping = { "man-egg", "royal-chest", "event-3" }, -- Will ping if this gets found (Chests & Eggs)
		Minimum = {
			Multiplier = 25,
			Time = 220, -- Eggs only, this won't count on Chests.
		},

		Result = {
			Eggs = {},
			Chests = {},
			IncludePing = false,
		}, -- Do NOT change.
	}

	--> Game
	local Spawn = Workspace:WaitForChild("Worlds"):FindFirstChild("The Overworld").SpawnLocation :: SpawnLocation
	local Rifts = Workspace.Rendered.Rifts
	local PlaceId = game.PlaceId
	local JobId = game.JobId

	-- Functions
	--> Renamed
	local Insert = table.insert
	local Sub = string.sub
	local Search = table.find
	local Round = math.round
	local Abs = math.abs
	local Decode = function(JSON)
		local Success, Data = pcall(function()
			return HttpService:JSONDecode(JSON)
		end)

		if not Success then
			warn(`📋 Could not decode JSON, reason: {Data}`)
		end

		return Success and Data
	end

	--> Exploit Environment
	local Get = function(Url: string): string
		if game.HttpGet then
			return game:HttpGet(Url)
		else
			return HttpService:GetAsync(Url)
		end
	end

	local Post = function(Url: string, Data: string)
		if game.HttpPost then
			game:HttpPost(Url, Data)
		else
			return HttpService:PostAsync(Url, Data)
		end
	end

	--> Game
	local GetDistance = function(Target: Instance): number
		local TargetPosition = (function()
			if Target:IsA("Model") then
				return Target:GetPivot().Y
			elseif Target:IsA("BasePart") then
				return Target.Position.Y
			end

			return warn(`Target is not a model, nor BasePart, but a {Target.ClassName}`)
		end)()

		return Round(Abs(TargetPosition - Spawn.Position.Y))
	end

	local GetTimeLeft = function(Target: Instance): number
		local DespawnAt = Target:GetAttribute("DespawnAt") :: number
		return Round(DespawnAt - os.time())
	end

	--> Roblox API / Webhook
	local WebhookRequest = function(Custom: string)
		if Custom then
			return Post(
				WebhookUrl,
				HttpService:JSONEncode({
					content = Custom,
				})
			)
		end

		-- Send egg & chest information to the webhook
		local Embeds = {
			Eggs = #Settings.Result.Eggs > 0 and {
				title = "🥚Eggs",
				color = 8126287,
				fields = {},
			},

			Chests = #Settings.Result.Chests > 0 and {
				title = "📦 Chests",
				color = 5814783,
				fields = {},
			},
		}

		for Name: "Eggs" | "Chests", Self in next, Embeds do
			local Results = Settings.Result[Name] :: { any }

			for _, Result in next, Results do
				local Field = {
					name = Result.Name,
					value = "",
				}

				for Name, Value in next, Result do
					if Name ~= "Name" then
						Field.value ..= `\n{Name}: {Value}`
					end
				end

				Insert(Self.fields, Field)
			end
		end

		for Name, Type in next, Embeds do
			if Type then
				Insert(Embeds, Type)
			end

			Embeds[Name] = nil
		end

		if #Embeds == 0 then
			return TestService:Message("Not sending to webhook, since there's nothing.")
		end

		return Post(
			WebhookUrl,
			HttpService:JSONEncode({
				content = `{Settings.Result.IncludePing and "@everyone | " or ""}**NEW SERVER FOUND!**\n*Jobid: {JobId}*\n[**JOIN ({#Players:GetPlayers()} / {Players.MaxPlayers})**](https://fern.wtf/joiner?placeId={PlaceId}&gameInstanceId={JobId})`,
				embeds = Embeds,
			})
		)
	end

    local ServerHop = function() 
        loadstring(game:HttpGet("https://raw.githubusercontent.com/78n/Amity/main/AutoServerHop.lua"))()
    end

	--> Checks / Setup
	local CheckTarget = function(Target: any)
		local Type = Target:GetAttribute("Type")
		local Matches = false

		local IgnoreChestType = Search(Settings.Chests, "Any")
		local IgnoreEggType = Search(Settings.Eggs, "Any")

		if Type == "Egg" then
			local LuckMultiplier = Target.Display.SurfaceGui.Icon.Luck.Text
			local Luck = tonumber(Sub(LuckMultiplier, 2, -1))
			local TimeLeft = GetTimeLeft(Target)

			if IgnoreEggType or Search(Settings.Eggs, Target.Name) then
				if
					table.find(Settings.IgnoreMultiplier, Target.Name)
					or Luck and (Luck >= Settings.Minimum.Multiplier) and (TimeLeft >= Settings.Minimum.Time)
				then
					Matches = true
					Insert(Settings.Result.Eggs, {
						["Name"] = Target.Name,
						["Time Left"] = TimeLeft,
						["Height"] = GetDistance(Target),
						["Multiplier"] = Luck,
					})
				end
			end
		elseif Type == "Chest" then
			if IgnoreChestType or Search(Settings.Chests, Target.Name) then
				Matches = true
				Insert(Settings.Result.Chests, {
					["Name"] = Target.Name,
					["Time Left"] = GetTimeLeft(Target),
					["Height"] = GetDistance(Target),
				})
			end
		end

		if Matches then
			local Emoji = Type == "Egg" and "🥚" or "📦"
			print(`{Emoji} | Found a NEW {string.upper(Type)} - {Target.Name}`)

			if table.find(Settings.Ping, Target.Name) then
				Settings.Result.IncludePing = true
			end
		end
	end

	local TeleportFailed = function(Player, Result, Error)
		WebhookRequest(`❌ Error trying to join server, reason: {Error}, trying to join again.`)
		ServerHop()
	end

	-- Main
	StarterGui:SetCore("DevConsoleVisible", true)
	TeleportService.TeleportInitFailed:Connect(TeleportFailed)

	local TeleportData = TeleportService:GetLocalPlayerTeleportData()
	if not TeleportData or not TeleportData.ShouldntLog then
		for _, Target in next, Rifts:GetChildren() do
			CheckTarget(Target)
		end

		WebhookRequest()
	else
		warn("🚨 Not logging anything (if there's anything to log) since this is a rejoin.")
	end

	task.wait(1)
	ServerHop()
end
