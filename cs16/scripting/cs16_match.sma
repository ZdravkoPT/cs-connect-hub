// CS16 Platform - no-admin match lifecycle: warmup -> LO3 -> live, surrender, tech timeout, reconnect/forfeit
#include <amxmodx>
#include <cstrike>
#include <cs16_core>

#define PLUGIN  "cs16_match"
#define VERSION "0.1.0"

#define TASK_WARMUP  5200
#define TASK_LO3     5201
#define TASK_FORFEIT 5300

new g_cvWarmup, g_cvReconnect, g_cvBanMins, g_cvTechTime;
new g_warmLeft, g_lo3Step;
new bool:g_gg[33];
new Trie:g_leavers;   // authid -> team
new g_techUsed[3];
new g_oldFreeze;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, "CS16 Platform");
	register_dictionary("cs16.txt");

	g_cvWarmup = register_cvar("cs_warmup_time", "20");
	g_cvReconnect = register_cvar("cs_reconnect_time", "120");
	g_cvBanMins = register_cvar("cs_leaver_ban_minutes", "30");
	g_cvTechTime = register_cvar("cs_tech_timeout", "60");

	new const gg[][] = { "say .gg", "say !gg", "say /gg", "say_team .gg", "say_team !gg", "say_team /gg" };
	for (new i = 0; i < sizeof(gg); i++) register_clcmd(gg[i], "cmd_gg");
	new const tech[][] = { "say .tech", "say !tech", "say /tech", "say_team .tech", "say_team !tech", "say_team /tech" };
	for (new i = 0; i < sizeof(tech); i++) register_clcmd(tech[i], "cmd_tech");

	g_leavers = TrieCreate();
}

public plugin_end() TrieDestroy(g_leavers);

public cs_on_state_change(oldstate, newstate)
{
	if (newstate == MS_WARMUP)
	{
		TrieClear(g_leavers);
		g_techUsed[1] = g_techUsed[2] = 0;
		for (new i = 1; i <= 32; i++) g_gg[i] = false;
		g_warmLeft = get_pcvar_num(g_cvWarmup);
		server_cmd("sv_restart 1");
		cs_msg(0, PFX_MATCH, "%L", LANG_PLAYER, "CS_WARMUP_START", g_warmLeft);
		set_task(1.0, "task_warmup", TASK_WARMUP, _, _, "b");
	}
	else if (newstate == MS_WAITING || newstate == MS_RESULT)
	{
		remove_task(TASK_WARMUP);
		remove_task(TASK_LO3);
		for (new t = TASK_FORFEIT; t < TASK_FORFEIT + 33; t++) remove_task(t);
	}
}

public task_warmup()
{
	if (cs_get_state() != MS_WARMUP)
	{
		remove_task(TASK_WARMUP);
		return;
	}
	if (g_warmLeft > 0)
	{
		cs_hud(0, 1.1, "%L", LANG_PLAYER, "CS_WARMUP_HUD", g_warmLeft);
		g_warmLeft--;
		return;
	}
	remove_task(TASK_WARMUP);
	cs_set_state(MS_LO3);
	g_lo3Step = 0;
	set_task(2.0, "task_lo3", TASK_LO3, _, _, "a", 3);
}

public task_lo3()
{
	g_lo3Step++;
	server_cmd("sv_restart 1");
	cs_msg(0, PFX_MATCH, "LIVE ON THREE ... %d", g_lo3Step);
	if (g_lo3Step >= 3)
		set_task(1.5, "task_live");
}

public task_live()
{
	cs_set_state(MS_LIVE);
	cs_hud(0, 3.0, "--- LIVE ---  GL HF");
	cs_msg(0, PFX_MATCH, "%L", LANG_PLAYER, "CS_LIVE");
}

// ---------- surrender: every connected member of a team types .gg ----------
public cmd_gg(id)
{
	if (cs_get_state() != MS_LIVE)
		return PLUGIN_HANDLED;
	new CsTeams:team = cs_get_user_team(id);
	if (team != CS_TEAM_T && team != CS_TEAM_CT)
		return PLUGIN_HANDLED;

	g_gg[id] = true;
	new total, votes;
	for (new i = 1; i <= 32; i++)
	{
		if (!is_user_connected(i) || cs_get_user_team(i) != team) continue;
		total++;
		if (g_gg[i]) votes++;
	}
	cs_msg(0, PFX_MATCH, "%L", LANG_PLAYER, "CS_GG_VOTE", votes, total);
	if (votes >= total)
		cs_end_match(team == CS_TEAM_T ? 2 : 1);
	return PLUGIN_HANDLED;
}

// ---------- technical timeout: once per team, extends next freezetime ----------
public cmd_tech(id)
{
	if (cs_get_state() != MS_LIVE)
		return PLUGIN_HANDLED;
	new t = _:cs_get_user_team(id);
	if (t != 1 && t != 2) return PLUGIN_HANDLED;
	if (g_techUsed[t])
	{
		cs_msg(id, PFX_MATCH, "%L", id, "CS_TECH_USED");
		return PLUGIN_HANDLED;
	}
	g_techUsed[t] = 1;
	g_oldFreeze = get_cvar_num("mp_freezetime");
	set_cvar_num("mp_freezetime", get_pcvar_num(g_cvTechTime));
	cs_msg(0, PFX_MATCH, "%L", LANG_PLAYER, "CS_TECH_CALLED", get_pcvar_num(g_cvTechTime));
	set_task(float(get_pcvar_num(g_cvTechTime)) + 120.0, "task_restore_freeze");
	return PLUGIN_HANDLED;
}

public task_restore_freeze() set_cvar_num("mp_freezetime", g_oldFreeze);

// ---------- reconnect / forfeit / leaver ban ----------
public client_disconnected(id)
{
	new st = cs_get_state();
	if (st != MS_LIVE && st != MS_LO3 && st != MS_PAUSED)
		return;
	new t = _:cs_get_user_team(id);
	if (t != 1 && t != 2)
		return;

	new auth[35];
	get_user_authid(id, auth, charsmax(auth));
	TrieSetCell(g_leavers, auth, t);

	new data[36];
	copy(data, charsmax(data), auth);
	set_task(float(get_pcvar_num(g_cvReconnect)), "task_forfeit", TASK_FORFEIT + id, data, sizeof(data));
	cs_msg(0, PFX_MATCH, "%L", LANG_PLAYER, "CS_PLAYER_LEFT", get_pcvar_num(g_cvReconnect));
}

public client_authorized(id)
{
	new auth[35], t;
	get_user_authid(id, auth, charsmax(auth));
	if (!TrieGetCell(g_leavers, auth, t))
		return;
	TrieDeleteKey(g_leavers, auth);
	for (new i = TASK_FORFEIT; i < TASK_FORFEIT + 33; i++)
	{
		// cancel the pending forfeit for this authid
		if (task_exists(i)) { remove_task(i); }
	}
	set_task(2.0, "task_rejoin", id + 6000, auth, sizeof(auth));
	g_rejoinTeam[id] = t;
}

new g_rejoinTeam[33];

public task_rejoin(const auth[], taskid)
{
	new id = taskid - 6000;
	if (!is_user_connected(id)) return;
	cs_set_user_team(id, g_rejoinTeam[id] == 1 ? CS_TEAM_T : CS_TEAM_CT);
	cs_msg(0, PFX_MATCH, "%L", LANG_PLAYER, "CS_PLAYER_BACK");
}

public task_forfeit(const auth[])
{
	if (cs_get_state() != MS_LIVE && cs_get_state() != MS_PAUSED)
		return;

	new t;
	if (!TrieGetCell(g_leavers, auth, t))
		return;

	if (cs_is_ranked() && get_pcvar_num(g_cvBanMins) > 0)
	{
		server_cmd("banid %d %s", get_pcvar_num(g_cvBanMins), auth);
		log_amx("[MATCH] leaver %s temp-banned %d min", auth, get_pcvar_num(g_cvBanMins));
	}

	new cnt[3];
	for (new i = 1; i <= 32; i++)
	{
		if (!is_user_connected(i)) continue;
		new pt = _:cs_get_user_team(i);
		if (pt == 1 || pt == 2) cnt[pt]++;
	}
	if (cnt[1] == 0) cs_end_match(2);
	else if (cnt[2] == 0) cs_end_match(1);
}
