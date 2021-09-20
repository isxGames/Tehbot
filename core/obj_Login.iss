objectdef obj_EVEExtension
{
	variable string Character=""

	function Initialize()
	{
		do
		{
			if !${ISXEVE(exists)}
			{
				extension ISXEVE
			}
			wait 10
		}
		while !${ISXEVE(exists)} || !${ISXEVE.IsReady}
	}
}


objectdef obj_Login inherits obj_StateQueue
{
	variable bool Wait=FALSE

	method Initialize()
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]

		if ${Me(exists)} && ${MyShip(exists)} && (${Me.InSpace} || ${Me.InStation})
		{
			return
		}
		This:QueueState["Build"]
	}

	member:bool Build()
	{
		if ${Wait}
		{
			UI:Update["Login", "Login pending for character \ao${EVEExtension.Character}", "y"]
		}
		This:QueueState["WaitForLogin"]
		if ${EVEExtension.Character.Length}
		{
			This:QueueState["Log", 10, "Beginning auto-login for character \ao${EVEExtension.Character},y"]
		}
		else
		{
			This:QueueState["Log", 10, "Autologin character not specified.  Specify a character in your command line.,r"]
			return
		}
		This:QueueState["SelectCharacter"]
		return TRUE
	}

	member:bool WaitForLogin()
	{
		if ${Wait}
		{
			return FALSE
		}
		return TRUE
	}

	member:bool Log(string msg, string color)
	{
		UI:Update["Login", "${msg}", "${color}"]
		return TRUE
	}

	member:bool SelectCharacter()
	{
		if ${Me(exists)} && ${MyShip(exists)} && (${Me.InSpace} || ${Me.InStation})
		{
			return TRUE
		}

		if ${EVE.IsProgressWindowOpen}
		{
			return FALSE
		}

		if ${EVEWindow[ByName,MessageBox](exists)} || ${EVEWindow[ByCaption,System Congested](exists)}
		{
			UI:Update["obj_Login", "System may be congested, waiting 10 seconds", "g"]
			Press Esc
			This:Clear
			This:QueueState["Idle", 10000]
			This:QueueState["SelectCharacter"]
			return TRUE
		}

		if ${EVEWindow[ByName,modal].Text.Find["The daily downtime will begin in"](exists)} || \
			${EVEWindow[ByName,modal].Text.Find["local session information is corrupt"](exists)}
		{
			EVEWindow[ByName,modal]:ClickButtonOK
			return FALSE
		}

		if ${EVEWindow[ByName,modal].Text.Find["has been flagged for recustomization"](exists)}
		{
			EVEWindow[ByName,modal]:ClickButtonNo
			return FALSE
		}
		if !${CharSelect.CharExists[${Config.Common.CharID}]}
		{
			return FALSE
		}

		CharSelect:ClickCharacter[${Config.Common.CharID}]
		UI:Update["obj_Login", "Character select command sent", "g"]
		This:Clear
		This:QueueState["Idle", 20000]
		This:QueueState["SelectCharacter"]
		return TRUE
	}
}