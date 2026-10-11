// CS16 Platform - server_core (Match Director)
#include <amxmodx>
#include <amxmisc>
#include <cs16_core>

#define PLUGIN  "cs16_core"
#define VERSION "0.1.0"
#define AUTHOR  "CS16 Platform"

new const STATE_NAMES[MS_COUNT][] = { "WAITING", "QUEUE", "WARMUP", "LO3", "LIVE", "PAUSED", "RESULT" };
new const MODE_NAMES[MODE_COUNT][] = { "NONE", "1v1", "HNS", "KZ" };
new const PREFIXES[][] = { "^4[LOBBY]^1", "^4[MATCH]^1", "^4[QUEUE]^1", "^4[RECORD]^1", "^4[SYSTEM]^1" };

new g_state = MS_WAITING;
new g_mode = MODE_NONE;
new g_matchId;
new g_fwState, g_fwEnd;
new g_hudSync;
new Float:g_perf[33];
new g_lockedName[33][32];

new g_cvRanked, g_cvStaging, g_cvResultTime;

public plugin_natives()
{
	register_library("cs16_core");
	register_native("cs_get_state", "_get_state");
	register_native("cs_set_state", "_set_state");
	register_native("cs_get_mode", "_get_mode");
	register_native("cs_set_mode", "_set_mode");
	register_native("cs_get_match_id", "_get_match_id");
	register_native("cs_is_ranked", "_is_ranked");
	register_native("cs_feature_enabled", "_feature_enabled");
	register_native("cs_end_match", "_end_match");
	register_native("cs_get_state_name", "_state_name");
	register_native("cs_get_mode_name", "_mode_name");
	register_native("cs_msg", "_msg");
	register_native("cs_hud", "_hud");
	register_native("cs_set_perf", "_set_perf");
	register_native("cs_get_perf", "_get_perf");
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_dictionary("cs16.txt");

	// Feature flags (override in configs/cs16_platform.cfg)
	register_cvar("cs_enable_1v1", "1");
	register_cvar("cs_enable_hns", "1");
	register_cvar("cs_enable_kz", "0");
	register_cvar("cs_enable_rating", "1");
	register_cvar("cs_enable_bounty", "0");
	register_cvar("cs_enable_trust", "0");
	register_cvar("cs_enable_nextclient", "0");
	g_cvRanked = register_cvar("cs_ranked", "1");
	g_cvStaging = register_cvar("cs_staging", "0");
	g_cvResultTime = register_cvar("cs_result_time", "10");
	register_cvar("cs16_version", VERSION, FCVAR_SERVER | FCVAR_SPONLY);

	g_fwState = CreateMultiForward("cs_on_state_change", ET_IGNORE, FP_CELL, FP_CELL);
	g_fwEnd = CreateMultiForward("cs_on_match_end", ET_IGNORE, FP_CELL, FP_CELL);
	g_hudSync = CreateHudSyncObj();

	// Commands restricted by match state
	register_clcmd("jointeam", "cmd_restricted");
	register_clcmd("chooseteam", "cmd_restricted");
	register_clcmd("kill", "cmd_restricted");

	register_concmd("cs_status", "cmd_status", ADMIN_ALL, "- prints platform state");
	register_concmd("cs_state", "cmd_force_state", ADMIN_RCON, "<state 0-6> - force match state");
	register_concmd("cs_reset", "cmd_reset", ADMIN_RCON, "- abort match, back to WAITING");

	server_print("[CS16] core %s loaded", VERSION);
}

public plugin_cfg()
{
	new dir[128];
	get_configsdir(dir, charsmax(dir));
	server_cmd("exec %s/cs16_platform.cfg", dir);
	server_exec();
}

// ---------------- state machine ----------------
set_state(ns)
{
	if (ns < 0 || ns >= MS_COUNT || ns == g_state)
		return;

	new old = g_state;
	g_state = ns;

	if (ns == MS_WARMUP && old != MS_PAUSED)
	{
		g_matchId = get_systime();
		for (new i = 1; i <= 32; i++)
			g_perf[i] = 0.5;
	}

	if (ns == MS_LIVE && get_pcvar_num(g_cvRanked))
	{
		for (new i = 1; i <= 32; i++)
			if (is_user_connected(i))
				get_user_name(i, g_lockedName[i], charsmax(g_lockedName[]));
	}

	log_amx("[CORE] state %s -> %s (match %d)", STATE_NAMES[old], STATE_NAMES[ns], g_matchId);
	new ret;
	ExecuteForward(g_fwState, ret, old, ns);
}

public _get_state(plugin, params) return g_state;
public _set_state(plugin, params) { set_state(get_param(1)); return 1; }
public _get_mode(plugin, params) return g_mode;
public _set_mode(plugin, params)
{
	new m = get_param(1);
	if (m < 0 || m >= MODE_COUNT)
		return 0;
	g_mode = m;
	log_amx("[CORE] mode = %s", MODE_NAMES[m]);
	return 1;
}
public _get_match_id(plugin, params) return g_matchId;
public _is_ranked(plugin, params) return get_pcvar_num(g_cvRanked);

public _feature_enabled(plugin, params)
{
	new flag[32], name[48];
	get_string(1, flag, charsmax(flag));
	formatex(name, charsmax(name), "cs_enable_%s", flag);
	return get_cvar_num(name);
}

public _end_match(plugin, params)
{
	if (g_state != MS_LIVE && g_state != MS_PAUSED)
		return 0;

	new winner = get_param(1);
	set_state(MS_RESULT);
	new ret;
	ExecuteForward(g_fwEnd, ret, winner, g_matchId);
	log_amx("[CORE] match %d ended, winner team %d", g_matchId, winner);
	set_task(float(get_pcvar_num(g_cvResultTime)), "task_back_to_lobby");
	return 1;
}

public task_back_to_lobby()
{
	set_state(MS_WAITING);
	server_cmd("sv_restart 1");
}

public _state_name(plugin, params)
{
	new s = get_param(1);
	if (s < 0 || s >= MS_COUNT) s = 0;
	set_string(2, STATE_NAMES[s], get_param(3));
	return 1;
}

public _mode_name(plugin, params)
{
	new m = get_param(1);
	if (m < 0 || m >= MODE_COUNT) m = 0;
	set_string(2, MODE_NAMES[m], get_param(3));
	return 1;
}

// ---------------- message / HUD manager ----------------
public _msg(plugin, params)
{
	new id = get_param(1);
	new p = clamp(get_param(2), 0, sizeof(PREFIXES) - 1);
	if (id && !is_user_connected(id))
		return 0;

	new text[190];
	vdformat(text, charsmax(text), 3, 4);
	client_print_color(id, print_team_default, "%s %s", PREFIXES[p], text);
	return 1;
}

public _hud(plugin, params)
{
	new id = get_param(1);
	if (id && !is_user_connected(id))
		return 0;

	new Float:hold = get_param_f(2);
	new text[256];
	vdformat(text, charsmax(text), 3, 4);
	set_hudmessage(0, 200, 255, -1.0, 0.15, 0, 0.0, hold, 0.0, 0.1, -1);
	ShowSyncHudMsg(id, g_hudSync, "%s", text);
	return 1;
}

public _set_perf(plugin, params)
{
	new id = get_param(1);
	if (id < 1 || id > 32) return 0;
	new Float:v = get_param_f(2);
	if (v < 0.0) v = 0.0;
	if (v > 1.0) v = 1.0;
	g_perf[id] = v;
	return 1;
}

public Float:_get_perf(plugin, params)
{
	new id = get_param(1);
	if (id < 1 || id > 32) return 0.5;
	return g_perf[id];
}

// ---------------- restrictions ----------------
public cmd_restricted(id)
{
	if (get_pcvar_num(g_cvStaging))
		return PLUGIN_CONTINUE;

	if (g_state == MS_LIVE || g_state == MS_LO3 || g_state == MS_PAUSED)
	{
		client_print_color(id, print_team_default, "%s %L", PREFIXES[PFX_MATCH], id, "CS_CMD_LOCKED");
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}

public client_putinserver(id)
{
	g_perf[id] = 0.5;
	g_lockedName[id][0] = 0;
}

public client_infochanged(id)
{
	if (!is_user_connected(id) || g_state != MS_LIVE || !get_pcvar_num(g_cvRanked) || !g_lockedName[id][0])
		return PLUGIN_CONTINUE;

	new newname[32];
	get_user_info(id, "name", newname, charsmax(newname));
	if (!equal(newname, g_lockedName[id]))
	{
		set_user_info(id, "name", g_lockedName[id]);
		client_print_color(id, print_team_default, "%s %L", PREFIXES[PFX_MATCH], id, "CS_NAME_LOCKED");
	}
	return PLUGIN_CONTINUE;
}

// ---------------- admin ----------------
public cmd_status(id, level, cid)
{
	console_print(id, "[CS16] state=%s mode=%s match=%d ranked=%d staging=%d",
		STATE_NAMES[g_state], MODE_NAMES[g_mode], g_matchId, get_pcvar_num(g_cvRanked), get_pcvar_num(g_cvStaging));
	return PLUGIN_HANDLED;
}

public cmd_force_state(id, level, cid)
{
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED;
	new arg[8];
	read_argv(1, arg, charsmax(arg));
	set_state(str_to_num(arg));
	console_print(id, "[CS16] state now %s", STATE_NAMES[g_state]);
	return PLUGIN_HANDLED;
}

public cmd_reset(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;
	remove_task();
	set_state(MS_WAITING);
	server_cmd("sv_restart 1");
	console_print(id, "[CS16] match aborted");
	return PLUGIN_HANDLED;
}
