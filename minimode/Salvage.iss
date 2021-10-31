objectdef obj_Configuration_Salvage inherits obj_Base_Configuration
{
	method Initialize()
	{
		This[parent]:Initialize["Salvage"]
	}

	method Set_Default_Values()
	{
		This.CommonRef:AddSetting[LockCount, 2]
		This.CommonRef:AddSetting[Size, "Small"]
	}

	Setting(int, LockCount, SetLockCount)
	Setting(string, Size, SetSize)
	Setting(bool, SalvageYellow, SetSalvageYellow)
}


objectdef obj_Salvage inherits obj_StateQueue
{
	variable obj_Configuration_Salvage Config
	variable obj_LootCans LootCans

	; Wreck list to apply tractor beams/salvagers on them
	variable obj_TargetList WrecksToLock

	; Wreck list for looting
	variable obj_TargetList WrecksNoLock
	variable bool IsBusy

	method Initialize()
	{
		This[parent]:Initialize
		DynamicAddMiniMode("Salvage", "Salvage")
		PulseFrequency:Set[500]
	}

	method Start()
	{
		This:UpdateWreckToLockQuery
		This:UpdateWreckNoLockQuery
		This:QueueState["Updated"]
		This:QueueState["Salvage"]
		LootCans:Enable
	}

	method Stop()
	{
		This.IsBusy:Set[FALSE]
		Busy:UnsetBusy["Salvage"]
		WrecksToLock.AutoLock:Set[FALSE]
		WrecksNoLock.AutoLock:Set[FALSE]
		LootCans:Disable
		This:Clear
	}

	method UpdateWreckToLockQuery()
	{
		variable string Size
		if ${Config.Size.Equal[Small]}
		{
			; BUG of ISXEVE: Type is just 'Wreck' for all wrecks. Should contain more info.
			Size:Set["&& (Type =- \"Small\" || Type =- \"Medium\" || Type =- \"Large\" || Type =- \"Cargo Container\")"]
		}
		elseif ${Config.Size.Equal[Medium]}
		{
			Size:Set["&& (Type =- \"Medium\" || Type =- \"Large\" || Type =- \"Cargo Container\")"]
		}
		else
		{
			Size:Set["&& (Type =- \"Large\" || Type =- \"Cargo Container\")"]
		}

		WrecksToLock:ClearTargetExceptions
		WrecksToLock:ClearQueryString

		variable string group = "(Group = \"Wreck\")"
		if ${Ship.ModuleList_TractorBeams.Count} > 0 && ${Ship.ModuleList_Salvagers.Count} > 0
		{
			group:Set["(Group = \"Wreck\" || ((Group = \"Cargo Container\") && (Distance >= 2500)))"]
		}
		elseif ${Ship.ModuleList_Salvagers.Count} > 0
		{
			group:Set["(Group = \"Wreck\")"]
		}
		elseif ${Ship.ModuleList_TractorBeams.Count} > 0
		{
			group:Set["((Group = \"Cargo Container\") && (Distance >= 2500))"]
		}
		elseif ${Me.InSpace}
		{
			UI:Update["Salvage", " Salvage mini module has no equipments to do anything", "r"]
		}

		; Ship.ModuleList.Count is NULL at early stage
		variable string canLoot = "&& !IsWreckEmpty && !IsWreckViewed"
		if ${Ship.ModuleList_Salvagers.Count} > 0
		{
			canLoot:Set[""]
		}

		variable string lootYellow = "&& HaveLootRights"
		if ${Config.SalvageYellow}
		{
			lootYellow:Set[""]
		}

		; echo "${group} ${canLoot} ${lootYellow} && !IsMoribund ${Size}"
		WrecksToLock:AddQueryString["${group} ${canLoot} ${lootYellow} && !IsMoribund ${Size}"]
		variable int maxLockTarget = ${MyShip.MaxLockedTargets}

		if ${Me.MaxLockedTargets} < ${MyShip.MaxLockedTargets}
		{
			maxLockTarget:Set[${Me.MaxLockedTargets}]
		}

		if ${Config.LockCount} < ${maxLockTarget}
		{
			maxLockTarget:Set[${Config.LockCount}]
		}

		variable float maxLockRange = ${Ship.ModuleList_TractorBeams.Range}
		if ${maxLockRange} > ${MyShip.MaxTargetRange}
		{
			maxLockRange:Set[${MyShip.MaxTargetRange}]
		}

		WrecksToLock.MaxRange:Set[${maxLockRange}]
		WrecksToLock.MinLockCount:Set[${maxLockTarget}]
		WrecksToLock.LockOutOfRange:Set[FALSE]
		WrecksToLock.AutoLock:Set[TRUE]
		WrecksToLock:RequestUpdate
	}

	method UpdateWreckNoLockQuery()
	{
		variable string Size
		if ${Config.Size.Equal[Small]}
		{
			; BUG of ISXEVE: Type is just 'Wreck' for all wrecks. Should contain more info.
			Size:Set["&& (Type =- \"Small\" || Type =- \"Medium\" || Type =- \"Large\" || Type =- \"Cargo Container\")"]
		}
		elseif ${Config.Size.Equal[Medium]}
		{
			Size:Set["&& (Type =- \"Medium\" || Type =- \"Large\" || Type =- \"Cargo Container\")"]
		}
		else
		{
			Size:Set["&& (Type =- \"Large\" || Type =- \"Cargo Container\")"]
		}

		WrecksNoLock:ClearTargetExceptions
		WrecksNoLock:ClearQueryString

		variable string group = "(Group = \"Wreck\" || (Group = \"Cargo Container\"))"
		variable string canLoot = "&& !IsWreckEmpty && !IsWreckViewed"
		variable string lootYellow = "&& HaveLootRights"
		if ${Config.SalvageYellow}
		{
			lootYellow:Set[""]
		}

		WrecksNoLock:AddQueryString["${group} ${canLoot} ${lootYellow} && !IsMoribund ${Size} && Distance < 2500"]
		WrecksNoLock.AutoLock:Set[FALSE]
		WrecksNoLock:RequestUpdate
	}

	member:bool Updated()
	{
		if ${WrecksToLock.Updated}&& ${WrecksNoLock.Updated}
			return TRUE
		return FALSE
	}

	member:bool Salvage()
	{
		if !${Client.InSpace} || ${Me.ToEntity.Mode} == 3
		{
			return FALSE
		}

		variable iterator wreckIterator
		WrecksToLock:RequestUpdate
		WrecksToLock.LockedTargetList:GetIterator[wreckIterator]
		if ${wreckIterator:First(exists)}
		{
			This.IsBusy:Set[TRUE]
			Busy:SetBusy["Salvage"]
			do
			{
				if ${wreckIterator.Value.ID(exists)} && !${wreckIterator.Value.IsMoribund} && ${wreckIterator.Value.IsLockedTarget}
				{
					; Abandon targets of no value
					if (!${Config.SalvageYellow} && !${wreckIterator.Value.HaveLootRights}) || \
						((${wreckIterator.Value.IsWreckEmpty} || ${wreckIterator.Value.IsWreckViewed}) && ${Ship.ModuleList_Salvagers.Count} == 0)
					{
						wreckIterator.Value:UnlockTarget
						return FALSE
					}

					; Salvage
					if !${Ship.ModuleList_Salvagers.IsActiveOn[${wreckIterator.Value.ID}]} && \
						${wreckIterator.Value.Distance} < ${Ship.ModuleList_Salvagers.Range} && \
						${Ship.ModuleList_Salvagers.InactiveCount} > 0 && \
						${wreckIterator.Value.GroupID} == GROUP_WRECK
					{
						if ${wreckIterator.Value.IsWreckEmpty} && \
							${Ship.ModuleList_TractorBeams.IsActiveOn[${wreckIterator.Value.ID}]} && \
							${MyShip.ToEntity.Velocity} < 20
						{
							Ship.ModuleList_TractorBeams:DeactivateOn[${wreckIterator.Value.ID}]
						}

						UI:Update["Salvage", "Activating salvager - \ap${wreckIterator.Value.Name}"]
						Ship.ModuleList_Salvagers:ActivateOne[${wreckIterator.Value.ID}]
						return FALSE
					}

					; Tractor beam
					if ${wreckIterator.Value.Distance} >= ${Ship.ModuleList_TractorBeams.Range}
					{
						wreckIterator.Value:UnlockTarget
						return FALSE
					}
					elseif ${wreckIterator.Value.Distance} < ${Ship.ModuleList_TractorBeams.Range} && \
							${wreckIterator.Value.Distance} >= 2500
					{
						if !${Ship.ModuleList_TractorBeams.IsActiveOn[${wreckIterator.Value.ID}]} && \
						   ${Ship.ModuleList_TractorBeams.InactiveCount} > 0
						{
							UI:Update["Salvage", "Activating tractor beam - \ap${wreckIterator.Value.Name}"]
							Ship.ModuleList_TractorBeams:ActivateOne[${wreckIterator.Value.ID}]
							return FALSE
						}
					}
					elseif ${Ship.ModuleList_TractorBeams.IsActiveOn[${wreckIterator.Value.ID}]} && \
							${MyShip.ToEntity.Velocity} < 20
					; Within 2500
					{
						Ship.ModuleList_TractorBeams:DeactivateOn[${wreckIterator.Value.ID}]
						return FALSE
					}
				}
			}
			while ${wreckIterator:Next(exists)}
		}
		; Something is no locked
		elseif ${Wrecks.TargetList.Used}
		{
			This.IsBusy:Set[FALSE]
			Busy:UnsetBusy["Salvage"]
			return FALSE
		}
		else
		{
			This.IsBusy:Set[FALSE]
			Busy:UnsetBusy["Salvage"]
			This:UpdateWreckToLockQuery
			This:UpdateWreckNoLockQuery
			This:QueueState["Updated"]
			This:QueueState["Salvage"]
			return TRUE
		}
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
		variable iterator wreckIterator
		variable index:item cargo
		variable iterator cargoIterator

		if !${Client.InSpace} || ${Me.ToEntity.Mode} == 3
		{
			return FALSE
		}

		if !${EVEWindow[Inventory](exists)}
		{
			EVE:Execute[OpenInventory]
			return FALSE
		}

		Salvage.WrecksNoLock:RequestUpdate
		Salvage.WrecksNoLock.TargetList:GetIterator[wreckIterator]
		if ${wreckIterator:First(exists)}
		{
			do
			{
				if !${wreckIterator.Value(exists)} || \
					${wreckIterator.Value.Distance} >= 2500 || \
					${wreckIterator.Value.IsWreckEmpty} || \
					${wreckIterator.Value.IsWreckViewed} || \
					${wreckIterator.Value.IsMoribund}
				{
					continue
				}

				; BUG of ISXEVE: Finding windows, getting items and looting all are not working for Wrecks, only for cargos.
				if !${EVEWindow[Inventory].ChildWindow[${wreckIterator.Value}](exists)}
				{
					UI:Update["Salvage", "Opening - \ap${wreckIterator.Value.Name}"]
					wreckIterator.Value:Open
					return FALSE
				}

				wreckIterator.Value:GetCargo[cargo]
				cargo:GetIterator[cargoIterator]
				if ${cargoIterator:First(exists)}
				{
					do
					{
						if ${cargoIterator.Value.IsContraband}
						{
							Salvage.WrecksNoLock:AddTargetException[${wreckIterator.Value.ID}]
							return FALSE
						}
					}
					while ${cargoIterator:Next(exists)}
				}
				EVEWindow[Inventory]:LootAll
				if ${wreckIterator.Value.GroupID} == GROUP_CARGOCONTAINER || ${Ship.ModuleList_Salvagers.Count} == 0
				{
					wreckIterator.Value:UnlockTarget
				}
				This:InsertState["Loot"]
				This:InsertState["Stack"]
				return TRUE
			}
			while ${wreckIterator:Next(exists)}
		}
		return FALSE
	}

	member:bool Stack()
	{
		EVE:StackItems[MyShip, CargoHold]
		return TRUE
	}
}