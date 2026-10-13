#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <cs16_core>

#pragma semicolon 1

#define PLUGIN "CS16 Draft"
#define VERSION "1.0"

// Captain draft + knife duel for 5v5 (and 3v3) matches.
// Flow: match locked -> pick 2 captains -> knife duel -> winner picks first
// -> draft menu with timer -> autopick on timeout -> teams confirmed -> map vote.

new g_captain[2];           // captain player ids (0 = T captain, 1 = CT captain)
new g_duelWinner;           // captain who won the knife duel (picks first)
new g_pickTurn;             // whose turn to pick (0/1)
new g_pool[16], g_poolNum;  // remaining draftable players
new g_draftActive;
new g_duelActive;
new g_pickTimer;
new g_cvarEnabled, g_cvarPickTime;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, "CS16 Platform");
	g_cvarEnabled = register_cvar("cs_draft", "1");
	g_cvarPickTime = register_cvar("cs_draft_picktime", "15");

	RegisterHam(Ham_Killed, "player", "fw_killed", 1);
	register_event("CurWeapon", "fw_curweapon", "be", "1=1");

	register_clcmd("say /draft", "cmd_draftstatus");
}

// ------------------------------------------------------------------
// Called by cs16_match when teams are locked and mode needs a draft
// ------------------------------------------------------------------
public start_draft(players[], num)
{
	if (!get_pcvar_num(g_cvarEnabled) || num < 4)
		return 0;

	g_draftActive = 1;
	g_duelActive = 0;
	g_poolNum = 0;

	// Captains: two highest-rated players (rating native returns int rating)
	new best[2] = { -1, -1 };
	new bestR[2] = { -99999, -99999 };
	for (new i = 0; i < num; i++)
	{
		new r = cs16_get_rating(players[i]);
		if (r > bestR[0]) { bestR[1] = bestR[0]; best[1] = best[0]; bestR[0] = r; best[0] = players[i]; }
		else if (r > bestR[1]) { bestR[1] = r; best[1] = players[i]; }
	}
	g_captain[0] = best[0];
	g_captain[1] = best[1];

	// Everyone else goes into the draft pool
	for (new i = 0; i < num; i++)
	{
		if (players[i] == g_captain[0] || players[i] == g_captain[1]) continue;
		g_pool[g_poolNum++] = players[i];
	}

	cs_set_user_team(g_captain[0], CS_TEAM_T);
	cs_set_user_team(g_captain[1], CS_TEAM_CT);

	new n1[MAX_NAME_LENGTH], n2[MAX_NAME_LENGTH];
	get_user_name(g_captain[0], n1, charsmax(n1));
	get_user_name(g_captain[1], n2, charsmax(n2));
	cs16_chat(0, "[MATCH] Kapitanqt na T e %s, kapitanqt na CT e %s.", n1, n2);
	cs16_chat(0, "[MATCH] Nojova duel za purvi izbor! / Knife duel for first pick!");

	start_knife_duel();
	return 1;
}

// ------------------------------------------------------------------
// Knife duel: both captains stripped to knife, first kill wins
// ------------------------------------------------------------------
start_knife_duel()
{
	g_duelActive = 1;
	for (new i = 0; i < 2; i++)
	{
		new id = g_captain[i];
		if (!is_user_alive(id)) respawn_player(id);
		strip_user_weapons(id);
		give_item(id, "weapon_knife");
	}
	cs16_hud(0, "KNIFE DUEL - purvi ubiec izbira purvi!");
}

public fw_curweapon(id)
{
	if (!g_duelActive) return;
	if (id != g_captain[0] && id != g_captain[1]) return;
	// captains may only use knife during the duel
	if (get_user_weapon(id) != CSW_KNIFE)
		engclient_cmd(id, "weapon_knife");
}

public fw_killed(victim, attacker, shouldgib)
{
	if (!g_duelActive) return;
	if (victim != g_captain[0] && victim != g_captain[1]) return;
	if (attacker != g_captain[0] && attacker != g_captain[1]) return;

	g_duelActive = 0;
	g_duelWinner = attacker;

	new n[MAX_NAME_LENGTH];
	get_user_name(attacker, n, charsmax(n));
	cs16_chat(0, "[MATCH] %s specheli nojovata duel i izbira purvi!", n);

	// restore captains, begin draft
	set_task(2.0, "task_begindraft");
}

public task_begindraft()
{
	g_pickTurn = (g_duelWinner == g_captain[1]) ? 1 : 0;
	show_pick_menu();
}

// ------------------------------------------------------------------
// Draft menu
// ------------------------------------------------------------------
show_pick_menu()
{
	if (!g_draftActive) return;
	if (g_poolNum <= 0) { finish_draft(); return; }

	// only one player left -> autopick to the captain with fewer players
	if (g_poolNum == 1)
	{
		new tCount = team_count(CS_TEAM_T), ctCount = team_count(CS_TEAM_CT);
		g_pickTurn = (tCount <= ctCount) ? 0 : 1;
		do_pick(g_pool[0]);
		return;
	}

	new id = g_captain[g_pickTurn];
	if (!is_user_connected(id)) { auto_pick(); return; }

	new menu = menu_create("Izberi igrach:", "h_pick");
	new info[8], name[MAX_NAME_LENGTH];
	for (new i = 0; i < g_poolNum; i++)
	{
		get_user_name(g_pool[i], name, charsmax(name));
		num_to_str(g_pool[i], info, charsmax(info));
		menu_additem(menu, name, info);
	}
	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
	menu_display(id, menu, get_pcvar_num(g_cvarPickTime));

	g_pickTimer = get_pcvar_num(g_cvarPickTime);
	set_task(float(g_pickTimer), "task_autopick", 9911);
}

public h_pick(id, menu, item)
{
	remove_task(9911);
	if (item < 0 || !g_draftActive) { menu_destroy(menu); return PLUGIN_HANDLED; }

	new info[8], dummy;
	menu_item_getinfo(menu, item, dummy, info, charsmax(info), _, _, dummy);
	menu_destroy(menu);

	new picked = str_to_num(info);
	do_pick(picked);
	return PLUGIN_HANDLED;
}

public task_autopick()
{
	if (g_draftActive) auto_pick();
}

auto_pick()
{
	// autopick: highest-rated remaining player
	new best = 0, bestR = -99999;
	for (new i = 0; i < g_poolNum; i++)
	{
		new r = cs16_get_rating(g_pool[i]);
		if (r > bestR) { bestR = r; best = g_pool[i]; }
	}
	cs16_chat(0, "[MATCH] Vremeto izteche - avtomatichni izbor.");
	do_pick(best);
}

do_pick(picked)
{
	// remove from pool
	for (new i = 0; i < g_poolNum; i++)
	{
		if (g_pool[i] == picked)
		{
			g_pool[i] = g_pool[--g_poolNum];
			break;
		}
	}

	new CsTeams:team = (g_pickTurn == 0) ? CS_TEAM_T : CS_TEAM_CT;
	cs_set_user_team(picked, team);

	new pn[MAX_NAME_LENGTH], cn[MAX_NAME_LENGTH];
	get_user_name(picked, pn, charsmax(pn));
	get_user_name(g_captain[g_pickTurn], cn, charsmax(cn));
	cs16_chat(0, "[MATCH] %s izbra %s.", cn, pn);

	if (g_poolNum <= 0) { finish_draft(); return; }

	g_pickTurn = 1 - g_pickTurn;
	show_pick_menu();
}

finish_draft()
{
	g_draftActive = 0;
	cs16_chat(0, "[MATCH] Otborite sa potvurdeni! / Teams confirmed!");
	cs16_set_state(STATE_MAPVOTE);
}

public cmd_draftstatus(id)
{
	if (!g_draftActive && !g_duelActive)
	{
		cs16_chat(id, "[MATCH] Nyama aktivna draft v momenta.");
		return PLUGIN_HANDLED;
	}
	if (g_duelActive)
		cs16_chat(id, "[MATCH] Nojova duel v momenta.");
	else
		cs16_chat(id, "[MATCH] Draft: ostavat %d igrachi za izbirane.", g_poolNum);
	return PLUGIN_HANDLED;
}

team_count(CsTeams:team)
{
	new n = 0;
	for (new i = 1; i <= 32; i++)
		if (is_user_connected(i) && cs_get_user_team(i) == team) n++;
	return n;
}

respawn_player(id)
{
	if (is_user_connected(id) && !is_user_alive(id))
		ExecuteHamB(Ham_CS_RoundRespawn, id);
}
