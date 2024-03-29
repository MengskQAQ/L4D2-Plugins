#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>

public Plugin myinfo =
{
	name = "L4D2 Survivor Auto aim",
	author = "DingbatFlat, HarryPotter, Mengsk",
	description = "Improve Survivor",
	version = "1.31",
	url = "https://github.com/MengskQAQ/L4D2-Plugins"
}

/*
// ====================================================================================================

About:

- Main items that can be improve shoot by introducing this plugin.

Attack a Common Infected.
Attack a Special Infected.
Attack a Tank.
Bash a flying Jockey.
Shoot a tank rock.
Shoot a Witch (Contronls the attack timing when have a shotgun).
Restrict switching to the sub weapon.

And the action during incapacitated.

- Sourcemod ver 1.10 is required.

// ====================================================================================================

Change Log:
1.31 (19-Aug-2022)
    - try to reduce the press to server.
    - add code about new-connect players.
1.3  (19-Aug-2022)
    - more violent,simply,and without beauty.
    - delete useless code.
1.2  (10-May-2022)
    - delete useless code.
    - try to rebuild the code.
    - add more optional.
1.12 (26-March-2022)
    - delete useless code.
    - try to fix the problem because of the lag between client and server.
    - fix the timer lag when plugins disable.
1.00 (09-September-2021)
    - Initial release.


// ====================================================================================================

#define BUFSIZE			(1 << 12)	// 4k

#define ZC_SMOKER       1
#define ZC_BOOMER       2
#define ZC_HUNTER       3
#define ZC_SPITTER      4
#define ZC_JOCKEY       5
#define ZC_CHARGER      6
#define ZC_TANK         8

#define MAXPLAYERS1     (MAXPLAYERS+1)
#define MAXENTITIES 2048

#define WITCH_INCAPACITATED 1
#define WITCH_KILLED 2

/****************************************************************************************************/

// ====================================================================================================
// Handle
// ====================================================================================================
ConVar sb_fix_enabled			= null;
ConVar sb_fix_headshot			= null;
ConVar sb_fix_lagshoot			= null;

ConVar sb_fix_help_enabled		= null;
ConVar sb_fix_help_range		= null;

ConVar sb_fix_ci_enabled		= null;
ConVar sb_fix_ci_range			= null;

ConVar sb_fix_si_enabled		= null;
ConVar sb_fix_si_range			= null;

ConVar sb_fix_tank_enabled		= null;
ConVar sb_fix_tank_range		= null;

ConVar sb_fix_si_tank_priority_type	= null;

ConVar sb_fix_bash_enabled		= null;
ConVar sb_fix_bash_jockey_range		= null;

ConVar sb_fix_rock_enabled		= null;
ConVar sb_fix_rock_range		= null;

ConVar sb_fix_witch_enabled		= null;
ConVar sb_fix_witch_range		= null;
ConVar sb_fix_witch_range_incapacitated	= null;
ConVar sb_fix_witch_range_killed	= null;
ConVar sb_fix_witch_shotgun_range_max	= null;
ConVar sb_fix_witch_shotgun_range_min	= null;

ConVar sb_fix_prioritize_ownersmoker	= null;

Handle ClientLag_Timer;

// ====================================================================================================
// SendProp
// ====================================================================================================
int g_Velo;

// ====================================================================================================
// Variables
// ====================================================================================================
bool g_bEnabled;
bool g_bHeadshot;
bool g_bLagShoot;

bool c_bHelp_Enabled;
float c_fHelp_Range;

bool c_bCI_Enabled;
float c_fCI_Range;

bool c_bSI_Enabled;
float c_fSI_Range;

bool c_bTank_Enabled;
float c_fTank_Range;

int c_iSITank_PriorityType;

bool c_bBash_Enabled;
float c_fBash_JockeyRange;

bool c_bRock_Enabled;
float c_fRock_Range;

bool c_bWitch_Enabled;
float c_fWitch_Range;
float c_fWitch_Range_Incapacitated;
float c_fWitch_Range_Killed;

bool c_bPrioritize_OwnerSmoker;

// ====================================================================================================
// Int Array
// ====================================================================================================
int g_iWitch_Process[MAXENTITIES];

int g_Stock_NextThinkTick[MAXPLAYERS1];

// ====================================================================================================
// Bool Array
// ====================================================================================================
bool g_bAutoAim[MAXPLAYERS1];
bool g_bAllowAutoaim[MAXPLAYERS1] = false;
bool g_bWitchActive = false;

bool g_bShove[MAXPLAYERS1][MAXPLAYERS1];
// ====================================================================================================
// Float Array
// ====================================================================================================
float lagTime[MAXPLAYERS1];
float clientLerp[MAXPLAYERS1]; 

/****************************************************************************************************/

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{
	EngineVersion test = GetEngineVersion();
	
	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	// Notes:
	// If "~_enabled" of the group is not set to 1, other Cvars in that group will not work.
	// If the plugin is too heavy, Try disable searching for "Entities" other than Client. (CI, Witch and tank rock)
	
	// ---------------------------------
	sb_fix_enabled			= CreateConVar("sb_fix_enabled", "0", "Enable the plugin. <0: Disable, 1: Enable>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	sb_fix_headshot			= CreateConVar("sb_fix_headshot", "0", "Force damagetype headshot. <0: Disable, 1: Enable>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	sb_fix_lagshoot			= CreateConVar("sb_fix_lagshoot", "1", "Enable lag shoot. <0: Disable, 1: Enable>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	// ---------------------------------
	sb_fix_help_enabled		= CreateConVar("sb_fix_help_enabled", "1", "Help a pinning survivor. <0: Disable, 1: Enable | def: 1>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	sb_fix_help_range		= CreateConVar("sb_fix_help_range", "1200", "Range to shoot/search a pinning survivor. <1 ~ 3000 | def: 1200>", FCVAR_NOTIFY, true, 1.0, true, 3000.0);
	// ---------------------------------
	sb_fix_ci_enabled		= CreateConVar("sb_fix_ci_enabled", "1", "Deal with Common Infecteds. <0: Disable, 1: Enable | def: 1>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	sb_fix_ci_range			= CreateConVar("sb_fix_ci_range", "500", "Range to shoot/search a Common Infected. <1 ~ 2000 | def: 500>", FCVAR_NOTIFY, true, 1.0, true, 2000.0);
	// ---------------------------------
	sb_fix_si_enabled		= CreateConVar("sb_fix_si_enabled", "1", "Deal with Special Infecteds. <0: Disable, 1: Enable | def: 1>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	sb_fix_si_range			= CreateConVar("sb_fix_si_range", "800", "Range to shoot/search a Special Infected. <1 ~ 3000 | def: 500>", FCVAR_NOTIFY, true, 1.0, true, 3000.0);
	// ---------------------------------
	sb_fix_tank_enabled		= CreateConVar("sb_fix_tank_enabled", "1", "Deal with Tanks. <0: Disable, 1: Enable | def: 1>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	sb_fix_tank_range		= CreateConVar("sb_fix_tank_range", "1200", "Range to shoot/search a Tank. <1 ~ 3000 | def: 1200>", FCVAR_NOTIFY, true, 1.0, true, 3000.0);
	// ---------------------------------
	sb_fix_si_tank_priority_type	= CreateConVar("sb_fix_si_tank_priority_type", "0", "When a Special Infected and a Tank is together within the specified range, which to prioritize. <0: Nearest, 1: Special Infected, 2: Tank | def: 0>", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	// ---------------------------------
	sb_fix_bash_enabled		= CreateConVar("sb_fix_bash_enabled", "1", "Bash a flying Hunter or Jockey. <0: Disable, 1: Enable | def: 1>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	sb_fix_bash_jockey_range	= CreateConVar("sb_fix_bash_jockey_range", "125", "Range to bash/search a flying Jockey. <1 ~ 500 | def: 125>", FCVAR_NOTIFY, true, 1.0, true, 500.0);
	// ---------------------------------
	sb_fix_rock_enabled		= CreateConVar("sb_fix_rock_enabled", "1", "Shoot a tank rock. <0: Disable, 1: Enable | def: 1>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	sb_fix_rock_range		= CreateConVar("sb_fix_rock_range", "700", "Range to shoot/search a tank rock. <1 ~ 2000 | def: 700>", FCVAR_NOTIFY, true, 1.0, true, 2000.0);
	// ---------------------------------
	sb_fix_witch_enabled		= CreateConVar("sb_fix_witch_enabled", "1", "Shoot a rage Witch. <0: Disable, 1: Enable | def: 1>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	sb_fix_witch_range		= CreateConVar("sb_fix_witch_range", "1500", "Range to shoot/search a rage Witch. <1 ~ 2000 | def: 1500>", FCVAR_NOTIFY, true, 1.0, true, 2000.0);
	sb_fix_witch_range_incapacitated= CreateConVar("sb_fix_witch_range_incapacitated", "1000", "Range to shoot/search a Witch that incapacitated a survivor. <0 ~ 2000 | def: 1000>", FCVAR_NOTIFY, true, 0.0, true, 2000.0);
	sb_fix_witch_range_killed	= CreateConVar("sb_fix_witch_range_killed", "0", "Range to shoot/search a Witch that killed a survivor. <0 ~ 2000 | def: 0>", FCVAR_NOTIFY, true, 0.0, true, 2000.0);
	sb_fix_witch_shotgun_range_max	= CreateConVar("sb_fix_witch_shotgun_range_max", "300", "If a Witch is within distance of the values, stop the attack. <1 ~ 1000 | def: 300>", FCVAR_NOTIFY, true, 1.0, true, 1000.0);
	sb_fix_witch_shotgun_range_min	= CreateConVar("sb_fix_witch_shotgun_range_min", "70", "If a Witch is at distance of the values or more, stop the attack. <1 ~ 500 | def: 70>", FCVAR_NOTIFY, true, 1.0, true, 500.0);
	// ---------------------------------
	sb_fix_prioritize_ownersmoker	= CreateConVar("sb_fix_prioritize_ownersmoker", "1", "Priority given to dealt a Smoker that is try to pinning self. <0: No, 1: Yes | def: 1>", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	sb_fix_help_enabled.AddChangeHook(SBHelp_ChangeConvar);
	sb_fix_help_range.AddChangeHook(SBHelp_ChangeConvar);
	// ---------------------------------
	sb_fix_ci_enabled.AddChangeHook(SBCI_ChangeConvar);
	sb_fix_ci_range.AddChangeHook(SBCI_ChangeConvar);
	// ---------------------------------
	sb_fix_si_enabled.AddChangeHook(SBSI_ChangeConvar);
	sb_fix_si_range.AddChangeHook(SBSI_ChangeConvar);
	// ---------------------------------
	sb_fix_tank_enabled.AddChangeHook(SBTank_ChangeConvar);
	sb_fix_tank_range.AddChangeHook(SBTank_ChangeConvar);
	// ---------------------------------
	sb_fix_si_tank_priority_type.AddChangeHook(SBTank_ChangeConvar);
	// ---------------------------------
	sb_fix_bash_enabled.AddChangeHook(SBBash_ChangeConvar);
	sb_fix_bash_jockey_range.AddChangeHook(SBBash_ChangeConvar);
	// ---------------------------------
	sb_fix_rock_enabled.AddChangeHook(SBEnt_ChangeConvar);
	sb_fix_rock_range.AddChangeHook(SBEnt_ChangeConvar);
	sb_fix_witch_enabled.AddChangeHook(SBEnt_ChangeConvar);
	sb_fix_witch_range.AddChangeHook(SBEnt_ChangeConvar);
	sb_fix_witch_range_incapacitated.AddChangeHook(SBEnt_ChangeConvar);
	sb_fix_witch_range_killed.AddChangeHook(SBEnt_ChangeConvar);
	sb_fix_witch_shotgun_range_max.AddChangeHook(SBEnt_ChangeConvar);
	sb_fix_witch_shotgun_range_min.AddChangeHook(SBEnt_ChangeConvar);
	// ---------------------------------
	sb_fix_enabled.AddChangeHook(SBConfigChangeConvar);
	sb_fix_prioritize_ownersmoker.AddChangeHook(SBConfigChangeConvar);
	sb_fix_headshot.AddChangeHook(SBConfigChangeConvar);
	sb_fix_lagshoot.AddChangeHook(SBConfigChangeConvar);
	
	HookEvent("player_incapacitated", Event_PlayerIncapacitated); // Witch Event
	HookEvent("player_death", Event_PlayerDeath); // Witch Event
	
	HookEvent("witch_harasser_set", Event_WitchRage);
	HookEvent("player_hurt", Event_HeadShotChange, EventHookMode_Pre);
	
	HookEvent("witch_harasser_set", Event_WitchRage);
	
	g_Velo = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
	
	RegConsoleCmd("sm_autoaim", cmdAutoaim, "allow client to enable autoaim");
}

public void OnMapStart()
{
	input_Help();
	input_CI();
	input_SI();
	input_Tank();
	input_Bash();
	input_Entity();
	inputConfig();
}

public void OnAllPluginsLoaded()
{
	input_Help();
	input_CI();
	input_SI();
	input_Tank();
	input_Bash();
	input_Entity();
	inputConfig();
}

public void SBHelp_ChangeConvar(Handle convar, const char[] oldValue, const char[] newValue){ 	input_Help(); }
public void SBCI_ChangeConvar(Handle convar, const char[] oldValue, const char[] newValue){	input_CI(); }
public void SBSI_ChangeConvar(Handle convar, const char[] oldValue, const char[] newValue){	input_SI(); }
public void SBTank_ChangeConvar(Handle convar, const char[] oldValue, const char[] newValue){ 	input_Tank(); }
public void SBBash_ChangeConvar(Handle convar, const char[] oldValue, const char[] newValue){	input_Bash(); }
public void SBEnt_ChangeConvar(Handle convar, const char[] oldValue, const char[] newValue){	input_Entity();}
public void SBConfigChangeConvar(Handle convar, const char[] oldValue, const char[] newValue){	inputConfig();}

void input_Help()
{
	c_bHelp_Enabled = GetConVarBool(sb_fix_help_enabled);
	c_fHelp_Range = GetConVarInt(sb_fix_help_range) * 1.0;
}

void input_CI()
{
	c_bCI_Enabled = GetConVarBool(sb_fix_ci_enabled);
	c_fCI_Range = GetConVarInt(sb_fix_ci_range) * 1.0;
}

void input_SI()
{
	c_bSI_Enabled = GetConVarBool(sb_fix_si_enabled);
	c_fSI_Range = GetConVarInt(sb_fix_si_range) * 1.0;
}

void input_Tank()
{
	c_bTank_Enabled = GetConVarBool(sb_fix_tank_enabled);
	c_fTank_Range = GetConVarInt(sb_fix_tank_range) * 1.0;
	
	c_iSITank_PriorityType = GetConVarInt(sb_fix_si_tank_priority_type);
}

void input_Bash()
{
	c_bBash_Enabled = GetConVarBool(sb_fix_bash_enabled);
	c_fBash_JockeyRange = GetConVarInt(sb_fix_bash_jockey_range) * 1.0;
}

void input_Entity()
{
	c_bRock_Enabled = GetConVarBool(sb_fix_rock_enabled);
	c_fRock_Range = GetConVarInt(sb_fix_rock_range) * 1.0;
	
	c_bWitch_Enabled = GetConVarBool(sb_fix_witch_enabled);
	c_fWitch_Range = GetConVarInt(sb_fix_witch_range) * 1.0;
	c_fWitch_Range_Incapacitated = GetConVarInt(sb_fix_witch_range_incapacitated) * 1.0;
	c_fWitch_Range_Killed = GetConVarInt(sb_fix_witch_range_killed) * 1.0;
}

void inputConfig()
{
	g_bEnabled = GetConVarBool(sb_fix_enabled);
	g_bHeadshot = GetConVarBool(sb_fix_headshot);
	g_bLagShoot = GetConVarBool(sb_fix_lagshoot);
	
	c_bPrioritize_OwnerSmoker = GetConVarBool(sb_fix_prioritize_ownersmoker);
	
	LerpRecord();
	LagRecord();
	StateHelper();
	
	//Notes: I write it because I want to change spread in autoaim-mode, and that command is connect to another plugin.
	ServerCommand("sm_info_reload");
}


/****************************************************************************************************/


/* ================================================================================================
*=
*=		Round / Start Ready / Get Client Lag
*=
================================================================================================ */

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{	
	CreateTimer(0.1, Timer_GameStart, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public Action Timer_GameStart(Handle Timer)
{
	if(g_bEnabled){
		CPrintToChatAll("{blue}[{default}Auto Aim{blue}]{default} Plugin State:{olive} Running{default}");
		CPrintToChatAll("{blue}[{default}Auto Aim{blue}]{default} Disable Weapon:{olive} Shotgun{default}");
		CPrintToChatAll("{blue}[{default}Auto Aim{blue}]{default} Please response if you have any bugs");
	}
	LerpRecord();
	LagRecord();
}

void Anounnce(int client){
	if(g_bEnabled && !isNotSurvivorBot(client)){
		CPrintToChat(client, "{blue}[{default}Auto Aim{blue}]{default} Plugin State:{olive} Running{default}");
		CPrintToChat(client, "{blue}[{default}Auto Aim{blue}]{default} Disable Weapon:{olive} Shotgun{default}");
		CPrintToChat(client, "{blue}[{default}Auto Aim{blue}]{default} Don't be nervous if someone seems a cheater");
	}
}

void StateHelper(){
	if(g_bEnabled){
		for (int client = 1; client <= MaxClients; client++) {	
			if(isNotSurvivorBot(client) && IsPlayerAlive(client)){
				CPrintToChat(client, "{blue}[{default}Auto Aim{blue}]{default} Plugin State:{olive} Running{default}");
				CPrintToChat(client, "{blue}[{default}Auto Aim{blue}]{default} Type {olive}!autoaim{default} in chat to toggle Your State");
			}
		}
	}
}

void LagRecord()
{
	if(g_bEnabled){
		if(ClientLag_Timer != INVALID_HANDLE)
		{
			KillTimer(ClientLag_Timer);
			ClientLag_Timer = INVALID_HANDLE;
		}
		ClientLag_Timer = CreateTimer(1.0, Timer_LagTime, INVALID_HANDLE, TIMER_REPEAT);
	}else{
		if(ClientLag_Timer != INVALID_HANDLE)
		{
			KillTimer(ClientLag_Timer);
			ClientLag_Timer = INVALID_HANDLE;
		}
	}
}

void LerpRecord()
{
	for (int client = 1; client <= MaxClients; client++) {	
		if(isNotSurvivorBot(client) && IsPlayerAlive(client)){
			CreateTimer(0.1, Process, client, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action Timer_LagTime(Handle Timer)
{
	for (int client = 1; client <= MaxClients; client++) {	
		if(isNotSurvivorBot(client) && IsPlayerAlive(client)){
			lagTime[client] = GetClientLatency(client, NetFlow_Both) + clientLerp[client];
		}
	}
	return Plugin_Continue;
}

public void OnClientSettingsChanged(int client)
{
	if (IsValidEntity(client) && !IsFakeClient(client)) {
		ProcessPlayerLerp(client);
	}
}

public Action Process(Handle Timer, int client)
{
	ProcessPlayerLerp(client);
	return Plugin_Stop;
}

void ProcessPlayerLerp(int client)
{
	char buffer[100];
	GetClientInfo(client, "cl_interp", buffer, 100);
	clientLerp[client] = Clamp(StringToFloat(buffer), 0.0, 0.5);
}

/* ================================================================================================
*=
*=		Client Command
*=
================================================================================================ */

public Action cmdAutoaim(int client, int args)
{
	if (!client)	 return Plugin_Handled;
	if (!GetConVarBool(FindConVar("sb_fix_enabled")))
		return Plugin_Handled;

	if (!g_bAutoAim[client]){ 
		CPrintToChat(client, "{blue}[{default}Auto Aim{blue}]{default} Your State: {olive}On{default}");
	}else{
		CPrintToChat(client, "{blue}[{default}Auto Aim{blue}]{default} Your State: {olive}Off{default}");
	}
	g_bAutoAim[client] = !g_bAutoAim[client];
	return Plugin_Handled;
}

/* ================================================================================================
*=
*=		Force Headshot
*=
================================================================================================ */

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_TraceAttack, TraceAttack);
	SDKHook(client, SDKHook_WeaponSwitch, WeaponSwitch);
	Anounnce(client);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_TraceAttack, TraceAttack);
	SDKUnhook(client, SDKHook_WeaponSwitch, WeaponSwitch);
}

public Action TraceAttack(int victim,int &attacker,int &inflictor, float &damage,int &damagetype,int &ammotype,int hitbox,int hitgroup)
{
	if(!g_bEnabled || !g_bHeadshot)		return Plugin_Continue;
	if(!g_bAutoAim[attacker])		return Plugin_Continue;
	if(!g_bAllowAutoaim[attacker])	return Plugin_Continue;
	if(isSurvivor(victim))	return Plugin_Continue;
	if(GetEntProp(victim, Prop_Send, "m_zombieClass") == ZC_TANK)		return Plugin_Continue;
	
	if(g_bHeadshot && hitgroup != 1)
	{
		float newDamage = damage * 4;
		hitgroup = 1;
		damage = newDamage;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action Event_HeadShotChange(Event event, const char[] name, bool dontBroadcast)
{	
	if(!g_bEnabled || !g_bHeadshot)		return Plugin_Continue;
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int userid = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!g_bAutoAim[attacker])		return Plugin_Continue;
	if(isSurvivor(userid))	return Plugin_Continue;
	if(g_bAllowAutoaim[attacker]){
		event.SetBool("hitgroup", true);

	}
	return Plugin_Continue;
}

public Action WeaponSwitch(int client, int weapon)
{
	if (!g_bEnabled || !isSurvivor(client)) return Plugin_Continue;
	
	char classname[32];
	int slot0 = GetPlayerWeaponSlot(client, 0);
	if (slot0 > -1) {			
		GetEntityClassname(slot0, classname, sizeof(classname));
	}
	
	if (isHaveItem(classname, "weapon_shotgun_chrome")
		|| isHaveItem(classname, "weapon_shotgun_spas")
		|| isHaveItem(classname, "weapon_pumpshotgun")
		|| isHaveItem(classname, "weapon_autoshotgun")) {
			g_bAllowAutoaim[client] = false;
	}else{
		g_bAllowAutoaim[client] = true;
	}
	return Plugin_Continue;
}

/****************************************************************************************************/

/* Client key input processing
 *
 * buttons: Entered keys (enumはinclude/entity_prop_stock.inc参照)

 * angles:
 *      [0]: pitch(UP-DOWN) -89~+89
 *      [1]: yaw(360) -180~+180
 */
 
 /*
 *		OnPlayerRunCmd is Runs 30 times per second. (every 0.03333... seconds)
 */
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse,
	float vel[3], float angles[3], int &weapon, int &iSubType, int &iCmdNum, int &iTickCount, int &iSeed)
{
	if (g_bEnabled) {
		if (!IsFakeClient(client) && IsClientInGame(client) && IsPlayerAlive(client)) {
			if(g_bAutoAim[client] && g_bAllowAutoaim[client]){
				if ((buttons & IN_ATTACK) == IN_ATTACK){
					Action ret = Plugin_Continue;
					ret = onSBRunCmd(client, buttons, vel, angles);
					return ret;
				}
			}
		}
	}
	return Plugin_Continue;
}


/****************************************************************************************************/


/* ================================================================================================
*=
*=		Client Run Cmd
*=
================================================================================================ */
stock Action onSBRunCmd(int client, int &buttons, float vel[3], float angles[3])
{
	if (!isIncapacitated(client)
		&& GetEntityMoveType(client) != MOVETYPE_LADDER)
	{
		/* -------------------------------------------------------------------------------------------------------------------------------------------------------------- 
		****************************************
		*		Get The Weapon		*
		****************************************
		--------------------------------------------------------------------------------------------------------------------------------------------------------------- */
		
		int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"); 
		
		static char AW_Classname[32];
		if (weapon > MAXPLAYERS) GetEntityClassname(weapon, AW_Classname, sizeof(AW_Classname)); // Exception reported: Entity -1 (-1) is invalid
	
		/* -------------------------------------------------------------------------------------------------------------------------------------------------------------- 
		*********************************
		*		Action		 *
		*********************************
		--------------------------------------------------------------------------------------------------------------------------------------------------------------- */
		
		// Find a nearest visible Special Infected
		int new_target = -1;
		float min_dist = 100000.0;
		float self_pos[3], target_pos[3];
		
		if ((c_bSI_Enabled || c_bTank_Enabled) && !NeedsTeammateHelp_ExceptSmoker(client)) {
			GetClientAbsOrigin(client, self_pos);
			for (int x = 1; x <= MaxClients; ++x) {
				if (isInfected(x)
					&& IsPlayerAlive(x)
					&& !isIncapacitated(x)
					&& isVisibleTo(client, x))
				{
					float dist;
					
					GetClientAbsOrigin(x, target_pos);
					dist = GetVectorDistance(self_pos, target_pos);
					
					int zombieClass = getZombieClass(x);
					if ((c_bSI_Enabled && zombieClass != ZC_TANK && dist <= c_fSI_Range)
						|| (c_bTank_Enabled && zombieClass == ZC_TANK && dist <= c_fTank_Range))
					{
						if ((c_iSITank_PriorityType == 1 && zombieClass != ZC_TANK)
							|| (c_iSITank_PriorityType == 2 && zombieClass == ZC_TANK)) {
							if (dist < min_dist) {
								min_dist = dist;
								new_target = x;
								continue;
							}
						}
						
						if (dist < min_dist) {
							min_dist = dist;
							new_target = x;
						}
					}
					
				}
			}
		}
		
		int aCap_Survivor = -1;
		float min_dist_CapSur = 100000.0;
		float target_pos_CapSur[3];
		
		int aCap_Infected = -1;
		float min_dist_CapInf = 100000.0;
		float target_pos_CapInf[3];
		
		if (c_bHelp_Enabled && !NeedsTeammateHelp_ExceptSmoker(client)) {
			// Find a Survivor who are pinned
			for (int x = 1; x <= MaxClients; ++x) {
				if (isSurvivor(x)
					&& NeedsTeammateHelp(x)
					&& (x != client)
					&& (isVisibleTo(client, x) || isVisibleTo(x, client)))
				{
					float dist;
					
					GetClientAbsOrigin(x, target_pos_CapSur);
					dist = GetVectorDistance(self_pos, target_pos_CapSur);
					if (dist < c_fHelp_Range) {
						if (dist < min_dist_CapSur) {
							min_dist_CapSur = dist;
							aCap_Survivor = x;
						}
					}
				}
			}
			
			// Find a Special Infected who are pinning
			for (int x = 1; x <= MaxClients; ++x) {
				if (isInfected(x)
					&& CappingSuvivor(x)
					&& (isVisibleTo(client, x) || isVisibleTo(x, client)))
				{
					float dist;
					
					GetClientAbsOrigin(x, target_pos_CapInf);
					dist = GetVectorDistance(self_pos, target_pos_CapInf);
					if (dist < c_fHelp_Range) {
						if (dist < min_dist_CapInf) {
							min_dist_CapInf = dist;
							aCap_Infected = x;
						}
					}
				}
			}
		}
		
		// Find a Smoker who is tongued self
		int aCapSmoker = -1;
		
		if (c_bPrioritize_OwnerSmoker) {
			float min_dist_CapSmo = 100000.0;
			float target_pos_CapSmo[3];
			
			for (int x = 1; x <= MaxClients; ++x) {
				if (isInfected(x)
					&& IsPlayerAlive(x)
					&& HasValidEnt(x, "m_tongueVictim"))
				{
					if (GetEntPropEnt(x, Prop_Send, "m_tongueVictim") == client) {
						float dist;
						
						GetClientAbsOrigin(x, target_pos_CapSmo);
						dist = GetVectorDistance(self_pos, target_pos_CapSmo);
						if (dist < 750.0) {
							if (dist < min_dist_CapSmo) {
								min_dist_CapSmo = dist;
								aCapSmoker = x;
							}
						}
					}
				}
			}
		}
		
		// Find a flying Jockey
		int aHunterJockey = -1;
		float hunjoc_pos[3];
		float min_dist_HunJoc = 100000.0;
		
		if (c_bBash_Enabled && !NeedsTeammateHelp_ExceptSmoker(client)) {
			for (int x = 1; x <= MaxClients; ++x) {
				if (isInfected(x)
					&& IsPlayerAlive(x)
					&& !isStagger(x)
					&& isVisibleTo(client, x))
				{
					if (getZombieClass(x) == ZC_JOCKEY) {
						float jockeyVelocity[3];
						GetEntDataVector(x, g_Velo, jockeyVelocity);
						if (jockeyVelocity[2] != 0.0) {
							GetClientAbsOrigin(x, hunjoc_pos);

							float jocdist;
							jocdist = GetVectorDistance(self_pos, hunjoc_pos);

							if (jocdist < c_fBash_JockeyRange) { // 125.0 best
								if (jocdist < min_dist_HunJoc) {
									min_dist_HunJoc = jocdist;
									aHunterJockey = x;
								}
							}
						}
					}
				}
			}
		}
		
		// Find a Common Infected
		int aCommonInfected = -1;
		float min_dist_CI = 100000.0;
		float ci_pos[3];
		
		if (c_bCI_Enabled && !NeedsTeammateHelp(client)) {
			for (int iEntity = MaxClients+1; iEntity <= MAXENTITIES; ++iEntity) {
				if (IsCommonInfected(iEntity)
					&& GetEntProp(iEntity, Prop_Data, "m_iHealth") > 0
					&& isVisibleToEntity(iEntity, client))
				{
					float dist;
					GetEntPropVector(iEntity, Prop_Data, "m_vecAbsOrigin", ci_pos);
					dist = GetVectorDistance(self_pos, ci_pos);
					
					if (dist < c_fCI_Range) {
						int iSeq = GetEntProp(iEntity, Prop_Send, "m_nSequence", 2);
						// Stagger			122, 123, 126, 127, 128, 133, 134
						// Down Stagger		128, 129, 130, 131
						// Object Climb (Very Low)	182, 183, 184, 185
						// Object Climb (Low)	190, 191, 192, 193, 194, 195, 196, 197, 198, 199
						// Object Climb (High)	206, 207, 208, 209, 210, 211, 218, 219, 220, 221, 222, 223
						
						if ((iSeq <= 121) || (iSeq >= 135 && iSeq <= 189) || (iSeq >= 200 && iSeq <= 205) || (iSeq >= 224)) {
							if (dist < min_dist_CI) {
								min_dist_CI = dist;
								aCommonInfected = iEntity;
							}
						}
					}
				}
			}
		}

		// Fina a rage Witch
		int aWitch = -1;
		float min_dist_Witch = 100000.0;
		float witch_pos[3];
		if (g_bWitchActive && c_bWitch_Enabled && !NeedsTeammateHelp(client)) {
			for (int iEntity = MaxClients+1; iEntity <= MAXENTITIES; ++iEntity)
			{
				if (IsWitch(iEntity)
					&& GetEntProp(iEntity, Prop_Data, "m_iHealth") > 0
					&& IsWitchRage(iEntity)
					&& isVisibleToEntity(iEntity, client))
				{
					float witch_dist;
					GetEntPropVector(iEntity, Prop_Data, "m_vecAbsOrigin", witch_pos);
					witch_dist = GetVectorDistance(self_pos, witch_pos);
					
					if ((g_iWitch_Process[iEntity] == 0 && witch_dist < c_fWitch_Range)
						|| (g_iWitch_Process[iEntity] == WITCH_INCAPACITATED && witch_dist < c_fWitch_Range_Incapacitated)
						|| (g_iWitch_Process[iEntity] == WITCH_KILLED && witch_dist < c_fWitch_Range_Killed)) {
						if (witch_dist < min_dist_Witch) {
							min_dist_Witch = witch_dist;
							aWitch = iEntity;
						}
					}
				}
			}
		}
		
		// Find a tank rock
		int aTankRock = -1;
		float rock_min_dist = 100000.0;
		float rock_pos[3];
		if (c_bRock_Enabled && !NeedsTeammateHelp(client)) {
			for (int iEntity = MaxClients+1; iEntity <= MAXENTITIES; ++iEntity)
			{
				if (IsTankRock(iEntity)
					&& isVisibleToEntity(iEntity, client))
				{
					float rock_dist;
					GetEntPropVector(iEntity, Prop_Data, "m_vecAbsOrigin", rock_pos);
					rock_dist = GetVectorDistance(self_pos, rock_pos);
					
					if (rock_dist < c_fRock_Range) {
						if (rock_dist < rock_min_dist) {
							rock_min_dist = rock_dist;
							aTankRock = iEntity;
						}
					}
				}
			}
		}
		
		/* ====================================================================================================
		*
		*   優先度A : Bash | flying Jockey
		*
		==================================================================================================== */ 
		if (aHunterJockey > 0) {
			
			float c_pos[3], e_pos[3];
			float lookat[3];
			
			GetClientAbsOrigin(client, c_pos);
			GetClientAbsOrigin(aHunterJockey, e_pos);
			e_pos[2] += -10.0;
			
			MakeVectorFromPoints(c_pos, e_pos, lookat);
			GetVectorAngles(lookat, angles);
			
			TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
			buttons |= IN_ATTACK2;

			return Plugin_Changed;
		}
		
		
		/* ====================================================================================================
		*
		*   優先度B : Self Smoker | aCapSmoker
		*
		==================================================================================================== */ 
		if (aCapSmoker > 0) { // Shoot even if client invisible the smoker
			
			float c_pos[3], e_pos[3];
			float lookat[3];
			
			GetClientAbsOrigin(client, c_pos);
			GetEntPropVector(aCapSmoker, Prop_Data, "m_vecOrigin", e_pos);
			e_pos[2] += 5.0;
			
			MakeVectorFromPoints(c_pos, e_pos, lookat);
			GetVectorAngles(lookat, angles);

			TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
			
 			float aimdist = GetVectorDistance(c_pos, e_pos);
			
			if (aimdist < 80.0){
				buttons |= IN_ATTACK2;
				return Plugin_Changed;
			}
			
			buttons |= IN_ATTACK;
			
			return Plugin_Changed;
		}
		
		/* ====================================================================================================
		*
		*  優先度C : Help | aCap_Infected, aCap_Survivor
		*
		==================================================================================================== */ 

		if (aCap_Infected > 0 && aCap_Survivor < 1) {			
			int zombieClass = getZombieClass(aCap_Infected);
			
			float c_pos[3], e_pos[3];
			float lookat[3];
			
			GetClientEyePosition(client, c_pos);
			
			if (aCapSmoker > 0) { // Prioritize aCapSmoker
				GetClientEyePosition(aCapSmoker, e_pos);
				e_pos[2] += -10.0;
			} else {
				GetClientEyePosition(aCap_Infected, e_pos);
				
				if (zombieClass == ZC_SMOKER || zombieClass == ZC_CHARGER) e_pos[2] += -9.0;
				else if (zombieClass == ZC_HUNTER) e_pos[2] += -14.0;
			}
			
			float aimdist = GetVectorDistance(c_pos, e_pos);
			
			if (zombieClass == ZC_CHARGER && aimdist < 300.0) e_pos[2] += 10.0;
			
			MakeVectorFromPoints(c_pos, e_pos, lookat);
			GetVectorAngles(lookat, angles);
			
			/****************************************************************************************************/
			
			if ((!isHaveItem(AW_Classname, "weapon_melee")) || (isHaveItem(AW_Classname, "weapon_melee") && aimdist < 110.0)) {
				TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);

				buttons |= IN_ATTACK;			
				return Plugin_Changed;
			}
		}
		else if (aCap_Survivor > 0) { // Pass if the client and target are "visible" to each other. so aCap Smoker doesn't pass
			
			float c_pos[3], e_pos[3];
			float lookat[3];
			
			GetClientEyePosition(client, c_pos);
			GetClientEyePosition(aCap_Survivor, e_pos);
			
			if (HasValidEnt(aCap_Survivor, "m_pounceAttacker")) e_pos[2] += 5.0;
			else if (aCapSmoker > 0) { // 引っ張っているSmoker
				GetClientEyePosition(aCapSmoker, e_pos);
				e_pos[2] += -10.0;
			}
			
			float aimdist = GetVectorDistance(c_pos, e_pos);
			
			MakeVectorFromPoints(c_pos, e_pos, lookat);
			GetVectorAngles(lookat, angles);
			
			/****************************************************************************************************/
			
			if ((!isHaveItem(AW_Classname, "weapon_melee")) || (isHaveItem(AW_Classname, "weapon_melee") && aimdist < 110.0)) {
				TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
				
				buttons |= IN_ATTACK;
				return Plugin_Changed;
			}
		}
		

		/* ====================================================================================================
		*
		*   優先度D : Tank Rock, Witch
		*
		==================================================================================================== */ 
		if (aTankRock > 1 && !HasValidEnt(client, "m_reviveTarget")) {
			float c_pos[3], rock_e_pos[3];
			float lookat[3];
			
			GetClientAbsOrigin(client, c_pos);
			GetEntPropVector(aTankRock, Prop_Data, "m_vecAbsOrigin", rock_e_pos);
			rock_e_pos[2] += -50.0;
			
			MakeVectorFromPoints(c_pos, rock_e_pos, lookat);
			GetVectorAngles(lookat, angles);
			
			float aimdist = GetVectorDistance(c_pos, rock_e_pos);
			
			if (aimdist > 40.0 && !isHaveItem(AW_Classname, "weapon_melee")) { //近接を持っていない場合
				TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
			
				buttons |= IN_ATTACK;
			}

			return Plugin_Changed;
		}
		
		if (aWitch > 1) {
			float c_pos[3], witch_e_pos[3];
			float lookat[3];
			
			GetClientEyePosition(client, c_pos);
			GetEntPropVector(aWitch, Prop_Data, "m_vecAbsOrigin", witch_e_pos);
			witch_e_pos[2] += 40.0;
			
			MakeVectorFromPoints(c_pos, witch_e_pos, lookat);
			GetVectorAngles(lookat, angles);
			
			TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);

			buttons |= IN_ATTACK;
			
			return Plugin_Changed;
		}
		
		
		
		/* ====================================================================================================
		*
		*   優先度E : Common Infected
		*
		==================================================================================================== */ 
		if (aCommonInfected > 0) {
			if (!HasValidEnt(client, "m_reviveTarget") && strcmp(AW_Classname, "first_aid_kit") != 0) {
				// Even if aCommonInfected dies and disappears, the Entity may not disappear for a while.(Bot keeps shooting the place)。 Even with InValidEntity(), true appears...
				// When the entity disappears, m_nNextThinkTick will not advance, so skip that if NextThinkTick has the same value as before.
				
				int iNextThinkTick = GetEntProp(aCommonInfected, Prop_Data, "m_nNextThinkTick");
				
				if (g_Stock_NextThinkTick[client] != iNextThinkTick) // If visible aCommonInfected
				{
					float c_pos[3], common_e_pos[3];
					float lookat[3];
					
					GetClientEyePosition(client, c_pos);
					GetEntPropVector(aCommonInfected, Prop_Data, "m_vecOrigin", common_e_pos);
						
					common_e_pos[2] += 40.0;
					
					float aimdist = GetVectorDistance(c_pos, common_e_pos);
					
					int iSeq = GetEntProp(aCommonInfected, Prop_Send, "m_nSequence", 2);
					// Stagger			122, 123, 126, 127, 128, 133, 134
					// Down Stagger		128, 129, 130, 131
					// Object Climb (Very Low)	182, 183, 184, 185
					// Object Climb (Low)	190, 191, 192, 193, 194, 195, 196, 197, 198, 199
					// Object Climb (High)	206, 207, 208, 209, 210, 211, 218, 219, 220, 221, 222, 223
					if (iSeq >= 182 && iSeq <= 189) common_e_pos[2] += -10.0;
					
					MakeVectorFromPoints(c_pos, common_e_pos, lookat);
					GetVectorAngles(lookat, angles);
					
					/****************************************************************************************************/
					
					g_Stock_NextThinkTick[client] = iNextThinkTick; // Set the current m_nNextThinkTick
					
					if (new_target > 0) {
						if (aimdist <= 90.0) TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
					} else {
						if (isHaveItem(AW_Classname, "weapon_melee")) {
							if (aimdist <= 90.0) TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
						} else {
							TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
						}
					}
					
 					if (new_target < 1 || (new_target > 0 && aimdist <= 90.0)) { // If new_target and common at the same time, prioritize to new_target. Attack only when within 90.0 dist.
						buttons |= IN_ATTACK;
						
						return Plugin_Changed;
					}
				}
				else // Skip if aCommonInfected is not visible
				{
					// PrintToChatAll("stock %i  |  next %i", g_Stock_NextThinkTick[client], iNextThinkTick);
				}
			}
		}
		
		
		
		/* ====================================================================================================
		*
		*   優先度F : Special Infected and Tank (new_target)
		*
		==================================================================================================== */ 
		if (new_target > 0) {
			float c_pos[3], e_pos[3];
			float lookat[3];
			
			GetClientAbsOrigin(client, c_pos);
			
			int zombieClass = getZombieClass(new_target);
			
			if (aCapSmoker > 0) { // Prioritize aCapSmoker
				GetClientAbsOrigin(aCapSmoker, e_pos);
				e_pos[2] += -10.0;
			} else {
				GetClientAbsOrigin(new_target, e_pos);
				if (zombieClass == ZC_HUNTER
					&& (GetClientButtons(new_target) & IN_DUCK)) {
					if (GetVectorDistance(c_pos, e_pos) > 250.0) e_pos[2] += -30.0;
					else e_pos[2] += -35.0;
				} else if (zombieClass == ZC_JOCKEY) {
					e_pos[2] += -30.0;
				} else {
					e_pos[2] += -10.0;
				}
			}
			
			if (zombieClass == ZC_TANK && aTankRock > 0) return Plugin_Continue; // If the Tank and tank rock are visible at the same time, prioritize the tank rock
			
			float aimdist = GetVectorDistance(c_pos, e_pos);
			
			if (aimdist < 200.0) {if (!g_bDanger[client]) g_bDanger[client] = true;}
			
			MakeVectorFromPoints(c_pos, e_pos, lookat);
			GetVectorAngles(lookat, angles);
			
			/****************************************************************************************************/
			
			if (isHaveItem(AW_Classname, "weapon_shotgun_chrome")
				|| isHaveItem(AW_Classname, "weapon_shotgun_spas")
				|| isHaveItem(AW_Classname, "weapon_pumpshotgun")
				|| isHaveItem(AW_Classname, "weapon_autoshotgun")) {
				if (aimdist > 1000.0) return Plugin_Continue;
			}
			
			/****************************************************************************************************/

			if ((zombieClass == ZC_JOCKEY && g_bShove[client][new_target])
				|| zombieClass == ZC_SMOKER
			{
				if (aimdist < 90.0 && !isStagger(new_target)) {
					TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
					buttons |= IN_ATTACK2;

					return Plugin_Changed;
				}
			}
			
			if (!isHaveItem(AW_Classname, "weapon_melee")
				|| (aimdist < 100.0 && isHaveItem(AW_Classname, "weapon_melee")))
			{			
				if ((g_bLagShoot) && (zombieClass == ZC_HUNTER || zombieClass == ZC_JOCKEY)){
					DataPack data;
					CreateDataTimer(lagTime[client], Timer_LagShoot, data);
					data.WriteFloat(e_pos[0]);
					data.WriteFloat(e_pos[1]);
					data.WriteFloat(e_pos[2]);
					data.WriteCell(client);
					data.WriteCell(buttons);
					data.Reset();
				}else{
					TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
					buttons |= IN_ATTACK;
				}
				
				return Plugin_Changed;
			}
		}
	}
	
	return Plugin_Continue;
}

//Original from https://forums.alliedmods.net/showthread.php?t=297789&page=3
public Action Timer_LagShoot(Handle timer, Handle data)
{ 
	float e_pos[3], c_pos[3], lookat[3], angles[3];
	DataPack datapack = view_as<DataPack>(data);
	e_pos[0] = datapack.ReadFloat();
	e_pos[1] = datapack.ReadFloat();
	e_pos[2] = datapack.ReadFloat();
	int client = datapack.ReadCell();
	int buttons = datapack.ReadCell();
	
	GetClientAbsOrigin(client, c_pos);
	MakeVectorFromPoints(c_pos, e_pos, lookat);
	GetVectorAngles(lookat, angles);
	TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
	
	buttons |= IN_ATTACK;
}

/* ================================================================================================
*=
*=		Events
*=
================================================================================================ */
public Action Event_PlayerIncapacitated(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled) return Plugin_Handled;
	
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attackerentid = event.GetInt("attackerentid");
	
	// int type = event.GetInt("type");
	// PrintToChatAll("\x04PlayerIncapacitated");
	// PrintToChatAll("type %i", type);
	
	if (isSurvivor(victim) && IsWitch(attackerentid))
	{
		g_iWitch_Process[attackerentid] = WITCH_INCAPACITATED;
		
		// PrintToChatAll("attackerentid %i attacked %N", attackerentid, victim);
		// int health = event.GetInt("health");
		// int dmg_health = event.GetInt("dmg_health");
		// PrintToChatAll("health: %i, damage: %i", health, dmg_health);
	}
	
	return Plugin_Handled;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled) return Plugin_Handled;
	
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attackerentid = event.GetInt("attackerentid");
	
	// int type = event.GetInt("type");
	// PrintToChatAll("\x04PlayerDeath");
	// PrintToChatAll("type %i", type);
	
	if (isSurvivor(victim) && IsWitch(attackerentid))
	{
		g_iWitch_Process[attackerentid] = WITCH_KILLED;
		
		// PrintToChatAll("attackerentid %i attacked %N", attackerentid, victim);
		// int health = event.GetInt("health");
		// int dmg_health = event.GetInt("dmg_health");
		// PrintToChatAll("health: %i, damage: %i", health, dmg_health);
	}
	
	// Witch Damage type: 4
	// Witch Incapacitated type: 32772
	
	return Plugin_Handled;
}

public Action Event_WitchRage(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("userid"));
	
	if (isSurvivor(attacker)) {
		// CallBotstoWitch(attacker);
		g_bWitchActive = true;
	}	
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!g_bEnabled) return;

	if (!IsValidEntityIndex(entity))
		return;

	if (strcmp(classname, "witch") == 0)
	{
		g_iWitch_Process[entity] = 0;
	}
}

public void OnEntityDestroyed(int entity)
{
	if (!IsValidEntityIndex(entity))
		return;
		
	static char classname[32];
	GetEntityClassname(entity, classname, sizeof(classname));

	if (strcmp(classname, "witch") == 0) {
		if (g_bWitchActive) {
			int iWitch_Count = 0;
			for (int iEntity = MaxClients+1; iEntity <= MAXENTITIES; ++iEntity)
			{
				if (IsWitch(iEntity) && GetEntProp(iEntity, Prop_Data, "m_iHealth") > 0 && IsWitchRage(iEntity))
				{
					iWitch_Count++;
				}
				
				//PrintToChatAll("witch count %d", iWitch_Count);
				
				if (iWitch_Count == 0) {g_bWitchActive = false;}
			}
		}
	}
}

/*
*
*   Bool
*
*/
bool NeedsTeammateHelp(int client)
{
	if (HasValidEnt(client, "m_tongueOwner")
	|| HasValidEnt(client, "m_pounceAttacker")
	|| HasValidEnt(client, "m_jockeyAttacker")
	|| HasValidEnt(client, "m_carryAttacker")
	|| HasValidEnt(client, "m_pummelAttacker"))
	{
		return true;
	}
	
	return false;
}

bool NeedsTeammateHelp_ExceptSmoker(int client)
{
	if (HasValidEnt(client, "m_pounceAttacker")
	|| HasValidEnt(client, "m_jockeyAttacker")
	|| HasValidEnt(client, "m_carryAttacker")
	|| HasValidEnt(client, "m_pummelAttacker"))
	{
		return true;
	}
	
	return false;
}

bool CappingSuvivor(int client)
{
	if (HasValidEnt(client, "m_tongueVictim")
	|| HasValidEnt(client, "m_pounceVictim")
	|| HasValidEnt(client, "m_jockeyVictim")
	|| HasValidEnt(client, "m_carryVictim")
	|| HasValidEnt(client, "m_pummelVictim"))
	{
		return true;
	}
	
	return false;
}

bool HasValidEnt(int client, const char[] entprop)
{
	int ent = GetEntPropEnt(client, Prop_Send, entprop);
	
	return (ent > 0
		&& IsClientInGame(ent));
}

bool IsWitchRage(int id) {
	if (GetEntPropFloat(id, Prop_Send, "m_rage") >= 1.0) return true;
	return false;
}

bool IsCommonInfected(int iEntity)
{
	if (iEntity && IsValidEntity(iEntity))
	{
		static char strClassName[16];
		GetEntityClassname(iEntity, strClassName, sizeof(strClassName));
		
		if (strcmp(strClassName, "infected") == 0)
			return true;
	}
	return false;
}

bool IsWitch(int iEntity)
{
	if (iEntity && IsValidEntity(iEntity))
	{
		static char strClassName[8];
		GetEntityClassname(iEntity, strClassName, sizeof(strClassName));
		if (strcmp(strClassName, "witch") == 0)
			return true;
	}
	return false;
}

bool IsTankRock(int iEntity)
{
	if (iEntity && IsValidEntity(iEntity))
	{
		static char strClassName[16];
		GetEntityClassname(iEntity, strClassName, sizeof(strClassName));
		if (strcmp(strClassName, "tank_rock") == 0)
			return true;
	}
	return false;
}

bool isGhost(int i)
{
	return view_as<bool>(GetEntProp(i, Prop_Send, "m_isGhost"));
}

stock bool isSpecialInfectedBot(int i)
{
	return i > 0 && i <= MaxClients && IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 3;
}

bool isNotSurvivorBot(int i)
{
	return isSurvivor(i) && !IsFakeClient(i);
}

bool isInfected(int i)
{
	return i > 0 && i <= MaxClients && IsClientInGame(i) && GetClientTeam(i) == 3 && !isGhost(i);
}

bool isSurvivor(int i)
{
	return i > 0 && i <= MaxClients && IsClientInGame(i) && GetClientTeam(i) == 2;
}

int getZombieClass(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

bool isIncapacitated(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) == 1;
}

bool isStagger(int client) // Client Only
{
	float staggerPos[3];
	GetEntPropVector(client, Prop_Send, "m_staggerStart", staggerPos);
	
	if (staggerPos[0] != 0.0 || staggerPos[1] != 0.0 || staggerPos[2] != 0.0) return true;
	
	return false;
}

stock bool isJockeyLeaping(int client)
{
	float jockeyVelocity[3];
	GetEntDataVector(client, g_Velo, jockeyVelocity);
	if (jockeyVelocity[2] != 0.0) return true;
	return false;
}

bool isHaveItem(const char[] FItem, const char[] SItem)
{
	if (strcmp(FItem, SItem) == 0) return true;
	
	return false;
}

/* -------------------------------------------------------------------------------------------------------------------------------------------------------------- 

--------------------------------------------------------------------------------------------------------------------------------------------------------------------- */

public bool traceFilter(int entity, int mask, any self)
{
	return entity != self;
}

public bool TraceRayDontHitPlayers(int entity, int mask)
{
	// Check if the beam hit a player and tell it to keep tracing if it did
	return (entity <= 0 || entity > MaxClients);
}

// Determine if the head of the target can be seen from the client
bool isVisibleTo(int client, int target)
{
	bool ret = false;
	float aim_angles[3];
	float self_pos[3];
	
	GetClientEyePosition(client, self_pos);
	computeAimAngles(client, target, aim_angles);
	
	Handle trace = TR_TraceRayFilterEx(self_pos, aim_angles, MASK_VISIBLE, RayType_Infinite, traceFilter, client);
	if (TR_DidHit(trace)) {
		int hit = TR_GetEntityIndex(trace);
		if (hit == target) {
			ret = true;
		}
	}
	delete trace;
	return ret;
}

/* Determine if the head of the entity can be seen from the client */
bool isVisibleToEntity(int target, int client)
{
	bool ret = false;
	float aim_angles[3];
	float self_pos[3], target_pos[3];
	float lookat[3];
	
	GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", target_pos);
	GetClientEyePosition(client, self_pos);
	
	MakeVectorFromPoints(target_pos, self_pos, lookat);
	GetVectorAngles(lookat, aim_angles);
	
	Handle trace = TR_TraceRayFilterEx(target_pos, aim_angles, MASK_VISIBLE, RayType_Infinite, traceFilter, target);
	if (TR_DidHit(trace)) {
		int hit = TR_GetEntityIndex(trace);
		if (hit == client) {
			ret = true;
		}
	}
	delete trace;
	return ret;
}

/* From the client to the target's head, whether it is blocked by mesh */
stock bool isInterruptTo(int client, int target)
{
	bool ret = false;
	float aim_angles[3];
	float self_pos[3];
	
	GetClientEyePosition(client, self_pos);
	computeAimAngles(client, target, aim_angles);
	Handle trace = TR_TraceRayFilterEx(self_pos, aim_angles, MASK_SOLID, RayType_Infinite, traceFilter, client);
	if (TR_DidHit(trace)) {
		int hit = TR_GetEntityIndex(trace);
		if (hit == target) {
			ret = true;
		}
	}
	delete trace;
	return ret;
}

// Calculate the angles from client to target
void computeAimAngles(int client, int target, float angles[3], int type = 1)
{
	float target_pos[3];
	float self_pos[3];
	float lookat[3];
	
	GetClientEyePosition(client, self_pos);
	switch (type) {
		case 1: { // Eye (Default)
			GetClientEyePosition(target, target_pos);
		}
		case 2: { // Body
			GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", target_pos);
		}
		case 3: { // Chest
			GetClientAbsOrigin(target, target_pos);
			target_pos[2] += 45.0;
		}
	}
	MakeVectorFromPoints(self_pos, target_pos, lookat);
	GetVectorAngles(lookat, angles);
}

bool IsValidEntityIndex(int entity)
{
    return (MaxClients+1 <= entity <= GetMaxEntities());
}

float Clamp(float inc, float low, float high)
{
	return (inc > high) ? high : ((inc < low) ? low : inc);
}
