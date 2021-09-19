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

objectdef obj_Ship inherits obj_StateQueue
{
	variable int RetryUpdateModuleList=1

	variable index:string ModuleLists
	variable collection:uint ModuleQueries

	method Initialize(int64 ID)
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]
		This:AddModuleList[ArmorProjectors, "ToItem.GroupID = GROUP_ARMOR_PROJECTOR"]
		This:AddModuleList[ShieldTransporters, "ToItem.GroupID = GROUP_SHIELD_TRANSPORTER"]
		This:AddModuleList[MiningLaser, "ToItem.GroupID = GROUP_MININGLASER || ToItem.GroupID = GROUP_STRIPMINER || ToItem.GroupID = GROUP_FREQUENCYMININGLASER"]
		This:AddModuleList[Weapon, "ToItem.GroupID = GROUP_PRECURSORWEAPON || ToItem.GroupID = GROUP_ENERGYWEAPON || ToItem.GroupID = GROUP_PROJECTILEWEAPON || ToItem.GroupID = GROUP_HYBRIDWEAPON || ToItem.GroupID = GROUP_MISSILELAUNCHERRAPIDHEAVY || ToItem.GroupID = GROUP_MISSILELAUNCHER || ToItem.GroupID = GROUP_MISSILELAUNCHERASSAULT || ToItem.GroupID = GROUP_MISSILELAUNCHERBOMB || ToItem.GroupID = GROUP_MISSILELAUNCHERCITADEL || ToItem.GroupID = GROUP_MISSILELAUNCHERCRUISE || ToItem.GroupID = GROUP_MISSILELAUNCHERDEFENDER || ToItem.GroupID = GROUP_MISSILELAUNCHERHEAVY || ToItem.GroupID = GROUP_MISSILELAUNCHERHEAVYASSAULT || ToItem.GroupID = GROUP_MISSILELAUNCHERROCKET || ToItem.GroupID = GROUP_MISSILELAUNCHERTORPEDO || ToItem.GroupID = GROUP_MISSILELAUNCHERSTANDARD"]
		This:AddModuleList[ECCM, "ToItem.GroupID = GROUP_ECCM"]
		This:AddModuleList[ActiveResists, "ToItem.GroupID = GROUP_SHIELD_HARDENER || ToItem.GroupID = GROUP_ARMOR_HARDENERS || ToItem.GroupID = GROUP_ARMOR_RESISTANCE_SHIFT_HARDENER"]
		This:AddModuleList[DamageControl, "ToItem.GroupID = GROUP_DAMAGE_CONTROL"]
		This:AddModuleList[Regen_Shield, "ToItem.GroupID = GROUP_SHIELD_BOOSTER"]
		This:AddModuleList[Repair_Armor, "ToItem.GroupID = GROUP_ARMOR_REPAIRERS"]
		This:AddModuleList[Repair_Hull, "ToItem.GroupID = NONE"]
		This:AddModuleList[AB_MWD, "ToItem.GroupID = GROUP_AFTERBURNER"]
		; Supress isxeve error log output.
		; This:AddModuleList[Passive, "!IsActivatable"]
		This:AddModuleList[Salvagers, "ToItem.GroupID = GROUP_SALVAGER"]
		This:AddModuleList[TractorBeams, "ToItem.GroupID = GROUP_TRACTOR_BEAM"]
		This:AddModuleList[Cloaks, "ToItem.GroupID = GROUP_CLOAKING_DEVICE"]
		This:AddModuleList[Scrambler, "ToItem.GroupID = GROUP_SCRAMBLER"]
		This:AddModuleList[SurveyScanner, "ToItem.GroupID = GROUP_SURVEYSCANNER"]
		This:AddModuleList[CommandBurst, "ToItem.GroupID = GROUP_COMMANDBURST"]
		This:AddModuleList[StasisWeb, "ToItem.GroupID = GROUP_STASIS_WEB"]
		This:AddModuleList[StasisGrap, "ToItem.GroupID = GROUP_STASIS_GRAPPLER"]
		This:AddModuleList[SensorBoost, "ToItem.GroupID = GROUP_SENSORBOOSTER"]
		This:AddModuleList[TargetPainter, "ToItem.GroupID = GROUP_TARGETPAINTER"]
		This:AddModuleList[EnergyVampire, "ToItem.GroupID = GROUP_ENERGY_VAMPIRE"]
		This:AddModuleList[TrackingComputer, "ToItem.GroupID = GROUP_TRACKINGCOMPUTER || ToItem.GroupID = GROUP_MISSILEGUIDANCECOMPUTER"]
		This:AddModuleList[GangLinks, "ToItem.GroupID = GROUP_GANGLINK"]
		This:AddModuleList[DroneControlUnit, "ToItem.GroupID = GROUP_DRONECONTROLUNIT"]
		This:AddModuleList[EnergyTransfer, "ToItem.GroupID = GROUP_ENERGY_TRANSFER"]
		This:AddModuleList[AutoTarget, "ToItem.GroupID = GROUP_AUTOMATED_TARGETING_SYSTEM"]
		This:AddModuleList[Siege, "ToItem.GroupID = GROUP_SIEGEMODULE"]
		This:AddModuleList[TargetModules, "MaxRange>0"]
		This:Clear
		This:QueueState["WaitForSpace"]
		This:QueueState["UpdateModules"]
	}

	method AddModuleList(string Name, string QueryString)
	{
		This.ModuleLists:Insert[${Name}]
		This.ModuleQueries:Set[${This.ModuleLists.Used}, ${LavishScript.CreateQuery[${QueryString.Escape}]}]
		declarevariable ModuleList_${Name} obj_ModuleList object
		This:Clear
		This:QueueState["WaitForSpace"]
		This:QueueState["UpdateModules"]
	}

	member:bool WaitForSpace()
	{
		if ${Client.InSpace}
		{
			return TRUE
		}
		return FALSE
	}

	member:bool UpdateModules()
	{
		variable iterator List
		variable index:module ModuleList
		ModuleLists:GetIterator[List]

		UI:Update["Ship", "Update Called"]

		if !${Client.InSpace}
		{
			UI:Update["Ship", "UpdateModules called while in station", "o"]
			RetryUpdateModuleList:Set[1]
			return
		}

		/* build module lists */
		ModuleList:Clear

		if ${List:First(exists)}
			do
			{
				This.ModuleList_${List.Value}:Clear
			}
			while ${List:Next(exists)}

		MyShip:GetModules[ModuleList]

		if !${ModuleList.Used} && ${MyShip.HighSlots} > 0
		{
			UI:Update["Ship", "UpdateModuleList - No modules found. Retrying in a few seconds", "o"]
			UI:Update["Ship", "If this ship has slots, you must have at least one module equipped, of any type.", "o"]
			RetryUpdateModuleList:Inc
			if ${RetryUpdateModuleList} >= 10
			{
				return TRUE
			}
			return FALSE
		}
		RetryUpdateModuleList:Set[0]

		variable iterator ModuleIter

		ModuleList:GetIterator[ModuleIter]
		if ${ModuleIter:First(exists)}
		do
		{
			if !${ModuleIter.Value(exists)}
			{
				UI:Update["Ship", "UpdateModuleList - Null module found. Retrying in a few seconds.", "o"]
				RetryUpdateModuleList:Inc
				return FALSE
			}
			if ${List:First(exists)}
			{
				do
				{
					if ${LavishScript.QueryEvaluate[${This.ModuleQueries.Element[${List.Key}]}, ModuleIter.Value]}
					{
						ModuleList_${List.Value}:Insert[${ModuleIter.Value.ID}]
					}
				}
				while ${List:Next(exists)}
			}
		}
		while ${ModuleIter:Next(exists)}

		UI:Update["Ship", "Ship Module Inventory", "y"]

		if ${List:First(exists)}
			do
			{
				This.ModuleList_${List.Value}:GetIterator[ModuleIter]
				if ${ModuleIter:First(exists)}
				{
					UI:Update["Ship", "${List.Value}:", "g"]
					do
					{
						UI:Update["Ship", " Slot: ${ModuleIter.Value.ToItem.Slot} ${ModuleIter.Value.ToItem.Name}", "-g"]
					}
					while ${ModuleIter:Next(exists)}
				}
			}
			while ${List:Next(exists)}

		if ${This.ModuleList_AB_MWD.Used} > 1
		{
			UI:Update["Ship", "Warning: More than 1 Afterburner or MWD was detected, I will only use the first one.", "o"]
		}
		This:QueueState["WaitForStation"]
		This:QueueState["WaitForSpace"]
		This:QueueState["UpdateModules"]
		return TRUE
	}

	member:bool WaitForStation()
	{
		if ${Me.InStation}
		{
			return TRUE
		}
		return FALSE
	}

	member:bool IsClosebyFrigate(int64 targetID)
	{
		if (${Entity[${targetID}].Group.Find[Frigate]} && ${Entity[${targetID}].Distance} < 15000) || \
		   (${Entity[${targetID}].Group.Find[Destroyer]} && ${Entity[${targetID}].Distance} < 10000)
		{
			return TRUE
		}
		else
		{
			return FALSE
		}
	}

	member:bool IsHardToDealWithTarget(int64 targetID)
	{
		; TODO Add issile judgement
		return ${This.IsClosebyFrigate[${targetID}]}
	}

}
