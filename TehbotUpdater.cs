using System;
using System.IO;
using System.Net;
using System.Text;
using System.Diagnostics;

using InnerSpaceAPI;

namespace TehbotUpdater
{
	class Program
	{
		static void Main(string[] args)
		{
			if (args == null || args.Length == 0)
			{
				string[] files = {
					"LICENSE",
					"README.md",
					"Tehbot.iss",
					"Tehbot.xml",
					"behavior/MiniMode.iss",
					"behavior/MiniMode.xml",
					"behavior/Mission.iss",
					"behavior/Mission.xml",
					"behavior/Salvager.iss",
					"behavior/Salvager.xml",
					"core/Defines.iss",
					"core/Macros.iss",
					"core/obj_Busy.iss",
					"core/obj_Cargo.iss",
					"core/obj_Client.iss",
					"core/obj_Configuration.iss",
					"core/obj_Drones.iss",
					"core/obj_Dynamic.iss",
					"core/obj_Login.iss",
					"core/obj_Module.iss",
					"core/obj_ModuleList.iss",
					"core/obj_Move.iss",
					"core/obj_NPCData.iss",
					"core/obj_PrioritizedTargets.iss",
					"core/obj_Utility.iss",
					"core/obj_Ship.iss",
					"core/obj_StateQueue.iss",
					"core/obj_TargetList.iss",
					"core/obj_Tehbot.iss",
					"core/obj_TehbotUI.iss",
					"core/obj_Logger.iss",
					"data/DroneData.xml",
					"data/NPCData.xml",
					"data/MissionDataExample.iss",
					"minimode/Automate.iss",
					"minimode/Automate.xml",
					"minimode/AutoModule.iss",
					"minimode/AutoModule.xml",
					"minimode/AutoThrust.iss",
					"minimode/AutoThrust.xml",
					"minimode/DroneControl.iss",
					"minimode/DroneControl.xml",
					"minimode/InstaWarp.iss",
					"minimode/InstaWarp.xml",
					"minimode/FightOrFlight.iss",
					"minimode/FightOrFlight.xml",
					"minimode/Salvage.iss",
					"minimode/Salvage.xml",
					"minimode/UndockWarp.iss",
					"minimode/UndockWarp.xml"
				};
				string InstallPath = InnerSpace.Path + "/Scripts/Tehbot/";
				InnerSpace.Echo("Building Folder Structure");
				System.IO.Directory.CreateDirectory(InstallPath + "/behavior");
				System.IO.Directory.CreateDirectory(InstallPath + "/core");
				System.IO.Directory.CreateDirectory(InstallPath + "/data");
				System.IO.Directory.CreateDirectory(InstallPath + "/minimode");
				using (WebClient wc = new System.Net.WebClient())
				{
					ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
					ServicePointManager.Expect100Continue = true;
					wc.Headers["User-Agent"] = "Mozilla/4.0 (Compatible; Windows NT 5.1; MSIE 6.0) (compatible; MSIE 6.0; Windows NT 5.1; .NET CLR 1.1.4322; .NET CLR 2.0.50727)";
					foreach (string file in files)
					{
						InnerSpace.Echo("Downloading: " + file);
						wc.DownloadFile("https://raw.githubusercontent.com/isxGames/Tehbot/main/" + file, InstallPath + file);
					}
				}

				return;
			}
			if (args.Length == 1)
			{
				if (args[0] == "CurVersion")
				{
					using (WebClient wc = new System.Net.WebClient())
					{
						ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
						ServicePointManager.Expect100Continue = true;
						wc.Headers["User-Agent"] = "Mozilla/4.0 (Compatible; Windows NT 5.1; MSIE 6.0) (compatible; MSIE 6.0; Windows NT 5.1; .NET CLR 1.1.4322; .NET CLR 2.0.50727)";
						string json = wc.DownloadString("https://api.github.com/repos/isxGames/Tehbot/git/trees/main");
						json = json.Split(':')[1];
						InnerSpace.Echo(json.Split('"')[1]);
					}
				}
			}
		}
	}

}

