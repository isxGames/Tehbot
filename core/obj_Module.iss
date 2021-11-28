objectdef obj_Module inherits obj_StateQueue
{
	variable bool Activated = FALSE
	variable bool Deactivating = FALSE
	variable int64 CurrentTarget = -1
	variable int64 ModuleID
	variable string TurretAmmoRangeType = "unknown"

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

	member:bool IsActive()
	{
		; ISXEVE API is not reliable
		; Don't simplify this for Lavish Script has bug
		if ${MyShip.Module[${ModuleID}].IsActive} || ${Activated}
			return TRUE
		return FALSE
	}

	member:bool IsDeactivating()
	{
		return ${Deactivating}
	}

	member:bool IsActiveOn(int64 checkTarget)
	{
		variable bool isTargetMatch = FALSE
		if (${CurrentTarget.Equal[0]} || ${CurrentTarget.Equal[-1]}) && (${checkTarget.Equal[0]} || ${checkTarget.Equal[-1]})
		{
			isTargetMatch:Set[TRUE]
		}
		elseif ${CurrentTarget.Equal[${checkTarget}]}
		{
			isTargetMatch:Set[TRUE]
		}

		; Don't simplify this for Lavish Script has bug
		if ${This.IsActive} && ${isTargetMatch}
		{
			return TRUE
		}
		return FALSE
	}

	method Deactivate()
	{
		if ${MyShip.Module[${ModuleID}].IsActive} && !${Deactivating}
		{
			MyShip.Module[${ModuleID}]:Deactivate
			Deactivating:Set[TRUE]
			This:Clear
			This:InsertState["WaitTillInactive", 50, 0]
		}
	}

	method ChooseAndLoadTurretAmmo(string shortRangeAmmo, string longRangeAmmo, int64 newTarget, int DefaultRangeThreshold)
	{
		; I can not reset TurretAmmoRangeType to 'unknown' between missions due to stupid script bugs,
		; There will be tiny risk of inaccurate TurretAmmoRangeType when the ammo is
		; changed manually between missions.
		; But the script can basically auto correct it as the mission goes on as follows:

		; 		Label "Short" X Ammo "Long":
		; 			For Close Target: Will switch to Ammo "Short" immediately
		; 			For Far Target: Will firstly switch to Ammo "Short" then switch to Label/Ammo "Long"
		; 			For Out of Range Target: Will switch Label to "Long"

		; 		Label "Long" X Ammo "Short":
		; 			For Target Within 40% Range: Will switch to Label "Short" immediately
		; 			For Target Within 40% - 100% Range: The only case that it cannot auto correct,
		; 				but this won't be big deal or lasts long as "Short" ammo is preferred and
		;				correct in this case, and the target in its optimal range should be destroyed soon.
		; 			For Out of Range Target: Will switch Ammo to "Long" immediately

		; The following code can completely fix this risk but it's too much extraS complexity
		; variable string TurretAmmoRangeType = "unknown"
		; if ${This.Charge.Type(exists)}
		; {
		; 	if ${This.Charge.Type.Find["Multifrequency"]} || \
		; 	${This.Charge.Type.Find["Gamma"]} || \
		; 	${This.Charge.Type.Find["Xray"]} || \
		; 	${This.Charge.Type.Find["Ultraviolet"]} || \
		; 	${This.Charge.Type.Find["Conflagration"]} || \
		; 	${This.Charge.Type.Find["Hail"]}
		; 	{
		; 		TurretAmmoRangeType:Set["short"]
		; 	}
		; 	elseif ${This.Charge.Type.Find["Standard"]} || \
		; 	${This.Charge.Type.Find["Infrared"]} || \
		; 	${This.Charge.Type.Find["Microwave"]} || \
		; 	${This.Charge.Type.Find["Radio"]} || \
		; 	${This.Charge.Type.Find["Scorch"]} || \
		; 	${This.Charge.Type.Find["Barrage"]}
		; 	{
		; 		TurretAmmoRangeType:Set["long"]
		; 	}
		; }

		switch ${TurretAmmoRangeType}
		{
			; When current ammo state is unknown, chose ammo by estimated default range.
			case unknown
				; echo current unknown ammo range ${This.Range}
				if ${MyShip.Cargo[${shortRangeAmmo}].Quantity} > 0 && ${Entity[${newTarget}].Distance} <= ${DefaultRangeThreshold}
				{
					TurretAmmoRangeType:Set["short"]
					This:QueueState["LoadOptimalAmmo", 50, ${shortRangeAmmo}]
				}

				if ${MyShip.Cargo[${longRangeAmmo}].Quantity} > 0 && ${Entity[${newTarget}].Distance} > ${DefaultRangeThreshold}
				{
					TurretAmmoRangeType:Set["long"]
					This:QueueState["LoadOptimalAmmo", 50, ${longRangeAmmo}]
				}

				break
			case short
				; echo current \ao short \aw ammo range ${This.Range}
				; Use dynamic range to take skills, tracking enhancers, tracking disrupters etc. to account
				if ${MyShip.Cargo[${shortRangeAmmo}].Quantity} > 0 && ${Entity[${newTarget}].Distance} <= ${This.Range}
				{
					TurretAmmoRangeType:Set["short"]
					This:QueueState["LoadOptimalAmmo", 50, ${shortRangeAmmo}]
				}

				if ${MyShip.Cargo[${longRangeAmmo}].Quantity} > 0 && ${Entity[${newTarget}].Distance} > ${This.Range}
				{
					TurretAmmoRangeType:Set["long"]
					This:QueueState["LoadOptimalAmmo", 50, ${longRangeAmmo}]
				}

				break
			case long
				; echo current \ag long \aw ammo range ${This.Range}
				if ${MyShip.Cargo[${shortRangeAmmo}].Quantity} > 0 && ${Entity[${newTarget}].Distance} <= ${Math.Calc[${This.Range} * 0.4]}
				{
					TurretAmmoRangeType:Set["short"]
					This:QueueState["LoadOptimalAmmo", 50, ${shortRangeAmmo}]
				}

				if ${MyShip.Cargo[${longRangeAmmo}].Quantity} > 0 && ${Entity[${newTarget}].Distance} > ${Math.Calc[${This.Range} * 0.4]}
				{
					TurretAmmoRangeType:Set["long"]
					This:QueueState["LoadOptimalAmmo", 50, ${longRangeAmmo}]
				}

				break
		}
	}

	method ChooseAndLoadTrackingComputerScript(int64 newTarget, int OptimalRange)
	{
		if ${Entity[${newTarget}].Distance} > ${OptimalRange}
		{
			; echo need range
			if !${This.Charge.Type(exists)} || ${This.Charge.Type.Find["Tracking Speed Script"]}
			{
				if ${MyShip.Cargo["Optimal Range Script"].Quantity} > 0
				{
					This:Deactivate
					This:QueueState["LoadOptimalAmmo", 50, "Optimal Range Script"]
				}
				; BUG of ISXEVE: UnloadToCargo method is not working
				; elseif ${This.Charge.Type.Find["Tracking Speed Script"]}
				; {
				; 	Logger:Log["obj_Module", "Unloading Tracking Speed Script"]
				; 	This:Deactivate
				; 	This:QueueState["UnloadAmmoToCargo", 50]
				; }
			}
		}
		elseif ${Entity[${newTarget}].Distance} < ${Math.Calc[${OptimalRange} * 0.6]}
		{
			; echo need tracking
			if !${This.Charge.Type(exists)} || ${This.Charge.Type.Find["Optimal Range Script"]}
			{
				if ${MyShip.Cargo["Tracking Speed Script"].Quantity} > 0
				{
					This:Deactivate
					This:QueueState["LoadOptimalAmmo", 50, "Tracking Speed Script"]
				}
				; BUG of ISXEVE: UnloadToCargo method is not working
				; elseif ${This.Charge.Type.Find["Optimal Range Script"]}
				; {
				; 	Logger:Log["obj_Module", "Unloading Optimal Range Script"]
				; 	This:Deactivate
				; 	This:QueueState["UnloadAmmoToCargo", 50]
				; }
			}
		}
	}

    method Activate(int64 newTarget=-1, int deactivateAfterCyclePercent=-1)
    {
        if ${This.IsReloading} || ${Deactivating}
		{
			return
		}

        if ${This.IsActive} && !${This.IsActiveOn[${newTarget}]} && \
			${This.ToItem.GroupID} != GROUP_TRACKINGCOMPUTER && \
			${This.ToItem.GroupID} != GROUP_MISSILEGUIDANCECOMPUTER
        {
            This:Deactivate
        }

        if ${Entity[${newTarget}].CategoryID} == CATEGORYID_ORE && ${This.ToItem.GroupID} == GROUP_FREQUENCY_MINING_LASER
        {
            This:QueueState["LoadMiningCrystal", 50, ${Entity[${newTarget}].Type}]
        }

		variable string shortRangeAmmo = ${Mission.ammo}
		variable string longRangeAmmo = ${Mission.secondaryAmmo}

		if ${Entity[${newTarget}].CategoryID} == CATEGORYID_ENTITY
		{
			if ${This.ToItem.GroupID} == GROUP_PRECURSORWEAPON
			{
				if ${Entity[${newTarget}].Distance} > 70000 || ${Mission.RudeEwar}
				{
					This:QueueState["LoadOptimalAmmo", 50, "Meson Exotic Plasma L"]
				}

				if ${Entity[${newTarget}].Distance} > 50000 && ${Entity[${newTarget}].Distance} < 70000 && !${Mission.RudeEwar}
				{
					This:QueueState["LoadOptimalAmmo", 50, "Mystic L"]
				}

				if ${Entity[${newTarget}].Distance} > 27000 && ${Entity[${newTarget}].Distance} < 50000 && !${Mission.RudeEwar}
				{
					This:QueueState["LoadOptimalAmmo", 50, "Baryon Exotic Plasma L"]
				}

				if ${Entity[${newTarget}].Distance} < 27000 && ${Entity[${newTarget}].Distance} > 7500 && !${Mission.RudeEwar}

				{
					This:QueueState["LoadOptimalAmmo", 50, "Occult L"]
				}

				if ${Entity[${newTarget}].Distance} < 7500 && !${Mission.RudeEwar}

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

				This:ChooseAndLoadTurretAmmo[${shortRangeAmmo}, ${longRangeAmmo}, ${newTarget}, 45000]
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

				if ${MyShip.Cargo[${shortRangeAmmo}].Quantity} > 0 && ${Entity[${newTarget}].Distance} < 62000
				{
					This:QueueState["LoadOptimalAmmo", 50, ${shortRangeAmmo}]
				}

				if ${MyShip.Cargo[${longRangeAmmo}].Quantity} > 0 && ${Entity[${newTarget}].Distance} > 62000
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

				This:ChooseAndLoadTurretAmmo[${shortRangeAmmo}, ${longRangeAmmo}, ${newTarget}, 49000]
			}
			elseif ${This.ToItem.GroupID} == GROUP_TRACKINGCOMPUTER
			{
				This:ChooseAndLoadTrackingComputerScript[${newTarget}, ${Ship.ModuleList_Weapon.OptimalRange.Int}]
			}
		}

        if ${This.ToItem.GroupID} == GROUP_PRECURSORWEAPON && ${Entity[${newTarget}].Distance} > ${Ship.CurrentOptimal}
        {
           return
        }

        if ${This.ToItem.GroupID} == GROUP_MISSILELAUNCHERRAPIDHEAVY && ${Entity[${newTarget}].Distance} > 70000
        {
           return
        }

        This:QueueState["ActivateOn", 50, "${newTarget}"]

        if ${deactivateAfterCyclePercent} > 0
        {
            This:QueueState["DeactivateAfterCyclePercent", 50, ${deactivateAfterCyclePercent}]
        }

		; Need this state to catch target destruction and reset CurrentTarget
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
				Logger:Log["obj_Module", "No crystals available - mining ouput decreased", "o"]
			}

			Crystals:GetIterator[Crystal]

			if ${Crystal:First(exists)}
			do
			{
				if ${OreType.Find[${Crystal.Value.Name.Token[1, " "]}](exists)}
				{
					Logger:Log["obj_Module", "Switching Crystal to ${Crystal.Value.Name}"]
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
					Logger:Log["obj_Module", "No Ammo available - dreadful - also, annoying", "o"]
				}
				return FALSE
			}

			availableAmmos:GetIterator[availableAmmoIterator]
			if ${availableAmmoIterator:First(exists)}
			do
			{
				if ${ammo.Equal[${availableAmmoIterator.Value.Name}]}
				{
					Logger:Log["obj_Module", "Switching Ammo to \ay${availableAmmoIterator.Value.Name}"]
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
			Logger:Log["obj_Module", "Unloading \ay${This.Charge.Type}"]
			This:UnloadToCargo
			return TRUE
		}

		return FALSE
	}

	member:bool ActivateOn(int64 newTarget)
	{
		if ${newTarget.Equal[-1]} || ${newTarget.Equal[0]}
		{
			if ${MyShip.Module[${ModuleID}].IsActive}
			{
				if (${Me.ToEntity.Mode} == 3 && ${This.ToItem.GroupID} == GROUP_AFTERBURNER)
				{
					Activated:Set[FALSE]
					CurrentTarget:Set[-1]
					This:Clear
				}
				return TRUE
			}
			MyShip.Module[${ModuleID}]:Activate
			CurrentTarget:Set[-1]
			Activated:Set[TRUE]
			This:InsertState["WaitTillActive", 50, 20]
			return TRUE
		}
		elseif ${Entity[${newTarget}](exists)} && ${Entity[${newTarget}].IsLockedTarget}
		{
			; Strict isActiveOn
			if ${MyShip.Module[${ModuleID}].IsActive} && ${This.TargetID.Equal[${newTarget}]}
			{
				return TRUE
			}
			MyShip.Module[${ModuleID}]:Activate[${newTarget}]
			CurrentTarget:Set[${newTarget}]
			Activated:Set[TRUE]
			This:InsertState["WaitTillActive", 50, 20]
			return FALSE
		}
		else
		{
			Activated:Set[FALSE]
			CurrentTarget:Set[-1]
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
			return ${MyShip.Module[${ModuleID}].IsActive}
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
			MyShip.Module[${ModuleID}]:Deactivate
			Deactivating:Set[TRUE]
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
			MyShip.Module[${ModuleID}]:Deactivate
			This:InsertState["WaitTillInactive", 50, 0]
			return TRUE
		}

		if ${MyShip.Module[${ModuleID}].IsActive}
		{
			if ${count} >= 0
			{
				This:InsertState["WaitTillInactive", 50, ${count:Inc}]
				return TRUE
			}
			else
			{
				; Waiting infinitely
				Deactivating:Set[FALSE]
				return FALSE
			}
		}

		Activated:Set[FALSE]
		Deactivating:Set[FALSE]
		CurrentTarget:Set[-1]
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

	member:string GetFallthroughObject()
	{
		return "MyShip.Module[${ModuleID}]"
	}

}