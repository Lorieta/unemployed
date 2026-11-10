# Tiny Human - Hearthmere & the Thorned Field

A self-contained 2.5D fantasy RPG: a chibi classic fantasy hero built from
primitive meshes, five weapon-specific outfits, five off-hand items, a detailed
procedural walk/run cycle and Souls-style whole-body attacks, a fixed 3/4 follow
camera, a true screen-space mouse cursor, and a classic gilded HUD with vitals,
five assignable skill slots filed into five weapon schools, five item slots,
minimap, story tracker, zone banner, boss bar and satchel.

The adventure now spans one large scene. **Hearthmere** is a lantern town with a
plaza, market, forge and elder's hall. South through the gate lies the **Thorned
Field**, where mosslings, briar wolves and foxfire wisps roam, a cold wayshrine
waits among leaning stones, and the elite **Briar Warden** sleeps until the
shrine is lit. Townsfolk give a main story quest and a side hunt, and two
shopkeepers sell supplies and permanent upgrades.

## Run it

- Press **F5** in Godot (the RPG world is the project's main scene), or
- Open `scenes/world/verdant_reach.tscn` and press **F6**.
- The earlier weapon sandbox remains at `scenes/demo/walk_test.tscn`.

The project renders at **1600 x 900** and scales with the window.

## Controls

| Input | Action |
|---|---|
| **Mouse** | Aim: a gilded screen-space cursor follows the pointer everywhere; a dotted line shows the hero's aim, and the hero turns toward it while standing still |
| **WASD** / **Arrow Keys** | Walk |
| **Shift** | Run |
| **Space** / **Left Mouse Button** | Attack with the equipped weapon |
| **1** - **5** | Use the skill assigned to that slot |
| **Right-click** a skill slot | Open the skill library already pointed at that slot (assign, swap or clear) |
| **K** | Open the skill library to browse all five schools |
| **6** | Drink a Crimson Draught (heals 45) |
| **7** | Drink an Azure Draught (restores 40 mana) |
| **8** | Kindle / smother the pitch torch |
| **9** | Read the Scroll of Return (return to Hearthmere's well) |
| **0** | Inspect the Moonpetal |
| **E** | Speak with a townsperson, light the shrine, or touch the old well |
| **I** | Open / close the satchel and armory |
| **J** | Open the journal |
| **M** | Open the world map |
| **Esc** | Close the satchel or any open overlay |
| **H** | Take test damage (shows the health ghost trail) |
| **U** | Mend 34 health (test key) |

While any overlay or the satchel is open the aim line and aim-facing hide, the
hero stops moving, and incoming damage is suppressed. The cursor itself stays
visible and still tracks the pointer.

Skill slots (`1`-`5`) begin **empty**. Right-click any of them to open the gilded
**Skill Library** already pointed at that slot, or press **K** / the **Skills**
button to browse. Talents are filed into five weapon-school folders.

### Sword - Steel and Step

| Talent | Mana | Cooldown | Effect |
|---|---|---|---|
| **Windstep** | 10 | 4 s | A low, wind-backed dash toward the aim mark |
| **Bulwark** | 8 | 8 s | Set your shoulder and shrug off the next blows |
| **Vanguard Arc** | 18 | 9 s | A full-bodied diagonal cut for 58 damage |

### Bow - Breath and Distance

| Talent | Mana | Cooldown | Effect |
|---|---|---|---|
| **Trueshot** | 14 | 7 s | One arrow drawn past the cheek and sent at the pointer for 48 damage |
| **Steady Aim** | 0 | 10 s | Centre the breath and recover 35 mana |
| **Rain of Arrows** | 26 | 13 s | Five quick shafts in a fan, 22 damage each |

### Staff - Spirit and Stone

| Talent | Mana | Cooldown | Effect |
|---|---|---|---|
| **Spirit Slam** | 20 | 10 s | Drive the crystal down for 48 damage in a 3.7 m shockwave |
| **Mend** | 22 | 12 s | A quiet word over the crystal restores 45 health |
| **Aegis** | 12 | 14 s | Draw a ward that breaks the next blows |

### Dagger - Shadow and Flurry

| Talent | Mana | Cooldown | Effect |
|---|---|---|---|
| **Shadowstep** | 9 | 4.5 s | A short, low dart toward the aim mark |
| **Thistle Flurry** | 16 | 8 s | Three snapping thrusts for 18 damage each |
| **Smoke Veil** | 11 | 11 s | Turn the shoulder to shadow and evade the next blows |

### Kitsune - Foxfire and Return

| Talent | Mana | Cooldown | Effect |
|---|---|---|---|
| **Foxfire** | 20 | 9 s | Send three hovering embers after the nearest foe for 18 damage each |
| **Spirit Mend** | 20 | 12 s | Borrow the fox-spirit's warmth and restore 40 health |
| **Fox Recall** | 16 | 16 s | Step back to the old well in a thread of pale fire |

A talent can only occupy one slot at a time; assigning it elsewhere moves it
rather than duplicating it. Weapons are **not** skills and cannot be placed in
these slots.

Weapons are equipped only through the satchel armory (`I`, then click a weapon in
the right-hand column). Item slots (`6`-`0`) are separate: potions, the torch, the
return scroll and the Moonpetal.

The camera keeps the character centered automatically. Movement happens on the
ground plane while the camera stays at a fixed 3/4 angle, giving the 2.5D look.

## Combat and weapons

All five weapons are defined once in `scenes/player/weapons/weapon_library.gd`.
The satchel armory, journal, HUD weapon label and character read that same
catalogue, so names, classes, stats, icons and animations never drift apart.

| Weapon | Class | Signature | Damage | Recovery | Range | Attack style |
|---|---|---|---|---|---|---|
| Wayfarer's Blade | Longsword | Vanguard Arc | 34 | 0.78 s | 2.9 m | Broad diagonal sweeps with a committed step into the cut |
| Hunting Bow | Longbow | Trueshot | 30 | 1.10 s | 16 m | Raise, draw to the cheek, hold, then loose a real arrow projectile |
| Spiritwood Staff | Quarterstaff | Spirit Slam | 26 | 1.30 s | 3.0 m | Overhead cast, then a ringing ground slam and shockwave |
| Thistle Dagger | Dagger | Thistle Flurry | 16 | 0.66 s | 2.2 m | Two quick snapping thrusts with a low lunge |
| Kitsune Ember | Spirit relic | Foxfire | 12 | 1.20 s | 12 m | A hovering fox-spirit flame that darts three embers at the nearest foe |

Every weapon is a whole different performance, not just a different prop.
Changing weapons also changes the hero's outfit, and every outfit is built once
in `scenes/player/hero_look.gd` as a visibility group hanging off the animated
pivots:

| Weapon | Outfit |
|---|---|
| Sword | Knight - blue tabard under a full steel cuirass, faulds, a winged helm and plate boots |
| Bow | Hunter - green hood and cloak, crossed leather harness, quiver and wrapped boots |
| Staff | Wizard - indigo robe with long sleeves, silver beard and a tall pointed hat |
| Dagger | Rogue - charcoal hood and face wrap, crossed harness, belt knives and soft boots |
| Kitsune | White kimono, vermilion haori and obi, fox ears and a live six-segment tail |

Shared pieces (face, hair and the three-segment cape) are recoloured from the
per-weapon palette, and the cape's size is tuned per outfit, so the silhouette
changes before a foot even moves. The kitsune tail arcs up and back from the
right hip and sways continuously; it gains energy as the hero runs.

### Off-hand arts

All five off-hands are available from the start and are equipped on the
**OFF-HAND** page of the satchel armory. They mount on the left arm with their
own carry and guard poses; the bow and the kitsune need both hands, so the
off-hand is stowed while either is drawn. Each contributes a passive effect:

| Off-hand | Class | Passive |
|---|---|---|
| **Warden's Shield** | Kite shield | Blunts every blow and turns aside far more while guarding |
| **Emberweave Gauntlet** | War glove | Adds fire to melee strikes |
| **Tome of the Verdant** | Grimoire | Strengthens spell and skill damage |
| **Wayfarer's Charm** | Travelling charm | Improves gold and experience gained |
| **Foxfire Lantern** | Spirit lantern | Carries a warm light and steadies the arm |

The shield is the default. The off-hand catalogue lives once in
`scenes/player/offhands/offhand_library.gd`, and both the satchel and the hero
read it.

The gait is data-driven too. `BODY_PROFILES` in
`scenes/player/tiny_human.gd` gives each weapon its own idle, walk and run
posture (hip swing, knee bend, crouch, stance width, sway, roll, lean, twist,
head motion, cape strength and float), plus a locomotion detail layer:

- `step_lift` - how high the swing foot clears the road,
- `heel` / `toe` - heel-strike straightening and toe-off roll,
- `bob` - pelvis rise and fall over each step,
- `weight` - side-to-side weight shift over the planted leg,
- `shoulder_roll` - counter-rotation against the hips,
- `arm_lag` - delayed arm follow-through,
- `flight` - the airborne beat of a sprint,
- `head_stabilize` - how steadily the head holds the horizon.

The `ATTACK_BODY` table gives each one its own lower-body strike: lead leg, hip
and knee drive, planted stance, foot roll, lunge, body yaw, body roll and torso
pitch.

On top of that:

- each weapon has a unique idle, walking and running carry, blended by actual
  speed, plus a wrist-level flourish layered over the body's attack pose;
- a bow that stays upright in the world while the arm raises and draws, with the
  string pulling back and snapping forward;
- a staff crystal that flares as the slam lands;
- a kitsune that hovers above the palm, trails behind a run, then surges forward
  and spins faster during Foxfire;
- a three-segment cape (`CapeRoot` → `CapeUpper`/`CapeMid` → `CapeLower`) that
  follows the gait, streams out in a run, snaps through an attack and flares when
  a skill is cast, with its flare chosen by the skill's pose.

Impacts are sold with matching effects: a gold blade trail for the sword and
dagger, a travelling arrow for the bow, an expanding shockwave for the staff,
and trailing ember wisps for the kitsune.

### Hearthmere and the Thorned Field

The world is one continuous scene, `scenes/world/verdant_reach.tscn`, built
procedurally by `scenes/world/world_builder.gd`. The hero starts by the old well
at the north end of Hearthmere, among the practice dummies.

- **Hearthmere** holds a fountain plaza, market stalls, a smithy, houses, lamps,
  benches, fences and the elder's hall. Elder Rowan waits in the hall, Mira keeps
  the red-awning market stall, Bran works the open forge, Tomas holds the south
  gate, and Nell, Garrick and Wren wander the square.
- **The Thorned Field** begins south of the gate under a ruined arch. Mosslings,
  briar wolves and foxfire wisps patrol the grass and briars; dead trees, rocks
  and bramble walls frame the road. Invisible boundaries keep the play space
  inside the charted Reach.
- **The wayshrine** stands southwest of the field at `(-6, 0, -74)`. It is cold
  until the story reaches it; touching the crystal lights it in green fire.
- **The Warden's Clearing** lies at the far south end. The Briar Warden is
  dormant until the shrine is lit, then wakes with a boss bar and does not
  respawn.

Monsters use one shared script and scene (`monster.gd`/`monster.tscn`) with four
silhouettes. They aggro, chase, strike, show billboard health bars and damage
numbers, drop experience and gold, and respawn after a delay. The Warden is the
exception: one named elite with a much larger health pool and no respawn.

### Quests

The story quest is **The Briar Watch**:

1. **Speak with Elder Rowan** in Hearthmere hall.
2. **Cull 8 beasts** - mosslings or briar wolves - in the Thorned Field.
3. **Return to Rowan** for **180 gold and 700 XP**.
4. **Light the wayshrine** southwest of the field.
5. **Defeat the Briar Warden** in the far clearing.
6. **Return to Rowan** for **320 gold and 1,400 XP**.

Tomas at the south gate offers a side hunt: kill **4 briar wolves**, then return
for **90 gold and 320 XP**. Quest markers (`!`, `?`, `$`) float above the
relevant townsfolk and update as stages advance.

The original Wayfarer tutorial remains intact and is still tracked in the
journal: speak to the Wayfarer, strike the three practice dummies, then claim
**120 gold**.

### Shops

Mira and Bran each open a dedicated gilded counter from their dialogue.

- **Mira's Wares** - Crimson Draughts, Azure Draughts, Waybread and Moonpetal,
  with per-visit limits.
- **Bran's Forge** - Forge Whetstones (**+2 permanent attack power**, limit 4),
  Shield Rivets (**+3% permanent damage reduction**, limit 3), plus draughts and
  waybread.

Purchases deduct gold, update the satchel and quickbar stacks, and reopen the
counter with the new purse. Bran's upgrades are applied directly to the hero and
remain for the rest of the run.

### Falling and recovery

Monster blows route through the HUD, which applies the off-hand's mitigation and
Bran's rivets. At zero health the hero falls, waits a moment, then wakes at the
Hearthmere spawn with **60% health**, **50% mana** and loses up to **40 gold**.
Overlays and the satchel suppress incoming damage so reading a page is safe.

The old well is still interactable and has its own flavour dialogue.

## HUD

- **Upper left** - Portrait, name, level, and class, with crimson health and
  sapphire mana bars. Fleeing health leaves a short gold "wound" ghost behind.
- **Top center** - Zone banner (Hearthmere, Thorned Field, Wayshrine, Warden's
  Clearing) and toast messages.
- **Screen centre** - A true screen-space gilded cursor. It tracks the pointer
  across the whole window; a dotted aim line and the hero's facing follow it
  while standing still. The aim line hides whenever the satchel or an overlay is
  open, but the cursor never does.
- **Upper right** - Live minimap rendered by a top-down orthographic camera that
  shares the game's World3D, framed with a compass rose. The story tracker sits
  beneath it and updates as objectives are completed.
- **Boss bar** - Appears under the zone banner when the Briar Warden wakes,
  showing its name and a crimson health bar. It disappears when the Warden falls.
- **Bottom center** - The action bar: five gilded **skill slots** (hotkeys 1-5)
  divided from five **item slots** (hotkeys 6-0). Skill slots start as empty
  waiting sockets with a faint plus; right-click opens the gilded skill library
  already pointed at that slot, and each slot shows its icon and radial cooldown
  once assigned. The equipped weapon's class and name sit above the bar. Item
  slots are consumables and tools. Weapons have no slot on this bar.
- **Bottom left** - Traveler's notes (controls).
- **Bottom right** - Satchel, journal, skills, map, and settings buttons, with a
  gold and day/dusk panel below. **K** opens the skill library, **J** the
  journal, and **M** the map from anywhere.
- **Satchel window** - A three-column spread: paper-doll equipment and your
  current main hand on the left, a clickable 20-slot item grid with descriptions
  and purse in the middle, and the tabbed **WEAPONS / OFF-HAND** armory with a
  detail card on the right. The armory is the only place weapons and off-hands
  are equipped; clicking a card draws it, and the detail card shows its class,
  signature and effect.
- **Skill library** - A gilded folder view of all fifteen talents, one tab per
  weapon school. Each card shows its tag, mana cost, cooldown and description;
  choosing a card fills the slot that opened the page. A clear button empties it
  again. Browsing from **K** leaves every slot untouched until you pick one.
- **Journal** - The Briar Watch story, the Wayfarer's tutorial errand, Tomas's
  hunt, notes on Hearthmere and the Thorned Field, the five weapon outfits, the
  five off-hands, the five skill schools and the controls.
- **Map** - A live aerial chart of Hearthmere and the Thorned Field that shares
  the game world, with position, current zone and field notes for the plaza,
  gate, field, wayshrine and Warden's Clearing.
- **Shops** - A dedicated gilded counter for Mira and Bran, with stock rows,
  prices, per-visit limits, the current purse, a purchase button and a shop
  ledger note.
- **Settings** - Fullscreen toggle, master volume, control-hint and vignette
  switches, and a restart button. Settings apply immediately.
- **Dialogue** - Framed speaker panel with choice buttons for townsfolk, shops
  and the old well. While any overlay is open, movement, attacks and incoming
  damage are suppressed.

## Character

The hero is a chibi 2.5D adventurer: about **1.47 m** tall with a deliberately
oversized head (roughly 27% of total height). `scenes/player/hero_look.gd`
decorates the rig at runtime, and rebuilds the outfit when `weapon_changed` fires,
so every animation pivot, weapon mount and gait keeps working. The face, hair and
cape are shared and recoloured; the clothes are grouped per weapon:

- **Sword (knight)** - blue tabard over a steel cuirass, brass trim, layered
  faulds, a winged helm, plate arms, knee cops and sabatons.
- **Bow (hunter)** - green hood and cloak, crossed leather harness, a back quiver
  with three arrows, bracers and wrapped boots.
- **Staff (wizard)** - indigo robe with wide sleeves, a hem and sash, a silver
  beard and a tall pointed hat with a brass band.
- **Dagger (rogue)** - charcoal hood and face wrap, crossed harness, twin belt
  knives, strapped bracers and soft boots.
- **Kitsune** - white kimono with a vermilion haori and obi, a gold fox charm,
  fox ears, and a six-segment tail rooted at the right hip that sways constantly
  and gains energy with speed.

The walk cycle is procedural and speed-driven, with a distinct gait per weapon:

- heel strike, flat contact and toe-off around a speed-matched step,
- a clearance lift so the swing toe never clips the ground,
- pelvis bob, side sway and weight shift over the planted leg,
- hip and knee swing with hip yaw, plus counter-rotating shoulders and torso roll,
- delayed arm swing with elbow flex, and a compact run arm carry,
- a sprint flight beat, and a stabilised head with idle look-around.

On top of that locomotion layer sit the per-weapon body profiles
(`BODY_PROFILES`/`BODY_DEFAULTS`) and attack lower-body language
(`ATTACK_BODY`), so changing weapons changes the whole silhouette: how the hero
stands, strides, runs, plants the lead foot, drives the back leg, rolls the hips,
pitches the chest and carries the head. The weapon carry layer
(`CARRY_PROFILES`) then adds grip, elbow and weapon-specific motion. During an
attack the wrist flourish is layered over the full-body strike, so the weapon
keeps its own character even when the shoulders, hips and cape are mid-swing.

After any attack or skill pose the character re-solves hip height from the legs
and samples the boot soles, so a deep lunge or a pitched toe never sinks the feet
through the floor.

## Files

| File | Purpose |
|---|---|
| `scenes/world/verdant_reach.tscn` | **Main scene.** Hearthmere and the Thorned Field, lighting and fog, town props, practice dummies, Wayfarer, townsfolk, shrine, thirteen monsters, character, camera, and HUD |
| `scenes/world/world_builder.gd` | Procedural Hearthmere (roads, plaza, houses, market, smithy, gate, lamps, props) and Thorned Field (ruins, brambles, dead trees, rocks, shrine ring, Warden arena, boundaries) |
| `scenes/world/monster.gd/.tscn` | Shared mossling, briar wolf, foxfire wisp and Briar Warden: AI, health bars, damage numbers, loot, respawn, boss awakening |
| `scenes/world/townsfolk.gd/.tscn` | Palette-driven townsperson builder with role props, name labels, quest markers and look-at-player idle |
| `scenes/world/shrine.gd/.tscn` | Buildable wayshrine with cold/lit states, interaction prompt and HUD hook |
| `scenes/demo/walk_test.tscn` | Earlier weapon sandbox: ground, practice field, Wayfarer, well, character, camera and HUD |
| `scenes/player/tiny_human.tscn` | Reusable chibi character, collision, belt, satchel, weapon mounts, off-hand mount, torch rig, and blade trail |
| `scenes/player/tiny_human.gd` | Movement, aim facing, procedural walk/idle with the expanded gait detail, per-weapon body and carry poses, whole-body attack state machine, data-driven skills, off-hand bonuses, permanent upgrades, damage mitigation, cape, grounding, hit logic, interactions |
| `scenes/player/hero_look.gd` | Five weapon outfits (knight, hunter, wizard, rogue, kitsune) with per-weapon palettes, shared recoloured cape and an animated kitsune tail |
| `scenes/player/weapons/weapon_library.gd` | Shared weapon catalogue: names, classes, signature names, stats, icons, cooldowns, styles |
| `scenes/player/weapons/sword.tscn` | Wayfarer's Blade model |
| `scenes/player/weapons/bow.tscn` | Hunting Bow model with a simulated string |
| `scenes/player/weapons/staff.tscn` | Spiritwood Staff model with a flaring crystal |
| `scenes/player/weapons/dagger.tscn` | Thistle Dagger model |
| `scenes/player/weapons/kitsune.tscn` | Kitsune Ember spirit model |
| `scenes/player/weapons/kitsune_hover.gd` | Hover, spin and surge motion for the kitsune spirit |
| `scenes/player/weapons/projectile.gd` | Arrow and ember projectiles; damages dummies and monsters |
| `scenes/player/weapons/shockwave.gd` | Expanding staff shockwave |
| `scenes/player/weapons/blade_trail.gd` | Sweeping melee trail |
| `scenes/player/offhands/offhand_library.gd` | Five off-hands: names, classes, icons, descriptions, passive bonuses |
| `scenes/player/offhands/*.tscn` | Shield, gauntlet, tome, charm and lantern models |
| `scenes/demo/training_dummy.gd/.tscn` | Target with health, damage numbers, wobble, knockdown, reset |
| `scenes/demo/wayfarer_npc.gd/.tscn` | Wayfarer quest-giver and dialogue anchor |
| `scenes/demo/old_well.gd/.tscn` | Interactable old well |
| `scenes/demo/follow_camera.gd` | Smooth centered camera follow |
| `scenes/hud/hud.tscn` | Main HUD layout, including the screen-space cursor, zone banner and boss bar |
| `scenes/hud/hud.gd` | Vitals, pointer raycast aim, school-folder skill library, combat input, toasts, story and side quests, NPC dialogue, shops, zone/boss tracking, death and recovery, overlays |
| `scenes/hud/skill_library.gd` | Five weapon schools and the fifteen talents, with mana, cooldown, effect, pose and timing data |
| `scenes/hud/skill_list_panel.gd` | Gilded skill-library overlay with one folder tab per school and slot assignment |
| `scenes/hud/aim_reticle.gd` | Full-screen gilded cursor and aim line |
| `scenes/hud/inventory_panel.tscn` | Three-column satchel layout |
| `scenes/hud/inventory_panel.gd` | Equipment, item grid, tabbed weapon/off-hand armory, detail card, item use, gold and item stacks |
| `scenes/hud/shop_panel.gd` | Gilded shop counter with stock, prices, purchase limits, purse and ledger |
| `scenes/hud/overlay_panel.gd` | Shared gilded overlay frame and open/close API |
| `scenes/hud/journal_panel.gd` | Story, tutorial and side-quest journal with outfit, off-hand and skill-school field notes |
| `scenes/hud/map_panel.gd` | Live world map page for Hearthmere and the Thorned Field |
| `scenes/hud/settings_panel.gd` | Settings page |
| `scenes/hud/dialogue_panel.gd` | Speaker dialogue page |
| `scenes/hud/stat_bar.gd` | Animated bars with trailing damage ghost |
| `scenes/hud/quick_slot.gd` | Reusable gilded slot with empty-socket state, stack and cooldown |
| `scenes/hud/ornate_panel.gd` | Double-bordered, studded panel frame |
| `scenes/hud/minimap.gd` | Live orthographic minimap camera |
| `scenes/hud/minimap_overlay.gd` | Compass furniture over the minimap |
| `assets/ui/icons/` | Hand-authored SVG icons |
| `scenes/demo/low_poly_tree.tscn` | Simple tree prop |
| `scenes/demo/ground_grid.gdshader` | World-space checker/grid ground |

## Tuning

- Weapon numbers live in `WEAPONS` in
  `scenes/player/weapons/weapon_library.gd` (`class`, `skill`, `damage`,
  `cooldown`, `anim_duration`, `range`, `style`, description, and trail colour).
  Add an entry and an `ORDER` id to extend the arsenal everywhere at once.
- Whole-body idle/walk/run stance is data-driven through `BODY_PROFILES` and
  `BODY_DEFAULTS` in `scenes/player/tiny_human.gd`. Tweak `hip`, `knee`,
  `crouch`, `stance`, `sway`, `roll`, `lean`, `twist`, `head_look`, `head_bob`,
  `cape` or `float` to reshape a silhouette, and `step_lift`, `heel`, `toe`,
  `bob`, `weight`, `shoulder_roll`, `arm_lag`, `flight` or `head_stabilize` to
  reshape the gait detail, without touching the locomotion code.
- Per-weapon attack lower bodies live in `ATTACK_BODY` (`lead`, `lead_hip`,
  `back_hip`, `lead_knee`, `back_knee`, `stance`, `foot_roll`, `lunge`,
  `body_yaw`, `body_roll`, `body_pitch`, `lift`). The upper-body weapon strikes
  remain the `_pose_sword`, `_pose_bow`, `_pose_staff`, `_pose_dagger` and
  `_pose_kitsune` functions.
- Talents live in `SkillLibrary` (`scenes/hud/skill_library.gd`): add an entry to
  `SKILLS`, add its id to `ORDER`, and give it a `school`, `pose` and `effect`.
  The pose must exist in `_apply_skill_pose` in `scenes/player/tiny_human.gd`.
  The HUD and the character both read the same entry, so damage, timing, mana and
  cooldowns stay in one place.
- Outfit colours live in `PALETTES` in `scenes/player/hero_look.gd`, and cape
  size in `CAPE_SCALES`. The garment geometry itself is built by
  `_build_knight`, `_build_hunter`, `_build_wizard`, `_build_rogue` and
  `_build_kitsune`; each piece joins an `Outfit_<weapon>` group that
  `_apply_outfit` toggles on `weapon_changed`.
- Idle, walk and run weapon handling is data-driven through `CARRY_PROFILES` in
  `scenes/player/tiny_human.gd`. Tweak `arm`, `elbow`, `weapon_pos`, `weapon_rot`,
  `cant`, `pitch`, or the kitsune's `offset`, `scale` and `energy` to reshape a
  stance without touching the locomotion code.
- Select `TinyHuman` to adjust walk/run speed, acceleration, stride length, hip
  swing, knee bend, arm swing, foot roll, and foot clearance in the Inspector.
- Select `Camera` to adjust the follow offset, focus height, and smoothing.
- Aim presentation lives in `scenes/hud/aim_reticle.gd` (cursor rings, aim line)
  and in `_update_aim()` in `scenes/hud/hud.gd`. The HUD casts a camera ray
  through the pointer onto the hero's ground plane, clamps the hit to 18 m and
  feeds it to `player.set_aim_point()`; above the horizon it falls back to the
  camera's ground basis so the hero still turns sensibly.
- HUD values live at the top of `scenes/hud/hud.gd` (`MAX_HEALTH`, `MAX_MANA`,
  `MAX_XP`, `QUEST_REWARD`, `STORY_BEASTS_REQUIRED`, `STORY_SIDE_WOLVES_REQUIRED`,
  the story/side gold and XP rewards, `DEATH_GOLD_LOSS`) and the starting values
  in `_health`, `_mana`, `_xp`, and `_gold`.
- The action bar is built in `_build_slot_data()` in `scenes/hud/hud.gd`. The
  first five entries are empty `skill_slot` records; the next five are the item
  entries. Skills are added to `SkillRow`, items to `ItemRow`, and slot choices
  come from `SkillLibrary` through `_show_skills()` and `_assign_skill()`.
- Satchel equipment and items are defined in `_equipment` and `_items` in
  `scenes/hud/inventory_panel.gd`. The weapon armory is generated from
  `WeaponLibrary` and the off-hand page from `OffhandLibrary`; both are equipment
  paths, never skill slots.
- Mira and Bran's stock, prices and per-visit limits live in `SHOP_STOCK` near
  the top of `scenes/hud/hud.gd`. Branch purchases (`whetstone`, `rivet`) call
  the hero's `upgrade_weapon_power()`/`upgrade_mitigation()` instead of adding an
  item, and every purchase is tracked in `_purchases`.
- Story and side-quest stages live in `_story_stage` and `_side_stage` in
  `scenes/hud/hud.gd`; the dialogue trees that advance them are
  `_show_elder_dialogue()` and `_show_tomas_dialogue()`. The HUD tracker is
  refreshed by `_refresh_quest()`, and the journal/tracker markers read the same
  state.
- Monster tuning is exported per instance in `verdant_reach.tscn`: `max_health`,
  `damage`, `move_speed`, `aggro_range`, `attack_range`, `attack_interval`,
  `xp_reward`, `gold_reward`, `boss` and `dormant`. The Warden is the only
  `boss`/`dormant` entry; lighting the shrine calls `awaken()`.
- Town and field geometry are generated by `scenes/world/world_builder.gd`.
  Player spawn (`z = 20`), the gate (`z = -30`), the wayshrine
  (`(-6, 0, -74)`) and the Warden arena (`(0, 0, -96)`) are set in
  `verdant_reach.tscn`; invisible boundaries at `x = +/-31`, `z = 41` and
  `z = -111` keep the play space inside the charted Reach.
- Dummy health and reset timing are exported on `training_dummy.tscn`; the
  starting positions of the three dummies, the Wayfarer, the townsfolk, the
  shrine and the monsters are set in `verdant_reach.tscn`.
- The walk/run cycle is procedural: hips, knees, feet, and arms are animated from
  the character's actual ground speed and the per-weapon gait table, so no
  imported animation is required.
