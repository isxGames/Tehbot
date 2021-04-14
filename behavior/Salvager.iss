objectdef obj_Configuration_Salvager
{
	variable string SetName = "Salvager"

	method Initialize()
	{
		if !${BaseConfig.BaseRef.FindSet[${This.SetName}](exists)}
		{
			UI:Update["Configuration", " ${This.SetName} settings missing - initializing", "o"]
			This:Set_Default_Values[]
		}
		UI:Update["Configuration", " ${This.SetName}: Initialized", "-g"]
	}

	member:settingsetref CommonRef()
	{
		return ${BaseConfig.BaseRef.FindSet[${This.SetName}]}
	}
	
	member:settingsetref SafeBookmarksRef()
	{
		if !${BaseConfig.BaseRef.FindSet[${This.SetName}].FindSet[SafeBookmarks](exists)}
		{
			This.CommonRef:AddSet[SafeBookmarks]
		}
		return ${BaseConfig.BaseRef.FindSet[${This.SetName}].FindSet[SafeBookmarks]}
	}	

	method Set_Default_Values()
	{
		BaseConfig.BaseRef:AddSet[${This.SetName}]
		This.CommonRef:AddSet[SafeBookmarks]		

		This.CommonRef:AddSetting[Dropoff_Type,Personal Hangar]
		This.CommonRef:AddSetting[Prefix,Salvage:]
		This.CommonRef:AddSetting[Dropoff,""]
	}

	Setting(string, Prefix, SetPrefix)
	Setting(string, Dropoff, SetDropoff)
	Setting(string, DropoffType, SetDropoffType)
	Setting(string, DropoffSubType, SetDropoffSubType)
}

objectdef obj_Salvager inherits obj_State
{
	variable obj_Configuration_Salvager Config
	variable obj_SalvageUI LocalUI
	
	variable bool ForceBookmarkCycle=FALSE
	variable index:int64 HoldOffPlayer
	variable index:int HoldOffTimer
	variable float NonDedicatedFullPercent = 0.95
	variable bool NonDedicatedNPCRun = FALSE
	variable bool Salvaging = FALSE
	variable queue:entity BeltPatrol
	variable set UsedBookmarks
	
	variable collection:int64 ReservedBookmarks
	
	variable obj_TargetList NPCs
	
	method Initialize()
	{
		This[parent]:Initialize
		LavishScript:RegisterEvent[Tehbot_SalvageBookmark]
		Event[Tehbot_SalvageBookmark]:AttachAtom[This:SalvageBookmarkEvent]
		LavishScript:RegisterEvent[Tehbot_ReserveBookmark]
		Event[Tehbot_ReserveBookmark]:AttachAtom[This:ReserveBookmarkEvent]
		NPCs:AddAllNPCs
		DynamicAddBehavior("Salvager", "Dedicated Salvager")
	}

	method Start()
	{
		UI:Update["obj_Salvage", "Started", "g"]
		if ${This.IsIdle}
		{
			This:QueueState["CheckCargoHold", 500]
		}
	}
	
	method Stop()
	{
		This:DeactivateStateQueueDisplay
		This:Clear
		noop This.DropCloak[FALSE]
	}

	method ReserveBookmarkEvent(string params)
	{
		ReservedBookmarks:Set[${params.Token[1,","]}, ${params.Token[2,","]}]
	}

	method SalvageBookmarkEvent(int64 ID)
	{
		EVE:RefreshBookmarks
		TimedCommand 50 Script[Tehbot].VariableScope.Salvager:AddBookmarksFromPilot[${ID}]
	}
	
	method AddBookmarksFromPilot(int64 ID)
	{
		variable index:bookmark Bookmarks
		variable iterator b

		EVE:GetBookmarks[Bookmarks]
		Bookmarks:GetIterator[b]
		if ${b:First(exists)}
			do
			{
				if ${b.Value.Label.Find[${Config.Prefix}]} && ${b.Value.CreatorID} == ${ID}
				{
					Config.SafeBookmarksRef:AddSetting[${b.Value.ID},${b.Value.Created.AsInt64}]
				}
			}
			while ${b:Next(exists)}		
		Config:Save
	}
	

	member:bool CheckBookmarks()
	{
		variable index:bookmark Bookmarks
		variable iterator BookmarkIterator
		variable string Target
		variable int64 TargetID
		variable int64 BookmarkTime=0
		variable bool BookmarkFound
		variable int64 BookmarkCreator
		variable iterator HoldOffIterator
		variable index:int RemoveHoldOff
		variable int RemoveDecAmount=0
		variable bool InHoldOff
		BookmarkFound:Set[FALSE]
		
		EVE:GetBookmarks[Bookmarks]
		Bookmarks:GetIterator[BookmarkIterator]
		
		HoldOffTimer:GetIterator[HoldOffIterator]
		if ${HoldOffIterator:First(exists)}
		do
		{
			if ${LavishScript.RunningTime} >= ${HoldOffIterator.Value}
			{
				RemoveHoldOff:Insert[${HoldOffIterator.Key}]
			}
		}
		while ${HoldOffIterator:Next(exists)}
		
		RemoveHoldOff:GetIterator[HoldOffIterator]
		if ${HoldOffIterator:First(exists)}
		do
		{
			HoldOffPlayer:Remove[${Math.Calc[${HoldOffIterator.Value}-${RemoveDecAmount}]}]
			HoldOffTimer:Remove[${Math.Calc[${HoldOffIterator.Value}-${RemoveDecAmount}]}]
			RemoveDecAmount:Inc
		}
		while ${HoldOffIterator:Next(exists)}
		
		HoldOffPlayer:GetIterator[HoldOffIterator]
		
		variable bool br=false
		variable iterator reservedbookmark

		if ${BookmarkIterator:First(exists)}
		do
		{	
			br:Set[FALSE]
			ReservedBookmarks:GetIterator[reservedbookmark]
			if ${reservedbookmark:First(exists)}
				do
				{
					if ${reservedbookmark.Value} == ${BookmarkIterator.Value.ID}
						br:Set[TRUE]
				}
				while ${reservedbookmark:Next(exists)}
			if ${br}
				continue
			if ${BookmarkIterator.Value.Label.Find[${Config.Prefix}]} && ${BookmarkIterator.Value.JumpsTo} <= 0 && ${Config.SafeBookmarks.FindSetting[${BookmarkIterator.Value.ID}]}
			{
				InHoldOff:Set[FALSE]
				if ${HoldOffIterator:First(exists)}
				do
				{
					if ${HoldOffIterator.Value.Equal[${BookmarkIterator.Value.CreatorID}]}
					{
						InHoldOff:Set[TRUE]
					}
				}
				while ${HoldOffIterator:Next(exists)}
				if !${InHoldOff}
				{
					if ${BookmarkIterator.Value.Created.AsInt64} + 72000000000 < ${EVETime.AsInt64} && !${UsedBookmarks.Contains[${BookmarkIterator.Value.ID}]}
					{
						UI:Update["Salvager", "Removing expired bookmark - ${BookmarkIterator.Value.Label}", "o", TRUE]
						BookmarkIterator.Value:Remove
						UsedBookmarks:Add[${BookmarkIterator.Value.ID}]
						This:InsertState["CheckBookmarks"]
						This:InsertState["Idle", 5000]
						return FALSE
					}
					if (${BookmarkIterator.Value.Created.AsInt64} < ${BookmarkTime} || ${BookmarkTime} == 0) && !${UsedBookmarks.Contains[${BookmarkIterator.Value.ID}]}
					{
						Target:Set[${BookmarkIterator.Value.Label}]
						TargetID:Set[${BookmarkIterator.Value.ID}]
						BookmarkTime:Set[${BookmarkIterator.Value.Created.AsInt64}]
						BookmarkCreator:Set[${BookmarkIterator.Value.CreatorID}]
						BookmarkFound:Set[TRUE]
					}
				}
			}
		}
		while ${BookmarkIterator:Next(exists)}

		if ${BookmarkIterator:First(exists)} && !${BookmarkFound}
		do
		{	
			br:Set[FALSE]
			ReservedBookmarks:GetIterator[reservedbookmark]
			if ${reservedbookmark:First(exists)}
				do
				{
					if ${reservedbookmark.Value} == ${BookmarkIterator.Value.ID}
						br:Set[TRUE]
				}
				while ${reservedbookmark:Next(exists)}
			if ${br}
				continue
			if ${BookmarkIterator.Value.Label.Find[${Config.Prefix}]} && ${Config.SafeBookmarks.FindSetting[${BookmarkIterator.Value.ID}]}
			{
				InHoldOff:Set[FALSE]
				if ${HoldOffIterator:First(exists)}
				do
				{
					if ${HoldOffIterator.Value.Equal[${BookmarkIterator.Value.CreatorID}]}
					{
						InHoldOff:Set[TRUE]
					}
				}
				while ${HoldOffIterator:Next(exists)}
				if !${InHoldOff}
				{
					if ${BookmarkIterator.Value.Created.AsInt64} + 72000000000 < ${EVETime.AsInt64} && !${UsedBookmarks.Contains[${BookmarkIterator.Value.ID}]}
					{
						UI:Update["Salvager", "Removing expired bookmark - ${BookmarkIterator.Value.Label}", "o", TRUE]
						BookmarkIterator.Value:Remove
						UsedBookmarks:Add[${BookmarkIterator.Value.ID}]
						This:InsertState["CheckBookmarks"]
						This:InsertState["Idle", 5000]
						return TRUE
					}
					if (${BookmarkIterator.Value.Created.AsInt64} < ${BookmarkTime} || ${BookmarkTime} == 0) && !${UsedBookmarks.Contains[${BookmarkIterator.Value.ID}]}
					{
						Target:Set[${BookmarkIterator.Value.Label}]
						TargetID:Set[${BookmarkIterator.Value.ID}]
						BookmarkTime:Set[${BookmarkIterator.Value.Created.AsInt64}]
						BookmarkCreator:Set[${BookmarkIterator.Value.CreatorID}]
						BookmarkFound:Set[TRUE]
					}
				}
			}
		}
		while ${BookmarkIterator:Next(exists)}
		
		if ${BookmarkFound}
		{
			relay "all other" -event Tehbot_ReserveBookmark ${Me.ID},${TargetID}
			UI:Update["obj_Salvage", "Setting course for ${Target}", "g"]
			Move:Bookmark[${Target}, TRUE]
			This:QueueState["Traveling"]
			This:QueueState["Log", 1000, "Salvaging at ${Target}"]
			This:QueueState["InitialUpdate", 100]
			This:QueueState["Updated", 100]
			This:QueueState["DropCloak", 50, TRUE]
			This:QueueState["SalvageWrecks", 500, "${BookmarkCreator}"]
			This:QueueState["DropCloak", 50, FALSE]
			This:QueueState["ClearAlreadySalvaged", 100]
			This:QueueState["DeleteBookmark", 1000, "${BookmarkCreator}"]
			This:QueueState["RefreshBookmarks", 3000]
			This:QueueState["GateCheck", 1000, "${BookmarkCreator}"]
			return TRUE
		}

		UI:Update["obj_Salvage", "No salvage bookmark found - returning to station", "g"]
		This:QueueState["Offload"]
		This:QueueState["Traveling"]
		This:QueueState["Log", 10, "Idling for 30 seconds"]
		This:QueueState["Idle", 30000]
		This:QueueState["CheckCargoHold", 500]
		return TRUE
	}

	method ReportOldestBookmark()
	{
		variable index:bookmark Bookmarks
		variable iterator BookmarkIterator
		variable iterator reservedbookmark
		variable bool br
		variable int64 BookmarkTime=0
		variable int totalBookmarks=0
		variable string BookmarkLabel
		EVE:GetBookmarks[Bookmarks]
		Bookmarks:GetIterator[BookmarkIterator]		
		if ${BookmarkIterator:First(exists)}
			do
			{	
				br:Set[FALSE]
				ReservedBookmarks:GetIterator[reservedbookmark]
				if ${reservedbookmark:First(exists)}
					do
					{
						if ${reservedbookmark.Value} == ${BookmarkIterator.Value.ID}
							br:Set[TRUE]
					}
					while ${reservedbookmark:Next(exists)}
				if ${br}
					continue
				if ${BookmarkIterator.Value.Label.Find[${Config.Prefix}]} && ${Config.SafeBookmarks.FindSetting[${BookmarkIterator.Value.ID}]}
				{
					InHoldOff:Set[FALSE]
					if ${HoldOffIterator:First(exists)}
					do
					{
						if ${HoldOffIterator.Value.Equal[${BookmarkIterator.Value.CreatorID}]}
						{
							InHoldOff:Set[TRUE]
						}
					}
					while ${HoldOffIterator:Next(exists)}
					if !${InHoldOff}
					{
						if !${UsedBookmarks.Contains[${BookmarkIterator.Value.ID}]}
							totalBookmarks:Inc
						if (${BookmarkIterator.Value.Created.AsInt64} < ${BookmarkTime} || ${BookmarkTime} == 0) && !${UsedBookmarks.Contains[${BookmarkIterator.Value.ID}]}
						{
							BookmarkTime:Set[${BookmarkIterator.Value.Created.AsInt64}]
							BookmarkLabel:Set[${BookmarkIterator.Value.Label}]
						}
					}
				}
			}
			while ${BookmarkIterator:Next(exists)}		
			
		if ${BookmarkTime} > 0
		{
			variable int expire
			expire:Set[${Math.Calc[(${BookmarkTime} + 72000000000 - ${EVETime.AsInt64}) / 600000000].Int}]
			UI:Update["Salvager", "Total Valid Salvage Bookmarks: \ar${totalBookmarks}", "o"]
			UI:Update["Salvager", "Oldest Salvage bookmark expires in \ar${expire} \aominutes", "o"]
			UI:Update["Salvager", " Named: \ar${BookmarkLabel}", "o"]
			
		}
	}
	
	member:bool Traveling()
	{
		if ${Cargo.Processing} || ${Move.Traveling} || ${Me.ToEntity.Mode} == 3
		{
			return FALSE
		}
		return TRUE
	}
	
	member:bool Log(string text)
	{
		UI:Update["obj_Salvage", "${text}", "g"]
		return TRUE
	}
	
	
	member:bool DoneSalvaging()
	{
		Salvaging:Set[FALSE]
	}
	
	member:bool InitialUpdate()
	{
		NPCs:RequestUpdate
		return TRUE
	}
	
	member:bool Updated()
	{
		return ${NPCs.Updated}
	}

	member:bool DropCloak(bool arg)
	{
		AutoModule.DropCloak:Set[${arg}]
		return TRUE
	}
	
	member:bool SalvageWrecks(int64 BookmarkCreator)
	{
		variable float FullHold = 0.95
		variable bool NPCRun = TRUE

		NPCs:RequestUpdate
		
		if ${NPCs.TargetList.Used} && ${NPCRun}
		{
			UI:Update["obj_Salvage", "Pocket has NPCs - Jumping Clear", "g"]

			HoldOffPlayer:Insert[${BookmarkCreator}]
			HoldOffTimer:Insert[${Math.Calc[${LavishScript.RunningTime} + 600000]}]
			This:Clear
			This:QueueState["JumpToCelestial"]
			This:QueueState["Traveling"]
			This:QueueState["RefreshBookmarks", 3000]
			This:QueueState["CheckBookmarks", 3000]
			
			return TRUE
		}

		if !${Client.Inventory}
		{
			return FALSE
		}

		if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].UsedCapacity} / ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].Capacity} > ${FullHold}
		{
			UI:Update["Salvage", "Unload trip required", "g"]
			This:Clear
			This:QueueState["Offload"]
			This:QueueState["Traveling"]
			This:QueueState["RefreshBookmarks", 3000]
			This:QueueState["CheckBookmarks", 3000]
			return TRUE
		}

		if ${Salvage.Wrecks.TargetList.Used} == 0
		{
			return TRUE
		}
		else
		{
			variable float MaxRange = ${Ship.ModuleList_TractorBeams.Range}
			if ${MaxRange} > ${MyShip.MaxTargetRange}
			{
				MaxRange:Set[${MyShip.MaxTargetRange}]
			}

			variable iterator TargetIterator
			Salvage.Wrecks.TargetList:GetIterator[TargetIterator]
			if ${TargetIterator:First(exists)}
			{
				do
				{
					if ${TargetIterator.Value.ID(exists)}
					{
						if !${TargetIterator.Value.HaveLootRights}
						{
							Move:Approach[${TargetIterator.Value.ID}]
							return FALSE
						}
						elseif	${TargetIterator.Value.Distance} > ${MaxRange}
						{
							Move:Approach[${TargetIterator.Value.ID}]
							return FALSE
						}
					}
				}
				while ${TargetIterator:Next(exists)}
			}
		}
		return FALSE
	}
	
	member:bool ClearAlreadySalvaged()
	{
		AlreadySalvaged:Clear
		return TRUE
	}
	
	member:bool GateCheck(int64 BookmarkCreator)
	{
		variable index:bookmark Bookmarks
		variable iterator BookmarkIterator
		variable bool UseJumpGate=FALSE
		if ${Entity[GroupID == GROUP_WARPGATE](exists)}
		{
			HoldOffPlayer:Insert[${BookmarkCreator}]
			HoldOffTimer:Insert[${Math.Calc[${LavishScript.RunningTime} + 600000]}]
			This:Clear
			This:QueueState["RefreshBookmarks", 3000]
			This:QueueState["CheckBookmarks", 3000]
			return TRUE
		}
		This:QueueState["CheckCargoHold", 500]
		return TRUE
	}
	
	member:bool JumpToCelestial()
	{
		UI:Update["Salvager", "Warping to ${Entity[GroupID = GROUP_SUN].Name}", "g"]
		Move:Warp[${Entity["GroupID = GROUP_SUN"].ID}]
		return TRUE
	}
	
	member:bool DeleteBookmark(int64 BookmarkCreator, int Removed=-1)
	{
		echo deletebookmark
		variable index:bookmark Bookmarks
		variable iterator BookmarkIterator
		EVE:GetBookmarks[Bookmarks]
		Bookmarks:GetIterator[BookmarkIterator]
		if ${BookmarkIterator:First(exists)}
		do
		{
			if ${BookmarkIterator.Value.Label.Find[${Config.Prefix}]} && ${BookmarkIterator.Value.CreatorID.Equal[${BookmarkCreator}]}
			{
				if ${BookmarkIterator.Value.JumpsTo} == 0
				{
					if ${BookmarkIterator.Value.Distance} < 150000 
					{
						if ${Removed} != ${BookmarkIterator.Value.ID}
						{
							UI:Update["obj_Salvage", "Finished Salvaging ${BookmarkIterator.Value.Label} - Deleting", "g"]
							This:InsertState["DeleteBookmark", 1000, "${BookmarkCreator},${BookmarkIterator.Value.ID}"]
							BookmarkIterator.Value:Remove
							return TRUE
						}
						else
						{
							
							UsedBookmarks:Add[${BookmarkIterator.Value.ID}]
							return TRUE
						}
					}
				}
			}
		}
		while ${BookmarkIterator:Next(exists)}
		return TRUE
	}
	
	
	member:bool CheckCargoHold()
	{
		if !${Client.Inventory}
		{
			return FALSE
		}
		if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].UsedCapacity} / ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo].Capacity} > 0.75
		{
			UI:Update["obj_Salvage", "Unload trip required", "g"]
			This:QueueState["Offload"]
			This:QueueState["Traveling"]
		}
		else
		{
			UI:Update["obj_Salvage", "Unload trip not required", "g"]
		}
		This:QueueState["RefreshBookmarks", 3000]
		This:QueueState["CheckBookmarks", 3000]
		return TRUE
	}

	
	

	member:bool RefreshBookmarks(bool refreshdone=FALSE)
	{
		if !${refreshdone}
		{
			UI:Update["obj_Salvage", "Refreshing bookmarks", "g"]
			EVE:RefreshBookmarks
			This:InsertState["RefreshBookmarks", 2000, "TRUE"]
			return TRUE
		}
		
		This:ReportOldestBookmark
		return TRUE
	}
	
	member:bool Offload()
	{
		switch ${Config.DropoffType}
		{
			case Personal Hangar
				Cargo:At[${Config.Dropoff}]:Unload
				break
			default
				Cargo:At[${Config.Dropoff},${Config.DropoffType},${Config.DropoffSubType},${Config.DropoffContainer}]:Unload
				break
		}
		return TRUE
	}

}




objectdef obj_SalvageUI inherits obj_State
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

		UIElement[DropoffList@DropoffFrame@Tehbot_DedicatedSalvager_Frame@Tehbot_DedicatedSalvager]:ClearItems
		if ${BookmarkIterator:First(exists)}
			do
			{	
				if ${UIElement[Dropoff@DropoffFrame@Tehbot_DedicatedSalvager_Frame@Tehbot_DedicatedSalvager].Text.Length}
				{
					if ${BookmarkIterator.Value.Label.Left[${Salvager.Config.Dropoff.Length}].Equal[${Salvager.Config.Dropoff}]}
						UIElement[DropoffList@DropoffFrame@Tehbot_DedicatedSalvager_Frame@Tehbot_DedicatedSalvager]:AddItem[${BookmarkIterator.Value.Label.Escape}]
				}
				else
				{
					UIElement[DropoffList@DropoffFrame@Tehbot_DedicatedSalvager_Frame@Tehbot_DedicatedSalvager]:AddItem[${BookmarkIterator.Value.Label.Escape}]
				}
			}
			while ${BookmarkIterator:Next(exists)}

			
		return FALSE
	}

}