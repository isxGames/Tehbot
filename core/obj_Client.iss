objectdef obj_Client
{
	variable int PulseIntervalInMilliseconds = 500
	variable int NextPulse

	variable bool Ready=TRUE

	variable bool TryWarpToBookmark=FALSE
	variable int64 SystemID=${Me.SolarSystemID}

	variable uint UndockWarpBookmarkFilterQuery

	method Initialize()
	{
		Event[ISXEVE_onFrame]:AttachAtom[This:Pulse]
		UndockWarpBookmarkFilterQuery:Set[${LavishScript.CreateQuery[SolarSystemID == ${Me.SolarSystemID} && Label =- "${UndockWarp.Config.substring}" && Distance > 150000 && Distance < 50000000]}]
	}

	method Shutdown()
	{
		LavishScript:FreeQuery[${UndockWarpBookmarkFilterQuery}]
		Event[ISXEVE_onFrame]:DetachAtom[This:Pulse]
		if !${EVE.Is3DDisplayOn}
		{
			EVE:Toggle3DDisplay
		}
		if !${EVE.IsUIDisplayOn}
		{
			EVE:ToggleUIDisplay
		}
		if !${EVE.IsTextureLoadingOn}
		{
			EVE:ToggleTextureLoading
		}
	}

	method Pulse()
	{
		if ${LavishScript.RunningTime} >= ${This.NextPulse}
		{
			if ${Me.SolarSystemID} != ${SystemID} && !${This.TryWarpToBookmark}
			{
				SystemID:Set[${Me.SolarSystemID}]
				This:Wait[5000]
				return
			}

			This.NextPulse:Set[${Math.Calc[${LavishScript.RunningTime} + ${PulseIntervalInMilliseconds} + ${Math.Rand[500]}]}]

			This:ManageGraphics

			if ${EVEWindow[rewardsWnd](exists)}
			{
				if ${EVEWindow[rewardsWnd].Button[DarkStyleButtonPrimary](exists)}
				{
					EVEWindow[rewardsWnd].Button[DarkStyleButtonPrimary]:Press
				}
				else
				{
					EVEWindow[rewardsWnd]:Close
				}
				return
			}
			if ${EVEWindow[ByName, NewFeatureNotifyWnd](exists)}
			{
				EVEWindow[ByName, NewFeatureNotifyWnd]:Close
				return
			}

			;  Implement menu/config for this
			if ${Me.Fleet.Invited}
			{
				variable index:being corp
				variable iterator c

				EVE:GetOnlineCorpMembers[corp]
				corp:GetIterator[c]
				if ${c:First(exists)}
					do
					{
						if ${Me.Fleet.InvitationText.Find[${c.Value.Name}]} == 1
						{
							Me.Fleet:AcceptInvite
							return
						}
					}
					while ${c:Next(exists)}
			}

			if ${Me.InStation}
			{
				TryWarpToBookmark:Set[TRUE]
			}

			if ${This.TryWarpToBookmark} && ${This.InSpace}
			{
				This:UndockWarp
			}

			if ${Tehbot.Paused}
			{
				return
			}

			This.Ready:Set[TRUE]
		}
	}

	member:bool InSpace()
	{
		if ${Me.InSpace(type).Name.Equal[bool]} && ${EVE.EntitiesCount} > 0
		{
			return ${Me.InSpace}
		}
		return FALSE
	}

	method ManageGraphics()
	{
		if ${Config.Common.Disable3D} && ${EVE.Is3DDisplayOn}
		{
			EVE:Toggle3DDisplay
		}
		elseif !${Config.Common.Disable3D} && !${EVE.Is3DDisplayOn}
		{
			EVE:Toggle3DDisplay
		}
		if ${Config.Common.DisableUI} && ${EVE.IsUIDisplayOn}
		{
			EVE:ToggleUIDisplay
		}
		elseif !${Config.Common.DisableUI} && !${EVE.IsUIDisplayOn}
		{
			EVE:ToggleUIDisplay
		}
		if ${Config.Common.DisableTexture} && ${EVE.IsTextureLoadingOn}
		{
			EVE:ToggleTextureLoading
		}
		elseif !${Config.Common.DisableTexture} && !${EVE.IsTextureLoadingOn}
		{
			EVE:ToggleTextureLoading
		}
	}

	method UndockWarp()
	{
		variable index:bookmark undockBookMarkIdx
		variable string suffix
		suffix:Set[${UndockWarp.Config.UndockSuffix}]
		EVE:GetBookmarks[undockBookMarkIdx]
		undockBookMarkIdx:RemoveByQuery[${UndockWarpBookmarkFilterQuery}, FALSE]
		undockBookMarkIdx:Collapse

		if ${undockBookMarkIdx.Used}
		{
			Logger:Log["Client", "Undock warping to ${undockBookMarkIdx.Get[1].Label}", "g"]
			undockBookMarkIdx.Get[1]:WarpTo
			Client:Wait[5000]
		}
		This.TryWarpToBookmark:Set[FALSE]
	}

	method Wait(int delay)
	{
		Logger:Log["Client", "Initiating ${delay} millisecond wait", "-o"]
		This.Ready:Set[FALSE]
		This.NextPulse:Set[${Math.Calc[${LavishScript.RunningTime} + ${delay}]}]
	}

	variable bool cycleCargoHold = FALSE
	member:bool Inventory()
	{
		if !${EVEWindow[Inventory](exists)}
		{
			EVE:Execute[OpenInventory]
			return FALSE
		}
		variable index:item cargo
		if !${EVEWindow[Inventory].ChildWindow[${Me.ShipID},ShipCargo]:GetItems[cargo](exists)}
		{
			Logger:Log["Client", "Cargo hold information invalid, activating", "g"]
			EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo]:MakeActive
			return FALSE
		}
		if ${MyShip.HasOreHold}
		{
			if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipOreHold].UsedCapacity} == -1 || \
				${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipOreHold].Capacity} <= 0
			{
				if !${cycleCargoHold}
				{
					EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipCargo]:MakeActive
					cycleCargoHold:Set[TRUE]
					return FALSE
				}
				else
				{
					Logger:Log["Client", "Ore hold information invalid, activating", "g"]
					EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipOreHold]:MakeActive
					cycleCargoHold:Set[TRUE]
					return FALSE
				}
			}
		}
		if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipFleetHangar](exists)}
		{
			if ${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipFleetHangar].UsedCapacity} == -1 || \
				${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipFleetHangar].Capacity} <= 0
			{
				Logger:Log["Client", "Fleet Hangar information invalid, activating", "g"]
				EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipFleetHangar]:MakeActive
				return FALSE
			}
		}

		return TRUE
	}
}