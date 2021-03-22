objectdef obj_StateQueue
{
	variable string Name
	variable int Frequency
	variable string Args

	method Initialize(string arg_Name, int arg_Frequency, string arg_Args)
	{
		Name:Set[${arg_Name}]
		Frequency:Set[${arg_Frequency}]
		Args:Set["${arg_Args.Escape}"]
	}
	
	method Set(string arg_Name, int arg_Frequency, string arg_Args)
	{
		Name:Set[${arg_Name}]
		Frequency:Set[${arg_Frequency}]
		Args:Set["${arg_Args.Escape}"]
	}
	
	method SetArgs(string arg_Args)
	{
		Args:Set["${arg_Args.Escape}"]
	}
}

objectdef obj_State
{
	variable queue:obj_StateQueue States
	variable obj_StateQueue CurState
	
	variable int NextPulse
	variable int PulseFrequency = 2000
	variable bool NonGameTiedPulse = FALSE
	variable bool IsIdle
	variable bool IndependentPulse = FALSE
	variable int RandomDelta = 500

	method Initialize()
	{
		CurState:Set["Idle", 100, ""]
		IsIdle:Set[TRUE]
		Event[ISXEVE_onFrame]:AttachAtom[This:Pulse]
	}
	
	method IndependentPulse()
	{
		IndependentPulse:Set[TRUE]
		Event[ISXEVE_onFrame]:DetachAtom[This:Pulse]
	}

	method Shutdown()
	{
		Event[ISXEVE_onFrame]:DetachAtom[This:Pulse]
	}
	

	method Pulse()
	{
		variable bool ReportIdle=TRUE
		if !${IndependentPulse}
		{
			if ${LavishScript.RunningTime} >= ${This.NextPulse}
			{
				if (!${ComBot.Paused} && ${Client.Ready}) || ${This.NonGameTiedPulse}
				{
					if ${This.${CurState.Name}[${CurState.Args}]}
					{
						if ${States.Used} == 0
						{
							This:QueueState["Idle", 100];
							IsIdle:Set[TRUE]
							ReportIdle:Set[FALSE]
						}
						CurState:Set[${States.Peek.Name}, ${States.Peek.Frequency}, "${States.Peek.Args.Escape}"]
						if ${ReportIdle}
						{
							UI:Log["${This(type)} State Change: ${States.Peek.Name}", TRUE]
						}
						States:Dequeue
					}
				}
				This.NextPulse:Set[${Math.Calc[${LavishScript.RunningTime} + ${CurState.Frequency} + ${Math.Rand[${RandomDelta}]}]}]
			}
		}
		else
		{
			if ${States.Used} == 0
			{
				This:QueueState["Idle", 100];
				IsIdle:Set[TRUE]
				ReportIdle:Set[FALSE]
			}
			
			if ${This.${CurState.Name}[${CurState.Args}]}
			{
				CurState:Set[${States.Peek.Name}, ${States.Peek.Frequency}, "${States.Peek.Args.Escape}"]
				if ${ReportIdle}
				{
					UI:Log["${This(type)} State Change: ${States.Peek.Name}", TRUE]
				}
				States:Dequeue
			}
		}
	}

	method QueueState(string arg_Name, int arg_Frequency=-1, string arg_Args="")
	{
		variable int var_Frequency
		if ${arg_Frequency} == -1
		{
			var_Frequency:Set[${This.PulseFrequency}]
		}
		else
		{
			var_Frequency:Set[${arg_Frequency}]
		}
		States:Queue[${arg_Name},${var_Frequency},"${arg_Args.Escape}"]
		This.IsIdle:Set[FALSE]
	}
	
	method InsertState(string arg_Name, int arg_Frequency=-1, string arg_Args="")
	{
		variable queue:obj_StateQueue tempStates
		tempStates:Clear
		variable iterator StateIterator
		States:GetIterator[StateIterator]
		if ${StateIterator:First(exists)}
		{
			do
			{
				tempStates:Queue[${StateIterator.Value.Name},${StateIterator.Value.Frequency},"${StateIterator.Value.Args.Escape}"]
			}
			while ${StateIterator:Next(exists)}
		}
		States:Clear
		
		
		variable int var_Frequency
		if ${arg_Frequency} == -1
		{
			var_Frequency:Set[${This.PulseFrequency}]
		}
		else
		{
			var_Frequency:Set[${arg_Frequency}]
		}
		States:Queue[${arg_Name},${var_Frequency},"${arg_Args.Escape}"]
		
		tempStates:GetIterator[StateIterator]
		if ${StateIterator:First(exists)}
		{
			do
			{
				States:Queue[${StateIterator.Value.Name},${StateIterator.Value.Frequency},"${StateIterator.Value.Args.Escape}"]
			}
			while ${StateIterator:Next(exists)}
		}
		
		This.IsIdle:Set[FALSE]
	}
	
	method SetStateArgs(string arg_Args="")
	{
		CurState:SetArgs["${arg_Args.Escape}"]
	}

	method Clear()
	{
		States:Clear
		CurState:Set["Idle", 100, ""]
		This.IsIdle:Set[TRUE]
	}

	member:bool Idle()
	{
		return TRUE
	}
	
	
}