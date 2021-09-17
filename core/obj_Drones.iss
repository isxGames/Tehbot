objectdef obj_Configuration_DroneData
{
	variable string SetName = "Drone Data"

	variable filepath CONFIG_PATH = "${Script.CurrentDirectory}/data"
	variable string CONFIG_FILE = "DroneData.xml"
	variable settingsetref BaseRef

	method Initialize()
	{
		LavishSettings[DroneData]:Clear
		LavishSettings:AddSet[DroneData]

		if ${CONFIG_PATH.FileExists["${CONFIG_FILE}"]}
		{
			LavishSettings[DroneData]:Import["${CONFIG_PATH}/${CONFIG_FILE}"]
		}
		BaseRef:Set[${LavishSettings[DroneData].FindSet[DroneTypes]}]

		UI:Update["Configuration", " ${This.SetName}: Initialized", "-g"]
	}

	method Shutdown()
	{
		LavishSettings[DroneData]:Clear
	}

	member:string DroneType(int TypeID)
	{
		variable iterator DroneTypes
		BaseRef:GetSetIterator[DroneTypes]
		if ${DroneTypes:First(exists)}
		{
			do
			{
				if ${DroneTypes.Value.FindSetting[${TypeID}](exists)}
				{
					return ${DroneTypes.Key}
				}
			}
			while ${DroneTypes:Next(exists)}
		}
	}

	member:float GetVolume(string DroneType)
	{
		variable iterator DroneTypes
		variable iterator Drones
		BaseRef:GetSetIterator[DroneTypes]
		if ${DroneTypes:First(exists)}
		{
			do
			{
				DroneTypes.Value:GetSettingIterator[Drones]
				if ${Drones:First(exists)}
				{
					do
					{
						if ${Drones.Value.FindAttribute[Type].String.Equal[${DroneType}]}
						{
							return ${Drones.Value.FindAttribute[Volume].Float}
						}
					}
					while ${Drones:Next(exists)}
				}
			}
			while ${DroneTypes:Next(exists)}
		}
		return -1
	}

	member:string SearchSimilarDroneFromRace(string DroneType, int RaceID)
	{
		variable iterator DroneTypes
		variable iterator Drones
		variable settingsetref TargetDroneType
		BaseRef:GetSetIterator[DroneTypes]
		if ${DroneTypes:First(exists)}
		{
			do
			{
				DroneTypes.Value:GetSettingIterator[Drones]
				if ${Drones:First(exists)}
				{
					do
					{
						if ${Drones.Value.FindAttribute[Type].String.Equal[${DroneType}]}
						{
							TargetDroneType:Set[${DroneTypes.Value}]
							break
						}
					}
					while ${Drones:Next(exists)}

					if ${TargetDroneType}
					{
						break
					}
				}
			}
			while ${DroneTypes:Next(exists)}
		}

		variable string affix = ""
		variable bool isNavy = FALSE
		if ${DroneType.Find["'Integrated'"]}
		{
			affix:Set["'Integrated'"]
		}
		elseif ${DroneType.Find["'Augmented'"]}
		{
			affix:Set["'Augmented'"]
		}
		elseif ${DroneType.Find["Navy"]} || ${DroneType.Find["Fleet"]}
		{
			isNavy:Set[TRUE]
		}
		elseif ${DroneType.Find[" II"]}
		{
			affix:Set[" II"]
		}
		elseif ${DroneType.Find[" I"]}
		{
			affix:Set[" I"]
		}

		TargetDroneType:GetSettingIterator[Drones]
		do
		{
			if ${Drones.Value.FindAttribute[Race].Int} == ${RaceID} && \
			   ((!${affix.Equal[""]} && \
			     ${Drones.Value.FindAttribute[Type].String.Find[${affix}]}) || \
			    ((${isNavy} && \
			     (${Drones.Value.FindAttribute[Type].String.Find[Navy]} || \
			      ${Drones.Value.FindAttribute[Type].String.Find[Fleet]})))
			{
				return ${Drones.Value.FindAttribute[Type].String}
			}
		}
		while ${Drones:Next(exists)}

		return NULL
	}

	member:int FindType(string TypeName)
	{
		variable iterator DroneTypeIDs
		BaseRef.FindSet[${TypeName}]:GetSettingIterator[DroneTypeIDs]
		if ${DroneTypeIDs:First(exists)}
		{
			do
			{
				if ${Drones.InactiveDroneCount[TypeID = ${DroneTypeIDs.Key}]} > 0
				{
					return ${DroneTypeIDs.Key}
				}
			}
			while ${DroneTypeIDs:Next(exists)}
		}
		return -1
	}
}


objectdef obj_Drones inherits obj_StateQueue
{
	variable obj_Configuration_DroneData Data
	variable set ActiveTypes
	variable collection:queue TypeQueues

	method Initialize()
	{
		This[parent]:Initialize
		PulseFrequency:Set[250]
	}

	method RecallAll()
	{
		UI:Update["obj_Drone", "Recalling Drones", "g"]
		EVE:Execute[CmdDronesReturnToBay]
		DronesOut:Set[FALSE]
	}

	method RefreshActiveTypes()
	{
		ActiveTypes:Clear
		variable index:activedrone ActiveDrones
		Me:GetActiveDrones[ActiveDrones]
		ActiveDrones:GetIterator[DroneIterator]
		if ${DroneIterator:First(exists)}
		{
			do
			{
				ActiveTypes:Add[${DroneIterator.Value.TypeID}]
			}
			while ${DroneIterator:Next(exists)}
		}
	}

	method Deploy(string TypeQuery, int Count=-1)
	{
		variable index:item DroneBayDrones
		variable index:int64 DronesToLaunch
		variable iterator DroneIterator
		variable int Selected = 0


		MyShip:GetDrones[DroneBayDrones]
		DroneBayDrones:RemoveByQuery[${LavishScript.CreateQuery[${TypeQuery}]}, FALSE]
		DroneBayDrones:Collapse[]
		DroneBayDrones:GetIterator[DroneIterator]
		if ${DroneIterator:First(exists)}
		{
			do
			{
				if ${Selected} >= ${Count} && ${Count} > 0
				{
					break
				}
				ActiveTypes:Add[${DroneIterator.Value.TypeID}]
				DronesToLaunch:Insert[${DroneIterator.Value.ID}]
				Selected:Inc
			}
			while ${DroneIterator:Next(exists)}
		}
		EVE:LaunchDrones[DronesToLaunch]
	}

	method Recall(string TypeQuery, int Count=-1)
	{
		variable index:activedrone ActiveDrones
		variable index:int64 DronesToRecall
		variable iterator DroneIterator
		variable int Selected = 0
		Me:GetActiveDrones[ActiveDrones]
		ActiveDrones:RemoveByQuery[${LavishScript.CreateQuery[${TypeQuery}]}, FALSE]
		ActiveDrones:Collapse[]
		ActiveDrones:GetIterator[DroneIterator]
		if ${DroneIterator:First(exists)}
		{
			do
			{
				if ${Selected} >= ${Count} && ${Count} > 0
				{
					break
				}
				DronesToRecall:Insert[${DroneIterator.Value.ID}]
				Selected:Inc
			}
			while ${DroneIterator:Next(exists)}
		}
		EVE:DronesReturnToDroneBay[DronesToRecall]
	}

	member:int GetTargeting(int64 TargetID)
	{
		variable index:activedrone ActiveDrones
		variable iterator DroneIterator
		variable int Targeting = 0
		Me:GetActiveDrones[ActiveDrones]
		ActiveDrones:GetIterator[DroneIterator]
		if ${DroneIterator:First(exists)}
		{
			do
			{
				if ${DroneIterator.Value.Target.ID.Equal[${TargetID}]}
				{
					Targeting:Inc
				}
			}
			while ${DroneIterator:Next(exists)}
		}
		return ${Targeting}
	}

	method Engage(string TypeQuery, int64 TargetID, bool Force=FALSE, int Count = -1)
	{
		if ${Entity[${TargetID}].IsLockedTarget}
		{
			This:QueueState["SwitchTarget", -1, ${TargetID}]
			This:QueueState["EngageTarget", -1, "${TypeQuery.Escape}, ${TargetID}, ${Force}, ${Count}"]
		}
	}

	member:int InactiveDroneCount(string TypeQuery)
	{
		variable index:item DroneBayDrones
		MyShip:GetDrones[DroneBayDrones]
		DroneBayDrones:RemoveByQuery[${LavishScript.CreateQuery[${TypeQuery}]}, FALSE]
		DroneBayDrones:Collapse[]
		return ${DroneBayDrones.Used}
	}

	member:int ActiveDroneCount(string TypeQuery)
	{
		variable index:activedrone ActiveDrones
		Me:GetActiveDrones[ActiveDrones]
		ActiveDrones:RemoveByQuery[${LavishScript.CreateQuery[${TypeQuery}]}, FALSE]
		ActiveDrones:Collapse[]
		return ${ActiveDrones.Used}
	}

	member:bool IdleDrone()
	{
		variable index:activedrone ActiveDrones
		Me:GetActiveDrones[ActiveDrones]
		ActiveDrones:RemoveByQuery[${LavishScript.CreateQuery["State == 0"]}, FALSE]
		ActiveDrones:Collapse[]
		return ${ActiveDrones.Used}
	}

	member:bool SwitchTarget(int64 TargetID)
	{
		if ${Entity[${TargetID}].IsLockedTarget}
		{
			Entity[${TargetID}]:MakeActiveTarget
		}
		return TRUE
	}

	member:bool EngageTarget(string TypeQuery, int64 TargetID, bool Force, int Count = -1)
	{
		if ${Entity[${TargetID}].IsLockedTarget} && ${Entity[${TargetID}].IsActiveTarget}
		{
			variable index:activedrone ActiveDrones
			variable index:int64 DronesToEngage
			variable iterator DroneIterator
			variable int Selected = 0
			Me:GetActiveDrones[ActiveDrones]
			ActiveDrones:RemoveByQuery[${LavishScript.CreateQuery[${TypeQuery}]}, FALSE]
			ActiveDrones:Collapse[]
			ActiveDrones:GetIterator[DroneIterator]

			Count:Dec[${This.GetTargetting[${TargetID}]}]

			if ${DroneIterator:First(exists)}
			{
				do
				{
					if ${Selected} >= ${Count} && ${Count} > 0
					{
						break
					}
					if ${DroneIterator.Value.State} == 0 || ${Force}
					{
						DronesToEngage:Insert[${DroneIterator.Value.ID}]
					}
					Selected:Inc
				}
				while ${DroneIterator:Next(exists)}
			}
			EVE:DronesEngageMyTarget[DronesToEngage]
		}
		return TRUE
	}

	member:int DronesInSpace()
	{
		variable index:activedrone ActiveDrones
		Me:GetActiveDrones[ActiveDrones]
		return ${ActiveDrones.Used}
	}

	member:int DronesInBay()
	{
		variable index:item Drones
		MyShip:GetDrones[Drones]
		return ${Drones.Used}
	}



}