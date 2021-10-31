objectdef obj_Configuration_UndockWarp
{
	variable string SetName = "UndockWarp"

	method Initialize()
	{
		if !${BaseConfig.BaseRef.FindSet[${This.SetName}](exists)}
		{
			Logger:Log["Configuration", " ${This.SetName} settings missing - initializing", "o"]
			This:Set_Default_Values[]
		}
	}

	member:settingsetref CommonRef()
	{
		return ${BaseConfig.BaseRef.FindSet[${This.SetName}]}
	}

	method Set_Default_Values()
	{
		BaseConfig.BaseRef:AddSet[${This.SetName}]

		This.CommonRef:AddSetting[substring, "Undock"]
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
		if ${Client.Undock}
		{
			return FALSE
		}
		if ${EVE.IsProgressWindowOpen}
		{
			if ${EVE.ProgressWindowTitle.Equal[Prepare to undock]}
			{
				Logger:Log["UndockWarp", "Triggering warp to undock bookmark, if available", "y"]
				Client.Undock:Set[TRUE]
			}
		}
		return FALSE
	}

}