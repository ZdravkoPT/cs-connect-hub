// CS16 Platform - trust score, restricted queue, new-account throttle, reports, anti-cheat signals.
// Signals only flag and log; nothing here auto-bans from a single signal.
// Must load BEFORE cs16_lobby so it can block .ready for restricted players.
#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <nvault>
#include <cs16_core>

#define PLUGIN  "cs16_trust"
#define VERSION "0.1.0"

enum { T_MINUTES = 0, T_MATCHES, T_REPORTS, T_FLAGS, T_LEAVES, T_FIELDS };

new g_vault = INVALID_HANDLE;
new g_data[33][T_FIELDS];
new g_cvMin, g_cvNewMinutes;

// anti-cheat state
new g_perfectJumps[33], g_groundFrames[33];
new Float:g_lastFlag[33];
new g_reportTarget[33];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, "CS16 Platform");
	g_vault = nvault_open("cs16_trust");
	g_cvMin = register_cvar("cs_trust_min", "30");
	g_cvNewMinutes = register_cvar("cs_new_account_minutes", "30");

	new const ready[][] = { "say .ready", "say !ready", "say /ready", "say .r", "say !r", "say /r",
		"say_team .ready", "say_team !ready", "say_team /ready" };
	for (new i = 0; i < sizeof(ready); i++) register_clcmd(ready[i], "cmd_ready_gate");

	register_clcmd("say /report", "cmd_report");
	register_clcmd("say .report", "cmd_report");
	register_clcmd("say /trust", "cmd_mytrust");
	register_concmd("cs_checktrust", "cmd_check", ADMIN_KICK, "<name> - show trust details");

	register_forward(FM_PlayerPreThink, "fw_prethink");
	set_task(60.0, "task_minute", 7800, _, _, "b");
	set_task(30.0, "task_fps", 7801, _, _, "b");
}

public plugin_end()
{
	for (new i = 1; i <= 32; i++) if (is_user_connected(i)) save(i);
	if (g_vault != INVALID_HANDLE) nvault_close(g_vault);
}

load(id)
{
	for (new k = 0; k < T_FIELDS; k++) g_data[id][k] = 0;
	new auth[35], val[64], p[T_FIELDS][8];
	get_user_authid(id, auth, charsmax(auth));
	if (!nvault_get(g_vault, auth, val, charsmax(val))) return;
	parse(val, p[0], 7, p[1], 7, p[2], 7, p[3], 7, p[4], 7);
	for (new k = 0; k < T_FIELDS; k++) g_data[id][k] = str_to_num(p[k]);
}

save(id)
{
	new auth[35], val[64];
	get_user_authid(id, auth, charsmax(auth));
	if (!auth[0] || equal(auth, "BOT")) return;
	formatex(val, charsmax(val), "%d %d %d %d %d", g_data[id][0], g_data[id][1], g_data[id][2], g_data[id][3], g_data[id][4]);
	nvault_set(g_vault, auth, val);
}

// 0..100: grows with playtime and matches, drops with reports, AC flags and leaves
trust(id)
{
	new s = 50 + min(g_data[id][T_MINUTES] / 30, 25) + min(g_data[id][T_MATCHES], 25)
		- g_data[id][T_REPORTS] * 3 - g_data[id][T_FLAGS] * 5 - g_data[id][T_LEAVES] * 8;
	return clamp(s, 0, 100);
}

public client_authorized(id) load(id);
public client_putinserver(id) { g_perfectJumps[id] = 0; g_lastFlag[id] = 0.0; }

public client_disconnected(id)
{
	new st = cs_get_state();
	if (st == MS_LIVE || st == MS_LO3) g_data[id][T_LEAVES]++;
	save(id);
}

public cs_on_match_end(winner, match_id)
{
	for (new i = 1; i <= 32; i++)
		if (is_user_connected(i) && get_user_team(i) >= 1 && get_user_team(i) <= 2) { g_data[i][T_MATCHES]++; save(i); }
}

public task_minute()
{
	for (new i = 1; i <= 32; i++) if (is_user_connected(i) && !is_user_bot(i)) g_data[i][T_MINUTES]++;
}

public cmd_ready_gate(id)
{
	if (!cs_is_ranked() || !cs_feature_enabled("trust")) return PLUGIN_CONTINUE;
	if (get_user_flags(id) & ADMIN_KICK) return PLUGIN_CONTINUE;

	if (g_data[id][T_MINUTES] < get_pcvar_num(g_cvNewMinutes))
	{
		cs_msg(id, PFX_QUEUE, "New account: ranked unlocks after %d minutes of play (you have %d).", get_pcvar_num(g_cvNewMinutes), g_data[id][T_MINUTES]);
		return PLUGIN_HANDLED;
	}
	if (trust(id) < get_pcvar_num(g_cvMin))
	{
		cs_msg(id, PFX_QUEUE, "Restricted queue: your trust is too low for ranked. Play unranked to recover.");
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}

public cmd_mytrust(id)
{
	new t = trust(id);
	cs_msg(id, PFX_SYSTEM, "Account standing: %s", t >= 70 ? "Good" : (t >= 40 ? "Normal" : "Low"));
	return PLUGIN_HANDLED;
}

public cmd_check(id, level, cid)
{
	if (!cmd_access(id, level, cid, 2)) return PLUGIN_HANDLED;
	new arg[32];
	read_argv(1, arg, charsmax(arg));
	new t = cmd_target(id, arg, CMDTARGET_ALLOW_SELF);
	if (!t) return PLUGIN_HANDLED;
	new name[32];
	get_user_name(t, name, charsmax(name));
	console_print(id, "[TRUST] %s score=%d minutes=%d matches=%d reports=%d acflags=%d leaves=%d", name, trust(t),
		g_data[t][T_MINUTES], g_data[t][T_MATCHES], g_data[t][T_REPORTS], g_data[t][T_FLAGS], g_data[t][T_LEAVES]);
	return PLUGIN_HANDLED;
}

// ---------- reports ----------
public cmd_report(id)
{
	new m = menu_create("\yReport player:", "menu_report");
	new name[32], info[4];
	for (new i = 1; i <= 32; i++)
	{
		if (i == id || !is_user_connected(i) || is_user_bot(i)) continue;
		get_user_name(i, name, charsmax(name));
		num_to_str(i, info, charsmax(info));
		menu_additem(m, name, info);
	}
	menu_display(id, m);
	return PLUGIN_HANDLED;
}

public menu_report(id, menu, item)
{
	if (item < 0) { menu_destroy(menu); return PLUGIN_HANDLED; }
	new info[4], acc, cb;
	menu_item_getinfo(menu, item, acc, info, charsmax(info), _, _, cb);
	menu_destroy(menu);
	g_reportTarget[id] = str_to_num(info);

	new r = menu_create("\yReason:", "menu_reason");
	menu_additem(r, "Cheating", "Cheating");
	menu_additem(r, "Griefing / blocking", "Griefing");
	menu_additem(r, "Abusive chat", "Abuse");
	menu_additem(r, "AFK", "AFK");
	menu_display(id, r);
	return PLUGIN_HANDLED;
}

public menu_reason(id, menu, item)
{
	if (item < 0) { menu_destroy(menu); return PLUGIN_HANDLED; }
	new reason[16], acc, cb;
	menu_item_getinfo(menu, item, acc, reason, charsmax(reason), _, _, cb);
	menu_destroy(menu);
	new t = g_reportTarget[id];
	if (!is_user_connected(t)) return PLUGIN_HANDLED;

	g_data[t][T_REPORTS]++;
	new a[32], b[32], aa[35], ba[35];
	get_user_name(id, a, 31); get_user_name(t, b, 31);
	get_user_authid(id, aa, 34); get_user_authid(t, ba, 34);
	log_to_file("cs16_reports.log", "match=%d %s (%s) reported %s (%s): %s", cs_get_match_id(), a, aa, b, ba, reason);
	cs_msg(id, PFX_SYSTEM, "Report sent. Thank you.");
	notify_admins("%s reported %s: %s", a, b, reason);
	return PLUGIN_HANDLED;
}

notify_admins(const fmt[], any:...)
{
	new msg[160];
	vformat(msg, charsmax(msg), fmt, 2);
	for (new i = 1; i <= 32; i++)
		if (is_user_connected(i) && (get_user_flags(i) & ADMIN_KICK))
			cs_msg(i, PFX_SYSTEM, "^3[ADMIN]^1 %s", msg);
}

// ---------- anti-cheat signals ----------
flag(id, const what[])
{
	if (get_gametime() - g_lastFlag[id] < 20.0) return;   // throttle
	g_lastFlag[id] = get_gametime();
	g_data[id][T_FLAGS]++;
	new name[32], auth[35];
	get_user_name(id, name, 31); get_user_authid(id, auth, 34);
	log_to_file("cs16_anticheat.log", "match=%d %s (%s) %s", cs_get_match_id(), name, auth, what);
	notify_admins("AC signal: %s - %s (review demo)", name, what);
}

public fw_prethink(id)
{
	if (!is_user_alive(id)) return FMRES_IGNORED;
	new flags = pev(id, pev_flags), buttons = pev(id, pev_button), old = pev(id, pev_oldbuttons);

	if (flags & FL_ONGROUND)
	{
		g_groundFrames[id]++;
		if ((buttons & IN_JUMP) && !(old & IN_JUMP))
		{
			// jump pressed on the very first ground frame = perfect bhop
			if (g_groundFrames[id] == 1) g_perfectJumps[id]++;
			else g_perfectJumps[id] = 0;
			if (g_perfectJumps[id] >= 12) { flag(id, "bhop script pattern (12 perfect jumps)"); g_perfectJumps[id] = 0; }
		}
	}
	else
		g_groundFrames[id] = 0;

	new Float:v[3];
	pev(id, pev_velocity, v);
	if ((flags & FL_ONGROUND) && floatsqroot(v[0] * v[0] + v[1] * v[1]) > 450.0 && pev(id, pev_movetype) == MOVETYPE_WALK)
		flag(id, "ground speed above 450");
	return FMRES_IGNORED;
}

public task_fps()
{
	if (cs_get_state() != MS_LIVE || !cs_is_ranked()) return;
	for (new i = 1; i <= 32; i++)
		if (is_user_connected(i) && !is_user_bot(i)) query_client_cvar(i, "fps_max", "on_fps");
}

public on_fps(id, const cvar[], const value[])
{
	if (str_to_float(value) > 101.0)
	{
		client_cmd(id, "fps_max 100");
		cs_msg(id, PFX_MATCH, "Ranked uses 100 FPS. fps_max set to 100.");
	}
}
