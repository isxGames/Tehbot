; This is a template for writing mission configs. One thing to keep in mind: For some reason CCP has added a space after some mission names.

function main()
{
	;
	; First you need to add agents to your agent list, the bot will switch between them to manage the decline timer
	; to try to ensure you always have available missions.
	;
	Script[Tehbot].VariableScope.Mission.AgentList:Insert["Guy"]
	Script[Tehbot].VariableScope.Mission.AgentList:Insert["Dude"]
	Script[Tehbot].VariableScope.Mission.AgentList:Insert["Bro"]

	;
	; Add the factions you don't want to fight against so missions with their logos will be declined.
	; Missions without faction logo won't be declined because they don't hurt faction standing.
	; The names don't need to be full names as long as they are not ambiguious.
	;
	Script[Tehbot].VariableScope.Mission.DontFightFaction:Insert["Amarr"]
	Script[Tehbot].VariableScope.Mission.DontFightFaction:Insert["Minmatar"]
	Script[Tehbot].VariableScope.Mission.DontFightFaction:Insert["Gallente"]
	Script[Tehbot].VariableScope.Mission.DontFightFaction:Insert["Caldari"]

	;
	; For most missions, all you need to do is use the DamageType collection to specify the mission name and the damage type.
	; Thus, the bot knows the mission is valid and what type of ammo to load.
	; For missions with faction logo in the journal, you can set the damage type to 'auto' and the bot will detect damage type automatically.
	; The bot will fly to the mission location, kill everything, and follow gates until it sees the mission is done.
	;
	Script[Tehbot].VariableScope.Mission.DamageType:Set["The Blockade", "Auto"]

	;
	; For missions without faction logo or when you want to force the damage type, you need to set the damage type manually.
	;
	Script[Tehbot].VariableScope.Mission.DamageType:Set["Attack of the Drones", "EM"]

	;
	; Some missions also require that you kill a target. To configure these, use the TargetToDestroy collection.
	; This collection requires the mission name and a search string. Most of these use the Name member. Note the single equal and the \ escaped quotes!
	;
	Script[Tehbot].VariableScope.Mission.DamageType:Set["The Right Hand Of Zazzmatazz", "Kinetic"]
	Script[Tehbot].VariableScope.Mission.TargetToDestroy:Set["The Right Hand Of Zazzmatazz", "Name = \"Outpost Headquarters\""]

	;
	; For some missions, you must loot an item. To configure these, use the ContainerToLoot collections.
	; This collection requires the mission name and a search string. Most of these use the Name member, but also empty wrecks need to be excluded. Note the single equal and the \ escaped quotes!
	;
	Script[Tehbot].VariableScope.Mission.DamageType:Set["Worlds Collide", "EM"]
	Script[Tehbot].VariableScope.Mission.ContainerToLoot:Set["Worlds Collide", "Name = \"Damaged Heron\" && !IsWreckEmpty"]
	; Script[Tehbot].VariableScope.Mission.AquireItem:Set["Worlds Collide", "Ship's Crew"]	<-- Not required anymore

	;
	; For some missions, you need a gate key to activate the acceleration gate.
	; The gate key item can either be obtained in the mission or brought to the mission.
	; Set the gate key item as below. If you already have the gate key, the bot will bring it to the mission, OTHERWISE it will search for the key in the specified container.
	;
	Script[Tehbot].VariableScope.Mission.DamageType:Set["Dread Pirate Scarlet", "Kinetic"]
	Script[Tehbot].VariableScope.Mission.GateKey:Set["Dread Pirate Scarlet", "Gate Key"]
	Script[Tehbot].VariableScope.Mission.GateKeyContainer:Set["Dread Pirate Scarlet", "Name = \"Cargo Container\""]

	;
	; Setting example of multistep mission 'The Anomaly'.
	;
	Script[Tehbot].VariableScope.Mission.DamageType:Set["The Anomaly (1 of 3)", "EM"]
	Script[Tehbot].VariableScope.Mission.GateKey:Set["The Anomaly (1 of 3)", "Oura Madusaari"]
	; 'Type' attribute tells the real Life Pod from the 3 fakes.
	Script[Tehbot].VariableScope.Mission.GateKeyContainer:Set["The Anomaly (1 of 3)", "Type = \"Life Pod\""]
	Script[Tehbot].VariableScope.Mission.TargetToDestroy:Set["The Anomaly (1 of 3)", "Name = \"Pressure Silo Debris\""]
	Script[Tehbot].VariableScope.Mission.ContainerToLoot:Set["The Anomaly (1 of 3)", "Name = \"Cargo Container\""]
	; Script[Tehbot].VariableScope.Mission.AquireItem:Set["The Anomaly (1 of 3)", "Fajah Ateshi"]	<-- Not required anymore

	;
	; For some missions, you need to deliver an item to a container.
	; Set the delivery as below.
	;
	Script[Tehbot].VariableScope.Mission.DamageType:Set["The Anomaly (2 of 3)", "EM"]
	; Script[Tehbot].VariableScope.Mission.DeliverItem:Set["The Anomaly (2 of 3)", "Neurowave Pattern Scanner"]	<-- Not required anymore
	Script[Tehbot].VariableScope.Mission.DeliverItemContainer:Set["The Anomaly (2 of 3)", "Name = \"The Anomaly\""]

	Script[Tehbot].VariableScope.Mission.DamageType:Set["The Anomaly (3 of 3)", "EM"]
	; Script[Tehbot].VariableScope.Mission.DeliverItem:Set["The Anomaly (3 of 3)", "Fajah Ateshi"]	<-- Not required anymore
	Script[Tehbot].VariableScope.Mission.DeliverItemContainer:Set["The Anomaly (3 of 3)", "Name = \"The Anomaly\""]

	;
	; Finally, use the BlackListedMission set to specify mission the bot should skip. TAKE NOTE, this is NOT a collection like all the above tools.
	; It only takes one argument (the name of the mission) and uses the "Add" method instead of the "Set" method.
	;
	Script[Tehbot].VariableScope.Mission.BlackListedMission:Add["Surprise Surprise"]

	echo done
}