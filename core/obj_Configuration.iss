objectdef obj_Base_Configuration
{
	variable string SetName = ""

	method Initialize(string name)
	{
		SetName:Set[${name}]
		if !${BaseConfig.BaseRef.FindSet[${This.SetName}](exists)}
		{
			UI:Update["Configuration", " ${This.SetName} settings missing - initializing", "o"]
			BaseConfig.BaseRef:AddSet[${This.SetName}]
			This:Set_Default_Values[]
		}
		UI:Update["Configuration", " ${This.SetName}: Initialized", "-g"]
	}

	member:settingsetref CommonRef()
	{
		return ${BaseConfig.BaseRef.FindSet[${This.SetName}]}
	}
	
	method Set_Default_Values()
	{
		
	}

}


objectdef obj_Configuration_BaseConfig
{
	variable string CONFIG_FILE = "${Me.Name} Config.xml"
	variable filepath CONFIG_PATH = "${Script.CurrentDirectory}/config"
	variable settingsetref BaseRef

	method Initialize()
	{
		if ${EVEExtension.Character.Length}
		{
			CONFIG_FILE:Set["${EVEExtension.Character} Config.xml"]
		}

		LavishSettings[TehbotSettings]:Clear
		LavishSettings:AddSet[TehbotSettings]
		if ${EVEExtension.Character.Length}
		{
			LavishSettings[TehbotSettings]:AddSet[${EVEExtension.Character}]
		}
		else
		{
			LavishSettings[TehbotSettings]:AddSet[${Me.Name}]
		}
		


		if !${CONFIG_PATH.FileExists["${CONFIG_PATH}/${CONFIG_FILE}"]}
		{
			UI:Update["Configuration", "Configuration file is ${CONFIG_FILE}", "g", TRUE]
			LavishSettings[TehbotSettings]:Import["${CONFIG_PATH}/${CONFIG_FILE}"]
		}

		if ${EVEExtension.Character.Length}
		{
			BaseRef:Set[${LavishSettings[TehbotSettings].FindSet[${EVEExtension.Character}]}]
		}
		else
		{
			BaseRef:Set[${LavishSettings[TehbotSettings].FindSet[${Me.Name}]}]
		}
		
	}

	method Shutdown()
	{
		This:Save[]
		LavishSettings[TehbotSettings]:Clear
	}

	method Save()
	{
		LavishSettings[TehbotSettings]:Export["${CONFIG_PATH}/${CONFIG_FILE}"]
	}
}




objectdef obj_Configuration
{
	variable obj_Configuration_Common Common
	method Save()
	{
		BaseConfig:Save[]
	}
}






objectdef obj_Configuration_Common
{
	variable string SetName = "Common"

	method Initialize()
	{
		if !${BaseConfig.BaseRef.FindSet[${This.SetName}](exists)}
		{
			UI:Update["Configuration", " ${This.SetName} settings missing - initializing", "o"]
			This:Set_Default_Values[]
		}
		UI:Update["Configuration", " ${This.SetName}: Initialized", "-g"]
	}

	member:settingsetref CommonRef()
	{
		return ${BaseConfig.BaseRef.FindSet[${This.SetName}]}
	}

	method Set_Default_Values()
	{
		BaseConfig.BaseRef:AddSet[${This.SetName}]

		This.CommonRef:AddSetting[Tehbot_Mode,"MiniMode"]
		This.CommonRef:AddSetting[ActiveTab,Status]
	}

	Setting(string, Tehbot_Mode, SetTehbot_Mode)
	Setting(bool, AutoStart, SetAutoStart)
	Setting(bool, Disable3D, SetDisable3D)
	Setting(bool, DisableUI, SetDisableUI)
	Setting(bool, DisableTexture, SetDisableTexture)
	Setting(bool, CloseChatInvites, SetCloseChatInvites)
	Setting(string, ActiveTab, SetActiveTab)
	Setting(bool, Hidden, SetHidden)
	Setting(int64, CharID, SetCharID)
}
