objectdef obj_NPCData
{
	variable string SetName = "NPCData"

	variable filepath CONFIG_PATH = "${Script.CurrentDirectory}/data"
	variable string CONFIG_FILE = "NPCData.xml"
	variable settingsetref BaseRef

	method Initialize()
	{
		LavishSettings[NPCData]:Clear
		LavishSettings:AddSet[NPCData]

		if ${CONFIG_PATH.FileExists["${CONFIG_FILE}"]}
		{
			LavishSettings[NPCData]:Import["${CONFIG_PATH}/${CONFIG_FILE}"]
		}
		BaseRef:Set[${LavishSettings[NPCData].FindSet[NPCTypes]}]

		Logger:Log["Configuration", " ${This.SetName}: Initialized", "-g"]
	}

	method Shutdown()
	{
		LavishSettings[NPCData]:Clear
	}

	member:string NPCType(int GroupID)
	{
		variable iterator NPCTypes
		BaseRef:GetSetIterator[NPCTypes]
		if ${NPCTypes:First(exists)}
		{
			do
			{
				if ${NPCTypes.Value.FindSetting[${GroupID}](exists)}
				{
					return ${NPCTypes.Key}
				}
			}
			while ${NPCTypes:Next(exists)}
		}
	}
}
