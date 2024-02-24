local DropGetter

print("[DROPFARM] Loading resources...")
wait(.1)
print("[DROPFARM] Loaded!")

spawn(function()
	while true do
		if game.Workspace:FindFirstChild("Drop") then
			DropGetter = game.Workspace:FindFirstChild("Drop")
			print(DropGetter)
		end
		task.wait()
	end
end)

while wait() do
	if DropGetter ~= nil then
		HidePickingTeam()
		RobCrate()
		DropGetter = nil
	elseif robberies.ship.open and not robberies.ship.hasRobbed then
		HidePickingTeam()
		RobShip()
		robberies.ship.hasRobbed = true
	elseif robberies.crate.open then
		HidePickingTeam()
		RobCrate()
	elseif robberies.mansion.open and player.Folder:FindFirstChild("MansionInvite") then
		HidePickingTeam()
		RobMansion()
	end
	
	if not ServerHopping then
		repeat 
			task.wait() 
			print("HOPPING") 
			ServerHop() 
		until ServerHopping
	end
end
