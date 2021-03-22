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



objectdef obj_Salvage inherits obj_State
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
			Wrecks:AddQueryString["(Group = \"Wreck\" || Group = \"Cargo Container\") && !IsMoribund ${Size}"]
		}
		else
		{
			Wrecks:AddQueryString["(Group = \"Wreck\" || Group = \"Cargo Container\") && HaveLootRights && !IsMoribund ${Size}"]
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
		if !${Client.InSpace}
		{
			return FALSE
		}
	
		variable iterator TargetIterator
		variable queue:int LootRangeAndTractored
		variable int MaxTarget = ${MyShip.MaxLockedTargets}
		variable int ClosestTractorKey
		variable bool ReactivateTractor = FALSE
		variable int64 SalvageMultiTarget = -1


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
				if ${TargetIterator.Value.ID(exists)}
				{
					if 	${TargetIterator.Value.IsLockedTarget} &&\
						${TargetIterator.Value.Distance} > ${Ship.ModuleList_TractorBeams.Range}
					{
						TargetIterator.Value:UnlockTarget
						return FALSE
					}
				
					if  !${Ship.ModuleList_TractorBeams.IsActiveOn[${TargetIterator.Value.ID}]} &&\
						${TargetIterator.Value.Distance} < ${Ship.ModuleList_TractorBeams.Range} &&\
						${TargetIterator.Value.Distance} > 2500 &&\
						${Ship.ModuleList_TractorBeams.InactiveCount} > 0 &&\
						${TargetIterator.Value.IsLockedTarget} &&\
						${TargetIterator.Value.HaveLootRights}
					{
						UI:Update["Salvage", "Activating tractor beam - ${TargetIterator.Value.Name}", "g"]
						Ship.ModuleList_TractorBeams:Activate[${TargetIterator.Value.ID}]
						return FALSE
					}
					if  !${Ship.ModuleList_TractorBeams.IsActiveOn[${TargetIterator.Value.ID}]} &&\
						${TargetIterator.Value.Distance} < ${Ship.ModuleList_TractorBeams.Range} &&\
						${TargetIterator.Value.Distance} > 2500 &&\
						${TargetIterator.Value.IsLockedTarget} &&\
						${ReactivateTractor} &&\
						${TargetIterator.Value.HaveLootRights}
					{
						UI:Update["Salvage", "Reactivating tractor beam - ${TargetIterator.Value.Name}", "g"]
						Ship.ModuleList_TractorBeams:Reactivate[${ClosestTractorKey}, ${TargetIterator.Value.ID}]
						return FALSE
					}
					if  ${Ship.ModuleList_TractorBeams.IsActiveOn[${TargetIterator.Value.ID}]} &&\
						${TargetIterator.Value.Distance} < 2500 &&\
						!${ReactivateTractor}
					{
						ClosestTractorKey:Set[${Ship.ModuleList_TractorBeams.GetActiveOn[${TargetIterator.Value.ID}]}]
						ReactivateTractor:Set[TRUE]
					}
					if  !${Ship.ModuleList_Salvagers.IsActiveOn[${TargetIterator.Value.ID}]} &&\
						${TargetIterator.Value.Distance} < ${Ship.ModuleList_Salvagers.Range} &&\
						${Ship.ModuleList_Salvagers.InactiveCount} > 0 &&\
						${TargetIterator.Value.IsLockedTarget} && ${Ship.ModuleList_Salvagers.Count} > 0 &&\
						!${TargetIterator.Value.Group.Equal[Cargo Container]}
					{
						UI:Update["obj_Salvage", "Activating salvager - ${TargetIterator.Value.Name}", "g"]
						Ship.ModuleList_Salvagers:Activate[${TargetIterator.Value.ID}]
						return FALSE
					}
					if  !${Ship.ModuleList_Salvagers.IsActiveOn[${TargetIterator.Value.ID}]} &&\
						${TargetIterator.Value.IsWreckEmpty} &&\
						${TargetIterator.Value.IsLockedTarget} && ${Ship.ModuleList_Salvagers.Count} == 0
					{
						TargetIterator.Value:Abandon
						TargetIterator.Value:UnlockTarget
					}
					if  ${TargetIterator.Value.Distance} < ${Ship.ModuleList_Salvagers.Range} &&\
						${Ship.ModuleList_Salvagers.InactiveCount} > 0 &&\
						${TargetIterator.Value.IsLockedTarget} &&\
						!${TargetIterator.Value.Group.Equal[Cargo Container]}
					{
						SalvageMultiTarget:Set[${TargetIterator.Value.ID}]
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
		if !${SalvageMultiTarget.Equal[-1]} && ${Ship.ModuleList_Salvagers.InactiveCount} > 0
		{
			Ship.ModuleList_Salvagers:Activate[${SalvageMultiTarget}]
		}
		return FALSE
	}

}


objectdef obj_LootCans inherits obj_State
{
	method Initialize()
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]
	}
	
	method Enable()
	{
		This:QueueState["Loot", 3000]
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
		
	
		if !${Client.InSpace}
		{
			return FALSE
		}
		
		if ${Me.ToEntity.Mode} == 3
		{
			return FALSE
		}

		Salvage.Wrecks.TargetList:GetIterator[TargetIterator]
		if ${TargetIterator:First(exists)} && ${EVEWindow[Inventory](exists)}
		{
			do
			{
				if 	${TargetIterator.Value.Distance} > 2500 ||\
					${TargetIterator.Value.IsWreckEmpty} ||\
					!${Entity[${TargetIterator.Value.ID}](exists)}
				{
					continue
				}
				if ${EVEWindow[Inventory].ChildWindow[${TargetIterator.Value}](exists)}
				{
					if !${EVEWindow[ByItemID, ${TargetIterator.Value}](exists)}
					{
						EVEWindow[Inventory].ChildWindow[${TargetIterator.Value}]:MakeActive
						return FALSE
					}
					
					Entity[${TargetIterator.Value}]:GetCargo[TargetCargo]
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
					
					UI:Update["Salvage", "Looting - ${TargetIterator.Value.Name}", "g"]
					EVEWindow[Inventory]:LootAll
					This:InsertState["Loot"]
					This:InsertState["Stack"]
					return TRUE
				}
				if !${EVEWindow[Inventory].ChildWindow[${TargetIterator.Value}](exists)}
				{
					UI:Update["Salvage", "Opening - ${TargetIterator.Value.Name}", "g"]
					TargetIterator.Value:Open
					return FALSE
				}		
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