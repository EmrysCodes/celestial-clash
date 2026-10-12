# Seraph Arena — Design (Angel Arena–faithful)

Spiritual successor to Warcraft III *Angel Arena* / *Angel Arena Allstars* (Youkaiz → BLOKKADE lineage).  
Original names and art. Not a Blizzard asset remake.

**Canonical living GDD:** [GDD.md](GDD.md) — research synthesis, art bible, WC3-mobile HUD, dual controls, milestones.

## What Angel Arena actually is

From the classic TFT maps and the Allstars remake, the formula is:

1. **Pick a hero** (or random) at your team tavern.
2. **Leave base** with a starter shop; farm **creep camps** for huge gold/XP.
3. **Every hero death costs the team a life.** First team to **0 lives** loses.
4. **Scheduled duels** yank heroes into an arena. The losing team loses several lives; winners get a gold/XP spike.
5. **Progression gates:** easy camps near base → medium/hard camps → **mid boss** → **god / ascension** and a **secret shop** of absurd late items.
6. Sessions are long grind-fests; winning is often secondary to getting disgustingly geared.

Older “Devil vs Angel” variants also used kill-count wins and secret-shop cheats; **Allstars’ lives + duels + god taverns** is the durable modern formula we follow.

## v0.2 phone slice (scaled, same soul)

| Classic AA | Seraph Arena v0.2 |
|------------|-------------------|
| 20 lives × players | **12 lives** per team (short match) |
| Duels every 5–15 min (−5 lives) | Duels every **75s** (−3 lives); winners get gold/XP |
| 70+ heroes, 30+ gods | **4 starters**, **1 God Ascension** after mid boss |
| 700+ creeps, many bosses | Tiered camps: Easy / Medium / Hard / **Mid Boss** |
| Base + mid + secret shops | Same three tiers (original item names) |
| 5v5–6v6 | **You + 1 ally bot vs 2 enemy bots** |

## Map zones

```
[ Angel Base + Base Shop + Easy Camps ]
              |
        Medium Camps (sides)
              |
   [ Mid Boss ] [ Duel Ring ] [ Mid Shop ]
              |
        Hard Camps + Secret Shop (after boss)
              |
[ Ashen Base + Base Shop + Easy Camps ]
```

## Match flow

```
Hero select → Spawn at fountain
     → Farm easy camps / buy starter gear
     → Contest medium/hard camps & gank
     → DUEL (forced) → lives swing + gold spike
     → Kill Mid Boss → unlock God Ascension + Secret Shop
     → Keep farming / dueling until one team hits 0 lives
```

## Online-ready architecture

```
Touch / Keyboard / BotAI
        |
        v
  InputCommand dict
        |
        v
     NetBridge  (future: WebRTC / dedicated server)
        |
        v
  MatchController (authority: lives, duels, camps, shops)
        |
        v
   CombatUnit state
```

UI and bots never mutate combat directly — only `NetBridge.submit_command()`.

## Roadmap after v0.2

- Larger roster + multiple gods  
- Item recipes / boss drop crafting  
- Deathmatch statues  
- True multiplayer through NetBridge  
- Richer Xogot art / animations  
