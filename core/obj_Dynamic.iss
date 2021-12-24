objectdef obj_Configuration_Dynamic
{
	variable string SetName = "Dynamic"

	method Initialize()
	{
		if !${BaseConfig.BaseRef.FindSet[${This.SetName}](exists)}
		{
			Logger:Log["Configuration", " ${This.SetName} settings missing - initializing", "o"]
			This:Set_Default_Values[]
		}
		Logger:Log["Configuration", " ${This.SetName}: Initialized", "-g"]
	}

	member:settingsetref CommonRef()
	{
		return ${BaseConfig.BaseRef.FindSet[${This.SetName}]}
	}

	method Set_Default_Values()
	{
		BaseConfig.BaseRef:AddSet[${This.SetName}]
		This.CommonRef:AddSet[Enabled MiniModes]
	}

	method AddMiniMode(string name)
	{
		if !${This.CommonRef.FindSet[Enabled MiniModes](exists)}
		{
			This.CommonRef:AddSet[Enabled MiniModes]
		}
		This.CommonRef.FindSet[Enabled MiniModes]:AddSetting[${name.Escape}, 1]
		BaseConfig:Save
	}

	method RemMiniMode(string name)
	{
		if !${This.CommonRef.FindSet[Enabled MiniModes](exists)}
		{
			This.CommonRef:AddSet[Enabled MiniModes]
		}
		if ${This.CommonRef.FindSet[Enabled MiniModes].FindSetting[${name.Escape}](exists)}
		{
			This.CommonRef.FindSet[Enabled MiniModes].FindSetting[${name.Escape}]:Remove
		}
		BaseConfig:Save
	}

	member:settingsetref EnabledMiniModes()
	{
		if !${This.CommonRef.FindSet[Enabled MiniModes](exists)}
		{
			This.CommonRef:AddSet[Enabled MiniModes]
		}
		return ${This.CommonRef.FindSet[Enabled MiniModes]}
	}
}

objectdef obj_DynamicItem
{
	variable string Name
	variable string DisplayName
	variable string ConfigPath
	method Initialize(string argName, string argDisplayName, string argConfigPath)
	{
		Name:Set[${argName.Escape}]
		DisplayName:Set[${argDisplayName.Escape}]
		ConfigPath:Set[${argConfigPath.Escape}]
	}
}

objectdef obj_Dynamic
{
	variable collection:obj_DynamicItem Behaviors
	variable collection:obj_DynamicItem MiniModes
	variable obj_Configuration_Dynamic Config

	method AddBehavior(string argName, string argDisplayName, string argConfigPath)
	{
		variable file Behavior = ${argConfigPath.Escape}
		Behaviors:Set[${argName.Escape}, ${argName.Escape}, ${argDisplayName.Escape}, ${Behavior.Path.Escape}]
	}

	method AddMiniMode(string argName, string argDisplayName, string argConfigPath)
	{
		variable file MiniMode = ${argConfigPath.Escape}
		MiniModes:Set[${argName.Escape}, ${argName.Escape}, ${argDisplayName.Escape}, ${MiniMode.Path.Escape}]
	}

	method PopulateMiniModes()
	{
		variable iterator MiniModeIterator
		MiniModes:GetIterator[MiniModeIterator]

		UIElement[MiniMode_Inactive@MiniMode@TehbottTab@Tehbot]:ClearItems
		UIElement[MiniMode_Active@MiniMode@TehbotTab@Tehbot]:ClearItems

		if ${MiniModeIterator:First(exists)}
		{
			do
			{
				if ${This.Config.EnabledMiniModes.FindSetting[${MiniModeIterator.Value.Name}](exists)}
				{
					UIElement[MiniMode_Active@MiniMode@TehbotTab@Tehbot]:AddItem[${MiniModeIterator.Value.DisplayName.Escape}, ${MiniModeIterator.Value.Name.Escape}]
					${MiniModeIterator.Value.Name}:Start
				}
				else
				{
					UIElement[MiniMode_Inactive@MiniMode@TehbotTab@Tehbot]:AddItem[${MiniModeIterator.Value.DisplayName.Escape}, ${MiniModeIterator.Value.Name.Escape}]
				}
			}
			while ${MiniModeIterator:Next(exists)}
		}
	}

	method PopulateBehaviors()
	{
		variable iterator BehaviorIterator
		Behaviors:GetIterator[BehaviorIterator]

		UIElement[Tehbot_Mode@Status@TehbotTab@Tehbot]:ClearItems

		if ${BehaviorIterator:First(exists)}
		{
			do
			{
				UIElement[Tehbot_Mode@Status@TehbotTab@Tehbot]:AddItem[${BehaviorIterator.Value.DisplayName.Escape}, ${BehaviorIterator.Value.Name.Escape}]
			}
			while ${BehaviorIterator:Next(exists)}
		}

		UIElement[Tehbot_Mode@Status@TehbotTab@Tehbot].ItemByValue[${Script[Tehbot].VariableScope.Config.Common.Tehbot_Mode}]:Select

	}

	method ActivateMiniMode(string name)
	{
		This.Config:AddMiniMode[${name.Escape}]
		${name}:Start
	}

	method DeactivateMiniMode(string name)
	{
		This.Config:RemMiniMode[${name.Escape}]
		${name}:Stop
	}
}