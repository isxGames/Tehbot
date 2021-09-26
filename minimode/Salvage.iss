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
		This:UpdateWreckQuery
		This:QueueState["Updated"]
		This:QueueState["Salvage"]
		LootCans:Enable
	}

	method Stop()
	{
		This.IsBusy:Set[FALSE]
		Busy:UnsetBusy["Salvage"]
		Wrecks.AutoLock:Set[FALSE]
		LootCans:Disable
		This:Clear
	}

	method UpdateWreckQuery()
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

		Wrecks:ClearTargetExceptions
		Wrecks:ClearQueryString

		variable string lootYellow = "&& HaveLootRights"
		if ${Config.SalvageYellow}
		{
			lootYellow:Set[""]
		}

		; Ship.ModuleList_Salvagers.Count is NULL at early stage
		variable string canLoot = "&& !IsWreckEmpty && !IsWreckViewed"
		if ${Ship.ModuleList_Salvagers.Count} > 0
		{
			canLoot:Set[""]
		}

		Wrecks:AddQueryString["(Group = \"Wreck\" || (Group = \"Cargo Container\")) ${canLoot} ${lootYellow} && !IsMoribund ${Size}"]
		Wrecks:RequestUpdate
	}

	member:bool Updated()
	{
		return ${Wrecks.Updated}
	}

	member:bool Salvage()
	{
		if !${Client.InSpace} || ${Me.ToEntity.Mode} == 3
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
			do
			{
				if ${TargetIterator.Value.ID(exists)} && ${TargetIterator.Value.IsLockedTarget}
				{
					; Abandon targets of no value
					if (!${Config.SalvageYellow} && !${TargetIterator.Value.HaveLootRights}) || \
						((${TargetIterator.Value.IsWreckEmpty} || ${TargetIterator.Value.IsWreckViewed}) && ${Ship.ModuleList_Salvagers.Count} == 0)
					{
						TargetIterator.Value:UnlockTarget
						return FALSE
					}

					; Salvage
					if !${Ship.ModuleList_Salvagers.IsActiveOn[${TargetIterator.Value.ID}]} && \
						${TargetIterator.Value.Distance} < ${Ship.ModuleList_Salvagers.Range} && \
						${Ship.ModuleList_Salvagers.InactiveCount} > 0 && \
						${TargetIterator.Value.GroupID} == GROUP_WRECK
					{
						if ${TargetIterator.Value.IsWreckEmpty} && ${Ship.ModuleList_TractorBeams.IsActiveOn[${TargetIterator.Value.ID}]}
						{
							Ship.ModuleList_TractorBeams:DeactivateOn[${TargetIterator.Value.ID}]
						}

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
			Wrecks.AutoLock:Set[FALSE]
			This:UpdateWreckQuery
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

		Salvage.Wrecks:RequestUpdate
		Salvage.Wrecks.TargetList:GetIterator[TargetIterator]
		if ${TargetIterator:First(exists)}
		{
			do
			{
				if !${TargetIterator.Value(exists)} || \
					${TargetIterator.Value.Distance} >= 2500 || \
					${TargetIterator.Value.IsWreckEmpty} || \
					${TargetIterator.Value.IsWreckViewed}
				{
					continue
				}


				; BUG of ISXEVE: Finding windows, getting items and looting all are not working for Wrecks, only for cargos.
				if !${EVEWindow[Inventory].ChildWindow[${TargetIterator.Value}](exists)}
				{
					UI:Update["Salvage", "Opening - \ap${TargetIterator.Value.Name}"]
					TargetIterator.Value:Open
					return FALSE
				}

				TargetIterator.Value:GetCargo[TargetCargo]
				TargetCargo:GetIterator[CargoIterator]
				if ${CargoIterator:First(exists)}
				{
					do
					{
						if ${CargoIterator.Value.IsContraband}
						{
							Salvage.Wrecks:AddTargetException[${TargetIterator.Value.ID}]
							return FALSE
						}
					}
					while ${CargoIterator:Next(exists)}
				}
				EVEWindow[Inventory]:LootAll
				if ${TargetIterator.Value.GroupID} == GROUP_CARGOCONTAINER || ${Ship.ModuleList_Salvagers.Count} == 0
				{
					TargetIterator.Value:UnlockTarget
				}
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