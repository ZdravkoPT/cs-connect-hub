// CS16 Platform - core API (server_core / Match Director)
// Every module talks to the core only through these natives and forwards.
#if defined _cs16_core_included
	#endinput
#endif
#define _cs16_core_included

#pragma reqlib cs16_core
#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib cs16_core
#endif

// Match states
enum
{
	MS_WAITING = 0,
	MS_QUEUE,
	MS_WARMUP,
	MS_LO3,
	MS_LIVE,
	MS_PAUSED,
	MS_RESULT,
	MS_COUNT
};

// Modes
enum
{
	MODE_NONE = 0,
	MODE_1V1,
	MODE_HNS,
	MODE_KZ,
	MODE_COUNT
};

// Message prefixes
enum
{
	PFX_LOBBY = 0,
	PFX_MATCH,
	PFX_QUEUE,
	PFX_RECORD,
	PFX_SYSTEM
};

native cs_get_state();
native cs_set_state(newstate);
native cs_get_mode();
native cs_set_mode(mode);
native cs_get_match_id();
native cs_is_ranked();
native cs_feature_enabled(const flag[]);   // reads cvar cs_enable_<flag>
native cs_end_match(winner_team);          // 1 = T, 2 = CT, 0 = draw
native cs_get_state_name(st, out[], len);
native cs_get_mode_name(md, out[], len);

// Message / HUD manager (single owner of chat prefixes and the main HUD channel)
native cs_msg(id, prefix, const fmt[], any:...);
native cs_hud(id, Float:hold, const fmt[], any:...);

// Performance score 0.0 - 1.0 for the current match (rating uses it as 25%)
native cs_set_perf(id, Float:value);
native Float:cs_get_perf(id);

forward cs_on_state_change(oldstate, newstate);
forward cs_on_match_end(winner_team, match_id);
