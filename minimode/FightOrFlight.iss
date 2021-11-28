
objectdef obj_FightOrFlight inherits obj_StateQueue
{
	variable bool IsWarpScrambled = FALSE
	variable bool IsOtherPilotsDetected = FALSE
	variable bool IsAttackedByGankers = FALSE
	variable bool IsEngagingGankers = FALSE

	variable obj_TargetList PCs
	variable obj_TargetList NPCs
	variable collection:int AttackTimestamp
	variable int64 currentTarget = 0

	method Initialize()
	{
		This[parent]:Initialize

		DynamicAddMiniMode("FightOrFlight", "FightOrFlight")
		This.PulseFrequency:Set[500]

		This:BuildPC
		NPCs:AddAllNPCs
	}

	method Start()
	{
		AttackTimestamp:Clear

		if ${This.IsIdle}
		{
			This:LogInfo["Starting"]
			This:QueueState["FightOrFlight"]
		}
	}

	method BuildPC()
	{
		PCs:ClearQueryString
		PCs:AddPCTargetingMe
		PCs:AddAllPC
	}

	method DetectOtherPilots(int threshold)
	{
		This:BuildPC
		PCs:RequestUpdate

		variable iterator pilotIterator
		PCs.TargetList:GetIterator[pilotIterator]
		variable int detected = 0
		; This:LogDebug[${threshold} total ${PCs.TargetList.Used}]
		if ${pilotIterator:First(exists)}
		{
			do
			{
				; Oh it's me.
				if ${pilotIterator.Value.ID.Equal[${MyShip.ID}]} || ${pilotIterator.Value.Mode} == 3
				{
					continue
				}

				; Lock and destroy everything only in vigilant mode.
				if (${threshold} > 1) && (${pilotIterator.Value.Type.Equal["Capsule"]} || ${pilotIterator.Value.Type.Find["Shuttle"]})
				{
					; This:LogDebug[${threshold} skipping ${pilotIterator.Value.Type}]
					continue
				}

				detected:Inc[1]
				; This:LogDebug["${detected} - ${pilotIterator.Value.Name} - ${pilotIterator.Value.Type} - ${pilotIterator.Value.IsTargetingMe} - ${pilotIterator.Value.IsLockedTarget} - ${pilotIterator.Value.ToAttacker.IsCurrentlyAttacking}"]

			}
			while ${pilotIterator:Next(exists)}
		}

		if ${detected} >= ${threshold}
		{
			This:LogDebug["Detected ${detected} other pilot nearby."]
		}

		if ${detected} >= ${threshold}
		{
			IsOtherPilotsDetected:Set[TRUE]
		}
		else
		{
			IsOtherPilotsDetected:Set[FALSE]
		}
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

					; if ${AttackTimestamp.Element[${attackerIterator.Value.Name.Escape}](exists)}
					; {
					; 	variable int lastAttackTimestamp
					; 	lastAttackTimestamp:Set[${AttackTimestamp.Element[${attackerIterator.Value.Name.Escape}]}]
					; 	This:LogDebug["lastattacktimestamp ${lastAttackTimestamp}"]
					; 	variable int secondsSinceAttacked
					; 	secondsSinceAttacked:Set[${Math.Calc[${Utility.EVETimestamp} - ${lastAttackTimestamp}]}]
					; 	This:LogDebug["secondsSinceAttacked ${secondsSinceAttacked}"]
					; }

					AttackTimestamp:Set[${attackerIterator.Value.Name.Escape}, ${Utility.EVETimestamp}]
					This:LogDebug["Update attack timer ${attackerIterator.Value.Name.Escape} -- ${Utility.EVETimestamp}"]
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
		if ${${Config.Common.Tehbot_Mode}.IsIdle}
		{
			; This:LogDebug["Bot is not running."]
			return FALSE
		}

		IsEngagingGankers:Set[FALSE]

		if ${Me.InStation} && !${This.LocalSafe}
		{
			This:LogInfo["Detected many hostile pilots in local, wait until they are gone."]
			${Config.Common.Tehbot_Mode}:Stop
			Move:Stop
			This:QueueState["LocalSafe"]
			This:QueueState["ResumeBot"]
			This:QueueState["FightOrFlight"]
			return TRUE
		}
		elseif ${Me.InStation}
		{
			return FALSE
		}

		; While currently jumping, Me.InSpace is false and status numbers will be null.
		if !${Client.InSpace}
		{
			This:LogDebug["Not in space, jumping?"]
			return FALSE
		}

		This:DetectGankers
		; When attacked, enter Engage phase
		if ${IsAttackedByGankers}
		{
			This:LogCritical["Entering engage ganker stage."]
			Ship.ModuleList_Siege:ActivateOne
			This:QueueState["EngageGankers"]
			return TRUE
		}

		This:DetectOtherPilots[3]
		if ${IsOtherPilotsDetected}
		{
			This:UnlockNPCsAndLockPCs
		}
		else
		{
			Mission.NPCs.AutoLock:Set[TRUE]
			Mission.ActiveNPCs.AutoLock:Set[TRUE]
		}

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
			This:LogInfo["I am in egg, I should flee."]
			${Config.Common.Tehbot_Mode}:Stop
			Move:Stop
			DroneControl:Stop
			This:QueueState["FleeToStation"]
			This:QueueState["FightOrFlight"]
			return TRUE
		}
		elseif ${MyShip.ShieldPct.Int} < 0 || ${MyShip.ArmorPct.Int} < 50 || ${MyShip.StructurePct.Int} < 100  || ${MyShip.CapacitorPct.Int} < 5
		{
			; TODO align and 75% speed before entering flee status, in case last second.
			This:LogInfo["PVE Low HP - Shield: ${MyShip.ShieldPct.Int}%, Armor: ${MyShip.ArmorPct.Int}%, Hull: ${MyShip.StructurePct.Int}%, Capacitor: ${MyShip.CapacitorPct.Int}%, I should flee."]
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
			This:LogInfo["Detected many red in local, I should flee."]
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

	member:bool EngageGankers()
	{
		if ${Me.InStation}
		{
			; Pod killed.
			This:LogCritical["Pod killed."]
			IsEngagingGankers:Set[FALSE]
			This:QueueState["FightOrFlight"]
			return TRUE
		}

		if !${Client.Inspace}
		{
			; Ship Destroyed?
			FALSE
		}

		IsEngagingGankers:Set[TRUE]

		${Config.Common.Tehbot_Mode}:Stop

		This:DetectWarpScrambleStatus
		if ${IsWarpScrambled}
		{
			This:LogDebug["WarpScrambled by gankers."]
		}

		if !${IsWarpScrambled} && ${MyShip.ToEntity.Type.Equal["Capsule"]}
		{
			This:LogInfo["I am in egg, I should flee."]
			This:QueueState["FleeToStation"]
			This:QueueState["FightOrFlight"]
			return TRUE
		}

		; if !${MyShip.ToEntity.Type.Equal["Capsule"]} && Findmywreck
		; {
		; 	Destroy my wreck
		; 	Then warpoff
		;	TODO add detection in Traveling status when
		;			scrambled when ships shows aligned but not really in warp.
		; 	and do something.
		; }

		This:UnlockNPCsAndLockPCs

		Ship.ModuleList_Siege:ActivateOne

		This:DetectGankers
		;;;;;;;;;;;;;;;;;;;;PickTarget;;;;;;;;;;;;;;;;;;;;
		if !${Entity[${currentTarget}]} || ${Entity[${currentTarget}].IsMoribund} || !(${Entity[${currentTarget}].IsLockedTarget} || ${Entity[${currentTarget}].BeingTargeted})
		{
			currentTarget:Set[0]
		}

		variable iterator lockedTargetIterator
		variable iterator activeNeuterIterator
		Ship:BuildActiveNeuterList

		if ${currentTarget} != 0
		{
			if ${Ship.ActiveNeuterList.Used}
			{
				if !${Ship.ActiveNeuterSet.Contains[${currentTarget}]}
				{
					; The only jammer we want to priortize is energy neutralizer.
					Ship.ActiveNeuterList:GetIterator[activeNeuterIterator]
					do
					{
						if ${Entity[${activeNeuterIterator.Value}].IsLockedTarget}
						{
							currentTarget:Set[${activeNeuterIterator.Value}]
							This:LogInfo["Switching target to active neutralizer \ar${Entity[${currentTarget}].Name}"]
							break
						}
					}
					while ${activeNeuterIterator:Next(exists)}
				}
			}
		}
		elseif ${PCs.LockedTargetList.Used}
		{
			; Need to re-pick from locked target
			if ${Ship.ActiveNeuterList.Used}
			{
				Ship.ActiveNeuterList:GetIterator[activeNeuterIterator]
				do
				{
					if ${Entity[${activeNeuterIterator.Value}].IsLockedTarget}
					{
						currentTarget:Set[${activeNeuterIterator.Value}]
						This:LogInfo["Targeting active neutralizer \ar${Entity[${currentTarget}].Name}"]
						break
					}
				}
				while ${activeNeuterIterator:Next(exists)}
			}

			if ${currentTarget} == 0
			{
				; Priortize the slowest target which is not capsule.
				variable int64 CapsuleTarget = 0
				PCs.LockedTargetList:GetIterator[lockedTargetIterator]
				do
				{
					variable int lastAttackTimestamp
					lastAttackTimestamp:Set[${AttackTimestamp.Element[${lockedTargetIterator.Value.Name.Escape}]}]
					variable int secondsSinceAttacked
					secondsSinceAttacked:Set[${Math.Calc[${Utility.EVETimestamp} - ${lastAttackTimestamp}]}]
					This:LogDebug["Seconds since attacker last attacked: \ar${secondsSinceAttacked}"]
					if ${secondsSinceAttacked} >= 300
					{
						continue
					}

					if ${lockedTargetIterator.Value.Type.Equal["Capsule"]}
					{
						CapsuleTarget:Set[${lockedTargetIterator.Value}]
					}
					elseif ${currentTarget} == 0 || ${Entity[${currentTarget}].Velocity} > ${Entity[${lockedTargetIterator.Value}].Velocity}
					{
						currentTarget:Set[${lockedTargetIterator.Value}]
					}
				}
				while ${lockedTargetIterator:Next(exists)}

				if ${currentTarget} == 0
				{
					currentTarget:Set[${CapsuleTarget}]
				}
			}
			This:LogInfo["Primary target: \ar${Entity[${currentTarget}].Name}"]
		}

		;;;;;;;;;;;;;;;;;;;;Shoot;;;;;;;;;;;;;;;;;;;;;
		if ${currentTarget} != 0 && ${Entity[${currentTarget}]} && !${Entity[${currentTarget}].IsMoribund}
		{
			Ship.ModuleList_Siege:ActivateOne
			if ${Ship.ModuleList_Weapon.Range} > ${Entity[${currentTarget}].Distance}
			{
				; This:LogDebug["Pew Pew: \ar${Entity[${currentTarget}].Name}"]
				Ship.ModuleList_Weapon:ActivateAll[${currentTarget}]
				Ship.ModuleList_TrackingComputer:ActivateAll[${currentTarget}]
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

		This:DetectOtherPilots[1]
		if ${IsOtherPilotsDetected}
		{
			; Remain vigilant once entered engage stage.
			return FALSE
		}

		; There is a short time after ship destruction that pod is not detected, we may overlook the
		; last pod. detect twice to avoid this. (No big deal anyway)
		Client:Wait[1000]
		This:DetectOtherPilots[1]
		if ${IsOtherPilotsDetected}
		{
			return FALSE
		}

		${Config.Common.Tehbot_Mode}:Start
		This:QueueState["FightOrFlight"]
		IsEngagingGankers:Set[FALSE]
		return TRUE
	}

	member:int LocalHostilePilots()
	{
		variable index:pilot pilotIndex
		EVE:GetLocalPilots[pilotIndex]

		if ${pilotIndex.Used} < 2
		{
			return 0
		}

		variable int count = 0
		variable iterator pilotIterator
		pilotIndex:GetIterator[pilotIterator]

		if ${pilotIterator:First(exists)}
		{
			do
			{
				if ${Me.CharID} == ${pilotIterator.Value.CharID} || ${pilotIterator.Value.ToFleetMember(exists)}
				{
					continue
				}
				; echo ${pilotIterator.Value.Name} ${pilotIterator.Value.CharID} ${pilotIterator.Value.Corp.ID} ${pilotIterator.Value.AllianceID}
				; echo ${pilotIterator.Value.Standing.MeToPilot}
				; echo ${pilotIterator.Value.Standing.MeToCorp}
				; echo ${pilotIterator.Value.Standing.MeToAlliance}
				if ${pilotIterator.Value.Standing.MeToPilot} < 0 || ${pilotIterator.Value.Standing.MeToCorp} < 0 || ${pilotIterator.Value.Standing.MeToAlliance}
				{
					count:Inc[1]
				}
			}
			while ${pilotIterator:Next(exists)}

		}

		return ${count}
	}

    ; Both a boolean member and a state.
	member:bool LocalSafe()
	{
		if ${This.LocalHostilePilots} < 8
		{
			return TRUE
		}
		return FALSE
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

	member:bool ResumeBot(bool Undock = FALSE)
	{
		This:LogInfo["Resuming bot."]

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
			This:LogInfo["Fleeing to station ${Entity[${StationID}].Name}."]
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

	method UnlockNPCsAndLockPCs()
	{
		Mission.NPCs.AutoLock:Set[FALSE]
		Mission.ActiveNPCs.AutoLock:Set[FALSE]

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

		variable int MaxTarget
		MaxTarget:Set[${MyShip.MaxLockedTargets}]
		if ${Me.MaxLockedTargets} < ${MyShip.MaxLockedTargets}
			MaxTarget:Set[${Me.MaxLockedTargets}]

		This:BuildPC
		PCs:RequestUpdate
		PCs.MinLockCount:Set[${MaxTarget}]
		PCs.AutoLock:Set[TRUE]
	}
}