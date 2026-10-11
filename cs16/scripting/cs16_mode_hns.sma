// CS16 Platform - mode_hns (classic Hide'n'Seek, ranked physics untouched)
// T = hiders, CT = seekers. Seekers fail -> hiders keep side; seekers win -> swap.
// HNS Impact = Catches*0.4 + FirstCatch*0.3 + ClutchWins*0.5 + SurvivalSec*0.05 - FirstDie*0.2
#include <amxmodx>
#include <cstrike>
#include <fun>
#include <fakemeta>
#include <hamsandwich>
#include <cs16_core>

#define PLUGIN  "cs16_mode_hns"
#define VERSION "0.1.0"

#define TASK_HIDE 5400

new g_cvHideTime, g_cvWinRounds;
new g_side[33];            // 1 = side A, 2 = side B (fixed for the match)
new g_score[3];
new g_hideLeft;
new bool:g_firstKill, bool:g_firstDeath;
new Float:g_roundStart;
new g_msgScreenFade;

new g_catches[33], g_firstCatch[33], g_clutch[33], g_firstDie[33];
new Float:g_survival[33];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, "CS16 Platform");
	register_dictionary("cs16.txt");
	g_cvHideTime = register_cvar("cs_hns_hidetime", "10");
	g_cvWinRounds = register_cvar("cs_hns_winrounds", "8");

	register_event("HLTV", "ev_new_round", "a", "1=0", "2=0");
	register_logevent("ev_round_start", 2, "1=Round_Start");
	register_logevent("ev_round_end", 2, "1=Round_End");
	register_event("DeathMsg", "ev_death", "a");
	RegisterHam(Ham_Spawn, "player", "fw_spawn_post", 1);
	RegisterHam(Ham_TakeDamage, "player", "fw_takedamage");
	g_msgScreenFade = get_user_msgid("ScreenFade");
}

bool:active()
{
	if (cs_get_mode() != MODE_HNS) return false;
	new st = cs_get_state();
	return (st == MS_WARMUP || st == MS_LIVE);
}

bool:live() return (cs_get_mode() == MODE_HNS && cs_get_state() == MS_LIVE);

public cs_on_state_change(oldstate, newstate)
{
	if (cs_get_mode() != MODE_HNS) return;
	if (newstate == MS_LIVE)
	{
		g_score[1] = g_score[2] = 0;
		for (new i = 1; i <= 32; i++)
		{
			g_catches[i] = g_firstCatch[i] = g_clutch[i] = g_firstDie[i] = 0;
			g_survival[i] = 0.0;
			g_side[i] = 0;
			if (!is_user_connected(i)) continue;
			new t = _:cs_get_user_team(i);
			if (t == 1 || t == 2) g_side[i] = t;   // side A starts as hiders
		}
	}
	else if (newstate == MS_RESULT || newstate == MS_WAITING)
		remove_task(TASK_HIDE);
}

public ev_new_round()
{
	g_firstKill = false;
	g_firstDeath = false;
}

public ev_round_start()
{
	if (!active()) return;
	g_roundStart = get_gametime();
	g_hideLeft = get_pcvar_num(g_cvHideTime);
	for (new i = 1; i <= 32; i++)
		if (is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_CT)
			freeze_seeker(i, true);
	remove_task(TASK_HIDE);
	set_task(1.0, "task_hide", TASK_HIDE, _, _, "b");
}

public task_hide()
{
	if (g_hideLeft > 0)
	{
		cs_hud(0, 1.1, "%L", LANG_PLAYER, "CS_HNS_HIDE", g_hideLeft);
		g_hideLeft--;
		return;
	}
	remove_task(TASK_HIDE);
	for (new i = 1; i <= 32; i++)
		if (is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_CT)
			freeze_seeker(i, false);
	cs_hud(0, 2.0, "%L", LANG_PLAYER, "CS_HNS_GO");
}

freeze_seeker(id, bool:on)
{
	if (on)
	{
		set_pev(id, pev_flags, pev(id, pev_flags) | FL_FROZEN);
		fade(id, 0, 0, 0, 255, true);
	}
	else
	{
		set_pev(id, pev_flags, pev(id, pev_flags) & ~FL_FROZEN);
		fade(id, 0, 0, 0, 0, false);
	}
}

fade(id, r, g, b, a, bool:hold)
{
	message_begin(MSG_ONE_UNRELIABLE, g_msgScreenFade, _, id);
	write_short(hold ? 4096 : 1024);
	write_short(hold ? 4096 : 1024);
	write_short(hold ? 0x0004 : 0x0000);   // FFADE_STAYOUT
	write_byte(r); write_byte(g); write_byte(b); write_byte(a);
	message_end();
}

public fw_spawn_post(id)
{
	if (!is_user_alive(id) || !active()) return HAM_IGNORED;
	set_task(0.1, "task_equip", id);
	return HAM_IGNORED;
}

public task_equip(id)
{
	if (!is_user_alive(id)) return;
	strip_user_weapons(id);
	give_item(id, "weapon_knife");
	if (cs_get_user_team(id) == CS_TEAM_T)
	{
		give_item(id, "weapon_flashbang");
		give_item(id, "weapon_flashbang");
		give_item(id, "weapon_smokegrenade");
	}
}

// hiders cannot damage anyone
public fw_takedamage(victim, inflictor, attacker, Float:dmg, bits)
{
	if (!active() || attacker < 1 || attacker > 32 || attacker == victim)
		return HAM_IGNORED;
	if (cs_get_user_team(attacker) == CS_TEAM_T)
		return HAM_SUPERCEDE;
	return HAM_IGNORED;
}

public ev_death()
{
	if (!live()) return;
	new killer = read_data(1), victim = read_data(2);
	if (is_user_connected(victim) && cs_get_user_team(victim) == CS_TEAM_T)
	{
		g_survival[victim] += get_gametime() - g_roundStart;
		if (!g_firstDeath) { g_firstDie[victim]++; g_firstDeath = true; }
	}
	if (killer != victim && is_user_connected(killer) && cs_get_user_team(killer) == CS_TEAM_CT)
	{
		g_catches[killer]++;
		if (!g_firstKill) { g_firstCatch[killer]++; g_firstKill = true; }
	}
}

public ev_round_end()
{
	if (!live()) return;

	new aliveT, lastT;
	for (new i = 1; i <= 32; i++)
	{
		if (!is_user_alive(i) || cs_get_user_team(i) != CS_TEAM_T) continue;
		aliveT++;
		lastT = i;
		g_survival[i] += get_gametime() - g_roundStart;
	}

	new hidingSide = 0;
	for (new i = 1; i <= 32; i++)
		if (is_user_connected(i) && g_side[i] && cs_get_user_team(i) == CS_TEAM_T) { hidingSide = g_side[i]; break; }
	if (!hidingSide) return;
	new seekingSide = 3 - hidingSide;

	if (aliveT > 0)
	{
		g_score[hidingSide]++;
		if (aliveT == 1) g_clutch[lastT]++;
		cs_msg(0, PFX_MATCH, "%L", LANG_PLAYER, "CS_HNS_HIDERS_WIN", g_score[1], g_score[2]);
	}
	else
	{
		g_score[seekingSide]++;
		cs_msg(0, PFX_MATCH, "%L", LANG_PLAYER, "CS_HNS_SEEKERS_WIN", g_score[1], g_score[2]);
		set_task(0.5, "task_swap");
	}

	new need = get_pcvar_num(g_cvWinRounds);
	if (g_score[1] >= need || g_score[2] >= need)
		finish(g_score[1] >= need ? 1 : 2);
}

public task_swap()
{
	for (new i = 1; i <= 32; i++)
	{
		if (!is_user_connected(i)) continue;
		new CsTeams:t = cs_get_user_team(i);
		if (t == CS_TEAM_T) cs_set_user_team(i, CS_TEAM_CT);
		else if (t == CS_TEAM_CT) cs_set_user_team(i, CS_TEAM_T);
	}
}

Float:impact(id)
{
	return float(g_catches[id]) * 0.4 + float(g_firstCatch[id]) * 0.3 + float(g_clutch[id]) * 0.5
		+ g_survival[id] * 0.05 - float(g_firstDie[id]) * 0.2;
}

finish(winSide)
{
	// performance 0..1 = impact normalised against the best player of the match
	new Float:best = 0.01, mvp;
	for (new i = 1; i <= 32; i++)
		if (is_user_connected(i) && g_side[i] && impact(i) > best) { best = impact(i); mvp = i; }

	for (new i = 1; i <= 32; i++)
	{
		if (!is_user_connected(i) || !g_side[i]) continue;
		new Float:p = impact(i) / best;
		cs_set_perf(i, p < 0.0 ? 0.0 : p);
	}

	if (mvp)
	{
		new name[32];
		get_user_name(mvp, name, charsmax(name));
		cs_msg(0, PFX_MATCH, "MVP: %s (Impact %.1f)", name, best);
	}

	// translate the winning side into the team it is on right now
	new winTeam = 0;
	for (new i = 1; i <= 32; i++)
		if (is_user_connected(i) && g_side[i] == winSide) { winTeam = _:cs_get_user_team(i); break; }
	cs_end_match(winTeam);
}
