// CS16 Platform - jumpstats: LongJump distance, prestrafe, strafes, sync. /ljstats toggles.
#include <amxmodx>
#include <fakemeta>
#include <cs16_core>

#define PLUGIN  "cs16_jumpstats"
#define VERSION "0.1.0"

#define MIN_LJ 215.0
#define MAX_LJ 275.0

new bool:g_on[33] = { true, ... };
new bool:g_inAir[33], bool:g_wasGround[33];
new Float:g_takeoff[33][3];
new Float:g_pre[33];
new g_strafes[33], g_lastDir[33];
new g_frames[33], g_syncFrames[33];
new Float:g_lastSpeed[33];
new bool:g_dirty[33];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, "CS16 Platform");
	register_forward(FM_PlayerPreThink, "fw_prethink");
	register_clcmd("say /ljstats", "cmd_toggle");
	register_clcmd("say .ljstats", "cmd_toggle");
}

public client_putinserver(id) { g_on[id] = true; g_inAir[id] = false; }

public cmd_toggle(id)
{
	g_on[id] = !g_on[id];
	cs_msg(id, PFX_RECORD, "JumpStats %s", g_on[id] ? "ON" : "OFF");
	return PLUGIN_HANDLED;
}

Float:hspeed(id)
{
	new Float:v[3];
	pev(id, pev_velocity, v);
	return floatsqroot(v[0] * v[0] + v[1] * v[1]);
}

public fw_prethink(id)
{
	if (!is_user_alive(id)) return FMRES_IGNORED;

	new flags = pev(id, pev_flags);
	new bool:ground = (flags & FL_ONGROUND) != 0;
	new buttons = pev(id, pev_button);

	if (g_wasGround[id] && !ground && (buttons & IN_JUMP))
	{
		// takeoff
		pev(id, pev_origin, g_takeoff[id]);
		g_pre[id] = hspeed(id);
		g_inAir[id] = true;
		g_strafes[id] = 0; g_lastDir[id] = 0;
		g_frames[id] = 0; g_syncFrames[id] = 0;
		g_lastSpeed[id] = g_pre[id];
		g_dirty[id] = false;
	}
	else if (g_inAir[id] && !ground)
	{
		new dir = 0;
		if (buttons & IN_MOVELEFT) dir = 1;
		else if (buttons & IN_MOVERIGHT) dir = 2;
		if (dir && dir != g_lastDir[id]) { g_strafes[id]++; g_lastDir[id] = dir; }

		new Float:sp = hspeed(id);
		g_frames[id]++;
		if (sp > g_lastSpeed[id]) g_syncFrames[id]++;
		g_lastSpeed[id] = sp;

		if (pev(id, pev_movetype) != MOVETYPE_WALK || (flags & FL_INWATER)) g_dirty[id] = true;
	}
	else if (g_inAir[id] && ground)
	{
		g_inAir[id] = false;
		land(id);
	}

	g_wasGround[id] = ground;
	return FMRES_IGNORED;
}

land(id)
{
	if (g_dirty[id] || !g_on[id]) return;
	new Float:o[3];
	pev(id, pev_origin, o);
	if (floatabs(o[2] - g_takeoff[id][2]) > 1.0) return;   // LJ only: same height

	new Float:dx = o[0] - g_takeoff[id][0], Float:dy = o[1] - g_takeoff[id][1];
	new Float:dist = floatsqroot(dx * dx + dy * dy) + 32.0;
	if (dist < MIN_LJ || dist > MAX_LJ) return;

	new sync = g_frames[id] ? (g_syncFrames[id] * 100 / g_frames[id]) : 0;
	new name[32];
	get_user_name(id, name, charsmax(name));
	cs_msg(id, PFX_RECORD, "LJ %.2f | Pre %.1f | Strafes %d | Sync %d%%", dist, g_pre[id], g_strafes[id], sync);
	if (dist >= 250.0)
		cs_msg(0, PFX_RECORD, "%s jumped %.2f LJ!", name, dist);
}
