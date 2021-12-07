objectdef obj_Module inherits obj_StateQueue
{
	variable int Instruction = INSTRUCTION_NONE
	variable int64 InstructionTargetID = TARGET_NA
	variable int64 ModuleID

	variable string Ammo
	variable string LongRangeAmmo

	variable int _lastDeactivationTimestamp
	variable int _deactivationRetryInterval = 1000
	variable int _lastChangeAmmoTimestamp
	variable int _changeAmmoRetryInterval = 1000
	; TODO: Switch ammo when grouped laser weapon is taking too long to activate, may be caused by crystal burnt out.
	variable int _lastActivationTimestamp
	variable int _activationRetryInterval = 1000

	; TODO actually the intervals above are not needed anymore after _tooSoon() is introduced.
	variable int _intervalBetweenOperations = 1000

	method Initialize(int64 ID)
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]
		ModuleID:Set[${ID}]
		PulseFrequency:Set[100]
	 	RandomDelta:Set[100]
		LogModuleName:Set["${This.Name}"]

		This.LogLevelBar:Set[${Config.Common.LogLevelBar}]

		This:LogInfo["Initialize module ${ModuleID} ${This.Name}"]
		This:LogDebug["Test GetFallthroughObject pass: ${This._testGetFallthroughObject}"]
		This:Clear
		This:QueueState["Operate"]
	}

	member:string GetFallthroughObject()
	{
		return "MyShip.Module[${ModuleID}]"
	}

;;;;;;;;;;single state
	member:bool Operate()
	{
		if !${Me.InSpace}
		{
			This:_resetState
			return FALSE
		}

		if !${This.IsActivatable} || \
			!${This.IsOnline} || \
			${This.IsBeingRepaired} || \
			${This.IsReloading} || \
			${This.IsDeactivating} || \
			${Instruction.Equal[INSTRUCTION_NONE]} || \
			${This._tooSoon}
		{
			return FALSE
		}

		switch ${Instruction}
		{
			case INSTRUCTION_ACTIVATE_ON
				This:OperateActivateOn[${InstructionTargetID}]
				break
			case INSTRUCTION_DEACTIVATE
				This:OperateDeactivate
				break
			case INSTRUCTION_LOAD_AMMO
				break
		}

		return FALSE
	}

;;;;;;;;;;public interface
	member:bool IsModuleActiveOn(int64 targetID)
	{
		if ${This.IsActive} && ${This._targetMatch[${This.TargetID}, ${targetID}]}
		{
			return TRUE
		}

		return FALSE
	}

	; "Soon gonna do" status
	member:bool IsInstructionMatch(int newInstruction, int64 targetID = TARGET_NA)
	{
		if ${newInstruction} != ${Instruction}
		{
			return FALSE
		}

		return ${This._targetMatch[${InstructionTargetID}, ${targetID}]}
	}

	method GiveInstruction(int instruction, int64 targetID = TARGET_NA)
	{
		if !${This.IsActivatable} || \
			!${This.IsOnline} || \
			${This.IsBeingRepaired}
		{
			return
		}

		if ${This.IsInstructionMatch[${instruction}, ${targetID}]}
		{
			return
		}

		; Update instruction
		Instruction:Set[${instruction}]
		InstructionTargetID:Set[${targetID}]

		if ${This._tooSoon}
		{
			This:Clear
			This:QueueState["Operate", ${_intervalBetweenOperations}]
		}

		This:_resetTimers
	}

	method ConfigureAmmo(string shortRangeAmmo, string longRangeAmmo)
	{
		This:LogDebug["${This.Name} configured ammo as ${shortRangeAmmo} + ${longRangeAmmo}"]
		Ammo:Set[${shortRangeAmmo}]
		LongRangeAmmo:Set[${longRangeAmmo}]
	}

	; Deactivate module when target doesn't match or need to change ammo, then activate it on specified target.
	; Instruction is erased when the target is destroyed.
	method OperateActivateOn(int64 targetID)
	{
		if (${targetID} != TARGET_NA) && \
			!(${Entity[${targetID}](exists)} && !${Entity[${targetID}].IsMoribund} && ${Entity[${targetID}].IsLockedTarget})
		{
			This:LogDebug["${This.Name} reset state for target is invalid"]
			This:_resetState
			return
		}

		variable string optimalAmmo
		if ${This.IsActive}
		{
			if !${This._targetMatch[${This.TargetID}, ${targetID}]}
			{
				This:LogDebug["Deactivating ${This.Name} to switch target, current Target ${This.TargetID} ${Entity[${This.TargetID}].Name} new target ${targetID} ${Entity[${targetID}].Name}."]
				This:_deactivate
				return
			}
			; target already match

			if ${targetID} != TARGET_NA
			{
				optimalAmmo:Set[${This._pickOptimalAmmo[${targetID}]}]
				if ${optimalAmmo.NotNULLOrEmpty} && !${optimalAmmo.Equal[${This.Charge.Type}]}
				{
					This:LogDebug["${This.Name} optimalAmmo is ${optimalAmmo} for ${Entity[${targetID}].Name} distance ${Entity[${targetID}].Distance}"]
					This:LogDebug["Deactivating ${This.Name} to change ammo to ${optimalAmmo}."]
					This:_deactivate
					return
				}
			}
			; ammo already match

			; Finished
			This:_resetTimers
			return
		}
		else
		{
			_lastDeactivationTimestamp:Set[0]

			optimalAmmo:Set[${This._pickOptimalAmmo[${targetID}]}]
			if ${optimalAmmo.NotNULLOrEmpty} && !${optimalAmmo.Equal[${This.Charge.Type}]}
			{
				This:_findAndChangeAmmo[${optimalAmmo}]
				return
			}
			else
			{
				_lastChangeAmmoTimestamp:Set[0]

				if (${targetID} == TARGET_NA) || \
					(${Entity[${targetID}]} && !${Entity[${targetID}].IsMoribund} && ${Entity[${targetID}].IsLockedTarget})
				{
					This:_activate[${targetID}]
				}
				else
				{
					This:LogDebug["${This.Name} reset state for target is gone"]
					This:_resetState
				}
				return
			}
		}
	}

	; Load the optimal ammo and activate module,
	; Instruction is kept forever.
	; Used with tracking computers, guidance computers, etc.
	; The difference from OperateActivateOn is that it won't deactivate module just because target changed.
	; TODO: Add unload script path when the ISXEVE api is fixed.
	method OperateActivateFor(int64 targetID)
	{
		variable string optimalAmmo
		if ${This.IsActive}
		{
			optimalAmmo:Set[${This._pickOptimalAmmo[${targetID}]}]
			if ${optimalAmmo.NotNULLOrEmpty} && !${optimalAmmo.Equal[${This.Charge.Type}]}
			{
				This:LogInfo["Deactivating ${This.Name} to change ammo."]
				This:_deactivate
				return
			}
			; ammo already match

			; Finished
			This:_resetTimers
			return
		}
		else
		{
			_lastDeactivationTimestamp:Set[0]

			optimalAmmo:Set[${This._pickOptimalAmmo[${targetID}]}]
			if ${optimalAmmo.NotNULLOrEmpty} && !${optimalAmmo.Equal[${This.Charge.Type}]}
			{
				This:_findAndChangeAmmo[${optimalAmmo}]
				return
			}
			else
			{
				; ammo already match
				_lastChangeAmmoTimestamp:Set[0]

				This:_activate[TARGET_NA]
				return
			}
		}
	}

	; Deactivate module.
	; Instruction is erased after module is turned off.
	method OperateDeactivate()
	{
		variable string optimalAmmo
		if ${This.IsActive}
		{
			This:_deactivate
			return
		}
		else
		{
			; Finished
			This:_resetState
			return
		}
	}

	method OperateLoadAmmo()
	{
		; TODO
	}

;;;;;;;;;;private

	member:bool _testGetFallthroughObject()
	{
		; ${This.Duration} is NULL for weapons.
		; ${This.LastTarget} ${This.TargetID} are NULL until target exists.
		if ${This.Name.NotNULLOrEmpty} && \
			${This.IsReloading(type).Name.Equal[bool]} && \
			${This.IsOnline(type).Name.Equal[bool]} && \
			${This.IsGoingOnline(type).Name.Equal[bool]} && \
			${This.IsDeactivating(type).Name.Equal[bool]} && \
			${This.IsActivatable(type).Name.Equal[bool]} && \
			${This.IsAutoReloadOn(type).Name.Equal[bool]} && \
			${This.AutoRepeat(type).Name.Equal[bool]} && \
			${This.IsActive(type).Name.Equal[bool]} && \
			${This.HP(type).Name.Equal[float64]} && \
			${This.Damage(type).Name.Equal[float64]}
		{
			return TRUE
		}
		return FALSE
	}

	method _resetState()
	{
		Instruction:Set[INSTRUCTION_NONE]
		InstructionTargetID:Set[TARGET_NA]
		This:_resetTimers
	}

	method _resetTimers()
	{
		_lastDeactivationTimestamp:Set[0]
		_lastChangeAmmoTimestamp:Set[0]
		_lastActivationTimestamp:Set[0]
	}

	; A bug will cause the module get stuck if interval between commands is too small.
	member:bool _tooSoon()
	{
		if (${Math.Calc[${LavishScript.RunningTime} - ${_lastActivationTimestamp}]} <= ${_intervalBetweenOperations}) || \
			(${Math.Calc[${LavishScript.RunningTime} - ${_lastChangeAmmoTimestamp}]} <= ${_intervalBetweenOperations}) || \
			(${Math.Calc[${LavishScript.RunningTime} - ${_lastDeactivationTimestamp}]} <= ${_intervalBetweenOperations})
		{
			return TRUE
		}

		return FALSE
	}

	member:bool _targetMatch(int64 currentTargetID, int64 newTargetID)
	{
		; NULL are treated as 0.

		; variable bool nullIsFALSE
		; nullIsFALSE:Set[!${This.TargetID}]

		; variable bool nullEqualsZero = FALSE
		; if ${This.TargetID} == 0
		; nullEqualsZero:Set[TRUE]

		; Validated both true

		; This:LogInfo[current target id ${currentTargetID} new target id ${newTargetID} equal NA ${newTargetID.Equal[TARGET_NA]}]
		if ${newTargetID.Equal[TARGET_ANY]}
		{
			return TRUE
		}

		if ${newTargetID.Equal[${currentTargetID}]}
		{
			return TRUE
		}

		return FALSE
	}

	method _activate(int64 targetID)
	{
		if ${_lastActivationTimestamp} == 0
		{
			This:LogDebug["Activating ${This.Name} on ${targetID} ${Entity[${targetID}].Name}"]
			_lastActivationTimestamp:Set[${LavishScript.RunningTime}]
			if ${targetID} == TARGET_NA
			{
				This:Activate
			}
			else
			{
				This:Activate[${targetID}]
			}
		}
		elseif ${LavishScript.RunningTime} > ${Math.Calc[${_lastActivationTimestamp} + ${_activationRetryInterval}]}
		{
			This:LogDebug["Retrying activate ${This.Name} on ${targetID} ${Entity[${targetID}].Name}"]
			_lastActivationTimestamp:Set[${LavishScript.RunningTime}]
			if ${targetID} == TARGET_NA
			{
				This:Activate
			}
			else
			{
				This:Activate[${targetID}]
			}
		}
	}

	method _deactivate()
	{
		if ${_lastDeactivationTimestamp} == 0
		{
			This:LogDebug["Deactivating ${This.Name}"]
			_lastDeactivationTimestamp:Set[${LavishScript.RunningTime}]
			This:Deactivate
		}
		elseif ${LavishScript.RunningTime} > ${Math.Calc[${_lastDeactivationTimestamp} + ${_deactivationRetryInterval}]}
		{
			This:LogDebug["Retrying deactivate ${This.Name}"]
			_lastDeactivationTimestamp:Set[${LavishScript.RunningTime}]
			This:Deactivate
		}
	}

	method _changeAmmo(int64 ammoID, int ammoAmount)
	{
		if ${_lastChangeAmmoTimestamp} == 0
		{
			This:LogDebug["Switching ${This.Name} ammo to \ay${ammoID}"]
			_lastChangeAmmoTimestamp:Set[${LavishScript.RunningTime}]
			This:ChangeAmmo[${ammoID}, ${ammoAmount}]
		}
		elseif ${LavishScript.RunningTime} > ${Math.Calc[${_lastChangeAmmoTimestamp} + ${_changeAmmoRetryInterval}]}
		{
			This:LogDebug["Retrying ${This.Name} switching ammo to \ay${ammoID}"]
			_lastChangeAmmoTimestamp:Set[${LavishScript.RunningTime}]
			This:ChangeAmmo[${ammoID}, ${ammoAmount}]
		}
	}

	member:string _pickOptimalAmmo(int64 targetID)
	{
		switch ${This.ToItem.GroupID}
		{
			case GROUP_ENERGYWEAPON
			case GROUP_PROJECTILEWEAPON
				return ${This._pickOptimalAmmoForTurret[${InstructionTargetID}]}
			case GROUP_TRACKINGCOMPUTER
				return ${This._pickOptimalScriptTrackingComputerScript[${InstructionTargetID}]}
		}

		return ""
	}

	member:string _pickOptimalAmmoForTurret(int64 targetID)
	{
		if (${targetID} == TARGET_NA) || \
			!(${Entity[${targetID}](exists)} && !${Entity[${targetID}].IsMoribund} && ${Entity[${targetID}].IsLockedTarget})
		{
			This:LogCritical["Picking turret ammo for invalid target."]
			return ""
		}

		variable string shortRangeAmmo
		variable string longRangeAmmo

		; This:LogDebug["_pickOptimalAmmoForTurret"]

		; Set fallback ammo
		if !${Ammo.NotNULLOrEmpty} || ${MyShip.Cargo[${Ammo}].Quantity} == 0
		{
			if ${This.ToItem.GroupID} == GROUP_ENERGYWEAPON
			{
				shortRangeAmmo:Set["Conflagration L"]
			}
			if ${This.ToItem.GroupID} == GROUP_PROJECTILEWEAPON
			{
				shortRangeAmmo:Set["Hail L"]
			}
		}
		else
		{
			shortRangeAmmo:Set[${Ammo}]
		}

		if !${LongRangeAmmo.NotNULLOrEmpty} || ${MyShip.Cargo[${LongRangeAmmo}].Quantity} == 0
		{
			if ${This.ToItem.GroupID} == GROUP_ENERGYWEAPON
			{
				longRangeAmmo:Set["Scorch L"]
			}
			if ${This.ToItem.GroupID} == GROUP_PROJECTILEWEAPON
			{
				longRangeAmmo:Set["Barrage L"]
			}
		}
		else
		{
			longRangeAmmo:Set[${LongRangeAmmo}]
		}

		if !${This.Charge(exists)} || \
			${This.Charge.Type.Find[${shortRangeAmmo}]} || \
			!${This.Charge.Type.Find[${longRangeAmmo}]}	/* this means unknown ammo is loaded */
		{
			if ${Entity[${targetID}].Distance} <= ${This.Range}
			{
				if  ${MyShip.Cargo[${shortRangeAmmo}].Quantity} > 0
				{
					return ${shortRangeAmmo}
				}
				elseif ${MyShip.Cargo[${longRangeAmmo}].Quantity} > 0
				{
					return ${longRangeAmmo}
				}
			}
			else
			{
				if ${MyShip.Cargo[${longRangeAmmo}].Quantity} > 0
				{
					return ${longRangeAmmo}
				}
				elseif  ${MyShip.Cargo[${shortRangeAmmo}].Quantity} > 0
				{
					return ${shortRangeAmmo}
				}
			}
		}
		elseif ${This.Charge.Type.Find[${longRangeAmmo}]}
		{
			if ${Entity[${targetID}].Distance} <= ${Math.Calc[${This.Range} * 0.4]}
			{
				if  ${MyShip.Cargo[${shortRangeAmmo}].Quantity} > 0
				{
					return ${shortRangeAmmo}
				}
				elseif ${MyShip.Cargo[${longRangeAmmo}].Quantity} > 0
				{
					return ${longRangeAmmo}
				}
			}
			else
			{
				if ${MyShip.Cargo[${longRangeAmmo}].Quantity} > 0
				{
					return ${longRangeAmmo}
				}
				elseif  ${MyShip.Cargo[${shortRangeAmmo}].Quantity} > 0
				{
					return ${shortRangeAmmo}
				}
			}
		}
		This:LogCritical["No configured ammo in cargo!"]
		return ""
	}

	member:string _pickOptimalScriptTrackingComputerScript(int64 targetID)
	{
		if (${targetID} == TARGET_NA)
		{
			return ""

		}

		if !(${Entity[${targetID}](exists)} && !${Entity[${targetID}].IsMoribund} && ${Entity[${targetID}].IsLockedTarget})
		{
			This:LogCritical["Picking script for invalid target."]
			return ""
		}

		if ${Entity[${targetID}].Distance} > ${Ship.ModuleList_Weapon.OptimalRange.Int}
		{
			; echo need range
			if !${This.Charge.Type(exists)} || ${This.Charge.Type.Find["Tracking Speed Script"]}
			{
				if ${MyShip.Cargo["Optimal Range Script"].Quantity} > 0
				{
					return "Optimal Range Script"
				}
				; BUG of ISXEVE: UnloadToCargo method is not working
				; elseif ${This.Charge.Type.Find["Tracking Speed Script"]}
				; {
				; 	return "unload"
				; }
			}
		}
		elseif ${Entity[${targetID}].Distance} < ${Math.Calc[${Ship.ModuleList_Weapon.OptimalRange.Int} * 0.6]}
		{
			; echo need tracking
			if !${This.Charge.Type(exists)} || ${This.Charge.Type.Find["Optimal Range Script"]}
			{
				if ${MyShip.Cargo["Tracking Speed Script"].Quantity} > 0
				{
					return "Tracking Speed Script"
				}
				; BUG of ISXEVE: UnloadToCargo method is not working
				; elseif ${This.Charge.Type.Find["Optimal Range Script"]}
				; {
				; 	return "unload"
				; }
			}
		}

		return ""
	}

	method _findAndChangeAmmo(string ammo)
	{
		variable index:item availableAmmos
		This:GetAvailableAmmo[availableAmmos]
		if ${availableAmmos.Used} == 0
		{
			This:LogCritical["No Ammo available - dreadful - also, annoying"]
			return
		}

		variable iterator availableAmmoIterator
		availableAmmos:GetIterator[availableAmmoIterator]
		if ${availableAmmoIterator:First(exists)}
		do
		{
			if ${ammo.Equal[${availableAmmoIterator.Value.Name}]}
			{
				variable int chargeAmountToLoad
				chargeAmountToLoad:Set[${Utility.Min[${This.MaxCharges}, ${MyShip.Cargo[${ammo}].Quantity}]}]
				This:_changeAmmo[${availableAmmoIterator.Value.ID}, ${chargeAmountToLoad}]
				return
			}
		}
		while ${availableAmmoIterator:Next(exists)}
	}

	member:float Range()
	{
		if ${This.TransferRange(exists)}
		{
			return ${This.TransferRange}
		}
		if ${This.ShieldTransferRange(exists)}
		{
			return ${This.ShieldTransferRange}
		}
		if ${This.OptimalRange(exists)}
		{
			if ${This.AccuracyFalloff(exists)}
			{
				return ${Math.Calc[${This.OptimalRange} + ${This.AccuracyFalloff}]}
			}
			return ${This.OptimalRange}
		}
		else
		{
			return ${Math.Calc[${This.Charge.MaxFlightTime} * ${This.Charge.MaxVelocity}]}
		}
	}
}


	; if ${This.ToItem.GroupID} == GROUP_MISSILELAUNCHERTORPEDO
	; 		{
	; 			if ${MyShip.Cargo[${shortRangeAmmo}].Quantity} == 0
	; 			{
	; 				if ${MyShip.Cargo["Scourge Rage Torpedo"].Quantity} > 0
	; 				{
	; 					shortRangeAmmo:Set["Scourge Rage Torpedo"]
	; 				}
	; 				elseif ${MyShip.Cargo["Mjolnir Rage Torpedo"].Quantity} > 0
	; 				{
	; 					shortRangeAmmo:Set["Mjolnir Rage Torpedo"]
	; 				}
	; 				elseif ${MyShip.Cargo["Nova Rage Torpedo"].Quantity} > 0
	; 				{
	; 					shortRangeAmmo:Set["Nova Rage Torpedo"]
	; 				}
	; 				elseif ${MyShip.Cargo["Inferno Rage Torpedo"].Quantity} > 0
	; 				{
	; 					shortRangeAmmo:Set["Inferno Rage Torpedo"]
	; 				}
	; 			}

	; 			if ${MyShip.Cargo[${longRangeAmmo}].Quantity} == 0
	; 			{
	; 				if ${MyShip.Cargo["Scourge Javelin Torpedo"].Quantity} > 0
	; 				{
	; 					longRangeAmmo:Set["Scourge Javelin Torpedo"]
	; 				}
	; 				elseif ${MyShip.Cargo["Mjolnir Javelin Torpedo"].Quantity} > 0
	; 				{
	; 					longRangeAmmo:Set["Mjolnir Javelin Torpedo"]
	; 				}
	; 				elseif ${MyShip.Cargo["Nova Javelin Torpedo"].Quantity} > 0
	; 				{
	; 					longRangeAmmo:Set["Nova Javelin Torpedo"]
	; 				}
	; 				elseif ${MyShip.Cargo["Inferno Javelin Torpedo"].Quantity} > 0
	; 				{
	; 					longRangeAmmo:Set["Inferno Javelin Torpedo"]
	; 				}
	; 			}

	; 			if ${MyShip.Cargo[${shortRangeAmmo}].Quantity} > 0 && ${Entity[${targetID}].Distance} < 62000
	; 			{
	; 				This:QueueState["_findAndChangeAmmo", 50, ${shortRangeAmmo}]
	; 			}

	; 			if ${MyShip.Cargo[${longRangeAmmo}].Quantity} > 0 && ${Entity[${targetID}].Distance} > 62000
	; 			{
	; 				This:QueueState["_findAndChangeAmmo", 50, ${longRangeAmmo}]
	; 			}
	; 		}
	; 		elseif ${This.ToItem.GroupID} == GROUP_PRECURSORWEAPON
	; 		{
	; 			if ${Entity[${targetID}].Distance} > 70000 || ${Mission.RudeEwar}
	; 			{
	; 				This:QueueState["_findAndChangeAmmo", 50, "Meson Exotic Plasma L"]
	; 			}

	; 			if ${Entity[${targetID}].Distance} > 50000 && ${Entity[${targetID}].Distance} < 70000 && !${Mission.RudeEwar}
	; 			{
	; 				This:QueueState["_findAndChangeAmmo", 50, "Mystic L"]
	; 			}

	; 			if ${Entity[${targetID}].Distance} > 27000 && ${Entity[${targetID}].Distance} < 50000 && !${Mission.RudeEwar}
	; 			{
	; 				This:QueueState["_findAndChangeAmmo", 50, "Baryon Exotic Plasma L"]
	; 			}

	; 			if ${Entity[${targetID}].Distance} < 27000 && ${Entity[${targetID}].Distance} > 7500 && !${Mission.RudeEwar}

	; 			{
	; 				This:QueueState["_findAndChangeAmmo", 50, "Occult L"]
	; 			}

	; 			if ${Entity[${targetID}].Distance} < 7500 && !${Mission.RudeEwar}

	; 			{
	; 				This:QueueState["_findAndChangeAmmo", 50, "Baryon Exotic Plasma L"]
	; 			}
	; 		}
	;

	; member:bool UnloadAmmoToCargo()
	; {
	; 	if !${This.Charge(exists)}
	; 	{
	; 		return TRUE
	; 	}
	; 	else
	; 	{
	; 		This:LogInfo["Unloading \ay${This.Charge.Type}"]
	; 		This:UnloadToCargo
	; 		return TRUE
	; 	}

	; 	return FALSE
	; }

	; member:bool ActivateOn(int64 targetID)
	; {
	; 	if ${targetID.Equal[-1]} || ${targetID.Equal[0]}
	; 	{
	; 		if ${This.IsActive}
	; 		{
	; 			if (${Me.ToEntity.Mode} == 3 && ${This.ToItem.GroupID} == GROUP_AFTERBURNER)
	; 			{
	; 				Activated:Set[FALSE]
	; 				InstructionTargetID:Set[-1]
	; 				This:Clear
	; 			}
	; 			return TRUE
	; 		}
	; 		This:Activate
	; 		InstructionTargetID:Set[-1]
	; 		Activated:Set[TRUE]
	; 		This:InsertState["WaitTillActive", 50, 20]
	; 		return TRUE
	; 	}
	; }

