/*
	Mission Data Parser
		Parses HTML Mission information to extract the needed details

	- CyberTech
*/

objectdef obj_MissionParser inherits obj_Logger
{
    ; Opposite to normal experience,
    ; Mission journals can only be stored correctly while initializing variables.
    ; Copying the string with Set[] method will only get a substring with the first few hunderds characters for unknown reason.
    ; Which essentially mean we can't store the mission journal in this object.
    ; Storing AgentName instead is a workaround.
    ; Lavish script is so shit.
    ;
	; variable string MissionJournal
    ;
    ; Must ensure that ${EVEWindow[ByCaption, Mission journal - ${AgentName}].HTML.Escape} already returns full length
    ; journal BEFORE setting this name or calling any parse function.
    variable string AgentName
	variable string MissionExpiresHex
	variable string MissionName
	variable string Caption

	variable int left = 0
	variable int right = 0

	method Initialize(string Details)
	{
		; This.LogLevelBar:Set[${FoFConfig.LogLevelBar}]
		This.LogLevelBar:Set[LOG_DEBUG]
	}

    member:string EnemyFactionName()
	{
        variable string journalText = ${EVEWindow[ByCaption, Mission journal - ${AgentName}].HTML.Escape}
        if !${journalText.Find["The following rewards will be yours if you complete this mission"]}
        {
            This:LogCritical["journal length not fully retrieved."]
            return
        }

        variable string factionLogoPrefix = "<img src=\"factionlogo:"

        ; This:LogDebug["journal length ${journalText.Length}"]

        variable int factionID
        variable int left
		left:Set[${journalText.Find[${factionLogoPrefix.Escape}]}]
		if ${left} > 0
		{
			;This:LogDebug["DEBUG: Found \"factionlogo\" at ${left}."]
			left:Inc[${factionLogoPrefix.Length}]
            factionID:Set[${journalText.Mid[${left}, 6]}]
		}
		else
		{
            return ""
		}

        This:LogDebug["EnemyFactionName" ${journalText.Length} -- ${factionID} -- ${FactionData.FactionName[${factionID}]}]

        return ${FactionData.FactionName[${factionID}]}
	}

    member:string EnemyDamageToDeal()
	{
        variable string journalText = ${EVEWindow[ByCaption, Mission journal - ${AgentName}].HTML.Escape}
        if !${journalText.Find["The following rewards will be yours if you complete this mission"]}
        {
            This:LogCritical["journal length not fully retrieved."]
            return
        }

		variable string factionLogoPrefix = "<img src=\"factionlogo:"

        ; This:LogDebug["journal length ${journalText.Length}"]

        variable int factionID
        variable int left
		left:Set[${journalText.Find[${factionLogoPrefix.Escape}]}]
		if ${left} > 0
		{
			;This:LogDebug["DEBUG: Found \"factionlogo\" at ${left}."]
			left:Inc[${factionLogoPrefix.Length}]
            factionID:Set[${journalText.Mid[${left}, 6]}]
		}
		else
		{
            return ""
		}

        This:LogInfo["EnemyDamageToDeal" ${journalText.Length} -- ${factionID} -- ${FactionData.FactionDamageToDeal[${factionID}]}]

        return ${FactionData.FactionDamageToDeal[${factionID}]}
	}

	; member:int TypeID()
	; {
	; 	variable int retval = 0

	; 	left:Set[${journalText.Find["<img src=\"typeicon:"]}]
	; 	if ${left} > 0
	; 	{
	; 		;This:LogDebug["DEBUG: Found \"typeicon\" at ${left}."]
	; 		left:Inc[20]
	; 		;This:LogDebug["DEBUG: typeicon substring = ${journalText.Mid[${left},16]}"]
	; 		right:Set[${journalText.Mid[${left},16].Find["\" "]}]
	; 		if ${right} > 0
	; 		{
	; 			right:Dec[2]
	; 			;This:LogDebug["DEBUG: left = ${left}"]
	; 			;This:LogDebug["DEBUG: right = ${right}"]
	; 			;This:LogDebug["DEBUG: string = ${journalText.Mid[${left}, ${right}]}"]
	; 			retval:Set[${journalText.Mid[${left}, ${right}]}]
	; 			This:LogDebug["DEBUG: typeID = ${retval}"]
	; 		}
	; 		else
	; 		{
	; 			This:LogCritical["ERROR: Did not find end of \"typeicon\"!"]
	; 		}
	; 	}
	; 	else
	; 	{
	; 		This:LogInfo["WARNING: Did not find \"typeicon\".  No cargo???"]
	; 	}
	; 	return ${retval}
	; }

	; member:float Volume()
	; {
	; 	variable int retval = 0
	; 	variable string CubicMetreUtf8 = "m³"

	; 	right:Set[${journalText.Find[${CubicMetreUtf8}]}]
	; 	if ${right} > 0
	; 	{
	; 		; This:LogDebug["DEBUG: Found \"${CubicMetreUtf8}\" at ${right}."]
	; 		right:Dec
	; 		left:Set[${journalText.Mid[${Math.Calc[${right}-16]},16].Find[" ("]}]
	; 		if ${left} > 0
	; 		{
	; 			left:Set[${Math.Calc[${right}-16+${left}+1]}]
	; 			right:Set[${Math.Calc[${right}-${left}]}]
	; 			;This:LogDebug["DEBUG: left = ${left}"]
	; 			;This:LogDebug["DEBUG: right = ${right}"]
	; 			;This:LogDebug["DEBUG: string = ${journalText.Mid[${left}, ${right}]}"]
	; 			retval:Set[${journalText.Mid[${left}, ${right}]}]
	; 			This:LogDebug["DEBUG: Volume = ${retval}"]
	; 		}
	; 		else
	; 		{
	; 			This:LogCritical["ERROR: Did not find number before \"${CubicMetreUtf8}\"!"]
	; 		}
	; 	}
	; 	else
	; 	{
	; 		This:LogInfo["WARNING: Did not find \"${CubicMetreUtf8}\".  No cargo???"]
	; 	}

	; 	return ${retval}
	; }

	member:bool IsLowSec()
	{
		variable string journalText = ${EVEWindow[ByCaption, Mission journal - ${AgentName}].HTML.Escape}
        if !${journalText.Find["The following rewards will be yours if you complete this mission"]}
        {
            This:LogCritical["journal length not fully retrieved."]
            return
        }

        ; This:LogDebug["IsLowSec journal length ${journalText.Length}"]

		if ${journalText.Find["low security system"]}
		{
            This:LogDebug["low sec mission."]
			return TRUE
		}

        return FALSE
	}

    member:bool IsComplete()
	{
		variable string journalText = ${EVEWindow[ByCaption, Mission journal - ${AgentName}].HTML.Escape}
        if !${journalText.Find["The following rewards will be yours if you complete this mission"]}
        {
            This:LogCritical["journal length not fully retrieved."]
            return
        }

        ; This:LogDebug["IsComplete journal length ${journalText.Length}"]

        variable int left
        variable int right
        variable string mainHeaderPrefix = "mainheader>"
        left:Set[${journalText.Find[${mainHeaderPrefix}]}]
        variable string missionName
		if ${left} > 0
		{
			left:Inc[${mainHeaderPrefix.Length}]
			right:Set[${journalText.Mid[${left}, 50].Find["<"]}]
			if ${right} > 0
			{
				right:Dec[1]
				missionName:Set[${journalText.Mid[${left}, ${right}]}]
				This:LogDebug["Mission name: ${missionName}"]
			}
		}

        if !${missionName.NotNULLOrEmpty}
		{
			This:LogCritical["Failed to parse mission name"]
		}

		variable string checkMarkIcon = "icon:38_193"
        variable string circleMarkIcon = "icon:38_195"
        if ${journalText.Find[${missionName} Objectives Complete]} || \
            ; check mark icon >=2 and
            (${Math.Calc[${journalText.Length} - ${journalText.ReplaceSubstring[${checkMarkIcon}, ""].Length}].Int} >= ${Math.Calc[${checkMarkIcon.Length} * 2].Int} && \
            ; No unfinished targets(circle) or the circle appears before the first check implies that the ship is not docked at the dropoff station.
            (!${journalText.Find[${circleMarkIcon}]} || ${journalText.Find[${circleMarkIcon}]} < ${journalText.Find[${checkMarkIcon}]}))
        {
            This:LogDebug["mission complete."]
			return TRUE
		}

        return FALSE
	}

    member:bool IsOngoing()
	{
		variable string journalText = ${EVEWindow[ByCaption, Mission journal - ${AgentName}].HTML.Escape}
        if !${journalText.Find["The following rewards will be yours if you complete this mission"]}
        {
            This:LogCritical["journal length not fully retrieved."]
            return
        }

        ; This:LogDebug["IsOngoing journal length ${journalText.Length}"]

        variable int left
        variable int right
        variable string mainHeaderPrefix = "mainheader>"
        left:Set[${journalText.Find[${mainHeaderPrefix}]}]
        variable string missionName
		if ${left} > 0
		{
			left:Inc[${mainHeaderPrefix.Length}]
			right:Set[${journalText.Mid[${left}, 50].Find["<"]}]
			if ${right} > 0
			{
				right:Dec[1]
				missionName:Set[${journalText.Mid[${left}, ${right}]}]
				This:LogDebug["Mission name: ${missionName}"]
			}
		}

        if !${missionName.NotNULLOrEmpty}
		{
			This:LogCritical["Failed to parse mission name"]
		}

		if !${This.IsComplete} && ${journalText.Find[${missionName} Objectives]}
		{
            This:LogDebug["mission ongoing."]
			return TRUE
		}

        return FALSE
	}

	method ParseCaption()
	{
		This.Caption:Set["${amIterator.Value.Name}"]
		left:Set[${This.Caption.Find["u2013"]}]

		if ${left} > 0
		{
			This:LogInfo["WARNING: Mission name contains u2013"]
			This:LogInfo["DEBUG: amIterator.Value.Name = ${amIterator.Value.Name}"]

			This.Caption:Set["${This.Caption.Right[${Math.Calc[${This.Caption.Length} - ${left} - 5]}]}"]

			This:LogInfo["DEBUG: This.Caption = ${This.Caption}"]
		}
	}

	method SaveCacheFile()
	{
		variable file DetailsFile
		DetailsFile:SetFilename["./config/logs/${This.MissionExpiresHex} ${This.MissionName.Replace[",",""]}.html"]

		if ${DetailsFile:Open(exists)}
		{
			DetailsFile:Write["${journalText}"]
			DetailsFile:Close
		}
	}
}