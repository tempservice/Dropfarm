if not game:IsLoaded() then game.Loaded:Wait() task.wait(3) end

LPH_JIT_MAX = function(...) return ... end
LPH_NO_VIRTUALIZE = function(...) return ... end

local services = {
	workspace = game:GetService("Workspace"),
	replicatedStorage = game:GetService('ReplicatedStorage'),
	tweenService = game:GetService('TweenService'),
	runService = game:GetService('RunService'),
	players = game:GetService('Players'),
	httpService = game:GetService('HttpService'),
	teleportService = game:GetService('TeleportService'),
	pathFindingService = game:GetService('PathfindingService'),
	textChatService = game:GetService('TextChatService'),
	virtualUser = game:GetService('VirtualUser'),
	lighting = game:GetService('Lighting')
}


local Workspace = services.workspace
local Players = services.players
local HttpService = services.httpService
local Lighting = services.lighting
local ReplicatedStorage = services.replicatedStorage
local PathfindingService = services.pathFindingService
local RunService = services.runService
local TeleportService = services.teleportService

--Random Stuff
local config = {
	HeliSpeed = 5000,
	VehicleSpeed = 500,
	FlightSpeed = 150,
	PathSpeed = 150
}

local Modules = {
	Vehicle = require(ReplicatedStorage.Vehicle.VehicleUtils),
	TeamChooseUI = require(ReplicatedStorage.Game.TeamChooseUI),
	SidebarUI = require(ReplicatedStorage.Game.SidebarUI),
	DefaultActions = require(ReplicatedStorage.Game.DefaultActions),
	ItemSystem = require(ReplicatedStorage.Game.ItemSystem.ItemSystem),
	GunItem = require(ReplicatedStorage.Game.Item.Gun),
	PlayerUtils = require(ReplicatedStorage.Game.PlayerUtils),
	Paraglide = require(ReplicatedStorage.Game.Paraglide),
	CharUtils = require(ReplicatedStorage.Game.CharacterUtil),
	Notification = require(ReplicatedStorage.Game.Notification),
	PuzzleFlow = require(game.ReplicatedStorage.Game.Robbery.PuzzleFlow),
	Heli = require(ReplicatedStorage.Game.Vehicle.Heli),
	Raycast = require(ReplicatedStorage.Module.RayCast),
	UI = require(ReplicatedStorage.Module.UI),
	GunShopUI = require(ReplicatedStorage.Game.GunShop.GunShopUI),
	GunShopUtils = require(ReplicatedStorage.Game.GunShop.GunShopUtils),
	AlexChassis = require(ReplicatedStorage.Module.AlexChassis),
	Store = require(ReplicatedStorage.App.store),
	TagUtils = require(ReplicatedStorage.Tag.TagUtils),
	RobberyConsts = require(ReplicatedStorage.Robbery.RobberyConsts),
	NpcShared = require(ReplicatedStorage.GuardNPC.GuardNPCShared),
	Npc = require(ReplicatedStorage.NPC.NPC),
	SafeConsts = require(ReplicatedStorage.Safes.SafesConsts),
	MansionUtils = require(ReplicatedStorage.MansionRobbery.MansionRobberyUtils),
	BossConsts = require(ReplicatedStorage.MansionRobbery.BossNPCConsts),
	BulletEmitter = require(ReplicatedStorage.Game.ItemSystem.BulletEmitter),
}

local RayIgnore = Modules.Raycast.RayIgnoreNonCollideWithIgnoreList


--Player Variables

local player = services.players.localPlayer
local playerGui = player.PlayerGui
local char, root, humanoid, vehicle, vehicleRoot

local UpdatePlayerVars = function()
	char = player.Character
	root = char:WaitForChild('HumanoidRootPart')
	humanoid = char:WaitForChild('Humanoid')
end

local UpdateVehicleVars = function()
	local vehicleModel = Modules.Vehicle.GetLocalVehicleModel()
	if vehicleModel == false then
		vehicle = nil
		vehicleRoot = nil
	else
		vehicle = vehicleModel
		vehicleRoot = vehicle.PrimaryPart
	end
end

if player.Character then UpdatePlayerVars() end

player.characterAdded:Connect(UpdatePlayerVars)
player.characterRemoving:Connect(UpdatePlayerVars)

UpdateVehicleVars()
Modules.Vehicle.OnVehicleEntered:Connect(UpdateVehicleVars)
Modules.Vehicle.OnVehicleExited:Connect(UpdateVehicleVars)


-- Bypass Anticheat


local OverwriteCnt = 0
local ExitFunc = nil 

LPH_NO_VIRTUALIZE(function()
	for i, v in pairs(getgc(true)) do
		if typeof(v) =="function" then
			if debug.info(v, "n"):match("CheatCheck") then
				hookfunction(v, function() end)
			end
		end

		if typeof(v) == "function" and getfenv(v).script == player.PlayerScripts.LocalScript then
			local con = getconstants(v)
			if table.find(con, "LastVehicleExit") and table.find(con, "tick") then
				ExitFunc = v
			end
		end
	end
end)()

--Robberys States

local robberyState = services.replicatedStorage.RobberyState
local robberyConsts = Modules.RobberyConsts

local robberies = {
	mansion = {open = false, hasRobbed = false},
	ship = {open = false, hasRobbed = false},
	crate = {open = false},
}

local UpdateStatus = function(robbery, var, val, checkStart, special)
	if not robberyState:FindFirstChild(robbery) then robberies[var][val] = false return end
	local status = robberyState:FindFirstChild(robbery).Value
	robberies[var][val] = ((status == 1 and not checkStart) and true) or ((status == 2 and not special) and true) or false
	if val == 'open' and robberies[var][val] == false then robberies[var]['hasRobbed'] = false end
end

coroutine.wrap(LPH_JIT_MAX(function()
	while true do
		UpdateStatus(robberyConsts.ENUM_ROBBERY.MANSION, 'mansion', 'open', false, true)
		UpdateStatus(robberyConsts.ENUM_ROBBERY.CARGO_SHIP, 'ship', 'open')
		robberies['crate'].open = (services.workspace:FindFirstChild('Drop') and true) or false
		task.wait(0.1)
	end
end))()

--Functions

local function HidePickingTeam()
	spawn(function()
		while true do
			wait(.1)
			pcall(function()
				Modules.TeamChooseUI.Hide()
			end)
		end
	end)
end

local function WaitForReward()
	if player.PlayerGui.AppUI:FindFirstChild("RewardSpinner") then
		repeat 
			task.wait() 
		until not player.PlayerGui.AppUI:FindFirstChild("RewardSpinner")
	end
end

local ServerHop = function()
	queue_on_teleport([[
		loadstring(game:HttpGet("https://dropfarm.vercel.app/script.lua"))()
    ]])

	local PlaceID = game.PlaceId
	local AllIDs = {}
	local foundAnything = ""
	local actualHour = os.date("!*t").hour
	local Deleted = false
	local File = pcall(function()
		AllIDs = game:GetService('HttpService'):JSONDecode(readfile("NotSameServers.json"))
	end)
	if not File then
		table.insert(AllIDs, actualHour)
		writefile("NotSameServers.json", game:GetService('HttpService'):JSONEncode(AllIDs))
	end
	function TPReturner()
		local Site;
		if foundAnything == "" then
			Site = game.HttpService:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Asc&limit=100'))
		else
			Site = game.HttpService:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Asc&limit=100&cursor=' .. foundAnything))
		end
		local ID = ""
		if Site.nextPageCursor and Site.nextPageCursor ~= "null" and Site.nextPageCursor ~= nil then
			foundAnything = Site.nextPageCursor
		end
		local num = 0;
		for i,v in pairs(Site.data) do
			local Possible = true
			ID = tostring(v.id)
			if tonumber(v.playing) <= 5 then
				for _,Existing in pairs(AllIDs) do
					if num ~= 0 then
						if ID == tostring(Existing) then
							Possible = false
						end
					else
						if tonumber(actualHour) ~= tonumber(Existing) then
							local delFile = pcall(function()
								delfile("NotSameServers.json")
								AllIDs = {}
								table.insert(AllIDs, actualHour)
							end)
						end
					end
					num = num + 1
				end
				if Possible == true then
					table.insert(AllIDs, ID)
					wait()
					pcall(function()
						writefile("NotSameServers.json", game:GetService('HttpService'):JSONEncode(AllIDs))
						wait()
						game:GetService("TeleportService"):TeleportToPlaceInstance(PlaceID, ID, game.Players.LocalPlayer)
					end)
					wait(4)
				end
			end
		end
	end

	function TeleportSmall()
		while wait() do
			pcall(function()
				TPReturner()
				if foundAnything ~= "" then
					TPReturner()
				end
			end)
		end
	end

	TeleportSmall()
end

Modules.TagUtils.isPointInTag = LPH_NO_VIRTUALIZE(function(_, Tag)
	if Tag == 'NoFallDamage' or Tag == 'NoRagdoll' or Tag == 'NoParachute' then
		return true
	end
end)

local rayDirs = { up = Vector3.new(0, 999, 0), down = Vector3.new(0, -999, 0) }
local rayCast = LPH_NO_VIRTUALIZE(function(pos, dir)
	local ignoreList = {}
	if char then table.insert(ignoreList, char) end
	if vehicle then table.insert(ignoreList, vehicle) end
	local rain = services.workspace:FindFirstChild('Rain')
	if rain then table.insert(ignoreList, rain) end

	local params = RaycastParams.new()
	params.RespectCanCollide = true
	params.FilterDescendantsInstances = ignoreList
	params.IgnoreWater = true
	local result = services.workspace:Raycast(pos, dir, params)
	if result then return result.Instance, result.Position else return nil, nil end
end)

local GetRoot = function() return (vehicle and vehicleRoot) or root end

local GoToGround = LPH_JIT_MAX(function()
	while true do
		local _, pos = rayCast(root.Position, rayDirs.down)
		if pos then 
			char:PivotTo(CFrame.new(root.Position.x, pos.y + 2, root.Position.z)) 
			task.wait(0.3) 
			GetRoot().Velocity = Vector3.zero 
			return 
		end
		task.wait()
	end
end)

local heliSpawnPos = {
	Vector3.new(725, 76, 1111),
	Vector3.new(-1255, 46, -1572),
	Vector3.new(840, 24, -3678),
	Vector3.new(-2875, 199, -4059)
}

local GetVehiclePos = LPH_JIT_MAX(function(playerPos)
	playerPos = Vector3.new(playerPos.x, 0, playerPos.z)
	local targetVehicle
	local minDist = math.huge

	for _, vehicle in pairs(services.workspace.Vehicles:GetChildren()) do
		if vehicle.name ~= 'Heli' then continue end
		if vehicle.Seat.position.y > 300 then continue end
		local pos = vehicle.Seat.Position
		pos = Vector3.new(pos.x, 0, pos.z)
		local dist = (pos - playerPos).Magnitude
		if dist > minDist or dist < 1 then continue end
		local hit, _ = rayCast(vehicle.Seat.Position, rayDirs.up)
		if hit then continue end
		minDist = dist
		targetVehicle = vehicle
	end

	if targetVehicle then return targetVehicle.Seat.Position, targetVehicle end

	local positions = heliSpawnPos
	for _, pos in pairs(positions) do
		local dist = (pos - playerPos).Magnitude
		if dist > minDist or dist < 1 then continue end
		minDist = dist
		targetVehicle = pos
	end

	return targetVehicle, nil
end)

local ActivateSpec = function(spec)
	spec.Duration = 0
	spec.Timed = true
	spec:Callback(true)
end

local ExitVehicle = function()
	if reset or not vehicle then return end
	Modules.CharUtils.OnJump()

	repeat 
		task.wait()  
	until not vehicle
end

local InHeli = function() return ((vehicle and vehicle.Name == 'Heli') and true) or false end

--Movement

local FlightMove = LPH_NO_VIRTUALIZE(function(pos)
	local speed = (InHeli() and -config['HeliSpeed']) or (vehicle and -config['VehicleSpeed']) or -config['FlightSpeed']
	local GetPos = function() return Vector3.new(pos.x, 500, pos.z) end
	char:PivotTo(CFrame.new(root.Position.x, 500, root.Position.z))

	local dist = GetRoot().Position - GetPos()
	while dist.Magnitude > 10 do
		dist = GetRoot().Position - GetPos()
		local velocity = dist.Unit * speed
		velocity = Vector3.new(velocity.x, 0, velocity.z)

		GetRoot().Velocity = velocity
		char:PivotTo(CFrame.new(root.Position.x, 500, root.Position.z))
		task.wait()
	end

	GetRoot().Velocity = Vector3.zero
	char:PivotTo(CFrame.new(GetPos()))
end)

local Travel = function()
	while not vehicle do
		local pos1, targetVehicle = GetVehiclePos(root.Position)
		FlightMove(pos1)
		GoToGround()

		if targetVehicle and targetVehicle.PrimaryPart and (targetVehicle.PrimaryPart.Position - root.Position).Magnitude < 30 then
			for _ = 1, 3 do
				for _, spec in pairs(Modules.UI.CircleAction.Specs) do
					if spec.Part and spec.Part == targetVehicle.Seat then ActivateSpec(spec) end
				end
				task.wait(0.3)
				if vehicle then 
					for i,v in pairs(targetVehicle:GetDescendants()) do
						if v:IsA("Part") or v:IsA("MeshPart") then
							v.CanCollide = false
						end
					end
					break end
			end
		end 
		task.wait()
	end
end

--Ship

local RobShip = LPH_NO_VIRTUALIZE(function() 

	wait(.1)

	HidePickingTeam()

	if not InHeli() then 
		ExitVehicle()
		Travel()
	end

	if robberies.ship.open == false then return end

	char:PivotTo(CFrame.new(root.Position.X, 500, root.Position.Z))
	task.wait(0.1)

	if not vehicle.Preset:FindFirstChild('RopePull') then
		repeat
			Modules.Vehicle.Classes.Heli.attemptDropRope()
			task.wait(2.5)
		until vehicle.Preset:FindFirstChild('RopePull')
		task.wait(0.5)
	end

	local ropePull = vehicle.Preset:WaitForChild('RopePull')
	local rope = vehicle.Winch.RopeConstraint

	rope.Length = 999
	rope.WinchEnabled = true
	ropePull.CanCollide = false
	ropePull.Massless = true

	for _ = 1, 2 do
		local crate = services.workspace.CargoShip.Crates:GetChildren()[1]
		player:RequestStreamAroundAsync(crate.MeshPart.Position, 1000)

		repeat
			ropePull:PivotTo(crate.MeshPart.CFrame)
			ropePull:WaitForChild('ReqLink'):FireServer(crate, Vector3.zero)
			task.wait()
		until ropePull.AttachedTo.Value ~= nil

		WaitForReward()

		task.wait(1)
		robberies.ship.hasRobbed = true

		repeat
			ropePull:PivotTo(CFrame.new(-471, -50, 1906))
			crate:PivotTo(CFrame.new(-471, -50, 1906))
			task.wait()
		until not crate:FindFirstChild('MeshPart')
	end

	rope.WinchEnabled = false
	ropePull.CanCollide = true
	ropePull.Massless = false
	rope.Length = 30

	if robberies.ship.open == false and robberies.crate.open == false and robberies.mansion.open == false then ServerHop() return end
	if robberies.ship.open and robberies.ship.hasRobbed == true then ServerHop() return end
end)

local function TeleporterC(pos, duration)
	local tper = game:GetService("RunService").Heartbeat:Connect(function()
		vehicleRoot.CFrame = CFrame.new(pos)
	end)

	wait(duration)

	tper:Disconnect()
end

local function RobCrate()
	wait(.1)

	HidePickingTeam()

	if not InHeli() then 
		ExitVehicle()
		Travel()
	end

	local dropMAIN = game.Workspace:FindFirstChild("Drop")

	if not dropMAIN then return end

	local dropRoot = game.Workspace:FindFirstChild("Drop"):FindFirstChild("Root")
	local droppos = game.Workspace:FindFirstChild("Drop"):FindFirstChild("Root").Position
	local dropposmodifed = Vector3.new(dropRoot.Position.X, dropRoot.Position.Y + 2.5, dropRoot.Position.Z)

	print(droppos)

	FlightMove(droppos)

	wait(.1)

	TeleporterC(dropposmodifed, 0.1)

	wait(.1)

	spawn(function()
		while dropMAIN:FindFirstChild("NPCs") == nil do
			wait(0.5)
		end
		dropMAIN:FindFirstChild("NPCs"):Destroy()
	end)

	local dropDone = false

	repeat 
		if not pcall(function()
				dropMAIN.BriefcasePress:FireServer(false)
				task.wait(1)
				dropMAIN.BriefcasePress:FireServer(true)
				dropMAIN.BriefcaseCollect:FireServer()
			end) then
			dropDone = true
		end

	until dropMAIN:GetAttribute("BriefcaseCollected") == true or not dropMAIN or dropDone

	task.wait(0.75)

	for i = 1, 3 do
		for _, spec in pairs(Modules.UI.CircleAction.Specs) do
			if spec.Name:sub(1, 9) == "Collect $" then
				spec:Callback(true)
			end
		end
		task.wait(0.25)
	end
end

local function NoclipStart()
	local NoclipLoop = LPH_NO_VIRTUALIZE(function()
		pcall(function()
			for i, child in pairs(char:GetDescendants()) do
				if child:IsA("BasePart") and child.CanCollide == true then
					child.CanCollide = false
				end
			end
		end)
	end)

	local Noclipper = RunService.Stepped:Connect(NoclipLoop)

	return {
		Stop = function()
			Noclipper:Disconnect()
		end
	}
end

local function DistanceXZ(firstPos, secondPos)
	local XZVector = Vector3.new(firstPos.X, 0, firstPos.Z) - Vector3.new(secondPos.X, 0, secondPos.Z)

	return XZVector.Magnitude 
end

local function LagBackCheck(part)
	local ShouldStop = false
	local OldPosition = part.Position
	local Signal = part:GetPropertyChangedSignal("CFrame"):Connect(LPH_NO_VIRTUALIZE(function()
		local CurrentPosition = part.Position

		if DistanceXZ(CurrentPosition, OldPosition) > 7 then
			LaggedBack = true
			task.delay(0.2, function()
				LaggedBack = false
			end)
		end
	end))

	task.spawn(function()
		while part and ShouldStop == false do
			OldPosition = part.Position
			task.wait()
		end
	end)

	return {
		Stop = function()
			ShouldStop = true
			Signal:Disconnect()
		end
	}
end

local function IsArrested()
	if player.PlayerGui.MainGui.CellTime.Visible or player.Folder:FindFirstChild("Cuffed") then
		return true
	end

	return false
end

local function SmallTP(cframe, speed)
	if not char or not root or IsArrested() then
		return false
	end

	if speed == nil then
		speed = 70
	end

	local IsTargetMoving = type(cframe) == "function"
	local LagCheck = LagBackCheck(root)
	local Noclip = NoclipStart()
	local TargetPos = (IsTargetMoving and cframe() or cframe).Position
	local LagbackCount = 0
	local Success = true

	local Mover = Instance.new("BodyVelocity", root)
	Mover.P = 3000
	Mover.MaxForce = Vector3.new(9e9, 9e9, 9e9)

	repeat
		if not root or humanoid.Health == 0 or IsArrested() then
			Success = false
		else
			TargetPos = (IsTargetMoving and cframe() or cframe).Position
			Mover.Velocity = CFrame.new(root.Position, TargetPos).LookVector * speed

			humanoid:SetStateEnabled("Running", false)
			humanoid:SetStateEnabled("Climbing", false)

			task.wait(0.03) 

			if LaggedBack then
				LagbackCount = LagbackCount + 1
				Mover.Velocity = Vector3.zero
				task.wait(1)

				if LagbackCount == 4 then
					Mover:Destroy()
					Noclip:Stop()
					LagCheck:Stop()

					humanoid.Health = 0
					Success = false
					task.wait(5)
				end
			end
		end
	until (root.Position - TargetPos).Magnitude <= 5 or not Success

	if Success then
		Mover.Velocity = Vector3.new(0, 0, 0)
		TargetPos = (IsTargetMoving and cframe() or cframe).Position
		root.CFrame = CFrame.new(TargetPos)
		task.wait(0.001)

		humanoid:SetStateEnabled("Running", true)
		humanoid:SetStateEnabled("Climbing", true)

		Mover:Destroy()
		Noclip:Stop()
		LagCheck:Stop()
	end

	return Success
end

local function ShootGun()
	local currentGun = require(game:GetService("ReplicatedStorage").Game:WaitForChild("ItemSystem"):WaitForChild("ItemSystem")).GetLocalEquipped()
	if not currentGun then return end
	require(game:GetService("ReplicatedStorage").Game:WaitForChild("Item"):WaitForChild("Gun"))._attemptShoot(currentGun)
end

local function GetGun()
	local SetThreadId = (setidentity or set_thread_identity or (syn and syn.set_thread_identity) or setcontext or setthreadcontext or set_thread_context)
	local IsOpen = pcall(Modules.GunShopUI.open)

	SetThreadId(2)
	Modules.GunShopUI.displayList(Modules.GunShopUtils.getCategoryData("Held"))
	SetThreadId(7)

	repeat 
		for i, v in next, Modules.GunShopUI.gui.Container.Container.Main.Container.Slider:GetChildren() do
			if v:IsA("ImageLabel") and v.Name == "Pistol" and (v.Bottom.Action.Text == "FREE" or v.Bottom.Action.Text == "EQUIP") then
				firesignal(v.Bottom.Action.MouseButton1Down)
			end
		end    

		task.wait()
	until player.Folder:FindFirstChild("Pistol")

	pcall(Modules.GunShopUI.close)
end

local function RobMansion()
	wait(.1)

	HidePickingTeam()

	if not InHeli() then 
		ExitVehicle()
	end

	if not player.Folder:FindFirstChild("MansionInvite") then
		return
	end

	local MansionRobbery = workspace.MansionRobbery
	local TouchToEnter = MansionRobbery.Lobby.EntranceElevator.TouchToEnter
	local ElevatorDoor = MansionRobbery.ArrivalElevator.Floors:GetChildren()[1].DoorLeft.InnerModel.Door
	local MansionTeleportCFrame = TouchToEnter.CFrame - Vector3.new(0, TouchToEnter.Size.Y / 2 - player.Character.Humanoid.HipHeight * 2, -TouchToEnter.Size.Z)

	local FailMansion = false

	task.delay(10, function()
		FailMansion = true
	end)

	local tper1 = RunService.Heartbeat:Connect(function()
		root.CFrame = MansionTeleportCFrame		
	end)

	repeat task.wait()
		firetouchinterest(root, TouchToEnter, 0)
		task.wait()
		firetouchinterest(root, TouchToEnter, 1)
	until Modules.MansionUtils.isPlayerInElevator(MansionRobbery, player) or FailMansion

	tper1:Disconnect()

	if FailMansion then 
		return
	end

	GetGun()
	repeat
		wait(0.1)
	until ElevatorDoor.Position.X > 3208

	for _, instance in pairs(MansionRobbery.Lasers:GetChildren()) do
		instance:Remove()
	end
	for _, instance in pairs(MansionRobbery.LaserTraps:GetChildren()) do
		instance:Remove()
	end   

	if not SmallTP(CFrame.new(3202, -200, -4703)) then return end
	if not SmallTP(CFrame.new(3201, -200, -4679)) then return end
	if not SmallTP(CFrame.new(3106, -204, -4675)) then return end
	if not SmallTP(CFrame.new(3106, -204, -4647)) then return end
	if not SmallTP(CFrame.new(3140, -204, -4647)) then return end
	if not SmallTP(CFrame.new(3147, -204, -4566)) then return end

	repeat wait() until MansionRobbery:GetAttribute("MansionRobberyProgressionState") == 3

	Modules.MansionUtils.getProgressionStateChangedSignal(MansionRobbery):Wait()

	local NPC_new = Modules.Npc.new
	local NPCShared_goTo = Modules.NpcShared.goTo

	Modules.Npc.new = function(NPCObject, ...)
		if NPCObject.Name ~= "ActiveBoss" then
			for i,v in pairs(NPCObject:GetDescendants()) do
				pcall(function()
					v.Transparency = 1
				end)
			end
		end
		return NPC_new(NPCObject, ...)
	end
	Modules.Npc.GetTarget = function(...)
		return MansionRobbery and MansionRobbery:FindFirstChild("ActiveBoss") and MansionRobbery:FindFirstChild("ActiveBoss").HumanoidRootPart
	end

	Modules.NpcShared.goTo = function(NPCData, Pos)
		if MansionRobbery and MansionRobbery:FindFirstChild("ActiveBoss") then
			return NPCShared_goTo(NPCData, MansionRobbery:FindFirstChild("ActiveBoss").HumanoidRootPart.Position)
		end
	end

	game.Workspace.Items.DescendantAdded:Connect(function(Des)
		if Des:IsA("BasePart") then
			Des.Transparency = 1
			Des:GetPropertyChangedSignal("Transparency"):Connect(function()
				Des.Transparency = 1
			end)
		end
	end)

	for i,v in pairs(services.replicatedStorage.Game.Item:GetChildren()) do
		require(v).ReloadDropAmmoVisual = function() end
		require(v).ReloadDropAmmoSound = function() end
		require(v).ReloadRefillAmmoSound = function() end
		require(v).ShootSound = function() end
	end

	getfenv(Modules.BulletEmitter.Emit).Instance = {
		new = function()
			return {
				Destroy = function() end
			}
		end
	}

	local BossCEO = MansionRobbery:WaitForChild("ActiveBoss")
	local OldHealth = BossCEO.Humanoid.Health

	LPH_NO_VIRTUALIZE(function()
		Modules.Raycast.RayIgnoreNonCollideWithIgnoreList = function(...)
			local arg = {RayIgnore(...)}

			if (tostring(getfenv(2).script) == "BulletEmitter" or tostring(getfenv(2).script) == "Taser") then
				arg[1] = BossCEO.Head
				arg[2] = BossCEO.Head.Position
			end

			return unpack(arg)
		end
	end)()

	require(ReplicatedStorage.NPC.NPC).GetTarget = function()
		return BossCEO:FindFirstChild("Head")
	end

	local Start = os.time()


	while player.Folder:FindFirstChild("Pistol") and BossCEO and BossCEO:FindFirstChild("HumanoidRootPart") and BossCEO.Humanoid.Health ~= 1 do
		player.Folder.Pistol.InventoryEquipRemote:FireServer(true)
		task.wait()
		ShootGun()
	end

	print("Killed bos in " .. Start - os.time())
	player.Folder.Pistol.InventoryEquipRemote:FireServer(false)
	repeat task.wait() until player.PlayerGui.AppUI:FindFirstChild("RewardSpinner")

	if not SmallTP(CFrame.new(3122, -205, -4527)) then return end
	if not SmallTP(CFrame.new(3119, -205, -4439)) then return end
	if not SmallTP(CFrame.new(3098, -205, -4440)) then return end
	if not SmallTP(CFrame.new(3097, -221, -4519)) then return end
	if not SmallTP(CFrame.new(3076, -221, -4518)) then return end
	if not SmallTP(CFrame.new(3075, -221, -4485)) then return end
	if not SmallTP(CFrame.new(3063, -221, -4486)) then return end
	if not SmallTP(CFrame.new(3064.07495, -220.748993, -4474.64209, 0, 0, -1, 0, 1, 0, 1, 0, 0)) then return end
	wait(.1)
	if not SmallTP(CFrame.new(3124, 51, -4415)) then return end
	if not SmallTP(CFrame.new(3106, 51, -4412)) then return end
	if not SmallTP(CFrame.new(3106, 57, -4377)) then return end
end

while true do
	wait(1)
	if robberies.ship.open then RobShip() end
	if robberies.crate.open then RobCrate() end
	if robberies.mansion.open then RobMansion() end

	if robberies.ship.open == true and robberies.ship.hasRobbed == true or robberies.crate.open == false and robberies.mansion.open == false then ServerHop() return end
	if robberies.ship.open == false and robberies.ship.hasRobbed == false or robberies.crate.open == false and robberies.mansion.open == false then ServerHop() return end
end
