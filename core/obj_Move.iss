objectdef obj_Move inherits obj_StateQueue
{
	variable obj_Approach ApproachModule

	variable bool Traveling=FALSE


	method Initialize()
	{
		This[parent]:Initialize
	}


	method Warp(int64 ID, int Dist=0, bool FleetWarp=FALSE)
	{
		if ${Me.Fleet.IsMember[${Me.CharID}]}
		{
			if (${Me.ToFleetMember.IsFleetCommander} || \
				${Me.ToFleetMember.IsWingCommander} || \
				${Me.ToFleetMember.IsSquadCommander}) && \
				${FleetWarp}
			{
				Entity[${ID}]:WarpFleetTo[${Dist}]
			}
			else
			{
				Entity[${ID}]:WarpTo[${Dist}]
			}
		}
		else
		{
			Entity[${ID}]:WarpTo[${Dist}]
		}
		Client:Wait[5000]
	}

	method ActivateAutoPilot()
	{
		if !${Me.AutoPilotOn}
		{
			UI:Update["Move", "Activating autopilot", "o"]
			EVE:Execute[CmdToggleAutopilot]
		}
	}

	method TravelToSystem(int64 DestinationSystemID)
	{
		if ${Me.ToEntity.Mode} == 3 || ${DestinationSystemID.Equal[${Me.SolarSystemID}]} || ${Me.AutoPilotOn}
		{
			return
		}

		variable index:int DestinationList
		EVE:GetWaypoints[DestinationList]

		if ${DestinationList[${DestinationList.Used}]} != ${DestinationSystemID}
		{
			UI:Update["Move", "Setting destination", "o"]
			UI:Update["Move", " ${Universe[${DestinationSystemID}].Name}", "-g"]
			Universe[${DestinationSystemID}]:SetDestination
			return
		}

		This:ActivateAutoPilot
	}

	method TravelToStation(int64 StationID)
	{
		if ${Me.ToEntity.Mode} == 3 || ${Me.AutoPilotOn}
		{
			return
		}

		variable index:int DestinationList
		EVE:GetWaypoints[DestinationList]

		if ${EVE.Station[${StationID}].SolarSystem.ID} == ${Me.SolarSystemID}
		{
			This:DockAtStation[${StationID}]
			return
		}

		if ${DestinationList[${DestinationList.Used}]} != ${EVE.Station[${StationID}].SolarSystem.ID}
		{
			UI:Update["Move", "Setting destination", "o"]
			UI:Update["Move", " ${EVE.Station[${StationID}].Name}", "-g"]
			Universe[${EVE.Station[${StationID}].SolarSystem.ID}]:SetDestination
			return
		}

		This:ActivateAutoPilot
	}

	method Undock()
	{
		EVE:Execute[CmdExitStation]
		Client:Wait[10000]
	}

	method DockAtStation(int64 StationID)
	{
		if ${Entity[${StationID}](exists)}
		{
			UI:Update["Move", "Docking", "o"]
			UI:Update["Move", " ${Entity[${StationID}].Name}", "-g"]
			Entity[${StationID}]:Dock
			Client:Wait[10000]
		}
		else
		{
			UI:Update["Move", "Station Requested does not exist", "r"]
			UI:Update["Move", "StationID: ${StationID}", "r"]
		}
	}



	method Fleetmember(int64 ID, bool IgnoreGate=FALSE, int Distance=0)
	{
		if ${This.Traveling}
		{
			return
		}

		if !${Me.Fleet.Member[${ID}](exists)}
		{
			UI:Update["Move", "Fleet member does not exist", "r"]
			UI:Update["Move", "Fleet member CharID: ${ID}", "r"]
			return
		}

		UI:Update["Move", "Movement queued", "o"]
		UI:Update["Move", " ${Being[${ID}].Name}", "-g"]
		This.Traveling:Set[TRUE]
		This:QueueState["FleetmemberMove", 2000, "${ID}, ${IgnoreGate}, ${Distance}"]
	}

	method Bookmark(string DestinationBookmarkLabel, bool IgnoreGate=FALSE, int Distance=0, bool FleetWarp=FALSE)
	{
		if ${This.Traveling}
		{
			return
		}

		if !${EVE.Bookmark[${DestinationBookmarkLabel}](exists)} && !${EVE.Station[${DestinationBookmarkLabel}](exists)}
		{
			UI:Update["Move", "Attempted to travel to a bookmark which does not exist", "r"]
			UI:Update["Move", "Bookmark label: ${DestinationBookmarkLabel}", "r"]
			return
		}

		if ${EVE.Bookmark[${DestinationBookmarkLabel}](exists)}
		{
			UI:Update["Move", "Movement queued", "o"]
			UI:Update["Move", " ${DestinationBookmarkLabel}", "-g"]
		}
		if ${EVE.Station[${DestinationBookmarkLabel}](exists)}
		{
			UI:Update["Move", "Movement queued", "o"]
			UI:Update["Move", " ${EVE.Station[${DestinationBookmarkLabel}].Name}", "-g"]
		}
		This.Traveling:Set[TRUE]
		This:QueueState["BookmarkMove", 2000, "${DestinationBookmarkLabel}, ${IgnoreGate}, ${Distance}, ${FleetWarp}"]
	}

	method AgentBookmark(int64 destinationID)
	{
		if ${This.Traveling}
		{
			return
		}
		variable index:agentmission Missions
		variable iterator m

		EVE:GetAgentMissions[Missions]
		Missions:GetIterator[m]
		if ${m:First(exists)}
			do
			{
				variable index:bookmark missionBookmarks
				variable iterator b
				m.Value:GetBookmarks[missionBookmarks]
				missionBookmarks:GetIterator[b]
				if ${b:First(exists)}
					do
					{
						if ${b.Value.ID} == ${destinationID}
						{
							if ${b.Value.LocationType.Equal[dungeon]}
							{
								if ${Client.InSpace} && (${Entity[Type = "Beacon"]} || ${Entity[Type = "Acceleration Gate"]})
								{
									UI:Update["Move", "Appear to already be in a dungeon", "o"]
									return
								}
							}
							UI:Update["Move", "Movement queued", "o"]
							UI:Update["Move", " ${b.Value.Label}", "-g"]
						}
					}
					while ${b:Next(exists)}
			}
			while ${m:Next(exists)}
		else
		{
			UI:Update["Move", "Attempted to travel to an agent bookmark which does not exist", "r"]
			UI:Update["Move", "Bookmark ID: ${destinationID}", "r"]
			return
		}


		This.Traveling:Set[TRUE]
		This:QueueState["AgentBookmarkMove", 2000, "${destinationID}"]
	}

	method System(string SystemID)
	{
		if ${This.Traveling}
		{
			return
		}

		if !${Universe[${SystemID}](exists)}
		{
			UI:Update["Move", "Attempted to travel to a system which does not exist", "r"]
			UI:Update["Move", "System ID: ${SystemID}", "r"]
			return
		}

		UI:Update["Move", "Movement queued", "o"]
		UI:Update["Move", " ${Universe[${SystemID}].Name}", "-g"]
		This.Traveling:Set[TRUE]
		This:QueueState["SystemMove", 2000, ${SystemID}]
	}

	method Object(int64 ID, int Distance=0, bool FleetWarp=FALSE)
	{
		if ${This.Traveling}
		{
			return
		}

		UI:Update["Move", "Movement queued", "o"]
		UI:Update["Move", " ${Entity[${ID}].Name}", "-g"]
		This.Traveling:Set[TRUE]
		This:QueueState["ObjectMove", 2000, "${ID},${Distance},${FleetWarp}"]
	}

	method Agent(string AgentName)
	{
		if ${This.Traveling}
		{
			return
		}

		if !${EVE.Agent[${AgentName}](exists)}
		{
			UI:Update["Move", "Attempted to travel to an agent which does not exist", "r"]
			UI:Update["Move", "Agent name: ${AgentName}", "r"]
			return
		}

		UI:Update["Move", "Movement queued", "o"]
		UI:Update["Move", " ${AgentName}", "-g"]
		This.Traveling:Set[TRUE]
		This:InsertState["AgentMove", 2000, ${EVE.Agent[AgentName].Index}]
	}

	method Agent(int AgentIndex)
	{
		if ${This.Traveling}
		{
			return
		}

		if !${EVE.Agent[${AgentIndex}](exists)}
		{
			UI:Update["Move", "Attempted to travel to an agent which does not exist", "r"]
			UI:Update["Move", "Agent index: ${AgentIndex}", "r"]
			return
		}

		UI:Update["Move", "Movement queued", "o"]
		UI:Update["Move", " ${EVE.Agent[${AgentIndex}].Name}", "-g"]
		This.Traveling:Set[TRUE]
		This:InsertState["AgentMove", 2000, ${AgentIndex}]
	}

	method Gate(int64 ID, bool CalledFromMove=FALSE)
	{
		UI:Update["Move", "Movement queued", "o"]
		UI:Update["Move", " ${Entity[${ID}].Name}", "-g"]
		This.Traveling:Set[TRUE]
		This:QueueState["GateMove", 2000, "${ID}, ${CalledFromMove}"]
	}

	member:bool GateMove(int64 ID, bool CalledFromMove)
	{
		if !${Entity[${ID}](exists)} || ${EVEWindow[byName, modal].Text.Find[This gate is locked!]}
		{
			if !${CalledFromMove}
			{
				This.Traveling:Set[FALSE]
			}
			return TRUE
		}

		if ${Me.ToEntity.Mode} == 3
		{
			return FALSE
		}

		if ${Entity[${ID}].Distance} < -8000
		{
			UI:Update["Move", "Too close!  Orbiting ${Entity[${ID}].Name}", "g"]
			Entity[${ID}]:Orbit
			Client:Wait[10000]
			return FALSE
		}
		if ${Entity[${ID}].Distance} > 3000
		{
			This:Approach[${ID}, 3000]
			return FALSE
		}
		UI:Update["Move", "Activating ${Entity[${ID}].Name}", "g"]
		Entity[${ID}]:Activate
		Client:Wait[5000]
		if !${CalledFromMove}
		{
			This.Traveling:Set[FALSE]
		}
		return FALSE
	}

	member:bool FleetmemberMove(int64 ID, bool IgnoreGate=FALSE, int Distance=0)
	{
		if !${Me.Fleet.Member[${ID}].ToPilot(exists)}
		{
			UI:Update["Move", "Fleet member ${Being[${ID}].Name} is no longer in local, canceling Move", "g"]
			This.Traveling:Set[FALSE]
			return TRUE
		}

		if ${Me.InStation}
		{
			UI:Update["Move", "Undocking", "o"]
			UI:Update["Move", " ${Me.Station.Name}", "-g"]
			This:Undock
			return FALSE
		}

		if !${Client.InSpace}
		{
			return FALSE
		}

		if ${Me.ToEntity.Mode} == 3
		{
			return FALSE
		}

		if ${Me.Fleet.Member[${ID}].ToEntity(exists)}
		{
			if ${Me.Fleet.Member[${ID}].ToEntity.Distance} > 100000
			{

				UI:Update["Move", "Bounce warping", "o"]
				UI:Update["Move", " ${Entity[ID >= 40000000 && ID <= 50000000].Name}", "-g"]
				Entity[ID >= 40000000 && ID <= 50000000]:WarpTo
				Client:Wait[5000]
				return FALSE
			}
			else
			{
				UI:Update["Move", "Reached \ao${Me.Fleet.Member[${ID}].ToPilot.Name}", "g"]
				This.Traveling:Set[FALSE]
				return TRUE
			}
		}
		else
		{
				if ${Entity["GroupID = GROUP_WARPGATE"](exists)} && !${IgnoreGate}
				{
					UI:Update["Move", "Gate found, activating", "g"]
					This:Gate[${Entity["GroupID = GROUP_WARPGATE"].ID}, TRUE]
					This:QueueState["FleetmemberMove", 2000, ${ID}]
					return TRUE
				}
				UI:Update["Move", "Warping", "o"]
				UI:Update["Move", " ${Me.Fleet.Member[${ID}].ToPilot.Name}", "-g"]
				Me.Fleet.Member[${ID}]:WarpTo[${Distance}]
				Client:Wait[5000]
				This:QueueState["FleetmemberMove", 2000, "${ID}, FALSE, ${Distance}"]

				return TRUE
		}
	}

	member:bool BookmarkMove(string Bookmark, bool IgnoreGate=FALSE, int Distance=0, bool FleetWarp=FALSE)
	{

		if ${Me.InStation}
		{
			if ${EVE.Bookmark[${Bookmark}](exists)}
			{
				if ${Me.StationID} == ${EVE.Bookmark[${Bookmark}].ItemID}
				{
					UI:Update["Move", "Docked", "o"]
					UI:Update["Move", " ${Bookmark}", "-g"]
					This.Traveling:Set[FALSE]
					return TRUE
				}
				else
				{
					UI:Update["Move", "Undocking", "o"]
					UI:Update["Move", " ${Me.Station.Name}", "-g"]
					This:Undock
					return FALSE
				}
			}
			if ${EVE.Station[${Bookmark}](exists)}
			{
				if ${Me.StationID} == ${Bookmark}
				{
					UI:Update["Move", "Docked", "o"]
					UI:Update["Move", " ${EVE.Station[${Bookmark}].Name}", "-g"]
					This.Traveling:Set[FALSE]
					return TRUE
				}
				else
				{
					UI:Update["Move", "Undocking", "o"]
					UI:Update["Move", " ${Me.Station.Name}", "-g"]
					This:Undock
					return FALSE
				}
			}
		}

		if !${Client.InSpace}
		{
			return FALSE
		}

		if ${Me.ToEntity.Mode} == 3
		{
			return FALSE
		}

		if ${EVE.Bookmark[${Bookmark}](exists)}
		{
			if ${EVE.Bookmark[${Bookmark}].SolarSystemID} != ${Me.SolarSystemID}
			{
				This:TravelToSystem[${EVE.Bookmark[${Bookmark}].SolarSystemID}]
				return FALSE
			}
		}
		if ${EVE.Station[${Bookmark}](exists)}
		{
			This:TravelToStation[${Bookmark}]
		}

		if ${EVE.Bookmark[${Bookmark}].ItemID} == -1
		{
			if ${EVE.Bookmark[${Bookmark}].Distance} > 150000
			{
				if ${Entity["GroupID = GROUP_WARPGATE"](exists)} && !${IgnoreGate}
				{
					UI:Update["Move", "Gate found, activating", "g"]
					This:Gate[${Entity["GroupID = GROUP_WARPGATE"].ID}, TRUE]
					This:QueueState["BookmarkMove", 2000, ${Bookmark}]
					return TRUE
				}

				UI:Update["Move", "Warping", "o"]
				UI:Update["Move", " ${Bookmark}", "-g"]
				if ${Me.Fleet.IsMember[${Me.CharID}]}
				{
					if (${Me.ToFleetMember.IsFleetCommander} || \
						${Me.ToFleetMember.IsWingCommander} || \
						${Me.ToFleetMember.IsSquadCommander}) && \
						${FleetWarp}
					{
						EVE.Bookmark[${Bookmark}]:WarpFleetTo[${Distance}]
					}
					else
					{
						EVE.Bookmark[${Bookmark}]:WarpTo[${Distance}]
					}
				}
				else
				{
					EVE.Bookmark[${Bookmark}]:WarpTo[${Distance}]
				}
				Client:Wait[5000]
				This:QueueState["BookmarkMove", 2000, ${Bookmark}]
				return TRUE
			}
			elseif ${EVE.Bookmark[${Bookmark}].Distance} != -1 && ${EVE.Bookmark[${Bookmark}].Distance(exists)}
			{
				UI:Update["Move", "Reached", "o"]
				UI:Update["Move", " ${Bookmark}", "-g"]
				This.Traveling:Set[FALSE]
				return TRUE
			}
			else
			{
				return FALSE
			}
		}
		else
		{
			if ${EVE.Bookmark[${Bookmark}].ToEntity(exists)}
			{
				if ${EVE.Bookmark[${Bookmark}].ToEntity.Distance} > 150000
				{
					UI:Update["Move", "Warping", "o"]
					UI:Update["Move", " ${Bookmark}", "-g"]
					if ${Me.Fleet.IsMember[${Me.CharID}]}
					{
						if (${Me.ToFleetMember.IsFleetCommander} || \
							${Me.ToFleetMember.IsWingCommander} || \
							${Me.ToFleetMember.IsSquadCommander}) && \
							${FleetWarp}
						{
							EVE.Bookmark[${Bookmark}].ToEntity:WarpFleetTo[${Distance}]
						}
						else
						{
							EVE.Bookmark[${Bookmark}].ToEntity:WarpTo[${Distance}]
						}
					}
					else
					{
						EVE.Bookmark[${Bookmark}].ToEntity:WarpTo[${Distance}]
					}
					return FALSE
				}
				elseif ${EVE.Bookmark[${Bookmark}].ToEntity.Distance} != -1 && ${EVE.Bookmark[${Bookmark}].ToEntity.Distance(exists)}
				{
					UI:Update["Move", "Docking", "o"]
					UI:Update["Move", " ${Bookmark}", "-g"]
					This:DockAtStation[${EVE.Bookmark[${Bookmark}].ItemID}]
					return FALSE
				}
				else
				{
					return FALSE
				}
			}
			else
			{
				if ${EVE.Bookmark[${Bookmark}].Distance} > 150000
				{
					UI:Update["Move", "Warping", "o"]
					UI:Update["Move", " ${Bookmark}", "-g"]
					if ${Me.Fleet.IsMember[${Me.CharID}]}
					{
						if (${Me.ToFleetMember.IsFleetCommander} || \
							${Me.ToFleetMember.IsWingCommander} || \
							${Me.ToFleetMember.IsSquadCommander}) && \
							${FleetWarp}
						{
							EVE.Bookmark[${Bookmark}]:WarpFleetTo[${Distance}]
						}
						else
						{
							EVE.Bookmark[${Bookmark}]:WarpTo[${Distance}]
						}
					}
					else
					{
						EVE.Bookmark[${Bookmark}]:WarpTo[${Distance}]
					}
					Client:Wait[5000]
					return FALSE
				}
				elseif ${EVE.Bookmark[${Bookmark}].Distance} != -1 && ${EVE.Bookmark[${Bookmark}].Distance(exists)}
				{
					UI:Update["Move", "Reached", "o"]
					UI:Update["Move", " ${Bookmark}", "-g"]
					This.Traveling:Set[FALSE]
					return TRUE
				}
				else
				{
					return FALSE
				}
			}
		}
	}

	member:bool AgentBookmarkMove(int64 destinationID)
	{
		variable index:agentmission Missions
		variable iterator m

		EVE:GetAgentMissions[Missions]
		Missions:GetIterator[m]
		if ${m:First(exists)}
			do
			{
			variable index:bookmark missionBookmarks
			variable iterator b
			m.Value:GetBookmarks[missionBookmarks]
			missionBookmarks:GetIterator[b]
			if ${b:First(exists)}
				do
				{
					if ${b.Value.ID} == ${destinationID}
					{
						if ${Me.InStation}
						{
							if ${Me.StationID} == ${b.Value.ItemID}
							{
								UI:Update["Move", "Docked", "o"]
								UI:Update["Move", " ${Me.Station.Name]}", "-g"]
								This.Traveling:Set[FALSE]
								return TRUE
							}
							else
							{
								UI:Update["Move", "Undocking", "o"]
								UI:Update["Move", " ${Me.Station.Name}", "-g"]
								This:Undock
								return FALSE
							}
						}
						if !${Client.InSpace} || ${Me.ToEntity.Mode} == 3
							return FALSE
						if ${b.Value.SolarSystemID} != ${Me.SolarSystemID}
						{
							This:TravelToSystem[${b.Value.SolarSystemID}]
							return FALSE
						}
						if ${b.Value.ItemID} == -1
						{
							if ${b.Value.Distance} > 150000
							{
								UI:Update["Move", "Warping", "o"]
								UI:Update["Move", " ${b.Value.Label}", "-g"]

								b.Value:WarpTo[0]
								Client:Wait[5000]
								This:QueueState["AgentBookmarkMove", 2000, ${destinationID}]
								return TRUE
							}
							elseif ${b.Value.Distance} != -1 && ${b.Value.Distance(exists)}
							{
								UI:Update["Move", "Reached", "o"]
								UI:Update["Move", " ${b.Value.Label}", "-g"]
								This.Traveling:Set[FALSE]
								return TRUE
							}
							else
							{
								return FALSE
							}
						}
						else
						{
							if ${b.Value.ToEntity(exists)}
							{
								if ${b.Value.ToEntity.Distance} > 150000
								{
									UI:Update["Move", "Warping", "o"]
									UI:Update["Move", " ${b.Value.Label}", "-g"]

									b.Value.ToEntity:WarpTo[0]
									return FALSE
								}
								elseif ${b.Value.ToEntity.Distance} != -1 && ${b.Value.ToEntity.Distance(exists)}
								{
									UI:Update["Move", "Docking", "o"]
									UI:Update["Move", " ${b.Value.Label}", "-g"]
									This:DockAtStation[${b.Value.ItemID}]
									return FALSE
								}
								else
								{
									return FALSE
								}
							}
							else
							{
								if ${b.Value.LocationType.Equal[dungeon]}
								{
									if ${Client.InSpace} && (${Entity[Type = "Beacon"]} || ${Entity[Type = "Acceleration Gate"]})
									{
										UI:Update["Move", "Appear to already be in a dungeon", "o"]
										This.Traveling:Set[FALSE]
										return TRUE
									}
								}
								if ${b.Value.Distance} > 150000
								{
									UI:Update["Move", "Warping", "o"]
									UI:Update["Move", " ${b.Value.Label}", "-g"]

									b.Value:WarpTo[0]
									Client:Wait[5000]
									return FALSE
								}
								elseif ${b.Value.Distance} != -1 && ${b.Value.Distance(exists)}
								{
									UI:Update["Move", "Reached", "o"]
									UI:Update["Move", " ${b.Value.Label}", "-g"]
									This.Traveling:Set[FALSE]
									return TRUE
								}
								else
								{
									return FALSE
								}
							}
						}
					}
				}
				while ${b:Next(exists)}
			}
			while ${m:Next(exists)}
	}

	member:bool AgentMove(int ID)
	{
		if ${Me.InStation}
		{
			if ${Me.StationID} == ${EVE.Agent[${ID}].StationID}
			{
				UI:Update["Move", "Docked", "o"]
				UI:Update["Move", " ${Agent[${ID}].Station}", "-g"]
				This.Traveling:Set[FALSE]
				return TRUE
			}
			else
			{
				UI:Update["Move", "Undocking", "o"]
				UI:Update["Move", " ${Me.Station.Name}", "-g"]
				This:Undock
				return FALSE
			}
		}

		if ${Me.ToEntity.Mode} == 3 || !${Client.InSpace}
		{
			return FALSE
		}

		if ${EVE.Agent[${ID}].Solarsystem.ID} != ${Me.SolarSystemID}
		{
			This:TravelToSystem[${EVE.Agent[${ID}].Solarsystem.ID}]
			return FALSE
		}

		if ${Entity[${EVE.Agent[${ID}].StationID}](exists)}
		{
			if ${Entity[${EVE.Agent[${ID}].StationID}].Distance} > 150000
			{
				UI:Update["Move", "Warping", "o"]
				UI:Update["Move", " ${EVE.Agent[${ID}].Station}", "-g"]
				This:Warp[${EVE.Agent[${ID}].StationID}]
				return FALSE
			}
			else
			{
				UI:Update["Move", "Docking", "o"]
				UI:Update["Move", " ${EVE.Agent[${ID}].Station}", "-g"]
				This:DockAtStation[${EVE.Agent[${ID}].StationID}]
				This.Traveling:Set[FALSE]
				return TRUE
			}
		}
	}

	member:bool SystemMove(int64 ID)
	{

		if ${Me.InStation}
		{
			if ${Me.SolarSystemID} == ${ID}
			{
				UI:Update["Move", "Reached ${Universe[${ID}].Name}", "g"]
				This.Traveling:Set[FALSE]
				return TRUE
			}
			else
			{
				UI:Update["Move", "Undocking", "o"]
				UI:Update["Move", " ${Me.Station.Name}", "-g"]
				This:Undock
				return FALSE
			}
		}

		if !${Client.InSpace}
		{
			return FALSE
		}

		if ${Me.ToEntity.Mode} == 3
		{
			return FALSE
		}

		if ${ID} != ${Me.SolarSystemID}
		{
			This:TravelToSystem[${ID}]
			return FALSE
		}
		This.Traveling:Set[FALSE]
		return TRUE
	}

	member:bool ObjectMove(int64 ID, int Distance=0, bool FleetWarp=FALSE)
	{

		if ${Me.InStation}
		{
			echo ObjectMove in station
			if ${Me.StationID} == ${ID}
			{
				echo Returned out of ObjectMove
				return TRUE
			}
			UI:Update["Move", "Undocking", "o"]
			UI:Update["Move", " ${Me.Station.Name}", "-g"]
			This:Undock
			return FALSE
		}

		if !${Client.InSpace}
		{
			return FALSE
		}

		if ${Me.ToEntity.Mode} == 3
		{
			return FALSE
		}

		if !${Entity[${ID}](exists)}
		{
			UI:Update["Move", "Attempted to warp to object ${ID} which does not exist", "r"]
		}

		if ${Entity[${ID}].Distance} > 150000
		{
			Entity[${ID}]:AlignTo
			This:Warp[${ID}, ${Distance}, ${FleetWarp}]
			return FALSE
		}
		elseif ${Entity[${ID}].GroupID} == 1404 || ${Entity[${ID}].GroupID} == 1406 || ${Entity[${ID}].GroupID} == 1657
		{
			This:DockAtStation[${ID}]
			return FALSE
		}

		This.Traveling:Set[FALSE]
		return TRUE
	}



	method Approach(int64 ID, int distance=0)
	{
		;	If we're already approaching the target, ignore the request
		if !${ApproachModule.IsIdle}
		{
			return
		}
		if !${Entity[${ID}](exists)}
		{
			UI:Update["Move", "Attempted to approach a target that does not exist", "r"]
			UI:Update["Move", "Target ID: ${ID}", "r"]
			return
		}
		if ${Entity[${ID}].Distance} <= ${distance}
		{
			return
		}

		ApproachModule:QueueState["CheckApproach", 1000, "${ID}, ${distance}"]
	}

	variable int64 orbitTarget = 0
	method Orbit(int64 ID, int distance=0)
	{
		if ${Me.ToEntity.Mode} == 3 || !${Entity[${ID}](exists)}
			return

		;	Find out if we need to approach the target
		if ${Me.ToEntity.Mode} != 4 || ${orbitTarget} != ${ID}
		{
			UI:Update["Move", "Orbiting ${Entity[${ID}].Name} at ${ComBot.MetersToKM_Str[${distance}]}", "g"]
			Entity[${ID}]:Orbit[${distance}]
			orbitTarget:Set[${ID}]
			return
		}
	}

	method SaveSpot()
	{
		UI:Update["Move", "Storing current location", "y"]
		This.SavedSpot:Set["Saved Spot ${EVETime.Time.Left[-3]}"]
		EVE:CreateBookmark["${This.SavedSpot}","","",1]
	}

	member:bool SavedSpotExists()
	{
		if ${This.SavedSpot.Length} > 0
		{
			return ${EVE.Bookmark["${This.SavedSpot}"](exists)}
		}
		return FALSE
	}

	method RemoveSavedSpot()
	{
		if ${This.SavedSpotExists}
		{
			EVE.Bookmark["${This.SavedSpot}"]:Remove
			SavedSpot:Set[""]
		}
	}

	method GotoSavedSpot()
	{
		if ${This.SavedSpotExists}
		{
			This:Bookmark["${This.SavedSpot}"]
		}
	}

}

objectdef obj_Approach inherits obj_StateQueue
{

	method Initialize()
	{
		This[parent]:Initialize
		This.PulseFrequency:Set[3000]
		This.NonGameTiedPulse:Set[TRUE]
	}


	member:bool CheckApproach(int64 ID, int distance)
	{
		;	Clear approach if we're in warp or the entity no longer exists
		if ${Me.ToEntity.Mode} == 3 || !${Entity[${ID}](exists)}
		{
			return TRUE
		}

		;	Find out if we need to approach the target
		if ${Entity[${ID}].Distance} > ${distance} && ${Me.ToEntity.Mode} != 1
		{
			UI:Update["Move", "Approaching to within ${ComBot.MetersToKM_Str[${distance}]} of ${Entity[${ID}].Name}", "g"]
			Entity[${ID}]:Approach[${distance}]
			return FALSE
		}

		;	If we're approaching a target, find out if we need to stop doing so
		if ${Entity[${ID}].Distance} <= ${distance} && ${Me.ToEntity.Mode} == 1
		{
			UI:Update["Move", "Within ${ComBot.MetersToKM_Str[${distance}]} of ${Entity[${ID}].Name}", "g"]
			EVE:Execute[CmdStopShip]
			Ship.ModuleList_AB_MWD:DeactivateAll
			return TRUE
		}

		return FALSE
	}
}
