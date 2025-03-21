/*========================================================================================
	Plugin Info:

*	Name	:	[L4D2] Look At Weapon Yourself
*	Author	:	Mengsk
*	Descrp	:	Make it possible to look at weapon anywhere in l4d2.
*	Plugins	:	https://www.bilibili.com/read/cv22443300

========================================================================================
	Change Log:
1.4.1 (21-March-2025)
	- 优化代码部分逻辑
1.4 (12-March-2025)
	- 修复开启 AFKCHECK 时的编译错误
1.3.1 (7-Oct-2023)
	- 修复菜单不能正确显示状态的bug
1.3 (7-Oct-2023)
	- 修复运行时后台会提示报错信息的bug
	- 增加新参数 l4d2_lookatweapon_way_sensitive ，开启后移动将会打断检视
	- 增加新参数 l4d2_lookatweapon_way_multishift ，可以指定SHIFT键敲击计数来开关检视，
		该参数优先于 l4d2_lookatweapon_way 参数中的 1 值设定。
1.2 (5-May-2023)
	- 增加了对播放静态动画的支持，可通过菜单播放指定动画
	- 增加了新参数 l4d2_lookatweapon_menu ，用于开关静态动画的支持
	- 增加了新编译选项 AFKCHECK ，用于选择是否编译新增的闲置自动触发检视
	- 在开启 AFKCHECK 编译后，增加了新参数 l4d2_lookatweapon_afk ，用于开关新增的闲置自动触发检视

1.1 (12-April-2023)
	- 增加了更多触发检视的按键，现支持4种方式

1.0 (16-March-2023)
	- Initial release.

==========================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define AFKCHECK 1	// 是否编译闲置自动触发检视
#define AFK_DURATION 10.0	// 在开启AFKCHECK的情况下，玩家静止几秒后认定处于闲置状态（浮点数）
#define SENSITIVE_DURATION 2.0 // 在开启 l4d2_lookatweapon_way_sensitive 的情况下，允许检视中保持移动多久

enum
{
	ENUM_KEYSHIFT	= (1 << 0),
	ENUM_COMMAND	= (1 << 1),
	ENUM_KEYF		= (1 << 2),
	ENUM_KEYR		= (1 << 3),
}

// Cvar Handles/Variables
static int iEntRef[MAXPLAYERS+1] = {INVALID_ENT_REFERENCE, ...};
static int iEntOwner[2048+1];
static bool g_bEntityState[MAXPLAYERS+1];
static int IMPULSE_FLASHLIGHT = 100;

#if AFKCHECK
	static float buttonTime[MAXPLAYERS+1];
	Handle AFK_Timer[MAXPLAYERS + 1];
	ConVar g_hCvarAfk;
	bool g_bCvarAfk;
#endif

ConVar g_hCvarAllow, g_hCvarHints, g_hCvarDist, g_hCvarWay, g_hCvarMenu, g_hCvarShiftCount, g_hCvarSensitive;
bool g_bCvarAllow, g_bCvarShiftCount, g_bCvarSensitive;
int g_iCvarHints, g_iCvarDist, g_iCvarWay, g_iCvarMenu, g_iCvarShiftCount;

int g_iLastButton[MAXPLAYERS+1], g_iLastSelect[MAXPLAYERS+1], g_iLastSequence[MAXPLAYERS+1], g_iSHIFTClickCount[MAXPLAYERS+1];
float g_fSHIFTTime[MAXPLAYERS+1],g_fSHIFTTime2[MAXPLAYERS+1],g_fKEYFTime[MAXPLAYERS+1],g_fKEYRTime[MAXPLAYERS+1];
bool g_bSensitiveDelet[MAXPLAYERS+1], g_bIsPlayingAnim[MAXPLAYERS+1];
Handle SHIFTClear_Timer[MAXPLAYERS+1];
Handle Sensitive_Timer[MAXPLAYERS+1];
Handle hTrie_Ammo = INVALID_HANDLE;
Handle hTrie_Sequence = INVALID_HANDLE;


// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================

public Plugin myinfo =
{
	name = "[L4D2] Look At Weapon Yourself",
	author = "Mengsk",
	description = "让你可以主动检视武器",
	version = "1.4.1",
	url = "https://space.bilibili.com/24447721"
}

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
	g_hCvarAllow 		= CreateConVar("l4d2_lookatweapon_allow", "1", "0=Plugin off, 1=Plugin on.");
	g_hCvarHints 		= CreateConVar("l4d2_lookatweapon_hints", "0", "0=No message, 1=Print to chat, 2=Hint box.");
	g_hCvarDist 		= CreateConVar("l4d2_lookatweapon_distance", "30", "Distance the entity forward player.");
	g_hCvarWay 			= CreateConVar("l4d2_lookatweapon_way", "2", "Bitwise: 0=no way, 1=double SHIFT, 2=chat command, 4=double F, 8=double R when full ammo");
	g_hCvarShiftCount 	= CreateConVar("l4d2_lookatweapon_way_multishift", "2", "How much time SHIFT need hit to switch, should greater than 2, 0=close");
	g_hCvarSensitive 	= CreateConVar("l4d2_lookatweapon_way_sensitive", "0", "0=No sensitive, 1=ONLY ONE touch can disable lookatweapon state.");
	g_hCvarMenu 		= CreateConVar("l4d2_lookatweapon_menu", "1", "0=Menu disalbe, 1=Menu enable.");


	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarHints.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDist.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarWay.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarMenu.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarShiftCount.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarSensitive.AddChangeHook(ConVarChanged_Cvars);

#if AFKCHECK
	g_hCvarAfk = CreateConVar("l4d2_lookatweapon_afk", "0", "0=Afk check disalbe, 1=Afk check enable.(AVAILABLE ONLY WHEN AFKCHECK COMPILED)");
	g_hCvarAfk.AddChangeHook(ConVarChanged_Cvars);
#endif

  	// 生成cfg文件
	AutoExecConfig(true, "l4d2_lookatweapon");

	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_team", Event_TeamChange, EventHookMode_Post);
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);

	HookEvent("player_bot_replace", Event_PlayerBotReplace, EventHookMode_Pre);
	HookEvent("jockey_ride", Event_Interrupt, EventHookMode_Pre);
	HookEvent("charger_carry_start", Event_Interrupt, EventHookMode_Pre);
	HookEvent("charger_pummel_start", Event_Interrupt, EventHookMode_Pre);
	HookEvent("tongue_grab", Event_Interrupt, EventHookMode_Pre);
	HookEvent("player_ledge_grab", Event_Interrupt, EventHookMode_Pre);
	HookEvent("lunge_pounce", Event_Interrupt, EventHookMode_Pre);
	HookEvent("player_incapacitated_start", Event_Interrupt, EventHookMode_Pre);

 	hTrie_Ammo = CreateTrie();
	hTrie_Sequence = CreateTrie();

 	// 注册命令，可自行修改名称
 	RegConsoleCmd("sm_lookatweapon", cmdLookAtWeapon, "allow client to toggle LookAtWeapon status");
  	RegConsoleCmd("sm_lookatmenu", cmdLookAtWeaponMenu, "Show menu to set weapon sequence");
}

public void OnPluginEnd()
{
	for( int i = 1; i <= MaxClients; i++ )
		DeleteFakeEntity(i);
}

public void OnMapEnd()
{
	for( int i = 1; i <= MaxClients; i++ )
		DeleteFakeEntity(i);

#if AFKCHECK
	AllClientStopAFKTimer();
#endif
}

public void OnClientConnected(int client)
{
	g_iLastSelect[client] = -1;
	g_iLastSequence[client] = -1;
	g_iSHIFTClickCount[client] = 0;
	ShutdownTimer(SHIFTClear_Timer[client]);
	ShutdownTimer(Sensitive_Timer[client]);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponCanUse, Hook_WeaponCanUse);
	SDKHook(client, SDKHook_WeaponSwitch, Hook_WeaponSwitch);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_WeaponCanUse, Hook_WeaponCanUse);
	SDKUnhook(client, SDKHook_WeaponSwitch, Hook_WeaponSwitch);
	DeleteFakeEntity(client);
}
// ====================================================================================================
//					CVARS
// ====================================================================================================

public void OnConfigsExecuted()
{
	IsAllowed();
}

public void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iCvarHints = g_hCvarHints.IntValue;
	g_iCvarDist = g_hCvarDist.IntValue;
	g_iCvarWay = g_hCvarWay.IntValue;
	g_iCvarMenu = g_hCvarMenu.IntValue;
	g_iCvarShiftCount = g_hCvarShiftCount.IntValue > 1 ? g_hCvarShiftCount.IntValue - 1 : 1;
	g_bCvarShiftCount = g_hCvarShiftCount.IntValue > 0 ? true : false;
	g_bCvarSensitive = g_hCvarSensitive.BoolValue;

#if AFKCHECK
	g_bCvarAfk = g_hCvarAfk.BoolValue;
	if(g_bCvarAfk)
	{
		AllClientInitAFKTimer();
	}else{
		AllClientStopAFKTimer();
	}
#endif
}

void IsAllowed()
{
	bool bAllowCvar = g_hCvarAllow.BoolValue;
	GetCvars();

	if( g_bCvarAllow == false && bAllowCvar == true)
	{
		g_bCvarAllow = true;
	}
	else if( g_bCvarAllow == true && bAllowCvar == false)
	{
		g_bCvarAllow = false;
		for( int i = 1; i <= MaxClients; i++ )
		{
			DeleteFakeEntity(i);
		}
	}
}

// ====================================================================================================
//					ACTION
// ====================================================================================================

public Action Hook_WeaponCanUse(int client, int weapon)
{
	if(!g_bCvarAllow || GetClientTeam(client) != 2 || !IsValidEntity(weapon))	return Plugin_Continue;
	for (int i = 1; i <= MaxClients; i++) {
		if(IsValidEntRef(iEntRef[i]) && (EntRefToEntIndex(weapon) == EntRefToEntIndex(iEntRef[i])))
			return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action Hook_WeaponSwitch(int client, int weapon)
{
	if(!g_bCvarAllow || !g_iCvarMenu || GetClientTeam(client) != 2 || !IsValidEntity(weapon) || IsFakeClient(client))	return Plugin_Continue;

	char classname[32];
	int weaponid = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	int Sequence = GetEntProp(GetEntPropEnt(client, Prop_Send, "m_hViewModel"), Prop_Send, "m_nSequence");

	if(weaponid == INVALID_ENT_REFERENCE) return Plugin_Continue;
	if(!GetEntityClassname(weaponid, classname, sizeof(classname))) return Plugin_Continue;
	if(hTrie_Sequence == INVALID_HANDLE) hTrie_Sequence = CreateTrie();
	SetTrieValue(hTrie_Sequence, classname, Sequence);

	// PrintToChat(client, "记录武器： %s 动画序列：%d", classname, Sequence);
	return Plugin_Continue;
}

public Action cmdLookAtWeapon(int client, int args)
{
	if (!client || !g_bCvarAllow || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2)	 return Plugin_Handled;
	if (g_iCvarWay & ENUM_COMMAND)	SwitchEntityState(client);
	return Plugin_Handled;
}

public Action cmdLookAtWeaponMenu(int client, int args)
{
	if (!client || !g_bCvarAllow || !g_iCvarMenu || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2)	 return Plugin_Handled;
	char classname[32];
	char text[64];
	char num[64];
	char status[64];
	// int ViewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(!GetEntityClassname(weapon, classname, sizeof(classname))) return Plugin_Handled;

	Menu menu = new Menu(iLookAtWeaponMenuHandler);
	menu.SetTitle(classname);
	FormatEx(status, sizeof(status), "当前检视状态：%s", g_bEntityState[client] ? "☑" : "☐");
	menu.AddItem("w", status);
	menu.AddItem("q", "上次选择");
	for (int i = 1; i <= 35; i++) {
		Format(text, sizeof(text), "动画序列 %d", i-1);
		IntToString(i-1, num, sizeof(num));
		menu.AddItem(num, text);
	}

	menu.ExitBackButton = true;
	menu.Display(client, 20);
	return Plugin_Handled;
}

int iLookAtWeaponMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	char classname[32];
	int ViewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(!GetEntityClassname(weapon, classname, sizeof(classname))) return 0;
	switch (action) {
		case MenuAction_Select:
		{
			char sParam[64];
			if(menu.GetItem(param2, sParam, sizeof(sParam)))
			{
				if(strcmp(sParam[0], "q") == 0)
				{
					if(g_iLastSelect[client] < 0){
						PrintToChat(client, "未获取到上次播放的序列", g_iLastSelect[client]);
						return 0;
					}
				}
				else if(strcmp(sParam[0], "w") == 0)
				{
					SwitchEntityState(client);
					return 0;
				}
				else
				{
					g_iLastSelect[client] = StringToInt(sParam);
				}
				if(g_iLastSelect[client] >= 0 && g_iLastSelect[client] <= 35)
				{
					int Sequence = GetEntProp(ViewModel, Prop_Send, "m_nSequence");
					if (Sequence > 4) {
						PrintToChat(client, "正在播放其他动画中");
						return 0;
					}
					g_iLastSequence[client] = Sequence;
					g_bIsPlayingAnim[client] = true;
					SetEntProp(ViewModel, Prop_Send, "m_nSequence", g_iLastSelect[client]);
					PrintToChat(client, "当前播放动画序列：%d", g_iLastSelect[client]);
				}
			}
		}
		case MenuAction_End:
			delete menu;
	}
	return 0;
}

public Action HideModel(int iEntity, int iClient)
{
	static int iOwner;
	iOwner = GetClientOfUserId(iEntOwner[iEntity]);

	if(iOwner < 1 || !IsClientInGame(iOwner))
		return Plugin_Handled;

 	// 仅玩家自身可见，这是为了避免服务器与客户端同步时去反复渲染此实体
	if(iOwner == iClient)
		return Plugin_Continue;

	return Plugin_Handled;
}

public Action Timer_SHIFTClear(Handle Timer, int client)
{
	g_iSHIFTClickCount[client] = 0;
	SHIFTClear_Timer[client] = INVALID_HANDLE;
	return Plugin_Stop;
}

public Action Timer_Sensitive(Handle Timer, int client)
{
	g_bSensitiveDelet[client] = true;
	Sensitive_Timer[client] = INVALID_HANDLE;
	return Plugin_Stop;
}

// ====================================================================================================
//					EVENTS
// ====================================================================================================

public void Event_PlayerDeath(Handle hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if(!g_bCvarAllow || client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2)
		return;

	DeleteFakeEntity(client);
}

public void Event_TeamChange(Handle hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if(!g_bCvarAllow || client < 1 || client > MaxClients || !IsClientInGame(client))
		return;

	DeleteFakeEntity(client);

#if AFKCHECK
	if (g_bCvarAfk && !IsFakeClient(client))
	{
   		int team = GetEventInt(hEvent, "team");
		if (team == 2){	// 仅生还
			InitAFKTimer(client);
		}else{
			StopAFKTimer(client);
		}
	}
#endif
}

public void TP_OnThirdPersonChanged(int client, bool bIsThirdPerson)
{
	if(g_bCvarAllow && client)
		DeleteFakeEntity(client);
}

public void Event_RoundStart(Handle hEvent, const char[] sEventName, bool bDontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++)
		DeleteFakeEntity(i);
}

public void Event_Interrupt(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, name));

	if(g_bCvarAllow)
		DeleteFakeEntity(client);
}

public void Event_PlayerBotReplace(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "player"));
	int bot = GetClientOfUserId(GetEventInt(event, "bot"));

	if(g_bCvarAllow){
		DeleteFakeEntity(client);
		DeleteFakeEntity(bot);
	}
}

// ====================================================================================================
//					DYNAMIC ENTITY ON/OFF
// ====================================================================================================

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if( g_bCvarAllow && IsClientInGame(client) && !IsFakeClient(client))
	{
		int ref = iEntRef[client];

#if AFKCHECK
		static int iLastMouse[MAXPLAYERS+1][2];
		if(g_bCvarAfk)
		{
			if (mouse[0] != iLastMouse[client][0] || mouse[1] != iLastMouse[client][1])
			{
				iLastMouse[client][0] = mouse[0];
				iLastMouse[client][1] = mouse[1];
				SetButtonTime(client);
			}
			else if (buttons || impulse) SetButtonTime(client);
		}
#endif

		if (g_iCvarMenu && g_bIsPlayingAnim[client])
		{
			int ViewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
			if( buttons & (IN_ATTACK | IN_RELOAD | IN_ATTACK2 | IN_USE) ){
				SetEntProp(ViewModel, Prop_Send, "m_nSequence", GetOriginalSequence(client));
				g_bIsPlayingAnim[client] = false;
			}
		}

		if ((buttons & IN_ATTACK) == IN_ATTACK)
		{
			DeleteFakeEntity(client);
			buttons |= IN_ATTACK;
			return Plugin_Continue;
		}

		if (GetClientTeam(client) != 2 || !IsPlayerAlive(client) || (buttons & (IN_USE | IN_ATTACK2)))
		{
			DeleteFakeEntity(client);
			return Plugin_Continue;
		}

		if(g_bCvarSensitive)
		{
			if(g_bEntityState[client] && (buttons & (IN_FORWARD | IN_BACK | IN_LEFT | IN_RIGHT | IN_JUMP | IN_DUCK)))
			{
				if(Sensitive_Timer[client] == INVALID_HANDLE)
				{
					Sensitive_Timer[client] = CreateTimer(SENSITIVE_DURATION, Timer_Sensitive, client);
				}

				if(g_bSensitiveDelet[client])
				{
					g_bSensitiveDelet[client] = false;
					DeleteFakeEntity(client);
				}

				return Plugin_Continue;
			}
		}

		if((!g_bCvarShiftCount) && (g_iCvarWay & ENUM_KEYSHIFT))
		{
			int iButton = IN_SPEED;
			if ((buttons & iButton) && !(g_iLastButton[client] & iButton))	// 摁下时触发
			{
				float time = GetGameTime();
				if(time - g_fSHIFTTime[client] <= 0.5) SwitchEntityState(client);
				g_fSHIFTTime[client] = time;
			}
			// if ((g_iLastButton[client] & iButton) && !(buttons & iButton)){}	//松开时触发
		}

		if(g_iCvarWay & ENUM_KEYR)
		{
			int iButton2 = IN_RELOAD;
			if ((buttons & iButton2) && !(g_iLastButton[client] & iButton2))
			{
				if(IsActiveWeaponFullAmmo(client)){
					float time = GetGameTime();
					if(time - g_fKEYRTime[client] <= 0.5) SwitchEntityState(client);
					g_fKEYRTime[client] = time;
				}
			}
			// if ((g_iLastButton[client] & iButton2) && !(buttons & iButton2)){}	//松开时触发
		}

		if(g_bCvarShiftCount)
		{
			int iButton3 = IN_SPEED;
			if ((buttons & iButton3) && !(g_iLastButton[client] & iButton3))	// 摁下时触发
			{
				float time = GetGameTime();
				if(time - g_fSHIFTTime2[client] <= 0.3)	SHIFTClickCount(client); // 多击SHIFT时，每次敲击间隔限定0.3s
				g_fSHIFTTime2[client] = time;
			}
			// if ((g_iLastButton[client] & iButton3) && !(buttons & iButton3)){}	//松开时触发
		}

		g_iLastButton[client] = buttons;

		if(g_iCvarWay & ENUM_KEYF)
		{
			if(impulse == IMPULSE_FLASHLIGHT)
			{
				float time = GetGameTime();
				if(time - g_fKEYFTime[client] <= 0.5) SwitchEntityState(client);
				g_fKEYFTime[client] = time;
			}
		}

		if(IsValidEntRef(ref)){
			TeleportDynamicLight(client, EntRefToEntIndex(ref));
		}
	}

	return Plugin_Continue;
}

void DeleteFakeEntity(int client)
{
	g_bEntityState[client] = false;	// 泄露就泄露吧

	if(IsValidEntRef(iEntRef[client]))
	{
		DisplayHint(client, false);
		AcceptEntityInput(EntRefToEntIndex(iEntRef[client]), "kill");
	}

	iEntRef[client] = INVALID_ENT_REFERENCE;
}

void CreatFakeEntity(int client)
{
	// if(IsLimited(client)) return; // 非安全状态下无法开启检视，避免未知bug

	g_bEntityState[client] = true;

	int iEntity;

	if(IsValidEntRef(iEntRef[client]))
		return;

	iEntity = CreateEntityByName("weapon_propanetank");
  // 起初我想通过prop_dynamic_override实现，
  // 但无论如何没有实体的物体没办法触发检视，
  // 而Prop_physics_override又与本文的方法无本质差异，
  // 所以最后选择了煤气罐，
  // 因为是圆柱性，可以省去实体旋转的步骤，减少计算量。

	if(iEntity < 0)
		return;
	DisplayHint(client, true);

	DispatchKeyValue(iEntity, "solid", "0");	// 取消碰撞模式
	DispatchKeyValue(iEntity, "disableshadows", "1"); // 关闭阴影

	// 消除光圈
	SetEntProp(iEntity, Prop_Send, "m_iGlowType", 3);
	SetEntProp(iEntity, Prop_Send, "m_glowColorOverride", 1);
	SetEntProp(iEntity, Prop_Send, "m_nGlowRange", 0);

   // 设置碰撞组，仅与世界碰撞
	SetEntProp(iEntity, Prop_Send, "m_CollisionGroup", 1);
	SetEntProp(iEntity, Prop_Send, "m_nSolidType", 1);

	// 模型透明
	SetEntityRenderMode(iEntity, RENDER_NONE);
	SetEntityRenderColor(iEntity, 100, 100, 100, 100);

   // 生成并激活实体
	DispatchSpawn(iEntity);
	ActivateEntity(iEntity);

	// 固定模型
	SetEntityMoveType(iEntity, MOVETYPE_NONE);

	iEntRef[client] = EntIndexToEntRef(iEntity);
	iEntOwner[iEntity] = GetClientUserId(client);

	// 规避所有碰撞
	SDKHook(iEntity, SDKHook_ShouldCollide, ShouldCollide);

	// 模型对其他人不可见
	SDKHook(iEntity, SDKHook_SetTransmit, HideModel);
}

public bool ShouldCollide(int entity, int collisiongroup, int contentsmask, bool originalResult)
{
	return false;
}

void TeleportDynamicLight(int client, int entity)
{
	if (!IsValidEntity(entity))
		return;
	
	float vLoc[3], vPos[3], vAng[3];

	GetClientEyeAngles(client, vAng);
	GetClientEyePosition(client, vLoc);

	Handle trace;
	trace = TR_TraceRayFilterEx(vLoc, vAng, MASK_SHOT, RayType_Infinite, TraceFilter, client);

	if( TR_DidHit(trace) )
	{
		TR_GetEndPosition(vPos, trace);
		float fDist = GetVectorDistance(vLoc, vPos);

		if( fDist >= g_iCvarDist )
		{
			GetAngleVectors(vAng, vAng, NULL_VECTOR, NULL_VECTOR);
			vPos[0] = vLoc[0] + (vAng[0] * g_iCvarDist);
			vPos[1] = vLoc[1] + (vAng[1] * g_iCvarDist);
			vPos[2] = vLoc[2] + (vAng[2] * g_iCvarDist);
			TeleportEntity(entity, vPos, view_as<float>({-89.0, 0.0, 0.0}), NULL_VECTOR);
        // 把实体旋转89度后，在相同距离下，实际的体验效果会大大增加
		}
		else
		{
			TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		}
	}

	delete trace;
}

// ====================================================================================================
//					OTHERS
// ====================================================================================================

void DisplayHint(int client, bool type)
{
	switch ( g_iCvarHints )
	{
		case 1:		// Print To Chat
		{
			if(type)	PrintToChat(client, "[LookAtWeapon] On");
			if(!type)	PrintToChat(client, "[LookAtWeapon] Off");
		}
		case 2:		// Print Hint Text
		{
			if(type)	PrintHintText(client, "[LookAtWeapon] On");
			if(!type)	PrintHintText(client, "[LookAtWeapon] Off");
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if(StrContains(classname, "weapon_", false) != -1) SDKHookEx(entity, SDKHook_SpawnPost, StoreMaxClip1);
}

public void StoreMaxClip1(int entity)
{
    if(hTrie_Ammo == INVALID_HANDLE) hTrie_Ammo = CreateTrie();
    if(entity <= MaxClients || !IsValidEntity(entity) || FindDataMapInfo(entity, "m_iClip1") == -1) return;

    char classname[30];
    if(!GetEntityClassname(entity, classname, sizeof(classname))) return;

    SetTrieValue(hTrie_Ammo, classname, GetEntProp(entity, Prop_Send, "m_iClip1"));
}

public void SHIFTClickCount(int client)
{
	g_iSHIFTClickCount[client]++;   // 计数+1

	if(g_iSHIFTClickCount[client] >= g_iCvarShiftCount)  // 计数达到预设值
	{
		SwitchEntityState(client);
		g_iSHIFTClickCount[client] = 0;
	}

	ShutdownTimer(SHIFTClear_Timer[client]);
	SHIFTClear_Timer[client] = CreateTimer(1.0, Timer_SHIFTClear, client);
}

void SwitchEntityState(int client)
{
	if(g_bEntityState[client]){
		DeleteFakeEntity(client);
	} else {
		CreatFakeEntity(client);

		if(g_bCvarSensitive)
		{
			ShutdownTimer(Sensitive_Timer[client]);
			Sensitive_Timer[client] = CreateTimer(SENSITIVE_DURATION, Timer_Sensitive, client);
		}
	}
}

int GetOriginalSequence(int client)
{
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	int sequence = -1;
	char classname[32];
	if(IsValidEntity(weapon) && IsValidEdict(weapon) && GetEntityClassname(weapon, classname, sizeof(classname)))
	{
		if(GetTrieValue(hTrie_Sequence, classname, sequence)) {
			// PrintToChat(client, "GetOriginalSequence: 得到表数据 %d", sequence);
			return sequence;
		}
	}
	// PrintToChat(client, "GetOriginalSequence: 得到上次记录 %d", g_iLastSequence[client]);
	return g_iLastSequence[client];
}

static bool IsValidEntRef(int iRef)
{
	return (iRef != INVALID_ENT_REFERENCE && EntRefToEntIndex(iRef) != -1);
}

public bool TraceFilter(int entity, int contentsMask, any client)
{
	if( entity == client )
		return false;
	return true;
	// return (entity != client)
}

bool IsActiveWeaponFullAmmo(int client)
{
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	int maxclip1 = -1;
	char classname[32];
	if (IsValidEntity(weapon) && IsValidEdict(weapon) && HasEntProp(weapon, Prop_Data, "m_iClip1"))
	{
		if(!GetEntityClassname(weapon, classname, sizeof(classname))) return false;
		if(!GetTrieValue(hTrie_Ammo, classname, maxclip1)) return false;
		return (GetEntProp(weapon, Prop_Send, "m_iClip1") >= maxclip1);
	}
	return false;
}

void ShutdownTimer(Handle& timer)
{
	if(timer != INVALID_HANDLE){
		KillTimer(timer);
		timer = INVALID_HANDLE;
	}
}

/*
bool IsLimited(int client)
{
	return (GetEntPropEnt(client, Prop_Send, "m_tongueVictim") > 0) // Smoker
		|| (GetEntPropEnt(client, Prop_Send, "m_pounceVictim") > 0) // Hunter
		|| (GetEntPropEnt(client, Prop_Send, "m_jockeyVictim") > 0) // Jockey
		|| (GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0) // Charger
		|| (GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0) // Charger
		|| (GetEntProp(client, Prop_Send, "m_isHangingFromLedge") != 0 || GetEntProp(client, Prop_Send, "m_isFallingFromLedge") != 0) // 挂边
		|| (GetEntityMoveType(client) == MOVETYPE_LADDER) // 爬梯
		|| (GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) == 1); // 倒地
}
*/

#if AFKCHECK
	public void AllClientInitAFKTimer()
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && GetClientTeam(i) == 2 && !IsFakeClient(i))
				InitAFKTimer(i);
		}
	}

	public void AllClientStopAFKTimer()
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			StopAFKTimer(i);
		}
	}

	public void InitAFKTimer(int client)
	{
		if(AFK_Timer[client] != INVALID_HANDLE){
			KillTimer(AFK_Timer[client]);
			AFK_Timer[client] = INVALID_HANDLE;
		}
		SetButtonTime(client);
		AFK_Timer[client] = CreateTimer(1.0, Timer_AFK, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}

	public void StopAFKTimer(int client)
	{
		if(AFK_Timer[client] != INVALID_HANDLE){
			KillTimer(AFK_Timer[client]);
			AFK_Timer[client] = INVALID_HANDLE;
		}

		DeleteFakeEntity(client);
	}

	public Action Timer_AFK(Handle Timer, int client)
	{
		if (IsPlayerAfk(client)) {
			if (!g_bEntityState[client])
			{
				CreatFakeEntity(client);
			}
		} else if (!g_bCvarSensitive) {	// 仅当另一个检测没有生效时，才会退出检视
			if (g_bEntityState[client])
			{
				DeleteFakeEntity(client);
			}
		}
		return Plugin_Continue;
	}

	void SetButtonTime(int client)
	{
		buttonTime[client] = GetEngineTime();
	}

	bool IsPlayerAfk(int client)
	{
		return GetEngineTime() - buttonTime[client] > AFK_DURATION;
	}
#endif
