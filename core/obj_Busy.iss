objectdef obj_Busy
{
	variable set BusyModes
	variable bool IsBusy
	variable queue:string ControlQueue
	variable string CurrentControl
	variable bool IsControlled = FALSE
	
	method SetBusy(string Name)
	{
		BusyModes:Add[${Name}]
		IsBusy:Set[TRUE]
	}
	
	method UnsetBusy(string Name)
	{
		BusyModes:Remove[${Name}]
		if ${BusyModes.Used} == 0
		{
			IsBusy:Set[FALSE]
		}
	}
	
	method RequestControl(string Name)
	{
		ControlQueue:Insert[${Name}]
		if !${IsControlled}
		{
			PopControl[]
		}
	}
	
	method ReleaseControl(string Name)
	{
		if ${Name.Equal[${CurrentControl}]}
		{
			PopControl[]
		}
	}
	
	method PopControl()
	{
		if ${ControlQueue.Used} > 0
		{
			CurrentControl:Set[${ControlQueue.Peek}]
			ControlQueue:Dequeue
			IsControlled:Set[TRUE]
		}
		else
		{
			CurrentControl:Set[""]
			IsControlled:Set[FALSE]
		}
	}
	
}