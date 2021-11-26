objectdef obj_Logger
{
	variable string LogFile
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

	method Log(string CallingModule, string StatusMessage, string Color="w", int Level=LOG_STANDARD)
	{
		/*
			Level = LOG_STANDARD - Standard, Log and Print to Screen
		*/

        variable string MSG
		MSG:Set["${Time.Time24}: ["]
		if ${CallingModule.Length} > 15
		{
			MSG:Concat["${CallingModule.Left[15]}]"]
		}
		else
		{
			MSG:Concat["${CallingModule}]"]
		}

		while ${MSG.Length} < 30
		{
			MSG:Concat[" "]
		}

		MSG:Concat["${StatusMessage.Escape}"]

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
}