#macro Setting(type, name, setname)
	member:type name()
	{
		return ${This.ConfigRef.FindSetting[name]}
	}

	method setname(type value)
	{
		This.ConfigRef:AddSetting[name,${value}]
		ConfigManager:Save
	}
#endmac

#macro DynamicAddBehavior(name, displayname)
	Dynamic:AddBehavior[name, displayname, ${String[_FILE_].Escape}]
#endmac

#macro DynamicAddMiniMode(name, displayname)
	Dynamic:AddMiniMode[name, displayname, ${String[_FILE_].Escape}]
#endmac