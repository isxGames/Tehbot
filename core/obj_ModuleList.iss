objectdef obj_ModuleList
{
	variable index:obj_Module Modules

	method Insert(int64 ID)
	{
		Modules:Insert[${ID}]
	}

	method ActivateOne(int64 target=-1, int deactivateAfterCyclePercent=-1)
	{
		variable iterator ModuleIterator
		Modules:GetIterator[ModuleIterator]
		if ${ModuleIterator:First(exists)}
		{
			do
			{
				if !${ModuleIterator.Value.IsActive}
				{
					ModuleIterator.Value:Activate[${target}, ${deactivateAfterCyclePercent}]
					return
				}
			}
			while ${ModuleIterator:Next(exists)}
		}
	}

	method ActivateAll(int64 target=-1, int deactivateAfterCyclePercent=-1)
	{
		variable iterator ModuleIterator
		Modules:GetIterator[ModuleIterator]
		if ${ModuleIterator:First(exists)}
		{
			do
			{
				; Will deactivate the module if the current target is not the same
				ModuleIterator.Value:Activate[${target}, ${deactivateAfterCyclePercent}]
			}
			while ${ModuleIterator:Next(exists)}
		}
	}

	method DeactivateAll()
	{
		variable iterator ModuleIterator
		Modules:GetIterator[ModuleIterator]
		if ${ModuleIterator:First(exists)}
		{
			do
			{
				if ${ModuleIterator.Value.IsActive}
				{
					ModuleIterator.Value:Deactivate
				}
			}
			while ${ModuleIterator:Next(exists)}
		}
	}

	method DeactivateOneNotOn(int64 target=-1)
	{
		variable iterator ModuleIterator
		Modules:GetIterator[ModuleIterator]
		if ${ModuleIterator:First(exists)}
		{
			do
			{
				if !${ModuleIterator.Value.IsActiveOn[${target}]} && ${ModuleIterator.Value.IsActive}
				{
					ModuleIterator.Value:Deactivate
					return
				}
			}
			while ${ModuleIterator:Next(exists)}
		}
	}

	method DeactivateOn(int64 target=-1)
	{
		variable iterator ModuleIterator
		Modules:GetIterator[ModuleIterator]
		if ${ModuleIterator:First(exists)}
		{
			do
			{
				if ${ModuleIterator.Value.IsActiveOn[${target}]}
				{
					ModuleIterator.Value:Deactivate
				}
			}
			while ${ModuleIterator:Next(exists)}
		}
	}

	member:bool IsActiveOn(int64 checkTarget)
	{
		variable iterator ModuleIterator
		Modules:GetIterator[ModuleIterator]
		if ${ModuleIterator:First(exists)}
		{
			do
			{
				if ${ModuleIterator.Value.IsActiveOn[${checkTarget}]}
				{
					return TRUE
				}
			}
			while ${ModuleIterator:Next(exists)}
		}
		return FALSE
	}

	member:int Count()
	{
		return ${Modules.Used}
	}

	member:int ActiveCount()
	{
		variable int countActive=0
		variable iterator ModuleIterator
		Modules:GetIterator[ModuleIterator]
		if ${ModuleIterator:First(exists)}
		{
			do
			{
				if ${ModuleIterator.Value.IsActive}
				{
					countActive:Inc
				}
			}
			while ${ModuleIterator:Next(exists)}
		}
		return ${countActive}
	}

	member:int ActiveCountOn(int64 checkTarget)
	{
		variable int countActive=0
		variable iterator ModuleIterator
		Modules:GetIterator[ModuleIterator]
		if ${ModuleIterator:First(exists)}
		{
			do
			{
				if ${ModuleIterator.Value.IsActiveOn[${checkTarget}]}
				{
					countActive:Inc
				}
			}
			while ${ModuleIterator:Next(exists)}
		}
		return ${countActive}
	}

	member:int InactiveCount()
	{
		variable iterator ModuleIterator
		variable int countInactive = 0
		Modules:GetIterator[ModuleIterator]
		if ${ModuleIterator:First(exists)}
		{
			do
			{
				if !${ModuleIterator.Value.IsActive} && !${ModuleIterator.Value.IsReloading}
				{
					countInactive:Inc
				}
			}
			while ${ModuleIterator:Next(exists)}
		}
		return ${countInactive}
	}

	member:float Range()
	{
		return ${Modules.Get[1].Range}
	}

	member:float OptimalRange()
	{
		return ${Modules.Get[1].OptimalRange}
	}

	member:bool IncludeModule(int64 ModuleID)
	{
		variable iterator ModuleIterator
		Modules:GetIterator[ModuleIterator]
		if ${ModuleIterator:First(exists)}
		{
			do
			{
				if ${ModuleIterator.Value.ID} == ${ModuleID}
				{
					return TRUE
				}
			}
			while ${ModuleIterator:Next(exists)}
		}
		return FALSE
	}

	member:string GetFallthroughObject()
	{
		return "Ship.${This.ObjectName}.Modules"
	}
}