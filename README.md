# Seraph Arena

Top-down arena brawler for **Xogot** (iPhone / iPad) and desktop Godot **4.4**.  
Spiritual successor to Warcraft III Angel Arena — lives, camps, duels, shops, god ascension.

**Design source of truth:** [GDD.md](GDD.md)

## Open on your phone (Xogot)

1. Clone this repo with **Working Copy** (or any git client):
   ```text
   https://github.com/EmrysCodes/celestial-clash.git
   ```
2. In **Xogot**, open the cloned folder (the one that contains `project.godot`).
3. Tap **Play**.

### Controls
- **Joystick** (left) *or* **tap ground** to move
- **Tap enemy** to attack / chase
- **Tap shop / fountain** to interact
- **Skill buttons** (Q/E/R) stay on the command card — never gesture-only
- **ATK** / **Shop** on the command strip
- Desktop: **WASD** · **Space** · **Q/E/R** · **F** shop · click world to move/attack

## Remotes

| Remote | URL |
|--------|-----|
| GitHub | https://github.com/EmrysCodes/celestial-clash |
| Origin | https://cursor.com/codebase/joshua-messier/celestial-clash |

## What’s in the project

- **4v4** vs AI (20 team lives)
- WC3-style **Hero Tavern** pick
- Large Angel Arena–style **floating island** map + camps
- Scheduled **duels**, Mid Boss → Secret Shop + Ascension
- Animated isometric heroes + skill particle FX
- WC3-inspired mobile HUD · joystick + tap-to-move · smarter bots

Art kit regenerator: `python3 tools/gen_art_kit.py`  
See [DESIGN.md](DESIGN.md) for rules summary and [GDD.md](GDD.md) for the full design doc.

## Desktop

```bash
git clone https://github.com/EmrysCodes/celestial-clash.git
cd celestial-clash
godot4 --path .
```

Requires **Godot 4.4** (Xogot-compatible).

```bash
# Headless smoke
godot4 --headless --path . -s res://tools/ci_smoke.gd
```
