# Roguelike Dungeon Game — 6-Sprint Development Checklist

A two-developer roguelike dungeon crawler built with **Godot 4** and **GDScript**.

## Project Concept

Players fight through increasingly dangerous dungeon rooms using hand-based combat, acquire randomized skills, develop a different build each run, and retain selected permanent progression after death.

> **Hand movement assumption:** Combat uses ordinary keyboard-and-mouse input for punching, blocking, or casting gestures. Camera-based hand tracking is out of scope for this prototype.

## Core Game Loop

- [ ] Enter the dungeon.
- [ ] Fight enemies using hand-based combat.
- [ ] Acquire random skills during the run.
- [ ] Defeat stronger enemies as the dungeon progresses.
- [ ] Die and reset the run.
- [ ] Retain approved permanent progression or unlocks.
- [ ] Start another run and attempt to progress further.

---

## Sprint 1 — Foundation and Movement

**Goal:** Establish a playable character and a working dungeon environment.

### Tasks

- [done] Create the Godot 4 project.
- [done] Configure the GitHub repository.
- [done] Establish the folder structure and coding conventions.
- [ ] Implement player movement.
- [ ] Implement camera controls.
- [ ] Create a basic dungeon room.
- [ ] Add collision detection and room boundaries.
- [ ] Implement player health.
- [ ] Create a basic HUD displaying health.
- [done] Establish a shared branching and pull request workflow.

### Deliverable

- [ ] The player can enter a dungeon, move around, collide with objects, and see their health.

### Acceptance Criteria

- [ ] Movement works consistently.
- [ ] The player cannot walk through walls.
- [ ] Health is displayed and updates correctly.
- [ ] Both developers can work without overwriting each other's changes.

---

## Sprint 2 — Hand-Based Combat and Enemies

**Goal:** Make combat functional.

### Tasks

- [ ] Implement one hand-based attack.
- [ ] Create an attack animation or placeholder animation.
- [ ] Implement attack range and hit detection.
- [ ] Add attack cooldowns.
- [ ] Create the first enemy type.
- [ ] Implement enemy movement and basic AI.
- [ ] Implement enemy attacks.
- [ ] Implement damage handling.
- [ ] Implement player and enemy death states.
- [ ] Add basic combat feedback, such as hit effects or damage numbers.

### Deliverable

- [ ] The player can fight enemies, take damage, and defeat them.

### Acceptance Criteria

- [ ] Attacks damage only enemies inside the valid attack area.
- [ ] Enemies can pursue and attack the player.
- [ ] Damage and death states are handled correctly.
- [ ] Cooldowns prevent unrestricted repeated attacks.

### Scope Limit

- [ ] Keep the prototype to one enemy type and one attack.
- [ ] Do not build a complex combo system yet.

---

## Sprint 3 — Random Skills and Build Variety

**Goal:** Introduce the defining random-skill progression system.

### Tasks

- [ ] Design the initial skill pool.
- [ ] Implement a reusable skill data structure.
- [ ] Create a random skill selection system.
- [ ] Create a skill selection UI.
- [ ] Add at least five skills.
- [ ] Implement skill effects.
- [ ] Implement skill cooldowns where applicable.
- [ ] Award skills after each completed room.
- [ ] Connect skills to the combat system.
- [ ] Test that skills do not break existing combat behavior.

### Initial Skill Checklist

- [ ] **Heavy Fist** — increases attack damage.
- [ ] **Swift Hands** — reduces attack cooldown.
- [ ] **Life Drain** — restores health when enemies are defeated.
- [ ] **Shockwave** — damages enemies around the player.
- [ ] **Iron Guard** — reduces incoming damage.

### Deliverable

- [ ] Players can acquire random skills during a run and create different combat builds.

### Acceptance Criteria

- [ ] Skills are selected from a defined pool.
- [ ] The selection system respects the available skill pool.
- [ ] Skill effects function correctly.
- [ ] Skill selection does not duplicate or break existing combat behavior.
- [ ] A completed room grants a skill reward.

---

## Sprint 4 — Dungeon Generation and Increasing Difficulty

**Goal:** Make each run different and progressively more challenging.

### Tasks

- [ ] Create a modular dungeon room system.
- [ ] Implement room transitions.
- [ ] Randomize room selection or room connections.
- [ ] Implement enemy spawning.
- [ ] Add enemy difficulty scaling.
- [ ] Create at least three enemy variants.
- [ ] Add a room-clear condition.
- [ ] Implement reward distribution after room clears.
- [ ] Create a basic final encounter or boss prototype.

### Difficulty Progression Checklist

- [ ] **Stage 1:** Basic enemies with low health.
- [ ] **Stage 2:** Stronger enemies with increased damage.
- [ ] **Stage 3:** Multiple enemy types can appear together.
- [ ] **Stage 4:** More aggressive enemies and fewer recovery opportunities.
- [ ] **Stage 5:** Boss encounter.

### Deliverable

- [ ] Players can progress through dungeon rooms, encounter stronger enemies, and reach a final encounter.

### Acceptance Criteria

- [ ] Rooms are selected or generated without breaking progression.
- [ ] Enemy difficulty increases according to defined rules.
- [ ] Rewards are issued after successful room clears.
- [ ] Players cannot bypass required encounters to advance.

### Scope Limit

- [ ] Use modular, hand-built rooms selected randomly.
- [ ] Defer fully procedural dungeon generation until after the prototype.

---

## Sprint 5 — Death, Reset, and Replayability

**Goal:** Make death meaningful and give players a reason to start another run.

### Tasks

- [ ] Implement death and game-over states.
- [ ] Reset player health after death.
- [ ] Reset temporary skills after death.
- [ ] Reset dungeon progress after death.
- [ ] Implement restarting a run.
- [ ] Define the permanent progression model.
- [ ] Implement at least one permanent upgrade or unlock.
- [ ] Save permanent progression locally.
- [ ] Add death and restart UI.
- [ ] Balance enemy difficulty and skill rewards.
- [ ] Test repeated runs for playability.

### Run Progression — Resets on Death

- [ ] Temporary skills.
- [ ] Current health.
- [ ] Dungeon stage.
- [ ] Temporary equipment or buffs.

### Permanent Progression — Persists Between Runs

- [ ] Unlocked skills.
- [ ] Permanent upgrades.
- [ ] Persistent currency, if included.
- [ ] Best dungeon stage reached.

### Deliverable

- [ ] Players can die, lose temporary run progress, retain approved permanent progression, and begin another run.

### Acceptance Criteria

- [ ] Death triggers a consistent game-over state.
- [ ] Restarting creates a fresh run.
- [ ] Temporary skills and dungeon progress reset correctly.
- [ ] Permanent upgrades survive restarting the game.
- [ ] Saving and loading do not corrupt progression data.

---

## Sprint 6 — Polish, Testing, and Release

**Goal:** Produce a complete, playable prototype that can be shared with other players.

### Tasks

- [ ] Improve attack animations.
- [ ] Improve enemy animations.
- [ ] Add sound effects.
- [ ] Add background music.
- [ ] Add visual feedback for damage.
- [ ] Add visual feedback for skill activation.
- [ ] Improve the main menu.
- [ ] Improve the game-over screen.
- [ ] Add a basic tutorial or control guide.
- [ ] Fix gameplay bugs.
- [ ] Balance enemy health and damage.
- [ ] Balance skill effectiveness.
- [ ] Test repeated runs.
- [ ] Test save persistence.
- [ ] Export a Linux build.
- [ ] Export a Windows build.
- [ ] Have external players test the game.
- [ ] Document known bugs and limitations.

### Deliverable

- [ ] A playable roguelike dungeon prototype with combat, randomized skills, escalating difficulty, death resets, and permanent progression.

### Acceptance Criteria

- [ ] The game launches from the exported build.
- [ ] A complete run can be started, progressed, and ended.
- [ ] Death and restart work reliably.
- [ ] Skills and dungeon progression function correctly.
- [ ] Permanent progression persists after restarting the application.
- [ ] No known critical bugs prevent completing a run.

---

## Agile Execution Checklist

### Weekly Sprint Structure

- [ ] **Monday:** Sprint planning and task assignment.
- [ ] **Tuesday–Thursday:** Development and daily progress checks.
- [ ] **Friday:** Integration, testing, and bug fixing.
- [ ] **Saturday:** Sprint review and retrospective.
- [ ] **Sunday:** Rest or optional independent learning.

> This schedule is a planning assumption. Adjust sprint duration if development is part-time.

### Work Division

| Sprint | Developer A | Developer B |
|---|---|---|
| 1 | Player movement and health | Dungeon room and collision |
| 2 | Combat and hit detection | Enemy AI and enemy attacks |
| 3 | Skill system and effects | Skill selection UI and skill data |
| 4 | Dungeon progression | Enemy variants and difficulty scaling |
| 5 | Death and reset system | Permanent progression and saving |
| 6 | Gameplay bug fixing | Visual polish and audio integration |

- [ ] Both developers participate in testing.
- [ ] Both developers participate in code reviews.
- [ ] Both developers participate in sprint planning.
- [ ] Swap responsibilities where practical so both developers understand the major systems.

---

## Git and Collaboration Checklist

- [ ] Use Git for version control.
- [ ] Use GitHub for collaboration.
- [ ] Keep `main` stable and playable.
- [ ] Use `develop` only if the team needs an integration branch.
- [ ] Create feature branches for individual changes.
- [ ] Open a pull request before merging feature work.
- [ ] Test integrated changes before merging into `main`.
- [ ] Commit Godot project files and source assets.
- [ ] Exclude generated caches and temporary build artifacts in `.gitignore`.
- [ ] Review each other's changes before merging.

### Suggested Branches

- `main` — stable, playable builds.
- `develop` — optional integrated development branch.
- `feature/player-movement` — player movement work.
- `feature/player-combat` — combat work.
- `feature/skill-system` — skill work.
- `feature/enemy-ai` — enemy behavior work.

---

## Definition of Done

A task is complete only when all applicable items are checked:

- [ ] The feature works in the integrated project.
- [ ] The main behavior has been tested.
- [ ] Existing features still work.
- [ ] The change is committed to version control.
- [ ] The task meets its acceptance criteria.
- [ ] Any known limitations are documented.

---

## Final Scope Checklist

By the end of the six sprints, aim to deliver:

- [ ] One playable character.
- [ ] One core hand-based combat system.
- [ ] At least three enemy types.
- [ ] At least five random skills.
- [ ] A sequence of randomized dungeon rooms.
- [ ] Increasing enemy difficulty.
- [ ] A boss encounter.
- [ ] Death and run resets.
- [ ] Basic permanent progression.
- [ ] Local save data.
- [ ] An exported Linux build.
- [ ] An exported Windows build.

**Central design principle:** Each run should create a different combat build, while death resets the run and leaves enough permanent progression to make another attempt worthwhile.

---

## Project Management Recommendation

For a two-person Godot project, use **GitHub with GitHub Issues and GitHub Projects** as the default setup. Azure DevOps is optional and is most useful if the goal is to practice enterprise Scrum tools, Azure Boards, or Azure Pipelines.

### Recommended GitHub Project Board

- [ ] Backlog
- [ ] Ready
- [ ] In Progress
- [ ] In Review
- [ ] Testing
- [ ] Done

### Project Setup

- [ ] Create six sprint milestones.
- [ ] Create one issue for each meaningful task.
- [ ] Include acceptance criteria in each issue.
- [ ] Assign each issue to a developer.
- [ ] Link pull requests to issues.
- [ ] Review the board during sprint planning and review.

### Use Azure DevOps When

- [ ] The primary goal is learning Azure Boards and formal Scrum planning.
- [ ] The team needs Azure Pipelines.
- [ ] The project is part of a Microsoft-focused or enterprise workflow.
- [ ] The additional setup overhead is worth the learning objective.

Avoid adding Azure hosting or paid cloud services unless the game actually needs them.

## References

- [ ] Godot documentation.
- [ ] Godot version-control guidance.
- [ ] Git documentation.
- [ ] GitHub Projects documentation.
- [ ] GitHub Issues documentation.
- [ ] Azure DevOps documentation, if Azure DevOps is used.
