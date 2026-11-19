### QA

## Infinite Dungeon (Under-Reach)

The dungeon runs embedded inside Verdant Reach: a briar-sealed cave mouth in
the western rocks, set back from the wayshrine, leads down into the Under-Reach
in a dedicated layer ~120 m below the world. There is no menu button; the
standalone `scenes/dungeon/dungeon.tscn` remains as a developer harness.

### Automated checks

Run from the project root with Godot 4.7 headless:

```
godot --headless -s res://scripts/dungeon/debug_check.gd       # pure layout logic (connectivity, boss depth, room counts, style validity)
godot --headless -s res://scripts/dungeon/debug_escape.gd      # style rotation, Collapsing Vault, traps, full-clear gate/stair, restore, high-floor mobs
godot --headless -s res://scripts/dungeon/debug_sim.gd         # standalone harness: gating, room clears, boss, descend to depth 2
godot --headless -s res://scripts/dungeon/debug_world_sim.gd   # world integration: entrance gating, entry, ascend/exit, lighting, restore
godot --headless -s res://scripts/dungeon/debug_persistence.gd # continued save: lit shrine restored, entrance stays open without re-lighting
godot --headless -s res://scripts/dungeon/debug_boss_respawn.gd # named-boss return timing after mark_defeated
godot --headless -s res://scripts/dungeon/debug_chest.gd       # treasure cache loot, one-shot open, open state restored on revisit
```

Each prints a result line and exits non-zero on failure. The layout and runtime
simulations use a random seed every run, so repeat launches to sample different
layouts. `debug_escape.gd` additionally pins its own seed so trap-type checks
stay deterministic.

### Floor shapes and the escape stage

- Five floor styles exist: **Twisting Warrens**, **Long Gauntlet**,
  **Crossroads**, **Ringed Halls** and **The Collapsing Vault**.
- The four normal styles rotate with depth, so consecutive floors never share a
  style. A seeded offset keeps separate runs from lining up.
- Styles change cell spacing, room sizes, growth rules and the number of maze
  loop corridors. Ringed Halls are the most tangled; the Gauntlet is the most
  linear.
- Every fifth depth is **The Collapsing Vault** (`escape`): a linear,
  monster-free run of trap chambers. Crossing each chamber's far-side exit
  clears it, and the exit stair rises only once every chamber is behind you.
  There is no warden on this stage.

### Traps and gating

- Six trap types share `scripts/dungeon/dungeon_trap.gd`: **spike**, **flame**,
  **darts**, **crusher**, **beam** and **sweeper**. Damage scales with depth.
- Corridors only use the compact floor traps (**spike**, **flame**) and offset
  them down the lane, clear of the gatehouse posts and the raised portcullis.
  The big rigs (crusher, beam, sweeper) are confined to combat halls and trap
  chambers.
- A gate starts shut when the room it leaves is an uncleared combat hall or
  trap chamber, or when it leads into the boss lair. Trap chambers seal when
  entered and reopen on both sides once their far exit is crossed.
- The boss gate (and the escape stair) opens **only** when every combat hall
  and trap chamber on the depth is cleared. The check counts room state rather
  than an incremental tally, so restoring a floor reopens it correctly.

### Enemy depth tiers

- Depths 1: mossling, briar wolf.
- Depths 2-3: briar wolf, wisp, ember hound.
- Depths 4-5: ember hound, cinder imp, barrow wight.
- Depths 6-8: cinder imp, barrow wight, grave knight.
- Depths 9+: barrow wight, grave knight, ash revenant.
- Wardens: Briar Warden (1-2), Barrow King (3-5), Frost Wraith (6-8),
  Ember Tyrant (9+). Escape depths have no warden.

### Manual QA checklist

- [ ] The wayshrine is dark at the start; walking up to the briar-sealed cave mouth in the western rocks (`-17.5, -83`) targets the entrance and shows "The cave is sealed by briars - light the wayshrine". Pressing E explains that the shrine must wake first.
- [ ] After lighting the shrine, approaching the cave mouth shows "Descend into the Under-Reach"; pressing E drops the hero into the Moss Crypt entrance and the world darkens around the hero.
- [ ] The hero spawns just inside the entrance's first door; an ascent stairwell waits in the room center.
- [ ] Walking into a combat room slams the door shut behind you (portcullis bars) and the hall holds 2+ monsters.
- [ ] Clearing every monster in the hall reopens the gates with a toast.
- [ ] Deeper halls, side chambers and the warden's door stay shut until every combat hall and trap chamber is cleared.
- [ ] Each depth reads differently: room spacing, room sizes and maze shortcuts shift between the five floor styles.
- [ ] Depth 5 (and every fifth depth) is the Collapsing Vault: no monsters or warden, trap chambers instead, and a dense spread of traps.
- [ ] Corridor traps never clip the gatehouse or block the doorway; heavy rigs (crusher, beam, sweeper) appear only inside rooms.
- [ ] Entering a trap chamber seals it; crossing its far-side exit opens it again and advances the clear count.
- [ ] Clearing the last trap chamber on the Collapsing Vault raises the exit stair.
- [ ] Entering the boss room wakes the dormant warden (braziers ring the dais).
- [ ] Defeating the warden spawns the spiral descend stair on the far side of the dais with a toast.
- [ ] Monsters change with depth: wisps and ember hounds early, barrow dead and grave knights in the middle, ash revenants and the Ember Tyrant deepest.
- [ ] Pressing E at the descend stair drops you at the next depth (healing pause +25), with stronger monsters (≈ +18% per depth) and the next floor style.
- [ ] Ascending a floor preserves it: cleared halls and trap chambers stay cleared, the warden stays dead, the boss gate stays open, and the hero is placed at the descend stair that was used to leave.
- [ ] Using the ascent stairwell in the Depth 1 entrance returns the hero to the exact surface spot and restores daylight/fog.
- [ ] Voluntary exit resets the run: re-entering starts a fresh Depth 1.
- [ ] Dying in the dungeon (game-over) sends the hero back to the surface spawn with the run reset.
- [ ] No fall-rescue misfires while inside the dungeon; walking off the surface map still respawns the hero if the dungeon's gate logic allows.
- [ ] ESC pause, skill slots and inventory all behave inside the dungeon floors.
- [ ] Every treasure room holds a glowing **Grand Cache**; opening it shakes the chest, throws the lid, spills light and coins, and adds gold plus 3 item stacks to the satchel and purse.
- [ ] Some combat halls hide a smaller **Old Cache**; it uses the same opening animation and a smaller common haul.
- [ ] An opened cache cannot be opened again, and climbing down then back up restores it in its open pose without a second haul.
- [ ] Using a potion from the satchel removes one stack; the last use removes the empty stack from the grid instead of leaving a `0` entry.
- [ ] Continue restores the exact saved satchel, including an intentionally empty one, and dungeon loot is written to the save immediately.

### Persistence and overworld return

- [ ] Light the wayshrine, then quit to the title screen and choose Continue. The shrine is already lit (no re-lighting needed), the cave mouth shows "Descend into the Under-Reach", and E opens the dungeon normally.
- [ ] A save that has `story_stage >= 4`, `shrine_lit`, or `boss_defeated` keeps the cave open even if the shrine scene loads dark.
- [ ] After a save is reloaded, the shrine's crystal, light and rune ring are all restored without replaying the lighting pulse.
- [ ] Touch a lit shrine while wounded: the blessing refills health and mana, saves the run, and reports a 90-second cooldown on the next touch.
- [ ] Touch a lit shrine at full health and mana: it says the hero is already whole and does not start the cooldown.

### Overworld boss respawns

- [ ] Kill the Briar Warden: it stays down, the arena quiets, and it returns to the arena at full health after roughly 240 seconds.
- [ ] Kill the Barrow King: it returns after roughly 300 seconds.
- [ ] A boss saved as defeated starts down on Continue but still keeps its return clock.
- [ ] Dungeon bosses still stay dead for the floor's lifecycle (`boss_respawns` is off for dungeon-spawned elites).

### Hearthmere and Thorned Field dressing

- [ ] Hearthmere shows the communal bread oven and bread cart near the north road/market, the chapel bell frame, and three bee skeps beside the chapel wall.
- [ ] The north road has its own lamps, a granary signpost and a chapel bench; the plaza, practice field, gate road and shop fronts stay clear.
- [ ] The Thorned Field shows the poacher's camp in the western briars, the memorial below the ruined arch, the old orchard and grave row to the east, and the prayer posts at the shrine's edge.
- [ ] All new props stay clear of the field road, shrine ring, cave approach, Warden arena and fixed monster spawns.

### Known limitations

- No ceilings (third-person camera stays unobstructed); corridors read as open shafts.
- Room footprints stay square-ish; floor styles vary their spacing, size and loop count rather than their outline.
- Treasure room grants one heal blessing on entry; skill rewards arrive with Sprint 3 integration.
- The surface ground is a finite slab (240 × 240) so the dungeon can sit below it; walking off the map edge inside the town boundary walls is still blocked by invisible fences.
