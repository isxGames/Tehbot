; This is a template for writing mission configs.  One thing to keep in mind: For some reason CCP has added a space after some mission names.

function main()
{
	;
	; For most missions, all you need to do is use the ValidMissions collection to specify the mission name and the damage type.
	; Thus, the bot knows the mission is valid and what type of ammo to load.
	; The bot will fly to the mission location, kill everything, and follow gates until it sees the mission is done.
	;
	Script[Tehbot].VariableScope.Mission.ValidMissions:Set["Gone Berserk", "Kinetic"]

	;
	; Some missions also require that you kill a target.  To configure these, use the AttackTarget collection.
	; This collection requires the mission name and a search string.  Most of these use the Name member.  Note the single equal and the \ escaped quotes!
	;
	Script[Tehbot].VariableScope.Mission.ValidMissions:Set["The Right Hand Of Zazzmatazz", "Kinetic"]
	Script[Tehbot].VariableScope.Mission.AttackTarget:Set["The Right Hand Of Zazzmatazz", "Name = \"Outpost Headquarters\""]

	;
	; Some missions further require that you receive an item.  To configure these, use the ItemsRequired collection.
	; This collection requires the mission name and the name of the item.  Note that this will not loot the item from a container - it's for missions that deposit an item in your cargo hold
	; when you kill a target.  For looting a needed item, see the next section.
	;
	Script[Tehbot].VariableScope.Mission.ValidMissions:Set["The Damsel In Distress", "Kinetic"]
	Script[Tehbot].VariableScope.Mission.AttackTarget:Set["The Damsel In Distress", "Name = \"Kruul's Pleasure Gardens\""]				
	Script[Tehbot].VariableScope.Mission.ItemsRequired:Set["The Damsel In Distress", "The Damsel"]

	;
	; For some missions, you must loot an item.  To configure these, use the LootContainers AND the ItemsRequired collections.
	; This collection requires the mission name and a search string.  Most of these use the Name member, but also empty wrecks need to be excluded.  Note the single equal and the \ escaped quotes!
	;
	Script[Tehbot].VariableScope.Mission.ValidMissions:Set["Unauthorized Military Presence", "EM"]
	Script[Tehbot].VariableScope.Mission.LootContainers:Set["Unauthorized Military Presence", "Name = \"Blood Raider Personnel Transport Wreck\" && !IsWreckEmpty"]
	Script[Tehbot].VariableScope.Mission.ItemsRequired:Set["Unauthorized Military Presence", "Militants"]

	;
	; Finally, use the InvalidMissions set to specify mission the bot should skip.  TAKE NOTE, this is NOT a collection like all the above tools.
	; It only takes one argument (the name of the mission) and uses the "Add" method instead of the "Set" method.
	;
	Script[Tehbot].VariableScope.Mission.InvalidMissions:Add["Worlds Collide"]
	
	echo done
}