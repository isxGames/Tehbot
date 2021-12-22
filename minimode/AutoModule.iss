/*

Tehbot  Copyright � 2012  Tehtsuo and Vendan

This file is part of Tehbot.

Tehbot is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Tehbot is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Tehbot.  If not, see <http://www.gnu.org/licenses/>.

*/

objectdef obj_Configuration_AutoModule
{
	variable string SetName = "AutoModule"

	method Initialize()
	{
		if !${BaseConfig.BaseRef.FindSet[${This.SetName}](exists)}
		{
			Logger:Log["obj_Configuration", " ${This.SetName} settings missing - initializing", "o"]
			This:Set_Default_Values[]
		}
		Logger:Log["obj_Configuration", " ${This.SetName}: Initialized", "-g"]
	}

	member:settingsetref CommonRef()
	{
		return ${BaseConfig.BaseRef.FindSet[${This.SetName}]}
	}

	method Set_Default_Values()
	{
		BaseConfig.BaseRef:AddSet[${This.SetName}]
		This.CommonRef:AddSetting[ActiveHardeners, TRUE]
		This.CommonRef:AddSetting[ActiveShieldBoost, 95]
		This.CommonRef:AddSetting[ActiveArmorRepair, 95]
		This.CommonRef:AddSetting[ActiveShieldCap, 35]
		This.CommonRef:AddSetting[ActiveArmorCap, 35]
		This.CommonRef:AddSetting[Cloak, TRUE]
		This.CommonRef:AddSetting[GangLink, TRUE]
		This.CommonRef:AddSetting[SensorBoosters, TRUE]
		This.CommonRef:AddSetting[AutoTarget, TRUE]
		This.CommonRef:AddSetting[TrackingComputers, TRUE]
		This.CommonRef:AddSetting[ECCM, TRUE]
		This.CommonRef:AddSetting[DroneControlUnit, TRUE]
		This.CommonRef:AddSetting[ShieldBoostOverloadThreshold, 50]
		This.CommonRef:AddSetting[ArmorRepairOverloadThreshold, 50]
	}

	Setting(bool, ActiveHardeners, SetActiveHardeners)
	Setting(bool, AlwaysShieldBoost, SetShieldBoost)
	Setting(int, ActiveShieldBoost, SetActiveShieldBoost)
	Setting(int, ActiveShieldCap, SetActiveShieldCap)
	Setting(bool, AlwaysArmorRepair, SetArmorRepair)
	Setting(int, ActiveArmorRepair, SetActiveArmorRepair)
	Setting(int, ActiveArmorCap, SetActiveArmorCap)
	Setting(bool, Cloak, SetCloak)
	Setting(bool, GangLink, SetGangLink)
	Setting(bool, SensorBoosters, SetSensorBoosters)
	Setting(bool, AutoTarget, SetAutoTarget)
	Setting(bool, TrackingComputers, SetTrackingComputers)
	Setting(bool, ECCM, SetECCM)
	Setting(bool, DroneControlUnit, SetDroneControlUnit)
	Setting(int, ShieldBoostOverloadThreshold, SetShieldBoostOverloadThreshold)
	Setting(int, ArmorRepairOverloadThreshold, SetArmorRepairOverloadThreshold)
}

objectdef obj_AutoModule inherits obj_StateQueue
{
	variable obj_Configuration_AutoModule Config
	variable bool SafetyOveride=FALSE
	variable bool DropCloak=FALSE

	method Initialize()
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]
		This.PulseFrequency:Set[100]
		DynamicAddMiniMode("AutoModule", "AutoModule")
	}

	method Start()
	{
		This:QueueState["AutoModule"]
	}

	method Stop()
	{
		This:Clear
	}

	variable int lastArmorRepActivate = 0
	member:bool AutoModule()
	{
		variable index:module modules
		variable iterator m

		if !${Client.InSpace} || ${SafetyOveride}
		{
			return FALSE
		}
		variable string cloak
		variable bool cloakon
		MyShip:GetModules[modules]
		modules:GetIterator[m]
		if ${m:First(exists)}
		{
			do
			{
				if ${m.Value.ToItem.Group.Equal[Cloaking Device]}
				{
					cloak:Set[${m.Value.Slot}]
					if ${m.Value.IsActive} && !${m.Value.IsDeactivating}
						cloakon:Set[TRUE]
				}
			}
			while ${m:Next(exists)}
		}

		if ${cloak.NotNULLOrEmpty} && ${Config.Cloak}
		{
			if ${This.DropCloak}
			{
				if ${cloakon}
					MyShip.Module[${cloak}]:Deactivate
			}
			elseif !${cloakon} && !${Entity[Distance < 2000 && !IsPC]} && !${Entity[IsTargetingMe]} && !${Me.ToEntity.IsCloaked}
			{
				MyShip.Module[${cloak}]:Activate
			}
			elseif ${Me.ToEntity.IsCloaked}
			{
				variable index:int DestinationList
				EVE:GetToDestinationPath[DestinationList]
				if ${Entity[Distance <= 2500 && Name = \"${Universe[${DestinationList[1]}].Name}\"]} && ${cloakon}
				{
					MyShip.Module[${cloak}]:Deactivate
				}
				if ${Entity[Distance <= 2500 && Name = \"${EVE.Station[${DestinationList[1]}].Name}\"]} && ${cloakon}
				{
					MyShip.Module[${cloak}]:Deactivate
				}
				return FALSE
			}
		}

		if ${Ship.ModuleList_Regen_Shield.InactiveCount} && \
			((${MyShip.ShieldPct.Int} < ${Config.ActiveShieldBoost} && ${MyShip.CapacitorPct.Int} > ${Config.ActiveShieldCap}) || \
			(${MyShip.ShieldPct.Int} < 90 && ${MyShip.CapacitorPct.Int} > 15 && ${FightOrFlight.IsEngagingGankers}) || \
			${Config.AlwaysShieldBoost})
		{
			if ${MyShip.ShieldPct.Int} < ${Config.ShieldBoostOverloadThreshold}
			{
				; 50 is module hp percent not the shield percent.
				Ship.ModuleList_Regen_Shield:SetOverloadHPThreshold[50]
			}
			elseif !${FightOrFlight.IsEngagingGankers}
			{
				Ship.ModuleList_Regen_Shield:SetOverloadHPThreshold[100]
			}
			Ship.ModuleList_Regen_Shield:ActivateAll
		}
		if ${Ship.ModuleList_Regen_Shield.ActiveCount} && \
			!${Config.AlwaysShieldBoost} && \
			(((${MyShip.ShieldPct.Int} > ${Config.ActiveShieldBoost} || ${MyShip.CapacitorPct.Int} < ${Config.ActiveShieldCap}) && !${FightOrFlight.IsEngagingGankers}) || \
			((${MyShip.ShieldPct.Int} >= 90 || ${MyShip.CapacitorPct.Int} <= 15) && ${FightOrFlight.IsEngagingGankers}))
		{
			Ship.ModuleList_Regen_Shield:SetOverloadHPThreshold[100]
			Ship.ModuleList_Regen_Shield:DeactivateAll
		}

		if ${Ship.ModuleList_Repair_Armor.InactiveCount} && \
			((${MyShip.ArmorPct.Int} < ${Config.ActiveArmorRepair} && ${MyShip.CapacitorPct.Int} > ${Config.ActiveArmorCap}) || \
			(${MyShip.ArmorPct.Int} < 85 && ${MyShip.CapacitorPct.Int} > 15 && ${FightOrFlight.IsEngagingGankers}) || \
			${Config.AlwaysArmorRepair})
		{
			if ${MyShip.ArmorPct.Int} < ${Config.ArmorRepairOverloadThreshold}
			{
				; 50 is module hp percent not the armor percent.
				Ship.ModuleList_Repair_Armor:SetOverloadHPThreshold[50]
			}
			elseif !${FightOrFlight.IsEngagingGankers}
			{
				Ship.ModuleList_Repair_Armor:SetOverloadHPThreshold[100]
			}

			Ship.ModuleList_Repair_Armor:ActivateAll
			; lastArmorRepActivate:Set[${Math.Calc[${LavishScript.RunningTime} + 3000]}]
		}

		if ${Ship.ModuleList_Repair_Armor.ActiveCount} && \
			!${Config.AlwaysArmorRepair} && \
			(((${MyShip.ArmorPct.Int} > ${Config.ActiveArmorRepair} || ${MyShip.CapacitorPct.Int} < ${Config.ActiveArmorCap}) && !${FightOrFlight.IsEngagingGankers}) || \
			((${MyShip.ArmorPct.Int} >= 85 || ${MyShip.CapacitorPct.Int} <= 15) && ${FightOrFlight.IsEngagingGankers}))
		{
			Ship.ModuleList_Repair_Armor:SetOverloadHPThreshold[100]
			Ship.ModuleList_Repair_Armor:DeactivateAll
		}

		if ${Ship.ModuleList_ActiveResists.Count} && ${Config.ActiveHardeners}
		{
			Ship.ModuleList_ActiveResists:ActivateAll
		}

		if ${Ship.ModuleList_GangLinks.ActiveCount} < ${Ship.ModuleList_GangLinks.Count} && ${Me.ToEntity.Mode} != MOVE_WARPING && ${Config.GangLink}
		{
			Ship.ModuleList_GangLinks:ActivateAll
		}

		if ${Ship.ModuleList_SensorBoost.ActiveCount} < ${Ship.ModuleList_SensorBoost.Count} && ${Config.SensorBoosters}
		{
			Ship.ModuleList_SensorBoost:ActivateAll
		}

		if ${Ship.ModuleList_AutoTarget.ActiveCount} < ${Ship.ModuleList_AutoTarget.Count} && ${Config.AutoTarget}
		{
			Ship.ModuleList_AutoTarget:ActivateAll
		}

		if ${Ship.ModuleList_TrackingComputer.ActiveCount} < ${Ship.ModuleList_TrackingComputer.Count} && ${Config.TrackingComputers}
		{
			Ship.ModuleList_TrackingComputer:ActivateFor[TARGET_ANY]
		}

		if ${Ship.ModuleList_ECCM.ActiveCount} < ${Ship.ModuleList_ECCM.Count} && ${Config.ECCM}
		{
			Ship.ModuleList_ECCM:ActivateAll
		}

		if ${Ship.ModuleList_DroneControlUnit.ActiveCount} < ${Ship.ModuleList_DroneControlUnit.Count} && ${Config.DroneControlUnit}
		{
			Logger:Log["AutoModule", "Activating DroneControlUnit", "g"]
			Ship.ModuleList_DroneControlUnit:ActivateAll
		}

		return FALSE
	}

}