objectdef obj_Module inherits obj_StateQueue
{
	variable bool _activationInstructed = FALSE
	variable bool _deactivationInstructed = FALSE
	variable int64 _instructedTarget = -1
	variable int64 ModuleID

	method Initialize(int64 ID)
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]
		ModuleID:Set[${ID}]
		; NonGameTiedPulse:Set[TRUE]
		PulseFrequency:Set[50]
	}

	member:string GetFallthroughObject()
	{
		return "MyShip.Module[${ModuleID}]"
	}

	member:bool TestGetFallthroughObject()
	{
		; ${This.IsChangingAmmo} is NULL for energy weapons, didn't test with other types.
		; ${This.Duration} is NULL for weapons.
		; ${This.LastTarget} ${This.TargetID} are NULL until target exists.
		if ${This.Name.NotNULLOrEmpty} && \
			${This.IsReloadingAmmo(type).Name.Equal[bool]} && \
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

	member:bool IsModuleActive()
	{
		; Don't simplify this for Lavish Script has bug
		if ${This.IsActive} || ${_activationInstructed}
			return TRUE
		return FALSE
	}

	member:bool IsModuleActiveOn(int64 targetID)
	{
		variable bool isTargetMatch = FALSE
		if (${_instructedTarget.Equal[0]} || ${_instructedTarget.Equal[-1]}) && (${targetID.Equal[0]} || ${targetID.Equal[-1]})
		{
			isTargetMatch:Set[TRUE]
		}
		elseif ${_instructedTarget.Equal[${targetID}]}
		{
			isTargetMatch:Set[TRUE]
		}

		; Don't simplify this for Lavish Script has bug
		if ${This.IsModuleActive} && ${isTargetMatch}
		{
			return TRUE
		}
		return FALSE
	}

	method DeactivateModule()
	{
		if ${This.IsActive} && !${_deactivationInstructed}
		{
			This:Deactivate
			_deactivationInstructed:Set[TRUE]
			This:Clear
			This:InsertState["WaitTillInactive", 50, 0]
		}
	}

	method ChooseAndLoadTurretAmmo(string shortRangeAmmo, string longRangeAmmo, int64 targetID)
	{
		if !${This.Charge(exists)} || \
			${This.Charge.Type.Find[${shortRangeAmmo}]} || \
			!${This.Charge.Type.Find[${longRangeAmmo}]}	/* this means unknown ammo is loaded */
		{
			if ${Entity[${targetID}].Distance} <= ${This.Range}
			{
				if  ${MyShip.Cargo[${shortRangeAmmo}].Quantity} > 0
				{
					This:QueueState["LoadOptimalAmmo", 50, ${shortRangeAmmo}]
					return
				}
				elseif ${MyShip.Cargo[${longRangeAmmo}].Quantity} > 0
				{
					This:QueueState["LoadOptimalAmmo", 50, ${longRangeAmmo}]
					return
				}
			}
			else
			{
				if ${MyShip.Cargo[${longRangeAmmo}].Quantity} > 0
				{
					This:QueueState["LoadOptimalAmmo", 50, ${longRangeAmmo}]
					return
				}
				elseif  ${MyShip.Cargo[${shortRangeAmmo}].Quantity} > 0
				{
					This:QueueState["LoadOptimalAmmo", 50, ${shortRangeAmmo}]
					return
				}
			}
		}
		else /* implies ${This.Charge.Type.Find[${longRangeAmmo}]} is TRUE */
		{
			if ${Entity[${targetID}].Distance} <= ${Math.Calc[${This.Range} * 0.4]}
			{
				if  ${MyShip.Cargo[${shortRangeAmmo}].Quantity} > 0
				{
					This:QueueState["LoadOptimalAmmo", 50, ${shortRangeAmmo}]
					return
				}
				elseif ${MyShip.Cargo[${longRangeAmmo}].Quantity} > 0
				{
					This:QueueState["LoadOptimalAmmo", 50, ${longRangeAmmo}]
					return
				}
			}
			else
			{
				if ${MyShip.Cargo[${longRangeAmmo}].Quantity} > 0
				{
					This:QueueState["LoadOptimalAmmo", 50, ${longRangeAmmo}]
					return
				}
				elseif  ${MyShip.Cargo[${shortRangeAmmo}].Quantity} > 0
				{
					This:QueueState["LoadOptimalAmmo", 50, ${shortRangeAmmo}]
					return
				}
			}
		}
		This:LogCritical["No configured ammo in cargo!"]
	}

	method ChooseAndLoadTrackingComputerScript(int64 targetID, int optimalRange)
	{
		if ${Entity[${targetID}].Distance} > ${optimalRange}
		{
			; echo need range
			if !${This.Charge.Type(exists)} || ${This.Charge.Type.Find["Tracking Speed Script"]}
			{
				if ${MyShip.Cargo["Optimal Range Script"].Quantity} > 0
				{
					This:DeactivateModule
					This:QueueState["LoadOptimalAmmo", 50, "Optimal Range Script"]
				}
				; BUG of ISXEVE: UnloadToCargo method is not working
				; elseif ${This.Charge.Type.Find["Tracking Speed Script"]}
				; {
				; 	This:Log["Unloading Tracking Speed Script"]
				; 	This:DeactivateModule
				; 	This:QueueState["UnloadAmmoToCargo", 50]
				; }
			}
		}
		elseif ${Entity[${targetID}].Distance} < ${Math.Calc[${optimalRange} * 0.6]}
		{
			; echo need tracking
			if !${This.Charge.Type(exists)} || ${This.Charge.Type.Find["Optimal Range Script"]}
			{
				if ${MyShip.Cargo["Tracking Speed Script"].Quantity} > 0
				{
					This:DeactivateModule
					This:QueueState["LoadOptimalAmmo", 50, "Tracking Speed Script"]
				}
				; BUG of ISXEVE: UnloadToCargo method is not working
				; elseif ${This.Charge.Type.Find["Optimal Range Script"]}
				; {
				; 	This:Log["Unloading Optimal Range Script"]
				; 	This:DeactivateModule
				; 	This:QueueState["UnloadAmmoToCargo", 50]
				; }
			}
		}
	}

    method ActivateModule(int64 targetID=-1, int deactivateAfterCyclePercent=-1)
    {
        if ${This.IsReloading} || ${_deactivationInstructed}
		{
			return
		}

        if ${This.IsModuleActive} && !${This.IsModuleActiveOn[${targetID}]} && \
			${This.ToItem.GroupID} != GROUP_TRACKINGCOMPUTER && \
			${This.ToItem.GroupID} != GROUP_MISSILEGUIDANCECOMPUTER
        {
            This:DeactivateModule
        }

        if ${Entity[${targetID}].CategoryID} == CATEGORYID_ORE && ${This.ToItem.GroupID} == GROUP_FREQUENCY_MINING_LASER
        {
            This:QueueState["LoadMiningCrystal", 50, ${Entity[${targetID}].Type}]
        }

		variable string shortRangeAmmo = ${Mission.ammo}
		variable string longRangeAmmo = ${Mission.secondaryAmmo}

		if ${Entity[${targetID}].CategoryID} == CATEGORYID_ENTITY
		{
			if ${This.ToItem.GroupID} == GROUP_PRECURSORWEAPON
			{
				if ${Entity[${targetID}].Distance} > 70000 || ${Mission.RudeEwar}
				{
					This:QueueState["LoadOptimalAmmo", 50, "Meson Exotic Plasma L"]
				}

				if ${Entity[${targetID}].Distance} > 50000 && ${Entity[${targetID}].Distance} < 70000 && !${Mission.RudeEwar}
				{
					This:QueueState["LoadOptimalAmmo", 50, "Mystic L"]
				}

				if ${Entity[${targetID}].Distance} > 27000 && ${Entity[${targetID}].Distance} < 50000 && !${Mission.RudeEwar}
				{
					This:QueueState["LoadOptimalAmmo", 50, "Baryon Exotic Plasma L"]
				}

				if ${Entity[${targetID}].Distance} < 27000 && ${Entity[${targetID}].Distance} > 7500 && !${Mission.RudeEwar}

				{
					This:QueueState["LoadOptimalAmmo", 50, "Occult L"]
				}

				if ${Entity[${targetID}].Distance} < 7500 && !${Mission.RudeEwar}

				{
					This:QueueState["LoadOptimalAmmo", 50, "Baryon Exotic Plasma L"]
				}
			}
			elseif ${This.ToItem.GroupID} == GROUP_PROJECTILEWEAPON
			{
				; This expression returns TRUE when the Quantity is NULL
				if ${MyShip.Cargo[${shortRangeAmmo}].Quantity} == 0
				{
					shortRangeAmmo:Set["Hail L"]
				}

				if ${MyShip.Cargo[${longRangeAmmo}].Quantity} == 0
				{
					longRangeAmmo:Set["Barrage L"]
				}

				This:ChooseAndLoadTurretAmmo[${shortRangeAmmo}, ${longRangeAmmo}, ${targetID}]
			}
			elseif ${This.ToItem.GroupID} == GROUP_MISSILELAUNCHERTORPEDO
			{
				if ${MyShip.Cargo[${shortRangeAmmo}].Quantity} == 0
				{
					if ${MyShip.Cargo["Scourge Rage Torpedo"].Quantity} > 0
					{
						shortRangeAmmo:Set["Scourge Rage Torpedo"]
					}
					elseif ${MyShip.Cargo["Mjolnir Rage Torpedo"].Quantity} > 0
					{
						shortRangeAmmo:Set["Mjolnir Rage Torpedo"]
					}
					elseif ${MyShip.Cargo["Nova Rage Torpedo"].Quantity} > 0
					{
						shortRangeAmmo:Set["Nova Rage Torpedo"]
					}
					elseif ${MyShip.Cargo["Inferno Rage Torpedo"].Quantity} > 0
					{
						shortRangeAmmo:Set["Inferno Rage Torpedo"]
					}
				}

				if ${MyShip.Cargo[${longRangeAmmo}].Quantity} == 0
				{
					if ${MyShip.Cargo["Scourge Javelin Torpedo"].Quantity} > 0
					{
						longRangeAmmo:Set["Scourge Javelin Torpedo"]
					}
					elseif ${MyShip.Cargo["Mjolnir Javelin Torpedo"].Quantity} > 0
					{
						longRangeAmmo:Set["Mjolnir Javelin Torpedo"]
					}
					elseif ${MyShip.Cargo["Nova Javelin Torpedo"].Quantity} > 0
					{
						longRangeAmmo:Set["Nova Javelin Torpedo"]
					}
					elseif ${MyShip.Cargo["Inferno Javelin Torpedo"].Quantity} > 0
					{
						longRangeAmmo:Set["Inferno Javelin Torpedo"]
					}
				}

				if ${MyShip.Cargo[${shortRangeAmmo}].Quantity} > 0 && ${Entity[${targetID}].Distance} < 62000
				{
					This:QueueState["LoadOptimalAmmo", 50, ${shortRangeAmmo}]
				}

				if ${MyShip.Cargo[${longRangeAmmo}].Quantity} > 0 && ${Entity[${targetID}].Distance} > 62000
				{
					This:QueueState["LoadOptimalAmmo", 50, ${longRangeAmmo}]
				}
			}
			elseif ${This.ToItem.GroupID} == GROUP_ENERGYWEAPON
			{
				if ${MyShip.Cargo[${shortRangeAmmo}].Quantity} == 0
				{
					shortRangeAmmo:Set["Conflagration L"]
				}

				if ${MyShip.Cargo[${longRangeAmmo}].Quantity} == 0
				{
					longRangeAmmo:Set["Scorch L"]
				}

				This:ChooseAndLoadTurretAmmo[${shortRangeAmmo}, ${longRangeAmmo}, ${targetID}]
			}
			elseif ${This.ToItem.GroupID} == GROUP_TRACKINGCOMPUTER
			{
				This:ChooseAndLoadTrackingComputerScript[${targetID}, ${Ship.ModuleList_Weapon.OptimalRange.Int}]
			}
		}

        if ${This.ToItem.GroupID} == GROUP_PRECURSORWEAPON && ${Entity[${targetID}].Distance} > ${Ship.CurrentOptimal}
        {
           return
        }

        if ${This.ToItem.GroupID} == GROUP_MISSILELAUNCHERRAPIDHEAVY && ${Entity[${targetID}].Distance} > 70000
        {
           return
        }

        This:QueueState["ActivateOn", 50, "${targetID}"]

        if ${deactivateAfterCyclePercent} > 0
        {
            This:QueueState["DeactivateAfterCyclePercent", 50, ${deactivateAfterCyclePercent}]
        }

		; Need this state to catch target destruction and reset _instructedTarget
        This:QueueState["WaitTillInactive", 50, -1]
    }

	member:bool LoadMiningCrystal(string OreType)
	{
		variable index:item Crystals
		variable iterator Crystal
		if ${OreType.Find[${This.Charge.Type.Token[1, " "]}]}
		{
			return TRUE
		}
		else
		{
			This:GetAvailableAmmo[Crystals]

			if ${Crystals.Used} == 0
			{
				This:Log["No crystals available - mining ouput decreased", "o"]
			}

			Crystals:GetIterator[Crystal]

			if ${Crystal:First(exists)}
			do
			{
				if ${OreType.Find[${Crystal.Value.Name.Token[1, " "]}](exists)}
				{
					This:Log["Switching Crystal to ${Crystal.Value.Name}"]
					This:ChangeAmmo[${Crystal.Value.ID}, 1]
					return TRUE
				}
			}
			while ${Crystal:Next(exists)}
		}

		return TRUE
	}

	member:bool LoadOptimalAmmo(string ammo)
	{
		if ${This.IsReloading}
		{
			return FALSE
		}

		if ${ammo.Equal[${This.Charge.Type}]}
		{
			return TRUE
		}
		else
		{
			variable index:item availableAmmos
			variable iterator availableAmmoIterator
			This:GetAvailableAmmo[availableAmmos]

			if ${availableAmmos.Used} == 0
			{
				if ${Me.InSpace}
				{
					This:Log["No Ammo available - dreadful - also, annoying", "o"]
				}
				return FALSE
			}

			availableAmmos:GetIterator[availableAmmoIterator]
			if ${availableAmmoIterator:First(exists)}
			do
			{
				if ${ammo.Equal[${availableAmmoIterator.Value.Name}]}
				{
					This:Log["Switching Ammo to \ay${availableAmmoIterator.Value.Name}"]
					variable int ChargeAmountToLoad = ${MyShip.Cargo[${ammo}].Quantity}

					if ${ChargeAmountToLoad} > ${This.MaxCharges}
					{
						ChargeAmountToLoad:Set[${This.MaxCharges}]
					}

					This:ChangeAmmo[${availableAmmoIterator.Value.ID}, ${ChargeAmountToLoad}]
					This:InsertState["WaitTillSwitchAmmo", 50, "\"${ammo}\", 20"]
					return TRUE
				}
			}
			while ${availableAmmoIterator:Next(exists)}
		}

		return FALSE
	}

	member:bool UnloadAmmoToCargo()
	{
		if ${This.IsReloading}
		{
			return FALSE
		}

		if !${This.Charge(exists)}
		{
			return TRUE
		}
		else
		{
			This:Log["Unloading \ay${This.Charge.Type}"]
			This:UnloadToCargo
			return TRUE
		}

		return FALSE
	}

	member:bool ActivateOn(int64 targetID)
	{
		if ${targetID.Equal[-1]} || ${targetID.Equal[0]}
		{
			if ${This.IsActive}
			{
				if (${Me.ToEntity.Mode} == 3 && ${This.ToItem.GroupID} == GROUP_AFTERBURNER)
				{
					_activationInstructed:Set[FALSE]
					_instructedTarget:Set[-1]
					This:Clear
				}
				return TRUE
			}
			This:Activate
			_instructedTarget:Set[-1]
			_activationInstructed:Set[TRUE]
			This:InsertState["WaitTillActive", 50, 20]
			return TRUE
		}
		elseif ${Entity[${targetID}](exists)} && ${Entity[${targetID}].IsLockedTarget}
		{
			; Strict isActiveOn
			if ${This.IsActive} && ${This.TargetID.Equal[${targetID}]}
			{
				return TRUE
			}
			This:Activate[${targetID}]
			_instructedTarget:Set[${targetID}]
			_activationInstructed:Set[TRUE]
			This:InsertState["WaitTillActive", 50, 20]
			return FALSE
		}
		else
		{
			_activationInstructed:Set[FALSE]
			_instructedTarget:Set[-1]
			This:Clear
			return TRUE
		}
	}

	; TODO: Add Wait till unload ammo
	member:bool WaitTillSwitchAmmo(string ammo, int countdown)
	{
		if ${countdown} > 0
		{
			This:SetStateArgs["\"${ammo}\", ${Math.Calc[${countdown} - 1]}"]
			return ${ammo.Equal[${This.Charge.Type}]}
		}
		return TRUE
	}

	member:bool WaitTillActive(int countdown)
	{
		if ${countdown} > 0
		{
			This:SetStateArgs[${Math.Calc[${countdown} - 1]}]
			return ${This.IsActive}
		}
		return TRUE
	}

	member:bool DeactivateAfterCyclePercent(int percent)
	{
		if ${percent} == -1
		{
			return TRUE
		}

		if ${Math.Calc[((${EVETime.AsInt64} - ${This.TimeLastClicked.AsInt64}) / ${This.ActivationTime}) * 100]} > ${percent}
		{
			This:Deactivate
			_deactivationInstructed:Set[TRUE]
			This:Clear
			This:InsertState["WaitTillInactive", 50, 0]
			return TRUE
		}
		return FALSE
	}

	member:bool WaitTillInactive(int count=-1)
	{
		if ${count} > 50
		{
			This:Deactivate
			This:InsertState["WaitTillInactive", 50, 0]
			return TRUE
		}

		if ${This.IsActive}
		{
			if ${count} >= 0
			{
				This:InsertState["WaitTillInactive", 50, ${count:Inc}]
				return TRUE
			}
			else
			{
				; Waiting infinitely
				_deactivationInstructed:Set[FALSE]
				return FALSE
			}
		}

		_activationInstructed:Set[FALSE]
		_deactivationInstructed:Set[FALSE]
		_instructedTarget:Set[-1]
		return TRUE
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
				return ${Math.Calc[${This.OptimalRange} + ${This.AccuracyFalloff}]}
			return ${This.OptimalRange}
		}
		else
		{
			return ${Math.Calc[${This.Charge.MaxFlightTime} * ${This.Charge.MaxVelocity}]}
		}
	}
}