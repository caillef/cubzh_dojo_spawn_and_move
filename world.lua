--[[
Client.OnStart = function()
	Player:SetParent(World)
	Player.Position = Number3(Map.Width * 0.5, Map.Height, Map.Depth * 0.5) * Map.Scale
	print("Edition: ", Environment.EDITION or "")

	bundle = require("bundle")
	local s

	s = bundle:Shape("wheelbarrow.vox")
	print("1>", s)

	s = bundle:Shape("assets/burger_classic.vox")
	print("2>", s)

	s = bundle:Shape("newpath/burger.vox")
	print("3>", s)
	Player:EquipHat(s)
	s.Scale = 5
end
--]]

local worldInfo = {
	rpc_url = "https://api.cartridge.gg/x/spawn-and-move-cubzh/katana",
	torii_url = "https://api.cartridge.gg/x/spawn-and-move-cubzh/torii",
	world = "0x7efebb0c2d4cc285d48a97a7174def3be7fdd6b7bd29cca758fa2e17e03ef30",
	actions = "0x5c70a663d6b48d8e4c6aaa9572e3735a732ac3765700d470463e670587852af",
	playerAddress = "0x76757de5cf706e6103d5097509a965896cd3a735948abd000e5d9942d8e4333",
	playerSigningKey = "0x3bb24379d6f0e346aafddc3d195e76fd4ca97e28945e11a10f86ceca1fd9692",
}

local Direction = {
	Left = 1,
	Right = 2,
	Up = 3,
	Down = 4,
}

local entities = {}
getOrCreatePlayerEntity = function(data)
	if not dojo:getModel(data, "Position") then return end
	local entity = entities[data.Key]
	if not entity then
		local ui = require("uikit")
		local avatar = require("avatar"):get("caillef")
		avatar:SetParent(World)
		avatar.Position = { 0.5 * map.Scale.X, 0, 0.5 * map.Scale.Z }
		avatar.Scale = 0.2
		avatar.Rotation.Y = math.pi
		avatar.Physics = PhysicsMode.Disabled

		local handle = Text()
		handle:SetParent(avatar)
		handle.FontSize = 10
		handle.LocalPosition = { 0, 40, 0 }
		avatar.nameHandle = handle
		handle.Backward = Camera.Backward

		entity = {
			key = data.Key,
			data = data,
			originalPos = { x = 10, y = 10 },
			avatar = avatar
		}
		entities[data.Key] = entity
	end

	myAddress = contractAddressToBase64(dojo.burnerAccount.Address)
	entity.update = function(self, newEntity)
		local avatar = self.avatar

		local moves = dojo:getModel(newEntity, "Moves")
		if moves then
			if moves.last_direction.Option == Direction.Left then avatar.Rotation.Y = math.pi * -0.5 end
			if moves.last_direction.Option == Direction.Right then avatar.Rotation.Y = math.pi * 0.5 end
			if moves.last_direction.Option == Direction.Up then avatar.Rotation.Y = 0 end
			if moves.last_direction.Option == Direction.Down then avatar.Rotation.Y = math.pi end

			local isLocalPlayer = myAddress == contractAddressToBase64(moves.player)
			if remainingMoves and isLocalPlayer then
				remainingMoves.Text = string.format("Remaining moves: %d", moves.remaining)
			end
		end

		local position = dojo:getModel(newEntity, "Position")
		if position then
			avatar.Position = {
				((position.vec.x - self.originalPos.x) + 0.5) * map.Scale.X,
				0,
				(-(position.vec.y - self.originalPos.y) + 0.5) * map.Scale.Z
			}
		end

		local playerConfig = dojo:getModel(newEntity, "PlayerConfig")
		if playerConfig then
			avatar.nameHandle.Text = playerConfig.name:ToString()
			local isLocalPlayer = myAddress == contractAddressToBase64(playerConfig.player)
			if isLocalPlayer then
				avatar.nameHandle.BackgroundColor = Color.Red
				avatar.nameHandle.Color = Color.White
			end
		end
		avatar.nameHandle.Backward = Camera.Backward

		self.data = newEntity
	end

	return entity
end

contractAddressToBase64 = function(contractAddress)
	return contractAddress.Data:ToString({ format = "base64" })
end

function startGame(toriiClient)
	-- sync existing entities
	local entities = toriiClient:Entities()
	print("Existing entities synced:", #entities)
	for _,newEntity in ipairs(entities) do
		local entity = getOrCreatePlayerEntity(newEntity)
		if entity then entity:update(newEntity) end
	end

	-- sync existing entities
	local events = toriiClient:EventMessages()
	print("Existing event synced:", #events)

	-- set on entity update callback
	toriiClient:OnEntityUpdate(function(newEntity)
		local entity = getOrCreatePlayerEntity(newEntity)
		if entity then entity:update(newEntity) end
	end)

	toriiClient:OnEventMessageUpdate(function(newEvent)
		--print("Event received", newEvent.Models[1].Name)
	end)

	-- call spawn method
	dojo.actions.spawn()
	dojo.actions.set_player_config("focg lover")

	-- init ui
	ui = require("uikit")
	remainingMoves = ui:createText("Remaining moves: 50", Color.White, "big")
	remainingMoves.parentDidResize = function()
		remainingMoves.pos = { Screen.Width - remainingMoves.Width - 5, Screen.Height - remainingMoves.Height - 50 - Screen.SafeArea.Top }
	end
	remainingMoves:parentDidResize()
end

Client.OnStart = function()
	map = MutableShape()
	for z=-10,10 do
		for x=-10,10 do
			map:AddBlock((x+z)%2 == 0 and Color(63, 155, 10) or Color(48, 140, 4), x, 0, z)
		end
	end
	map:SetParent(World)
	map.Scale = 5
	map.Pivot.Y = 1

	Camera:SetModeFree()
	Camera.Position = { 0, 40, -50}
	Camera.Rotation.X = math.pi * 0.25

	-- create Torii client
	worldInfo.onConnect = startGame
	dojo:createToriiClient(worldInfo)
 end

Client.OnChat = function(payload)
	local message = payload.message
	if string.sub(payload.message,1,6) == "!name " then
		local name = string.sub(message,7,#message)
		dojo.actions.set_player_config(name)
		return true
	end
end

Client.DirectionalPad = function(dx, dy)
	if dx == -1 then
		dojo.actions.move(Direction.Left)
	elseif dx == 1 then
		dojo.actions.move(Direction.Right)
	elseif dy == 1 then
		dojo.actions.move(Direction.Up)
	elseif dy == -1 then
		dojo.actions.move(Direction.Down)
	end
end

-- dojo module

dojo = {}

dojo.getOrCreateBurner = function(self, config)
	dojo.burnerAccount = self.toriiClient:CreateBurner(config.playerAddress, config.playerSigningKey)
end

dojo.createToriiClient = function(self, config)
	dojo.config = config
	local err
	dojo.toriiClient, err = Dojo:CreateToriiClient(config.torii_url, config.rpc_url, config.world)
	if dojo.toriiClient == nil then
		local connectionHandler
		print(err)
		print("Dojo: can't connect to torii, retrying in a few seconds...")
		connectionHandler = Timer(3, true, function()
			dojo.toriiClient, err = Dojo:CreateToriiClient(config.torii_url, config.rpc_url, config.world)
			if dojo.toriiClient == nil then
				print(err)
				print("Dojo: can't connect to torii, retrying in a few seconds...")
				return
			end
			connectionHandler:Cancel()
			self:getOrCreateBurner(config)
			if config.onConnect then
				config.onConnect(self.toriiClient)
			end
		end)
		return
	end
	self:getOrCreateBurner(config)
	if config.onConnect then
		config.onConnect(self.toriiClient)
	end
end

dojo.getModel = function(_, entity, modelName)
	for _,model in ipairs(entity.Models) do
		if model.Name == modelName then
			return model
		end
	end
end

function bytes_to_hex(data)
	local hex = "0x"
	for i=1, data.Length do
        hex = hex .. string.format("%02x", data[i])
	end
	return hex
end

-- generated contracts

dojo.actions = {
	spawn = function()
		if not dojo.toriiClient then return end
		dojo.toriiClient:Execute(dojo.burnerAccount, dojo.config.actions, "spawn")
	end,
	move = function(dir)
		if not dojo.toriiClient then return end
		dojo.toriiClient:Execute(dojo.burnerAccount, dojo.config.actions, "move", { dir })
	end,
	set_player_config = function(name)
		if not dojo.toriiClient then return end
		dojo.toriiClient:Execute(dojo.burnerAccount, dojo.config.actions, "set_player_config", { { type = "ByteArray", value = name } })
	end
}

--]]
