### QA

## Dungeon Generator (Sprint 4)

The dungeon runs embedded inside Verdant Reach: the sunken stone ring beside
the wayshrine leads down into the Under-Reach in a dedicated layer ~120 m
below the world. There is no menu button anymore; the standalone
`scenes/dungeon/dungeon.tscn` remains as a developer harness.

### Automated checks

Run from the project root with Godot 4.7 headless:

```
godot --headless -s res://scripts/dungeon/debug_check.gd       # pure layout logic (connectivity, boss depth, room counts)
godot --headless -s res://scripts/dungeon/debug_sim.gd         # standalone harness: gating, room clears, boss, descend to depth 2
godot --headless -s res://scripts/dungeon/debug_world_sim.gd   # world integration: entrance gating, entry, ascend/exit, lighting
```

Each prints a result line and exits non-zero on failure. The simulations use a
random seed every run, so repeat launches to sample different layouts.

### Manual QA checklist

- [ ] The wayshrine is dark at the start; the stone ring east of it (`-13.5, -79.5`) offers no prompt until the shrine is lit.
- [ ] After lighting the shrine, standing on the ring shows "Descend into the Under-Reach"; pressing E drops the hero into the Moss Crypt entrance and the world darkens around the hero.
- [ ] The hero spawns just inside the entrance's first door; an ascent stairwell waits in the room center.
- [ ] Walking into a combat room slams the door shut behind you (portcullis bars) and the hall holds 2+ monsters.
- [ ] Clearing every monster in the hall reopens the gates with a toast.
- [ ] Deeper halls and the warden's door stay shut until all combat rooms are cleared.
- [ ] Entering the boss room wakes the dormant Briar Warden (braziers ring the dais).
- [ ] Defeating the warden spawns the spiral descend stair on the far side of the dais with a toast.
- [ ] Pressing E at the descend stair drops you at the next depth (healing pause +25), stronger monsters (≈ +18% per depth), and a new biome every third depth.
- [ ] Ascending a floor preserves it: cleared halls stay cleared, the warden stays dead, and the hero is placed at the descend stair that was used to leave.
- [ ] Using the ascent stairwell in the Depth 1 entrance returns the hero to the exact surface spot and restores daylight/fog.
- [ ] Voluntary exit resets the run: re-entering starts a fresh Depth 1.
- [ ] Dying in the dungeon (game-over) sends the hero back to the surface spawn with the run reset.
- [ ] No fall-rescue misfires while inside the dungeon; walking off the surface map still respawns the hero if the dungeon's gate logic allows.
- [ ] ESC pause, skill slots and inventory all behave inside the dungeon floors.

### Known limitations

- No ceilings (third-person camera stays unobstructed); corridors read as open shafts.
- Rooms are square-ish slabs; pillar/rubble dressing carries the variety for now.
- Treasure room grants one heal blessing on entry; skill rewards arrive with Sprint 3 integration.
- The surface ground is now a finite slab (240 × 240) so the dungeon can sit below it; walking off the map edge inside the town boundary walls is still blocked by invisible fences.
