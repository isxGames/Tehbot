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
		This.CommonRef:AddSetting[LockCount, 2]
		This.CommonRef:AddSetting[UseIPC, TRUE]
		This.CommonRef:AddSetting[Aggressive, FALSE]
	}

	Setting(bool, Sentries, SetSentries)
	Setting(int, SentryRange, SetSentryRange)
	Setting(int, MaxDroneCount, SetDroneCount)
	Setting(int, LockCount, SetLockCount)
	Setting(bool, UseIPC, SetUseIPC)
	Setting(bool, Aggressive, SetAggressive)
}

objectdef obj_DroneControl inherits obj_StateQueue
{
	variable obj_TargetList DroneTargets
	variable obj_Configuration_DroneControl Config
	variable int64 CurrentTarget = -1
	variable bool IsBusy

	variable bool CurAggressive
	variable bool CurIPC

	variable bool RecallActive=FALSE

	method Initialize()
	{
		This[parent]:Initialize
		PulseFrequency:Set[1500]
		DynamicAddMiniMode("DroneControl", "DroneControl")
	}

	method SetAggressiveState()
	{
		variable iterator classIterator
		variable iterator groupIterator
		variable string groups = ""
		variable string seperator = ""

		DroneTargets:ClearQueryString

		if ${Config.Aggressive}
		{
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
			DroneTargets:AddQueryString["Distance < 20000 && IsNPC && !IsMoribund && (${groups})"]

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
			DroneTargets:AddQueryString["Distance < 20000 && IsNPC && !IsMoribund && (${groups}) && (Group =- \"Frigate\" || Group =- \"Destroyer\")"]

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
			DroneTargets:AddQueryString["Distance < 20000 && IsNPC && !IsMoribund && (${groups}) && (Group =- \"Frigate\" || Group =- \"Destroyer\")"]


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
					DroneTargets:AddQueryString["Distance < 20000 && IsNPC && !IsMoribund && (${groups}) && (Group =- \"Frigate\" || Group =- \"Destroyer\" || GroupID = 806)"]
				}
				while ${classIterator:Next(exists)}
			}
			DroneTargets:AddQueryString["Distance < 20000 && IsTargetingMe && IsNPC && !IsMoribund && (Group =- \"Frigate\" || Group =- \"Destroyer\" || GroupID = 806)"]
		}
		else
		{
			DroneTargets:AddQueryString["Distance < 20000 && IsTargetingMe && IsNPC && !IsMoribund && (Group =- \"Frigate\" || Group =- \"Destroyer\" || GroupID = 806)"]
		}
		CurAggressive:Set[${Config.Aggressive}]

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
		return ${Drones.ActiveDroneCount["(ToEntity.GroupID = 100 || ToEntity.GroupID == 549) && (${types})"]}
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
		Drones:Recall["(ToEntity.GroupID = 100 || ToEntity.GroupID == 549) && (${types})", ${Drones.ActiveDroneCount["ToEntity.GroupID == 100 && (${types})"]}]
	}

	method Start()
	{
		DroneTargets.MaxRange:Set[20000]
		DroneTargets.MinLockCount:Set[${Config.LockCount}]
		This:SetAggressiveState[]
		DroneTargets.AutoLock:Set[TRUE]
		This:QueueState["DroneControl"]
	}

	method Stop()
	{
		DroneTargets.AutoLock:Set[FALSE]
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

	member:bool DroneControl()
	{
		variable index:activedrone ActiveDrones
		variable iterator DroneIterator
		variable float CurrentDroneHealth
		variable iterator DroneTypesIter
		variable int MaxDroneCount = ${Config.MaxDroneCount}
		if ${MaxDroneCount} > ${Me.MaxActiveDrones}
		{
			MaxDroneCount:Set[${Me.MaxActiveDrones}]
		}

		DroneTargets.MinLockCount:Set[${Config.LockCount}]
		variable iterator TargetIterator

		if !${Client.InSpace}
		{
			return FALSE
		}

		if ${Me.ToEntity.Mode} == 3
		{
			if ${Drones.ActiveCount["ToEntity.GroupID == 100 || ToEntity.GroupID == 549"]} > 0
			{
				Drones:Recall["ToEntity.GroupID = 100 || ToEntity.GroupID == 549"]
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

		if ${CurAggressive} != ${Config.Aggressive}
		{
			This:SetAggressiveState[]
		}

		Me:GetActiveDrones[ActiveDrones]
		ActiveDrones:GetIterator[DroneIterator]
		if ${DroneIterator:First(exists)}
		{
			do
			{
				CurrentDroneHealth:Set[${Math.Calc[${DroneIterator.Value.ToEntity.ShieldPct} + ${DroneIterator.Value.ToEntity.ArmorPct} + ${DroneIterator.Value.ToEntity.StructurePct}]}]
				if ${Drones.DroneHealth.Element[${DroneIterator.Value.ID}]} && ${CurrentDroneHealth} < ${Drones.DroneHealth.Element[${DroneIterator.Value.ID}]}
				{
					; echo recalling ID ${DroneIterator.Value.ID}
					Drones:Recall["ID = ${DroneIterator.Value.ID}", 1]
					Drones.ReturningDrones:Add[${DroneIterator.Value.ID}]
				}
				Drones.DroneHealth:Set[${DroneIterator.Value.ID}, ${CurrentDroneHealth}]
				; echo drone refreshed cached health ${Drones.DroneHealth.Element[${DroneIterator.Value.ID}]}
			}
			while ${DroneIterator:Next(exists)}
		}

		DroneTargets:RequestUpdate
		DroneTargets.LockedAndLockingTargetList:GetIterator[TargetIterator]

		if !${Entity[${CurrentTarget}](exists)} || (!${Entity[${CurrentTarget}].IsLockedTarget} && !${Entity[${CurrentTarget}].BeingTargeted}) || ${Entity[${CurrentTarget}].Distance} > 300000
		{
			CurrentTarget:Set[-1]
		}
		else
		{
			if ${Drones.ActiveDroneCount["ToEntity.GroupID == 100 || ToEntity.GroupID == 549"]} > 0 &&\
					${Entity[${CurrentTarget}].Distance} < ${Me.DroneControlDistance}
			{
				Drones:Engage["ToEntity.GroupID == 100 || ToEntity.GroupID == 549", ${CurrentTarget}, ${MaxDroneCount}]
			}

			if ${MaxDroneCount} > ${Drones.ActiveDroneCount}
			{
				if ${Entity[${CurrentTarget}].Distance} > ${Me.DroneControlDistance}
				{
					Drones:Deploy["TypeID = ${Drones.Data.FindType[Fighters]}", ${Math.Calc[${MaxDroneCount} - ${Drones.ActiveDroneCount}]}]
				}
				elseif ${Entity[${CurrentTarget}].Distance} > (${Config.SentryRange} * 1000) && ${Config.Sentries}
				{
					Drones:Deploy["TypeID = ${Drones.Data.FindType[Sentry Drones]}", ${Math.Calc[${MaxDroneCount} - ${Drones.ActiveDroneCount}]}]
				}
				else
				{
					; echo Drones:Deploy["TypeID = ${This.FindBestType[${Entity[${CurrentTarget}].GroupID}]}", ${Math.Calc[${MaxDroneCount} - ${Drones.ActiveDroneCount}]}]
					Drones:Deploy["TypeID = ${This.FindBestType[${Entity[${CurrentTarget}].GroupID}]}", ${Math.Calc[${MaxDroneCount} - ${Drones.ActiveDroneCount}]}]
				}
				IsBusy:Set[TRUE]
				Busy:SetBusy["DroneControl"]
			}

			Drones:RefreshActiveTypes
			; Drones:RefreshDroneHealthCache
		}

		if ${TargetIterator:First(exists)}
		{
			do
			{
				if ${CurrentTarget.Equal[-1]} && ${TargetIterator.Value(exists)}
				{
					UI:Update["DroneControl", "Primary target: \ar${TargetIterator.Value.Name}", "g"]
					CurrentTarget:Set[${TargetIterator.Value.ID}]
					break
				}
			}
			while ${TargetIterator:Next(exists)}
		}
		else
		{
			if ${Drones.ActiveDroneCount["ToEntity.GroupID = 100 || ToEntity.GroupID == 549"]} > 0
			{
				Drones:Recall["ToEntity.GroupID = 100 || ToEntity.GroupID == 549"]
				This:QueueState["Idle", 5000]
				This:QueueState["DroneControl"]
				return TRUE
			}
		}
		return FALSE
	}

}
