# CS Connect Hub

Hello see this 
Да. Нека това стане последното уточняване на спецификацията. След него приемаме проекта като заключен и започваме реалната имплементация стъпка по стъпка.

Прегледах и последния файл с допълненията — ще го третирам като част от финалната спецификация.

🔒 FINAL SPECIFICATION — CS 1.6 MATCHMAKING PLATFORM

1. Технологична основа

Фиксирана локална директория:

C:\Users\levak\Downloads\CS16-Server

Архитектура:

Windows 11
 └── HLDS
      ├── ReHLDS
      ├── ReGameDLL_CS
      ├── Metamod-R
      ├── AMX Mod X
      ├── ReAPI
      ├── MySQL
      └── собствена модулна AMXX система

Вече потвърдено:

HLDS работи

ReHLDS 3.15.0.896 работи

ReGameDLL_CS 5.30.0.814 работи

Metamod-R 1.3.0.149 работи

amxmodx_mm.dll съществува

Остава да потвърдим AMX Mod X loading с meta list, amxx version, amxx plugins.

2. Архитектура

Няма да правим един гигантски .sma.

Ще имаме отделни модули:

server_core.sma
database.sma
player_system.sma
account_system.sma
lobby.sma
queue.sma
matchmaking.sma
ready_system.sma
captain_system.sma
knife_duel.sma
draft_system.sma
map_system.sma
team_system.sma
match_state.sma
stats_system.sma
rating_system.sma
record_system.sma
demo_system.sma
spectator_system.sma
reconnect_system.sma
afk_system.sma
substitute_system.sma
admin_system.sma
anti_cheat.sma
chat_system.sma
voice_system.sma
hud_system.sma

И отделни mode engines:

mode_1v1.sma
mode_kz.sma
mode_floppy.sma
mode_bricks.sma
mode_hns.sma
mode_parkour.sma
mode_survival.sma

Match Director / server_core.sma ще бъде централният контролер.

Другите plugins няма да си пречат и ще комуникират чрез natives / forwards / events.

Точното разделяне physics/business/match-state е част от финалната архитектура.

3. Match State Machine

Основната система ще следва:

WAITING
 ↓
PLAYER CHECK
 ↓
QUEUE
 ↓
MODE SELECTION
 ↓
RANKED / UNRANKED
 ↓
READY
 ↓
CAPTAIN SELECTION
 ↓
KNIFE DUEL
 ↓
DRAFT
 ↓
TEAM CONFIRMATION
 ↓
MAP SELECTION
 ↓
MAP VOTE
 ↓
SIDE SELECTION
 ↓
START CHECKLIST
 ↓
MATCH LOCK
 ↓
MATCH
 ↓
RESULT VALIDATION
 ↓
STATS
 ↓
RATING
 ↓
MVP
 ↓
ACHIEVEMENTS
 ↓
RECORDS
 ↓
DEMO
 ↓
HISTORY
 ↓
RESULT SCREEN
 ↓
LOBBY

4. Lobby

Lobby-то ще показва:

текущ брой играчи;

текущ режим;

Ranked / Unranked;

queue;

ready status;

Match ID;

играчи;

капитани;

карта;

отбори;

countdown;

Match State.

Ще има fallback режими при малък брой играчи.

5. Matchmaking

Поддържаме:

1v1
2v2
3v3
5v5

Matchmaking няма да търси само абсолютния най-близък рейтинг.

Ще използва разширяващ се skill window:

acceptable_gap(wait)
=
min(
    base_gap + widen_per_second × wait,
    max_window
)

Това е специално важно за малък player pool.

Ще има:

solo queue;

party queue;

ranked;

unranked;

restricted/low-priority queue;

calibration;

anti-boost логика.

6. Rating System — Glicko-2

Финално:

не обикновен Elo.

Ще използваме:

Rating
RD / Confidence
Volatility

Тоест Glicko-2 модел.

Причината е, че системата трябва да знае не само рейтинга, но и колко сигурни сме в него, особено при играчи с нередовно участие.

Performance component

За HNS:

75% Match Result
25% Performance

Този performance component ще участва контролирано в rating adjustment.

7. HNS Impact Rating

За HNS ще имаме:

Impact =
(Catches × 0.4)
+
(First Catch × 0.3)
+
(Clutch Wins × 0.5)
+
(Survival Seconds × 0.05)
-
(First Die × 0.2)

Това ще се използва за:

MVP;

performance;

статистика;

история;

analytics.

Формулата е запазена точно както е в подадената спецификация.

8. HNS

Основният Ranked HNS:

5v5

Но архитектурата ще позволява:

2v2
3v3
5v5

Основна механика

T = Hiders

CT = Seekers

freeze time;

movement;

knife;

гранати;

tension sound;

periodic sound;

hide knife;

auto team swap при сериен loss;

half-time switch;

clutch;

survival;

catches.

Тези HNS механики са част от финалните идеи.

9. JumpStats / Movement Engine

Ще направим собствен ReAPI-based movement system.

Ще следим:

LongJump
WeirdJump
CountJump
BhopInDuck
DuckBhop
LadderJump
...

И:

distance
maxspeed
gain
prestrafe
strafes
sync
duck count
air time
gain/loss per strafe

Ще има:

Units;

JumpStats;

segment timer;

PB;

WR;

ghost;

replay;

jump beam;

Block Distance;

Edge Distance;

EdgeBug;

JumpBug.

Списъкът и терминологията ще следват подадената референтна спецификация, но имплементацията ще бъде наша и върху ReAPI.

10. T / CT различен HUD

T:

Units
Distance
Prestrafe
Strafes
Sync
Duck
...

CT:

Prestrafe

Останалата JumpStats информация няма да му spam-ва екрана по време на chase.

11. Boost system

Adaptive Boost Locking:

при валиден player-on-player boost ще стабилизираме хоризонталната скорост за кратък период, за да намалим нежеланото свличане.

12. Ranked Physics

Много важно:

Ranked

Classic CS 1.6 physics
100 FPS cap
standard LJ
zero modified movement physics

Unranked/Fun

може да има:

Wall Jump
Ledge Climb
Parkour

Това разделение е изрично заложено във финалните идеи.

13. Parkour

Отделен:

HNS Parkour / Freerun

с:

wall jump;

ledge grab;

climbing;

sprint animations.

Няма да променя Ranked HNS физиката.

14. KZ / Floppy / Bricks

Ще има отделни mode engines.

KZ:

course;

checkpoints;

timer;

PB;

WR;

segments;

ghost;

records;

validation.

KZ архетипи:

Raceway
Bhop Raceway
Deathtrap
Bungee



При WR:

automatic .dem
↓
metadata
↓
record
↓
player profile



15. Mini Events

При недостатъчно играчи за 5v5:

Catch the Leader
LJ Challenge

и други бъдещи mini-events.



16. Warmup LJ Duel

Докато хората чакат в lobby:

/ljduel

Двама играчи могат да влязат в mini LJ arena.

Всички виждат:

Player A: 248.42 units
Player B: 251.17 units

17. Captain Draft

При competitive match:

captain selection;

knife duel;

draft timer;

autopick;

player scouting.

Mercenary играчите ще имат информация като:

Avg Survival
Winrate
Fav Mode

от последните 3 мача.

18. Bounty

След голям clutch:

BOUNTY

следващия рунд.

CT, който го хване първи:

Coins;

bonus rating offset.



19. Voice

Dynamic Voice Controller:

Lobby

AllTalk

Knife / Halftime / End

AllTalk

Live HNS

Team Only

Clutch

dead players mute-ват според правилата, за да останат footsteps/fall sounds чисти.



20. Spectator Protection

Spectators няма да получават ненужна информация за скритите Hiders.

Ще използваме packet suppression, когато е възможно чрез ReAPI.

Това има две цели:

anti-ghost
+
network optimization



21. Anti-Cheat

Ще имаме няколко слоя:

Real-time checks
+
Movement validation
+
Command frequency
+
Bhop detection
+
Demo analysis
+
Admin investigation

Ще следим например:

suspicious +jump;

+duck;

mwheel patterns;

impossible acceleration;

abnormal movement;

high FPS-related exploits;

speed anomalies.

Но няма автоматично да банваме играч само от един подозрителен сигнал.

22. Demo System

Ranked мачовете ще имат demo.

При важни събития:

Match ID
Player
Timestamp
Event

При WR:

automatic demo
+
metadata

23. Knife / Stab Analytics

При knife hit ще можем да записваме:

Hit distance
Angle
Body part
Ping difference
Hard stab
Blind stab

Това ще влиза в analytics/history.

24. Voice / Chat / HUD

Ще използваме централизирана система:

CromChat
HUD Manager
Message Manager

Префикси:

[LOBBY]
[MATCH]
[QUEUE]
[RECORD]
[SYSTEM]

И няма различни plugins да spam-ват един и същ HUD frame.

25. Commands

Central Command Restriction System.

Например по време на Live:

jointeam
retry
kill
name

могат да бъдат ограничени според Match State.



26. Player Identity

Ще има:

Account
Player ID
SteamID
Name history
Profile

Ranked мачът заключва името, за да няма проблеми с demo/statistics.

27. Accounts / Profiles

Профилът ще съдържа:

Rating
Confidence
Volatility
Rank
Season
Matches
Wins
Losses
Performance
MVP
Records
PB
Achievements
Coins
Clans
Friends
Rivals
Reports
Trust

28. Trust Score

Няма да разчитаме само на:

report count

Ще имаме скрит Trust Score, който може да използва:

reports
admin actions
account age
playtime
behavior
disconnect history

и да влияе върху matchmaking/restrictions според правилата.

29. Restricted Queue

Вместо директен permanent ban при определени нарушения:

Restricted Queue

Например:

AFK;

repeated disconnect;

repeated reports;

leaver behavior.

Може да бъде:

Unranked only
No Coins
No season progression

с постепенно увеличаване на санкцията.



30. Calibration

Нов account:

Placement
+
wide K-factor / confidence adjustment
+
self-test

за ограничаване на smurf ефекта без задължителна телефонна верификация.

31. Reconnect / AFK / Substitute

Ще има:

reconnect timer;

pause;

AFK detection;

penalties;

substitute;

reconnect control;

surrender;

technical timeout.

OpenHNS-style reconnect/substitute концепцията е включена във финалния план.

32. Clans

Ще има:

Clan
Clan members
Clan rating/history
Clan matches
Clan-vs-Clan

Ако два активни clan-а имат 10 играчи:

Clan A 5
vs
Clan B 5

може да се използва отделен Clan Ranked режим.

33. Friends / Rivals

Friends
Rivals
Block/Mute
Match history

34. Coins / Cosmetics

Coins могат да се печелят от:

achievements;

events;

records;

bounty;

milestones.

По-късно:

/knife

с cosmetic knives/models.

CustomShop ще бъде отделен от Match Core.

35. Languages

Player setting:

BG
EN

Чат/HUD ще се сменя индивидуално за играча.



36. NextClient

Optional.

Ако играчът използва NextClient:

advanced HUD
custom UI
custom sounds
killfeed
client features

Vanilla CS 1.6:

fallback

Няма да изискваме NextClient за игра.



37. Admin System

Ще има:

Admin
Watcher
Freelook
Listen
IP information
ESP
Reports
Match control
Demo review
Logs



38. Database

MySQL.

Основни таблици:

accounts
players
elo
ranks
seasons

matches
match_players
match_teams
match_stats
match_events
match_history

clans
clan_members
friends
rivals

achievements
player_achievements

records
map_records
personal_bests
segments
ghost_data

reports
admin_logs
demos
backups

39. API

В бъдеще:

GET /top
GET /profile/{id}
GET /history/{match_id}

read-only публичен API за:

website;

leaderboard;

Discord bot;

overlays.



40. Feature Flags

Всеки голям feature ще може да бъде включван/изключван през:

configs/

Например:

enable_hns = 1
enable_parkour = 0
enable_bounty = 1
enable_nextclient = 1
enable_trust = 1

Така няма да променяме кода всеки път.

Ще има и отделен staging/test режим.

41. Map-specific configuration

Всеки map ще може да има собствен config:

maps/
 ├── hns_floppytown.cfg
 ├── hns_...
 ├── kz_...
 └── ...

Например:

Fall damage
Boost zones
Records
Spawn positions
Pickups
Bounty locations
LJ blocks
Segments

42. Специално за Floppytown

Fall-damage display/regeneration/god timer ще бъде само за Floppytown, както е посочено във финалните идеи.

43. Development Order

Това е най-важната част.

Няма да опитаме да направим всичко наведнъж.

PHASE 1 — Foundation

HLDS
ReHLDS
ReGameDLL
Metamod-R
AMX Mod X
ReAPI

PHASE 2 — Core

server_core
player_system
database
configs
logging

PHASE 3 — Lobby

Lobby
Account
Player lifecycle
Ready
Queue

PHASE 4 — First playable mode

1v1 DM

Това ще бъде първият истински playable vertical slice.

PHASE 5

KZ
Floppy
Bricks
JumpStats
Records
PB
Ghost

PHASE 6

HNS 2v2
HNS 3v3
HNS 5v5

PHASE 7

Glicko-2
Teams
Captain
Knife
Draft
Map vote
Side
Match lock
Stats
MVP
Demo

PHASE 8

Profiles
Friends
Rivals
Clans
Achievements
Coins
Seasons

PHASE 9

Anti-cheat
Trust
Restricted Queue
Parkour
Events
Advanced spectator

PHASE 10

Admin
REST API
Website
Discord
NextClient
Production infrastructure

🔴 И едно правило оттук нататък

Нищо от финалната спецификация няма да се счита за готово само защото сме го написали в кода.

За всеки модул:

WRITE
 ↓
COMPILE
 ↓
INSTALL
 ↓
START SERVER
 ↓
TEST
 ↓
VERIFY
 ↓
NEXT MODULE

Ако нещо не работи — спираме там и го оправяме.

🚀 Започваме

Първо не пишем Matchmaking системата.

Първо доказваме, че AMX Mod X работи.

Стартирай:

C:\Users\levak\Downloads\CS16-Server\server\start_server.bat

В конзолата изпълни:

meta list

след това:

amxx version

след това:

amxx plugins

Прати ми трите резултата.

Ако всичко е наред, следващата ни реална стъпка ще бъде:

server_test.sma → compile → install → load → влизаме в CS 1.6 → получаваме потвърждение в играта.

Това ще бъде първият ни истински plugin и оттам започваме да изграждаме целия сървър.




i want from you too see from paid plugins  / customers ideas for plugins /  hns plugins / hns events /  youtube videos ideas / plugins from all forums for cs 1.6 to give me new ideas for my project

This project was built with [Lovable](https://lovable.dev).

## Build with Lovable

Continue developing this project in the [Lovable editor](https://lovable.dev/projects/6e3505f5-b42c-484e-87e1-d5679f83a346).

- **Ship faster**: describe what you want to build and Lovable handles the code.
- **Stay in sync**: every change made in Lovable is committed straight to this repository.
- **Full ownership**: this code is yours. Push to `main` on GitHub and your changes sync back into Lovable, ready for your next prompt.

## Development

Prefer working locally? You need Node.js and npm — [install with nvm](https://github.com/nvm-sh/nvm#installing-and-updating).

```sh
git clone <this-repository-url>
cd <repository-name>
npm i
npm run dev
```
