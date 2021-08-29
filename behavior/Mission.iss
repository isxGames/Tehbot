objectdef obj_Configuration_Mission
{
	variable string SetName = "Mission"

	method Initialize()
	{
		if !${BaseConfig.BaseRef.FindSet[${This.SetName}](exists)}
		{
			UI:Update["Configuration", " ${This.SetName} settings missing - initializing", "o"]
			This:Set_Default_Values[]
		}
		UI:Update["Configuration", " ${This.SetName}: Initialized", "-g"]
	}

	member:settingsetref CommonRef()
	{
		return ${BaseConfig.BaseRef.FindSet[${This.SetName}]}
	}
	


	method Set_Default_Values()
	{
		BaseConfig.BaseRef:AddSet[${This.SetName}]
		This.CommonRef:AddSetting[Threshold,100]
		This.CommonRef:AddSetting[SalvagePrefix,Salvage: ]
	}
	
	Setting(bool, Halt, SetHalt)
	Setting(bool, Secondary, SetSecondary)
	Setting(bool, Drones, SetDrones)
	Setting(bool, RangeLimit, SetRangeLimit)
	Setting(string, SalvagePrefix, SetSalvagePrefix)
	Setting(string, DropoffType, SetDropoffType)
	Setting(string, DropoffSubType, SetDropoffSubType)
	Setting(string, DroneType, SetDroneType)
	Setting(string, Agent, SetAgent)
	Setting(string, MissionFile, SetMissionFile)
	Setting(string, KineticAmmo, SetKineticAmmo)
	Setting(string, ThermalAmmo, SetThermalAmmo)
	Setting(string, EMAmmo, SetEMAmmo)
	Setting(string, ExplosiveAmmo, SetExplosiveAmmo)
	Setting(string, KineticAmmoSecondary, SetKineticAmmoSecondary)
	Setting(string, ThermalAmmoSecondary, SetThermalAmmoSecondary)
	Setting(string, EMAmmoSecondary, SetEMAmmoSecondary)
	Setting(string, ExplosiveAmmoSecondary, SetExplosiveAmmoSecondary)
	Setting(int, Level, SetLevel)
	Setting(int, Threshold, SetThreshold)	

}

objectdef obj_Mission inherits obj_State
{
	variable int agentIndex = 0
	variable string missiontarget
	variable string ammo
	variable string secondaryammo
	variable string lootcontainer
	variable string itemneeded
	
	variable collection:string ValidMissions
	variable collection:string AttackTarget
	variable collection:string LootContainers
	variable collection:string ItemsRequired
	variable collection:float64 CapacityRequired
	variable set InvalidMissions
	
	variable bool reload = TRUE
	variable collection:int FWStatus
	variable bool halt = FALSE
	
	variable obj_TargetList NPC	
	variable obj_TargetList ActiveNPC	
	variable obj_TargetList Wrecks
	
	variable obj_Configuration_Mission Config
	variable obj_MissionUI LocalUI
	
	
	method Initialize()
	{
		This[parent]:Initialize

		DynamicAddBehavior("Mission", "Combat Missions")		
		This.PulseFrequency:Set[500]		

		LavishScript:RegisterEvent[Tehbot_ScheduleHalt]
		Event[Tehbot_ScheduleHalt]:AttachAtom[This:ScheduleHalt]
		LavishScript:RegisterEvent[Tehbot_ScheduleResume]
		Event[Tehbot_ScheduleResume]:AttachAtom[This:ScheduleResume]
		
		NPC:AddAllNPCs
		ActiveNPC:AddTargetingMe
		Wrecks:AddQueryString["(GroupID==GROUP_WRECK || GroupID==GROUP_CARGOCONTAINER) && !IsMoribund"]
	}

	method ScheduleHalt()
	{
		halt:Set[TRUE]
	}	
	
	method ScheduleResume()
	{
		halt:Set[FALSE]
		if ${This.IsIdle}
		{
			This:Start
		}
	}
	
	method Start()
	{
		ValidMissions:Clear
		LootContainers:Clear
		ItemsRequired:Clear
		InvalidMissions:Clear
		AttackTarget:Clear

		if !${Config.MissionFile.NotNULLOrEmpty}
		{
			UI:Update["obj_Mission", "You need to specify a mission file!", "r"]
			return
		}
		
		variable filepath MissionData = "${Script[Tehbot].CurrentDirectory}/data/${Config.MissionFile}"
		runscript "${MissionData}"
		
		
		if ${This.IsIdle}
		{
			UI:Update["obj_Mission", "Started", "g"]
			This:QueueState["UpdateTargets"]
			This:QueueState["ReportMissionConfigs"]
			This:QueueState["CheckForWork"]
			EVE:RefreshBookmarks
		}
	}
	
	method Stop()
	{
		This:Clear
	}	

	member:bool test()
	{
		echo ${Config.Halt}
	}
	
	member:bool UpdateTargets()
	{
		NPC:RequestUpdate
		return TRUE
	}

	member:bool ReportMissionConfigs()
	{
		UI:Update["obj_Mission", "Mission Configuration Loaded", "g"]
		UI:Update["obj_Mission", " ${ValidMissions.Used} Missions Configured", "o"]
		return TRUE
	}
	
	member:bool Repair()
	{
		if !${Client.InSpace}
		{
			if !${EVEWindow[RepairShop](exists)}
			{
				MyShip.ToItem:GetRepairQuote
				return TRUE
			}
			else
			{
				if ${EVEWindow[byName, modal](exists)} && ${EVEWindow[byName, modal].Text.Find[Repairing these items]}
				{
					EVEWindow[byName, modal]:ClickButtonYes
					Client:Wait[1000]
					return TRUE
				}
				if ${EVEWindow[byName,"Set Quantity"](exists)}
				{
					EVEWindow[byName,"Set Quantity"]:ClickButtonOK
					Client:Wait[1000]
					return TRUE
				}
				if !${EVEWindow[RepairShop].TotalCost.Equal[0]}
				{
					EVEWindow[RepairShop]:RepairAll
					return TRUE
				}
			}
		}
		return FALSE
	}

	member:string AgentName(int ID)
	{
		return ${EVE.Agent[${ID}].Name}
	}
	
	member:bool CheckForWork()
	{
		if ${agentIndex} == 0
		{
			agentIndex:Set[${EVE.Agent[${Config.Agent}].Index}]
		}
		variable index:agentmission Missions
		variable iterator m
		
		EVE:GetAgentMissions[Missions]
		Missions:GetIterator[m]
		if ${m:First(exists)}
			do
			{
				if ${m.Value.AgentID} != ${EVE.Agent[${agentIndex}].ID}
					continue
				if !${EVEWindow[ByCaption, Mission journal - ${This.AgentName[${agentIndex}]}](exists)}
				{
					m.Value:GetDetails
					return FALSE
				}
				
				if ${m.Value.State} == 1
				{
					This:InsertState["CheckForWork"]
					if ${ValidMissions.FirstKey(exists)}
						do
						{
							if ${EVEWindow[ByCaption, Mission journal - ${This.AgentName[${agentIndex}]}].HTML.Find[${ValidMissions.CurrentKey} Objectives]}
							{
								UI:Update["Mission", "Accepting mission", "g"]
								UI:Update["Mission", " ${m.Value.Name}", "o"]
								This:InsertState["InteractAgent", 1500, "ACCEPT"]
							}
						}
						while ${ValidMissions.NextKey(exists)}
					
					if ${InvalidMissions.FirstKey(exists)}
						do
						{
							if ${EVEWindow[ByCaption, Mission journal - ${This.AgentName[${agentIndex}]}].HTML.Find[${InvalidMissions.CurrentKey} Objectives]}
							{
								UI:Update["Mission", "Declining mission", "g"]
								UI:Update["Mission", " ${m.Value.Name}", "o"]
								This:InsertState["InteractAgent", 1500, "DECLINE"]
							}
						}
						while ${InvalidMissions.NextKey(exists)}
						
					This:InsertState["Cleanup"}
					return TRUE				
				}
				
				if ${m.Value.State} == 2
				{
					if ${ValidMissions.FirstKey(exists)}
					do
					{
						if ${EVEWindow[ByCaption, Mission journal - ${This.AgentName[${agentIndex}]}].HTML.Find[${ValidMissions.CurrentKey} Objectives Complete]}
						{
							UI:Update["Mission", "Mission Complete", "g"]
							UI:Update["Mission", " ${m.Value.Name}", "o"]
							This:InsertState["CompleteMission"]
							This:InsertState["Cleanup"]
							return TRUE
						}
						if ${EVEWindow[ByCaption, Mission journal - ${This.AgentName[${agentIndex}]}].HTML.Find[${ValidMissions.CurrentKey} Objectives]}
						{
							UI:Update["Mission", "Active mission identified", "g"]
							UI:Update["Mission", " ${m.Value.Name}", "o"]
							
							
							if ${AttackTarget.Element[${ValidMissions.CurrentKey}](exists)}
								missiontarget:Set[${AttackTarget.Element[${ValidMissions.CurrentKey}]}]
							else
								missiontarget:Set[""]
							
							switch ${ValidMissions.CurrentValue.Lower}
							{
								case kinetic
									ammo:Set[${Config.KineticAmmo}]
									if ${Config.Secondary}
										secondaryammo:Set[${Config.KineticAmmoSecondary}]
									else
										secondaryammo:Set[""]
									break
								case em
									ammo:Set[${Config.EMAmmo}]
									if ${Config.Secondary}
										secondaryammo:Set[${Config.EMAmmoSecondary}]
									else
										secondaryammo:Set[""]
									break
								case thermal
									ammo:Set[${Config.ThermalAmmo}]
									if ${Config.Secondary}
										secondaryammo:Set[${Config.ThermalAmmoSecondary}]
									else
										secondaryammo:Set[""]
									break
								case explosive
									ammo:Set[${Config.ExplosiveAmmo}]
									if ${Config.Secondary}
										secondaryammo:Set[${Config.ExplosiveAmmoSecondary}]
									else
										secondaryammo:Set[""]
									break
								default
									ammo:Set[${Config.KineticAmmo}]
									if ${Config.Secondary}
										secondaryammo:Set[${Config.KineticAmmoSecondary}]
									else
										secondaryammo:Set[""]
									break
							}
								
							if ${LootContainers.Element[${ValidMissions.CurrentKey}](exists)}
								lootcontainer:Set[${LootContainers.Element[${ValidMissions.CurrentKey}]}]
							else
								lootcontainer:Set[""]
							if ${ItemsRequired.Element[${ValidMissions.CurrentKey}](exists)}
							{
								itemneeded:Set[${ItemsRequired.Element[${ValidMissions.CurrentKey}]}]
								variable index:item cargo
								variable iterator c
								if (!${EVEWindow[Inventory](exists)})
								{
									EVE:Execute[OpenInventory]
									return FALSE
								}								
								if !${EVEWindow[Inventory].ChildWindow[${Me.ShipID},ShipCargo]:GetItems[cargo](exists)}
								{
									EVEWindow[Inventory].ChildWindow[${Me.ShipID},ShipCargo]:MakeActive
									return FALSE
								}
								cargo:GetIterator[c]
								if ${c:First(exists)}
									do
									{
										if ${c.Value.Name.Equal[${ItemsRequired.Element[${ValidMissions.CurrentKey}]}]}
										{
											UI:Update["Mission", "Mission Complete", "g"]
											UI:Update["Mission", " ${m.Value.Name}", "o"]
											This:InsertState["CompleteMission"]
											This:InsertState["Cleanup"]
											return TRUE
										}
									}
									while ${c:Next(exists)}	
							}
							
							if ${Client.InSpace} && (${Entity[Type = "Beacon"]} || ${Entity[Type = "Acceleration Gate"]})
							{
								This:InsertState["PerformMission"]
								This:InsertState["Cleanup"]
								return TRUE
							}							
						}
					}
					while ${ValidMissions.NextKey(exists)}

					if ${Me.InStation} && ${reload}
					{
						UI:Update["Mission", "Loading Ammo", "g"]
						UI:Update["Mission", " ${ammo}", "o"]
						if ${Config.Secondary}
							UI:Update["Mission", " ${secondaryammo}", "o"]
						reload:Set[FALSE]
						This:InsertState["CheckForWork"]
						This:InsertState["LoadAmmo"]
						This:InsertState["PrepHangars"]
						return TRUE
					}
					
					variable index:bookmark missionBookmarks
					variable iterator b
					m.Value:GetBookmarks[missionBookmarks]
					missionBookmarks:GetIterator[b]
					if ${b:First(exists)}
						do
						{
							if ${b.Value.LocationType.Equal[dungeon]}
							{
								Move:AgentBookmark[${b.Value.ID}]
								This:InsertState["PerformMission"]
								This:InsertState["Traveling"]
								This:InsertState["Cleanup"]
								reload:Set[TRUE]
								return TRUE
							}
						}
						while ${b:Next(exists)}	
		
				}
			}
			while ${m:Next(exists)}	
		This:InsertState["CheckForWork"]
		UI:Update["Mission", "Requesting mission", "g"]
		This:InsertState["InteractAgent", 1500, "OFFER"]
		This:InsertState["Cleanup"]
		return TRUE			
	}
	
	member:set WebbingMe()
	{
		variable set webs
		variable index:attacker attackers
		variable iterator attackeriterator
		Me:GetAttackers[attackers]
		attackers:GetIterator[attackeriterator]
		if ${attackeriterator:First(exists)}
		do
		{
			variable index:attack attacks
			variable iterator attackiterator
			attackeriterator.Value:GetAttacks[attacks]
			attacks:GetIterator[attackiterator]
			if ${attackiterator:First(exists)}
			do
			{
				if ${attackiterator.Value.Name.Find[effects.ModifyTargetSpeed]}
				{
					webs:Add[${attackeriterator.Value.ID]
				}
			}
			while ${attackiterator:Next(exists)}		
		}
		while ${attackeriterator:Next(exists)}			
		return webs
	}
	
	method BuildActiveNPC()
	{
		variable iterator classIterator
		variable iterator groupIterator
		variable string groups = ""
		variable string seperator = ""

		ActiveNPC:ClearQueryString

		variable int range = ${Math.Calc[${MyShip.MaxTargetRange} * .95]}

		variable index:attacker attackers
		variable iterator attackeriterator
		Me:GetAttackers[attackers]
		attackers:GetIterator[attackeriterator]
		if ${attackeriterator:First(exists)}
		do
		{
			variable index:attack attacks
			variable iterator attackiterator
			attackeriterator.Value:GetAttacks[attacks]
			attacks:GetIterator[attackiterator]
			if ${attackiterator:First(exists)}
			do
			{
				if ${attackiterator.Value.Name.Find[effects.ModifyTargetSpeed]}
				{
					groups:Concat[${seperator}ID =- "${attackeriterator.Value.ID}"]
					seperator:Set[" || "]
				}
			}
			while ${attackiterator:Next(exists)}		
		}
		while ${attackeriterator:Next(exists)}			
		
		ActiveNPC:AddQueryString["IsNPC && !IsMoribund && (${groups})"]
		ActiveNPC:AddQueryString["IsNPC && !IsMoribund && IsWarpScramblingMe"]

		seperator:Set[""]
		groups:Set[""]
		PriorityTargets.Scramble:GetIterator[groupIterator]
		if ${groupIterator:First(exists)}
		{
			do
			{
				groups:Concat[${seperator}Name =- "${groupIterator.Value}"]
				seperator:Set[" || "]
			}
			while ${groupIterator:Next(exists)}
		}
		ActiveNPC:AddQueryString["IsNPC && IsTargetingMe && !IsMoribund && (${groups})"]

		seperator:Set[""]
		groups:Set[""]
		PriorityTargets.Neut:GetIterator[groupIterator]
		if ${groupIterator:First(exists)}
		{
			do
			{
				groups:Concat[${seperator}Name =- "${groupIterator.Value}"]
				seperator:Set[" || "]
			}
			while ${groupIterator:Next(exists)}
		}
		ActiveNPC:AddQueryString["IsNPC && IsTargetingMe && !IsMoribund && (${groups})"]

		seperator:Set[""]
		groups:Set[""]
		PriorityTargets.ECM:GetIterator[groupIterator]
		if ${groupIterator:First(exists)}
		{
			do
			{
				groups:Concat[${seperator}Name =- "${groupIterator.Value}"]
				seperator:Set[" || "]
			}
			while ${groupIterator:Next(exists)}
		}
		ActiveNPC:AddQueryString["IsNPC && IsTargetingMe && !IsMoribund && (${groups})"]



		NPCData.BaseRef:GetSetIterator[classIterator]
		if ${classIterator:First(exists)}
		{
			do
			{
				seperator:Set[""]
				groups:Set[""]
				classIterator.Value:GetSettingIterator[groupIterator]
				if ${groupIterator:First(exists)}
				{
					do
					{
						groups:Concat["${seperator}GroupID = ${groupIterator.Key}"]
						seperator:Set[" || "]
					}
					while ${groupIterator:Next(exists)}
				}
				ActiveNPC:AddQueryString["IsNPC && IsTargetingMe && !IsMoribund && (${groups})"]
			}
			while ${classIterator:Next(exists)}
		}

		ActiveNPC:AddTargetingMe	
	}

	variable bool looted=FALSE
	variable int64 activetarget = 0
	variable set blacklistedcontainers
	variable int WCgateUsed=0
	variable int64 currentLootContainer
	variable int64 approachTimer
	variable bool notdone=FALSE
	member:bool PerformMission(int nextwaitcomplete = 0)
	{
		variable iterator c
		This:BuildActiveNPC
		Wrecks:RequestUpdate
		ActiveNPC:RequestUpdate
		NPC:RequestUpdate
		variable iterator TargetIterator
		Ship.ModuleList_ActiveResists:Activate
		variable index:bookmark BookmarkIndex


		if ${Me.ToEntity.Mode} == 3
		{
			This:InsertState["PerformMission"]
			return TRUE
		}

		variable index:entity lootcontainers
		EVE:QueryEntities[lootcontainers, ${lootcontainer}]
		
		variable iterator b
		blacklistedcontainers:GetIterator[b]
		if ${b:First(exists)}
			do
			{
				lootcontainers:RemoveByQuery[${LavishScript.CreateQuery[ID = ${b.Value}]}]
			}
			while ${b:Next(exists)}
		lootcontainers:Collapse
		
		if ${lootcontainers.Used}
		{
			lootcontainers:GetIterator[c]
		}
		if ${lootcontainer.NotNULLOrEmpty} && ${lootcontainers.Used}
		{
			if !${currentLootContainer}
			{
				currentLootContainer:Set[${lootcontainers.Get[1].ID}]
			}
			else
			{
			
				if !${Entity[${currentLootContainer}](exists)} || ${Entity[${currentLootContainer}].IsWreckEmpty} || ${Entity[${currentLootContainer}].IsMoribund}
				{
					currentLootContainer:Set[0]
				}
				else
				{
					if ${Entity[${currentLootContainer}].Distance} > 2500
					{
						if ${MyShip.ToEntity.Mode} != 1 || ${LavishScript.RunningTime} > ${approachTimer}
						{
							Entity[${currentLootContainer}]:Approach[1000]
							This:InsertState["PerformMission"]
							approachTimer:Set[${Math.Calc[${LavishScript.RunningTime} + 10000]}]
							return TRUE
						}
						if ${Ship.ModuleList_TractorBeams.Count}
						{
							if !${Entity[${currentLootContainer}].IsLockedTarget}
							{
								if !${Entity[${currentLootContainer}].BeingTargeted}
								{
									Entity[${currentLootContainer}]:LockTarget
									This:InsertState["PerformMission"]
									return TRUE
								
								}
							}
							else
							{
								if ${Ship.ModuleList_TractorBeams.GetActiveOn[${currentLootContainer}]} < 1 && ${Entity[${currentLootContainer}].Distance} < ${Ship.ModuleList_TractorBeams.Range}
								{
									Ship.ModuleList_TractorBeams:Activate[${currentLootContainer}]
									Ship.ModuleList_TractorBeams:DeactivateNotOn[${currentLootContainer}]								
									This:InsertState["PerformMission"]
									return TRUE
								}
							}
						}
						notdone:Set[TRUE]
					}
					elseif !${NPC.TargetList.Used}
					{
						variable index:item cargo
						if !${EVEWindow[Inventory].ChildWindow[${currentLootContainer}](exists)}
						{
							Entity[${currentLootContainer}]:Open
							This:InsertState["PerformMission"]
							return TRUE
						}
						else
						{
							EVEWindow[Inventory].ChildWindow[${currentLootContainer}]:GetItems[cargo]
							if ${cargo.Used}
							{
								cargo:GetIterator[c]
								if ${c:First(exists)}
									do
									{
										if ${c.Value.Type.Equal[${itemneeded}]}
										{
											c.Value:MoveTo[${MyShip.ID}, CargoHold]
											This:InsertState["PerformMission"]
											notdone:Set[FALSE]
											return TRUE
										}
									}
									while ${c:Next(exists)}
								blacklistedcontainers:Add[${currentLootContainer}]
								currentLootContainer:Set[0]
								EVE:Execute[CmdStopShip]
								This:InsertState["PerformMission"]
								notdone:Set[FALSE]
								return TRUE
							}
							else
							{
								blacklistedcontainers:Add[${currentLootContainer}]
								currentLootContainer:Set[0]
								EVE:Execute[CmdStopShip]
								This:InsertState["PerformMission"]
								notdone:Set[FALSE]
								return TRUE
							}
						}
					}
					else
					{
						notdone:Set[TRUE]
					}
				}
			}
		}
		else
		{
			notdone:Set[FALSE]
			if ${Entity[Type = "Acceleration Gate"]}
			{
				if ${MyShip.ToEntity.Mode} != 4 && ${MyShip.ToEntity.Mode} != 1
				{
					Entity[Type = "Acceleration Gate"]:Orbit[2000]
					This:InsertState["PerformMission"]
					return TRUE
				}
			}
			elseif ${Entity[Name = "Acceleration Gate (Locked Down)"]}
			{
				if ${MyShip.ToEntity.Mode} != 4 && ${MyShip.ToEntity.Mode} != 1
				{
					Entity[Name = "Acceleration Gate (Locked Down)"]:Orbit[2000]
					This:InsertState["PerformMission"]
					return TRUE
				}
			}
			elseif ${Entity[Type = "Beacon"]}
			{
				if ${MyShip.ToEntity.Mode} != 4 && ${MyShip.ToEntity.Mode} != 1
				{
					Entity[Type = "Beacon"]:Orbit[2000]
					This:InsertState["PerformMission"]
					return TRUE
				}
			}
		}
			
		if ${EVEWindow[Telecom](exists)}
		{
			EVEWindow[Telecom]:Close
			return FALSE
		}
		
		if ${This.WebbingMe.Used} && ${activetarget} != 0 && !${This.WebbingMe.Contains[${activetarget}]}
		{
			variable iterator web
			This.WebbingMe:GetIterator[web]
			
			web:First
			activetarget:Set[${web.Value}]
		}
		
		variable int MaxTarget = ${MyShip.MaxLockedTargets}		
		if ${Me.MaxLockedTargets} < ${MyShip.MaxLockedTargets}
			MaxTarget:Set[${Me.MaxLockedTargets}]
		MaxTarget:Dec[2]
		
		ActiveNPC.MinLockCount:Set[${MaxTarget}]
		ActiveNPC.AutoLock:Set[TRUE]
		
		if ${activetarget} != 0 && !${Entity[${activetarget}].IsLockedTarget} && !${Entity[${activetarget}].BeingTargeted}
			activetarget:Set[0]
		
		if ${activetarget} == 0 || ${Entity[${activetarget}].IsMoribund} || !${Entity[${activetarget}]}
		{
			if ${ActiveNPC.LockedTargetList.Used}
			{
				activetarget:Set[${ActiveNPC.LockedTargetList.Get[1]}]
				if (${activetarget} == ${DroneControl.CurrentTarget} || \
					(${Entity[${activetarget}].Group.Find[Frigate]} && ${Entity[${activetarget}].Distance} > 15000) || \
					(${Entity[${activetarget}].Group.Find[Destroyer]} && ${Entity[${activetarget}].Distance} > 15000)) && \
					${ActiveNPC.LockedTargetList.Get[2](exists)}
					activetarget:Set[${ActiveNPC.LockedTargetList.Get[2]}]
				if (${activetarget} == ${DroneControl.CurrentTarget} || \
					(${Entity[${activetarget}].Group.Find[Frigate]} > 0 && ${Entity[${activetarget}].Distance} > 15000) || \
					(${Entity[${activetarget}].Group.Find[Destroyer]} && ${Entity[${activetarget}].Distance} > 15000)) && \
					${ActiveNPC.LockedTargetList.Get[3](exists)}
					activetarget:Set[${ActiveNPC.LockedTargetList.Get[3]}]
				UI:Update["Mission", "Primary target: \ar${Entity[${activetarget}].Name}", "g"]				
			}
			else
				activetarget:Set[0]
		}
		
		if (${activetarget} == 0 || ${activetarget} == ${ActiveNPC.TargetList.Get[1].ID}) && ${ActiveNPC.TargetList.Get[1].Distance} > 90000 && ${MyShip.ToEntity.Mode} != 1
		{
			UI:Update["Mission", "Deactivate siege module due to no target", "g"]
			Ship.ModuleList_Siege:Deactivate
			UI:Update["Mission", "Approaching far target: \ar${ActiveNPC.TargetList.Get[1].Name}", "g"]				
			ActiveNPC.TargetList.Get[1]:Approach
			This:InsertState["PerformMission"]
			return TRUE
		}
		
		if ${activetarget} != 0 && !${Entity[${activetarget}].IsMoribund} && ${Entity[${activetarget}]}
		{
			Ship.ModuleList_Siege:Activate
			if ${Ship.ModuleList_Weapon.Range} > ${Entity[${activetarget}].Distance} || !${Config.RangeLimit}
				Ship.ModuleList_Weapon:Activate[${activetarget}]
			Ship.ModuleList_TargetPainter:Activate[${activetarget}]
			Ship.ModuleList_Weapon:DeactivateNotOn[${activetarget}]
			Ship.ModuleList_TargetPainter:DeactivateNotOn[${activetarget}]
			if ${Entity[${activetarget}].Distance} <= 30000
			{
				Ship.ModuleList_StasisGrap:Activate[${activetarget}]
				Ship.ModuleList_StasisGrap:DeactivateNotOn[${activetarget}]
			}
			if ${Entity[${activetarget}].Distance} <= 15000
			{
				Ship.ModuleList_StasisWeb:Activate[${activetarget}]
				Ship.ModuleList_StasisWeb:DeactivateNotOn[${activetarget}]
			}
		}

		if ${ActiveNPC.TargetList.Used} || ${nextwaitcomplete} == 0
		{
			This:InsertState["PerformMission", 500, ${Math.Calc[${LavishScript.RunningTime} + 10000]}]
			return TRUE
		}
		
		if ${LavishScript.RunningTime} < ${nextwaitcomplete}
			return FALSE
		
		NPC.MinLockCount:Set[1]
		NPC.AutoLock:Set[TRUE]
		
		if ${NPC.TargetList.Used}
		{
			if ${NPC.TargetList.Get[1].Distance} > ${Math.Calc[${Ship.ModuleList_Weapon.MaxRange} * .95]} && ${MyShip.ToEntity.Mode} != 1
			{
				NPC.TargetList.Get[1]:Approach
			}
			
			if ${activetarget} == 0 || ${Entity[${activetarget}].IsMoribund} || !${Entity[${activetarget}]}
			{
				if ${NPC.LockedTargetList.Used}
					activetarget:Set[${NPC.LockedTargetList.Get[1]}]
				else
					activetarget:Set[0]
			}			
			This:InsertState["PerformMission"]
			return TRUE
		}

		DroneControl:Recall

		if ${Entity[Name = "Drone Structure II"](exists)}
		{
			if !${Entity[Name = "Drone Structure II"].IsLockedTarget} && !${Entity[Name = "Drone Structure II"].BeingTargeted}
			{
				UI:Update["Mission", "Locking Mission Target", "g"]
				UI:Update["Mission", " ${Entity[Name = \"Drone Structure II\"].Name}", "o"]
				Entity[Name = "Drone Structure II"]:LockTarget
			}
			Ship.ModuleList_Weapon:ActivateAll[${Entity[Name = "Drone Structure II"].ID}]
			This:InsertState["PerformMission"]
			return TRUE
		}
		
		if ${Entity[${missiontarget}]}
		{
			if ${Entity[${missiontarget}].Distance} > ${Math.Calc[${Ship.ModuleList_Weapon.MaxRange} * .95]} && ${MyShip.ToEntity.Mode} != 1
			{
				Entity[${missiontarget}]:Approach
			}
			if !${Entity[${missiontarget}].IsLockedTarget} && !${Entity[${missiontarget}].BeingTargeted}
			{
				UI:Update["Mission", "Locking Mission Target", "g"]
				UI:Update["Mission", " ${Entity[${missiontarget}].Name}", "o"]
				Entity[${missiontarget}]:LockTarget
			}
			elseif !${Entity[${missiontarget}].BeingTargeted}
			{
				Ship.ModuleList_Weapon:ActivateAll[${Entity[${missiontarget}].ID}]
			}	
			This:InsertState["PerformMission"]
			return TRUE
		}
		
		if ${notdone} || ${Busy.IsBusy}
		{
			This:InsertState["PerformMission"]
			return TRUE
		}
		
		if ${Entity[Type = "Acceleration Gate"]} && !${EVEWindow[byName, modal].Text.Find[This gate is locked!]}
		{
			UI:Update["Mission", "Deactivate siege module due to approaching", "g"]
			Ship.ModuleList_Siege:Deactivate
			if ${Wrecks.TargetList.Used} && ${Config.SalvagePrefix.NotNULLOrEmpty}
			{
				EVE:GetBookmarks[BookmarkIndex]
				BookmarkIndex:RemoveByQuery[${LavishScript.CreateQuery[SolarSystemID == ${Me.SolarSystemID}]}, FALSE]
				BookmarkIndex:RemoveByQuery[${LavishScript.CreateQuery[Distance < 200000]}, FALSE]
				BookmarkIndex:Collapse
				
				if !${BookmarkIndex.Used}
					Wrecks.TargetList.Get[1]:CreateBookmark["${Config.SalvagePrefix} ${Config.Agent} ${Me.Name} ${EVETime.Time.Left[5]}", "", "Corporation Locations", 1]
			}
			activetarget:Set[0]
			Move:Gate[${Entity[Type = "Acceleration Gate"]}]
			This:InsertState["PerformMission"]
			This:InsertState["Traveling"]
			This:InsertState["ReloadWeapons"]
			return TRUE
		}
		
		if ${Wrecks.TargetList.Used} && ${Config.SalvagePrefix.NotNULLOrEmpty}
		{
			EVE:GetBookmarks[BookmarkIndex]
			BookmarkIndex:RemoveByQuery[${LavishScript.CreateQuery[SolarSystemID == ${Me.SolarSystemID}]}, FALSE]
			BookmarkIndex:RemoveByQuery[${LavishScript.CreateQuery[Distance < 200000]}, FALSE]
			BookmarkIndex:Collapse
			
			if !${BookmarkIndex.Used}
				Wrecks.TargetList.Get[1]:CreateBookmark["${Config.SalvagePrefix} ${Config.Agent} ${EVETime.Time.Left[5]}", "", "Corporation Locations", 1]
		}

		activetarget:Set[0]
		This:InsertState["CheckForWork"]
		This:InsertState["ReloadWeapons"]
		looted:Set[FALSE]
		return TRUE
	}
	
	
	
	member:bool ReloadWeapons()
	{
		EVE:Execute[CmdReloadAmmo]
		return TRUE
	}
	
	member:bool Cleanup()
	{
		if ${Me.InStation} && ${This.Repair}
		{
			This:InsertState["Cleanup", 2000]
			return TRUE
		}
		if ${EVEWindow[AgentBrowser](exists)}
		{
			EVEWindow[AgentBrowser]:Close
			return FALSE
		}
		if ${EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}](exists)}
		{
			EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}]:Close
			return FALSE
		}
		if ${EVEWindow[ByCaption, Mission journal](exists)}
		{
			EVEWindow[ByCaption, Mission journal]:Close
			return FALSE
		}
		if ${EVEWindow[RepairShop](exists)}
		{
			EVEWindow[RepairShop]:Close
		}
		return TRUE
	}
	
	member:bool CompleteMission()
	{
		if ${Me.InSpace}  
		{
			UI:Update["Mission", "Deactivate siege module due to mission complete", "g"]
			Ship.ModuleList_Siege:Deactivate
		}

		if ${Me.StationID} != ${EVE.Agent[${agentIndex}].StationID}
		{
			UI:Update["Mission", "Need to be at agent station to complete mission", "g"]
			UI:Update["Mission", "Setting course for \ao${EVE.Station[${EVE.Agent[${agentIndex}].StationID}].Name}", "g"]
			Move:Agent[${agentIndex}]
			This:InsertState["CompleteMission"]
			This:InsertState["Traveling"]
			return TRUE
		}
		
		
		if !${EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}](exists)}
		{
			EVE.Agent[${agentIndex}]:StartConversation
			Client:Wait[3000]
			return FALSE
		}
		
		if ${CloseAgentInteraction}
		{
			if ${EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}](exists)}
				EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}]:Close
		}
		else
		{
			if ${EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["View Mission"](exists)}
			{
				EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["View Mission"]:Press
				This:InsertState[CompleteMission, 1500]
				return TRUE
			}
			
			if ${EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["Complete Mission"](exists)}
			{
				EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["Complete Mission"]:Press
				relay "all" -event Tehbot_SalvageBookmark ${Me.ID}
			}
		}
			
		variable index:agentmission Missions
		variable iterator m
		
		EVE:GetAgentMissions[Missions]
		Missions:GetIterator[m]
		if ${m:First(exists)}
			do
			{
				if ${m.Value.AgentID} == ${EVE.Agent[${agentIndex}].ID} && ${m.Value.State} == 2
					return FALSE
			}
			while ${m:Next(exists)}

		if !${Config.Halt} && !${halt}
		{
			This:InsertState[CheckForWork]
			This:InsertState[InteractAgent, 1500, "OFFER"]
			This:InsertState[SalvageCheck]
			This:InsertState[RefreshBookmarks]
		}
		else
		{
			UIElement[Run@TitleBar@Tehbot]:SetText[Run]
		}
		halt:Set[FALSE]
		This:InsertState["UnloadAmmo"]			
		CloseAgentInteraction:Set[FALSE]
		return TRUE
	}	

	variable bool CloseAgentInteraction=FALSE
	member:bool InteractAgent(string Action)
	{
		if ${Me.StationID} != ${EVE.Agent[${agentIndex}].StationID}
		{
			Move:Bookmark[${EVE.Agent[${agentIndex}].StationID}]
			This:InsertState["InteractAgent", 1500, "${agentIndex}, ${Action}]
			This:InsertState["Traveling"]
			return TRUE
		}
		
		if !${EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}](exists)}
		{
			EVE.Agent[${agentIndex}]:StartConversation
			return FALSE
		}
		
		if ${CloseAgentInteraction}
		{
			if ${EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}](exists)}
				EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}]:Close
		}
		else
		{
			switch ${Action} 
			{
				case OFFER
					if ${EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["View Mission"](exists)}
					{
						EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["View Mission"]:Press
						return FALSE
					}
					if ${EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["Request Mission"](exists)}
					{
						EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["Request Mission"]:Press
					}
					
					break
				case ACCEPT
					if ${EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["Request Mission"](exists)}
					{
						EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["Request Mission"]:Press
						return FALSE
					}
					if ${EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["View Mission"](exists)}
					{
						EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["View Mission"]:Press
						return FALSE
					}
					if ${EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["Accept"](exists)}
					{
						EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["Accept"]:Press
						return FALSE
					}
					if ${EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["Close"](exists)}
					{
						EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["Close"]:Press
					}
					break
				case DECLINE
					if ${EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["View Mission"](exists)}
					{
						EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["View Mission"]:Press
						return FALSE
					}
					if ${EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["Decline"](exists)}
					{
						EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["Decline"]:Press
						variable time NextTime=${Time.Timestamp}
						NextTime.Hour:Inc[4]
						NextTime:Update
						Config:Save
					}
					break
			}
		}
		CloseAgentInteraction:Set[FALSE]
		return TRUE
	}	
	
	
	member:bool StackShip()
	{
		EVEWindow[Inventory].ChildWindow[${Me.ShipID},ShipCargo]:StackAll
		return TRUE
	}
	member:bool StackHangars()
	{
		if ${Config.DropoffType.Equal[Corporation Hangar]}
		{
			variable index:item cargo
			if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)}
			{
				EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
				return FALSE
			}
			
			if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.DropoffSubType}]:GetItems[cargo](exists)}
			{
			
				EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.DropoffSubType}]:MakeActive
				return FALSE
			}
			EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.DropoffSubType}]:StackAll
		}
		else
		{
			if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID},StationItems]:GetItems[cargo](exists)}
			{
			
				EVEWindow[Inventory].ChildWindow[${Me.Station.ID},StationItems]:MakeActive
				return FALSE
			}
			EVEWindow[Inventory].ChildWindow[${Me.Station.ID},StationItems]:StackAll
		}
		return TRUE
	}

	member:bool PrepHangars()
	{
		variable index:eveinvchildwindow InvWindowChildren
		variable iterator Iter
		EVEWindow[Inventory]:GetChildren[InvWindowChildren]
		InvWindowChildren:GetIterator[Iter]
		if ${Iter:First(exists)}
			do
			{
				if ${Iter.Value.Name.Equal[StationCorpHangars]}
				{
					Iter.Value:MakeActive
				}
			}
			while ${Iter:Next(exists)}		
		return TRUE
	}
	
	member:bool UnloadAmmo()
	{
		if (!${EVEWindow[Inventory](exists)})
		{
			EVE:Execute[OpenInventory]
			return FALSE
		}

		variable index:item cargo
		
		if ${Config.DropoffType.Equal[Corporation Hangar]}
		{
			if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)}
			{
				EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
				return FALSE
			}

			if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.DropoffSubType}]:GetItems[cargo](exists)}
			{
			
				EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.DropoffSubType}]:MakeActive
				return FALSE
			}
		}
		else
		{
			if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID},StationItems]:GetItems[cargo](exists)}
			{
			
				EVEWindow[Inventory].ChildWindow[${Me.Station.ID},StationItems]:MakeActive
				return FALSE
			}
		}

		
		variable iterator c
		variable int toMove
		if !${EVEWindow[Inventory].ChildWindow[${Me.ShipID},ShipCargo]:GetItems[cargo](exists)}
		{
			EVEWindow[Inventory].ChildWindow[${Me.ShipID},ShipCargo]:MakeActive
			return FALSE
		}
		cargo:GetIterator[c]
		if ${c:First(exists)}
			do
			{
				if ${Config.DropoffType.Equal[Corporation Hangar]}
				{			
					variable string folder
					switch ${Config.DropoffSubType}
					{
						case Folder1
							folder:Set[Corporation Folder 1]
							break
						case Folder2
							folder:Set[Corporation Folder 2]
							break
						case Folder3
							folder:Set[Corporation Folder 3]
							break
						case Folder4
							folder:Set[Corporation Folder 4]
							break
						case Folder5
							folder:Set[Corporation Folder 5]
							break
						case Folder6
							folder:Set[Corporation Folder 6]
							break
						case Folder7
							folder:Set[Corporation Folder 7]
							break
					}

					if ${c.Value.Name.Equal[Militants]}
						c.Value:MoveTo[MyStationCorporateHangar,StationCorporateHangar,${c.Value.Quantity},${folder}]
					if ${c.Value.Name.Equal[${Config.KineticAmmo}]} || ${c.Value.Name.Equal[${Config.ThermalAmmo}]} || ${c.Value.Name.Equal[${Config.EMAmmo}]} || ${c.Value.Name.Equal[${Config.ExplosiveAmmo}]}
					{
						c.Value:MoveTo[MyStationCorporateHangar,StationCorporateHangar,${c.Value.Quantity},${folder}]
					}
					if ${Config.Secondary} && (${c.Value.Name.Equal[${Config.KineticAmmoSecondary}]} || ${c.Value.Name.Equal[${Config.ThermalAmmoSecondary}]} || ${c.Value.Name.Equal[${Config.EMAmmoSecondary}]} || ${c.Value.Name.Equal[${Config.ExplosiveAmmoSecondary}]})
					{
						c.Value:MoveTo[MyStationCorporateHangar,StationCorporateHangar,${c.Value.Quantity},${folder}]
					}
				}
				else
				{
					if ${c.Value.Name.Equal[Militants]}
						c.Value:MoveTo[MyStationHangar,Hangar,${c.Value.Quantity}]
					if ${c.Value.Name.Equal[${Config.KineticAmmo}]} || ${c.Value.Name.Equal[${Config.ThermalAmmo}]} || ${c.Value.Name.Equal[${Config.EMAmmo}]} || ${c.Value.Name.Equal[${Config.ExplosiveAmmo}]}
					{
						c.Value:MoveTo[MyStationHangar,Hangar,${c.Value.Quantity}]
					}
					if ${Config.Secondary} && (${c.Value.Name.Equal[${Config.KineticAmmoSecondary}]} || ${c.Value.Name.Equal[${Config.ThermalAmmoSecondary}]} || ${c.Value.Name.Equal[${Config.EMAmmoSecondary}]} || ${c.Value.Name.Equal[${Config.ExplosiveAmmoSecondary}]})
					{
						c.Value:MoveTo[MyStationHangar,Hangar,${c.Value.Quantity}]
					}
				}
			}
			while ${c:Next(exists)}	
		This:InsertState["StackHangars"]
		return TRUE
	}
	
	member:bool LoadAmmo()
	{
		if (!${EVEWindow[Inventory](exists)})
		{
			EVE:Execute[OpenInventory]
			return FALSE
		}

		variable index:item cargo
		variable iterator c
		variable int Scorch = ${Config.Threshold}
		variable int Conflagration = ${Config.Threshold}
		if !${EVEWindow[Inventory].ChildWindow[${Me.ShipID},ShipCargo]:GetItems[cargo](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID},ShipCargo].Capacity} < 0
		{
			EVEWindow[Inventory].ChildWindow[${Me.ShipID},ShipCargo]:MakeActive
			return FALSE
		}

		cargo:GetIterator[c]
		if ${c:First(exists)}
			do
			{
				if ${c.Value.Name.Equal[${ammo}]}
				{
					Scorch:Dec[${c.Value.Quantity}]
				}				
				if ${c.Value.Name.Equal[${secondaryammo}]}
				{
					Conflagration:Dec[${c.Value.Quantity}]
				}				
			}
			while ${c:Next(exists)}			

		if ${Config.Drones}
		{
			if !${EVEWindow[Inventory].ChildWindow[${Me.ShipID},ShipDroneBay]:GetItems[cargo](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID},ShipDroneBay].Capacity} < 0
			{
				EVEWindow[Inventory].ChildWindow[${Me.ShipID},ShipDroneBay]:MakeActive
				return FALSE
			}

			variable float64 dronespace = ${Math.Calc[${EVEWindow[Inventory].ChildWindow[${Me.ShipID},ShipDroneBay].Capacity} - ${EVEWindow[Inventory].ChildWindow[${Me.ShipID},ShipDroneBay].UsedCapacity}]}
		}
		
		if ${Config.DropoffType.Equal[Corporation Hangar]}
		{
			if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)}
			{
				EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
				return FALSE
			}

			if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.DropoffSubType}]:GetItems[cargo](exists)}
			{
			
				EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.DropoffSubType}]:MakeActive
				return FALSE
			}
		}
		else
		{
			if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID},StationItems]:GetItems[cargo](exists)}
			{
			
				EVEWindow[Inventory].ChildWindow[${Me.Station.ID},StationItems]:MakeActive
				return FALSE
			}
		}
		
		
		variable index:int64 loadAmmo
		cargo:GetIterator[c]
		if ${c:First(exists)}
			do
			{
				if ${Config.Drones}
				{
					if ${c.Value.Name.Equal[${Config.DroneType}]} && ${dronespace} >= ${c.Value.Volume}
					{
						c.Value:MoveTo[${MyShip.ID},DroneBay,${Math.Calc[${dronespace}\\${c.Value.Volume}]}]
						return FALSE
					}	
				}
				if ${c.Value.Name.Equal[${secondaryammo}]} && ${c.Value.Quantity} == 1 && ${Conflagration} > 0
				{
					loadAmmo:Insert[${c.Value.ID}]
					Conflagration:Dec
				}
				if ${c.Value.Name.Equal[${ammo}]} && ${c.Value.Quantity} == 1 && ${Scorch} > 0
				{
					loadAmmo:Insert[${c.Value.ID}]
					Scorch:Dec
				}
			}
			while ${c:Next(exists)}	
			
		if ${loadAmmo.Used}
		{
			EVE:MoveItemsTo[loadAmmo, MyShip, CargoHold]
			return FALSE
		}
		
		if ${Config.Threshold} <= 0
			return TRUE
		if ${c:First(exists)}
			do
			{
				if ${c.Value.Name.Equal[${ammo}]} && ${Scorch} > 0
				{
					if ${c.Value.Quantity} >= ${Scorch}
					{
						c.Value:MoveTo[${MyShip.ID},CargoHold,${Scorch}]
						return FALSE
					}
					else
					{
						c.Value:MoveTo[${MyShip.ID},CargoHold,${c.Value.Quantity}]
						return FALSE
					}
				}
				if ${c.Value.Name.Equal[${secondaryammo}]} && ${Conflagration} > 0
				{
					if ${c.Value.Quantity} >= ${Conflagration}
					{
						c.Value:MoveTo[${MyShip.ID},CargoHold,${Conflagration}]
						return FALSE
					}
					else
					{
						c.Value:MoveTo[${MyShip.ID},CargoHold,${Conflagration}]
						return FALSE
					}
				}
			}
			while ${c:Next(exists)}			
			
		if ${Scorch} > 0
		{
			UI:Update["Mission", "You're out of ${ammo}, halting.", "r"]
			This:Clear
			return TRUE
		}
		elseif ${Conflagration} > 0
		{
			UI:Update["Mission", "You're out of ${secondaryammo}, halting.", "r"]
			This:Clear
			return TRUE
		}
		elseif ${Hobgoblin} > 0
		{
			UI:Update["Mission", "You're out of drones, halting.", "r"]
			This:Clear
			return TRUE
		}
		else
		{
			This:InsertState["StackShip"]
			return TRUE
		}
	}
	
	member:bool RefreshBookmarks()
	{
		UI:Update["obj_Mission", "Refreshing bookmarks", "g"]
		EVE:RefreshBookmarks
		return TRUE
	}
	
	member:bool SalvageCheck(bool refreshdone=FALSE)
	{
		variable index:bookmark Bookmarks
		variable iterator BookmarkIterator
		variable int totalBookmarks=0

		EVE:GetBookmarks[Bookmarks]
		Bookmarks:GetIterator[BookmarkIterator]		
		if ${BookmarkIterator:First(exists)}
			do
			{	
				if ${BookmarkIterator.Value.Label.Find[${Config.Agent}]}
				{
					totalBookmarks:Inc
				}
			}
			while ${BookmarkIterator:Next(exists)}		
		
		EVE:RefreshBookmarks
		if ${totalBookmarks} > 15
		{
			UI:Update["obj_Mission", "Salvage running behind, waiting 5 minutes", "g"]
			This:InsertState[RefreshBookmarks, 300000]
		}
		
		return TRUE
	}	
	
	member:bool Traveling()
	{
		if ${Cargo.Processing} || ${Move.Traveling} || ${Me.ToEntity.Mode} == 3
		{
			if ${Me.InSpace} && ${ammo.Length}
			{
				variable index:module modules
				variable iterator m
				MyShip:GetModules[modules]
				modules:GetIterator[m]
				if ${m:First(exists)}
					do
					{
						if !${m.Value.IsActivatable} || ${m.Value.Charge.Type.Equals[${ammo}]} || ${m.Value.IsReloading}
							continue
						if ${m.Value.Charge.Type.Equals[${Config.KineticAmmo}]} || ${m.Value.Charge.Type.Equals[${Config.ThermalAmmo}]} || ${m.Value.Charge.Type.Equals[${Config.EMAmmo}]} || ${m.Value.Charge.Type.Equals[${Config.ExplosiveAmmo}]}
						{
							if (!${EVEWindow[Inventory](exists)})
							{
								EVE:Execute[OpenInventory]
								return FALSE
							}
							
							variable index:item cargo
							variable iterator c
							if !${EVEWindow[Inventory].ChildWindow[${Me.ShipID},ShipCargo]:GetItems[cargo](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID},ShipCargo].Capacity} < -1
							{
								EVEWindow[Inventory].ChildWindow[${Me.ShipID},ShipCargo]:MakeActive
								return FALSE
							}
								
							cargo:GetIterator[c]
							if ${c:First(exists)}
								do
								{
									if ${c.Value.Type.Equal[${ammo}]} 
									{
										m.Value:ChangeAmmo[${c.Value.ID}]
										return FALSE
									}
								}
								while ${c:Next(exists)}
						}
					}
					while ${m:Next(exists)}
				
			}
			
			if ${EVEWindow[byCaption, Agent Conversation](exists)}
			{
				EVEWindow[byCaption, Agent Conversation]:Close
				return FALSE
			}
			if ${EVEWindow[ByCaption, Mission journal](exists)}
			{
				EVEWindow[ByCaption, Mission journal]:Close
				return FALSE
			}
			
			return FALSE
		}
		return TRUE
	}	

	method DeepCopyIndex(string From, string To)
	{
		variable iterator i
		${From}:GetIterator[i]
		if ${i:First(exists)}
		{
			do
			{
				${To}:Insert[${i.Value}]
			}
			while ${i:Next(exists)}
		}
	}
}

	

objectdef obj_MissionUI inherits obj_State
{
	variable index:being Agents

	method Initialize()
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]
	}
	
	method Start()
	{
		if ${This.IsIdle}
		{
			This:QueueState["Update", 5]
		}
	}
	
	method Stop()
	{
		This:Clear
	}


}