objectdef obj_ModuleList
{
	variable index:int64 ModuleID

	method Insert(int64 ID)
	{
		ModuleID:Insert[${ID}]
	}

	method ActivateOne(int64 targetID=-1, int deactivateAfterCyclePercent=-1)
	{
		variable iterator moduleIDIterator
		ModuleID:GetIterator[moduleIDIterator]
		if ${moduleIDIterator:First(exists)}
		{
			do
			{
				if !${Ship.RegisteredModule.Element[${moduleIDIterator.Value}].IsActive}
				{
					Ship.RegisteredModule.Element[${moduleIDIterator.Value}]:Activate[${targetID}, ${deactivateAfterCyclePercent}]
					return
				}
			}
			while ${moduleIDIterator:Next(exists)}
		}
	}

	method ActivateAll(int64 targetID=-1, int deactivateAfterCyclePercent=-1)
	{
		variable iterator moduleIDIterator
		ModuleID:GetIterator[moduleIDIterator]
		if ${moduleIDIterator:First(exists)}
		{
			do
			{
				; Will deactivate the module if the current targetID is not the same
				Ship.RegisteredModule.Element[${moduleIDIterator.Value}]:Activate[${targetID}, ${deactivateAfterCyclePercent}]
			}
			while ${moduleIDIterator:Next(exists)}
		}
	}

	method DeactivateAll()
	{
		variable iterator moduleIDIterator
		ModuleID:GetIterator[moduleIDIterator]
		if ${moduleIDIterator:First(exists)}
		{
			do
			{
				if ${Ship.RegisteredModule.Element[${moduleIDIterator.Value}].IsActive}
				{
					Ship.RegisteredModule.Element[${moduleIDIterator.Value}]:Deactivate
				}
			}
			while ${moduleIDIterator:Next(exists)}
		}
	}

	method DeactivateOneNotOn(int64 targetID=-1)
	{
		variable iterator moduleIDIterator
		ModuleID:GetIterator[moduleIDIterator]
		if ${moduleIDIterator:First(exists)}
		{
			do
			{
				if !${Ship.RegisteredModule.Element[${moduleIDIterator.Value}].IsActiveOn[${targetID}]} && ${Ship.RegisteredModule.Element[${moduleIDIterator.Value}].IsActive}
				{
					Ship.RegisteredModule.Element[${moduleIDIterator.Value}]:Deactivate
					return
				}
			}
			while ${moduleIDIterator:Next(exists)}
		}
	}

	method DeactivateOn(int64 targetID=-1)
	{
		variable iterator moduleIDIterator
		ModuleID:GetIterator[moduleIDIterator]
		if ${moduleIDIterator:First(exists)}
		{
			do
			{
				if ${Ship.RegisteredModule.Element[${moduleIDIterator.Value}].IsActiveOn[${targetID}]}
				{
					Ship.RegisteredModule.Element[${moduleIDIterator.Value}]:Deactivate
				}
			}
			while ${moduleIDIterator:Next(exists)}
		}
	}

	member:bool IsActiveOn(int64 targetID)
	{
		variable iterator moduleIDIterator
		ModuleID:GetIterator[moduleIDIterator]
		if ${moduleIDIterator:First(exists)}
		{
			do
			{
				if ${Ship.RegisteredModule.Element[${moduleIDIterator.Value}].IsActiveOn[${targetID}]}
				{
					return TRUE
				}
			}
			while ${moduleIDIterator:Next(exists)}
		}
		return FALSE
	}

	member:int Count()
	{
		return ${ModuleID.Used}
	}

	member:int ActiveCount()
	{
		variable int countActive=0
		variable iterator moduleIDIterator
		ModuleID:GetIterator[moduleIDIterator]
		if ${moduleIDIterator:First(exists)}
		{
			do
			{
				if ${Ship.RegisteredModule.Element[${moduleIDIterator.Value}].IsActive}
				{
					countActive:Inc
				}
			}
			while ${moduleIDIterator:Next(exists)}
		}
		return ${countActive}
	}

	member:int ActiveCountOn(int64 targetID)
	{
		variable int countActive=0
		variable iterator moduleIDIterator
		ModuleID:GetIterator[moduleIDIterator]
		if ${moduleIDIterator:First(exists)}
		{
			do
			{
				if ${Ship.RegisteredModule.Element[${moduleIDIterator.Value}].IsActiveOn[${targetID}]}
				{
					countActive:Inc
				}
			}
			while ${moduleIDIterator:Next(exists)}
		}
		return ${countActive}
	}

	member:int InactiveCount()
	{
		variable iterator moduleIDIterator
		variable int countInactive = 0
		ModuleID:GetIterator[moduleIDIterator]
		if ${moduleIDIterator:First(exists)}
		{
			do
			{
				if !${Ship.RegisteredModule.Element[${moduleIDIterator.Value}].IsActive} && !${Ship.RegisteredModule.Element[${moduleIDIterator.Value}].IsReloading}
				{
					countInactive:Inc
				}
			}
			while ${moduleIDIterator:Next(exists)}
		}
		return ${countInactive}
	}

	member:float Range()
	{
		return ${Ship.RegisteredModule.Element[${ModuleID.Get[1]}].Range}
	}

	member:float OptimalRange()
	{
		return ${Ship.RegisteredModule.Element[${ModuleID.Get[1]}].OptimalRange}
	}

	member:bool IncludeModule(int64 moduleID)
	{
		variable iterator moduleIDIterator
		ModuleID:GetIterator[moduleIDIterator]
		if ${moduleIDIterator:First(exists)}
		{
			do
			{
				if ${Ship.RegisteredModule.Element[${moduleIDIterator.Value}].ID} == ${moduleID}
				{
					return TRUE
				}
			}
			while ${moduleIDIterator:Next(exists)}
		}
		return FALSE
	}

	member:string GetFallthroughObject()
	{
		return "Ship.${This.ObjectName}.ModuleID"
	}
}