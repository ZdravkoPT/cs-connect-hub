// CS16 Platform - map vote after every match + /rtv in lobby. Maps from configs/cs16_maps.ini
#include <amxmodx>
#include <amxmisc>
#include <cs16_core>

#define PLUGIN  "cs16_mapvote"
#define VERSION "0.1.0"
#define MAX_MAPS 64
#define VOTE_MAPS 5

new g_maps[MAX_MAPS][32], g_mapCount;
new g_choice[VOTE_MAPS], g_votes[VOTE_MAPS];
new bool:g_voting, bool:g_rtv[33];
new g_menu;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, "CS16 Platform");
	register_clcmd("say /rtv", "cmd_rtv");
	register_clcmd("say rtv", "cmd_rtv");
	register_clcmd("say .rtv", "cmd_rtv");
	register_concmd("cs_mapvote", "cmd_force", ADMIN_MAP, "- start a map vote now");
}

public plugin_cfg()
{
	new path[128], line[64], cur[32];
	get_configsdir(path, charsmax(path));
	add(path, charsmax(path), "/cs16_maps.ini");
	get_mapname(cur, charsmax(cur));
	new f = fopen(path, "rt");
	if (!f) { log_amx("[MAPVOTE] %s missing", path); return; }
	while (!feof(f) && g_mapCount < MAX_MAPS)
	{
		fgets(f, line, charsmax(line));
		trim(line);
		if (!line[0] || line[0] == ';' || equali(line, cur) || !is_map_valid(line)) continue;
		copy(g_maps[g_mapCount++], 31, line);
	}
	fclose(f);
}

public client_disconnected(id) g_rtv[id] = false;

public cmd_rtv(id)
{
	new st = cs_get_state();
	if (g_voting || (st != MS_WAITING && st != MS_QUEUE)) return PLUGIN_HANDLED;
	g_rtv[id] = true;
	new n, total = get_playersnum();
	for (new i = 1; i <= 32; i++) if (g_rtv[i]) n++;
	new need = (total * 6 + 9) / 10;
	if (need < 1) need = 1;
	cs_msg(0, PFX_LOBBY, "RTV %d/%d", n, need);
	if (n >= need) start_vote();
	return PLUGIN_HANDLED;
}

public cmd_force(id, level, cid)
{
	if (cmd_access(id, level, cid, 1)) start_vote();
	return PLUGIN_HANDLED;
}

public cs_on_match_end(winner, match_id) set_task(2.0, "start_vote");

public start_vote()
{
	if (g_voting || g_mapCount == 0) return;
	g_voting = true;

	new used[MAX_MAPS], n = min(VOTE_MAPS, g_mapCount);
	for (new i = 0; i < n; i++)
	{
		new r;
		do { r = random(g_mapCount); } while (used[r]);
		used[r] = 1;
		g_choice[i] = r;
		g_votes[i] = 0;
	}

	g_menu = menu_create("\yNext map:", "menu_vote");
	new info[4];
	for (new i = 0; i < n; i++)
	{
		num_to_str(i, info, charsmax(info));
		menu_additem(g_menu, g_maps[g_choice[i]], info);
	}
	menu_setprop(g_menu, MPROP_EXIT, MEXIT_NEVER);
	for (new i = 1; i <= 32; i++)
		if (is_user_connected(i) && !is_user_bot(i)) menu_display(i, g_menu);

	cs_msg(0, PFX_LOBBY, "Map vote started (15 s)");
	set_task(15.0, "end_vote");
}

public menu_vote(id, menu, item)
{
	if (item < 0 || !g_voting) return PLUGIN_HANDLED;
	new info[4], acc, cb;
	menu_item_getinfo(menu, item, acc, info, charsmax(info), _, _, cb);
	g_votes[str_to_num(info)]++;
	return PLUGIN_HANDLED;
}

public end_vote()
{
	g_voting = false;
	for (new i = 1; i <= 32; i++) { g_rtv[i] = false; if (is_user_connected(i)) show_menu(i, 0, "^n", 1); }
	menu_destroy(g_menu);

	new best = 0, n = min(VOTE_MAPS, g_mapCount);
	for (new i = 1; i < n; i++) if (g_votes[i] > g_votes[best]) best = i;
	new map[32];
	copy(map, charsmax(map), g_maps[g_choice[best]]);
	cs_msg(0, PFX_LOBBY, "Next map: ^4%s^1 (%d votes)", map, g_votes[best]);
	set_task(cs_get_state() == MS_RESULT ? 9.0 : 4.0, "do_change", 0, map, sizeof(map));
}

public do_change(const map[])
{
	new st = cs_get_state();
	if (st == MS_LIVE || st == MS_LO3) return;   // never change during a live match
	server_cmd("changelevel %s", map);
}
