// CS16 Platform - lobby / queue / ready
#include <amxmodx>
#include <cstrike>
#include <cs16_core>

#define PLUGIN  "cs16_lobby"
#define VERSION "0.1.0"

#define TASK_HUD   5100
#define TASK_COUNT 5101

new bool:g_ready[33];
new g_cvHnsPlayers, g_cvCountdown;
new g_countdown;
new g_lastMatch[128];
new g_pendingMode = MODE_1V1;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, "CS16 Platform");
	register_dictionary("cs16.txt");

	g_cvHnsPlayers = register_cvar("cs_hns_players", "4");
	g_cvCountdown = register_cvar("cs_lobby_countdown", "5");

	reg_say("ready", "cmd_ready");
	reg_say("r", "cmd_ready");
	reg_say("unready", "cmd_unready");
	reg_say("notready", "cmd_unready");
	reg_say("queue", "cmd_status");
	reg_say("status", "cmd_status");
	reg_say("lastmatch", "cmd_lastmatch");
	reg_say("1v1", "cmd_mode_1v1");
	reg_say("hns", "cmd_mode_hns");

	set_task(1.0, "task_hud", TASK_HUD, _, _, "b");
	copy(g_lastMatch, charsmax(g_lastMatch), "-");
}

reg_say(const cmd[], const handler[])
{
	new buf[32];
	new const pfx[][] = { ".", "!", "/" };
	for (new i = 0; i < sizeof(pfx); i++)
	{
		formatex(buf, charsmax(buf), "say %s%s", pfx[i], cmd);
		register_clcmd(buf, handler);
		formatex(buf, charsmax(buf), "say_team %s%s", pfx[i], cmd);
		register_clcmd(buf, handler);
	}
}

bool:in_lobby()
{
	new st = cs_get_state();
	return (st == MS_WAITING || st == MS_QUEUE);
}

needed_players()
{
	if (g_pendingMode == MODE_HNS)
		return max(2, get_pcvar_num(g_cvHnsPlayers));
	return 2;
}

count_ready()
{
	new n;
	for (new i = 1; i <= 32; i++)
		if (g_ready[i] && is_user_connected(i))
			n++;
	return n;
}

public client_putinserver(id) g_ready[id] = false;
public client_disconnected(id)
{
	g_ready[id] = false;
	if (task_exists(TASK_COUNT) && count_ready() < needed_players())
	{
		remove_task(TASK_COUNT);
		cs_msg(0, PFX_QUEUE, "%L", LANG_PLAYER, "CS_COUNT_ABORT");
	}
}

public cmd_ready(id)
{
	if (!in_lobby())
	{
		cs_msg(id, PFX_LOBBY, "%L", id, "CS_NOT_IN_LOBBY");
		return PLUGIN_HANDLED;
	}
	if (g_ready[id])
		return PLUGIN_HANDLED;

	g_ready[id] = true;
	new name[32];
	get_user_name(id, name, charsmax(name));
	cs_msg(0, PFX_QUEUE, "%L", LANG_PLAYER, "CS_PLAYER_READY", name, count_ready(), needed_players());
	if (cs_get_state() == MS_WAITING)
		cs_set_state(MS_QUEUE);
	check_start();
	return PLUGIN_HANDLED;
}

public cmd_unready(id)
{
	if (!g_ready[id])
		return PLUGIN_HANDLED;
	g_ready[id] = false;
	if (task_exists(TASK_COUNT) && count_ready() < needed_players())
	{
		remove_task(TASK_COUNT);
		cs_msg(0, PFX_QUEUE, "%L", LANG_PLAYER, "CS_COUNT_ABORT");
	}
	return PLUGIN_HANDLED;
}

set_mode_vote(id, mode, const flag[])
{
	if (!in_lobby())
		return;
	if (!cs_feature_enabled(flag))
	{
		cs_msg(id, PFX_LOBBY, "%L", id, "CS_MODE_DISABLED");
		return;
	}
	g_pendingMode = mode;
	new mname[16];
	cs_get_mode_name(mode, mname, charsmax(mname));
	cs_msg(0, PFX_LOBBY, "%L", LANG_PLAYER, "CS_MODE_SET", mname, needed_players());
	check_start();
}

public cmd_mode_1v1(id) { set_mode_vote(id, MODE_1V1, "1v1"); return PLUGIN_HANDLED; }
public cmd_mode_hns(id) { set_mode_vote(id, MODE_HNS, "hns"); return PLUGIN_HANDLED; }

check_start()
{
	if (task_exists(TASK_COUNT) || count_ready() < needed_players())
		return;
	g_countdown = get_pcvar_num(g_cvCountdown);
	set_task(1.0, "task_countdown", TASK_COUNT, _, _, "b");
}

public task_countdown()
{
	if (count_ready() < needed_players() || !in_lobby())
	{
		remove_task(TASK_COUNT);
		return;
	}
	if (g_countdown > 0)
	{
		cs_hud(0, 1.1, "%L", LANG_PLAYER, "CS_MATCH_STARTS", g_countdown);
		g_countdown--;
		return;
	}
	remove_task(TASK_COUNT);
	start_match();
}

start_match()
{
	new players[32], num;
	for (new i = 1; i <= 32; i++)
		if (g_ready[i] && is_user_connected(i))
			players[num++] = i;

	new need = needed_players();
	if (g_pendingMode == MODE_1V1)
		need = 2;

	// first N ready players play, alternating T / CT, everyone else spectates
	for (new i = 1; i <= 32; i++)
	{
		if (!is_user_connected(i))
			continue;
		new slot = -1;
		for (new k = 0; k < num && k < need; k++)
			if (players[k] == i)
				slot = k;

		if (slot == -1)
		{
			if (is_user_alive(i)) user_silentkill(i);
			cs_set_user_team(i, CS_TEAM_SPECTATOR);
		}
		else
			cs_set_user_team(i, (slot % 2 == 0) ? CS_TEAM_T : CS_TEAM_CT);
	}

	for (new i = 1; i <= 32; i++)
		g_ready[i] = false;

	cs_set_mode(g_pendingMode);

	// team matches with 6+ players go through captain draft first (draft sets WARMUP itself)
	if (g_pendingMode != MODE_1V1 && need >= 6 && get_cvar_num("cs_draft")
		&& callfunc_begin("draft_begin", "cs16_draft.amxx") == 1)
	{
		callfunc_end();
		return;
	}
	cs_set_state(MS_WARMUP);
}

public cs_on_match_end(winner, match_id)
{
	new mname[16];
	cs_get_mode_name(cs_get_mode(), mname, charsmax(mname));
	formatex(g_lastMatch, charsmax(g_lastMatch), "#%d %s winner=%s", match_id, mname,
		winner == 1 ? "T" : (winner == 2 ? "CT" : "draw"));
}

public cmd_status(id)
{
	new sname[16], mname[16];
	cs_get_state_name(cs_get_state(), sname, charsmax(sname));
	cs_get_mode_name(g_pendingMode, mname, charsmax(mname));
	cs_msg(id, PFX_QUEUE, "%L", id, "CS_STATUS", sname, mname, count_ready(), needed_players(), get_playersnum());
	return PLUGIN_HANDLED;
}

public cmd_lastmatch(id)
{
	cs_msg(id, PFX_LOBBY, "%s", g_lastMatch);
	return PLUGIN_HANDLED;
}

public task_hud()
{
	if (!in_lobby() || task_exists(TASK_COUNT))
		return;
	new mname[16];
	cs_get_mode_name(g_pendingMode, mname, charsmax(mname));
	cs_hud(0, 1.1, "%L", LANG_PLAYER, "CS_LOBBY_HUD", get_playersnum(), mname, count_ready(), needed_players());
}
