# Tehbot - A mission running and salvaging bot

Tehbot is a rewrite of Combot designed specifically to run missions, usually in the safety of high sec. It also contains a salvaging bot.

## Mission Running

The bot will run missions using a mission configuration you build yourself. To build the configuration, see the data/MissionDataExample.iss file, and follow the instructions within. It's actually very simple to configure, as most missions only require one line of configuration.

User beware: This bot is NOT designed to run missions with every ship configuration imaginable. For example, drones are ONLY used to kill frigates and destroyers that get within 15km. Sorry, no drone boat support. In addition, for best results you should try and maximize your damage application range. Heavy missiles instead of HAMs, Cruise Missiles instead of torpedos, etc.

This bot is also not a good candidate for running missions you can barely do by hand. Exmamples are burner missions and trying to run higher level missions with low-skilled characters. Level 4s in a drake? Nope. Level 3s in a caracal? Probably not...

This bot also lacks any kind of safety functions. It won't protect you if you try to run missions while someone has you wardecced, and if your ship doesn't have enough tank to survive a mission it won't warp out when you go into structure. Your aim should be to set your ship up so it can easily run missions - best practice is to make it so your ship would be fine if you let it sit in a mission and get shot at indefinitely

### Mission Flow

Unless otherwise specified in the config, the bot will fly to the mission location, kill every enemy on grid, then follow the gate if there is one on grid. It will repeat this until there are no more gates. If your mission requires an item in your cargo hold, set it in the config following the examples. Most of missions are now supported and tested including The Anomaly and World Collide, but I can't test all missions especially those fighting navys. So you may still encounter missions that the bot can't do no matter how hard you try try and configure them. You can config and skip them in this case.

## Salvaging

The salvager included with this bot is designed to respond to innerspace relays from the mission runners telling it that their sites are safe to salvage. Therefore, if you are running multiple computers, you'll need to set up an innerspace relay. The bot will not follow gates, as it expects the missions to be completed, and therefore all gates/enemies despawned, before it is told the sites are ready.

## Support

Visit the isxGames discord channel for support. I'm usually there.

## Donations

Use my bitcoin address: 31vArgW2AwpKUkMkKMTj5UFmjCYLp6F1Ck

Or

[![Bitcoin Donate Button](https://i.stack.imgur.com/MnQ6V.png)](https://isxgames.github.io/Tehbot/bitcoin-redirect.html)