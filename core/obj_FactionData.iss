objectdef obj_FactionData
{
	variable string SetName = "FactionData"

	variable filepath CONFIG_PATH = "${Script.CurrentDirectory}/data"
	variable string CONFIG_FILE = "FactionData.xml"
	variable settingsetref BaseRef

	method Initialize()
	{
		LavishSettings[FactionData]:Clear
		LavishSettings:AddSet[FactionData]

		if ${CONFIG_PATH.FileExists["${CONFIG_FILE}"]}
		{
			LavishSettings[FactionData]:Import["${CONFIG_PATH}/${CONFIG_FILE}"]
		}
		BaseRef:Set[${LavishSettings[FactionData].FindSet[Factions]}]

		Logger:Log["Configuration", " ${This.SetName}: Initialized", "-g"]
	}

	method Shutdown()
	{
		LavishSettings[FactionData]:Clear
	}

	member:string FactionName(int factionID)
	{
		variable iterator factions
		BaseRef:GetSetIterator[factions]
		if ${factions:First(exists)}
		{
			do
			{
				if ${factions.Value.FindSetting[ID].Int.Equal[${factionID}]}
				{
					return ${factions.Key}
				}
			}
			while ${factions:Next(exists)}
		}
	}

	member:string FactionDamageToDeal(int factionID)
	{
		variable iterator factions
		BaseRef:GetSetIterator[factions]
		if ${factions:First(exists)}
		{
			do
			{
				if ${factions.Value.FindSetting[ID].Int.Equal[${factionID}]}
				{
					return ${factions.Value.FindSetting[DamageToDeal].String}
				}
			}
			while ${factions:Next(exists)}
		}
	}
}
