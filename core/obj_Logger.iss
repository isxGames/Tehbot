objectdef obj_Logger
{
	variable string LogFile
	variable string LogLevelBar = LOG_DEBUG
	variable string LogModuleName
	variable string LogInfoColor

	variable queue:string ConsoleBuffer
	variable string PreviousMsg

    variable bool dedup = FALSE

	method Initialize()
	{
		declare FP filepath "${Script.CurrentDirectory}"
		if !${FP.FileExists["Config"]}
		{
			FP:MakeSubdirectory["Config"]
		}
		FP:Set["${Script.CurrentDirectory}/Config"]
		if !${FP.FileExists["Logs"]}
		{
			FP:MakeSubdirectory["Logs"]
		}
		This.LogFile:Set["./Config/Logs/${Me.Name} - ${Time.Date.Replace["\/","."]}.log"]

		This:InitializeLogs
	}

	method InitializeLogs()
	{
		redirect -append "${This.LogFile}" echo "--------------------------------------------------------------------------------------"
		redirect -append "${This.LogFile}" echo "Bot starting on ${Time.Date} at ${Time.Time24}"
	}

	method Log(string CallingModule, string StatusMessage, string Color = "w", int level = LOG_INFO, int logLevelBar = LOG_DEBUG)
	{
		if ${level} < ${logLevelBar}
		{
			return
		}

        variable string MSG
		MSG:Set["${Time.Time24}: "]

		switch ${level}
		{
			case LOG_DEBUG
				MSG:Concat["DEBUG"]
				break
			case LOG_INFO
				MSG:Concat["INFO"]
				break
			case LOG_CRITICAL
				MSG:Concat["CRITICAL"]
				break
		}

		while ${MSG.Length} < 20
		{
			MSG:Concat[" "]
		}

		if ${CallingModule.Length} > 15
		{
			MSG:Concat["[${CallingModule.Left[15]}]"]
		}
		else
		{
			MSG:Concat["[${CallingModule}]"]
		}

		while ${MSG.Length} < 40
		{
			MSG:Concat[" "]
		}

		MSG:Concat["${StatusMessage.Escape.Replace["\"", ""].Replace["\\", ""]}"]

		variable bool Filter = FALSE

        if ${StatusMessage.Escape.Equal["${This.PreviousMsg.Escape}"]}
        {
            Filter:Set[TRUE]
        }
        elseif ${dedup}
        {
            This.PreviousMsg:Set["${StatusMessage.Escape}"]
        }

        ; Write to log file.
        redirect -append "${This.LogFile}" Echo "${MSG}"

        ; Update UI.
        if !${Filter}
        {
            UI:Update["${CallingModule.Escape}", "${StatusMessage.Escape}", "${Color}"]
        }
	}

	method LogInfo(string message)
	{
		if !${LogModuleName.NotNULLOrEmpty}
		{
			LogModuleName:Set[${This.ObjectName}]
		}
		; Don't use This:Log or it won't work when inherited.
		Logger:Log[${LogModuleName}, "${message.Escape}", "${LogInfoColor}", LOG_INFO, ${This.LogLevelBar}]
	}

	method LogDebug(string message)
	{
		if !${LogModuleName.NotNULLOrEmpty}
		{
			LogModuleName:Set[${This.ObjectName}]
		}
		; Don't use This:Log or it won't work when inherited.
		Logger:Log[${LogModuleName}, "${message.Escape}", "", LOG_DEBUG, ${This.LogLevelBar}]
	}

	method LogCritical(string message)
	{
		if !${LogModuleName.NotNULLOrEmpty}
		{
			LogModuleName:Set[${This.ObjectName}]
		}
		; Don't use This:Log or it won't work when inherited.
		Logger:Log[${LogModuleName}, "${message.Escape}", "r", LOG_CRITICAL, ${This.LogLevelBar}]
	}
}