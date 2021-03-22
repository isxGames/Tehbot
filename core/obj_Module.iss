variable collection:obj_ModuleBase ModuleBaseModules

objectdef obj_Module
{
	variable int64 ModuleID
	method Initialize(int64 ID)
	{
		ModuleID:Set[${MyShip.Module[${ID}].ID}]
		if !${ModuleBaseModules[${ModuleID}](exists)}
		{
			ModuleBaseModules:Set[${ModuleID}, ${ModuleID}]
		}
	}
	
	member:int64 CurrentTarget()
	{
		return ${ModuleBaseModules[${ModuleID}].CurrentTarget}
	}
	
	member:bool IsActive()
	{
		return ${ModuleBaseModules[${ModuleID}].IsActive}
	}
	
	member:bool IsDeactivating()
	{
		return ${ModuleBaseModules[${ModuleID}].IsDeactivating}
	}
	
	member:bool IsActiveOn(int64 checkTarget)
	{
		return ${ModuleBaseModules[${ModuleID}].IsActiveOn[${checkTarget}]}
	}
	
	method Deactivate()
	{
		ModuleBaseModules[${ModuleID}]:Deactivate
	}
	
	method Activate(int64 newTarget=-1, bool DoDeactivate=TRUE, int DeactivatePercent=100)
	{
		ModuleBaseModules[${ModuleID}]:Activate[${newTarget}, ${DoDeactivate}, ${DeactivatePercent}]
	}
	
	member:bool LoadMiningCrystal(string OreType)
	{
		return ${ModuleBaseModules[${ModuleID}].LoadMiningCrystal[${OreType.Escape}]}
	}
	
	member:float Range()
	{
		return ${ModuleBaseModules[${ModuleID}].Range}
	}
	
	member:string GetFallthroughObject()
	{
		return "MyShip.Module[${ModuleID}]"
	}
}