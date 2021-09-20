objectdef obj_Configuration_Salvage inherits obj_Base_Configuration
{
	method Initialize()
	{
		This[parent]:Initialize["Salvage"]
	}

	method Set_Default_Values()
	{
		This.CommonRef:AddSetting[LockCount, 2]
		This.CommonRef:AddSetting[Size,"Small"]



	}

	Setting(int, LockCount, SetLockCount)
	Setting(string, Size, SetSize)
	Setting(bool, SalvageYellow, SetSalvageYellow)

}



objectdef obj_Salvage inherits obj_StateQueue
{
	variable obj_Configuration_Salvage Config
	variable obj_LootCans LootCans

	variable obj_TargetList Wrecks
	variable bool IsBusy


	method Initialize()
	{
		This[parent]:Initialize
		DynamicAddMiniMode("Salvage", "Salvage")
		PulseFrequency:Set[500]
	}


	method Start()
	{
		variable string Size
		if ${Config.Size.Equal[Small]}
		{
			Size:Set[&& (Type =- \"Small\" || Type =- \"Medium\" || Type =- \"Large\" || Type =- \"Cargo Container\")]
		}
		elseif ${Config.Size.Equal[Medium]}
		{
			Size:Set[&& (Type =- \"Medium\" || Type =- \"Large\" || Type =- \"Cargo Container\")]
		}
		else
		{
			Size:Set[&& (Type =- \"Large\" || Type =- \"Cargo Container\")]
		}

		Wrecks:ClearTargetExceptions
		Wrecks:ClearQueryString

		if ${Config.SalvageYellow}
		{
			echo SalvageYellow
			Wrecks:AddQueryString["(Group = \"Wreck\" || Group = \"Cargo Container\") && !IsAbandoned && !IsMoribund ${Size}"]
		}
		else
		{
			Wrecks:AddQueryString["(Group = \"Wreck\" || Group = \"Cargo Container\") && HaveLootRights && !IsAbandoned && !IsMoribund ${Size}"]
		}

		Wrecks:RequestUpdate
		This:QueueState["Updated"]
		This:QueueState["Salvage"]
	}

	method Stop()
	{
		This.IsBusy:Set[FALSE]
		Busy:UnsetBusy["Salvage"]
		Wrecks.AutoLock:Set[FALSE]
		This:Clear
	}

	member:bool Updated()
	{
		return ${Wrecks.Updated}
	}

	member:bool Salvage()
	{
		if !${Client.InSpace} ||!${Client.InSpace}
		{
			return FALSE
		}

		variable iterator TargetIterator
		variable queue:int LootRangeAndTractored
		variable int MaxTarget = ${MyShip.MaxLockedTargets}
		variable int ClosestTractorKey
		variable bool ReactivateTractor = FALSE

		if ${Me.MaxLockedTargets} < ${MyShip.MaxLockedTargets}
		{
			MaxTarget:Set[${Me.MaxLockedTargets}]
		}
		if ${Config.LockCount} < ${MaxTarget}
		{
			MaxTarget:Set[${Config.LockCount}]
		}
		variable float MaxRange = ${Ship.ModuleList_TractorBeams.Range}
		if ${MaxRange} > ${MyShip.MaxTargetRange}
		{
			MaxRange:Set[${MyShip.MaxTargetRange}]
		}
		Wrecks.MaxRange:Set[${MaxRange}]
		Wrecks.MinLockCount:Set[${MaxTarget}]
		Wrecks.LockOutOfRange:Set[FALSE]
		Wrecks.AutoLock:Set[TRUE]
		Wrecks:RequestUpdate

		Wrecks.LockedTargetList:GetIterator[TargetIterator]
		if ${TargetIterator:First(exists)}
		{
			This.IsBusy:Set[TRUE]
			Busy:SetBusy["Salvage"]
			LootCans:Enable
			do
			{
				if ${TargetIterator.Value.ID(exists)} && ${TargetIterator.Value.IsLockedTarget}
				{
					; Abandon targets of no value
					if ${TargetIterator.Value.IsAbandoned} || \
						!${TargetIterator.Value.HaveLootRights} || \
						(${TargetIterator.Value.IsWreckEmpty} && ${Ship.ModuleList_Salvagers.Count} == 0)
					{
						TargetIterator.Value:Abandon
						TargetIterator.Value:UnlockTarget
						return FALSE
					}

					; Salvage
					if !${Ship.ModuleList_Salvagers.IsActiveOn[${TargetIterator.Value.ID}]} && \
						${TargetIterator.Value.Distance} < ${Ship.ModuleList_Salvagers.Range} && \
						${Ship.ModuleList_Salvagers.Count} > 0 && \
						${Ship.ModuleList_Salvagers.InactiveCount} > 0 && \
						${TargetIterator.Value.Group.Equal["Wreck"]}
					{
						UI:Update["Salvage", "Activating salvager - \ap${TargetIterator.Value.Name}"]
						Ship.ModuleList_Salvagers:Activate[${TargetIterator.Value.ID}]
						return FALSE
					}

					; Tractor beam
					if ${TargetIterator.Value.Distance} >= ${Ship.ModuleList_TractorBeams.Range}
					{
						TargetIterator.Value:UnlockTarget
						return FALSE
					}
					elseif ${TargetIterator.Value.Distance} < ${Ship.ModuleList_TractorBeams.Range} && \
							${TargetIterator.Value.Distance} >= 2500
					{
						if !${Ship.ModuleList_TractorBeams.IsActiveOn[${TargetIterator.Value.ID}]} && \
						   ${Ship.ModuleList_TractorBeams.InactiveCount} > 0
						{
							UI:Update["Salvage", "Activating tractor beam - \ap${TargetIterator.Value.Name}"]
							Ship.ModuleList_TractorBeams:Activate[${TargetIterator.Value.ID}]
							return FALSE
						}
					}
					elseif ${Ship.ModuleList_TractorBeams.IsActiveOn[${TargetIterator.Value.ID}]}
					; Within 2500
					{
						Ship.ModuleList_TractorBeams:DeactivateOn[${TargetIterator.Value.ID}]
						return FALSE
					}
				}
			}
			while ${TargetIterator:Next(exists)}
		}
		else
		{
			if ${Wrecks.TargetList.Used} > 0
			{
				This.IsBusy:Set[FALSE]
				Busy:UnsetBusy["Salvage"]
			}
			else
			{
				LootCans:Disable
				This.IsBusy:Set[FALSE]
				Busy:UnsetBusy["Salvage"]
				Wrecks.AutoLock:Set[FALSE]
				return FALSE
			}
		}
		return FALSE
	}

}


objectdef obj_LootCans inherits obj_StateQueue
{
	method Initialize()
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]
	}

	method Enable()
	{
		This:QueueState["Loot", 2000]
	}

	method Disable()
	{
		This:Clear
	}

	member:bool Loot()
	{
		variable iterator TargetIterator
		variable index:item TargetCargo
		variable iterator CargoIterator

		if !${Client.InSpace} || ${Me.ToEntity.Mode} == 3
		{
			return FALSE
		}

		if !${EVEWindow[Inventory](exists)}
		{
			EVE:Execute[OpenInventory]
			return FALSE
		}

		Salvage.Wrecks.TargetList:GetIterator[TargetIterator]
		if ${TargetIterator:First(exists)}
		{
			do
			{
				if ${TargetIterator.Value.Distance} > 2500 || \
					${TargetIterator.Value.IsWreckEmpty} || \
					${TargetIterator.Value.IsWreckViewed} || \
					${TargetIterator.Value.IsAbandoned} || \
					!${Entity[${TargetIterator.Value.ID}](exists)}
				{
					continue
				}

				if !${EVEWindow[Inventory].ChildWindow[${TargetIterator.Value}](exists)}
				{
					UI:Update["Salvage", "Opening - \ap${TargetIterator.Value.Name}", "y"]
					TargetIterator.Value:Open
					return FALSE
				}

				Entity[${TargetIterator.Value}]:GetCargo[TargetCargo]
				TargetCargo:GetIterator[CargoIterator]
				if ${CargoIterator:First(exists)}
				{
					do
					{
						if ${CargoIterator.Value.IsContraband} || ${CargoIterator.Value.Volume} > 0.5
						{
							continue
						}
						CargoIterator.Value:MoveTo[${MyShip.ID}, CargoHold]
						return FALSE
					}
					while ${CargoIterator:Next(exists)}
				}
				; EVEWindow[Inventory]:LootAll
				TargetIterator.Value:Abandon
				if ${Entity[${currentLootContainer}].Group.Equal["Cargo Container"]}
					Entity[${TargetIterator.Value.ID}]:UnlockTarget
				This:InsertState["Loot"]
				This:InsertState["Stack"]
				return TRUE
			}
			while ${TargetIterator:Next(exists)}
		}
		return FALSE
	}

	member:bool Stack()
	{
		EVE:StackItems[MyShip, CargoHold]
		return TRUE
	}
}