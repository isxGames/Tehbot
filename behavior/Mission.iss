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
		This.CommonRef:AddSetting[AmmoAmountToLoad, 100]
		This.CommonRef:AddSetting[DeclineLowSec, TRUE]
		This.CommonRef:AddSetting[SalvagePrefix, "Salvage: "]
	}

	Setting(bool, Halt, SetHalt)
	Setting(bool, UseSecondaryAmmo, SetSecondary)
	Setting(bool, UseDrones, SetDrones)
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
	Setting(int, AmmoAmountToLoad, SetAmmoAmountToLoad)
	Setting(bool, DeclineLowSec, SetDeclineLowSec)
}

objectdef obj_Mission inherits obj_StateQueue
{
	variable int agentIndex = 0
	variable string missionAttackTarget
	variable string ammo
	variable string secondaryAmmo
	variable string missionLootContainer
	variable string missionItemRequired
	variable int useDroneRace = 0

	; If a target can't be killed within 2 minutes, something is going wrong.
	variable int maxAttackTime
	variable int switchTargetAfter = 120

	variable collection:string ValidMissions
	variable collection:string AttackTarget
	variable collection:string LootContainers
	variable collection:string ItemsRequired
	variable collection:float64 CapacityRequired
	variable set InvalidMissions

	variable bool reload = TRUE
	variable bool loadingFallBackDrones
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
		Wrecks:AddQueryString["(GroupID = GROUP_WRECK || GroupID = GROUP_CARGOCONTAINER) && !IsMoribund"]
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
			This:QueueState["Cleanup"]
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
		agentIndex:Set[${EVE.Agent[${Config.Agent}].Index}]

		variable index:agentmission missions
		variable iterator missionIterator

		EVE:GetAgentMissions[missions]
		missions:GetIterator[missionIterator]
		if ${missionIterator:First(exists)}
		{
			do
			{
				if ${missionIterator.Value.AgentID} != ${EVE.Agent[${agentIndex}].ID}
				{
					continue
				}

				if !${EVEWindow[ByCaption, Mission journal - ${This.AgentName[${agentIndex}]}](exists)}
				{
					missionIterator.Value:GetDetails
					return FALSE
				}

				variable string missionJournalText = ${EVEWindow[ByCaption, Mission journal - ${This.AgentName[${agentIndex}]}].HTML.Escape}

				if !${missionJournalText.NotNULLOrEmpty} || ${missionJournalText.Length} < 1000
				{
					missionIterator.Value:GetDetails
					return FALSE
				}

				; offered
				if ${missionIterator.Value.State} == 1
				{
					if ${Config.DeclineLowSec} && ${missionJournalText.Find["low security system"]}
					{
						UI:Update["Mission", "Declining low security mission", "g"]
						UI:Update["Mission", " ${missionIterator.Value.Name}", "o"]
						This:InsertState["Cleanup"]
						This:InsertState["CheckForWork"]
						This:InsertState["InteractAgent", 1500, "DECLINE"]
						return TRUE
					}

					if ${ValidMissions.FirstKey(exists)}
					{
						do
						{
							if ${missionJournalText.Find[${ValidMissions.CurrentKey} Objectives]}
							{
								UI:Update["Mission", "Accepting mission \ao${missionIterator.Value.Name}", "g"]
								This:InsertState["Cleanup"]
								This:InsertState["CheckForWork"]
								This:InsertState["InteractAgent", 1500, "ACCEPT"]
								useDroneRace:Set[0]
								return TRUE
							}
						}
						while ${ValidMissions.NextKey(exists)}
					}

					if ${InvalidMissions.FirstKey(exists)}
					{
						do
						{
							if ${missionJournalText.Find[${InvalidMissions.CurrentKey} Objectives]}
							{
								UI:Update["Mission", "Declining mission \ao${missionIterator.Value.Name}", "g"]
								This:InsertState["Cleanup"]
								This:InsertState["CheckForWork"]
								This:InsertState["InteractAgent", 1500, "DECLINE"]
								return TRUE
							}
						}
						while ${InvalidMissions.NextKey(exists)}
					}

					UI:Update["Mission", "Unknown mission \ao${missionIterator.Value.Name}", "g"]
					if ${Me.StationID} != ${EVE.Agent[${agentIndex}].StationID}
					{
						UI:Update["Mission", "Going to the agent station anyway", "g"]								This:InsertState["Cleanup"]
						This:InsertState["CheckForWork"]
						This:InsertState["InteractAgent", 1500, "OFFER"]
						return TRUE
					}

					This:InsertState["CheckForWork"]
					return TRUE
				}
				; accepted
				elseif ${missionIterator.Value.State} == 2
				{
					if ${ValidMissions.FirstKey(exists)}
					{
						do
						{
							variable string checkmarkIcon = "icon:38_193"
							variable string circlemarkIcon = "icon:38_195"
							if ${missionJournalText.Find[${ValidMissions.CurrentKey} Objectives Complete]} || \
							(${Math.Calc[${missionJournalText.Length} - ${missionJournalText.ReplaceSubstring[${checkmarkIcon}, ""].Length}].Int} >= ${Math.Calc[${checkmarkIcon.Length} * 2].Int} && \
							; No unfinished targets(circle) or the circle appears before the first check which means the ship is not docked at the dropoff station
							(!${missionJournalText.Find[${circlemarkIcon}]} || ${missionJournalText.Find[${circlemarkIcon}]} < ${missionJournalText.Find[${checkmarkIcon}]}))
							{
								UI:Update["Mission", "Mission Complete", "g"]
								UI:Update["Mission", " ${missionIterator.Value.Name}", "o"]
								This:InsertState["Cleanup"]
								This:InsertState["CompleteMission", 1500]
								return TRUE
							}

							if ${missionJournalText.Find[${ValidMissions.CurrentKey} Objectives]}
							{
								UI:Update["Mission", "Ongoing mission identified", "g"]
								UI:Update["Mission", " ${missionIterator.Value.Name}", "o"]

								missionAttackTarget:Set[""]
								if ${AttackTarget.Element[${ValidMissions.CurrentKey}](exists)}
								{
									UI:Update["Mission", "Attack target: \ao${AttackTarget.Element[${ValidMissions.CurrentKey}]}", "g"]
									missionAttackTarget:Set[${AttackTarget.Element[${ValidMissions.CurrentKey}]}]
								}

								missionLootContainer:Set[""]
								if ${LootContainers.Element[${ValidMissions.CurrentKey}](exists)}
								{
									UI:Update["Mission", "Loot container: \ao${LootContainers.Element[${ValidMissions.CurrentKey}]}", "g"]
									missionLootContainer:Set[${LootContainers.Element[${ValidMissions.CurrentKey}]}]
								}

								missionItemRequired:Set[""]
								if ${ItemsRequired.Element[${ValidMissions.CurrentKey}](exists)}
								{
									UI:Update["Mission", "Acquire item: \ao${ItemsRequired.Element[${ValidMissions.CurrentKey}]}", "g"]
									missionItemRequired:Set[${ItemsRequired.Element[${ValidMissions.CurrentKey}]}]
								}

								switch ${ValidMissions.CurrentValue.Lower}
								{
									case kinetic
										ammo:Set[${Config.KineticAmmo}]
										if ${Config.UseSecondaryAmmo}
											secondaryAmmo:Set[${Config.KineticAmmoSecondary}]
										else
											secondaryAmmo:Set[""]
										useDroneRace:Set[DRONE_RACE_CALDARI]
										break
									case em
										ammo:Set[${Config.EMAmmo}]
										if ${Config.UseSecondaryAmmo}
											secondaryAmmo:Set[${Config.EMAmmoSecondary}]
										else
											secondaryAmmo:Set[""]
										useDroneRace:Set[DRONE_RACE_AMARR]
										break
									case thermal
										ammo:Set[${Config.ThermalAmmo}]
										if ${Config.UseSecondaryAmmo}
											secondaryAmmo:Set[${Config.ThermalAmmoSecondary}]
										else
											secondaryAmmo:Set[""]
										useDroneRace:Set[DRONE_RACE_GALLENTE]
										break
									case explosive
										ammo:Set[${Config.ExplosiveAmmo}]
										if ${Config.UseSecondaryAmmo}
											secondaryAmmo:Set[${Config.ExplosiveAmmoSecondary}]
										else
											secondaryAmmo:Set[""]
										useDroneRace:Set[DRONE_RACE_MINMATAR]
										break
									default
										ammo:Set[${Config.KineticAmmo}]
										if ${Config.UseSecondaryAmmo}
											secondaryAmmo:Set[${Config.KineticAmmoSecondary}]
										else
											secondaryAmmo:Set[""]
										break
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
					}

					if ${Me.InStation} && ${reload}
					{
						UI:Update["Mission", "Loading Ammo", "g"]
						UI:Update["Mission", " ${ammo}", "o"]
						if ${Config.UseSecondaryAmmo}
							UI:Update["Mission", " ${secondaryAmmo}", "o"]
						reload:Set[FALSE]
						This:InsertState["CheckForWork"]
						loadingFallBackDrones:Set[FALSE]
						This:InsertState["ReloadAmmoAndDrones"]
						This:InsertState["PrepHangars"]
						return TRUE
					}

					variable index:bookmark missionBookmarks
					variable iterator bookmarkIterator
					missionIterator.Value:GetBookmarks[missionBookmarks]
					missionBookmarks:GetIterator[bookmarkIterator]
					if ${bookmarkIterator:First(exists)}
					{
						do
						{
							if ${bookmarkIterator.Value.LocationType.Equal[dungeon]}
							{
								Move:AgentBookmark[${bookmarkIterator.Value.ID}]
								This:InsertState["PerformMission"]
								This:InsertState["Traveling"]
								This:InsertState["Cleanup"]
								reload:Set[TRUE]
								return TRUE
							}
						}
						while ${bookmarkIterator:Next(exists)}
					}
				}
			}
			while ${missionIterator:Next(exists)}
		}

		UI:Update["Mission", "Requesting mission", "g"]
		This:InsertState["CheckForWork"]
		This:InsertState["InteractAgent", 1500, "OFFER"]
		return TRUE
	}

	method BuildActiveNPC()
	{
		variable iterator classIterator
		variable iterator groupIterator
		variable string groups = ""
		variable string seperator = ""

		ActiveNPC:ClearQueryString

		variable int range = ${Math.Calc[${MyShip.MaxTargetRange} * .95]}

		; Add ongoing jammers.
		variable index:jammer attackers
		variable iterator attackerIterator
		Me:GetJammers[attackers]
		attackers:GetIterator[attackerIterator]
		if ${attackerIterator:First(exists)}
		do
		{
			variable index:string jams
			variable iterator jamsIterator
			attackerIterator.Value:GetJams[jams]
			jams:GetIterator[jamsIterator]
			if ${jamsIterator:First(exists)}
			{
				do
				{
					; Both scramble and disrupt
					if ${jamsIterator.Value.Lower.Find["warp"]}
					{
						groups:Concat[${seperator}ID =- "${attackerIterator.Value.ID}"]
						seperator:Set[" || "]
					}
					elseif ${jamsIterator.Value.Lower.Find["trackingdisrupt"]}
					{
						groups:Concat[${seperator}ID =- "${attackerIterator.Value.ID}"]
						seperator:Set[" || "]
					}
					elseif ${jamsIterator.Value.Lower.Find["electronic"]}
					{
						groups:Concat[${seperator}ID =- "${attackerIterator.Value.ID}"]
						seperator:Set[" || "]
					}
					; Energy drain and neutralizer
					elseif ${jamsIterator.Value.Lower.Find["energy"]}
					{
						groups:Concat[${seperator}ID =- "${attackerIterator.Value.ID}"]
						seperator:Set[" || "]
					}
					elseif ${jamsIterator.Value.Lower.Find["remotesensordamp"]}
					{
						groups:Concat[${seperator}ID =- "${attackerIterator.Value.ID}"]
						seperator:Set[" || "]
					}
					elseif ${jamsIterator.Value.Lower.Find["webify"]}
					{
						groups:Concat[${seperator}ID =- "${attackerIterator.Value.ID}"]
						seperator:Set[" || "]
					}
					elseif ${jamsIterator.Value.Lower.Find["targetpaint"]}
					{
						groups:Concat[${seperator}ID =- "${attackerIterator.Value.ID}"]
						seperator:Set[" || "]
					}
					else
					{
						UI:Update["Mission", "unknown EW ${jamsIterator.Value}", "r"]
					}
				}
				while ${jamsIterator:Next(exists)}
			}
		}
		while ${attackerIterator:Next(exists)}

		ActiveNPC:AddQueryString["IsNPC && !IsMoribund && (${groups})"]
		ActiveNPC:AddQueryString["IsNPC && !IsMoribund && IsWarpScramblingMe"]

		; Add potential jammers.
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

	variable bool looted = FALSE
	variable int64 currentTarget = 0
	variable set blackListedContainers
	variable int64 currentLootContainer
	variable int64 approachTimer
	variable bool notDone = FALSE
	member:bool PerformMission(int nextwaitcomplete = 0)
	{
		variable iterator itemIterator
		This:BuildActiveNPC
		Wrecks:RequestUpdate
		ActiveNPC:RequestUpdate
		NPC:RequestUpdate
		Ship.ModuleList_ActiveResists:Activate
		variable index:bookmark BookmarkIndex

		if ${Me.ToEntity.Mode} == 3
		{
			This:InsertState["PerformMission"]
			return TRUE
		}

		variable index:entity lootContainers
		EVE:QueryEntities[lootContainers, ${missionLootContainer}]

		variable iterator containerIterator
		blackListedContainers:GetIterator[containerIterator]
		if ${containerIterator:First(exists)}
			do
			{
				lootContainers:RemoveByQuery[${LavishScript.CreateQuery[ID = ${containerIterator.Value}]}]
			}
			while ${containerIterator:Next(exists)}
		lootContainers:Collapse

		; Determine movement and perform loot
		if ${missionLootContainer.NotNULLOrEmpty} && ${lootContainers.Used}
		{
			if !${currentLootContainer}
			{
				currentLootContainer:Set[${lootContainers.Get[1].ID}]
			}
			else
			{
				if !${Entity[${currentLootContainer}](exists)} || \
					${Entity[${currentLootContainer}].IsWreckEmpty} || \
					${Entity[${currentLootContainer}].IsWreckViewed} || \
					${Entity[${currentLootContainer}].IsMoribund}
				{
					currentLootContainer:Set[0]
				}
				else
				{
					if ${Entity[${currentLootContainer}].Distance} > 2500
					{
						if ${MyShip.ToEntity.Mode} != 1 || ${LavishScript.RunningTime} > ${approachTimer}
						{
							if ${Ship.ModuleList_Siege.ActiveCount}
							{
								; UI:Update["Mission", "Deactivate siege module due to approaching"]
								Ship.ModuleList_Siege:Deactivate
							}
							Entity[${currentLootContainer}]:Approach[1000]
							This:InsertState["PerformMission"]
							approachTimer:Set[${Math.Calc[${LavishScript.RunningTime} + 10000]}]
							return TRUE
						}
						if ${Ship.ModuleList_TractorBeams.Count} && \
						   (${Entity[${currentLootContainer}].GroupID} == GROUP_WRECK || ${Entity[${currentLootContainer}].GroupID} == GROUP_CARGOCONTAINER)
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
								if ${Ship.ModuleList_TractorBeams.GetActiveOn[${currentLootContainer}]} < 1 && \
								${Entity[${currentLootContainer}].Distance} < ${Ship.ModuleList_TractorBeams.Range} && \
								(${Entity[${currentLootContainer}].GroupID} == GROUP_WRECK || ${Entity[${currentLootContainer}].GroupID} == GROUP_CARGOCONTAINER)
								{
									Ship.ModuleList_TractorBeams:Activate[${currentLootContainer}]
									Ship.ModuleList_TractorBeams:DeactivateNotOn[${currentLootContainer}]
									This:InsertState["PerformMission"]
									return TRUE
								}
							}
						}
						notDone:Set[TRUE]
					}
					elseif !${NPC.TargetList.Used}
					{
						variable index:item items
						if !${EVEWindow[Inventory].ChildWindow[${currentLootContainer}](exists)}
						{
							Entity[${currentLootContainer}]:Open
							This:InsertState["PerformMission"]
							return TRUE
						}
						else
						{
							EVEWindow[Inventory].ChildWindow[${currentLootContainer}]:GetItems[items]
							if ${items.Used}
							{
								items:GetIterator[itemIterator]
								if ${itemIterator:First(exists)}
									do
									{
										if ${itemIterator.Value.Type.Equal[${missionItemRequired}]}
										{
											itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold]
											This:InsertState["CheckForWork"]
											This:InsertState["Idle", 2000]
											notDone:Set[FALSE]
											return TRUE
										}
									}
									while ${itemIterator:Next(exists)}
								blackListedContainers:Add[${currentLootContainer}]
								currentLootContainer:Set[0]
								EVE:Execute[CmdStopShip]
								This:InsertState["PerformMission"]
								notDone:Set[FALSE]
								return TRUE
							}
							else
							{
								blackListedContainers:Add[${currentLootContainer}]
								currentLootContainer:Set[0]
								EVE:Execute[CmdStopShip]
								This:InsertState["PerformMission"]
								notDone:Set[FALSE]
								return TRUE
							}
						}
					}
					else
					{
						notDone:Set[TRUE]
					}
				}
			}
		}
		else
		{
			notDone:Set[FALSE]
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

		variable int MaxTarget = ${MyShip.MaxLockedTargets}
		if ${Me.MaxLockedTargets} < ${MyShip.MaxLockedTargets}
			MaxTarget:Set[${Me.MaxLockedTargets}]
		MaxTarget:Dec[2]

		ActiveNPC.MinLockCount:Set[${MaxTarget}]
		ActiveNPC.AutoLock:Set[TRUE]

		; ActiveNPC:RequestUpdate
		; echo list is ${ActiveNPC.LockedTargetList.Used}
		; finalized target not locked.
		if !${Entity[${currentTarget}]} || ${Entity[${currentTarget}].IsMoribund} || !(${Entity[${currentTarget}].IsLockedTarget} || ${Entity[${currentTarget}].BeingTargeted}) || (${maxAttackTime} > 0 && ${LavishScript.RunningTime} > ${maxAttackTime})
		{
			currentTarget:Set[0]
			maxAttackTime:Set[0]
		}

		variable iterator lockedTargetIterator
		variable iterator activateJammerIterator
		Ship:BuildActivateJammerList

		if ${currentTarget} != 0
		{
			; Finalized decision
			variable bool finalized
			finalized:Set[FALSE]
			if ${Ship.ActivateJammerList.Used}
			{
				if !${Ship.ActivateJammerSet.Contains[${currentTarget}]}
				{
					; Being jammed but the jammer is not the current target
					Ship.ActivateJammerList:GetIterator[activateJammerIterator]
					do
					{
						if ${Entity[${activateJammerIterator.Value}].IsLockedTarget}
						{
							currentTarget:Set[${activateJammerIterator.Value}]
							maxAttackTime:Set[${Math.Calc[${LavishScript.RunningTime} + (${switchTargetAfter} * 1000)]}]
							UI:Update["Mission", "Switching target to activate jammer \ar${Entity[${currentTarget}].Name}", "g"]
							finalized:Set[TRUE]
							break
						}
					}
					while ${activateJammerIterator:Next(exists)}
				}
				else
				{
					finalized:Set[TRUE]
				}
			}

			if !${finalized} && ${Ship.IsHardToDealWithTarget[${currentTarget}]} && ${ActiveNPC.LockedTargetList.Used}
			{
				; Switch to easier target
				ActiveNPC.LockedTargetList:GetIterator[lockedTargetIterator]
				do
				{
					if !${Ship.IsHardToDealWithTarget[${lockedTargetIterator.Value}]} && \
					(${Ship.IsHardToDealWithTarget[${currentTarget}]} || ${Entity[${currentTarget}].Distance} > ${Entity[${lockedTargetIterator.Value}].Distance})
					{
						currentTarget:Set[${lockedTargetIterator.Value}]
						maxAttackTime:Set[${Math.Calc[${LavishScript.RunningTime} + (${switchTargetAfter} * 1000)]}]
						UI:Update["Mission", "Switching to easier target: \ar${Entity[${currentTarget}].Name}", "g"]
					}
				}
				while ${lockedTargetIterator:Next(exists)}
			}
		}
		elseif ${ActiveNPC.LockedTargetList.Used}
		{
			; Need to re-pick from locked target
			if ${Ship.ActivateJammerList.Used}
			{
				Ship.ActivateJammerList:GetIterator[activateJammerIterator]
				do
				{
					if ${Entity[${activateJammerIterator.Value}].IsLockedTarget}
					{
						currentTarget:Set[${activateJammerIterator.Value}]
						maxAttackTime:Set[${Math.Calc[${LavishScript.RunningTime} + (${switchTargetAfter} * 1000)]}]
						UI:Update["Mission", "Targeting activate jammer \ar${Entity[${currentTarget}].Name}", "g"]
						break
					}
				}
				while ${activateJammerIterator:Next(exists)}
			}

			if ${currentTarget} == 0
			{
				; Priortize the closest target which is not hard to deal with to
				; reduce the frequency of switching ammo.
				variable int64 HardToDealWithTarget = 0
				ActiveNPC.LockedTargetList:GetIterator[lockedTargetIterator]
				do
				{
					if ${Ship.IsHardToDealWithTarget[${lockedTargetIterator.Value}]}
					{
						HardToDealWithTarget:Set[${lockedTargetIterator.Value}]
					}
					elseif ${currentTarget} == 0 || ${Entity[${currentTarget}].Distance} > ${Entity[${lockedTargetIterator.Value}].Distance}
					{
						; if ${currentTarget} != 0
						; 	UI:Update["Mission", "there is something closer ${Entity[${lockedTargetIterator.Value}].Name}"]
						currentTarget:Set[${lockedTargetIterator.Value}]
						maxAttackTime:Set[${Math.Calc[${LavishScript.RunningTime} + (${switchTargetAfter} * 1000)]}]
					}
				}
				while ${lockedTargetIterator:Next(exists)}

				if ${currentTarget} == 0
				{
					; UI:Update["Mission", "no easy target"]
					currentTarget:Set[${HardToDealWithTarget}]
					maxAttackTime:Set[${Math.Calc[${LavishScript.RunningTime} + (${switchTargetAfter} * 1000)]}]
				}
			}
			UI:Update["Mission", "Primary target: \ar${Entity[${currentTarget}].Name}", "g"]
		}

		; Nothing locked
		if (${currentTarget} == 0 || ${currentTarget} == ${ActiveNPC.TargetList.Get[1].ID}) && \
		   ${ActiveNPC.TargetList.Get[1].Distance} > ${Math.Calc[${Ship.ModuleList_Weapon.Range} * .95]} && \
		   ${MyShip.ToEntity.Mode} != 1
		{
			if ${Ship.ModuleList_Siege.ActiveCount}
			{
				; UI:Update["Mission", "Deactivate siege module due to no target"]
				Ship.ModuleList_Siege:Deactivate
			}
			UI:Update["Mission", "Approaching distanced target: \ar${ActiveNPC.TargetList.Get[1].Name}", "g"]
			ActiveNPC.TargetList.Get[1]:Approach
			This:InsertState["PerformMission"]
			return TRUE
		}

		if ${currentTarget} != 0 && ${Entity[${currentTarget}]} && !${Entity[${currentTarget}].IsMoribund}
		{
			Ship.ModuleList_Siege:Activate
			if ${Ship.ModuleList_Weapon.Range} > ${Entity[${currentTarget}].Distance} || !${Config.RangeLimit}
			{
				Ship.ModuleList_Weapon:ActivateAll[${currentTarget}]
				Ship.ModuleList_Weapon:DeactivateNotOn[${currentTarget}]
				if ${AutoModule.Config.TrackingComputers}
				{
					Ship.ModuleList_TrackingComputer:ActivateAll[${currentTarget}]
				}
			}
			if ${Entity[${currentTarget}].Distance} <= ${Ship.ModuleList_TargetPainter.Range}
			{
				Ship.ModuleList_TargetPainter:Activate[${currentTarget}]
				Ship.ModuleList_TargetPainter:DeactivateNotOn[${currentTarget}]
			}
			; 'Effectiveness Falloff' is not read by ISXEVE, but 20km is a generally reasonable range to activate the module
			if ${Entity[${currentTarget}].Distance} <= ${Math.Calc[${Ship.ModuleList_StasisGrap.Range} + 20000]} 
			{
				Ship.ModuleList_StasisGrap:Activate[${currentTarget}]
				Ship.ModuleList_StasisGrap:DeactivateNotOn[${currentTarget}]
			}
			if ${Entity[${currentTarget}].Distance} <= ${Ship.ModuleList_StasisWeb.Range}
			{
				Ship.ModuleList_StasisWeb:Activate[${currentTarget}]
				Ship.ModuleList_StasisWeb:DeactivateNotOn[${currentTarget}]
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
			if ${NPC.TargetList.Get[1].Distance} > ${Math.Calc[${Ship.ModuleList_Weapon.Range} * .95]} && ${MyShip.ToEntity.Mode} != 1
			{
				if ${Ship.ModuleList_Siege.ActiveCount}
				{
					; UI:Update["Mission", "Deactivate siege module due to approaching"]
					Ship.ModuleList_Siege:Deactivate
				}
				NPC.TargetList.Get[1]:Approach
			}

			if ${currentTarget} == 0 || ${Entity[${currentTarget}].IsMoribund} || !${Entity[${currentTarget}]}
			{
				if ${NPC.LockedTargetList.Used}
					currentTarget:Set[${NPC.LockedTargetList.Get[1]}]
				else
					currentTarget:Set[0]
			}
			This:InsertState["PerformMission"]
			return TRUE
		}

		DroneControl:Recall

		if ${Entity[${missionAttackTarget}]}
		{
			if ${Entity[${missionAttackTarget}].Distance} > ${Math.Calc[${Ship.ModuleList_Weapon.Range} * .95]} && ${MyShip.ToEntity.Mode} != 1
			{
				if ${Ship.ModuleList_Siege.ActiveCount}
				{
					; UI:Update["Mission", "Deactivate siege module due to approaching"]
					Ship.ModuleList_Siege:Deactivate
				}
				Entity[${missionAttackTarget}]:Approach
			}
			if !${Entity[${missionAttackTarget}].IsLockedTarget} && !${Entity[${missionAttackTarget}].BeingTargeted}
			{
				UI:Update["Mission", "Locking Mission Target", "g"]
				UI:Update["Mission", " ${Entity[${missionAttackTarget}].Name}", "o"]
				Entity[${missionAttackTarget}]:LockTarget
			}
			elseif ${Entity[${missionAttackTarget}].IsLockedTarget}
			{
				Ship.ModuleList_Weapon:ActivateAll[${Entity[${missionAttackTarget}].ID}]
				if ${AutoModule.Config.TrackingComputers}
				{
					Ship.ModuleList_TrackingComputer:ActivateAll[${currentTarget}]
				}
			}
			This:InsertState["PerformMission"]
			return TRUE
		}

		if ${notDone} || ${Busy.IsBusy}
		{
			This:InsertState["PerformMission"]
			return TRUE
		}

		; Check mission complete for World Collide and Extravaganza before activating an extra gate
		variable index:agentmission missions
		variable iterator missionIterator
		EVE:GetAgentMissions[missions]
		missions:GetIterator[missionIterator]

		if ${missionIterator:First(exists)}
		{
			do
			{
				if ${missionIterator.Value.AgentID} != ${EVE.Agent[${agentIndex}].ID}
				{
					continue
				}

				if !${EVEWindow[ByCaption, Mission journal - ${This.AgentName[${agentIndex}]}](exists)}
				{
					missionIterator.Value:GetDetails
					return FALSE
				}

				variable string missionJournalText = ${EVEWindow[ByCaption, Mission journal - ${This.AgentName[${agentIndex}]}].HTML.Escape}
				if !${missionJournalText.NotNULLOrEmpty} || ${missionJournalText.Length} < 1000
				{
					missionIterator.Value:GetDetails
					return FALSE
				}

				; accepted
				if ${missionIterator.Value.State} == 2
				{
					if ${ValidMissions.FirstKey(exists)}
					{
						do
						{
							variable string checkmarkIcon = "icon:38_193"
							variable string circlemarkIcon = "icon:38_195"
							if ${missionJournalText.Find[${ValidMissions.CurrentKey} Objectives Complete]} || \
							(${Math.Calc[${missionJournalText.Length} - ${missionJournalText.ReplaceSubstring[${checkmarkIcon}, ""].Length}].Int} >= ${Math.Calc[${checkmarkIcon.Length} * 2].Int} && \
							; No unfinished targets(circle) or the circle appears before the first check which means the ship is not docked at the dropoff station
							(!${missionJournalText.Find[${circlemarkIcon}]} || ${missionJournalText.Find[${circlemarkIcon}]} < ${missionJournalText.Find[${checkmarkIcon}]}))
							{
								UI:Update["Mission", "Mission Complete", "g"]
								UI:Update["Mission", " ${missionIterator.Value.Name}", "o"]
								This:InsertState["Cleanup"]
								This:InsertState["CompleteMission", 1500]
								return TRUE
							}
						}
						while ${ValidMissions.NextKey(exists)}
					}
				}
			}
			while ${missionIterator:Next(exists)}
		}

		if ${Entity[Type = "Acceleration Gate"]} && !${EVEWindow[byName, modal].Text.Find[This gate is locked!]}
		{
			if ${Ship.ModuleList_Siege.ActiveCount}
			{
				; UI:Update["Mission", "Deactivate siege module due to approaching"]
				Ship.ModuleList_Siege:Deactivate
			}

			if ${Wrecks.TargetList.Used} && ${Config.SalvagePrefix.NotNULLOrEmpty}
			{
				EVE:GetBookmarks[BookmarkIndex]
				BookmarkIndex:RemoveByQuery[${LavishScript.CreateQuery[SolarSystemID == ${Me.SolarSystemID}]}, FALSE]
				BookmarkIndex:RemoveByQuery[${LavishScript.CreateQuery[Distance < 200000]}, FALSE]
				BookmarkIndex:Collapse

				if !${BookmarkIndex.Used}
					Wrecks.TargetList.Get[1]:CreateBookmark["${Config.SalvagePrefix} ${Config.Agent} ${Me.Name} ${EVETime.Time.Left[5]}", "", "Corporation Locations", 1]
			}

			currentTarget:Set[0]
			Move:Gate[${Entity[Type = "Acceleration Gate"]}]
			; Blitz cargo delivery and recon 1 of 3
			This:InsertState["CheckForWork"]
			This:InsertState["Idle", 2000]
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

		currentTarget:Set[0]
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
			DroneControl:Recall
			if ${Ship.ModuleList_Siege.ActiveCount}
			{
				; UI:Update["Mission", "Deactivate siege module due to mission complete"]
				Ship.ModuleList_Siege:Deactivate
			}
		}

		if ${Me.StationID} != ${EVE.Agent[${agentIndex}].StationID}
		{
			UI:Update["Mission", "Need to be at agent station to complete mission", "g"]
			UI:Update["Mission", "Setting course for \ao${EVE.Station[${EVE.Agent[${agentIndex}].StationID}].Name}", "g"]
			Move:Agent[${agentIndex}]
			This:InsertState["CompleteMission", 1500]
			This:InsertState["Traveling"]
			return TRUE
		}

		if !${EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}](exists)}
		{
			EVE.Agent[${agentIndex}]:StartConversation
			return FALSE
		}

		if ${EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["View Mission"](exists)}
		{
			EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["View Mission"]:Press
			return FALSE
		}

		if ${EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["Complete Mission"](exists)}
		{
			EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["Complete Mission"]:Press
			relay "all" -event Tehbot_SalvageBookmark ${Me.ID}
		}

		variable index:agentmission missions
		variable iterator missionIterator

		EVE:GetAgentMissions[missions]
		missions:GetIterator[missionIterator]
		if ${missionIterator:First(exists)}
			do
			{
				if ${missionIterator.Value.AgentID} == ${EVE.Agent[${agentIndex}].ID} && ${missionIterator.Value.State} == 2
					return FALSE
			}
			while ${missionIterator:Next(exists)}

		if !${Config.Halt} && !${halt}
		{
			This:InsertState["CheckForWork"]
			This:InsertState["InteractAgent", 1500, "OFFER"]
			This:InsertState["SalvageCheck"]
			This:InsertState["RefreshBookmarks"]
		}
		else
		{
			UIElement[Run@TitleBar@Tehbot]:SetText[Run]
		}
		halt:Set[FALSE]
		This:InsertState["UnloadLoots"]
		This:InsertState["Cleanup"]
		return TRUE
	}

	member:bool InteractAgent(string Action)
	{
		if ${Me.StationID} != ${EVE.Agent[${agentIndex}].StationID}
		{
			Move:Bookmark[${EVE.Agent[${agentIndex}].StationID}]
			This:InsertState["InteractAgent", 1500, ${Action}]
			This:InsertState["Traveling"]
			return TRUE
		}

		if !${EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}](exists)}
		{
			EVE.Agent[${agentIndex}]:StartConversation
			return FALSE
		}

		switch ${Action}
		{
			case OFFER
				if ${EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["View Mission"](exists)}
				{
					EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["View Mission"]:Press
					return TRUE
				}
				if ${EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["Request Mission"](exists)}
				{
					EVEWindow[agentinteraction_${EVE.Agent[${agentIndex}].ID}].Button["Request Mission"]:Press
					return TRUE
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
					return TRUE
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
					variable time NextTime = ${Time.Timestamp}
					NextTime.Hour:Inc[4]
					NextTime:Update
					Config:Save
					return TRUE
				}
				break
		}
		return TRUE
	}

	member:bool StackShip()
	{
		EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo]:StackAll
		return TRUE
	}

	member:bool StackHangars()
	{
		if ${Config.DropoffType.Equal[Corporation Hangar]}
		{
			if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)}
			{
				EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
				return FALSE
			}

			if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.DropoffSubType}](exists)}
			{
				EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.DropoffSubType}]:MakeActive
				return FALSE
			}

			EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.DropoffSubType}]:StackAll
		}
		else
		{
			if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
			{

				EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
				return FALSE
			}
			EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:StackAll
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

	member:string CorporationFolder()
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

		return ${folder}
	}

	member:bool UnloadLoots()
	{
		if (!${EVEWindow[Inventory](exists)})
		{
			EVE:Execute[OpenInventory]
			return FALSE
		}

		if !${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo](exists)}
		{
			EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo]:MakeActive
			return FALSE
		}

		variable index:item items
		variable iterator itemIterator
		EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo]:GetItems[items]
		items:GetIterator[itemIterator]
		if ${itemIterator:First(exists)}
		{
			do
			{
				if !${itemIterator.Value.Name.Equal[${Config.KineticAmmo}]} && \
				   !${itemIterator.Value.Name.Equal[${Config.ThermalAmmo}]} && \
				   !${itemIterator.Value.Name.Equal[${Config.EMAmmo}]} && \
				   !${itemIterator.Value.Name.Equal[${Config.ExplosiveAmmo}]} && \
				   !${itemIterator.Value.Name.Equal[${Config.KineticAmmoSecondary}]} && \
				   !${itemIterator.Value.Name.Equal[${Config.ThermalAmmoSecondary}]} && \
				   !${itemIterator.Value.Name.Equal[${Config.EMAmmoSecondary}]} && \
				   !${itemIterator.Value.Name.Equal[${Config.ExplosiveAmmoSecondary}]} && \
				   !${itemIterator.Value.Name.Equal[${Ship.FallbackAmmo}]} && \
				   !${itemIterator.Value.Name.Equal[${Ship.FallbackSecondaryAmmo}]} && \
				   ; Anomaly gate key
				   !${itemIterator.Value.Name.Equal["Oura Madusaari"]} && \
				   !${itemIterator.Value.Group.Equal["Acceleration Gate Keys"]} && \
				   !${itemIterator.Value.Name.Find["Script"]} && \
				   ; Insignias for Extravaganza missions
				   !${itemIterator.Value.Name.Find["Diamond"]}
				{
					if ${Config.DropoffType.Equal[Corporation Hangar]}
					{
						if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)}
						{
							EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
							return FALSE
						}

						if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.DropoffSubType}](exists)}
						{

							EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.DropoffSubType}]:MakeActive
							return FALSE
						}

						itemIterator.Value:MoveTo[MyStationCorporateHangar, StationCorporateHangar, ${itemIterator.Value.Quantity}, ${This.CorporationFolder}]
						; return FALSE
					}
					else
					{
						if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
						{
							EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
							return FALSE
						}
						itemIterator.Value:MoveTo[MyStationHangar, Hangar, ${itemIterator.Value.Quantity}]
						; return FALSE
					}
				}
			}
			while ${itemIterator:Next(exists)}
		}

		This:InsertState["StackHangars"]
		return TRUE
	}

	member:bool ReloadAmmoAndDrones()
	{
		if ${Config.AmmoAmountToLoad} <= 0
			return TRUE

		variable index:item items
		variable iterator itemIterator
		variable int defaultAmmoAmountToLoad = ${Config.AmmoAmountToLoad}
		variable int secondaryAmmoAmountToLoad = ${Config.AmmoAmountToLoad}
		variable int droneAmountToLoad = -1
		variable int loadingDroneNumber = 0
		variable string preferredDroneType
		variable string fallbackDroneType

		if (!${EVEWindow[Inventory](exists)})
		{
			EVE:Execute[OpenInventory]
			return FALSE
		}

		if ${Config.UseDrones}
		{
			if (!${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].Capacity} < 0)
			{
				EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay]:MakeActive
				return FALSE
			}

			variable float specifiedDroneVolume = ${Drones.Data.GetVolume[${Config.DroneType}]}
			preferredDroneType:Set[${Drones.Data.SearchSimilarDroneFromRace[${Config.DroneType}, ${useDroneRace}]}]
			if !${preferredDroneType.Equal[${Config.DroneType}]}
			{
				fallbackDroneType:Set[${Config.DroneType}]
			}

			EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay]:GetItems[items]
			items:GetIterator[itemIterator]
			if ${itemIterator:First(exists)}
			{
				do
				{
					if ${Config.DropoffType.Equal[Corporation Hangar]}
					{
						if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)}
						{
							EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
							return FALSE
						}

						if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.DropoffSubType}](exists)}
						{

							EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.DropoffSubType}]:MakeActive
							return FALSE
						}

						if !${itemIterator.Value.Name.Equal[${preferredDroneType}]}
						{
							itemIterator.Value:MoveTo[MyStationCorporateHangar, StationCorporateHangar, ${itemIterator.Value.Quantity}, ${This.CorporationFolder}]
							return FALSE
						}
					}
					else
					{
						if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
						{
							EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
							return FALSE
						}
						if !${itemIterator.Value.Name.Equal[${preferredDroneType}]} && \
							(!${itemIterator.Value.Name.Equal[${fallbackDroneType}]} || !${loadingFallBackDrones})
						{
							itemIterator.Value:MoveTo[MyStationHangar, Hangar, ${itemIterator.Value.Quantity}]
							return FALSE
						}
					}

				}
				while ${itemIterator:Next(exists)}
			}

			variable float remainingDroneSpace = ${Math.Calc[${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].Capacity} - ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].UsedCapacity}]}

			if ${specifiedDroneVolume} > 0
			{
				droneAmountToLoad:Set[${Math.Calc[${remainingDroneSpace} / ${specifiedDroneVolume}].Int}]
			}
		}

		if !${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo].Capacity} < 0
		{
			EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo]:MakeActive
			return FALSE
		}

		EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo]:GetItems[items]
		items:GetIterator[itemIterator]
		if ${itemIterator:First(exists)}
		{
			do
			{
				if ${itemIterator.Value.Name.Equal[${ammo}]}
				{
					defaultAmmoAmountToLoad:Dec[${itemIterator.Value.Quantity}]
					continue
				}

				if ${itemIterator.Value.Name.Equal[${secondaryAmmo}]}
				{
					secondaryAmmoAmountToLoad:Dec[${itemIterator.Value.Quantity}]
					continue
				}

				if ${droneAmountToLoad} > 0 && ${itemIterator.Value.Name.Equal[${preferredDroneType}]}
				{
					if (!${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].Capacity} < 0)
					{
						EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay]:MakeActive
						return FALSE
					}

					if ${itemIterator.Value.Name.Equal[${preferredDroneType}]}
					{
						loadingDroneNumber:Set[${droneAmountToLoad}]
						if ${itemIterator.Value.Quantity} < ${droneAmountToLoad}
						{
							loadingDroneNumber:Set[${itemIterator.Value.Quantity}]
						}
						UI:Update["Mission", "Loading ${loadingDroneNumber} \ao${preferredDroneType}\aws."]
						itemIterator.Value:MoveTo[${MyShip.ID}, DroneBay, ${loadingDroneNumber}]
						droneAmountToLoad:Dec[${loadingDroneNumber}]
						return FALSE
					}
					continue
				}

				; Move fallback drones together(to station hanger) before moving them to drone bay to ensure preferred type is loaded before fallback type.
				if ${itemIterator.Value.Name.Equal[${fallbackDroneType}]}
				{
					if ${Config.DropoffType.Equal[Corporation Hangar]}
					{
						if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)}
						{
							EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
							return FALSE
						}

						if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.DropoffSubType}](exists)}
						{

							EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.DropoffSubType}]:MakeActive
							return FALSE
						}

						itemIterator.Value:MoveTo[MyStationCorporateHangar, StationCorporateHangar, ${itemIterator.Value.Quantity}, ${This.CorporationFolder}]
						return FALSE
					}
					else
					{
						if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
						{
							EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
							return FALSE
						}

						itemIterator.Value:MoveTo[MyStationHangar, Hangar, ${itemIterator.Value.Quantity}]
						return FALSE
					}
					continue
				}
			}
			while ${itemIterator:Next(exists)}
		}

		if ${Config.DropoffType.Equal[Corporation Hangar]}
		{
			if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)}
			{
				EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
				return FALSE
			}

			if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.DropoffSubType}](exists)}
			{
				EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.DropoffSubType}]:MakeActive
				return FALSE
			}

			EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.DropoffSubType}]:GetItems[items]
		}
		else
		{
			if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
			{
				EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
				return FALSE
			}

			EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:GetItems[items]
		}

		; Load ammos
		items:GetIterator[itemIterator]
		if ${itemIterator:First(exists)}
		{
			do
			{
				if ${defaultAmmoAmountToLoad} > 0 && ${itemIterator.Value.Name.Equal[${ammo}]}
				{
					if ${itemIterator.Value.Quantity} >= ${defaultAmmoAmountToLoad}
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${defaultAmmoAmountToLoad}]
						defaultAmmoAmountToLoad:Set[0]
						return FALSE
					}
					else
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${itemIterator.Value.Quantity}]
						defaultAmmoAmountToLoad:Dec[${itemIterator.Value.Quantity}]
						return FALSE
					}
				}

				if ${secondaryAmmoAmountToLoad} > 0 && ${itemIterator.Value.Name.Equal[${secondaryAmmo}]}
				{
					if ${itemIterator.Value.Quantity} >= ${secondaryAmmoAmountToLoad}
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${secondaryAmmoAmountToLoad}]
						secondaryAmmoAmountToLoad:Set[0]
						return FALSE
					}
					else
					{
						itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${itemIterator.Value.Quantity}]
						secondaryAmmoAmountToLoad:Dec[${itemIterator.Value.Quantity}]
						return FALSE
					}
				}
			}
			while ${itemIterator:Next(exists)}
		}

		if (!${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay].Capacity} < 0)
		{
			EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipDroneBay]:MakeActive
			return FALSE
		}

		; Load preferred type of drones
		items:GetIterator[itemIterator]
		if ${droneAmountToLoad} > 0 && ${itemIterator:First(exists)}
		{
			do
			{
				if ${droneAmountToLoad} > 0 && ${itemIterator.Value.Name.Equal[${preferredDroneType}]}
				{
					loadingDroneNumber:Set[${droneAmountToLoad}]
					if ${itemIterator.Value.Quantity} < ${droneAmountToLoad}
					{
						loadingDroneNumber:Set[${itemIterator.Value.Quantity}]
					}
					UI:Update["Mission", "Loading ${loadingDroneNumber} \ao${preferredDroneType}\aws."]
					itemIterator.Value:MoveTo[${MyShip.ID}, DroneBay, ${loadingDroneNumber}]
					droneAmountToLoad:Dec[${loadingDroneNumber}]
					return FALSE
				}
			}
			while ${itemIterator:Next(exists)}
		}

		; Out of preferred type of drones, load fallback(configured) type
		if ${droneAmountToLoad} > 0 && ${fallbackDroneType.NotNULLOrEmpty}
		{
			loadingFallBackDrones:Set[TRUE]
			items:GetIterator[itemIterator]
			if ${itemIterator:First(exists)}
			{
				do
				{
					if ${droneAmountToLoad} > 0 && ${itemIterator.Value.Name.Equal[${fallbackDroneType}]}
					{
						loadingDroneNumber:Set[${droneAmountToLoad}]
						if ${itemIterator.Value.Quantity} < ${droneAmountToLoad}
						{
							loadingDroneNumber:Set[${itemIterator.Value.Quantity}]
						}
						UI:Update["Mission", "Loading ${loadingDroneNumber} \ao${fallbackDroneType}\aws for having no \ao${preferredDroneType}\aw."]
						itemIterator.Value:MoveTo[${MyShip.ID}, DroneBay, ${loadingDroneNumber}]
						droneAmountToLoad:Dec[${loadingDroneNumber}]
						return FALSE
					}
				}
				while ${itemIterator:Next(exists)}
			}
		}

		if ${defaultAmmoAmountToLoad} > 0
		{
			UI:Update["Mission", "You're out of ${ammo}, halting.", "r"]
			This:Clear
			return TRUE
		}
		elseif ${Config.UseSecondaryAmmo} && ${secondaryAmmoAmountToLoad} > 0
		{
			UI:Update["Mission", "You're out of ${secondaryAmmo}, halting.", "r"]
			This:Clear
			return TRUE
		}
		elseif ${Config.UseDrones} && ${droneAmountToLoad} > 0
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

	member:bool SalvageCheck(bool refreshdone = FALSE)
	{
		variable index:bookmark Bookmarks
		variable iterator BookmarkIterator
		variable int totalBookmarks = 0

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
			This:InsertState["RefreshBookmarks", 300000]
		}

		return TRUE
	}

	member:bool Traveling()
	{
		if ${Cargo.Processing} || ${Move.Traveling} || ${Me.ToEntity.Mode} == 3
		{
			if ${Me.InSpace}
			{
				if ${Ship.ModuleList_Regen_Shield.InactiveCount} && ((${MyShip.ShieldPct} < 100 && ${MyShip.CapacitorPct} > ${AutoModule.Config.ActiveShieldCap}) || ${AutoModule.Config.ShieldBoost})
				{
					Ship.ModuleList_Regen_Shield:ActivateCount[${Ship.ModuleList_Regen_Shield.InactiveCount}]
				}
				if ${Ship.ModuleList_Regen_Shield.ActiveCount} && (${MyShip.ShieldPct} == 100 || ${MyShip.CapacitorPct} < ${AutoModule.Config.ActiveShieldCap}) && !${AutoModule.Config.ShieldBoost}
				{
					Ship.ModuleList_Regen_Shield:DeactivateCount[${Ship.ModuleList_Regen_Shield.ActiveCount}]
				}
				if ${Ship.ModuleList_Repair_Armor.InactiveCount} && ((${MyShip.ArmorPct} < 100 && ${MyShip.CapacitorPct} > ${AutoModule.Config.ActiveArmorCap}) || ${AutoModule.Config.ArmorRepair}) && ${LavishScript.RunningTime} > ${lastArmorRepActivate}
				{
					Ship.ModuleList_Repair_Armor:ActivateCount[1]
					lastArmorRepActivate:Set[${Math.Calc[${LavishScript.RunningTime} + 3000]}]
				}
				if ${Ship.ModuleList_Repair_Armor.ActiveCount} && (${MyShip.ArmorPct} == 100 || ${MyShip.CapacitorPct} < ${AutoModule.Config.ActiveArmorCap}) && !${AutoModule.Config.ArmorRepair}
				{
					Ship.ModuleList_Repair_Armor:DeactivateCount[${Ship.ModuleList_Repair_Armor.ActiveCount}]
				}

				if ${ammo.Length}
				{
					variable index:module modules
					variable iterator moduleIterator
					MyShip:GetModules[modules]
					modules:GetIterator[moduleIterator]
					if ${moduleIterator:First(exists)}
						do
						{
							if !${Ship.ModuleList_Weapon:IncludeModule[${moduleIterator.Value.ID}]} || ${moduleIterator.Value.Charge.Type.Equal[${ammo}]} || ${moduleIterator.Value.IsReloading}
							{
								continue
							}

							if ${moduleIterator.Value.Charge.Type.Equal[${Config.KineticAmmo}]} || ${moduleIterator.Value.Charge.Type.Equal[${Config.ThermalAmmo}]} || ${moduleIterator.Value.Charge.Type.Equal[${Config.EMAmmo}]} || ${moduleIterator.Value.Charge.Type.Equal[${Config.ExplosiveAmmo}]}
							{
								if (!${EVEWindow[Inventory](exists)})
								{
									EVE:Execute[OpenInventory]
									return FALSE
								}

								variable index:item items
								variable iterator itemIterator
								if !${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo].Capacity} < -1
								{
									EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo]:MakeActive
									return FALSE
								}

								EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo]:GetItems[items]

								items:GetIterator[itemIterator]
								if ${itemIterator:First(exists)}
									do
									{
										if ${itemIterator.Value.Type.Equal[${ammo}]}
										{
											moduleIterator.Value:ChangeAmmo[${itemIterator.Value.ID}]
											return FALSE
										}
									}
									while ${itemIterator:Next(exists)}
							}
						}
						while ${moduleIterator:Next(exists)}
				}
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