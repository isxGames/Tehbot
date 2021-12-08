objectdef obj_Configuration_Agents
{
	variable string SetName = "Agents"

	method Initialize()
	{
		if !${BaseConfig.BaseRef.FindSet[${This.SetName}](exists)}
		{
			Logger:Log["Warning: ${This.SetName} settings missing - initializing"]
			This:Set_Default_Values
		}
		Logger:Log["Configuration", " ${This.SetName}: Initialized", "-g"]
	}

	member:settingsetref AgentsRef()
	{
		return ${BaseConfig.BaseRef.FindSet[${This.SetName}]}
	}

	member:settingsetref AgentRef(string name)
	{
		return ${This.AgentsRef.FindSet[${name}]}
	}

	method Set_Default_Values()
	{
		BaseConfig.BaseRef:AddSet[${This.SetName}]
		This.AgentsRef:AddSet["Fykalia Adaferid"]
		This.AgentRef["Fykalia Adaferid"]:AddSetting[AgentIndex, 9591]
		This.AgentRef["Fykalia Adaferid"]:AddSetting[AgentID, 3018920]
		This.AgentRef["Fykalia Adaferid"]:AddSetting[NextDeclineableTime, ${Utility.EVETimestamp}]
	}

	member:int AgentIndex(string name)
	{
		;Logger:Log["obj_Configuration_Agents: AgentIndex ${name}"]
		return ${This.AgentRef[${name}].FindSetting[AgentIndex, 9591]}
	}

	method SetAgentIndex(string name, int value)
	{
		;Logger:Log["obj_Configuration_Agents: SetAgentIndex ${name} ${value}"]
		if !${This.AgentsRef.FindSet[${name}](exists)}
		{
			This.AgentsRef:AddSet[${name}]
		}

		This.AgentRef[${name}]:AddSetting[AgentIndex, ${value}]
	}

	member:int AgentID(string name)
	{
		;Logger:Log["obj_Configuration_Agents: AgentID ${name}"]
		return ${This.AgentRef[${name}].FindSetting[AgentID, 3018920]}
	}

	method SetAgentID(string name, int value)
	{
		;Logger:Log["obj_Configuration_Agents: SetAgentID ${name} ${value}"]
		if !${This.AgentsRef.FindSet[${name}](exists)}
		{
			This.AgentsRef:AddSet[${name}]
		}

		This.AgentRef[${name}]:AddSetting[AgentID, ${value}]
	}

	member:int NextDeclineableTime(string name)
	{
		; Logger:Log["obj_Configuration_Agents", "NextDeclineableTime ${name} ${This.AgentRef[${name}].FindSetting[NextDeclineableTime, 0]}", "", LOG_DEBUG]
		return ${This.AgentRef[${name}].FindSetting[NextDeclineableTime, 0]}
	}

	member:int SecondsTillDeclineable(string name)
	{
		; Logger:Log["obj_Configuration_Agents", "SecondsTillDeclineable ${name}", "", LOG_DEBUG]
		if ${This.NextDeclineableTime[${name}]} < ${Utility.EVETimestamp}
		{
			return 0
		}
		return ${Math.Calc[${This.NextDeclineableTime[${name}]} - ${Utility.EVETimestamp}]}
	}

	member:bool CanDeclineMission(string name)
	{
		; Logger:Log["obj_Configuration_Agents", "CanDeclineMission ${name}", "", LOG_DEBUG]
		if ${This.NextDeclineableTime[${name}]} < ${Utility.EVETimestamp}
		{
			return TRUE
		}
		return FALSE
	}

	method SetNextDeclineableTime(string name, int value)
	{
		; Logger:Log["obj_Configuration_Agents", "SetNextDeclineableTime ${name} ${value}", "", LOG_DEBUG]
		if !${This.AgentsRef.FindSet[${name}](exists)}
		{
			This.AgentsRef:AddSet[${name}]
		}

		This.AgentRef[${name}]:AddSetting[NextDeclineableTime, ${value}]
	}
}

objectdef obj_Configuration_Mission
{
	variable string SetName = "Mission"

	method Initialize()
	{
		if !${BaseConfig.BaseRef.FindSet[${This.SetName}](exists)}
		{
			Logger:Log["Configuration", " ${This.SetName} settings missing - initializing", "o"]
			This:Set_Default_Values
		}
		Logger:Log["Configuration", " ${This.SetName}: Initialized", "-g"]
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
		This.CommonRef:AddSetting[AggressiveMode, FALSE]
		This.CommonRef:AddSetting[IgnoreNPCSentries, FALSE]
		This.CommonRef:AddSetting[DeactivateSiegeModuleEarly, FALSE]
		This.CommonRef:AddSetting[SalvagePrefix, "Salvage: "]
		This.CommonRef:AddSetting[LogLevelBar, LOG_INFO]
	}

	Setting(bool, Halt, SetHalt)
	Setting(bool, UseSecondaryAmmo, SetSecondary)
	Setting(bool, UseDrones, SetDrones)
	Setting(bool, RangeLimit, SetRangeLimit)
	Setting(bool, DeclineLowSec, SetDeclineLowSec)
	Setting(bool, DropOffToContainer, SetDropOffToContainer)
	Setting(bool, AggressiveMode, SetAggressiveMode)
	Setting(bool, IgnoreNPCSentries, SetIgnoreNPCSentries)
	Setting(bool, DeactivateSiegeModuleEarly, SetDeactivateSiegeModuleEarly)
	Setting(string, SalvagePrefix, SetSalvagePrefix)
	Setting(string, DropOffContainerName, SetDropOffContainerName)
	Setting(string, MunitionStorage, SetMunitionStorage)
	Setting(string, MunitionStorageFolder, SetMunitionStorageFolder)
	Setting(string, DroneType, SetDroneType)
	Setting(string, MissionFile, SetMissionFile)
	Setting(string, KineticAmmo, SetKineticAmmo)
	Setting(string, ThermalAmmo, SetThermalAmmo)
	Setting(string, EMAmmo, SetEMAmmo)
	Setting(string, ExplosiveAmmo, SetExplosiveAmmo)
	Setting(string, KineticAmmoSecondary, SetKineticAmmoSecondary)
	Setting(string, ThermalAmmoSecondary, SetThermalAmmoSecondary)
	Setting(string, EMAmmoSecondary, SetEMAmmoSecondary)
	Setting(string, ExplosiveAmmoSecondary, SetExplosiveAmmoSecondary)
	Setting(int, AmmoAmountToLoad, SetAmmoAmountToLoad)
	Setting(int, LogLevelBar, SetLogLevelBar)
}

objectdef obj_Mission inherits obj_StateQueue
{
	;;;;;;;;;; Mission database.
	variable set BlackListedMissions
	variable collection:string DamageType
	variable collection:string TargetToDestroy
	variable collection:string ContainerToLoot
	variable collection:float64 CapacityRequired
	; (Optional) Bring key to mission when available
	variable collection:string GateKey
	; Look for mission key in cargo if didn't bring
	variable collection:string GateKeyContainer
	; To be deprecated.
	variable collection:string AquireItem
	variable collection:string DeliverItem
	variable collection:string DeliverItemContainer

	;;;;;;;;;; Used when picking agents.
	variable index:string AgentList
	variable set CheckedAgent
	variable int validOfferAgentCandidateIndex = 0
	variable int validOfferAgentCandidateDistance = 0
	variable int noOfferAgentCandidateIndex = 0
	variable int noOfferAgentCandidateDistance = 0
	variable int invalidOfferAgentCandidateIndex = 0
	variable int invalidOfferAgentCandidateDistance = 0
	variable int invalidOfferAgentCandidateDeclineWaitTime = 0

	;;;;;;;;;; current mission data.
	variable int currentAgentIndex = 0
	variable string targetToDestroy
	variable string ammo
	variable string secondaryAmmo
	variable string containerToLoot
	variable string aquireItem
	variable string gateKey
	variable string gateKeyContainer
	variable string deliverItem
	variable string deliverItemContainer
	variable int useDroneRace = 0
	variable bool haveGateKeyInCargo = FALSE
	variable bool haveDeliveryInCargo = FALSE

	;;;;;;;;;; Used when performing mission.
	; If a target can't be killed within 2 minutes, something is going wrong.
	variable int maxAttackTime
	variable int switchTargetAfter = 120

	variable set AllowDronesOnNpcClass
	variable obj_TargetList NPCs
	variable obj_TargetList ActiveNPCs
	variable obj_TargetList Lootables

	variable obj_Configuration_Mission Config
	variable obj_Configuration_Agents Agents
	variable obj_MissionUI LocalUI

	variable bool reload = TRUE
	variable bool isLoadingFallbackDrones
	variable bool halt = FALSE

	method Initialize()
	{
		This[parent]:Initialize

		DynamicAddBehavior("Mission", "Combat Missions")
		This.PulseFrequency:Set[500]

		This.LogInfoColor:Set["g"]
		This.LogLevelBar:Set[${Config.LogLevelBar}]

		LavishScript:RegisterEvent[Tehbot_ScheduleHalt]
		Event[Tehbot_ScheduleHalt]:AttachAtom[This:ScheduleHalt]
		LavishScript:RegisterEvent[Tehbot_ScheduleResume]
		Event[Tehbot_ScheduleResume]:AttachAtom[This:ScheduleResume]

		Lootables:AddQueryString["(GroupID = GROUP_WRECK || GroupID = GROUP_CARGOCONTAINER) && !IsMoribund"]

		AllowDronesOnNpcClass:Add["Frigate"]
		AllowDronesOnNpcClass:Add["Destroyer"]
		AllowDronesOnNpcClass:Add["Cruiser"]
		AllowDronesOnNpcClass:Add["BattleCruiser"]
		AllowDronesOnNpcClass:Add["Battleship"]
		AllowDronesOnNpcClass:Add["Sentry"]
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
		AgentList:Clear
		DamageType:Clear
		ContainerToLoot:Clear
		AquireItem:Clear
		BlackListedMissions:Clear
		TargetToDestroy:Clear
		GateKey:Clear
		GateKeyContainer:Clear

		if !${Config.MissionFile.NotNULLOrEmpty}
		{
			This:LogCritical["You need to specify a mission file!"]
			return
		}

		variable filepath MissionData = "${Script[Tehbot].CurrentDirectory}/data/${Config.MissionFile}"
		runscript "${MissionData}"

		if ${This.IsIdle}
		{
			This:LogInfo["Starting"]
			This:QueueState["UpdateNPCs"]
			This:QueueState["ReportMissionConfigs"]
			This:QueueState["Repair"]
			This:QueueState["Cleanup"]
			This:QueueState["RequestMissionsFromAgentsInStation"]
			This:QueueState["PickAgent"]
			This:QueueState["CheckForWork"]
			EVE:RefreshBookmarks
		}

		This:BuildNpcQueries
		ActiveNPCs.AutoLock:Set[TRUE]
		NPCs.AutoLock:Set[TRUE]
		UIElement[Run@TitleBar@Tehbot]:SetText[Stop]
	}

	method Stop()
	{
		This:LogInfo["Stopping."]
		This:Clear
		UIElement[Run@TitleBar@Tehbot]:SetText[Run]
	}

	member:bool test()
	{
		echo ${Config.Halt}
	}

	member:bool UpdateNPCs()
	{
		NPCs:RequestUpdate
		return TRUE
	}

	member:bool ReportMissionConfigs()
	{
		This:LogInfo["Mission Configuration Loaded"]
		This:LogInfo[" ${DamageType.Used} Missions Configured", "o"]
		return TRUE
	}

	member:bool Repair()
	{
		if ${Me.InStation} && ${Utility.Repair}
		{
			This:InsertState["Repair", 2000]
			return TRUE
		}

		return TRUE
	}

	member:bool CheckForWork()
	{
		This:LogDebug["CheckForWork \ao${EVE.Agent[${currentAgentIndex}].Name}"]
		variable index:agentmission missions
		variable iterator missionIterator
		variable string missionName

		EVE:GetAgentMissions[missions]
		missions:GetIterator[missionIterator]
		if ${missionIterator:First(exists)}
		{
			do
			{
				if ${missionIterator.Value.AgentID} != ${EVE.Agent[${currentAgentIndex}].ID}
				{
					continue
				}

				missionIterator.Value:GetDetails
				if !${EVEWindow[ByCaption, Mission journal - ${EVE.Agent[${currentAgentIndex}].Name}](exists)}
				{
					if ${EVEWindow[ByCaption, Mission journal](exists)}
					{
						; Close journal of other mission.
						EVEWindow[ByCaption, Mission journal]:Close
					}
					missionIterator.Value:GetDetails
					return FALSE
				}

				variable string missionJournalText = ${EVEWindow[ByCaption, Mission journal - ${EVE.Agent[${currentAgentIndex}].Name}].HTML.Escape}
				if !${missionJournalText.NotNULLOrEmpty} || !${missionJournalText.Find["The following rewards will be yours if you complete this mission"]}
				{
					missionIterator.Value:GetDetails
					return FALSE
				}

				missionName:Set[${missionIterator.Value.Name.Trim}]

				; offered
				if ${missionIterator.Value.State} == 1
				{
					if ${Config.DeclineLowSec} && ${missionJournalText.Find["low security system"]}
					{
						This:LogInfo["Declining low security mission \ao${missionName}"]
						This:InsertState["Cleanup"]
						This:InsertState["CheckForWork"]
						This:InsertState["InteractAgent", 1500, "DECLINE"]
						return TRUE
					}

					if ${BlackListedMissions.Contains[${missionName}]}
					{
						This:LogInfo["Declining mission \ao${missionName}"]
						This:InsertState["Cleanup"]
						This:InsertState["CheckForWork"]
						This:InsertState["InteractAgent", 1500, "DECLINE"]
						return TRUE
					}

					if ${DamageType.Element[${missionName}](exists)}
					{
						This:LogInfo["Accepting mission \ao${missionName}"]
						This:InsertState["Cleanup"]
						This:InsertState["CheckForWork"]
						This:InsertState["InteractAgent", 1500, "ACCEPT"]
						useDroneRace:Set[0]
						return TRUE
					}

					This:LogInfo["Unconfigured mission \ao${missionName}"]
					if ${Me.StationID} != ${EVE.Agent[${currentAgentIndex}].StationID}
					{
						This:LogInfo["Going to the agent station anyway"]
						This:InsertState["Cleanup"]
						This:InsertState["Repair"]
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
					if ${DamageType.Element[${missionName}](exists)}
					{
						variable string checkmarkIcon = "icon:38_193"
						variable string circlemarkIcon = "icon:38_195"
						if ${missionJournalText.Find[${missionName} Objectives Complete]} || \
						(${Math.Calc[${missionJournalText.Length} - ${missionJournalText.ReplaceSubstring[${checkmarkIcon}, ""].Length}].Int} >= ${Math.Calc[${checkmarkIcon.Length} * 2].Int} && \
						; No unfinished targets(circle) or the circle appears before the first check implies that the ship is not docked at the dropoff station
						(!${missionJournalText.Find[${circlemarkIcon}]} || ${missionJournalText.Find[${circlemarkIcon}]} < ${missionJournalText.Find[${checkmarkIcon}]}))
						{
							This:LogInfo["Mission Complete \ao${missionName}"]
							This:Clear
							This:InsertState["Cleanup"]
							This:InsertState["Repair"]
							This:InsertState["CompleteMission", 1500]
							return TRUE
						}

						if ${missionJournalText.Find[${missionName} Objectives]}
						{
							This:LogInfo["Ongoing mission identified \ao${missionName}"]

							targetToDestroy:Set[""]
							if ${TargetToDestroy.Element[${missionName}](exists)}
							{
								This:LogInfo["Destroy target: \ao${TargetToDestroy.Element[${missionName}]}"]
								targetToDestroy:Set[${TargetToDestroy.Element[${missionName}]}]
							}

							containerToLoot:Set[""]
							if ${ContainerToLoot.Element[${missionName}](exists)}
							{
								This:LogInfo["Loot container: \ao${ContainerToLoot.Element[${missionName}]}"]
								containerToLoot:Set[${ContainerToLoot.Element[${missionName}]}]
							}

							aquireItem:Set[""]
							if ${AquireItem.Element[${missionName}](exists)}
							{
								This:LogInfo["Acquire item: \ao${AquireItem.Element[${missionName}]}"]
								aquireItem:Set[${AquireItem.Element[${missionName}]}]
							}

							gateKey:Set[""]
							gateKeyContainer:Set[""]
							if ${GateKey.Element[${missionName}](exists)}
							{
								This:LogInfo["Bring gate key if available: \ao${GateKey.Element[${missionName}]}"]
								gateKey:Set[${GateKey.Element[${missionName}]}]

								haveGateKeyInCargo:Set[FALSE]
								if (!${EVEWindow[Inventory](exists)})
								{
									EVE:Execute[OpenInventory]
									return FALSE
								}

								if !${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo].Capacity} < 0
								{
									EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo]:MakeActive
									return FALSE
								}

								if ${This.InventoryItemQuantity[${gateKey}, ${Me.ShipID}, "ShipCargo"]} > 0
								{
									This:LogInfo["Confirmed gate key \"${gateKey}\" in cargo."]
									haveGateKeyInCargo:Set[TRUE]
								}

								if !${haveGateKeyInCargo}
								{
									if ${GateKeyContainer.Element[${missionName}](exists)}
									{
										This:LogInfo["Look for the gate key in: \ao${GateKeyContainer.Element[${missionName}]}"]
										gateKeyContainer:Set[${GateKeyContainer.Element[${missionName}]}]
									}
								}
							}

							deliverItem:Set[""]
							deliverItemContainer:Set[""]
							if ${DeliverItem.Element[${missionName}](exists)}
							{
								This:LogInfo["Deliver item: \ao${DeliverItem.Element[${missionName}]}"]
								deliverItem:Set[${DeliverItem.Element[${missionName}]}]

								haveDeliveryInCargo:Set[FALSE]
								if (!${EVEWindow[Inventory](exists)})
								{
									EVE:Execute[OpenInventory]
									return FALSE
								}

								if !${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo].Capacity} < 0
								{
									EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo]:MakeActive
									return FALSE
								}

								if ${This.InventoryItemQuantity[${deliverItem}, ${Me.ShipID}, "ShipCargo"]} > 0
								{
									This:LogInfo["Confirmed delivery \"${deliverItem}\" in cargo."]
									haveDeliveryInCargo:Set[TRUE]
								}

								if ${DeliverItemContainer.Element[${missionName}](exists)}
								{
									This:LogInfo["Deliver the item to: \ao${DeliverItemContainer.Element[${missionName}]}"]
									deliverItemContainer:Set[${DeliverItemContainer.Element[${missionName}]}]
								}
								else
								{
									This:LogCritical["Don't know where to deliver, halting."]
									This:Clear
									return TRUE
								}
							}

							; echo damagetype ${DamageType.Element[${missionName}].Lower}
							switch ${DamageType.Element[${missionName}].Lower}
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

							Ship.ModuleList_Weapon:ConfigureAmmo[${ammo}, ${secondaryAmmo}]

							if ${Client.InSpace} && (${Entity[Type = "Beacon"]} || ${Entity[Type = "Acceleration Gate"]})
							{
								This:InsertState["PerformMission"]
								This:InsertState["Cleanup"]
								return TRUE
							}
						}
					}

					if ${Me.InStation} && ${reload}
					{
						This:LogInfo["Loading Ammo \ao${ammo}"]
						if ${Config.UseSecondaryAmmo}
						{
							This:LogInfo["Loading Secondary Ammo \ao${secondaryAmmo}", "o"]
						}
						reload:Set[FALSE]
						This:InsertState["CheckForWork"]
						isLoadingFallbackDrones:Set[FALSE]
						This:InsertState["ReloadAmmoAndDrones"]
						if !${haveGateKeyInCargo}
						{
							This:InsertState["TryBringGateKey"]
						}
						if ${deliverItem.NotNULLOrEmpty} && !${haveDeliveryInCargo}
						{
							This:InsertState["BringDelivery"]
						}
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
								This:BuildNpcQueries
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

		This:LogInfo["Requesting mission"]
		This:InsertState["CheckForWork"]
		This:InsertState["InteractAgent", 1500, "OFFER"]
		return TRUE
	}

	method BuildNpcQueries()
	{
		variable iterator classIterator
		variable iterator groupIterator
		variable string groups = ""
		variable string seperator = ""

		ActiveNPCs:ClearQueryString

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
						This:LogCritical["unknown EW ${jamsIterator.Value}"]
					}
				}
				while ${jamsIterator:Next(exists)}
			}
		}
		while ${attackerIterator:Next(exists)}

		ActiveNPCs:AddQueryString["IsNPC && !IsMoribund && (${groups})"]
		ActiveNPCs:AddQueryString["IsNPC && !IsMoribund && IsWarpScramblingMe"]

		; Add potential jammers.
		seperator:Set[""]
		groups:Set[""]
		PrioritizedTargets.Scramble:GetIterator[groupIterator]
		if ${groupIterator:First(exists)}
		{
			do
			{
				groups:Concat[${seperator}Name =- "${groupIterator.Value}"]
				seperator:Set[" || "]
			}
			while ${groupIterator:Next(exists)}
		}
		ActiveNPCs:AddQueryString["IsNPC && IsTargetingMe && !IsMoribund && (${groups})"]

		seperator:Set[""]
		groups:Set[""]
		PrioritizedTargets.Neut:GetIterator[groupIterator]
		if ${groupIterator:First(exists)}
		{
			do
			{
				groups:Concat[${seperator}Name =- "${groupIterator.Value}"]
				seperator:Set[" || "]
			}
			while ${groupIterator:Next(exists)}
		}
		ActiveNPCs:AddQueryString["IsNPC && IsTargetingMe && !IsMoribund && (${groups})"]

		seperator:Set[""]
		groups:Set[""]
		PrioritizedTargets.ECM:GetIterator[groupIterator]
		if ${groupIterator:First(exists)}
		{
			do
			{
				groups:Concat[${seperator}Name =- "${groupIterator.Value}"]
				seperator:Set[" || "]
			}
			while ${groupIterator:Next(exists)}
		}
		ActiveNPCs:AddQueryString["IsNPC && IsTargetingMe && !IsMoribund && (${groups})"]

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
				ActiveNPCs:AddQueryString["IsNPC && IsTargetingMe && !IsMoribund && (${groups})"]
			}
			while ${classIterator:Next(exists)}
		}

		ActiveNPCs:AddTargetingMe

		if ${Config.AggressiveMode}
		{
			ActiveNPCs:AddAllNPCs
			if ${targetToDestroy.NotNULLOrEmpty}
			{
				ActiveNPCs:AddQueryString[${targetToDestroy.Escape}]
			}
		}

		NPCs:ClearQueryString
		NPCs:AddAllNPCs

		if ${Config.IgnoreNPCSentries}
		{
			ActiveNPCs:AddTargetExceptionByPartOfName["Battery"]
			ActiveNPCs:AddTargetExceptionByPartOfName["Batteries"]
			ActiveNPCs:AddTargetExceptionByPartOfName["Sentry Gun"]
			ActiveNPCs:AddTargetExceptionByPartOfName["Tower Sentry"]

			NPCs:AddTargetExceptionByPartOfName["Battery"]
			NPCs:AddTargetExceptionByPartOfName["Batteries"]
			NPCs:AddTargetExceptionByPartOfName["Sentry Gun"]
			NPCs:AddTargetExceptionByPartOfName["Tower Sentry"]
		}
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
		ActiveNPCs:RequestUpdate
		NPCs:RequestUpdate
		Lootables:RequestUpdate
		Ship.ModuleList_ActiveResists:ActivateAll
		variable index:bookmark BookmarkIndex

		if ${Me.ToEntity.Mode} == 3
		{
			This:InsertState["PerformMission"]
			return TRUE
		}

		variable bool allowSiegeModule
		variable iterator targetIterator
		allowSiegeModule:Set[TRUE]
		if ${Config.DeactivateSiegeModuleEarly} && (${NPCs.TargetList.Used} < 2) && !${Entity[${targetToDestroy}]}
		{
			allowSiegeModule:Set[FALSE]
			NPCs.TargetList:GetIterator[targetIterator]
			if ${targetIterator:First(exists)}
			{
				do
				{
					if ${Entity[${targetIterator.Value}].Distance} > 70000
					{
						This:LogDebug["still allowing siege for target is ${Entity[${targetIterator.Value}].Distance} away"]
						allowSiegeModule:Set[TRUE]
						break
					}
				}
				while ${targetIterator:Next(exists)}
			}
		}

		if !${allowSiegeModule} && ${Ship.ModuleList_Siege.ActiveCount}
		{
			This:LogDebug["Deactivating siege module early. ${NPCs.TargetList.Used}"]
			Ship.ModuleList_Siege:DeactivateAll
		}

		; Hack: Approach to spawn Fajah Ateshi in Anomaly 1, not worth adding another mission configue for this one mission
		variable string containerQuery = "(Type = \"Ancient Ship Structure\")"
		variable string seperator = " || "

		if ${containerToLoot.NotNULLOrEmpty}
		{
			containerQuery:Concat["${seperator}(${containerToLoot})"]
			seperator:Set[" || "]
		}

		; Only interested in the gate key container when it's necessary to loot the key
		if ${gateKeyContainer.NotNULLOrEmpty} && \
			!${haveGateKeyInCargo} && \
			!${gateKeyContainer.Equal[${containerToLoot}]}
		{
			containerQuery:Concat["${seperator}(${gateKeyContainer})"]
			seperator:Set[" || "]
		}

		if ${deliverItemContainer.NotNULLOrEmpty} && \
			${haveDeliveryInCargo}
		{
			containerQuery:Concat["${seperator}(${deliverItemContainer})"]
			seperator:Set[" || "]
		}

		variable index:entity lootContainers
		if ${containerQuery.NotNULLOrEmpty}
		{
			EVE:QueryEntities[lootContainers, ${containerQuery}]
		}

		; Avoid duplicate check on containers.
		variable iterator containerIterator
		blackListedContainers:GetIterator[containerIterator]
		if ${containerIterator:First(exists)}
			do
			{
				lootContainers:RemoveByQuery[${LavishScript.CreateQuery[ID = ${containerIterator.Value}]}]
			}
			while ${containerIterator:Next(exists)}
		lootContainers:Collapse

		; Move to the loot or delivery containers before moving to gates.
		if ${lootContainers.Used}
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
								; This:LogInfo["Deactivate siege module due to approaching"]
								Ship.ModuleList_Siege:DeactivateAll
							}
							Entity[${currentLootContainer}]:Approach[1000]
							This:InsertState["PerformMission"]
							approachTimer:Set[${Math.Calc[${LavishScript.RunningTime} + 10000]}]
							return TRUE
						}

						if ${Ship.ModuleList_TractorBeams.Count} && \
							${Entity[${currentLootContainer}].Distance} < ${Ship.ModuleList_TractorBeams.Range} && \
							${Entity[${currentLootContainer}].Distance} < ${MyShip.MaxTargetRange} && \
							(${Entity[${currentLootContainer}].GroupID} == GROUP_WRECK || ${Entity[${currentLootContainer}].GroupID} == GROUP_CARGOCONTAINER)
						{
							if ${Entity[${currentLootContainer}].IsLockedTarget} && !${Ship.ModuleList_TractorBeams.IsActiveOn[${currentLootContainer}]}
							{
								if ${Ship.ModuleList_TractorBeams.InactiveCount} > 0
								{
									Ship.ModuleList_TractorBeams:ActivateOne[${currentLootContainer}]
								}
								else
								{
									Ship.ModuleList_TractorBeams:DeactivateOneNotOn[${currentLootContainer}]
								}
								return FALSE
							}
							elseif !${Entity[${currentLootContainer}].IsLockedTarget} && !${Entity[${currentLootContainer}].BeingTargeted}
							{
								Entity[${currentLootContainer}]:LockTarget
								return FALSE
							}
						}
						notDone:Set[TRUE]
					}
					; TODO Test without this condition
					elseif !${NPCs.TargetList.Used}
					{
						if !${EVEWindow[Inventory].ChildWindow[${currentLootContainer}](exists)}
						{
							Entity[${currentLootContainer}]:Open
							This:InsertState["PerformMission"]
							return TRUE
						}

						variable index:item items
						EVEWindow[Inventory].ChildWindow[${currentLootContainer}]:GetItems[items]
						if ${items.Used}
						{
							items:GetIterator[itemIterator]
							if ${itemIterator:First(exists)}
								do
								{
									if ${itemIterator.Value.Type.Equal[${aquireItem}]}
									{
										itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold]
										This:LogInfo["Aquired mission item: \ao${aquireItem}"]
										This:InsertState["CheckForWork"]
										This:InsertState["Idle", 2000]
										notDone:Set[FALSE]
										return TRUE
									}
									elseif ${itemIterator.Value.Type.Equal[${gateKey}]}
									{
										itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold]
										This:LogInfo["Aquired mission gate key: \ao${gateKey}"]
										haveGateKeyInCargo:Set[TRUE]
										gateKeyContainer:Set[""]
										This:InsertState["PerformMission"]
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
						elseif ${haveDeliveryInCargo} && ${deliverItemContainer.Find[${Entity[${currentLootContainer}].Name}]}
						{
							if !${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo].Capacity} < 0
							{
								EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo]:MakeActive
								return FALSE
							}

							variable index:item cargo
							variable iterator cargoIterator
							EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo]:GetItems[cargo]
							cargo:GetIterator[cargoIterator]
							if ${cargoIterator:First(exists)}
							{
								do
								{
									if ${cargoIterator.Value.Name.Equal[${deliverItem}]}
									{
										cargoIterator.Value:MoveTo[${Entity[${currentLootContainer}].ID}, CargoHold]
										This:LogInfo["Delivered \ao\"${deliverItem}\""]
										haveDeliveryInCargo:Set[FALSE]
										This:InsertState["CheckForWork"]
										This:InsertState["Idle", 2000]
										return TRUE
									}
								}
								while ${cargoIterator:Next(exists)}
							}

							This:LogCritical["Can't find the delivery in cargo"]
							; Don't halt here to help surviving
							; This:Clear
							; return TRUE
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

		variable int MaxTarget
		MaxTarget:Set[${Utility.Min[${Me.MaxLockedTargets}, ${MyShip.MaxLockedTargets}]}]
		MaxTarget:Dec[2]

		ActiveNPCs.MinLockCount:Set[${MaxTarget}]

		; ActiveNPCs:RequestUpdate
		; echo list is ${ActiveNPCs.LockedTargetList.Used}
		; finalized target not locked.
		if !${Entity[${currentTarget}]} || ${Entity[${currentTarget}].IsMoribund} || !(${Entity[${currentTarget}].IsLockedTarget} || ${Entity[${currentTarget}].BeingTargeted})
		{
			currentTarget:Set[0]
			maxAttackTime:Set[0]
		}
		elseif (${maxAttackTime} > 0 && ${LavishScript.RunningTime} > ${maxAttackTime})
		{
			This:LogInfo["Resseting target for the current one is taking too long."]
			currentTarget:Set[0]
			maxAttackTime:Set[0]
		}

		variable iterator lockedTargetIterator
		variable iterator activeJammerIterator
		Ship:BuildActiveJammerList
		; May switch target more than once so use this flag to avoid log spamming.
		variable bool switched
		if ${currentTarget} != 0
		{
			; Finalized decision
			variable bool finalized
			finalized:Set[FALSE]
			if ${Ship.ActiveJammerList.Used}
			{
				if !${Ship.ActiveJammerSet.Contains[${currentTarget}]}
				{
					; Being jammed but the jammer is not the current target
					Ship.ActiveJammerList:GetIterator[activeJammerIterator]
					do
					{
						if ${Entity[${activeJammerIterator.Value}].IsLockedTarget}
						{
							currentTarget:Set[${activeJammerIterator.Value}]
							maxAttackTime:Set[${Math.Calc[${LavishScript.RunningTime} + (${switchTargetAfter} * 1000)]}]
							This:LogInfo["Switching target to activate jammer \ar${Entity[${currentTarget}].Name}"]
							finalized:Set[TRUE]
							break
						}
					}
					while ${activeJammerIterator:Next(exists)}
				}
				else
				{
					finalized:Set[TRUE]
				}
			}

			if !${finalized} && ${ActiveNPCs.LockedTargetList.Used} && (${Ship.IsHardToDealWithTarget[${currentTarget}]} || ${This.IsStructure[${currentTarget}]})
			{
				ActiveNPCs.LockedTargetList:GetIterator[lockedTargetIterator]
				if ${lockedTargetIterator:First(exists)}
				{
					do
					{
						if ${This.IsStructure[${currentTarget}]} && !${This.IsStructure[${lockedTargetIterator.Value}]}
						{
							This:LogInfo["Pritorizing non-structure targets."]
							currentTarget:Set[0]
							maxAttackTime:Set[0]
							return FALSE
						}
					}
					while ${lockedTargetIterator:Next(exists)}
				}

				; Switched to easier target.
				switched:Set[FALSE]
				if ${lockedTargetIterator:First(exists)}
				{
					do
					{
						if !${Ship.IsHardToDealWithTarget[${lockedTargetIterator.Value}]} && !${This.IsStructure[${lockedTargetIterator.Value}]} && \
						(${Ship.IsHardToDealWithTarget[${currentTarget}]} || ${Entity[${currentTarget}].Distance} > ${Entity[${lockedTargetIterator.Value}].Distance})
						{
							currentTarget:Set[${lockedTargetIterator.Value}]
							maxAttackTime:Set[${Math.Calc[${LavishScript.RunningTime} + (${switchTargetAfter} * 1000)]}]
							switched:Set[TRUE]
						}
					}
					while ${lockedTargetIterator:Next(exists)}
				}
				if ${switched}
				{
					This:LogInfo["Switching to easier target: \ar${Entity[${currentTarget}].Name}"]
				}
			}
		}
		elseif ${ActiveNPCs.LockedTargetList.Used}
		{
			; Need to re-pick from locked target
			if ${Ship.ActiveJammerList.Used}
			{
				Ship.ActiveJammerList:GetIterator[activeJammerIterator]
				do
				{
					if ${Entity[${activeJammerIterator.Value}].IsLockedTarget}
					{
						currentTarget:Set[${activeJammerIterator.Value}]
						maxAttackTime:Set[${Math.Calc[${LavishScript.RunningTime} + (${switchTargetAfter} * 1000)]}]
						This:LogInfo["Targeting activate jammer \ar${Entity[${currentTarget}].Name}"]
						break
					}
				}
				while ${activeJammerIterator:Next(exists)}
			}

			if ${currentTarget} == 0
			{
				; Priortize the closest target which is not hard to deal with to
				; reduce the frequency of switching ammo.
				variable int64 lowPriorityTarget = 0
				ActiveNPCs.LockedTargetList:GetIterator[lockedTargetIterator]
				if ${lockedTargetIterator:First(exists)}
				{
					do
					{
						if ${Ship.IsHardToDealWithTarget[${lockedTargetIterator.Value}]} || ${This.IsStructure[${lockedTargetIterator.Value}]}
						{
							; Structure priority is lower than ships.
							if !${This.IsStructure[${lockedTargetIterator.Value}]} || ${lowPriorityTarget.Equal[0]}
							{
								lowPriorityTarget:Set[${lockedTargetIterator.Value}]
							}
						}
						elseif ${currentTarget} == 0 || ${Entity[${currentTarget}].Distance} > ${Entity[${lockedTargetIterator.Value}].Distance}
						{
							; if ${currentTarget} != 0
							; 	This:LogInfo["there is something closer ${Entity[${lockedTargetIterator.Value}].Name}"]
							currentTarget:Set[${lockedTargetIterator.Value}]
							maxAttackTime:Set[${Math.Calc[${LavishScript.RunningTime} + (${switchTargetAfter} * 1000)]}]
						}
					}
					while ${lockedTargetIterator:Next(exists)}
				}

				if ${currentTarget} == 0
				{
					; This:LogInfo["no easy target"]
					currentTarget:Set[${lowPriorityTarget}]
					maxAttackTime:Set[${Math.Calc[${LavishScript.RunningTime} + (${switchTargetAfter} * 1000)]}]
				}
			}
			This:LogInfo["Primary target: \ar${Entity[${currentTarget}].Name}"]
		}

		; Nothing is locked.
		if ${ActiveNPCs.TargetList.Used} && \
		   (${currentTarget} == 0 || ${currentTarget} == ${ActiveNPCs.TargetList.Get[1].ID}) && \
		   ${ActiveNPCs.TargetList.Get[1].Distance} > ${Math.Calc[${Ship.ModuleList_Weapon.Range} * 0.95]} && \
		   ${MyShip.ToEntity.Mode} != 1
		{
			if ${Ship.ModuleList_Siege.ActiveCount}
			{
				; This:LogInfo["Deactivate siege module due to no target"]
				Ship.ModuleList_Siege:DeactivateAll
			}
			This:LogInfo["Approaching distanced target: \ar${ActiveNPCs.TargetList.Get[1].Name}"]
			ActiveNPCs.TargetList.Get[1]:Approach
			This:InsertState["PerformMission"]
			return TRUE
		}

		if ${currentTarget} != 0 && ${Entity[${currentTarget}]} && !${Entity[${currentTarget}].IsMoribund}
		{
			variable string targetClass
			targetClass:Set[${NPCData.NPCType[${Entity[${currentTarget}].GroupID}]}]
			; Avoid using drones against structures which may cause AOE damage when destructed.
			if !${AllowDronesOnNpcClass.Contains[${targetClass}]}
			{
				DroneControl:Recall
			}

			if ${allowSiegeModule}
			{
				Ship.ModuleList_Siege:ActivateOne
			}

			; Shoot at out of range target to trigger them.
			if ${Ship.ModuleList_Weapon.Range} > ${Entity[${currentTarget}].Distance} || !${Config.RangeLimit} || !${Entity[${currentTarget}].IsTargetingMe}
			{
				Ship.ModuleList_Weapon:ActivateAll[${currentTarget}]
				Ship.ModuleList_TrackingComputer:ActivateFor[${currentTarget}]
			}
			if ${Entity[${currentTarget}].Distance} <= ${Ship.ModuleList_TargetPainter.Range}
			{
				Ship.ModuleList_TargetPainter:ActivateAll[${currentTarget}]
			}
			; 'Effectiveness Falloff' is not read by ISXEVE, but 20km is a generally reasonable range to activate the module
			if ${Entity[${currentTarget}].Distance} <= ${Math.Calc[${Ship.ModuleList_StasisGrap.Range} + 20000]}
			{
				Ship.ModuleList_StasisGrap:ActivateAll[${currentTarget}]
			}
			if ${Entity[${currentTarget}].Distance} <= ${Ship.ModuleList_StasisWeb.Range}
			{
				Ship.ModuleList_StasisWeb:ActivateAll[${currentTarget}]
			}
		}

		if ${ActiveNPCs.TargetList.Used} || ${nextwaitcomplete} == 0
		{
			This:InsertState["PerformMission", 500, ${Math.Calc[${LavishScript.RunningTime} + 10000]}]
			return TRUE
		}

		if ${LavishScript.RunningTime} < ${nextwaitcomplete}
			return FALSE

		NPCs.MinLockCount:Set[1]

		if ${NPCs.TargetList.Used}
		{
			if ${NPCs.TargetList.Get[1].Distance} > ${Math.Calc[${Ship.ModuleList_Weapon.Range} * .95]} && ${MyShip.ToEntity.Mode} != 1
			{
				if ${Ship.ModuleList_Siege.ActiveCount}
				{
					; This:LogInfo["Deactivate siege module due to approaching"]
					Ship.ModuleList_Siege:DeactivateAll
				}
				NPCs.TargetList.Get[1]:Approach
			}

			if ${currentTarget} == 0 || ${Entity[${currentTarget}].IsMoribund} || !${Entity[${currentTarget}]}
			{
				if ${NPCs.LockedTargetList.Used}
					currentTarget:Set[${NPCs.LockedTargetList.Get[1]}]
				else
					currentTarget:Set[0]
			}
			This:InsertState["PerformMission"]
			return TRUE
		}

		DroneControl:Recall

		if ${Entity[${targetToDestroy}]}
		{
			if ${Entity[${targetToDestroy}].Distance} > ${Math.Calc[${Ship.ModuleList_Weapon.Range} * .95]} && ${MyShip.ToEntity.Mode} != 1
			{
				if ${Ship.ModuleList_Siege.ActiveCount}
				{
					; This:LogInfo["Deactivate siege module due to approaching"]
					Ship.ModuleList_Siege:DeactivateAll
				}
				Entity[${targetToDestroy}]:Approach
			}

			if !${Entity[${targetToDestroy}].IsLockedTarget} && !${Entity[${targetToDestroy}].BeingTargeted} && \
				${Entity[${targetToDestroy}].Distance} < ${MyShip.MaxTargetRange}
			{
				This:LogInfo["Locking Target To Destroy"]
				This:LogInfo[" ${Entity[${targetToDestroy}].Name}", "o"]
				Entity[${targetToDestroy}]:LockTarget
			}
			elseif ${Entity[${targetToDestroy}].IsLockedTarget}
			{
				Ship.ModuleList_Weapon:ActivateAll[${Entity[${targetToDestroy}].ID}]
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
		variable string missionName
		EVE:GetAgentMissions[missions]
		missions:GetIterator[missionIterator]

		if ${missionIterator:First(exists)}
		{
			do
			{
				if ${missionIterator.Value.AgentID} != ${EVE.Agent[${currentAgentIndex}].ID}
				{
					continue
				}

				missionIterator.Value:GetDetails
				if !${EVEWindow[ByCaption, Mission journal - ${EVE.Agent[${currentAgentIndex}].Name}](exists)}
				{
					if ${EVEWindow[ByCaption, Mission journal](exists)}
					{
						; Close journal of other mission.
						EVEWindow[ByCaption, Mission journal]:Close
					}
					missionIterator.Value:GetDetails
					return FALSE
				}

				variable string missionJournalText = ${EVEWindow[ByCaption, Mission journal - ${EVE.Agent[${currentAgentIndex}].Name}].HTML.Escape}
				if !${missionJournalText.NotNULLOrEmpty} || !${missionJournalText.Find["The following rewards will be yours if you complete this mission"]}
				{
					missionIterator.Value:GetDetails
					return FALSE
				}

				missionName:Set[${missionIterator.Value.Name.Trim}]

				; accepted
				if ${missionIterator.Value.State} == 2
				{
					if ${DamageType.Element[${missionName}](exists)}
					{
						variable string checkmarkIcon = "icon:38_193"
						variable string circlemarkIcon = "icon:38_195"
						if ${missionJournalText.Find[${missionName} Objectives Complete]} || \
						(${Math.Calc[${missionJournalText.Length} - ${missionJournalText.ReplaceSubstring[${checkmarkIcon}, ""].Length}].Int} >= ${Math.Calc[${checkmarkIcon.Length} * 2].Int} && \
						; No unfinished targets(circle) or the circle appears before the first check which means the ship is not docked at the dropoff station
						(!${missionJournalText.Find[${circlemarkIcon}]} || ${missionJournalText.Find[${circlemarkIcon}]} < ${missionJournalText.Find[${checkmarkIcon}]}))
						{
							This:LogInfo["Mission Complete \ao${missionName}"]
							This:Clear
							This:InsertState["Cleanup"]
							This:InsertState["Repair"]
							This:InsertState["CompleteMission", 1500]
							return TRUE
						}
					}
				}
			}
			while ${missionIterator:Next(exists)}
		}

		if ${Entity[Type = "Acceleration Gate"]} && !${EVEWindow[byName, modal].Text.Find[This gate is locked!]}
		{
			if ${Ship.ModuleList_Siege.ActiveCount}
			{
				; This:LogInfo["Deactivate siege module due to approaching"]
				Ship.ModuleList_Siege:DeactivateAll
			}

			if ${Lootables.TargetList.Used} && ${Config.SalvagePrefix.NotNULLOrEmpty}
			{
				EVE:GetBookmarks[BookmarkIndex]
				BookmarkIndex:RemoveByQuery[${LavishScript.CreateQuery[SolarSystemID == ${Me.SolarSystemID}]}, FALSE]
				BookmarkIndex:RemoveByQuery[${LavishScript.CreateQuery[Distance < 200000]}, FALSE]
				BookmarkIndex:Collapse

				if !${BookmarkIndex.Used}
					Lootables.TargetList.Get[1]:CreateBookmark["${Config.SalvagePrefix} ${EVE.Agent[${currentAgentIndex}].Name} ${Me.Name} ${EVETime.Time.Left[5]}", "", "Corporation Locations", 1]
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

		if ${Lootables.TargetList.Used} && ${Config.SalvagePrefix.NotNULLOrEmpty}
		{
			EVE:GetBookmarks[BookmarkIndex]
			BookmarkIndex:RemoveByQuery[${LavishScript.CreateQuery[SolarSystemID == ${Me.SolarSystemID}]}, FALSE]
			BookmarkIndex:RemoveByQuery[${LavishScript.CreateQuery[Distance < 200000]}, FALSE]
			BookmarkIndex:Collapse

			if !${BookmarkIndex.Used}
				Lootables.TargetList.Get[1]:CreateBookmark["${Config.SalvagePrefix} ${EVE.Agent[${currentAgentIndex}].Name} ${EVETime.Time.Left[5]}", "", "Corporation Locations", 1]
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
		if ${EVEWindow[AgentBrowser](exists)}
		{
			EVEWindow[AgentBrowser]:Close
			return FALSE
		}
		if ${EVEWindow[agentinteraction_${EVE.Agent[${currentAgentIndex}].ID}](exists)}
		{
			EVEWindow[agentinteraction_${EVE.Agent[${currentAgentIndex}].ID}]:Close
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
			if ${Ship.ModuleList_Siege.ActiveCount}
			{
				; This:LogInfo["Deactivate siege module due to mission complete"]
				Ship.ModuleList_Siege:DeactivateAll
			}

			if ${DroneControl.ActiveDrones.Used} > 0
			{
				DroneControl:Recall
				return FALSE
			}
		}

		if ${Me.StationID} != ${EVE.Agent[${currentAgentIndex}].StationID}
		{
			This:LogInfo["Need to be at agent station to complete mission"]
			This:LogInfo["Setting course for \ao${EVE.Station[${EVE.Agent[${currentAgentIndex}].StationID}].Name}"]
			Move:Agent[${currentAgentIndex}]
			This:InsertState["CompleteMission", 1500]
			This:InsertState["Traveling"]
			return TRUE
		}

		if !${EVEWindow[agentinteraction_${EVE.Agent[${currentAgentIndex}].ID}](exists)}
		{
			EVE.Agent[${currentAgentIndex}]:StartConversation
			return FALSE
		}

		if ${EVEWindow[agentinteraction_${EVE.Agent[${currentAgentIndex}].ID}].Button["View Mission"](exists)}
		{
			EVEWindow[agentinteraction_${EVE.Agent[${currentAgentIndex}].ID}].Button["View Mission"]:Press
			return FALSE
		}

		if ${EVEWindow[agentinteraction_${EVE.Agent[${currentAgentIndex}].ID}].Button["Complete Mission"](exists)}
		{
			EVEWindow[agentinteraction_${EVE.Agent[${currentAgentIndex}].ID}].Button["Complete Mission"]:Press
			relay "all" -event Tehbot_SalvageBookmark ${Me.ID}
		}

		variable index:agentmission missions
		variable iterator missionIterator

		EVE:GetAgentMissions[missions]
		missions:GetIterator[missionIterator]
		if ${missionIterator:First(exists)}
			do
			{
				if ${missionIterator.Value.AgentID} == ${EVE.Agent[${currentAgentIndex}].ID} && ${missionIterator.Value.State} == 2
				{
					return FALSE
				}
			}
			while ${missionIterator:Next(exists)}

		if ${Utility.DowntimeClose}
		{
			This:LogInfo["Halting for downtime close."]
		}

		if !${Config.Halt} && !${halt} && !${Utility.DowntimeClose}
		{
			This:InsertState["CheckForWork"]
			This:InsertState["PickAgent"]
			This:InsertState["RequestMissionsFromAgentsInStation"]
			; This:InsertState["InteractAgent", 1500, "OFFER"]
			This:InsertState["SalvageCheck"]
			This:InsertState["RefreshBookmarks"]
		}
		else
		{
			UIElement[Run@TitleBar@Tehbot]:SetText[Run]
		}
		halt:Set[FALSE]
		This:InsertState["DropOffLoot"]
		This:InsertState["Cleanup"]
		This:InsertState["Repair"]
		return TRUE
	}

	member:bool InteractAgent(string Action)
	{
		if !${Me.InStation} || ${Me.StationID} != ${EVE.Agent[${currentAgentIndex}].StationID}
		{
			Move:Agent[${currentAgentIndex}]
			This:InsertState["InteractAgent", 1500, ${Action}]
			This:InsertState["Traveling"]
			return TRUE
		}

		if !${EVEWindow[agentinteraction_${EVE.Agent[${currentAgentIndex}].ID}](exists)}
		{
			EVE.Agent[${currentAgentIndex}]:StartConversation
			return FALSE
		}

		switch ${Action}
		{
			case OFFER
				if ${EVEWindow[agentinteraction_${EVE.Agent[${currentAgentIndex}].ID}].Button["View Mission"](exists)}
				{
					EVEWindow[agentinteraction_${EVE.Agent[${currentAgentIndex}].ID}].Button["View Mission"]:Press
					return TRUE
				}
				if ${EVEWindow[agentinteraction_${EVE.Agent[${currentAgentIndex}].ID}].Button["Request Mission"](exists)}
				{
					EVEWindow[agentinteraction_${EVE.Agent[${currentAgentIndex}].ID}].Button["Request Mission"]:Press
					return TRUE
				}

				break
			case ACCEPT
				if ${EVEWindow[agentinteraction_${EVE.Agent[${currentAgentIndex}].ID}].Button["Request Mission"](exists)}
				{
					EVEWindow[agentinteraction_${EVE.Agent[${currentAgentIndex}].ID}].Button["Request Mission"]:Press
					return FALSE
				}
				if ${EVEWindow[agentinteraction_${EVE.Agent[${currentAgentIndex}].ID}].Button["View Mission"](exists)}
				{
					EVEWindow[agentinteraction_${EVE.Agent[${currentAgentIndex}].ID}].Button["View Mission"]:Press
					return FALSE
				}
				if ${EVEWindow[agentinteraction_${EVE.Agent[${currentAgentIndex}].ID}].Button["Accept"](exists)}
				{
					EVEWindow[agentinteraction_${EVE.Agent[${currentAgentIndex}].ID}].Button["Accept"]:Press
					return FALSE
				}
				if ${EVEWindow[agentinteraction_${EVE.Agent[${currentAgentIndex}].ID}].Button["Close"](exists)}
				{
					EVEWindow[agentinteraction_${EVE.Agent[${currentAgentIndex}].ID}].Button["Close"]:Press
					return TRUE
				}
				break
			case DECLINE
				if !${Agents.CanDeclineMission[${EVE.Agent[${currentAgentIndex}].Name}]}
				{
					This:InsertState["CheckForWork"]
					This:InsertState["PickAgent"]
					return TRUE
				}
				if ${EVEWindow[agentinteraction_${EVE.Agent[${currentAgentIndex}].ID}].Button["View Mission"](exists)}
				{
					EVEWindow[agentinteraction_${EVE.Agent[${currentAgentIndex}].ID}].Button["View Mission"]:Press
					return FALSE
				}
				if ${EVEWindow[agentinteraction_${EVE.Agent[${currentAgentIndex}].ID}].Button["Decline"](exists)}
				{
					EVEWindow[agentinteraction_${EVE.Agent[${currentAgentIndex}].ID}].Button["Decline"]:Press
					This:InsertState["CatchDeclineWarning", 1500]
					return TRUE
				}
				break
		}
		return TRUE
	}

	member:bool CatchDeclineWarning()
	{
		if ${EVEWindow[byName, modal](exists)} && ${EVEWindow[byName, modal].Text.Find["if you decline a mission"]}
		{
			variable string prefix = "If you decline a mission before "
			variable string text = ${EVEWindow[byName, modal].Text.Mid[${prefix.Length}, 18]}

			variable string dataText = ${text.Token[1, " "]}
			variable string timeText = ${text.Token[2, " "]}

			variable int year = ${dataText.Token[1, "."]}
			variable int month = ${dataText.Token[2, "."]}
			variable int day = ${dataText.Token[3, "."]}
			variable int hour = ${timeText.Token[1, ":"]}
			variable int minute = ${timeText.Token[2, ":"]}

			variable time nextDeclineableTime
			nextDeclineableTime.YearPtr:Set[${Math.Calc[${year} - 1900]}]
			nextDeclineableTime.MonthPtr:Set[${Math.Calc[${month} - 1]}]
			nextDeclineableTime.Day:Set[${day}]
			nextDeclineableTime.Hour:Set[${hour}]
			nextDeclineableTime.Minute:Set[${minute}]
			nextDeclineableTime:Update

			EVEWindow[byName, modal]:ClickButtonNo
			Agents:SetNextDeclineableTime[${EVE.Agent[${currentAgentIndex}].Name}, ${nextDeclineableTime.Timestamp}]
			Agents:Save

			; This:LogInfo["agent ${EVE.Agent[${currentAgentIndex}].Name} next declineable time ${Agents.NextDeclineableTime[${EVE.Agent[${currentAgentIndex}].Name}]}"]
			; This:LogInfo["agent ${EVE.Agent[${currentAgentIndex}].Name} availability: ${Agents.CanDeclineMission[${EVE.Agent[${currentAgentIndex}].Name}]}"]
			; This:LogInfo["agent ${EVE.Agent[${currentAgentIndex}].Name} wait time: ${Agents.SecondsTillDeclineable[${EVE.Agent[${currentAgentIndex}].Name}]}"]

			; Client:Wait[1000]

			return FALSE
		}
		This:InsertState["CheckForWork"]
		return TRUE
	}

	member:bool WaitTill(int timestamp, bool start = TRUE)
	{
		if ${start}
		{
			variable time waitUntil
			waitUntil:Set[${timestamp}]

			variable int hour
			hour:Set[${waitUntil.Time24.Token[1, ":"]}]
			variable int minute
			minute:Set[${waitUntil.Time24.Token[2, ":"]}]

			if ${hour} == 10 && ${minute} >= 30 && ${minute} <= 59
			{
				This:LogInfo["Specified time ${waitUntil.Time24} is close to downtime, just halt."]

				This:InsertState["WaitTill", 5000, ${timestamp:Inc[3600]}]
				return TRUE
			}

			This:LogInfo["Start waiting until ${waitUntil.Date} ${waitUntil.Time24}."]
		}

		if ${Utility.EVETimestamp} < ${timestamp}
		{
			This:InsertState["WaitTill", 5000, "${timestamp}, FALSE"]
			return TRUE
		}

		This:LogInfo["Finished waiting."]
		return TRUE
	}

	member:bool StackShip()
	{
		EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo]:StackAll
		return TRUE
	}

	member:bool StackHangars()
	{
		if !${Me.InStation}
		{
			return TRUE
		}

		if !${EVEWindow[Inventory](exists)}
		{
			EVE:Execute[OpenInventory]
			return FALSE
		}

		variable index:item items
		variable iterator itemIterator
		variable int64 dropOffContainerID = 0;

		if ${Config.MunitionStorage.Equal[Corporation Hangar]}
		{
			if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)}
			{
				EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
				return FALSE
			}

			if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)}
			{
				EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
				return FALSE
			}
			EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:StackAll

			if ${Config.DropOffToContainer} && ${Config.DropOffContainerName.NotNULLOrEmpty}
			{
				EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:GetItems[items]
			}
		}
		elseif ${Config.MunitionStorage.Equal[Personal Hangar]}
		{
			if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
			{

				EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
				return FALSE
			}
			EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:StackAll

			if ${Config.DropOffToContainer} && ${Config.DropOffContainerName.NotNULLOrEmpty}
			{
				EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:GetItems[items]
			}
		}

		items:GetIterator[itemIterator]
		if ${itemIterator:First(exists)}
		{
			do
			{
				if ${itemIterator.Value.Name.Equal[${Config.DropOffContainerName}]} && ${itemIterator.Value.Type.Equal["Station Container"]}
				{
					dropOffContainerID:Set[${itemIterator.Value.ID}]
					itemIterator.Value:Open

					if !${EVEWindow[Inventory].ChildWindow[${dropOffContainerID}](exists)}
					{
						EVEWindow[Inventory].ChildWindow[${dropOffContainerID}]:MakeActive
						return FALSE
					}
					EVEWindow[Inventory].ChildWindow[${dropOffContainerID}]:StackAll
					break
				}
			}
			while ${itemIterator:Next(exists)}
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
		switch ${Config.MunitionStorageFolder}
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

	member:bool DropOffLoot()
	{
		if !${Me.InStation}
		{
			return TRUE
		}

		if !${EVEWindow[Inventory](exists)}
		{
			EVE:Execute[OpenInventory]
			return FALSE
		}

		variable index:item items
		variable iterator itemIterator
		variable int64 dropOffContainerID = 0;
		; Find the container item id first
		if ${Config.DropOffToContainer} && ${Config.DropOffContainerName.NotNULLOrEmpty}
		{
			if ${Config.MunitionStorage.Equal[Corporation Hangar]}
			{
				if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)}
				{
					EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
					return FALSE
				}

				if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)}
				{

					EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
					return FALSE
				}
				EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:GetItems[items]
			}
			elseif ${Config.MunitionStorage.Equal[Personal Hangar]}
			{
				if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
				{
					EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
					return FALSE
				}
				EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:GetItems[items]
			}

			items:GetIterator[itemIterator]
			if ${itemIterator:First(exists)}
			{
				do
				{
					if ${itemIterator.Value.Name.Equal[${Config.DropOffContainerName}]} && \
						${itemIterator.Value.Type.Equal["Station Container"]}
					{
						dropOffContainerID:Set[${itemIterator.Value.ID}]
						itemIterator.Value:Open

						if !${EVEWindow[Inventory].ChildWindow[${dropOffContainerID}](exists)}
						{
							EVEWindow[Inventory].ChildWindow[${dropOffContainerID}]:MakeActive
							return FALSE
						}
						break
					}
				}
				while ${itemIterator:Next(exists)}
			}
		}

		if !${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo](exists)}
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
					if ${Config.DropOffToContainer} && ${Config.DropOffContainerName.NotNULLOrEmpty} && ${dropOffContainerID} > 0
					{
						itemIterator.Value:MoveTo[${dropOffContainerID}, CargoHold]
						return FALSE
					}
					elseif ${Config.MunitionStorage.Equal[Corporation Hangar]}
					{
						if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)}
						{
							EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
							return FALSE
						}

						if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)}
						{
							EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
							return FALSE
						}

						itemIterator.Value:MoveTo[MyStationCorporateHangar, StationCorporateHangar, ${itemIterator.Value.Quantity}, ${This.CorporationFolder}]
						; return FALSE
					}
					elseif ${Config.MunitionStorage.Equal[Personal Hangar]}
					{
						if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
						{
							EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
							return FALSE
						}
						itemIterator.Value:MoveTo[MyStationHangar, Hangar]
						; return FALSE
					}
				}
			}
			while ${itemIterator:Next(exists)}
		}

		This:InsertState["StackHangars"]
		return TRUE
	}

	member:bool TryBringGateKey()
	{
		if !${gateKey.NotNULLOrEmpty}
		{
			return TRUE
		}

		if (!${EVEWindow[Inventory](exists)})
		{
			EVE:Execute[OpenInventory]
			return FALSE
		}

		if !${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo].Capacity} < 0
		{
			EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo]:MakeActive
			return FALSE
		}

		if ${This.InventoryItemQuantity[${gateKey}, ${Me.ShipID}, "ShipCargo"]} > 0
		{
			This:LogInfo["Confirmed gate key \"${gateKey}\" in cargo."]
			haveGateKeyInCargo:Set[TRUE]
			gateKeyContainer:Set[""]
			return TRUE
		}

		variable index:item items
		variable iterator itemIterator

		; Try loading from hangar
		if ${Config.MunitionStorage.Equal[Corporation Hangar]}
		{
			if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)}
			{
				EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
				return FALSE
			}

			if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)}
			{
				EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
				return FALSE
			}

			EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:GetItems[items]
		}
		elseif ${Config.MunitionStorage.Equal[Personal Hangar]}
		{
			if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
			{
				EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
				return FALSE
			}

			EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:GetItems[items]
		}

		items:GetIterator[itemIterator]
		if ${itemIterator:First(exists)}
		{
			do
			{
				if ${itemIterator.Value.Name.Equal[${gateKey}]}
				{
					This:LogInfo["Moving the gate key \"${gateKey}\" to cargo."]
					itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, 1]
					return FALSE
				}
			}
			while ${itemIterator:Next(exists)}
		}

		return TRUE
	}

	member:bool BringDelivery()
	{
		if !${deliverItem.NotNULLOrEmpty}
		{
			return TRUE
		}

		if (!${EVEWindow[Inventory](exists)})
		{
			EVE:Execute[OpenInventory]
			return FALSE
		}

		if !${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo](exists)} || ${EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo].Capacity} < 0
		{
			EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo]:MakeActive
			return FALSE
		}

		if ${This.InventoryItemQuantity[${deliverItem}, ${Me.ShipID}, "ShipCargo"]} > 0
		{
			This:LogInfo["Confirmed the delivery \"${deliverItem}\" in cargo."]
			haveDeliveryInCargo:Set[TRUE]
			return TRUE
		}

		if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
		{
			EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
			return FALSE
		}

		variable index:item items
		variable iterator itemIterator
		EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:GetItems[items]

		items:GetIterator[itemIterator]
		if ${itemIterator:First(exists)}
		{
			do
			{
				if ${itemIterator.Value.Name.Equal[${deliverItem}]}
				{
					This:LogInfo["Moving the delivery \"${deliverItem}\" to cargo."]
					itemIterator.Value:MoveTo[${MyShip.ID}, CargoHold, 1]
					return FALSE
				}
			}
			while ${itemIterator:Next(exists)}
		}

		This:LogCritical["Can't find the delivery ${deliverItem}, halting."]
		This:Clear
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
					if ${Config.MunitionStorage.Equal[Corporation Hangar]}
					{
						if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)}
						{
							EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
							return FALSE
						}

						if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)}
						{

							EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
							return FALSE
						}

						if !${itemIterator.Value.Name.Equal[${preferredDroneType}]}
						{
							itemIterator.Value:MoveTo[MyStationCorporateHangar, StationCorporateHangar, ${itemIterator.Value.Quantity}, ${This.CorporationFolder}]
							return FALSE
						}
					}
					elseif ${Config.MunitionStorage.Equal[Personal Hangar]}
					{
						if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
						{
							EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
							return FALSE
						}

						if !${itemIterator.Value.Name.Equal[${preferredDroneType}]} && \
							(!${itemIterator.Value.Name.Equal[${fallbackDroneType}]} || !${isLoadingFallbackDrones})
						{
							itemIterator.Value:MoveTo[MyStationHangar, Hangar]
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

		defaultAmmoAmountToLoad:Dec[${This.InventoryItemQuantity[${ammo}, ${Me.ShipID}, "ShipCargo"]}]
		secondaryAmmoAmountToLoad:Dec[${This.InventoryItemQuantity[${secondaryAmmo}, ${Me.ShipID}, "ShipCargo"]}]

		EVEWindow[Inventory].ChildWindow[${Me.ShipID}, ShipCargo]:GetItems[items]
		items:GetIterator[itemIterator]
		if ${itemIterator:First(exists)}
		{
			do
			{
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
						This:LogInfo["Loading ${loadingDroneNumber} \ao${preferredDroneType}\aws."]
						itemIterator.Value:MoveTo[${MyShip.ID}, DroneBay, ${loadingDroneNumber}]
						droneAmountToLoad:Dec[${loadingDroneNumber}]
						return FALSE
					}
					continue
				}

				; Move fallback drones together(to station hanger) before moving them to drone bay to ensure preferred type is loaded before fallback type.
				if ${itemIterator.Value.Name.Equal[${fallbackDroneType}]}
				{
					if ${Config.MunitionStorage.Equal[Corporation Hangar]}
					{
						if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)}
						{
							EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
							return FALSE
						}

						if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)}
						{

							EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
							return FALSE
						}

						itemIterator.Value:MoveTo[MyStationCorporateHangar, StationCorporateHangar, ${itemIterator.Value.Quantity}, ${This.CorporationFolder}]
						return FALSE
					}
					elseif ${Config.MunitionStorage.Equal[Personal Hangar]}
					{
						if !${EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems](exists)}
						{
							EVEWindow[Inventory].ChildWindow[${Me.Station.ID}, StationItems]:MakeActive
							return FALSE
						}

						itemIterator.Value:MoveTo[MyStationHangar, Hangar]
						return FALSE
					}
					continue
				}
			}
			while ${itemIterator:Next(exists)}
		}

		if ${Config.MunitionStorage.Equal[Corporation Hangar]}
		{
			if !${EVEWindow[Inventory].ChildWindow[StationCorpHangar](exists)}
			{
				EVEWindow[Inventory].ChildWindow[StationCorpHangars]:MakeActive
				return FALSE
			}

			if !${EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}](exists)}
			{
				EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:MakeActive
				return FALSE
			}

			EVEWindow[Inventory].ChildWindow["StationCorpHangar", ${Config.MunitionStorageFolder}]:GetItems[items]
		}
		elseif ${Config.MunitionStorage.Equal[Personal Hangar]}
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
					This:LogInfo["Loading ${loadingDroneNumber} \ao${preferredDroneType}\aws."]
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
			isLoadingFallbackDrones:Set[TRUE]
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
						This:LogInfo["Loading ${loadingDroneNumber} \ao${fallbackDroneType}\aws for having no \ao${preferredDroneType}\aw."]
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
			This:LogCritical["You're out of ${ammo}, halting."]
			This:Clear
			return TRUE
		}
		elseif ${Config.UseSecondaryAmmo} && ${secondaryAmmoAmountToLoad} > 0
		{
			This:LogCritical["You're out of ${secondaryAmmo}, halting."]
			This:Clear
			return TRUE
		}
		elseif ${Config.UseDrones} && ${droneAmountToLoad} > 0
		{
			This:LogCritical["You're out of drones, halting."]
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
		This:LogInfo["Refreshing bookmarks"]
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
				if ${BookmarkIterator.Value.Label.Find[${EVE.Agent[${currentAgentIndex}].Name}]}
				{
					totalBookmarks:Inc
				}
			}
			while ${BookmarkIterator:Next(exists)}

		EVE:RefreshBookmarks
		if ${totalBookmarks} > 15
		{
			This:LogInfo["Salvage running behind, waiting 5 minutes"]
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
				if ${Ship.ModuleList_Siege.ActiveCount}
				{
					Ship.ModuleList_Siege:DeactivateAll
				}

				if ${ammo.NotNULLOrEmpty}
				{
					Ship.ModuleList_Weapon:ConfigureAmmo[${ammo}, ${secondaryAmmo}]
				}

				Ship.ModuleList_Weapon:ReloadDefaultAmmo

				if ${Ship.ModuleList_Regen_Shield.InactiveCount} && ((${MyShip.ShieldPct.Int} < 100 && ${MyShip.CapacitorPct.Int} > ${AutoModule.Config.ActiveShieldCap}) || ${AutoModule.Config.ShieldBoost})
				{
					Ship.ModuleList_Regen_Shield:ActivateAll
				}
				if ${Ship.ModuleList_Regen_Shield.ActiveCount} && (${MyShip.ShieldPct.Int} == 100 || ${MyShip.CapacitorPct.Int} < ${AutoModule.Config.ActiveShieldCap}) && !${AutoModule.Config.ShieldBoost}
				{
					Ship.ModuleList_Regen_Shield:DeactivateAll
				}
				if ${Ship.ModuleList_Repair_Armor.InactiveCount} && ((${MyShip.ArmorPct.Int} < 100 && ${MyShip.CapacitorPct.Int} > ${AutoModule.Config.ActiveArmorCap}) || ${AutoModule.Config.ArmorRepair})
				{
					Ship.ModuleList_Repair_Armor:ActivateAll
				}
				if ${Ship.ModuleList_Repair_Armor.ActiveCount} && (${MyShip.ArmorPct.Int} == 100 || ${MyShip.CapacitorPct.Int} < ${AutoModule.Config.ActiveArmorCap}) && !${AutoModule.Config.ArmorRepair}
				{
					Ship.ModuleList_Repair_Armor:DeactivateAll
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

	member:int InventoryItemQuantity(string itemName, string inventoryID, string subFolderName = "")
	{
		variable index:item items
		variable iterator itemIterator

		if !${EVEWindow[Inventory].ChildWindow[${inventoryID}, ${subFolderName}](exists)} || ${EVEWindow[Inventory].ChildWindow[${inventoryID}, ${subFolderName}].Capacity} < 0
		{
			echo must open inventory window before calling this function
			echo ${Math.Calc[1 / 0]}
		}

		EVEWindow[Inventory].ChildWindow[${inventoryID}, ${subFolderName}]:GetItems[items]
		items:GetIterator[itemIterator]

		variable int itemQuantity = 0
		if ${itemIterator:First(exists)}
		{
			do
			{
				if ${itemIterator.Value.Name.Equal[${itemName}]}
				{
					itemQuantity:Inc[${itemIterator.Value.Quantity}]
				}
			}
			while ${itemIterator:Next(exists)}
		}

		return ${itemQuantity}
	}

	method ResetAgentPickingStatus()
	{
		CheckedAgent:Clear
		validOfferAgentCandidateIndex:Set[0]
		validOfferAgentCandidateDistance:Set[0]
		noOfferAgentCandidateIndex:Set[0]
		noOfferAgentCandidateDistance:Set[0]
		invalidOfferAgentCandidateIndex:Set[0]
		invalidOfferAgentCandidateDistance:Set[0]
		invalidOfferAgentCandidateDeclineWaitTime:Set[0]
	}

	member:bool RequestMissionsFromAgentsInStation()
	{
		variable iterator agentIterator
		variable index:agentmission missions
		EVE:GetAgentMissions[missions]
		variable iterator missionIterator
		variable string missionName
		variable string agentName
		variable int agentIndex = 0
		variable bool offered = FALSE

		; Firstly get offer from all the specified agents in the same station.
		if ${Me.InStation}
		{
			AgentList:GetIterator[agentIterator]
			do
			{
				agentName:Set[${agentIterator.Value}]
				; Somehow direct initialization does not work.
				agentIndex:Set[${EVE.Agent[${agentName}].Index}]

				if ${agentIndex} == 0
				{
					This:LogCritical["Failed to find agent index for ${agentName}."]
					halt:Set[TRUE]
					return TRUE
				}

				offered:Set[FALSE]

				if ${Me.StationID} != ${EVE.Agent[${agentIndex}].StationID}
				{
					continue
				}

				missions:GetIterator[missionIterator]
				if ${missionIterator:First(exists)}
				{
					do
					{
						if ${missionIterator.Value.AgentID} == ${EVE.Agent[${agentIndex}].ID}
						{
							offered:Set[TRUE]
							break
						}
					}
					while ${missionIterator:Next(exists)}
				}

				if !${offered}
				{
					currentAgentIndex:Set[${agentIndex}]
					This:InsertState["RequestMissionsFromAgentsInStation"]
					This:InsertState["InteractAgent", 1500, "OFFER"]
					return TRUE
				}
			}
			while ${agentIterator:Next(exists)}
		}

		currentAgentIndex:Set[0]
		return TRUE
	}

	member:bool PickAgent()
	{
		; This method is called when:
		; 1. Starting script.
		; 2. Current active agent becomes unavailable(invalid offer and can't decline).
		; 3. Finishes current mission.

		; Assuming all the agents in the same station already have mission offer.

		if !${AgentList.Used}
		{
			This:LogCritical["AgentList not set."]
			halt:Set[TRUE]
			return TRUE
		}

		variable iterator agentIterator
		variable index:agentmission missions
		EVE:GetAgentMissions[missions]
		variable iterator missionIterator
		variable string missionName
		variable string agentName
		variable int agentIndex = 0
		variable bool offered = FALSE
		variable int agentDistance = 0

		AgentList:GetIterator[agentIterator]
		do
		{
			agentName:Set[${agentIterator.Value}]
			if ${CheckedAgent.Contains[${agentName}]}
			{
				; Avoid dead loop when opening journals of checked agent.
				continue
			}

			agentIndex:Set[${EVE.Agent[${agentName}].Index}]
			if ${agentIndex} == 0
			{
				This:LogCritical["Failed to find agent index for ${agentName}."]
				halt:Set[TRUE]
				return TRUE
			}

			; The distance seems to be the shortest path which can go throw low sec no matter the in game setting.
			agentDistance:Set[${EVE.Station[${EVE.Agent[${agentIndex}].StationID}].SolarSystem.JumpsTo}]
			if ${Me.InStation} && (${Me.StationID} == ${EVE.Agent[${agentIndex}].StationID})
			{
				agentDistance:Set[-1]
			}

			offered:Set[FALSE]
			missions:GetIterator[missionIterator]
			if ${missionIterator:First(exists)}
			{
				do
				{
					if ${missionIterator.Value.AgentID} == ${EVE.Agent[${agentIndex}].ID}
					{
						missionName:Set[${missionIterator.Value.Name.Trim}]
						This:LogDebug["Found mission for agent ${agentName} \ao${missionName}."]

						; accepted
						if ${missionIterator.Value.State} == 2
						{
							This:LogInfo["Found ongoing mission for agent ${agentName}, skip picking agents."]
							currentAgentIndex:Set[${agentIndex}]
							This:ResetAgentPickingStatus
							return TRUE
						}

						missionIterator.Value:GetDetails
						if !${EVEWindow[ByCaption, Mission journal - ${agentName}](exists)}
						{
							if ${EVEWindow[ByCaption, Mission journal](exists)}
							{
								EVEWindow[ByCaption, Mission journal]:Close
							}
							missionIterator.Value:GetDetails
							return FALSE
						}

						; Can't reliablely copy the string to vairable due to Lavish script bug.
						; variable string missionJournalText = ${EVEWindow[ByCaption, Mission journal - ${agentName}].HTML.Escape}
						if !${EVEWindow[ByCaption, Mission journal - ${agentName}].HTML.Escape.Find["The following rewards will be yours if you complete this mission"]}
						{
							missionIterator.Value:GetDetails
							return FALSE
						}

						This:LogDebug["Found mission for ${agentName} ${missionName}."]
						offered:Set[TRUE]

						if ${BlackListedMissions.Contains[${missionName}]} || (${Config.DeclineLowSec} && ${EVEWindow[ByCaption, Mission journal - ${agentName}].HTML.Escape.Find["low security system"]})
						{
							variable int agentDeclineWaitTime
							agentDeclineWaitTime:Set[${Agents.SecondsTillDeclineable[${agentName}]}]

							if ${invalidOfferAgentCandidateIndex} == 0 || \
								(${invalidOfferAgentCandidateDeclineWaitTime} > ${agentDeclineWaitTime}) || \
								((${invalidOfferAgentCandidateDeclineWaitTime} == ${agentDeclineWaitTime}) && (${invalidOfferAgentCandidateDistance} > ${agentDistance}))
							{
								invalidOfferAgentCandidateIndex:Set[${agentIndex}]
								invalidOfferAgentCandidateDeclineWaitTime:Set[${agentDeclineWaitTime}]
								invalidOfferAgentCandidateDistance:Set[${agentDistance}]

								This:LogInfo["Agent with invalid offer ${agentName} is ${agentDistance} jumps away and can decline again in ${invalidOfferAgentCandidateDeclineWaitTime} secs."]
							}
						}
						else
						{
							if ${validOfferAgentCandidateIndex} == 0 || ${validOfferAgentCandidateDistance} > ${agentDistance}
							{
								validOfferAgentCandidateIndex:Set[${agentIndex}]
								validOfferAgentCandidateDistance:Set[${agentDistance}]
							}

							This:LogInfo["Agent with valid offer ${agentName} is ${agentDistance} jumps away."]
						}

						; No multiple missions from the same agent.
						break
					}
				}
				while ${missionIterator:Next(exists)}
			}

			if !${offered}
			{
				This:LogInfo["Agent without offer ${agentName} is ${agentDistance} jumps away."]

				if ${agentDistance} == -1
				{
					This:LogCritical["Mission", "	which is unexpected."]
				}

				if ${noOfferAgentCandidateIndex} == 0 || ${noOfferAgentCandidateDistance} > ${agentDistance}
				{
					noOfferAgentCandidateIndex:Set[${agentIndex}]
					noOfferAgentCandidateDistance:Set[${agentDistance}]
				}
			}

			CheckedAgent:Add[${agentName}]
		}
		while ${agentIterator:Next(exists)}


		; Priority:
		; 1. Agents within 2 jumps with invalid offers which can be declined now. - if exists, it's guaranteed to be the current candidate.
		; (Previous steps guaranteed that agents in the same station have offers)
		; 2. Agents with valid offers.
		; 3. Agents without offer.
		; 4. Agents with invalid offers which may needs waiting.
		; For 1 to 3, pick the nearest agent.
		; For 4, pick the agent with the earliest decline time and then the shortest distance.
		if ${invalidOfferAgentCandidateIndex} != 0 && ${invalidOfferAgentCandidateDistance} < 3 && ${invalidOfferAgentCandidateDeclineWaitTime} == 0
		{
			currentAgentIndex:Set[${invalidOfferAgentCandidateIndex}]
			This:LogInfo["Prioritizing declining mission from agent ${EVE.Agent[${currentAgentIndex}].Name} to refresh the decline timer earlier."]
		}
		elseif ${validOfferAgentCandidateIndex} != 0
		{
			currentAgentIndex:Set[${validOfferAgentCandidateIndex}]
			This:LogInfo["Do offered mission for agent ${EVE.Agent[${currentAgentIndex}].Name}."]
		}
		elseif ${noOfferAgentCandidateIndex} != 0
		{
			currentAgentIndex:Set[${noOfferAgentCandidateIndex}]
			This:LogInfo["Request mission from agent ${EVE.Agent[${currentAgentIndex}].Name}."]
		}
		elseif ${invalidOfferAgentCandidateIndex} != 0
		{
			currentAgentIndex:Set[${invalidOfferAgentCandidateIndex}]
			if ${invalidOfferAgentCandidateDeclineWaitTime} > 0
			{
				; Schedule waiting AFTER travelling to the agent when necessary.
				variable time waitUntil
				waitUntil:Set[${Agents.NextDeclineableTime[${EVE.Agent[${currentAgentIndex}].Name}]}]
				This:LogInfo["Moving to agent ${EVE.Agent[${currentAgentIndex}].Name} and then wait until ${waitUntil.Date} ${waitUntil.Time24}"]
				This:InsertState["WaitTill", 1000, ${Agents.NextDeclineableTime[${EVE.Agent[${currentAgentIndex}].Name}]}]

				if ${invalidOfferAgentCandidateDistance} > -1
				{
					Move:Agent[${currentAgentIndex}]
					This:InsertState["Traveling"]
				}
			}
		}
		else
		{
			This:LogCritical["Failed to pick agent."]
			halt:Set[TRUE]
			This:ResetAgentPickingStatus
			return TRUE
		}

		This:LogInfo["Picked agent ${EVE.Agent[${currentAgentIndex}].Name}."]
		This:ResetAgentPickingStatus
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

	member:bool IsStructure(int64 targetID)
	{
		variable string targetClass
		targetClass:Set[${NPCData.NPCType[${Entity[${targetID}].GroupID}]}]
		if ${AllowDronesOnNpcClass.Contains[${targetClass}]}
		{
			return FALSE
		}

		return TRUE
	}
}


objectdef obj_MissionUI inherits obj_State
{
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