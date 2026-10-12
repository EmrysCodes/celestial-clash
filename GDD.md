# Seraph Arena — Game Design Document

**Version:** 1.0  
**Status:** Living document — source of truth for build decisions  
**Platform:** Xogot / Godot 4.4 (iPhone first, desktop OK)  
**Inspiration:** Warcraft III *Angel Arena* / *Angel Arena Allstars* (Youkaiz → BLOKKADE)  
**IP:** Original names, art, audio. Spiritual successor — not a Blizzard remake.

---

## 1. Research synthesis (what Angel Arena *is*)

### 1.1 Genre DNA
Angel Arena is a **team hero arena + farming RPG**, not a MOBA lane game and not a pure deathmatch.

| Pillar | Classic AA behavior | Player fantasy |
|--------|---------------------|----------------|
| Grind | Kill endless creep camps for absurd gold/XP | “I’m getting disgusting” |
| Gear | Base → mid → secret shops; recipes / fusions | Build identity through items |
| Lives | Hero death drains **team lives**; 0 = lose (4v4 phone slice = 20/side) | Every death matters to the squad |
| Duels | Forced mid fights on a timer; losers lose several lives | Spikes of PvP chaos |
| Ascension | Bosses / taverns unlock **Gods** | Mid→late power fantasy |
| Session | Long (often 60–90+ min on classic maps) | Phone slice is shorter but same loop |

Hive / ENT / wiki consensus and player reviews emphasize: **farming is the game**, duels swing momentum, god forms and late items define the endgame, and the map is Angel/Heaven vs Devil/Ashen themed with distinct biomes (forest camps, ice/gold/death cities in larger Allstars maps).

### 1.2 How it *looks* (visual language)
From screenshots, map pages, and WC3 conventions AA sits on:

- **Engine skin:** Standard TFT/Reforged **bottom HUD** — portrait, HP/MP bars, inventory grid, **command card** abilities.
- **Top chrome:** Resources (gold / lumber), optional multiboard (level, K/D, lives, mode).
- **World:** Top-down / high isometric; dual bases (light north / dark south); dirt paths; mid stone duel ring; creep camps as clear “knots” of monsters; shop buildings as readable landmarks.
- **Units:** Distinct hero silhouettes; creeps by tier; bosses oversized; gold floaters on kill.
- **FX:** Ability flashes, death dissipate, duel teleport, item glitter — readable over dense camps.

Reviews praise **addictive farm→gear loop** and flexible modes; complaints cluster on **balance**, **length**, **lag late game**, and **new-player onboarding**. Our GDD attacks those: clearer objectives HUD, shorter phone match, readable art, tutorial feed.

### 1.3 How it *controls* (classic)
WC3 AA is **RTS-select + click-to-move/attack**:
- Left-click select / ground-move / enemy-attack
- Right-click context (move/attack)
- Ability hotkeys on command card (Q/W/E/R era)
- Inventory clicks for items
- Shops via unit proximity + buy UI

**Seraph Arena mobile translation (this GDD):**
- **Joystick** *and* **tap-to-move** (both always available)
- **Tap enemy** = attack-move / focus target
- **Tap shop / fountain / interactable** = interact
- **Skill buttons** stay on the command strip (never gesture-cast only)
- Optional hold-to-pan is out of scope for v1.1

---

## 2. Vision

> *Farm the wilds. Gear at the stalls. Answer the duel bell. Drain their lives — or ascend and end them.*

Seraph Arena is Angel Arena’s soul on a phone: the grind, the gear climb, the duel spike, the god unlock — with a **WC3-inspired but original mobile HUD** and dual stick/tap controls.

### 2.1 Non-goals (for now)
- Full 70+ hero / 30+ god roster  
- Exact WC3 item recipes / protected-map clones  
- Online matchmaking (architecture reserved via `NetBridge`)  
- Reforged asset reuse  

---

## 3. Core loop

```
Pick hero → Spawn at base shop
    → Farm Easy camps near base
    → Buy starter gear
    → Contest Medium/Hard camps
    → Scheduled DUEL (lives swing + gold/XP)
    → Mid Boss → Secret Shop + God Ascension
    → Keep farming / fighting until enemy lives = 0
```

### 3.1 Win / lose
- Each team starts with **L lives** (phone default **12**).
- Hero death outside duel: **−1 life**.
- Duel loss: **−3 lives** (winners get gold/XP spike).
- First team to **0 lives** loses.

### 3.2 Economy
| Source | Gold | XP |
|--------|------|-----|
| Easy creep | ~45 | ~28 |
| Medium | ~95 | ~55 |
| Hard | ~180 | ~90 |
| Mid Boss | ~900 + unlock | ~400 |
| Hero kill | ~180 | ~70 |
| Duel win share | ~350 | ~120 |

Shops: **Base** (fountain) → **Mid** → **Secret** (after Mid Boss).

---

## 4. Presentation & art direction

### 4.1 Art bible
| Token | Value | Use |
|-------|-------|-----|
| Seraph gold | `#D4AF37` | UI frames, light team, rewards |
| Ashen crimson | `#C45C4A` | Dark team, danger, hard camps |
| Slate void | `#1A222C` | HUD panels, night ground |
| Angel ice | `#8EC5E8` | Light FX, fountain |
| Ember | `#E8923C` | Ability bursts, boss |
| Font | Clean geometric sans in-engine | No Inter/Roboto defaults if custom fonts later |

**Silhouette rules:** Heroes/creeps use **isometric ~2.5D** sprites (WC3 AA camera: 3/4 view, volumetric shading, readable silhouettes). Masters in `assets/sprites/source_iso/`; sheets via `tools/process_iso_sprites.py`. Bosses oversized.

### 4.2 Asset checklist (we draw all original)
- [x] Hero spritesheets idle/walk/attack (Seraph, Ashwalker, Tidebound, Thornwight)
- [x] Creep tier spritesheets (light/dark/elite) + boss scale
- [x] Ability icons (12) + attack + shop
- [x] Item icons (boots/blade/cloak/potion/shield/ring/amulet/tome)
- [x] HUD: bottom bar, portrait bezel, HP/MP tracks, inventory slots, command frames, minimap frame
- [x] Cursors / tap markers: move, attack, interact
- [x] VFX: hit/heal/fire/water/nature/holy bursts, nova/ascend rings, slash, death puff, gold popup
- [x] World props: shop stall, fountain, camp rune rings
- Art generator: `tools/gen_art_kit.py` (re-run anytime to regenerate)

### 4.3 Animation standards
| Anim | Frames | Notes |
|------|--------|-------|
| Idle | 2–4 | Subtle bob / weapon gleam |
| Walk | 4 | Loop; facing 4-way flip/rotate |
| Attack | 3 | Snap then recover |
| Cast | 3 | Glow flash |
| Death | 4 | Fade + particles |
| VFX one-shots | 4–6 | Additive blend |

---

## 5. HUD — “WC3 soul, mobile body”

### 5.1 Layout (portrait phone)

```
┌─────────────────────────────┐
│ Lives | Duel timer | Gold   │  ← top status (multiboard-lite)
│ Objective feed              │
│                    [Minimap]│
│                             │
│         WORLD VIEW          │
│                             │
│      (boss bar if near)     │
├─────────────────────────────┤
│ [Portrait] HP/MP/XP         │  ← WC3-style unit panel
│ STR AGI INT   Inv [ ][ ][ ] │
│               Inv [ ][ ][ ] │
│ Joy    │ ATK │ Q │ E │ R │   │  ← command strip
│ Stick  │ INT │   Shop      │
└─────────────────────────────┘
```

### 5.2 Principles
1. **Portrait + bars** always visible when alive (WC3 familiarity).  
2. **Inventory 2×3** like WC3 hero pack.  
3. **Skills as command-card buttons** with cooldown sweeps.  
4. **Minimap** always on (camps, shops, heroes, boss).  
5. **No full-screen opaque chrome** — world stays playable above the bottom dock.  
6. Thumb reach: stick left, skills right; shop near skills.

### 5.3 Multiboard-lite (top)
Shows: team lives, next duel countdown, player gold, short objective string. Expand later to ally levels.

---

## 6. Controls (v1.1)

| Input | Action |
|-------|--------|
| Virtual joystick | Continuous move |
| Tap empty ground | Move-to point (click-to-move) |
| Tap enemy | Set attack target / chase |
| Tap shop / fountain / NPC | Interact (open shop / heal context) |
| ATK button | Attack current target or nearest hostile in range |
| Q / E / R buttons | Cast ability 1/2/3 |
| Shop button | Toggle shop if in range |
| Double-tap ground | Short dash toward point (optional later) |

**Move marker:** gold X under tap.  
**Attack marker:** crimson sword under target.  
**Interact marker:** cyan hand.

Desktop: WASD + left-click move + right-click attack/interact parity + hotkeys.

---

## 7. Systems map (code)

```
Touch / Click / Keyboard / BotAI
        │
        ▼
  InputCommand { move, move_to, attack, attack_target, ability, buy, interact, shop_toggle }
        │
        ▼
     NetBridge  (online later)
        │
        ▼
  MatchController — lives, duels, camps, boss, shops
        │
        ▼
   CombatUnit + VFX + HUD
```

---

## 8. Content (phone slice)

### 8.1 Heroes (starters)
| ID | Role | Fantasy |
|----|------|---------|
| Seraph | Support/Burst | Holy light, heal, nova |
| Ashwalker | Melee Carry | Dash, burn, inferno form |
| Tidebound | Control Mage | Slow, pull, wave |
| Thornwight | Bruiser | Reflect, root, overgrowth |

Each has a **God name** unlocked at Lv8+ after Mid Boss (stat + ability scaling).

### 8.2 Camps & boss
Easy near bases → Medium sides → Hard near mid → **Mid Boss** north of duel ring.

### 8.3 Items
Base (boots, buckler, blade, crystal, salve) → Mid (Burn Shield, Rapid Strike, Guardian Force, Holy Warfare) → Secret (Overgod’s Armor, Warlock’s Staff, Aether Cleaver) — original implementations of classic AA *fantasy*, not asset copies.

---

## 9. Audio (later)
Placeholder: UI clicks, hit, death, duel bell, shop chime, level-up. Original SFX only.

---

## 10. Milestones

| Milestone | Deliverable |
|-----------|-------------|
| **M0** | Playable lives/duels/camps slice (done) |
| **M1** | GDD + WC3-mobile HUD + click-to-move + art kit v1 ← **current** |
| **M2** | Walk/attack anims for all heroes; VFX pass |
| **M3** | Expanded camp biomes + mid-boss telegraphs |
| **M4** | More heroes / second god path |
| **M5** | Online via NetBridge |

---

## 11. Acceptance criteria (M1)

- [ ] GDD committed and followed  
- [ ] Bottom HUD: portrait, HP/MP/XP, inventory 2×3, skill buttons, ATK, Shop  
- [ ] Top: lives, duel timer, gold, objective  
- [ ] Minimap present  
- [ ] Joystick **and** tap-to-move work together  
- [ ] Tap enemy attacks; tap shop interacts  
- [ ] Original icons/sprites (no WC3 ripped assets)  
- [ ] Cloneable Godot project on GitHub for Xogot  

---

## 12. Open decisions (defaults locked unless we change them)

| Topic | Default |
|-------|---------|
| Match length target | 12–20 min phone |
| Camera | Top-down follow, slight zoom |
| Fog of war | Off (classic AA often clear map) |
| Right-click on desktop | Attack / interact context |
| Lumber resource | Deferred (gold-only phone economy) |

---

*End of GDD v1.0 — update version when systems change.*
