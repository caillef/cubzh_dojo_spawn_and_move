local worldInfo = {
	rpc_url = "https://api.cartridge.gg/x/spawn-and-move-cubzh/katana",
	torii_url = "https://api.cartridge.gg/x/spawn-and-move-cubzh/torii",
	world = "0x25e74888e786245ec7aa93d846b2cc9e4b49a5244209860bbf4b384f654521b",
	actions = "0x24d926d75cd84104c3bd24f0f79e95c273d6a99ed449f3c8b83114857020332",
	playerAddress = "0x657e5f424dc6dee0c5a305361ea21e93781fea133d83efa410b771b7f92b",
	playerSigningKey = "0xcd93de85d43988b9492bfaaff930c129fc3edbc513bb0c2b81577291848007",
}

local Direction = {
	Left = 1,
	Right = 2,
	Up = 3,
	Down = 4,
}

local avatarNames = { "caillef", "aduermael", "gdevillele", "claire", "soliton", "buche", "voxels", "petroglyph" }

local entities = {}
getOrCreatePlayerEntity = function(key, data)
	if not dojo:getModel(data, "dojo_examples-Position") then return end
	local entity = entities[key]
	if not entity then
		local ui = require("uikit")
		local avatar = require("avatar"):get(avatarNames[math.random(1,#avatarNames)])
		avatar.Scale = 0.2
		--local avatar = MutableShape()
		--avatar.Pivot = { 0.5, 0, 0.5 }
		--avatar:AddBlock(Color.Red,0,0,0)
		--avatar.Scale = 2
		avatar:SetParent(World)
		avatar.Position = { 0.5 * map.Scale.X, 0, 0.5 * map.Scale.Z }
		avatar.Rotation.Y = math.pi
		avatar.Physics = PhysicsMode.Disabled

		local handle = Text()
		handle:SetParent(avatar)
		handle.FontSize = 2 / avatar.Scale.X
		handle.LocalPosition = { 0, 4 * handle.FontSize, 0 }
		avatar.nameHandle = handle
		handle.Backward = Camera.Backward

		entity = {
			key = data.Key,
			data = data,
			originalPos = { x = 10, y = 10 },
			avatar = avatar
		}
		entities[key] = entity
	end

	myAddress = dojo.burnerAccount.Address
	entity.update = function(self, newEntity)
		local avatar = self.avatar

		local moves = dojo:getModel(newEntity, "dojo_examples-Moves")
		if moves then
			if moves.last_direction.value.option == "Left" then avatar.Rotation.Y = math.pi * -0.5 end
			if moves.last_direction.value.option == "Right" then avatar.Rotation.Y = math.pi * 0.5 end
			if moves.last_direction.value.option == "Up" then avatar.Rotation.Y = 0 end
			if moves.last_direction.value.option == "Down" then avatar.Rotation.Y = math.pi end

			local isLocalPlayer = myAddress == moves.player.value
			if remainingMoves and isLocalPlayer then
				remainingMoves.Text = string.format("Remaining moves: %d", moves.remaining.value)
			end
		end

		local position = dojo:getModel(newEntity, "dojo_examples-Position")
		if position then
			avatar.Position = {
				((position.vec.value.x.value - self.originalPos.x) + 0.5) * map.Scale.X,
				0,
				(-(position.vec.value.y.value - self.originalPos.y) + 0.5) * map.Scale.Z
			}
		end

		local playerConfig = dojo:getModel(newEntity, "dojo_examples-PlayerConfig")
		if playerConfig then
			local name = playerConfig.name.value
			avatar.nameHandle.Text = name
			local isLocalPlayer = myAddress == playerConfig.player.value
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

function startGame(toriiClient)
	-- sync existing entities
	toriiClient:Entities("{ \"limit\": 100, \"offset\": 0 }", function(entities)	
		for key,newEntity in pairs(entities) do
			local entity = getOrCreatePlayerEntity(key, newEntity)
			if entity then entity:update(newEntity) end
		end
	end)
	
	-- set on entity update callback
	-- match everything
	local clauseJsonStr = "[{ \"Keys\": { \"keys\": [], \"models\": [], \"pattern_matching\": \"VariableLen\" } }]"
	toriiClient:OnEntityUpdate(clauseJsonStr, function(entities)
		for key,newEntity in pairs(entities) do
			local entity = getOrCreatePlayerEntity(key, newEntity)
			if entity then entity:update(newEntity) end
		end
	end)

	-- call spawn method
	dojo.actions.spawn()
	Timer(2, function()
		dojo.actions.set_player_config("focg lover")	
	end)
	
	-- init ui
	ui = require("uikit")
	remainingMoves = ui:createText("Remaining moves: 50", Color.White, "big")
	remainingMoves.parentDidResize = function()
		remainingMoves.pos = { Screen.Width - remainingMoves.Width - 5, Screen.Height - remainingMoves.Height - Screen.SafeArea.Top }
	end
	remainingMoves:parentDidResize()

	if Screen.Width < Screen.Height then
		local controlsFrame = ui:createFrame()
		local size = 100
		local leftBtn = ui:createButton("⬅️")
		leftBtn.parentDidResize = function()
			leftBtn.pos = { 0, 0 }
		end
		leftBtn:setParent(controlsFrame)
		leftBtn.onRelease = function()
			dojo.actions.move(Direction.Left)
		end
		local rightBtn = ui:createButton("➡️")
		rightBtn.parentDidResize = function()
			rightBtn.pos = { size * 2, 0 }
		end
		rightBtn:setParent(controlsFrame)
		rightBtn.onRelease = function()
			dojo.actions.move(Direction.Right)
		end
		local downBtn = ui:createButton("⬇️")
		downBtn.parentDidResize = function()
			downBtn.pos = { size, 0 }
		end
		downBtn:setParent(controlsFrame)
		downBtn.onRelease = function()
			dojo.actions.move(Direction.Down)
		end
		local upBtn = ui:createButton("⬆️")
		upBtn.parentDidResize = function()
			upBtn.pos = { size, size }
		end
		upBtn:setParent(controlsFrame)
		upBtn.onRelease = function()
			dojo.actions.move(Direction.Up)
		end

		leftBtn.Size = size
		rightBtn.Size = size
		downBtn.Size = size
		upBtn.Size = size

		controlsFrame.parentDidResize = function()
			controlsFrame.pos = { Screen.Width - size * 3 - 10, 10 }
		end
		controlsFrame:parentDidResize()
	end
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

dojo.getOrCreateBurner = function(self, config, cb)
	self.toriiClient:CreateBurner(config.playerAddress, config.playerSigningKey, function(success, burnerAccount)
		dojo.burnerAccount = burnerAccount
		cb()
	end)
end

dojo.createToriiClient = function(self, config)
	dojo.config = config
	local err
	dojo.toriiClient = Dojo:CreateToriiClient(config.torii_url, config.rpc_url, config.world)
	dojo.toriiClient.OnConnect = function(success)
		if not success then
			print("Connection failed")
			return
		end
		self:getOrCreateBurner(config, function()
			config.onConnect(dojo.toriiClient)
		end)
	end
	dojo.toriiClient:Connect()
end

dojo.getModel = function(_, entity, modelName)
	for key,model in pairs(entity) do
		if key == modelName then
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

function number_to_hexstr(number)
	return "0x"..string.format("%x", number)
end

-- generated contracts

dojo.actions = {
	spawn = function()
		if not dojo.toriiClient then return end
		dojo.toriiClient:Execute(dojo.burnerAccount, dojo.config.actions, "spawn")
	end,
	move = function(dir)
		if not dojo.toriiClient then return end
		dojo.toriiClient:Execute(dojo.burnerAccount, dojo.config.actions, "move", string.format("[\"%s\"]", number_to_hexstr(dir)))
	end,
	set_player_config = function(name)
		if not dojo.toriiClient then return end
		local serialized = Dojo:SerializeBytearray(name)
		dojo.toriiClient:Execute(dojo.burnerAccount, dojo.config.actions, "set_player_config", string.format("[\"%s\"]", string.sub(serialized, 3, #serialized - 2)))
	end
}

--]]
