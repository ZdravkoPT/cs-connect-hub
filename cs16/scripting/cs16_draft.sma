// CS16 Platform - captain draft + knife duel (team matches, 6+ players)
// Flow: lobby assigns players -> 2 highest-rated become captains -> knife duel
// -> winner picks first -> timed pick menu, autopick on timeout -> WARMUP
#include <amxmodx>
#include <cstrike>
#include <fun>
#include <hamsandwich>
#include <cs16_core>

#define PLUGIN  "cs16_draft"
#define VERSION "0.1.0"
#define TASK_PICK 9911

native cs_get_rating(id);

new g_captain[2];
new g_duelWinner;
new g_pickTurn;
new g_pool[32], g_poolNum;
new bool:g_draftActive, bool:g_duelActive;
new g_cvEnabled, g_cvPickTime;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, "CS16 Platform");
	g_cvEnabled = register_cvar("cs_draft", "1");
	g_cvPickTime = register_cvar("cs_draft_picktime", "15");

	RegisterHam(Ham_Killed, "player", "fw_killed", 1);
	RegisterHam(Ham_Spawn, "player", "fw_spawn", 1);
	register_event("CurWeapon", "fw_curweapon", "be", "1=1");
	register_clcmd("say /draft", "cmd_draftstatus");
	register_clcmd("say !draft", "cmd_draftstatus");
}

// called by cs16_lobby via callfunc after teams are assigned
public draft_begin()
{
	new players[32], num;
	for (new i = 1; i <= 32; i++)
	{
		if (!is_user_connected(i)) continue;
		new CsTeams:t = cs_get_user_team(i);
		if (t == CS_TEAM_T || t == CS_TEAM_CT) players[num++] = i;
	}
	if (!get_pcvar_num(g_cvEnabled) || num < 4)
	{
		cs_set_state(MS_WARMUP);
		return;
	}

	g_draftActive = true;
	g_poolNum = 0;

	new best[2] = { 0, 0 }, bestR[2] = { -99999, -99999 };
	for (new i = 0; i < num; i++)
	{
		new r = cs_get_rating(players[i]);
		if (r > bestR[0]) { bestR[1] = bestR[0]; best[1] = best[0]; bestR[0] = r; best[0] = players[i]; }
		else if (r > bestR[1]) { bestR[1] = r; best[1] = players[i]; }
	}
	g_captain[0] = best[0];
	g_captain[1] = best[1];

	// pool waits in spectator while captains fight
	for (new i = 0; i < num; i++)
	{
		new id = players[i];
		if (id == g_captain[0] || id == g_captain[1]) continue;
		g_pool[g_poolNum++] = id;
		if (is_user_alive(id)) user_silentkill(id);
		cs_set_user_team(id, CS_TEAM_SPECTATOR);
	}
	cs_set_user_team(g_captain[0], CS_TEAM_T);
	cs_set_user_team(g_captain[1], CS_TEAM_CT);

	new n1[32], n2[32];
	get_user_name(g_captain[0], n1, charsmax(n1));
	get_user_name(g_captain[1], n2, charsmax(n2));
	cs_msg(0, PFX_MATCH, "Kapitani / Captains: T = %s, CT = %s", n1, n2);
	cs_msg(0, PFX_MATCH, "Nojova duel za purvi izbor! / Knife duel for first pick!");

	g_duelActive = true;
	server_cmd("sv_restart 1");
	set_task(1.5, "task_arm_captains");
}

public task_arm_captains()
{
	for (new i = 0; i < 2; i++)
	{
		new id = g_captain[i];
		if (!is_user_connected(id)) continue;
		if (!is_user_alive(id)) ExecuteHamB(Ham_CS_RoundRespawn, id);
		strip_user_weapons(id);
		give_item(id, "weapon_knife");
	}
	cs_hud(0, 3.0, "KNIFE DUEL");
}

public fw_spawn(id)
{
	if (g_duelActive && is_user_alive(id) && (id == g_captain[0] || id == g_captain[1]))
	{
		strip_user_weapons(id);
		give_item(id, "weapon_knife");
	}
}

public fw_curweapon(id)
{
	if (!g_duelActive || (id != g_captain[0] && id != g_captain[1])) return;
	if (get_user_weapon(id) != CSW_KNIFE) engclient_cmd(id, "weapon_knife");
}

public fw_killed(victim, attacker, shouldgib)
{
	if (!g_duelActive) return;
	if (victim != g_captain[0] && victim != g_captain[1]) return;
	if (attacker != g_captain[0] && attacker != g_captain[1]) return;

	g_duelActive = false;
	g_duelWinner = attacker;
	new n[32];
	get_user_name(attacker, n, charsmax(n));
	cs_msg(0, PFX_MATCH, "%s specheli duela i izbira purvi! / wins the duel and picks first!", n);
	set_task(2.0, "task_begindraft");
}

public task_begindraft()
{
	g_pickTurn = (g_duelWinner == g_captain[1]) ? 1 : 0;
	show_pick_menu();
}

show_pick_menu()
{
	if (!g_draftActive) return;
	if (g_poolNum <= 0) { finish_draft(); return; }

	if (g_poolNum == 1)
	{
		g_pickTurn = (team_count(CS_TEAM_T) <= team_count(CS_TEAM_CT)) ? 0 : 1;
		do_pick(g_pool[0]);
		return;
	}

	new id = g_captain[g_pickTurn];
	if (!is_user_connected(id)) { auto_pick(); return; }

	new menu = menu_create("\yIzberi igrach / Pick a player:", "h_pick");
	new info[8], name[32];
	for (new i = 0; i < g_poolNum; i++)
	{
		get_user_name(g_pool[i], name, charsmax(name));
		format(name, charsmax(name), "%s \d(%d)", name, cs_get_rating(g_pool[i]));
		num_to_str(g_pool[i], info, charsmax(info));
		menu_additem(menu, name, info);
	}
	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
	menu_display(id, menu);

	remove_task(TASK_PICK);
	set_task(float(get_pcvar_num(g_cvPickTime)), "task_autopick", TASK_PICK);
	cs_hud(0, 2.0, "DRAFT - %d", get_pcvar_num(g_cvPickTime));
}

public h_pick(id, menu, item)
{
	if (item < 0 || !g_draftActive || id != g_captain[g_pickTurn])
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	new info[8], access, cb;
	menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, cb);
	menu_destroy(menu);
	remove_task(TASK_PICK);

	new picked = str_to_num(info);
	if (!in_pool(picked)) { show_pick_menu(); return PLUGIN_HANDLED; }
	do_pick(picked);
	return PLUGIN_HANDLED;
}

public task_autopick()
{
	if (!g_draftActive) return;
	new id = g_captain[g_pickTurn];
	if (is_user_connected(id)) show_menu(id, 0, "^n", 1); // close the open menu
	auto_pick();
}

auto_pick()
{
	new best = g_pool[0], bestR = -99999;
	for (new i = 0; i < g_poolNum; i++)
	{
		new r = cs_get_rating(g_pool[i]);
		if (r > bestR) { bestR = r; best = g_pool[i]; }
	}
	cs_msg(0, PFX_MATCH, "Vremeto izteche - avtomatichen izbor. / Autopick.");
	do_pick(best);
}

do_pick(picked)
{
	for (new i = 0; i < g_poolNum; i++)
		if (g_pool[i] == picked) { g_pool[i] = g_pool[--g_poolNum]; break; }

	if (is_user_connected(picked))
		cs_set_user_team(picked, g_pickTurn == 0 ? CS_TEAM_T : CS_TEAM_CT);

	new pn[32], cn[32];
	get_user_name(picked, pn, charsmax(pn));
	get_user_name(g_captain[g_pickTurn], cn, charsmax(cn));
	cs_msg(0, PFX_MATCH, "%s izbra / picked %s", cn, pn);

	if (g_poolNum <= 0) { finish_draft(); return; }
	g_pickTurn = 1 - g_pickTurn;
	show_pick_menu();
}

finish_draft()
{
	g_draftActive = false;
	remove_task(TASK_PICK);
	cs_msg(0, PFX_MATCH, "Otborite sa potvurdeni! / Teams confirmed!");
	cs_set_state(MS_WARMUP);
}

public client_disconnected(id)
{
	if (!g_draftActive) return;
	for (new i = 0; i < g_poolNum; i++)
		if (g_pool[i] == id) { g_pool[i] = g_pool[--g_poolNum]; break; }
	if (g_duelActive && (id == g_captain[0] || id == g_captain[1]))
	{
		g_duelActive = false;
		g_duelWinner = (id == g_captain[0]) ? g_captain[1] : g_captain[0];
		set_task(1.0, "task_begindraft");
	}
}

public cmd_draftstatus(id)
{
	if (g_duelActive) cs_msg(id, PFX_MATCH, "Nojova duel v momenta. / Knife duel in progress.");
	else if (g_draftActive) cs_msg(id, PFX_MATCH, "Draft: %d igrachi ostavat / players left.", g_poolNum);
	else cs_msg(id, PFX_MATCH, "Nyama aktiven draft. / No draft running.");
	return PLUGIN_HANDLED;
}

bool:in_pool(id)
{
	for (new i = 0; i < g_poolNum; i++) if (g_pool[i] == id) return true;
	return false;
}

team_count(CsTeams:team)
{
	new n;
	for (new i = 1; i <= 32; i++)
		if (is_user_connected(i) && cs_get_user_team(i) == team) n++;
	return n;
}
