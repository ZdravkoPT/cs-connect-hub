// CS16 Platform - mode_kz: timer, checkpoints, Pro/Nub, PB, map WR, WR HUD
// Active on kz_/bkz_/xc_/kzbg_ maps when cs_enable_kz 1. Runs outside the match state machine.
#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <nvault>
#include <cs16_core>

#define PLUGIN  "cs16_kz"
#define VERSION "0.1.0"

new bool:g_kzMap;
new g_vault = INVALID_HANDLE;
new g_map[64];

new bool:g_running[33];
new Float:g_start[33];
new g_cps[33], g_tps[33];
new Float:g_cp[33][3], bool:g_hasCp[33];
new Float:g_startPos[33][3], bool:g_hasStart[33];
new Float:g_pb[33];
new Float:g_wr = 0.0;
new g_wrName[32];
new g_hud;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, "CS16 Platform");
	get_mapname(g_map, charsmax(g_map));
	g_kzMap = (equali(g_map, "kz_", 3) || equali(g_map, "bkz_", 4) || equali(g_map, "xc_", 3) || equali(g_map, "kzbg_", 5));
	if (!g_kzMap || !cs_feature_enabled("kz"))
	{
		g_kzMap = false;
		return;
	}

	g_vault = nvault_open("cs16_kz");
	load_wr();
	g_hud = CreateHudSyncObj();

	RegisterHam(Ham_Use, "func_button", "fw_button");
	say("cp", "cmd_cp"); say("tp", "cmd_tp"); say("gc", "cmd_tp");
	say("start", "cmd_start"); say("stop", "cmd_stop"); say("reset", "cmd_stop");
	say("wr", "cmd_wr"); say("pb", "cmd_pb");
	set_task(0.5, "task_hud", 7700, _, _, "b");
}

say(const c[], const h[])
{
	new b[32];
	formatex(b, 31, "say /%s", c); register_clcmd(b, h);
	formatex(b, 31, "say .%s", c); register_clcmd(b, h);
	formatex(b, 31, "say_team /%s", c); register_clcmd(b, h);
}

public plugin_end() if (g_vault != INVALID_HANDLE) nvault_close(g_vault);

load_wr()
{
	new val[64], t[16];
	if (nvault_get(g_vault, g_map, val, charsmax(val)))
	{
		strtok(val, t, charsmax(t), g_wrName, charsmax(g_wrName), ' ');
		g_wr = str_to_float(t);
	}
}

pb_key(id, out[], len)
{
	new auth[35];
	get_user_authid(id, auth, charsmax(auth));
	formatex(out, len, "%s_%s", auth, g_map);
}

public client_putinserver(id)
{
	g_running[id] = false; g_hasCp[id] = false; g_hasStart[id] = false;
	g_pb[id] = 0.0;
	if (!g_kzMap) return;
	new key[100], val[16];
	pb_key(id, key, charsmax(key));
	if (nvault_get(g_vault, key, val, charsmax(val))) g_pb[id] = str_to_float(val);
}

public fw_button(ent, caller, activator, use_type, Float:value)
{
	if (!g_kzMap || activator < 1 || activator > 32 || !is_user_alive(activator))
		return HAM_IGNORED;

	new target[32], tname[32];
	pev(ent, pev_target, target, charsmax(target));
	pev(ent, pev_targetname, tname, charsmax(tname));

	if (is_start(target) || is_start(tname)) start_run(activator);
	else if (is_stop(target) || is_stop(tname)) finish_run(activator);
	return HAM_IGNORED;
}

bool:is_start(const s[]) return (equali(s, "counter_start") || equali(s, "clockstartbutton") || equali(s, "firsttimerelay") || containi(s, "climb_start") != -1 || containi(s, "start_timer") != -1);
bool:is_stop(const s[]) return (equali(s, "counter_off") || equali(s, "clockstopbutton") || equali(s, "clockstop") || containi(s, "climb_end") != -1 || containi(s, "stop_timer") != -1);

start_run(id)
{
	g_running[id] = true;
	g_start[id] = get_gametime();
	g_cps[id] = g_tps[id] = 0;
	g_hasCp[id] = false;
	pev(id, pev_origin, g_startPos[id]);
	g_hasStart[id] = true;
	cs_msg(id, PFX_RECORD, "Timer started. /cp /tp /start /stop");
}

finish_run(id)
{
	if (!g_running[id]) return;
	g_running[id] = false;
	new Float:t = get_gametime() - g_start[id];
	new name[32], ts[16];
	get_user_name(id, name, charsmax(name));
	fmt_time(t, ts, charsmax(ts));
	new bool:pro = (g_tps[id] == 0);

	cs_msg(0, PFX_RECORD, "%s finished in %s [%s] CP:%d TP:%d", name, ts, pro ? "PRO" : "NUB", g_cps[id], g_tps[id]);

	if (g_pb[id] == 0.0 || t < g_pb[id])
	{
		g_pb[id] = t;
		new key[100], val[16];
		pb_key(id, key, charsmax(key));
		formatex(val, charsmax(val), "%.3f", t);
		nvault_set(g_vault, key, val);
		cs_msg(id, PFX_RECORD, "New personal best: %s", ts);
	}

	// WR ladder = PRO runs only (no teleports)
	if (pro && (g_wr == 0.0 || t < g_wr))
	{
		g_wr = t;
		copy(g_wrName, charsmax(g_wrName), name);
		new val[64];
		formatex(val, charsmax(val), "%.3f %s", t, name);
		nvault_set(g_vault, g_map, val);
		cs_msg(0, PFX_RECORD, "^3NEW MAP RECORD^1 by %s: %s", name, ts);
		log_to_file("cs16_records.log", "WR %s %s %.3f", g_map, name, t);
	}
}

fmt_time(Float:t, out[], len)
{
	new m = floatround(t, floatround_floor) / 60;
	new Float:s = t - float(m * 60);
	formatex(out, len, "%02d:%06.3f", m, s);
}

public cmd_cp(id)
{
	if (!is_user_alive(id)) return PLUGIN_HANDLED;
	if (!(pev(id, pev_flags) & FL_ONGROUND))
	{
		cs_msg(id, PFX_RECORD, "Checkpoints only on the ground.");
		return PLUGIN_HANDLED;
	}
	pev(id, pev_origin, g_cp[id]);
	g_hasCp[id] = true;
	g_cps[id]++;
	return PLUGIN_HANDLED;
}

public cmd_tp(id)
{
	if (!is_user_alive(id) || !g_hasCp[id]) return PLUGIN_HANDLED;
	set_pev(id, pev_velocity, Float:{0.0, 0.0, 0.0});
	engfunc(EngFunc_SetOrigin, id, g_cp[id]);
	g_tps[id]++;
	return PLUGIN_HANDLED;
}

public cmd_start(id)
{
	if (!is_user_alive(id) || !g_hasStart[id]) return PLUGIN_HANDLED;
	set_pev(id, pev_velocity, Float:{0.0, 0.0, 0.0});
	engfunc(EngFunc_SetOrigin, id, g_startPos[id]);
	g_running[id] = false;
	return PLUGIN_HANDLED;
}

public cmd_stop(id) { g_running[id] = false; return PLUGIN_HANDLED; }

public cmd_wr(id)
{
	new ts[16];
	if (g_wr == 0.0) cs_msg(id, PFX_RECORD, "No record on %s yet.", g_map);
	else { fmt_time(g_wr, ts, charsmax(ts)); cs_msg(id, PFX_RECORD, "%s record: %s by %s", g_map, ts, g_wrName); }
	return PLUGIN_HANDLED;
}

public cmd_pb(id)
{
	new ts[16];
	if (g_pb[id] == 0.0) cs_msg(id, PFX_RECORD, "No personal best yet.");
	else { fmt_time(g_pb[id], ts, charsmax(ts)); cs_msg(id, PFX_RECORD, "Your best: %s", ts); }
	return PLUGIN_HANDLED;
}

public task_hud()
{
	new wr[16], cur[16];
	if (g_wr == 0.0) copy(wr, charsmax(wr), "--:--");
	else fmt_time(g_wr, wr, charsmax(wr));
	for (new id = 1; id <= 32; id++)
	{
		if (!is_user_alive(id)) continue;
		set_hudmessage(255, 200, 0, 0.01, 0.20, 0, 0.0, 0.6, 0.0, 0.0, -1);
		if (g_running[id])
		{
			fmt_time(get_gametime() - g_start[id], cur, charsmax(cur));
			ShowSyncHudMsg(id, g_hud, "WR %s (%s)^nTime %s  CP %d  TP %d", wr, g_wrName, cur, g_cps[id], g_tps[id]);
		}
		else
			ShowSyncHudMsg(id, g_hud, "WR %s (%s)", wr, g_wrName);
	}
}
