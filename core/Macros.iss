#macro Setting(type, name, setname)
	member:type name()
	{
		return ${This.CommonRef.FindSetting[name]}
	}

	method setname(type value)
	{
		This.CommonRef:AddSetting[name,${value}]
		Config:Save
	}
#endmac

#macro DynamicAddBehavior(name, displayname)
	Dynamic:AddBehavior[name, displayname, ${String[_FILE_].Escape}]
#endmac

#macro DynamicAddMiniMode(name, displayname)
	Dynamic:AddMiniMode[name, displayname, ${String[_FILE_].Escape}]
#endmac