objectdef obj_InstaWarp inherits obj_StateQueue
{
	variable bool InstaWarp_Cooldown=FALSE

	method Initialize()
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]
		DynamicAddMiniMode("InstaWarp", "InstaWarp")
	}

	method Start()
	{
		This:QueueState["InstaWarp"]
	}

	method Stop()
	{
		This:Clear
	}

	member:bool InstaWarp()
	{
		if !${Client.InSpace}
		{
			return FALSE
		}

		if ${Me.ToEntity.Mode} == 3 && ${InstaWarp_Cooldown} && ${Ship.ModuleList_AB_MWD.ActiveCount}
		{
			Ship.ModuleList_AB_MWD:Deactivate
			return FALSE
		}

		if ${Me.ToEntity.Mode} == 3 && !${InstaWarp_Cooldown}
		{
			Ship.ModuleList_AB_MWD:Activate[-1, FALSE]
			InstaWarp_Cooldown:Set[TRUE]
			return FALSE
		}
		if ${Me.ToEntity.Mode} != 3
		{
			InstaWarp_Cooldown:Set[FALSE]
			return FALSE
		}
	}

}