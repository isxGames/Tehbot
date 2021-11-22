#include core/Defines.iss
#include core/Macros.iss

; Keep and updated
#include core/obj_Tehbot.iss
; Keep and updated
#include core/obj_Configuration.iss
; Updated, possibly still need to remove independent pulse if it's not used
#include core/obj_StateQueue.iss
; Keep and updated
#include core/obj_TehbotUI.iss
#include core/obj_Logger.iss
; Need to implement menu/config item for accepting fleet invites from corp members
; Update undock warp bookmark search to use aligned once it's moved to production out of dev version
; Probably need to restore undock minimode check, think undocks always happen right now
; Probably get rid of the Inventory member
#include core/obj_Client.iss
; Probably can be further cleaned up.  Remove unneeded move types, remove fleet warps, remove ignore gate stuff
; Probably need to rethink Approach and Orbit behaviors.  Make both separate modules, or let behaviors manage them on their own?
#include core/obj_Move.iss
; clear
#include core/obj_ModuleBase.iss
; clear
#include core/obj_Module.iss
; clear
#include core/obj_ModuleList.iss
; May work, need to verify querys work with strings instead of IDs
#include core/obj_Ship.iss
; Might remove altogether
#include core/obj_Cargo.iss
; May need more work, quickly removed IPC and profiling
#include core/obj_TargetList.iss
; clear
#include core/obj_Drones.iss
; clear
#include core/obj_Login.iss
; clear
#include core/obj_Dynamic.iss
; want to try and remove
;#include core/obj_Busy.iss

; clear
#include core/obj_NPCData.iss
#include core/obj_PrioritizedTargets.iss
#include core/obj_Utility.iss

#include behavior/MiniMode.iss
#include behavior/Salvager.iss
#include behavior/Mission.iss

#include minimode/Automate.iss
#include minimode/AutoModule.iss
#include minimode/AutoThrust.iss
#include minimode/DroneControl.iss
#include minimode/InstaWarp.iss
#include minimode/FightOrFlight.iss
#include minimode/Salvage.iss
#include minimode/UndockWarp.iss

function atexit()
{

}

function main(string Character="")
{
	declarevariable EVEExtension obj_EVEExtension script
	EVEExtension.Character:Set[${Character}]
	call EVEExtension.Initialize

	echo "${Time} Tehbot: Starting"

	declarevariable UI obj_TehbotUI script
	declarevariable Logger obj_Logger script
	declarevariable Tehbot obj_Tehbot script
	declarevariable BaseConfig obj_Configuration_BaseConfig script
	declarevariable Config obj_Configuration script
	UI:Reload

	declarevariable NPCData obj_NPCData script
	declarevariable PrioritizedTargets obj_PrioritizedTargets script
	declarevariable Utility obj_Utility script
	declarevariable TehbotLogin obj_Login script
	declarevariable Dynamic obj_Dynamic script

	declarevariable MiniMode obj_MiniMode script
	declarevariable Salvager obj_Salvager script
	declarevariable Mission obj_Mission script

	declarevariable Automate obj_Automate script
	declarevariable AutoModule obj_AutoModule script
	declarevariable AutoThrust obj_AutoThrust script
	declarevariable InstaWarp obj_InstaWarp script
	declarevariable FightOrFlight obj_FightOrFlight script
	declarevariable UndockWarp obj_UndockWarp script
	declarevariable Salvage obj_Salvage script
	declarevariable DroneControl obj_DroneControl script

	Dynamic:PopulateBehaviors
	Dynamic:PopulateMiniModes

	while TRUE
	{
		if ${Me(exists)} && ${MyShip(exists)} && (${Me.InSpace} || ${Me.InStation})
		{
			break
		}
		wait 10
	}
	Config.Common:SetCharID[${Me.CharID}]

	declarevariable Client obj_Client script
	declarevariable Move obj_Move script
	declarevariable Ship obj_Ship script
	declarevariable Cargo obj_Cargo script
	declarevariable RefineData obj_Configuration_RefineData script
	declarevariable Drones obj_Drones script


	Logger:Log["Tehbot", "Module initialization complete", "y"]

	if ${Config.Common.AutoStart}
	{
		Tehbot:Resume
	}
	else
	{
		Logger:Log["Tehbot", "Paused", "r"]
	}


	while TRUE
	{
		wait 10
	}
}
