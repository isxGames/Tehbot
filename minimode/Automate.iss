objectdef obj_Configuration_Automate
{
	variable string SetName = "Automate"

	method Initialize()
	{
		if !${BaseConfig.BaseRef.FindSet[${This.SetName}](exists)}
		{
			UI:Update["Automate", " ${This.SetName} settings missing - initializing", "o"]
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
		This.CommonRef:AddSetting[Hour, 20]
		This.CommonRef:AddSetting[Minute, 0]
		This.CommonRef:AddSetting[Bookmark, ""]
		This.CommonRef:AddSetting[LaunchCommand, ""]
	}

	Setting(int, Hour, SetHour)
	Setting(int, Minute, SetMinute)
	Setting(int, LogoutDelta, SetLogoutDelta)
	Setting(int, StartHour, SetStartHour)
	Setting(int, StartMinute, SetStartMinute)
	Setting(int, StartDelta, SetStartDelta)
	Setting(bool, DelayLogin, SetDelayLogin)
	Setting(bool, DelayLoginDelta, SetDelayLoginDelta)
	Setting(bool, Questor, SetQuestor)
	Setting(bool, TimedLogout, SetTimedLogout)
	Setting(bool, ScheduleLogout, SetScheduleLogout)
	Setting(string, Bookmark, SetBookmark)
	Setting(bool, Launch, SetLaunch)
	Setting(bool, Downtime, SetDowntime)
	Setting(string, LaunchCommand, SetLaunchCommand)
}


objectdef obj_Automate inherits obj_State
{
	variable obj_Configuration_Automate Config
	variable obj_AutomateUI LocalUI
	variable bool StartComplete=FALSE
	
	method Initialize()
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]
		PulseFrequency:Set[500]
		LavishScript:RegisterEvent[QuestorIdle]
		Event[QuestorIdle]:AttachAtom[This:QuestorIdle]
		DynamicAddMiniMode("Automate", "Automate")
	}
	
	method Start()
	{
		UI:Update["Automate", "Starting Automate", "g"]
		StartComplete:Set[FALSE]
		if !${Me(exists)} && !${MyShip(exists)} && !(${Me.InSpace} || ${Me.InStation})
		{
			if ${Config.DelayLogin}
			{
				UI:Update["Automate", "Login will proceed at \ag${Config.StartHour}:${Config.StartMinute}\ay plus ~\ag${Config.StartDelta}\ay minutes", "y"]
				TehbotLogin.Wait:Set[TRUE]
			}
			if ${Config.DelayLoginDelta}
			{
				UI:Update["Automate", "Login will proceed in ~\ag${Config.StartDelta}\ay minutes", "y"]
				TehbotLogin.Wait:Set[TRUE]
				variable int Delta=${Math.Rand[${Config.StartDelta} + 1]}
				StartComplete:Set[TRUE]
				UI:Update["Automate", "Starting in \ao${Delta}\ag minutes", "g"]
				This:QueueState["AllowLogin", ${Math.Calc[${Delta} * 60000]}.Int]
				This:QueueState["WaitForLogin"]
				This:QueueState["Launch"]
			}
			else
			{
				This:QueueState["WaitForLogin"]
				This:QueueState["Launch"]
			}
		}
		else
		{
			This:QueueState["Launch"]
		}
		if ${Config.TimedLogout}
		{
			variable int Logout=${Math.Calc[${Config.Hour} * 60 + ${Config.Minute} + ${Math.Rand[${Config.LogoutDelta} + 1]}]}
			UI:Update["Automate", "Logout in \ag${Config.Hour}\ay hours \ag${Config.Minute}\ay minutes plus ~\ag${Config.LogoutDelta}\ay minutes", "y"]
			echo  This:QueueState["Idle", ${Math.Calc[${Logout} * 60000].Int}]
			This:QueueState["Idle", ${Math.Calc[${Logout} * 60000].Int}]
			if ${Config.Questor}
			{
				This:QueueState["LogoutQuestor"]
			}
			else
			{
				This:QueueState["MoveToLogout"]
				This:QueueState["Traveling"]
				This:QueueState["Logout"]
			}
		}
		This:QueueState["Automate"]
	}
	
	method Stop()
	{
		This:Clear
		UI:Update["Automate", "Stopping Automate", "g"]
	}
	
	member:bool Automate()
	{
		if ${Time.Hour} == ${Config.Hour} && ${Time.Minute} == ${Config.Minute}
		{
			variable int Logout=${Math.Rand[${Config.LogoutDelta} + 1]}
			UI:Update["Automate", "Logout will proceed in \ao${Logout}\ag minutes", "g"]
			This:QueueState["Idle", ${Math.Calc[${Logout} * 60000].Int}
			if ${Config.Questor}
			{
				This:QueueState["LogoutQuestor"]
			}
			else
			{
				This:QueueState["MoveToLogout"]
				This:QueueState["Traveling"]
				This:QueueState["Logout"]
			}
			return TRUE
		}
		if ${Time.Hour} == ${Config.StartHour} && ${Time.Minute} == ${Config.StartMinute} && !${StartComplete}
		{
			variable int Delta=${Math.Rand[${Config.StartDelta} + 1]}
			StartComplete:Set[TRUE]
			UI:Update["Automate", "Starting in \ao${Delta}\ag minutes", "g"]
			This:QueueState["AllowLogin", ${Math.Calc[${Delta} * 60000]}]
			This:QueueState["WaitForLogin"]
			This:QueueState["AutoStart"]
			This:QueueState["Launch"]
			This:QueueState["Automate"]
			return TRUE
		}
		return FALSE
	}
	
	method QuestorIdle()
	{
		echo Automate found Questor is Idle!
	}
	
	member:bool AllowLogin()
	{
		TehbotLogin.Wait:Set[FALSE]
		return TRUE
	}
	
	member:bool WaitForLogin()
	{
		if ${Me(exists)} && ${MyShip(exists)} && (${Me.InSpace} || ${Me.InStation})
		{
			echo Logged in
			return TRUE
		}
		return FALSE
	}
	
	member:bool AutoStart()
	{
		Tehbot:Resume
		return TRUE
	}
	
	member:bool Launch()
	{
		echo Launching ${Config.LaunchCommand}
		if ${Config.Launch}
		{
			execute ${Config.LaunchCommand}
		}
		return TRUE
	}
	
	method DeltaLogoutNow()
	{
		variable int Logout=${Math.Rand[${Config.LogoutDelta} + 1]}
		UI:Update["Automate", "Logout will proceed in \ao${Logout}\ag minutes", "g"]
		This:Clear
		This:QueueState["Idle", ${Math.Calc[${Logout} * 60000].Int}
		This:QueueState["MoveToLogout"]
		This:QueueState["Traveling"]
		This:QueueState["Logout"]
	}

	method LogoutNow()
	{
		UI:Update["Automate", "Logout time!", "r"]
		This:Clear
		This:QueueState["MoveToLogout"]
		This:QueueState["Traveling"]
		This:QueueState["Logout"]
	}
	
	
	method GotoLogoutNow()
	{
		UI:Update["Automate", "Going Home!", "r"]
		This:Clear
		This:QueueState["MoveToLogout"]
		This:QueueState["Traveling"]
	}

	method StationaryLogoutNow()
	{
		This:Clear
		This:QueueState["Logout"]
	}
	
	member:bool MoveToLogout()
	{
		if ${Busy.IsBusy}
		{
			UI:Update["Automate", "Waiting for drones", "y"]
			return FALSE
		}
		variable iterator Behaviors
		Move.NonGameTiedPulse:Set[TRUE]
		Dynamic.Behaviors:GetIterator[Behaviors]
		if ${Behaviors:First(exists)}
		{
			do
			{
				${Behaviors.Value.Name}:Clear
			}
			while ${Behaviors:Next(exists)}
		}
		UIElement[Run@TitleBar@Tehbot]:SetText[Run]
		Move:Clear
		Move.Traveling:Set[FALSE]
		Move:Bookmark[${Config.Bookmark}]
		return TRUE
	}
	
	member:bool Traveling()
	{
		if ${Move.Traveling} || ${Me.ToEntity.Mode} == 3
		{
			return FALSE
		}
		return TRUE
	}
	
	member:bool Logout()
	{
		EVE:Execute[CmdQuitGame]
		endscript Tehbot
	}
	member:bool LogoutQuestor()
	{
		execute SetExitWhenIdle TRUE
		endscript Tehbot
	}
}


objectdef obj_AutomateUI inherits obj_State
{


	method Initialize()
	{
		This[parent]:Initialize
		This.NonGameTiedPulse:Set[TRUE]
	}
	
	method Start()
	{
		This:QueueState["UpdateBookmarkLists", 5]
	}
	
	method Stop()
	{
		This:Clear
	}

	member:bool UpdateBookmarkLists()
	{
		variable index:bookmark Bookmarks
		variable iterator BookmarkIterator

		EVE:GetBookmarks[Bookmarks]
		Bookmarks:GetIterator[BookmarkIterator]
		

		UIElement[BookmarkList@AutoLogoutFrame@Tehbot_Automate_Frame@Tehbot_Automate]:ClearItems
		if ${BookmarkIterator:First(exists)}
			do
			{	
				if ${UIElement[Bookmark@AutoLogoutFrame@Tehbot_Automate_Frame@Tehbot_Automate].Text.Length}
				{
					if ${BookmarkIterator.Value.Label.Left[${Automate.Config.Bookmark.Length}].Equal[${Automate.Config.Bookmark}]}
						UIElement[BookmarkList@AutoLogoutFrame@Tehbot_Automate_Frame@Tehbot_Automate]:AddItem[${BookmarkIterator.Value.Label.Escape}]
				}
				else
				{
					UIElement[BookmarkList@AutoLogoutFrame@Tehbot_Automate_Frame@Tehbot_Automate]:AddItem[${BookmarkIterator.Value.Label.Escape}]
				}
			}
			while ${BookmarkIterator:Next(exists)}
			
			
		return FALSE
	}

}