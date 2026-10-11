// CS16 Platform - rating_system (Glicko-2, per mode, nVault storage for now; MySQL later)
// score = 75% match result + 25% performance
// rules: participation scaling, anti-derank floor (half of season peak), reduced loss at low rating
#include <amxmodx>
#include <cstrike>
#include <nvault>
#include <cs16_core>

#define PLUGIN  "cs16_rating"
#define VERSION "0.1.0"

#define SCALE 173.7178
#define TAU   0.5
#define LOW_RATING 1200.0

new g_vault = INVALID_HANDLE;
new Float:g_r[33], Float:g_rd[33], Float:g_vol[33], Float:g_peak[33];
new g_games[33];
new Float:g_joinLive[33];
new Float:g_liveStart;
new bool:g_played[33];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, "CS16 Platform");
	register_dictionary("cs16.txt");
	g_vault = nvault_open("cs16_rating");
	new const cmds[][] = { "say /rank", "say !rank", "say .rank", "say_team /rank", "say_team !rank", "say_team .rank" };
	for (new i = 0; i < sizeof(cmds); i++) register_clcmd(cmds[i], "cmd_rank");
}

public plugin_end() if (g_vault != INVALID_HANDLE) nvault_close(g_vault);

key_for(id, out[], len)
{
	new auth[35], mname[16];
	get_user_authid(id, auth, charsmax(auth));
	cs_get_mode_name(cs_get_mode(), mname, charsmax(mname));
	formatex(out, len, "%s_%s", auth, mname);
}

load(id)
{
	g_r[id] = 1500.0; g_rd[id] = 350.0; g_vol[id] = 0.06; g_peak[id] = 1500.0; g_games[id] = 0;
	if (g_vault == INVALID_HANDLE) return;
	new key[64], val[96];
	key_for(id, key, charsmax(key));
	if (!nvault_get(g_vault, key, val, charsmax(val))) return;
	new a[16], b[16], c[16], d[16], e[16];
	parse(val, a, 15, b, 15, c, 15, d, 15, e, 15);
	g_r[id] = str_to_float(a); g_rd[id] = str_to_float(b); g_vol[id] = str_to_float(c);
	g_peak[id] = str_to_float(d); g_games[id] = str_to_num(e);
}

save(id)
{
	if (g_vault == INVALID_HANDLE) return;
	new key[64], val[96];
	key_for(id, key, charsmax(key));
	formatex(val, charsmax(val), "%.2f %.2f %.5f %.2f %d", g_r[id], g_rd[id], g_vol[id], g_peak[id], g_games[id]);
	nvault_set(g_vault, key, val);
}

public cs_on_state_change(oldstate, newstate)
{
	if (newstate != MS_LIVE) return;
	g_liveStart = get_gametime();
	for (new i = 1; i <= 32; i++)
	{
		g_played[i] = false;
		if (!is_user_connected(i)) continue;
		new t = _:cs_get_user_team(i);
		if (t == 1 || t == 2) { g_played[i] = true; g_joinLive[i] = g_liveStart; load(i); }
	}
}

public client_putinserver(id)
{
	g_played[id] = false;
	if (cs_get_state() == MS_LIVE) { g_joinLive[id] = get_gametime(); g_played[id] = true; load(id); }
}

Float:fexp(Float:x) return floatpower(2.718281828, x);
Float:fln(Float:x) return floatlog(x, 2.718281828);

Float:vol_f(Float:x, Float:delta2, Float:phi2, Float:v, Float:a)
{
	new Float:ex = fexp(x);
	new Float:top = ex * (delta2 - phi2 - v - ex);
	new Float:bot = 2.0 * floatpower(phi2 + v + ex, 2.0);
	return top / bot - (x - a) / (TAU * TAU);
}

// One Glicko-2 period against an averaged opponent
glicko(id, Float:oppR, Float:oppRD, Float:s)
{
	new Float:mu = (g_r[id] - 1500.0) / SCALE;
	new Float:phi = g_rd[id] / SCALE;
	new Float:muj = (oppR - 1500.0) / SCALE;
	new Float:phij = oppRD / SCALE;

	new Float:g = 1.0 / floatsqroot(1.0 + 3.0 * phij * phij / (M_PI * M_PI));
	new Float:E = 1.0 / (1.0 + fexp(-g * (mu - muj)));
	new Float:v = 1.0 / (g * g * E * (1.0 - E));
	new Float:delta = v * g * (s - E);

	// volatility (Illinois algorithm)
	new Float:sigma = g_vol[id];
	new Float:a = fln(sigma * sigma);
	new Float:phi2 = phi * phi, Float:delta2 = delta * delta;
	new Float:A = a, Float:B;
	if (delta2 > phi2 + v) B = fln(delta2 - phi2 - v);
	else
	{
		new k = 1;
		while (vol_f(a - float(k) * TAU, delta2, phi2, v, a) < 0.0 && k < 50) k++;
		B = a - float(k) * TAU;
	}
	new Float:fA = vol_f(A, delta2, phi2, v, a), Float:fB = vol_f(B, delta2, phi2, v, a);
	for (new it = 0; it < 30 && floatabs(B - A) > 0.000001; it++)
	{
		new Float:C = A + (A - B) * fA / (fB - fA);
		new Float:fC = vol_f(C, delta2, phi2, v, a);
		if (fC * fB < 0.0) { A = B; fA = fB; }
		else fA = fA / 2.0;
		B = C; fB = fC;
	}
	new Float:newSigma = fexp(A / 2.0);

	new Float:phiStar = floatsqroot(phi2 + newSigma * newSigma);
	new Float:newPhi = 1.0 / floatsqroot(1.0 / (phiStar * phiStar) + 1.0 / v);
	new Float:newMu = mu + newPhi * newPhi * g * (s - E);

	return _:(newMu * SCALE + 1500.0) * 0 + _:newPhi * 0 + set_result(id, newMu * SCALE + 1500.0, newPhi * SCALE, newSigma);
}

set_result(id, Float:r, Float:rd, Float:vol)
{
	g_r[id] = r; g_rd[id] = rd; g_vol[id] = vol;
	return 0;
}

public cs_on_match_end(winner, match_id)
{
	if (!cs_feature_enabled("rating") || !cs_is_ranked() || winner < 0) return;

	new Float:now = get_gametime();
	new Float:total = now - g_liveStart;
	if (total < 1.0) total = 1.0;

	// team averages (before update)
	new Float:sumR[3], Float:sumRD[3], cnt[3];
	for (new i = 1; i <= 32; i++)
	{
		if (!g_played[i] || !is_user_connected(i)) continue;
		new t = _:cs_get_user_team(i);
		if (t != 1 && t != 2) continue;
		sumR[t] += g_r[i]; sumRD[t] += g_rd[i]; cnt[t]++;
	}
	if (!cnt[1] || !cnt[2]) return;

	for (new i = 1; i <= 32; i++)
	{
		if (!g_played[i] || !is_user_connected(i)) continue;
		new t = _:cs_get_user_team(i);
		if (t != 1 && t != 2) continue;
		new o = 3 - t;

		new Float:result = (winner == 0) ? 0.5 : (winner == t ? 1.0 : 0.0);
		new Float:s = 0.75 * result + 0.25 * cs_get_perf(i);
		new Float:before = g_r[i];
		glicko(i, sumR[o] / float(cnt[o]), sumRD[o] / float(cnt[o]), s);

		// participation scaling
		new Float:part = (now - g_joinLive[i]) / total;
		if (part > 1.0) part = 1.0;
		if (part < 0.0) part = 0.0;
		new Float:diff = (g_r[i] - before) * part;

		// reduced loss at low rating
		if (diff < 0.0 && before < LOW_RATING) diff *= 0.5;

		g_r[i] = before + diff;

		// anti-derank floor
		if (g_r[i] < g_peak[i] * 0.5) g_r[i] = g_peak[i] * 0.5;
		if (g_r[i] > g_peak[i]) g_peak[i] = g_r[i];
		g_games[i]++;
		save(i);

		cs_msg(i, PFX_MATCH, "%L", i, "CS_RATING_CHANGE", g_r[i], diff >= 0.0 ? "+" : "", diff);
	}
}

public cmd_rank(id)
{
	load(id);
	new mname[16];
	cs_get_mode_name(cs_get_mode(), mname, charsmax(mname));
	cs_msg(id, PFX_SYSTEM, "%L", id, "CS_RATING_SHOW", mname, g_r[id], g_rd[id], g_games[id]);
	return PLUGIN_HANDLED;
}
