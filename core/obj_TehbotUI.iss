objectdef obj_TehbotUI
{
	variable int NextPulse
	variable int PulseIntervalInMilliseconds = 60000

	variable int NextMsgBoxPulse
	variable int PulseMsgBoxIntervalInMilliSeconds = 15000
	variable queue:string ConsoleBuffer
	variable bool Reloaded = FALSE

	method Initialize()
	{
		ui -load Tehbot.xml
		This:Update["Tehbot", "Tehbot  Copyright � 2021  Tehtsuo", "o"]
		This:Update["Tehbot", "This program comes with ABSOLUTELY NO WARRANTY", "o"]
		This:Update["Tehbot", "This is free software and you are welcome to redistribute it", "o"]
		This:Update["Tehbot", "under certain conditions.  See LICENSE file for details", "o"]
		This:Update["Tehbot", "Current Version: \ayNEED TO INSERT VERSIONING", "g"]
		This:Update["Tehbot", "Initializing modules", "y"]

		Event[ISXEVE_onFrame]:AttachAtom[This:Pulse]
	}

	method Shutdown()
	{
		Event[ISXEVE_onFrame]:DetachAtom[This:Pulse]
		ui -unload Tehbot.xml
	}

	method Pulse()
	{
	    if ${LavishScript.RunningTime} >= ${This.NextPulse}
		{
    		This.NextPulse:Set[${Math.Calc[${LavishScript.RunningTime} + ${PulseIntervalInMilliseconds} + ${Math.Rand[500]}]}]
		}

		if ${Tehbot.Paused}
		{
			return
		}

	    if ${LavishScript.RunningTime} >= ${This.NextMsgBoxPulse}
		{
			if ${EVEWindow[ByName,modal].Text.Find["The daily downtime will begin in"](exists)}
			{
				EVEWindow[ByName,modal]:ClickButtonOK
				if ${Automate.Config.Downtime}
				{
					Automate:DeltaLogoutNow
				}
			}
			EVE:CloseAllMessageBoxes
			if ${CommonConfig.CloseChatInvites}
			{
				EVE:CloseAllChatInvites
			}

    		This.NextMsgBoxPulse:Set[${Math.Calc[${LavishScript.RunningTime} + ${PulseMsgBoxIntervalInMilliSeconds} + ${Math.Rand[500]}]}]
		}

	}

	method Reload()
	{
		ui -reload Tehbot.xml
		This.Reloaded:Set[TRUE]
		UIElement[TehbotTab@Tehbot].Tab[${CommonConfig.ActiveTab}]:Select
		if ${CommonConfig.Hidden}
		{
			UIElement[TehbotTab@Tehbot]:Hide
			This:SetText[Show]
		}
		else
		{
			UIElement[TehbotTab@Tehbot]:Show
			This:SetText[Hide]
		}
	}

	method Update(string CallingModule, string StatusMessage, string Color="w")
	{
		variable string MSG
		variable string MSGRemainder
		MSG:Set["\aw["]
		if ${CallingModule.Length} > 15
		{
			MSG:Concat[${CallingModule.Left[15]}]
		}
		else
		{
			MSG:Concat[${CallingModule}]
		}
		MSG:Concat["]"]

		while ${MSG.Length} < 20
		{
			MSG:Concat[" "]
		}

		MSG:Concat["\a${Color}${StatusMessage.Escape}"]

		if ${MSG.Length} > 85
		{
			MSGRemainder:Set[${MSG.Right[-85].Escape}]
			MSG:Set[${MSG.Left[85].Escape}]
			if ${This.Reloaded}
			{
				UIElement[StatusConsole@Status@TehbotTab@Tehbot]:Echo["${MSG.Escape}"]
				UIElement[StatusConsole@Status@TehbotTab@Tehbot]:Echo["-                 \a${Color}${MSGRemainder.Escape}"]
			}
		}
		else
		{
			if ${This.Reloaded}
			{
				UIElement[StatusConsole@Status@TehbotTab@Tehbot]:Echo["${MSG.Escape}"]
			}
		}
	}

}
