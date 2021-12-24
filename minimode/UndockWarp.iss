objectdef obj_Configuration_UndockWarp inherits obj_Base_Configuration
{
	method Initialize()
	{
		This[parent]:Initialize["UndockWarp"]
	}

	method Set_Default_Values()
	{
		BaseConfig.BaseRef:AddSet[${This.SetName}]

		This.ConfigRef:AddSetting[substring, "Undock"]
	}

	Setting(string, substring, Setsubstring)

}

objectdef obj_UndockWarp inherits obj_StateQueue
{
	variable obj_Configuration_UndockWarp Config

	method Initialize()
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]
		DynamicAddMiniMode("UndockWarp", "UndockWarp")
	}

	method Start()
	{
		This:QueueState["UndockWarp"]
	}

	method Stop()
	{
		This:Clear
	}

	member:bool UndockWarp()
	{
		if ${Client.TryWarpToBookmark}
		{
			return FALSE
		}
		if ${EVE.IsProgressWindowOpen}
		{
			if ${EVE.ProgressWindowTitle.Equal[Prepare to undock]}
			{
				Logger:Log["UndockWarp", "Triggering warp to undock bookmark, if available", "y"]
				Client.TryWarpToBookmark:Set[TRUE]
			}
		}
		return FALSE
	}

}