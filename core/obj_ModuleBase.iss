/*

ComBot  Copyright © 2012  Tehtsuo and Vendan

This file is part of ComBot.

ComBot is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

ComBot is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with ComBot.  If not, see <http://www.gnu.org/licenses/>.

*/

objectdef obj_ModuleBase inherits obj_StateQueue
{
	variable bool Activated = FALSE
	variable bool Deactivated = FALSE
	variable int64 CurrentTarget = -1
	variable int64 ModuleID

	method Initialize(int64 ID)
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]
		ModuleID:Set[${ID}]
		NonGameTiedPulse:Set[TRUE]
		PulseFrequency:Set[50]
	}

	member:bool IsActive()
	{
		if ${MyShip.Module[${ModuleID}].IsActive}
			return TRUE
		return ${Activated}
	}

	member:bool IsDeactivating()
	{
		return ${Deactivated}
	}

	member:bool IsActiveOn(int64 checkTarget)
	{
		if (${This.CurrentTarget.Equal[${checkTarget}]})
		{
			if ${This.IsActive}
			{
				return TRUE
			}
		}
		return FALSE
	}

	method Deactivate()
	{
		if !${Deactivated}
		{
			MyShip.Module[${ModuleID}]:Deactivate
			Deactivated:Set[TRUE]
			This:Clear
			This:QueueState["WaitTillInactive", 50, 0]
		}
	}

    method Activate(int64 newTarget=-1, bool DoDeactivate=TRUE, int DeactivatePercent=100)
    {
        if ${DoDeactivate} && ${This.IsActive}
        {
            This:Deactivate
        }
        if ${newTarget} != ${CurrentTarget} &&  ${This.IsActive}
        {
            This:Deactivate
        }
        if ${Entity[${newTarget}].CategoryID} == CATEGORYID_ORE && ${MyShip.Module[${ModuleID}].ToItem.GroupID} == GROUP_FREQUENCY_MINING_LASER
        {
            This:QueueState["LoadMiningCrystal", 50, ${Entity[${newTarget}].Type}]
        }

        if ${Entity[${newTarget}].CategoryID} == CATEGORYID_ENTITY && ${MyShip.Module[${ModuleID}].ToItem.GroupID} == GROUP_PRECURSORWEAPON
        {

			if ${Entity[${newTarget}].Distance} > 70000 || ${Mission.RudeEwar}
			{
				This:QueueState["LoadOptimalAmmo", 50, Meson Exotic Plasma L]
			}

			if ${Entity[${newTarget}].Distance} > 50000 && ${Entity[${newTarget}].Distance} < 70000 && !${Mission.RudeEwar}
			{
				This:QueueState["LoadOptimalAmmo", 50, Mystic L]
			}

			if ${Entity[${newTarget}].Distance} > 27000 && ${Entity[${newTarget}].Distance} < 50000 && !${Mission.RudeEwar}
			{
				This:QueueState["LoadOptimalAmmo", 50, Baryon Exotic Plasma L]
			}

			if ${Entity[${newTarget}].Distance} < 27000 && ${Entity[${newTarget}].Distance} > 7500 && !${Mission.RudeEwar}

			{
				This:QueueState["LoadOptimalAmmo", 50, Occult L]
			}

			if ${Entity[${newTarget}].Distance} < 7500 && !${Mission.RudeEwar}

			{
				This:QueueState["LoadOptimalAmmo", 50, Baryon Exotic Plasma L]
			}
        }

		if ${Entity[${newTarget}].CategoryID} == CATEGORYID_ENTITY && ${MyShip.Module[${ModuleID}].ToItem.GroupID} == GROUP_PROJECTILEWEAPON
        {

			if ${Entity[${newTarget}].Distance} > 45000
			{
				This:QueueState["LoadOptimalAmmo", 50, Barrage L]
			}

			if ${Entity[${newTarget}].Distance} < 45000
			{
				This:QueueState["LoadOptimalAmmo", 50, Hail L]
			}

        }

		if ${Entity[${newTarget}].CategoryID} == CATEGORYID_ENTITY && ${MyShip.Module[${ModuleID}].ToItem.GroupID} == GROUP_MISSILELAUNCHERTORPEDO
		{
			variable string longRange = ""
			variable string shortRange = ""
			if ${MyShip.Cargo[Scourge Javelin Torpedo].Quantity} > 300 || ${MyShip.Cargo[Scourge Rage Torpedo].Quantity} > 300
			{
				longRange:Set[Scourge Javelin Torpedo]
				shortRange:Set[Scourge Rage Torpedo]
			}
			if ${MyShip.Cargo[Mjolnir Javelin Torpedo].Quantity} > 300 || ${MyShip.Cargo[Mjolnir Rage Torpedo].Quantity} > 300
			{
				longRange:Set[Mjolnir Javelin Torpedo]
				shortRange:Set[Mjolnir Rage Torpedo]
			}
			if ${MyShip.Cargo[Nova Javelin Torpedo].Quantity} > 300 || ${MyShip.Cargo[Nova Rage Torpedo].Quantity} > 300
			{
				longRange:Set[Nova Javelin Torpedo]
				shortRange:Set[Nova Rage Torpedo]
			}
			if ${MyShip.Cargo[Inferno Javelin Torpedo].Quantity} > 300 || ${MyShip.Cargo[Inferno Rage Torpedo].Quantity} > 300
			{
				longRange:Set[Inferno Javelin Torpedo]
				shortRange:Set[Inferno Rage Torpedo]
			}
			if ${Entity[${newTarget}].Distance} > 62000 && !${longRange.Equal[""]}
			{
				This:QueueState["LoadOptimalAmmo", 50, ${longRange}]
			}

			if ${Entity[${newTarget}].Distance} < 62000 && !${shortRange.Equal[""]}
			{
				This:QueueState["LoadOptimalAmmo", 50, ${shortRange}]
			}

		}

        if ${Entity[${newTarget}].CategoryID} == CATEGORYID_ENTITY && ${MyShip.Module[${ModuleID}].ToItem.GroupID} == GROUP_ENERGYWEAPON
        {
			if ${MyShip.Cargo[Scorch L].Quantity} > 0 && ${Entity[${newTarget}].Distance} > 49000
			{
				This:QueueState["LoadOptimalAmmo", 50, Scorch L]
			}
			if ${MyShip.Cargo[Conflagration L].Quantity} > 0 && ${Entity[${newTarget}].Distance} < 49000
			{
				This:QueueState["LoadOptimalAmmo", 50, Conflagration L]
			}
        }
        if ${MyShip.Module[${ModuleID}].ToItem.GroupID} == GROUP_PRECURSORWEAPON && ${Entity[${newTarget}].Distance} > ${Ship.CurrentOptimal}
        {
           return
        }

        if ${MyShip.Module[${ModuleID}].ToItem.GroupID} == GROUP_MISSILELAUNCHERRAPIDHEAVY && ${Entity[${newTarget}].Distance} > 70000
        {
           return
        }

		if ${MyShip.Module[${ModuleID}].IsReloading}
		{
			return
		}
        This:QueueState["ActivateOn", 50, "${newTarget}"]
        This:QueueState["WaitTillActive", 50, 20]
        if ${DeactivatePercent} < 100
        {
            This:QueueState["DeactivatePercent", 50, ${DeactivatePercent}]
        }
        This:QueueState["WaitTillInactive"]
        if ${DoDeactivate}
        {
            CurrentTarget:Set[${newTarget}]
			Activated:Set[TRUE]
        }
    }

	member:bool LoadMiningCrystal(string OreType)
	{
		variable index:item Crystals
		variable iterator Crystal
		if ${OreType.Find[${MyShip.Module[${ModuleID}].Charge.Type.Token[1," "]}]}
		{
			return TRUE
		}
		else
		{
			MyShip.Module[${ModuleID}]:GetAvailableAmmo[Crystals]

			if ${Crystals.Used} == 0
			{
				UI:Update["obj_Module", "No crystals available - mining ouput decreased", "o"]
			}

			Crystals:GetIterator[Crystal]

			if ${Crystal:First(exists)}
			do
			{
				if ${OreType.Find[${Crystal.Value.Name.Token[1, " "]}](exists)}
				{
					UI:Update["obj_Module", "Switching Crystal to ${Crystal.Value.Name}"]
					MyShip.Module[${ModuleID}]:ChangeAmmo[${Crystal.Value.ID},1]
					return TRUE
				}
			}
			while ${Crystal:Next(exists)}
		}

		return TRUE
	}

	member:bool LoadOptimalAmmo(string AmmoName)
	{
		variable index:item Plasmas
		variable iterator Plasma

		if ${MyShip.Module[${ModuleID}].IsReloading}
			return FALSE

		if ${AmmoName.Find[${MyShip.Module[${ModuleID}].Charge.Type}]}
		{
			return TRUE
		}
		else
		{
			MyShip.Module[${ModuleID}]:GetAvailableAmmo[Plasmas]

			if ${Plasmas.Used} == 0
			{
				UI:Update["obj_Module", "No Ammo available - dreadful - also, annoying", "o"]
			}

			Plasmas:GetIterator[Plasma]

			if ${Plasma:First(exists)}
			do
			{
				if ${AmmoName.Find[${Plasma.Value.Name}](exists)}
				{
					UI:Update["obj_Module", "Switching Ammo to ${Plasma.Value.Name}"]
					MyShip.Module[${ModuleID}]:ChangeAmmo[${Plasma.Value.ID},1]
					return TRUE
				}
			}
			while ${Plasma:Next(exists)}
		}

		return FALSE
	}


	member:bool ActivateOn(int64 newTarget)
	{
		if ${newTarget} == -1 || ${newTarget} == 0
		{
			MyShip.Module[${ModuleID}]:Activate
		}
		else
		{
			if ${Entity[${newTarget}](exists)} && ${Entity[${newTarget}].IsLockedTarget}
			{
				MyShip.Module[${ModuleID}]:Activate[${newTarget}]
			}
			else
			{
				Activated:Set[FALSE]
				CurrentTarget:Set[-1]
				This:Clear
				return TRUE
			}
		}
		Activated:Set[TRUE]
		CurrentTarget:Set[${newTarget}]
		return TRUE
	}

	member:bool WaitTillActive(int countdown)
	{
		if ${countdown} > 0
		{
			This:SetStateArgs[${Math.Calc[${countdown}-1]}]
			return ${MyShip.Module[${ModuleID}].IsActive}
		}
		return TRUE
	}

	member:bool DeactivatePercent(int Percent=100)
	{
		if ${Percent} == 100
		{
			return TRUE
		}
		if  ${Math.Calc[((${EVETime.AsInt64} - ${MyShip.Module[${ModuleID}].TimeLastClicked.AsInt64}) / ${MyShip.Module[${ModuleID}].ActivationTime}) * 100]} > ${Percent}
		{
			MyShip.Module[${ModuleID}]:Deactivate
			Deactivated:Set[TRUE]
			This:Clear
			This:InsertState["WaitTillInactive", 50, 0]
			return TRUE
		}
		return FALSE
	}

	member:bool WaitTillInactive(int Count = -1)
	{
		if ${Count} > 50
		{
			MyShip.Module[${ModuleID}]:Deactivate
			This:InsertState["WaitTillInactive", 50, 0]
			return TRUE
		}
		if ${MyShip.Module[${ModuleID}].IsActive}
		{
			if ${Count} >= 0
			{
				This:InsertState["WaitTillInactive", 50, ${Count:Inc}]
				return TRUE
			}
			return FALSE
		}
		Activated:Set[FALSE]
		Deactivated:Set[FALSE]
		CurrentTarget:Set[-1]
		return TRUE
	}

	member:float Range()
	{
		if ${MyShip.Module[${ModuleID}].TransferRange(exists)}
		{
			return ${MyShip.Module[${ModuleID}].TransferRange}
		}
		if ${MyShip.Module[${ModuleID}].ShieldTransferRange(exists)}
		{
			return ${MyShip.Module[${ModuleID}].ShieldTransferRange}
		}
		if ${MyShip.Module[${ModuleID}].OptimalRange(exists)}
		{
			if ${MyShip.Module[${ModuleID}].AccuracyFalloff(exists)}
				return ${Math.Calc[${MyShip.Module[${ModuleID}].OptimalRange}+${MyShip.Module[${ModuleID}].AccuracyFalloff}]}
			return ${MyShip.Module[${ModuleID}].OptimalRange}
		}
		else
		{
			return ${Math.Calc[${MyShip.Module[${ModuleID}].Charge.MaxFlightTime} * ${MyShip.Module[${ModuleID}].Charge.MaxVelocity}]}
		}
	}

	member:string GetFallthroughObject()
	{
		return "MyShip.Module[${ModuleID}]"
	}

}