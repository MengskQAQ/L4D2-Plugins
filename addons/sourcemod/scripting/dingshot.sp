// 关联文件: addons/sourcemod/configs/dingshotsounds.txt
/*===========================================================================
	Change Log:
1.4  (6-Aug-2023)
	- 在菜单中添加了切换开关
    - 修改了事件顺序
	- 添加了默认开关的参数
1.3  (5-May-2022)
	- 更换了cookie的加载逻辑。
	- 无法解决FileExists问题，暂时删除此部分。
	- 添加了调试信息。
1.21 (3-May-2022)
	- 更正了更新日志表达错误。
1.2 (16-Mar-2022)
	- 更正了PrecacheSound使用错误。
1.1 (20-Dec-2021)
	- 添加了新cookie以记录音效开关。
	- 更改了默认音效。
1.0 (10-Dec-2021)
	- 首次发布。

==============================================================================*/

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

#define DINGSHOTSOUNDS_PATH		"configs/dingshotsounds.txt"

ConVar g_cvDefaultSound, g_cvDefaultStatus, g_cvDebug;
char g_sDefaultSound[64];
bool g_bDefaultStatus, g_bDebug;

new bool:gb_ClientDingShot[MAXPLAYERS+1];
new String:g_sDingShotSounds[MAXPLAYERS+1][64];
new Handle:g_hCookieSounds = INVALID_HANDLE;
new Handle:g_hCookieSwitch = INVALID_HANDLE;
new Handle:g_hSoundsKV;

public Plugin:myinfo=
{
	name = "Dingshot",
	author = "Mengsk",
	description = "自定义爆头音效!",
	version = "1.4",
	url = "https://github.com/MengskQAQ/L4D2-Plugins"
}

public OnPluginStart()
{
	//读取DingShotSounds.txt文件
	decl String:sBuffer[128];
	g_hSoundsKV = CreateKeyValues("DingShotSounds");
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), DINGSHOTSOUNDS_PATH);
	if (!FileToKeyValues(g_hSoundsKV, sBuffer))
	{
		SetFailState("加载DingShotSounds.txt失败!");
	}

	//hook事件发生前并指定回调函数
	HookEvent("player_hurt", HeadShotHook, EventHookMode_Post);
	HookEvent("infected_hurt", HeadShotHook, EventHookMode_Post);
	HookEvent("infected_death", HeadShotHook, EventHookMode_Post);

	//创建新参数
	g_cvDefaultSound = CreateConVar("dingshot_default", "level/scoreregular.wav", "默认爆头音效");
	g_cvDefaultSound.AddChangeHook(DingShotDefaultCvarsChange);

	g_cvDefaultStatus = CreateConVar("dingshot_status", "0", "默认音效开关 <0: 关闭, 1: 开启>");
	g_cvDefaultStatus.AddChangeHook(DingShotDefaultCvarsChange);

	g_cvDebug = CreateConVar("dingshot_debug", "0", "调试信息显示 <0: 关闭, 1: 开启>");
	g_cvDebug.AddChangeHook(DingShotDefaultCvarsChange);

	GetConfig();

	//生成cfg文件
	AutoExecConfig(true, "dingshot");

	//设置客户端命令
	RegConsoleCmd("sm_yinxiao", cmdDingShot, "爆头音效开关");
	RegConsoleCmd("sm_yinxiaomenu", cmdDingShotMenu, "爆头音效菜单");
	RegConsoleCmd("sm_yinxiaomeun", cmdDingShotMenu, "爆头音效菜单");

	//创建cookie
	g_hCookieSounds = RegClientCookie("DingShot_choices", "DingShot Sounds Choice", CookieAccess_Public);
	g_hCookieSwitch = RegClientCookie("DingShot_switch", "DingShot Sounds Choice", CookieAccess_Public);
}

public void OnMapStart()
{
	//如果你的音效不是官方音效，请在此处依据样式自行添加
	PrecacheSound("ui/littlereward.wav");
	PrecacheSound("level/bell_normal.wav");
}

public void OnClientConnected(client)
{
	//爆头音效开关默认值
	gb_ClientDingShot[client] = g_bDefaultStatus;

	//爆头音效默认值
	g_sDingShotSounds[client] = g_sDefaultSound;

	//检测客户端cookie是否加载
	if(AreClientCookiesCached(client)){
		LoadPreferences(client);
	}
}

public OnClientCookiesCached(client)
{
	//排除机器人
	if (IsFakeClient(client))	return;

	//检测客户端cookie是否加载
	if (AreClientCookiesCached(client)){
		LoadPreferences(client);
    }
}

//加载客户端cookie
void LoadPreferences(client)
{
	//获取客户端cookie
	char sCookie[64];
	char sSwitch[64];
	GetClientCookie(client, g_hCookieSounds, sCookie, sizeof(sCookie));
	GetClientCookie(client, g_hCookieSwitch, sSwitch, sizeof(sSwitch));

	//如果客户端cookie不为空使用客户端音效，为空使用默认音效
	if(sCookie[0] != '\0' ){
		g_sDingShotSounds[client] = sCookie;
	}

	if(sSwitch[0] != '\0'){
		if(StringToInt(sSwitch)){
			gb_ClientDingShot[client] = true;
		}else{
			gb_ClientDingShot[client] = false;
		}
	}

	PrintDebug("[DingShot_LoadCookie] client:%N  Path: %s  Switch:%d", client, g_sDingShotSounds[client], gb_ClientDingShot[client]);
}

//如果在游戏中改变默认参数，执行该函数
public DingShotDefaultCvarsChange(ConVar convar, char[] oldValue, char[] newValue)
{
	GetConfig();

	//刷新客户端音效
	for(int i = 1; i <= MaxClients; i++){
		if(IsClientInGame(i))
		LoadPreferences(i);
	}
}

//获取新参数
void GetConfig()
{
	GetConVarString(g_cvDefaultSound, g_sDefaultSound, sizeof(g_sDefaultSound));
	g_bDefaultStatus = GetConVarBool(g_cvDefaultStatus);
	g_bDebug = GetConVarBool(g_cvDebug);
}

//音效菜单命令
public Action cmdDingShotMenu(int client, int argc)
{
	if (!client)	 return Plugin_Handled;
	DingShotMenu(client);
	return Plugin_Handled;
}

//音效菜单
DingShotMenu(client)
{
	new Handle:hMenu = CreateMenu(DingShotMenuHandler);
	SetMenuTitle(hMenu, "选择爆头音效:");
	new String:sPath[64];
	new String:sName[64];

	//在菜单里添加一个开关选项
	FormatEx(sName, sizeof(sName), "是否已开启音效：%s", gb_ClientDingShot[client] ? "☑" : "☐");
	AddMenuItem(hMenu, "status", sName);

	//读取文件，设置选项
	KvRewind(g_hSoundsKV);
	if (KvGotoFirstSubKey(g_hSoundsKV))
	{
		do
		{
			KvGetSectionName(g_hSoundsKV, sPath, sizeof(sPath));
			KvGetString(g_hSoundsKV, "name", sName, sizeof(sName));
			AddMenuItem(hMenu, sPath, sName);
		} while (KvGotoNextKey(g_hSoundsKV));
	}
	DisplayMenu(hMenu, client, 20);
}

public DingShotMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		int client = param1;
		new String:sName[64], String:sPath[64];

		//得到客户端选择的音效，sPath是路劲，sName是音效名
		GetMenuItem(menu, param2, sPath, sizeof(sPath), _, sName, sizeof(sName));
		//为开关选项做一个特殊处理
		if (strcmp(sPath, "status") == 0)
		{
			ToggleStatus(client);
			return 0;
		}

		//设置客户端cookie，并更改音效
		SetClientCookie(client, g_hCookieSounds, sPath);
		g_sDingShotSounds[client] = sPath;
		PrintToChat(client, "[QAQ]cookie已保存");
		PrintDebug("[DingShot_Menu] client:%N  Path: %s  Switch:%d", client, g_sDingShotSounds[client], gb_ClientDingShot[client]);
		//播放已选择的音效
		EmitSoundToClient(client, sPath, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL);
	}
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

//音效开关
public Action cmdDingShot(int client, int args)
{
	if (!client)	 return Plugin_Handled;
	ToggleStatus(client);
	return Plugin_Handled;
}

public HeadShotHook(Handle event, const char[] name, bool dontBroadcast)
{
	//获取event信息
	int hitgroup;
	int attacker = GetEventInt(event, "attacker");
	int type = GetEventInt(event, "type");
	int client = GetClientOfUserId(attacker);

	//判断客户端音效开关
	if(!gb_ClientDingShot[client])	return;

	//获取爆头信息
	if (strcmp(name, "infected_death") == 0) {
		hitgroup = GetEventInt(event, "headshot");
	}else {
		hitgroup = GetEventInt(event, "hitgroup");
	}

	//播放音效
	//Bugs:Tank死亡后，在模型延迟消失时，会频繁触发判定。
	if (IsClientValid(client) && hitgroup == 1 && type != 8) {  // 8 == death by fire...
		PrintDebug("[DingShot_HookEvent] client:%N  Path: %s  Switch:%d", client, g_sDingShotSounds[client], gb_ClientDingShot[client]);
		EmitSoundToClient(client, g_sDingShotSounds[client], SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL);
	}
}

//切换玩家的音效开关
public void ToggleStatus(int client)
{
	gb_ClientDingShot[client] = !gb_ClientDingShot[client];

	if(gb_ClientDingShot[client]){
		SetClientCookie(client, g_hCookieSwitch, "1");
		PrintToChat(client, "[QAQ]爆头音效 开启");
	}else{
		SetClientCookie(client, g_hCookieSwitch, "0");
		PrintToChat(client, "[QAQ]爆头音效 关闭");
	}
  
	PrintDebug("[DingShot_Switch] client:%N  Path: %s  Switch:%d", client, g_sDingShotSounds[client], gb_ClientDingShot[client]);
}

bool IsClientValid(int client) {
	if (client >= 1 && client <= MaxClients) {
		if (IsClientConnected(client)) {
			 if (IsClientInGame(client)) {
				return true;
			 }
		}
	}
	return false;
}

void PrintDebug(const char[] Message, any ...) {
	if (g_bDebug) {
		char DebugBuff[256];
		VFormat(DebugBuff, sizeof(DebugBuff), Message, 2);
		LogMessage(DebugBuff);
	//	PrintToChatAll(DebugBuff);	//单人调试时可取消该行注释
	}
}