
objectdef obj_FightOrFlight inherits obj_StateQueue
{
	variable bool IsWarpScrambled = FALSE
	variable bool IsOtherPilotsDetected = FALSE
	variable bool IsAttackedByGankers = FALSE

	variable obj_TargetList PCs
	variable obj_TargetList NPCs
	variable collection:int AttackTimestamp

	method Initialize()
	{
		This[parent]:Initialize

		DynamicAddMiniMode("FightOrFlight", "FightOrFlight")
		This.PulseFrequency:Set[500]

		This:BuildPC
		NPCs:AddAllNPCs
	}

	method Log(string text)
	{
		Logger:Log["FightOrFlight", "${text.Escape}", "", LOG_STANDARD]
	}

	method LogDebug(string text)
	{
		Logger:Log["FightOrFlight", "${text.Escape}"]
	}

	method LogCritical(string text)
	{
		Logger:Log["FightOrFlight", "${text.Escape}", "", LOG_CRITICAL]
	}

	method Start()
	{
		AttackTimestamp:Clear

		if ${This.IsIdle}
		{
			This:Log["Started"]
			This:QueueState["FightOrFlight"]
		}
	}

	method BuildPC()
	{
		PCs:ClearQueryString
		PCs:AddPCTargetingMe
		PCs:AddAllPC
	}

	method DetectOtherPilots()
	{
		This:BuildPC
		PCs:RequestUpdate

		variable iterator pilotIterator
		PCs.TargetList:GetIterator[pilotIterator]
		variable bool detected = FALSE
		if ${pilotIterator:First(exists)}
		{
			do
			{
				; Oh it's me.
				if ${pilotIterator.Value.ID.Equal[${MyShip.ID}]} || ${pilotIterator.Value.Type.Equal["Capsule"]} || ${pilotIterator.Value.Type.Find["Shuttle"]} || ${pilotIterator.Value.Mode} == 3
				{
					continue
				}
				detected:Set[TRUE]
				This:LogDebug["Detected other pilot nearby: \ar ${pilotIterator.Value.Name} ${pilotIterator.Value.Type} ${pilotIterator.Value.IsTargetingMe} ${pilotIterator.Value.IsLockedTarget} ${pilotIterator.Value.ToAttacker.IsCurrentlyAttacking}"]

			}
			while ${pilotIterator:Next(exists)}
		}

		IsOtherPilotsDetected:Set[${detected}]
	}

	method DetectGankers()
	{
		variable index:attacker attackers
		variable iterator attackerIterator
		Me:GetAttackers[attackers]
		attackers:GetIterator[attackerIterator]
		variable bool detected = FALSE
		if ${attackerIterator:First(exists)}
		{
			do
			{
				if ${attackerIterator.Value.IsPC}
				{
					This:LogCritical["Being attacked by player: \ar${attackerIterator.Value.Name} in a ${attackerIterator.Value.Type}"]
					AttackTimestamp:Set[${attackerIterator.Value.Name}, ${This.EVETimestamp}]
					detected:Set[TRUE]
				}

			}
			while ${attackerIterator:Next(exists)}
		}

		IsAttackedByGankers:Set[${detected}]
	}

	; From either PC or NPC.
	method DetectWarpScrambleStatus()
	{
		variable index:jammer jammers
		variable iterator jammerIterator
		Me:GetJammers[jammers]
		jammers:GetIterator[jammerIterator]
		variable bool detected = FALSE
		if ${jammerIterator:First(exists)}
		{
			do
			{
				variable index:string jams
				variable iterator jamsIterator
				jammerIterator.Value:GetJams[jams]
				jams:GetIterator[jamsIterator]
				if ${jamsIterator:First(exists)}
				{
					do
					{
						; Either scramble or disrupt.
						if ${jamsIterator.Value.Lower.Find["warp"]}
						{
							detected:Set[TRUE]
							return
						}
					}
					while ${jamsIterator:Next(exists)}
				}
			}
			while ${jammerIterator:Next(exists)}
		}

		IsWarpScrambled:Set[${detected}]
	}

	member:bool FightOrFlight()
	{
		; Do not disturb manual operation.
		; if ${${Config.Common.Tehbot_Mode}.IsIdle}
		; {
		; 	; This:LogDebug["Bot is not running."]
		; 	return FALSE
		; }

		if ${Me.InStation} && !${This.LocalSafe}
		{
			This:Log["Detected many hostile pilots in local, wait until they are gone."]
			${Config.Common.Tehbot_Mode}:Stop
			Move:Stop
			This:QueueState["WaitTillLocalSafe"]
			This:QueueState["ResumeBot"]
			This:QueueState["FightOrFlight"]
			return TRUE
		}
		elseif ${Me.InStation}
		{
			return FALSE
		}

		; While currently jumping, Me.InSpace is false and status numbers will be null.
		if !${Me.InSpace}
		{
			This:LogDebug["Not in space, jumping?"]
			return FALSE
		}

		This:DetectOtherPilots
		if ${IsOtherPilotsDetected}
		{
			Mission.NPCs.AutoLock:Set[FALSE]
			Mission.ActiveNPCs.AutoLock:Set[FALSE]

			; When other players detected, lock PC and unlock other NPCs
			variable iterator npcIterator
			NPCs:AddAllNPCs
			NPCs:RequestUpdate
			NPCs.LockedTargetList:GetIterator[npcIterator]
			if ${npcIterator:First(exists)}
			{
				do
				{
					if ${npcIterator.Value.ID(exists)} && ${npcIterator.Value.IsNPC} && ${npcIterator.Value.IsLockedTarget}
					{
						This:LogDebug["Unlocking NPC ${npcIterator.Value.Name}."]
						Entity[${npcIterator.Value.ID}]:UnlockTarget
					}
				}
				while ${npcIterator:Next(exists)}
			}

			variable int MaxTarget = ${MyShip.MaxLockedTargets}
			if ${Me.MaxLockedTargets} < ${MyShip.MaxLockedTargets}
				MaxTarget:Set[${Me.MaxLockedTargets}]

			PCs.MinLockCount:Set[${MaxTarget}]
			PCs.AutoLock:Set[TRUE]

			This:DetectGankers
			; When attacked, enter Engage phase
			if ${IsAttackedByGankers}
			{
				This:LogDebug["Entering engage ganker stage."]
				; TODO
				return FALSE
			}
		}

		Mission.NPCs.AutoLock:Set[TRUE]
		Mission.ActiveNPCs.AutoLock:Set[TRUE]

		; Flee to a station in the system if not warpscrambled && (in egg or (low hp && not pvp fight) or module offline)
		; ${Me.ToEntity.IsWarpScrambled} is bugged.
		This:DetectWarpScrambleStatus
		if ${IsWarpScrambled}
		{
			This:LogDebug["IsWarpScrambled"]
			return FALSE
		}

		if ${MyShip.ToEntity.Type.Equal["Capsule"]}
		{
			This:Log["I am in egg, I should flee."]
			${Config.Common.Tehbot_Mode}:Stop
			Move:Stop
			DroneControl:Stop
			This:QueueState["FleeToStation"]
			This:QueueState["FightOrFlight"]
			return TRUE
		}
		elseif ${MyShip.ShieldPct.Int} < 0 || ${MyShip.ArmorPct.Int} < 50 || ${MyShip.StructurePct.Int} < 100
		{
			This:Log["PVE Low HP - Shield: ${MyShip.ShieldPct.Int}%, Armor: ${MyShip.ArmorPct.Int}%, Hull: ${MyShip.StructurePct.Int}%, I should flee."]
			${Config.Common.Tehbot_Mode}:Stop
			Move:Stop
			DroneControl:Stop
			This:QueueState["FleeToStation"]
			This:QueueState["Repair"]
			This:QueueState["LocalSafe"]
			This:QueueState["ResumeBot"]
			This:QueueState["FightOrFlight"]
			return TRUE
		}
		elseif !${Move.Traveling} && !${This.LocalSafe}
		{
			This:Log["Detected many red in local, I should flee."]
			${Config.Common.Tehbot_Mode}:Stop
			Move:Stop
			DroneControl:Stop
			This:QueueState["FleeToStation"]
			This:QueueState["Repair"]
			This:QueueState["LocalSafe"]
			This:QueueState["ResumeBot"]
			This:QueueState["FightOrFlight"]
			return TRUE
		}
		; TODO flee when module offline.(put online).

		return FALSE
	}

	member:int LocalHostilePilots()
	{
		return 5
	}

    ; Both a boolean member and a state.
	member:bool LocalSafe()
	{
		if ${This.LocalHostilePilots} < 7
		{
			return TRUE
		}
		return FALSE
	}

	member:bool Repair()
	{
		if ${Me.InStation}
		{
			if !${EVEWindow[RepairShop](exists)}
			{
				MyShip.ToItem:GetRepairQuote
				This:LogDebug["GetRepairQuote."]
				This:InsertState["Repair", 2000]
				return TRUE
			}
			else
			{
				if ${EVEWindow[byName, modal](exists)} && ${EVEWindow[byName, modal].Text.Find[Repairing these items]}
				{
					EVEWindow[byName, modal]:ClickButtonYes
					This:LogDebug["Repairing these items."]
					This:InsertState["Repair", 2000]
					return TRUE
				}
				if ${EVEWindow[byName,"Set Quantity"](exists)}
				{
					EVEWindow[byName,"Set Quantity"]:ClickButtonOK
					This:LogDebug["ClickButtonOK."]
					This:InsertState["Repair", 2000]
					return TRUE
				}
				if !${EVEWindow[RepairShop].TotalCost.Equal[0]}
				{
					EVEWindow[RepairShop]:RepairAll
					This:LogDebug["RepairAlls."]
					return FALSE
				}
			}
		}

		return TRUE
	}

	member:bool ResumeBot(bool Undock = FALSE)
	{
		This:Log["Resuming bot."]

		; To avoid going back to agent to reload ammos.
		if ${Undock}
		{
			Move:Undock
		}

		${Config.Common.Tehbot_Mode}:Start
        DroneControl:Start
		return TRUE
	}

	member:bool FleeToStation(bool waitForDrones = FALSE)
	{
		if ${Me.InStation}
		{
			Logger:Log["Dock called, but we're already instation!"]
			return TRUE
		}

		if ${Ship.ModuleList_Siege.ActiveCount}
		{
			Ship.ModuleList_Siege:DeactivateAll
		}

		if ${DroneControl.ActiveDrones.Used} > 0
		{
			DroneControl:Recall
			if ${waitForDrones}
			{
				return FALSE
			}
		}

		variable int64 StationID
		StationID:Set[${Entity["CategoryID = CATEGORYID_STATION"].ID}]
		if ${Entity[${StationID}](exists)}
		{
			This:Log["Fleeing to station ${Entity[${StationID}].Name}."]
			Move.Traveling:Set[FALSE]
			Move:Entity[${StationID}]
			This:InsertState["Traveling"]
			return TRUE
		}
		else
		{
			Logger:Log["No stations in this system!", LOG_CRITICAL]
			return TRUE
		}
	}

	member:bool Traveling()
	{
		; This:LogDebug["Traveling."]
		if ${Cargo.Processing} || ${Move.Traveling} || ${Me.ToEntity.Mode} == 3
		{
			if ${Me.InSpace}
			{
				if ${Ship.ModuleList_Siege.ActiveCount}
				{
					Ship.ModuleList_Siege:DeactivateAll
				}

				if ${Ship.ModuleList_Regen_Shield.InactiveCount} && (${MyShip.ShieldPct.Int} < 100 && ${MyShip.CapacitorPct.Int} > 15)
				{
					Ship.ModuleList_Regen_Shield:ActivateAll
				}
				if ${Ship.ModuleList_Regen_Shield.ActiveCount} && (${MyShip.ShieldPct.Int} == 100 || ${MyShip.CapacitorPct.Int} < 15) /* Deactivate to prevent hardener off */
				{
					Ship.ModuleList_Regen_Shield:DeactivateAll
				}
				if ${Ship.ModuleList_Repair_Armor.InactiveCount} && (${MyShip.ArmorPct.Int} < 100 && ${MyShip.CapacitorPct.Int} > 15)
				{
					Ship.ModuleList_Repair_Armor:ActivateAll
				}
				if ${Ship.ModuleList_Repair_Armor.ActiveCount} && (${MyShip.ArmorPct.Int} == 100 || ${MyShip.CapacitorPct.Int} < 15) /* Deactivate to prevent hardener off */
				{
					Ship.ModuleList_Repair_Armor:DeactivateAll
				}
			}

			return FALSE
		}

		return TRUE
	}

	member:int EVETimestamp()
	{
		variable string text = ${EVETime.DateAndTime}
		variable string dataText = ${text.Token[1, " "]}
		variable string timeText = ${text.Token[2, " "]}

		variable int year = ${dataText.Token[1, "."]}
		variable int month = ${dataText.Token[2, "."]}
		variable int day = ${dataText.Token[3, "."]}
		variable int hour = ${timeText.Token[1, ":"]}
		variable int minute = ${timeText.Token[2, ":"]}

		variable time timeObj
		timeObj.YearPtr:Set[${Math.Calc[${year} - 1900]}]
		timeObj.MonthPtr:Set[${Math.Calc[${month} - 1]}]
		timeObj.Day:Set[${day}]
		timeObj.Hour:Set[${hour}]
		timeObj.Minute:Set[${minute}]
		; timeObj.Hour:Dec[${delayHours}]
		timeObj:Update
		return ${timeObj.Timestamp.Signed}
	}
}