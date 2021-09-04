---
title: "Setup 7 Days Game Server on Docker"
date: 2021-09-04T21:00:00+02:00
draft: false
description: "Tutorial on how to setup a 7 Days to Die Game Server on Docker."
tags: ["docker", "games", "server"]
categories: ["containers"]
---

![7daystodie](https://7daystodie.com/images/header_g.png)

This post will show how to setup your own [7 days to die](https://7daystodie.com/) game server on [docker](https://docker.com) using docker compose.

## About

The game [7 days to die](https://7daystodie.com/) is set in a post-apocalyptic world overrun by zombies, 7 Days to Die is an open-world game that is a unique combination of first person shooter, survival horror, tower defense, and role-playing games. It presents multiple features such as combat, crafting, looting, mining, exploration, and character growth.

I've been playing it for a couple of weeks an decided to share how I've setup my server on Docker.

## Setup using Docker Compose

The `docker-compose.yml`:

```yaml
# https://hub.docker.com/r/vinanrra/7dtd-server
version: '3.8'

services:
  7dtdserver:
    image: vinanrra/7dtd-server
    container_name: 7days-gameserver
    environment:
      # documented here 
      # https://github.com/vinanrra/Docker-7DaysToDie#parameters
      - START_MODE=1 
      - VERSION=stable 
      - PUID=1000 # your uid of your user
      - PGID=1000 # your gid of your user's group
      - TimeZone=Africa/Johannesburg
      - TEST_ALERT=YES
      #- ALLOC_FIXES=YES #Optional - Install ALLOC FIXES
    volumes:
      - ./data/serverfiles:/home/sdtdserver/serverfiles/ #Optional, serverfiles
      - ./data/7daystodie:/home/sdtdserver/.local/share/7DaysToDie/ #Optional, maps files
      - ./data/log:/home/sdtdserver/log/ #Optional, logs
      - ./data/backups:/home/sdtdserver/lgsm/backup/ #Optional, backups
      - ./data/lgsm-config:/home/sdtdserver/lgsm/config-lgsm/sdtdserver # Optional, alerts
    ports:
      - 26900:26900/tcp
      - 26900:26900/udp
      - 26901:26901/udp
      - 26902:26902/udp
      - 8080:8080/tcp 
      - 8081:8081/tcp 
      - 8082:8082/tcp
    restart: unless-stopped #NEVER USE WITH START_MODE=4 or START_MODE=0
    logging:
      driver: "json-file"
      options:
        max-size: "1m"
```

You can now boot the server, since its the initial boot, the server files will be downloaded and the config will be generated:

```bash
docker-compose up -d
```

To configure notifications, you can have a look at the `data/lgsm-config/common.cfg` config file, for sending notifications to discord, [create a discord webhook](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks) and configure as the following:

```
discordalert="on"
discordwebhook="https://discord.com/api/webhooks/x/x"
```

And for configuring your server, such as max players, server password, etc, you can look at the `data/serverfiles/sdtdserver.xml` config file, a example of mine:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ServerSettings>
   <!-- GENERAL SERVER SETTINGS -->
   <!-- Server representation -->
   <property name="ServerName" value="My7DaysServer" />
   <!-- Whatever you want the name of the server to be. -->
   <property name="ServerDescription" value="a demo for a blog post" />
   <!-- Whatever you want the server description to be, will be shown in the server browser. -->
   <property name="ServerWebsiteURL" value="" />
   <!-- Website URL for the server, will be shown in the serverbrowser as a clickable link -->
   <property name="ServerPassword" value="secret" />
   <!-- Password to gain entry to the server -->
   <property name="ServerLoginConfirmationText" value="" />
   <!-- If set the user will see the message during joining the server and has to confirm it before continuing. For more complex changes to this window you can change the "serverjoinrulesdialog" window in XUi -->
   <!-- Networking -->
   <property name="ServerPort" value="26900" />
   <!-- Port you want the server to listen on. Keep it in the ranges 26900 to 26905 or 27015 to 27020 if you want PCs on the same LAN to find it as a LAN server. -->
   <property name="ServerVisibility" value="2" />
   <!-- Visibility of this server: 2 = public, 1 = only shown to friends, 0 = not listed. As you are never friend of a dedicated server setting this to "1" will only work when the first player connects manually by IP. -->
   <property name="ServerDisabledNetworkProtocols" value="SteamNetworking" />
   <!-- Networking protocols that should not be used. Separated by comma. Possible values: LiteNetLib, SteamNetworking. Dedicated servers should disable SteamNetworking if there is no NAT router in between your users and the server or when port-forwarding is set up correctly -->
   <property name="ServerMaxWorldTransferSpeedKiBs" value="1024" />
   <!-- Maximum (!) speed in kiB/s the world is transferred at to a client on first connect if it does not have the world yet. Maximum is about 1300 kiB/s, even if you set a higher value. -->
   <!-- Slots -->
   <property name="ServerMaxPlayerCount" value="8" />
   <!-- Maximum Concurrent Players -->
   <property name="ServerReservedSlots" value="0" />
   <!-- Out of the MaxPlayerCount this many slots can only be used by players with a specific permission level -->
   <property name="ServerReservedSlotsPermission" value="100" />
   <!-- Required permission level to use reserved slots above -->
   <property name="ServerAdminSlots" value="0" />
   <!-- This many admins can still join even if the server has reached MaxPlayerCount -->
   <property name="ServerAdminSlotsPermission" value="0" />
   <!-- Required permission level to use the admin slots above -->
   <!-- Admin interfaces -->
   <property name="ControlPanelEnabled" value="true" />
   <!-- Enable/Disable the web control panel -->
   <property name="ControlPanelPort" value="8080" />
   <!-- Port of the control panel webpage -->
   <property name="ControlPanelPassword" value="secret" />
   <!-- Password to gain entry to the control panel -->
   <property name="TelnetEnabled" value="true" />
   <!-- Enable/Disable the telnet -->
   <property name="TelnetPort" value="8081" />
   <!-- Port of the telnet server -->
   <property name="TelnetPassword" value="" />
   <!-- Password to gain entry to telnet interface. If no password is set the server will only listen on the local loopback interface -->
   <property name="TelnetFailedLoginLimit" value="10" />
   <!-- After this many wrong passwords from a single remote client the client will be blocked from connecting to the Telnet interface -->
   <property name="TelnetFailedLoginsBlocktime" value="10" />
   <!-- How long will the block persist (in seconds) -->
   <property name="TerminalWindowEnabled" value="true" />
   <!-- Show a terminal window for log output / command input (Windows only) -->
   <!-- Folder and file locations -->
   <property name="AdminFileName" value="serveradmin.xml" />
   <!-- Server admin file name. Path relative to the SaveGameFolder -->
   <!-- Other technical settings -->
   <property name="EACEnabled" value="true" />
   <!-- Enables/Disables EasyAntiCheat -->
   <property name="HideCommandExecutionLog" value="0" />
   <!-- Hide logging of command execution. 0 = show everything, 1 = hide only from Telnet/ControlPanel, 2 = also hide from remote game clients, 3 = hide everything -->
   <property name="MaxUncoveredMapChunksPerPlayer" value="131072" />
   <!-- Override how many chunks can be uncovered on the ingame map by each player. Resulting max map file size limit per player is (x * 512 Bytes), uncovered area is (x * 256 m²). Default 131072 means max 32 km² can be uncovered at any time -->
   <property name="PersistentPlayerProfiles" value="false" />
   <!-- If disabled a player can join with any selected profile. If true they will join with the last profile they joined with -->
   <!-- GAMEPLAY -->
   <!-- World -->
   <property name="GameWorld" value="Navezgane" />
   <!-- "RWG" (see WorldGenSeed and WorldGenSize options below) or any already existing world name in the Worlds folder (currently shipping with e.g. "Navezgane", "PREGEN01", ...) -->
   <property name="WorldGenSeed" value="asdf" />
   <!-- If RWG this is the seed for the generation of the new world. If a world with the resulting name already exists it will simply load it -->
   <property name="WorldGenSize" value="4096" />
   <!-- If RWG this controls the width and height of the created world. It is also used in combination with WorldGenSeed to create the internal RWG seed thus also creating a unique map name even if using the same WorldGenSeed. Has to be between 2048 and 16384, though large map sizes will take long to generate / download / load -->
   <property name="GameName" value="My Game" />
   <!-- Whatever you want the game name to be. This affects the save game name as well as the seed used when placing decoration (trees etc) in the world. It does not control the generic layout of the world if creating an RWG world -->
   <property name="GameMode" value="GameModeSurvival" />
   <!-- GameModeSurvival -->
   <!-- Difficulty -->
   <property name="GameDifficulty" value="2" />
   <!-- 0 - 5, 0=easiest, 5=hardest -->
   <property name="BlockDamagePlayer" value="100" />
   <!-- How much damage do players to blocks (percentage in whole numbers) -->
   <property name="BlockDamageAI" value="100" />
   <!-- How much damage do AIs to blocks (percentage in whole numbers) -->
   <property name="BlockDamageAIBM" value="100" />
   <!-- How much damage do AIs during blood moons to blocks (percentage in whole numbers) -->
   <property name="XPMultiplier" value="100" />
   <!-- XP gain multiplier (percentage in whole numbers) -->
   <property name="PlayerSafeZoneLevel" value="5" />
   <!-- If a player is less or equal this level he will create a safe zone (no enemies) when spawned -->
   <property name="PlayerSafeZoneHours" value="5" />
   <!-- Hours in world time this safe zone exists -->
   <!--  -->
   <property name="BuildCreate" value="false" />
   <!-- cheat mode on/off -->
   <property name="DayNightLength" value="60" />
   <!-- real time minutes per in game day: 60 minutes -->
   <property name="DayLightLength" value="18" />
   <!-- in game hours the sun shines per day: 18 hours day light per in game day -->
   <property name="DropOnDeath" value="1" />
   <!-- 0 = nothing, 1 = everything, 2 = toolbelt only, 3 = backpack only, 4 = delete all -->
   <property name="DropOnQuit" value="0" />
   <!-- 0 = nothing, 1 = everything, 2 = toolbelt only, 3 = backpack only -->
   <property name="BedrollDeadZoneSize" value="15" />
   <!-- Size (box "radius", so a box with 2 times the given value for each side's length) of bedroll deadzone, no zombies will spawn inside this area, and any cleared sleeper volumes that touch a bedroll deadzone will not spawn after they've been cleared. -->
   <property name="BedrollExpiryTime" value="45" />
   <!-- Number of days a bedroll stays active after owner was last online -->
   <!-- Performance related -->
   <property name="MaxSpawnedZombies" value="64" />
   <!-- This setting covers the entire map. There can only be this many zombies on the entire map at one time. Changing this setting has a huge impact on performance. -->
   <property name="MaxSpawnedAnimals" value="50" />
   <!-- If your server has a large number of players you can increase this limit to add more wildlife. Animals don't consume as much CPU as zombies. NOTE: That this doesn't cause more animals to spawn arbitrarily: The biome spawning system only spawns a certain number of animals in a given area, but if you have lots of players that are all spread out then you may be hitting the limit and can increase it. -->
   <property name="ServerMaxAllowedViewDistance" value="12" />
   <!-- Max viewdistance a client may request (6 - 12). High impact on memory usage and performance. -->
   <!-- Zombie settings -->
   <property name="EnemySpawnMode" value="true" />
   <!-- Enable/Disable enemy spawning -->
   <property name="EnemyDifficulty" value="0" />
   <!-- 0 = Normal, 1 = Feral -->
   <property name="ZombieMove" value="0" />
   <!-- 0-4 (walk, jog, run, sprint, nightmare) -->
   <property name="ZombieMoveNight" value="3" />
   <!-- 0-4 (walk, jog, run, sprint, nightmare) -->
   <property name="ZombieFeralMove" value="3" />
   <!-- 0-4 (walk, jog, run, sprint, nightmare) -->
   <property name="ZombieBMMove" value="3" />
   <!-- 0-4 (walk, jog, run, sprint, nightmare) -->
   <property name="BloodMoonFrequency" value="7" />
   <!-- What frequency (in days) should a blood moon take place. Set to "0" for no blood moons -->
   <property name="BloodMoonRange" value="0" />
   <!-- How many days can the actual blood moon day randomly deviate from the above setting. Setting this to 0 makes blood moons happen exactly each Nth day as specified in BloodMoonFrequency -->
   <property name="BloodMoonWarning" value="8" />
   <!-- The Hour number that the red day number begins on a blood moon day. Setting this to -1 makes the red never show.  -->
   <property name="BloodMoonEnemyCount" value="8" />
   <!-- This is the number of zombies that can be alive (spawned at the same time) at any time PER PLAYER during a blood moon horde, however, MaxSpawnedZombies overrides this number in multiplayer games. Also note that your game stage sets the max number of zombies PER PARTY. Low game stage values can result in lower number of zombies than the BloodMoonEnemyCount setting. Changing this setting has a huge impact on performance. -->
   <!-- Loot -->
   <property name="LootAbundance" value="100" />
   <!-- percentage in whole numbers -->
   <property name="LootRespawnDays" value="30" />
   <!-- days in whole numbers -->
   <property name="AirDropFrequency" value="72" />
   <!-- How often airdrop occur in game-hours, 0 == never -->
   <property name="AirDropMarker" value="false" />
   <!-- Sets if a marker is added to map/compass for air drops. -->
   <!-- Multiplayer -->
   <property name="PartySharedKillRange" value="100" />
   <!-- The distance you must be within to receive party shared kill xp and quest party kill objective credit. -->
   <property name="PlayerKillingMode" value="3" />
   <!-- Player Killing Settings (0 = No Killing, 1 = Kill Allies Only, 2 = Kill Strangers Only, 3 = Kill Everyone) -->
   <!-- Land claim options -->
   <property name="LandClaimCount" value="1" />
   <!-- Maximum allowed land claims per player. -->
   <property name="LandClaimSize" value="41" />
   <!-- Size in blocks that is protected by a keystone -->
   <property name="LandClaimDeadZone" value="30" />
   <!-- Keystones must be this many blocks apart (unless you are friends with the other player) -->
   <property name="LandClaimExpiryTime" value="7" />
   <!-- The number of days a player can be offline before their claims expire and are no longer protected -->
   <property name="LandClaimDecayMode" value="0" />
   <!-- Controls how offline players land claims decay. 0=Slow (Linear) , 1=Fast (Exponential), 2=None (Full protection until claim is expired). -->
   <property name="LandClaimOnlineDurabilityModifier" value="4" />
   <!-- How much protected claim area block hardness is increased when a player is online. 0 means infinite (no damage will ever be taken). Default is 4x -->
   <property name="LandClaimOfflineDurabilityModifier" value="4" />
   <!-- How much protected claim area block hardness is increased when a player is offline. 0 means infinite (no damage will ever be taken). Default is 4x -->
   <property name="LandClaimOfflineDelay" value="0" />
   <!-- The number of minutes after a player logs out that the land claim area hardness transitions from online to offline. Default is 0 -->
   <property name="TwitchServerPermission" value="90" />
   <!-- Required permission level to use twitch integration on the server -->
   <property name="TwitchBloodMoonAllowed" value="false" />
   <!-- If the server allows twitch actions during a blood moon. This could cause server lag with extra zombies being spawned during blood moon. -->
   <!-- There are several game settings that you cannot change when starting a new game.
	You can use console commands to change at least some of them ingame.
	setgamepref BedrollDeadZoneSize 30 -->
</ServerSettings>
```

After any of the configs were changed, you can restart the server with:

```
docker-compose restart
```

To check the server status, exec into the container:

```
docker exec -it 7days-gameserver bash
```

Then switch to the `sdtdserver` user:

```
su - sdtdserver
```

A list of commands that you can use (from linuxgsm):

```bash
Commands
start         st   | Start the server.
stop          sp   | Stop the server.
restart       r    | Restart the server.
monitor       m    | Check server status and restart if crashed.
test-alert    ta   | Send a test alert.
details       dt   | Display server information.
postdetails   pd   | Post details to termbin.com (removing passwords).
update-lgsm   ul   | Check and apply any LinuxGSM updates.
update        u    | Check and apply any server updates.
force-update  fu   | Apply server updates bypassing check.
validate      v    | Validate server files with SteamCMD.
backup        b    | Create backup archives of the server.
console       c    | Access server console.
debug         d    | Start server directly in your terminal.
mods-install  mi   | View and install available mods/addons.
mods-remove   mr   | View and remove an installed mod/addon.
mods-update   mu   | Update installed mods/addons.
install       i    | Install the server.
auto-install  ai   | Install the server without prompts.
developer     dev  | Enable developer Mode.
donate        do   | Donation options.
```

To check the status of the server:

```
./sdtdserver monitor
[  OK  ] Monitoring sdtdserver: Checking session: OK
[  OK  ] Monitoring sdtdserver: Querying port: gsquery: 172.24.0.2:26900 : 0/1: OK
```

Now you can launch 7 days and to join your server, select "Join A Game":

![image](https://user-images.githubusercontent.com/567298/132108002-de18399b-0cae-4eb6-91cb-cc91b72cc71d.png)

Then select "Connect To IP":

![image](https://user-images.githubusercontent.com/567298/132108054-c5942ef1-5fa0-40da-891b-965f841ff139.png)

If your server runs on your local network use the private IP address and the port `26900`, if you are connecting via the internet, you will need to forward `26900` tcp and udp from your router to your server, if you are using a home internet setup and use the public IP address.

## Mods

The following resources can be referenced for installing mods on your server:

- https://7daystodiemods.com/how-to-install-7-days-to-die-mods/
- https://7daystodiemods.com/
- https://docs.linuxgsm.com/commands/mods

## Resources

The following resources can be used to reference documentation:

- https://7daystodie.com/
- https://hub.docker.com/r/vinanrra/7dtd-server
- https://github.com/vinanrra/Docker-7DaysToDie
- https://docs.linuxgsm.com/

## Thank You

Thanks for reading, if you like my content, check out my **[website](https://ruan.dev)** or follow me at **[@ruanbekker](https://twitter.com/ruanbekker)** on Twitter.
