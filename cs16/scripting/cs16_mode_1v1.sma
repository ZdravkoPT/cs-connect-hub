// CS16 Platform - mode_1v1 (first playable: 1v1 deathmatch, first to N frags)
#include <amxmodx>
#include <cstrike>
#include <fun>
#include <hamsandwich>
#include <cs16_core>

#define PLUGIN  "cs16_mode_1v1"
#define VERSION "0.1.0"

new g_cvFrags, g_cvWeapon;
new g_frags[33];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, "CS16 Platform");
	register_dictionary("cs16.txt");
	g_cvFrags = register_cvar("cs_1v1_frags", "10");
	g_cvWeapon = register_cvar("cs_1v1_weapon", "weapon_ak47");

	register_event("DeathMsg", "ev_death", "a");
	RegisterHam(Ham_Spawn, "player", "fw_spawn_post", 1);
}

bool:active()
{
	if (cs_get_mode() != MODE_1V1) return false;
	new st = cs_get_state();
	return (st == MS_WARMUP || st == MS_LIVE);
}

public cs_on_state_change(oldstate, newstate)
{
	if (newstate == MS_LIVE && cs_get_mode() == MODE_1V1)
		for (new i = 1; i <= 32; i++) g_frags[i] = 0;
}

public fw_spawn_post(id)
{
	if (!is_user_alive(id) || !active())
		return HAM_IGNORED;
	set_task(0.1, "task_equip", id);
	return HAM_IGNORED;
}

public task_equip(id)
{
	if (!is_user_alive(id)) return;
	new wpn[32];
	get_pcvar_string(g_cvWeapon, wpn, charsmax(wpn));
	strip_user_weapons(id);
	give_item(id, "weapon_knife");
	give_item(id, wpn);
	give_item(id, "weapon_deagle");
	new wid = get_weaponid(wpn);
	if (wid) cs_set_user_bpammo(id, wid, 90);
	cs_set_user_bpammo(id, CSW_DEAGLE, 35);
	cs_set_user_armor(id, 100, CS_ARMOR_VESTHELM);
}

public ev_death()
{
	if (!active()) return;
	new killer = read_data(1), victim = read_data(2);

	if (is_user_connected(victim))
		set_task(1.0, "task_respawn", victim);

	if (cs_get_state() != MS_LIVE || killer == victim || !is_user_connected(killer))
		return;

	g_frags[killer]++;
	new kname[32];
	get_user_name(killer, kname, charsmax(kname));
	cs_hud(0, 2.0, "%s  %d / %d", kname, g_frags[killer], get_pcvar_num(g_cvFrags));

	if (g_frags[killer] >= get_pcvar_num(g_cvFrags))
	{
		new loserFrags = is_user_connected(victim) ? g_frags[victim] : 0;
		cs_set_perf(killer, 0.5 + 0.5 * float(g_frags[killer] - loserFrags) / float(g_frags[killer]));
		if (is_user_connected(victim))
			cs_set_perf(victim, 0.5 * float(loserFrags) / float(g_frags[killer]));
		cs_msg(0, PFX_MATCH, "%L", LANG_PLAYER, "CS_1V1_WIN", kname, g_frags[killer], loserFrags);
		cs_end_match(_:cs_get_user_team(killer));
	}
}

public task_respawn(id)
{
	if (!is_user_connected(id) || is_user_alive(id) || !active()) return;
	new CsTeams:t = cs_get_user_team(id);
	if (t == CS_TEAM_T || t == CS_TEAM_CT)
		ExecuteHamB(Ham_CS_RoundRespawn, id);
}
