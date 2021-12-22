objectdef obj_Configuration_DroneControl inherits obj_Base_Configuration
{
	method Initialize()
	{
		This[parent]:Initialize["DroneControl"]
	}

	method Set_Default_Values()
	{
		This.CommonRef:AddSetting[Sentries, FALSE]
		This.CommonRef:AddSetting[SentryRange, 30]
		This.CommonRef:AddSetting[MaxDroneCount, 5]
	}

	Setting(bool, Sentries, SetSentries)
	Setting(int, SentryRange, SetSentryRange)
	Setting(int, MaxDroneCount, SetDroneCount)
	Setting(bool, UseIPC, SetUseIPC)
}

objectdef obj_DroneControl inherits obj_StateQueue
{
	variable obj_Configuration_DroneControl Config
	variable obj_TargetList ActiveNPC
	variable int64 currentTarget = 0
	variable bool IsBusy
	variable int droneEngageRange = 30000
	variable bool RecallActive=FALSE

	method Initialize()
	{
		This[parent]:Initialize
		PulseFrequency:Set[1000]
		This.NonGameTiedPulse:Set[TRUE]
		DynamicAddMiniMode("DroneControl", "DroneControl")
	}

	member:int FindBestType(int TargetGroupID)
	{
		variable string TargetClass
		variable int DroneType
		TargetClass:Set[${NPCData.NPCType[${TargetGroupID}]}]
		switch ${TargetClass}
		{
			case Frigate
			case Destroyer

				DroneType:Set[${Drones.Data.FindType["Light Scout Drones"]}]
				if ${DroneType} != -1
				{
					return ${DroneType}
				}

				DroneType:Set[${Drones.Data.FindType["Medium Scout Drones"]}]
				if ${DroneType} != -1
				{
					return ${DroneType}
				}

			case Cruiser
			case BattleCruiser

				DroneType:Set[${Drones.Data.FindType["Fighters"]}]
				if ${DroneType} != -1
				{
					return ${DroneType}
				}

				DroneType:Set[${Drones.Data.FindType["Medium Scout Drones"]}]
				if ${DroneType} != -1
				{
					return ${DroneType}
				}

				DroneType:Set[${Drones.Data.FindType["Light Scout Drones"]}]
				if ${DroneType} != -1
				{
					return ${DroneType}
				}

			case Battleship

				DroneType:Set[${Drones.Data.FindType["Fighters"]}]
				if ${DroneType} != -1
				{
					return ${DroneType}
				}

				DroneType:Set[${Drones.Data.FindType["Heavy Attack Drones"]}]
				if ${DroneType} != -1
				{
					return ${DroneType}
				}

				DroneType:Set[${Drones.Data.FindType["Medium Scout Drones"]}]
				if ${DroneType} != -1
				{
					return ${DroneType}
				}

				DroneType:Set[${Drones.Data.FindType["Light Scout Drones"]}]
				if ${DroneType} != -1
				{
					return ${DroneType}
				}
		}

		; Fallback for PVP
		DroneType:Set[${Drones.Data.FindType["Light Scout Drones"]}]
		if ${DroneType} != -1
		{
			return ${DroneType}
		}

		DroneType:Set[${Drones.Data.FindType["Medium Scout Drones"]}]
		if ${DroneType} != -1
		{
			return ${DroneType}
		}
	}

	member:int SentryCount()
	{
		variable iterator typeIterator
		variable string types = ""
		variable string seperator = ""

		seperator:Set[""]
		types:Set[""]
		Drones.Data.BaseRef.FindSet["Sentry Drones"]:GetSettingIterator[typeIterator]
		if ${typeIterator:First(exists)}
		{
			do
			{
				types:Concat["${seperator}TypeID = ${typeIterator.Key}"]
				seperator:Set[" || "]
			}
			while ${typeIterator:Next(exists)}
		}
		return ${Drones.ActiveDroneCount["${types}"]}
	}

	method RecallAllSentry()
	{
		variable iterator typeIterator
		variable string types = ""
		variable string seperator = ""

		seperator:Set[""]
		types:Set[""]
		Drones.Data.BaseRef.FindSet["Sentry Drones"]:GetSettingIterator[typeIterator]
		if ${typeIterator:First(exists)}
		{
			do
			{
				types:Concat["${seperator}TypeID = ${typeIterator.Key}"]
				seperator:Set[" || "]
			}
			while ${typeIterator:Next(exists)}
		}
		Drones:Recall["${types}", ${Drones.ActiveDroneCount["${types}"]}]
	}

	member:int NonSentryCount()
	{
		variable iterator typeIterator
		variable string types = ""
		variable string seperator = ""

		seperator:Set[""]
		types:Set[""]
		Drones.Data.BaseRef.FindSet["Sentry Drones"]:GetSettingIterator[typeIterator]
		if ${typeIterator:First(exists)}
		{
			do
			{
				types:Concat["${seperator}TypeID != ${typeIterator.Key}"]
				seperator:Set[" && "]
			}
			while ${typeIterator:Next(exists)}
		}
		return ${Drones.ActiveDroneCount["(ToEntity.GroupID = GROUP_SCOUT_DRONE || ToEntity.GroupID = GROUP_COMBAT_DRONE) && (${types})"]}
	}

	method RecallAllNonSentry()
	{
		variable iterator typeIterator
		variable string types = ""
		variable string seperator = ""

		seperator:Set[""]
		types:Set[""]
		Drones.Data.BaseRef.FindSet["Sentry Drones"]:GetSettingIterator[typeIterator]
		if ${typeIterator:First(exists)}
		{
			do
			{
				types:Concat["${seperator}TypeID != ${typeIterator.Key}"]
				seperator:Set[" && "]
			}
			while ${typeIterator:Next(exists)}
		}
		Drones:Recall["(ToEntity.GroupID = GROUP_SCOUT_DRONE || ToEntity.GroupID = GROUP_COMBAT_DRONE) && (${types})", ${Drones.ActiveDroneCount["ToEntity.GroupID = GROUP_SCOUT_DRONE && (${types})"]}]
	}

	method Start()
	{
		if ${This.IsIdle}
		{
			This:LogInfo["Starting."]
			ActiveNPC.MaxRange:Set[${droneEngageRange}]
			variable int MaxTarget = ${MyShip.MaxLockedTargets}
			if ${Me.MaxLockedTargets} < ${MyShip.MaxLockedTargets}
				MaxTarget:Set[${Me.MaxLockedTargets}]
			MaxTarget:Dec[2]

			ActiveNPC.MinLockCount:Set[${MaxTarget}]
			ActiveNPC.AutoLock:Set[TRUE]
			This:QueueState["DroneControl"]
		}
	}

	method Stop()
	{
		This:LogInfo["Stopping."]
		ActiveNPC.AutoLock:Set[FALSE]
		This:Clear
	}

	method Recall()
	{
		if ${This.RecallActive}
		{
			return
		}
		This.RecallActive:Set[TRUE]

		variable bool DontResume=${This.IsIdle}

		This:Clear

		if ${Drones.DronesInSpace}
		{
			Busy:SetBusy["DroneControl"]
			Drones:RecallAll
			This:QueueState["Idle", 2000]
			This:QueueState["RecallCheck"]
		}
		else
		{
			Busy:UnsetBusy["DroneControl"]
		}

		This:QueueState["Idle", 20000]
		This:QueueState["ResetRecall", 50]

		if !${DontResume}
		{
			This:QueueState["DroneControl"]
		}
	}

	member:bool RecallCheck()
	{
		if ${Drones.DronesInSpace}
		{
			Drones:RecallAll
			This:InsertState["RecallCheck"]
			This:InsertState["Idle", 2000]
		}
		else
		{
			Busy:UnsetBusy["DroneControl"]
		}
		return TRUE
	}

	member:bool ResetRecall()
	{
		This.RecallActive:Set[FALSE]
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
						Logger:Log["Mission", "unknown EW ${jamsIterator.Value}", "r"]
					}
				}
				while ${jamsIterator:Next(exists)}
			}
		}
		while ${attackerIterator:Next(exists)}

		ActiveNPC:AddQueryString["Distance < ${droneEngageRange} && IsNPC && !IsMoribund && (${groups})"]
		ActiveNPC:AddQueryString["Distance < ${droneEngageRange} && IsNPC && !IsMoribund && IsWarpScramblingMe"]

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
		ActiveNPC:AddQueryString["Distance < ${droneEngageRange} && IsNPC && IsTargetingMe && !IsMoribund && (${groups})"]

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
		ActiveNPC:AddQueryString["Distance < ${droneEngageRange} && IsNPC && IsTargetingMe && !IsMoribund && (${groups})"]

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
		ActiveNPC:AddQueryString["Distance < ${droneEngageRange} && IsNPC && IsTargetingMe && !IsMoribund && (${groups})"]

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
				ActiveNPC:AddQueryString["Distance < ${droneEngageRange} && IsNPC && IsTargetingMe && !IsMoribund && (${groups})"]
			}
			while ${classIterator:Next(exists)}
		}

		ActiveNPC:AddTargetingMe
	}

	member:bool DroneControl()
	{
		variable index:activedrone ActiveDrones
		variable iterator DroneIterator
		variable float CurrentDroneHealth
		variable iterator DroneTypesIter
		variable int MaxDroneCount = ${Config.MaxDroneCount}

		This:BuildActiveNPC
		ActiveNPC:RequestUpdate

		if ${MaxDroneCount} > ${Me.MaxActiveDrones}
		{
			MaxDroneCount:Set[${Me.MaxActiveDrones}]
		}

		ActiveNPC.MinLockCount:Set[${Config.LockCount}]

		if !${Client.InSpace}
		{
			return FALSE
		}

		if ${Me.ToEntity.Mode} == MOVE_WARPING
		{
			if ${Drones.ActiveCount["ToEntity.GroupID = GROUP_SCOUT_DRONE || ToEntity.GroupID = GROUP_COMBAT_DRONE"]} > 0
			{
				Drones:Recall["ToEntity.GroupID = GROUP_SCOUT_DRONE || ToEntity.GroupID = GROUP_COMBAT_DRONE"]
			}
			return FALSE
		}

		if ${Drones.DronesInBay.Equal[0]} && ${Drones.DronesInSpace.Equal[0]}
		{
			Busy:UnsetBusy["DroneControl"]
			return FALSE
		}

		if ${IsBusy}
		{
			if ${Drones.DronesInSpace.Equal[0]}
			{
				Busy:UnsetBusy["DroneControl"]
				IsBusy:Set[FALSE]
			}
		}

		Me:GetActiveDrones[ActiveDrones]
		ActiveDrones:GetIterator[DroneIterator]
		if ${DroneIterator:First(exists)}
		{
			do
			{
				CurrentDroneHealth:Set[${Math.Calc[${DroneIterator.Value.ToEntity.ShieldPct.Int} + ${DroneIterator.Value.ToEntity.ArmorPct.Int} + ${DroneIterator.Value.ToEntity.StructurePct.Int}]}]
				if ${Drones.DroneHealth.Element[${DroneIterator.Value.ID}]} && ${CurrentDroneHealth} < ${Drones.DroneHealth.Element[${DroneIterator.Value.ID}]}
				{
					; echo recalling ID ${DroneIterator.Value.ID}
					Drones:Recall["ID = ${DroneIterator.Value.ID}", 1]
				}
				Drones.DroneHealth:Set[${DroneIterator.Value.ID}, ${CurrentDroneHealth.Int}]
				; echo drone refreshed cached health ${Drones.DroneHealth.Element[${DroneIterator.Value.ID}]}
			}
			while ${DroneIterator:Next(exists)}
		}


		if !${Entity[${currentTarget}](exists)} || ${Entity[${currentTarget}].IsMoribund} || (!${Entity[${currentTarget}].IsLockedTarget} && !${Entity[${currentTarget}].BeingTargeted}) || ${Entity[${currentTarget}].Distance} > ${droneEngageRange}
		{
			currentTarget:Set[0]
		}

		variable iterator lockedTargetIterator
		variable iterator activeJammerIterator
		Ship:BuildActiveJammerList

		if ${currentTarget} != 0
		{
			; Finalized decision
			variable bool finalized
			finalized:Set[FALSE]

			if ${FightOrFlight.IsEngagingGankers} && !${FightOrFlight.currentTarget.Equal[0]} && !${FightOrFlight.currentTarget.Equal[${currentTarget}]}
			{
				currentTarget:Set[${FightOrFlight.currentTarget}]
				This:LogInfo["Switching target to ganker \ar${Entity[${currentTarget}].Name}"]
				finalized:Set[TRUE]
			}

			if !${finalized} && ${Ship.ActiveJammerList.Used}
			{
				if !${Ship.ActiveJammerSet.Contains[${currentTarget}]}
				{
					; Being jammed but the jammer is not the current target
					Ship.ActiveJammerList:GetIterator[activeJammerIterator]
					do
					{
						if ${Entity[${activeJammerIterator.Value}].IsLockedTarget} && ${Entity[${activeJammerIterator.Value}].Distance} < ${droneEngageRange}
						{
							currentTarget:Set[${activeJammerIterator.Value}]
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
			; May switch target more than once so use this flag to avoid log spamming.
			variable bool switched
			if !${finalized} && !${Ship.IsHardToDealWithTarget[${currentTarget}]} && ${ActiveNPC.LockedTargetList.Used}
			{
				; Switch to difficult target for the ship
				switched:Set[FALSE]
				ActiveNPC.LockedTargetList:GetIterator[lockedTargetIterator]
				do
				{
					if ${Entity[${lockedTargetIterator.Value}].Distance} < ${droneEngageRange} && ${Ship.IsHardToDealWithTarget[${lockedTargetIterator.Value}]} && \
					(!${Ship.IsHardToDealWithTarget[${currentTarget}]} || ${Entity[${currentTarget}].Distance} > ${Entity[${lockedTargetIterator.Value}].Distance})
					{
						currentTarget:Set[${lockedTargetIterator.Value}]
						switched:Set[TRUE]
					}
				}
				while ${lockedTargetIterator:Next(exists)}
				if ${switched}
				{
					This:LogInfo["Switching to target skipped by ship: \ar${Entity[${currentTarget}].Name}"]
				}
			}
		}
		elseif ${FightOrFlight.IsEngagingGankers} && !${FightOrFlight.currentTarget.Equal[0]} && ${Entity[${FightOrFlight.currentTarget}](exists)}
		{
			currentTarget:Set[${FightOrFlight.currentTarget}]
			This:LogInfo["Engaging ganker \ar${Entity[${currentTarget}].Name}"]
		}
		elseif ${ActiveNPC.LockedTargetList.Used}
		{
			; Need to re-pick from locked target
			if ${Ship.ActiveJammerList.Used}
			{
				Ship.ActiveJammerList:GetIterator[activeJammerIterator]
				do
				{
					if ${Entity[${activeJammerIterator.Value}].IsLockedTarget} && ${Entity[${activeJammerIterator.Value}].Distance} < ${droneEngageRange}
					{
						currentTarget:Set[${activeJammerIterator.Value}]
						This:LogInfo["Targeting activate jammer \ar${Entity[${currentTarget}].Name}"]
						break
					}
				}
				while ${activeJammerIterator:Next(exists)}
			}

			if ${currentTarget} == 0
			{
				ActiveNPC.LockedTargetList:GetIterator[lockedTargetIterator]
				do
				{
					if ${Entity[${lockedTargetIterator.Value}].Distance} < ${droneEngageRange} && \
					(!${Entity[${currentTarget}](exists)} || \
					(!${Ship.IsHardToDealWithTarget[${currentTarget}]} && (${Ship.IsHardToDealWithTarget[${lockedTargetIterator.Value}]} || ${Entity[${currentTarget}].Distance} > ${Entity[${lockedTargetIterator.Value}].Distance})))
					{
						currentTarget:Set[${lockedTargetIterator.Value}]
					}
				}
				while ${lockedTargetIterator:Next(exists)}
			}

			if ${currentTarget} != 0
			{
				This:LogInfo["Primary target: \ar${Entity[${currentTarget}].Name}"]
			}
		}

		if ${currentTarget} != 0
		{
			if ${Drones.ActiveDroneCount["ToEntity.GroupID = GROUP_SCOUT_DRONE || ToEntity.GroupID = GROUP_COMBAT_DRONE"]} > 0 && \
			   ${Entity[${currentTarget}].Distance} < ${Me.DroneControlDistance}
			{
				; echo ${MaxDroneCount} drones engaging
				Drones:Engage["ToEntity.GroupID = GROUP_SCOUT_DRONE || ToEntity.GroupID = GROUP_COMBAT_DRONE", ${currentTarget}]
			}

			if ${MaxDroneCount} > ${Drones.ActiveDroneCount}
			{
				if ${Entity[${currentTarget}].Distance} > ${Me.DroneControlDistance}
				{
					Drones:Deploy["TypeID = ${Drones.Data.FindType[Fighters]}", ${Math.Calc[${MaxDroneCount} - ${Drones.ActiveDroneCount}]}]
				}
				elseif ${Entity[${currentTarget}].Distance} > (${Config.SentryRange} * 1000) && ${Config.Sentries}
				{
					Drones:Deploy["TypeID = ${Drones.Data.FindType[Sentry Drones]}", ${Math.Calc[${MaxDroneCount} - ${Drones.ActiveDroneCount}]}]
				}
				else
				{
					Drones:Deploy["TypeID = ${This.FindBestType[${Entity[${currentTarget}].GroupID}]}", ${Math.Calc[${MaxDroneCount} - ${Drones.ActiveDroneCount}]}]
				}
				IsBusy:Set[TRUE]
				Busy:SetBusy["DroneControl"]
			}

			Drones:RefreshActiveTypes
		}

		if ${currentTarget} == 0 && ${Drones.ActiveDroneCount["ToEntity.GroupID = GROUP_SCOUT_DRONE || ToEntity.GroupID = GROUP_COMBAT_DRONE"]} > 0
		{
			Drones:Recall["ToEntity.GroupID = GROUP_SCOUT_DRONE || ToEntity.GroupID = GROUP_COMBAT_DRONE"]
			This:QueueState["Idle", 5000]
			This:QueueState["DroneControl"]
			return TRUE
		}

		return FALSE
	}

}
