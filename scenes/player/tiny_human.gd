extends CharacterBody3D

## Chibi adventurer with a procedural walk cycle and five hand-built weapons.
##
## Movement stays readable without an imported rig: limbs are pivoting mesh
## groups. Every weapon carries a whole-body profile that reshapes the idle
## stance, stride, hip/knee drive, torso lean and cape motion, so switching from
## a greatsword to a bow or a floating relic changes the character's movement,
## not only the thing in its hand. The HUD owns the assignable skill bar; attacks
## and skills both run through this node so cooldowns, animation and damage agree.

signal weapon_changed(weapon_id: String)
signal offhand_changed(offhand_id: String)
signal attack_started(weapon_id: String)
signal attack_finished(weapon_id: String)
signal skill_started(skill_id: String)
signal skill_finished(skill_id: String)
signal enemy_hit(target: Node, amount: float)
signal interaction_changed(prompt: String)

@export_group("Movement")
@export var walk_speed := 2.8
@export var run_speed := 4.8
@export var acceleration := 20.0
@export var turn_speed := 12.0
@export var gravity := 24.0

@export_group("Animation")
## World units travelled per full two-step walk cycle.
@export var stride_length := 1.35
@export var hip_swing := 0.56
@export var knee_bend := 0.88
@export var arm_swing := 0.62
## How much the toe lifts on the forward step and drops on the push-off.
@export var foot_roll := 0.07
## Extra ground clearance while the foot rolls, so toes never clip.
@export var foot_clearance := 0.011

@export_group("Combat")
@export var interaction_range := 2.6

## The dungeon floors run far below y = 0, so the fall rescue must stand down
## while the hero is inside. The dungeon manager flips this on entry and exit.
@export var allow_fall_rescue := true

const PROJECTILE := preload("res://scenes/player/weapons/projectile.gd")
const SHOCKWAVE := preload("res://scenes/player/weapons/shockwave.gd")
const SKILL_LIBRARY := preload("res://scenes/hud/skill_library.gd")
const OFFHAND_LIBRARY := preload("res://scenes/player/offhands/offhand_library.gd")

## Character-space blade directions. Sword, dagger and staff are no longer posed
## in hand space: their grip is solved against the hero's own yaw, so the blade
## keeps a readable direction while the shoulder, elbow and torso swing beneath
## it. `carry` is the resting direction of the weapon's own +Y axis; the attack
## keys sweep that direction through the strike. The bow keeps its existing
## string simulation and the kitsune keeps its hover motion.
const GRIP_PROFILES := {
	"sword": {
		"roll": 0.34,
		"carry": Vector3(0.2, 0.93, -0.3),
		"attack": [
			[0.0, Vector3(0.2, 0.93, -0.3)],
			[0.24, Vector3(0.6, 0.65, 0.46)],
			[0.42, Vector3(0.28, 0.04, -0.96)],
			[0.58, Vector3(-0.42, -0.56, -0.72)],
			[0.8, Vector3(0.05, 0.62, -0.78)],
			[1.0, Vector3(0.2, 0.93, -0.3)],
		],
	},
	"dagger": {
		"roll": 0.55,
		"carry": Vector3(0.1, 0.6, -0.79),
		"attack": [
			[0.0, Vector3(0.1, 0.6, -0.79)],
			[0.18, Vector3(0.08, 0.78, -0.62)],
			[0.27, Vector3(0.04, 0.12, -0.99)],
			[0.42, Vector3(0.1, 0.66, -0.74)],
			[0.58, Vector3(0.0, 0.08, -1.0)],
			[0.78, Vector3(0.12, 0.58, -0.8)],
			[1.0, Vector3(0.1, 0.6, -0.79)],
		],
	},
	"staff": {
		"roll": 0.0,
		"carry": Vector3(0.04, 0.99, -0.12),
		"attack": [
			[0.0, Vector3(0.04, 0.99, -0.12)],
			[0.3, Vector3(0.08, 0.58, 0.81)],
			[0.55, Vector3(0.04, 0.3, 0.95)],
			[0.66, Vector3(0.0, 0.16, -0.99)],
			[0.8, Vector3(0.04, 0.72, -0.69)],
			[1.0, Vector3(0.04, 0.99, -0.12)],
		],
	},
}

## How the left arm carries each off-hand. These are small offsets from the
## hand-authored mount positions, plus the character-space euler angle that
## keeps the prop readable, plus a guard angle used when the hero braces.
const OFFHAND_POSES := {
	# `euler` keeps the prop readable in the hero's own frame instead of letting
	# it tumble with the forearm. `hang` props (charm, lantern) stay gravity-down
	# and swing like pendulums; `follow` props (the gauntlet) are worn on the
	# hand and must inherit the hand's exact angle.
	"shield": {
		"idle": Vector3(0.0, 0.0, 0.012), "guard": Vector3(-0.03, 0.05, -0.06),
		"euler": Vector3(0.04, 0.34, -0.08), "guard_euler": Vector3(0.0, -0.04, -0.10),
		"sway": 0.026,
	},
	"gauntlet": {
		"idle": Vector3.ZERO, "guard": Vector3(0.0, 0.01, -0.02),
		"euler": Vector3.ZERO, "guard_euler": Vector3.ZERO,
		"sway": 0.012, "follow": true,
	},
	"tome": {
		"idle": Vector3(0.0, 0.02, 0.0), "guard": Vector3(0.0, 0.06, -0.05),
		"euler": Vector3(0.02, 0.44, 0.10), "guard_euler": Vector3(0.0, 0.04, 0.02),
		"sway": 0.02,
	},
	"charm": {
		"idle": Vector3.ZERO, "guard": Vector3.ZERO,
		"euler": Vector3.ZERO, "guard_euler": Vector3.ZERO,
		"sway": 0.18, "hang": true,
	},
	"lantern": {
		"idle": Vector3.ZERO, "guard": Vector3.ZERO,
		"euler": Vector3.ZERO, "guard_euler": Vector3.ZERO,
		"sway": 0.24, "hang": true,
	},
}

## Per-weapon carry poses. `arm`/`support` are shoulder euler angles,
## `elbow`/`support_elbow` bend the forearms, and `weapon_pos`/`weapon_rot` pose
## the weapon in the grip. `swing` and `support_swing` let the gait move the arms
## around those anchors so walking and running still read as locomotion. The bow
## ignores weapon_rot (it is stabilised upright) and uses `cant`/`pitch`; the
## kitsune drives its hover offset, energy and scale instead.
const CARRY_PROFILES := {
	"sword": {
		"main": "right",
		"idle": {
			"arm": Vector3(0.30, 0.0, 0.30), "elbow": 1.00,
			"support": Vector3(-0.05, 0.0, -0.18), "support_elbow": 0.34,
			"weapon_pos": Vector3(0.02, -0.06, -0.05), "weapon_rot": Vector3(-0.55, 0.25, -0.12),
			"offset": Vector3.ZERO, "scale": 1.0, "energy": 0.0, "cant": 0.0, "pitch": 0.0,
			"swing": 0.0, "support_swing": 0.10,
		},
		"walk": {
			"arm": Vector3(0.16, 0.0, 0.32), "elbow": 0.78,
			"support": Vector3(-0.08, 0.0, -0.20), "support_elbow": 0.38,
			"weapon_pos": Vector3(0.02, -0.05, -0.05), "weapon_rot": Vector3(-0.72, 0.30, -0.16),
			"offset": Vector3.ZERO, "scale": 1.0, "energy": 0.0, "cant": 0.0, "pitch": 0.0,
			"swing": 0.16, "support_swing": 0.38,
		},
		"run": {
			"arm": Vector3(-0.55, 0.0, 0.28), "elbow": 1.05,
			"support": Vector3(-0.42, 0.0, -0.24), "support_elbow": 0.95,
			"weapon_pos": Vector3(0.02, -0.04, -0.03), "weapon_rot": Vector3(-0.25, 0.18, 0.40),
			"offset": Vector3.ZERO, "scale": 1.0, "energy": 0.0, "cant": 0.0, "pitch": 0.0,
			"swing": 0.22, "support_swing": 0.55,
		},
	},
	"bow": {
		"main": "left",
		"idle": {
			"arm": Vector3(0.38, 0.0, -0.32), "elbow": 0.72,
			"support": Vector3(-0.04, 0.0, 0.16), "support_elbow": 0.32,
			"weapon_pos": Vector3(0.0, -0.02, -0.06), "weapon_rot": Vector3.ZERO,
			"offset": Vector3.ZERO, "scale": 1.0, "energy": 0.0, "cant": 0.18, "pitch": 0.05,
			"swing": 0.0, "support_swing": 0.08,
		},
		"walk": {
			"arm": Vector3(0.22, 0.0, -0.36), "elbow": 0.60,
			"support": Vector3(-0.08, 0.0, 0.18), "support_elbow": 0.36,
			"weapon_pos": Vector3(0.0, -0.01, -0.07), "weapon_rot": Vector3.ZERO,
			"offset": Vector3.ZERO, "scale": 1.0, "energy": 0.0, "cant": 0.28, "pitch": 0.08,
			"swing": 0.08, "support_swing": 0.38,
		},
		"run": {
			"arm": Vector3(-0.42, 0.0, -0.38), "elbow": 0.92,
			"support": Vector3(-0.40, 0.0, 0.22), "support_elbow": 0.90,
			"weapon_pos": Vector3(0.0, 0.03, -0.05), "weapon_rot": Vector3.ZERO,
			"offset": Vector3.ZERO, "scale": 1.0, "energy": 0.0, "cant": 0.34, "pitch": 0.12,
			"swing": 0.12, "support_swing": 0.50,
		},
	},
	"staff": {
		"main": "right",
		"idle": {
			"arm": Vector3(0.22, 0.0, 0.14), "elbow": 0.55,
			"support": Vector3(-0.06, 0.0, -0.18), "support_elbow": 0.34,
			"weapon_pos": Vector3(0.0, -0.05, -0.03), "weapon_rot": Vector3(-0.12, 0.0, -0.10),
			"offset": Vector3.ZERO, "scale": 1.0, "energy": 0.0, "cant": 0.0, "pitch": 0.0,
			"swing": 0.0, "support_swing": 0.12,
		},
		"walk": {
			"arm": Vector3(0.06, 0.0, 0.18), "elbow": 0.38,
			"support": Vector3(-0.10, 0.0, -0.20), "support_elbow": 0.40,
			"weapon_pos": Vector3(0.0, -0.04, -0.04), "weapon_rot": Vector3(-0.30, 0.05, -0.16),
			"offset": Vector3.ZERO, "scale": 1.0, "energy": 0.0, "cant": 0.0, "pitch": 0.0,
			"swing": 0.12, "support_swing": 0.40,
		},
		"run": {
			"arm": Vector3(-0.62, 0.0, 0.22), "elbow": 0.88,
			"support": Vector3(-0.50, 0.0, -0.22), "support_elbow": 0.95,
			"weapon_pos": Vector3(0.0, -0.05, -0.02), "weapon_rot": Vector3(-0.72, 0.12, 0.32),
			"offset": Vector3.ZERO, "scale": 1.0, "energy": 0.0, "cant": 0.0, "pitch": 0.0,
			"swing": 0.18, "support_swing": 0.55,
		},
	},
	"dagger": {
		"main": "right",
		"idle": {
			"arm": Vector3(0.24, 0.0, 0.20), "elbow": 1.15,
			"support": Vector3(-0.12, 0.0, -0.16), "support_elbow": 0.42,
			"weapon_pos": Vector3(0.0, -0.05, -0.04), "weapon_rot": Vector3(-0.95, 0.20, 0.25),
			"offset": Vector3.ZERO, "scale": 1.0, "energy": 0.0, "cant": 0.0, "pitch": 0.0,
			"swing": 0.0, "support_swing": 0.10,
		},
		"walk": {
			"arm": Vector3(0.12, 0.0, 0.22), "elbow": 0.92,
			"support": Vector3(-0.08, 0.0, -0.20), "support_elbow": 0.45,
			"weapon_pos": Vector3(0.0, -0.05, -0.04), "weapon_rot": Vector3(-0.82, 0.22, 0.38),
			"offset": Vector3.ZERO, "scale": 1.0, "energy": 0.0, "cant": 0.0, "pitch": 0.0,
			"swing": 0.18, "support_swing": 0.42,
		},
		"run": {
			"arm": Vector3(-0.65, 0.0, 0.18), "elbow": 0.62,
			"support": Vector3(-0.45, 0.0, -0.24), "support_elbow": 0.90,
			"weapon_pos": Vector3(0.0, -0.06, -0.02), "weapon_rot": Vector3(-0.35, 0.15, 0.72),
			"offset": Vector3.ZERO, "scale": 1.0, "energy": 0.0, "cant": 0.0, "pitch": 0.0,
			"swing": 0.24, "support_swing": 0.60,
		},
	},
	"kitsune": {
		"main": "left",
		"idle": {
			"arm": Vector3(0.42, 0.0, -0.26), "elbow": 0.82,
			"support": Vector3(-0.08, 0.0, 0.16), "support_elbow": 0.40,
			"weapon_pos": Vector3.ZERO, "weapon_rot": Vector3.ZERO,
			"offset": Vector3(0.0, 0.16, 0.0), "scale": 0.90, "energy": 1.0, "cant": 0.0, "pitch": 0.0,
			"swing": 0.0, "support_swing": 0.08,
		},
		"walk": {
			"arm": Vector3(0.22, 0.0, -0.30), "elbow": 0.68,
			"support": Vector3(-0.08, 0.0, 0.18), "support_elbow": 0.45,
			"weapon_pos": Vector3.ZERO, "weapon_rot": Vector3.ZERO,
			"offset": Vector3(0.0, 0.14, 0.05), "scale": 0.92, "energy": 1.08, "cant": 0.0, "pitch": 0.0,
			"swing": 0.08, "support_swing": 0.38,
		},
		"run": {
			"arm": Vector3(-0.45, 0.0, -0.30), "elbow": 0.58,
			"support": Vector3(-0.40, 0.0, 0.20), "support_elbow": 0.90,
			"weapon_pos": Vector3.ZERO, "weapon_rot": Vector3.ZERO,
			"offset": Vector3(0.0, 0.12, 0.18), "scale": 0.98, "energy": 1.25, "cant": 0.0, "pitch": 0.0,
			"swing": 0.12, "support_swing": 0.55,
		},
	},
}

## Baseline whole-body motion. Every weapon/state entry overrides only the keys
## it cares about, so the table stays readable while each stance still has a
## complete, deterministic pose.
const BODY_DEFAULTS := {
	"stride": 1.0,
	"hip": 1.0,
	"knee": 1.0,
	"stance": 0.0,
	"crouch": 0.0,
	"sway": 0.012,
	"roll": 1.0,
	"twist": 1.0,
	"lean": 1.0,
	"head_bob": 1.0,
	"head_look": 1.0,
	"head_tilt": 0.0,
	"bounce": 1.0,
	"float": 0.0,
	"cape": 1.0,
	"hip_yaw": 1.0,
	"foot_roll": 1.0,
	"arm": 1.0,
	# Gait detail. `step_lift` scales swing-foot clearance, `heel`/`toe` scale
	# the heel-strike and toe-off ankle rolls, `bob` and `weight` add pelvis
	# bounce and lateral weight transfer, `shoulder_roll` counter-rotates the
	# chest, `arm_lag` delays the arm swing, `flight` lifts a sprint off the
	# ground, and `head_stabilize` keeps the gaze level against the body.
	"step_lift": 1.0,
	"heel": 1.0,
	"toe": 1.0,
	"bob": 1.0,
	"weight": 1.0,
	"shoulder_roll": 1.0,
	"arm_lag": 1.0,
	"flight": 0.0,
	"head_stabilize": 1.0,
}

## Per-weapon whole-body motion for idle, walk and run. These values drive the
## hips, knees, feet, torso, head and cape in `_animate`, which is what makes a
## dagger crouch and dart while a staff strides slowly and a bow stands square.
const BODY_PROFILES := {
	"sword": {
		# A knight: planted, weighty, heel first.
		"idle": {"stance": 0.07, "crouch": 0.05, "sway": 0.012, "head_tilt": 0.02, "step_lift": 0.55, "heel": 0.95, "toe": 1.05, "bob": 0.8, "weight": 0.9, "shoulder_roll": 1.0, "arm_lag": 0.9, "flight": 0.0, "head_stabilize": 1.05},
		"walk": {"stride": 1.0, "hip": 1.0, "knee": 1.0, "stance": 0.09, "crouch": 0.04, "sway": 0.014, "roll": 1.05, "cape": 1.1, "head_look": 0.8, "step_lift": 0.8, "heel": 1.15, "toe": 1.2, "bob": 1.0, "weight": 1.05, "shoulder_roll": 1.1, "arm_lag": 1.0, "flight": 0.0, "head_stabilize": 1.1},
		"run": {"stride": 1.12, "hip": 1.15, "knee": 1.2, "stance": 0.07, "crouch": 0.02, "sway": 0.010, "roll": 0.9, "twist": 1.15, "lean": 1.2, "head_bob": 1.2, "head_look": 0.4, "bounce": 1.3, "cape": 1.5, "arm": 1.1, "step_lift": 1.25, "heel": 0.8, "toe": 1.35, "bob": 1.3, "weight": 0.9, "shoulder_roll": 1.25, "arm_lag": 1.2, "flight": 0.022, "head_stabilize": 1.15},
	},
	"bow": {
		# A hunter: quiet, low, almost no head bob.
		"idle": {"stance": 0.10, "crouch": 0.14, "sway": 0.006, "roll": 0.6, "twist": 0.55, "lean": 1.1, "head_bob": 0.35, "head_look": 0.25, "head_tilt": 0.01, "bounce": 0.5, "cape": 0.6, "hip_yaw": 0.5, "foot_roll": 0.7, "arm": 0.8, "step_lift": 0.4, "heel": 0.55, "toe": 0.55, "bob": 0.45, "weight": 0.65, "shoulder_roll": 0.5, "arm_lag": 0.65, "flight": 0.0, "head_stabilize": 1.3},
		"walk": {"stride": 0.85, "hip": 0.7, "knee": 0.8, "stance": 0.12, "crouch": 0.09, "sway": 0.008, "roll": 0.7, "twist": 0.6, "lean": 1.15, "head_bob": 0.4, "head_look": 0.2, "bounce": 0.6, "cape": 0.8, "hip_yaw": 0.55, "foot_roll": 0.8, "arm": 0.7, "step_lift": 0.5, "heel": 0.6, "toe": 0.6, "bob": 0.5, "weight": 0.7, "shoulder_roll": 0.55, "arm_lag": 0.7, "flight": 0.0, "head_stabilize": 1.35},
		"run": {"stride": 0.92, "hip": 0.85, "knee": 1.0, "stance": 0.14, "crouch": 0.06, "sway": 0.008, "roll": 0.8, "twist": 0.7, "lean": 1.3, "head_bob": 0.6, "head_look": 0.15, "bounce": 0.8, "cape": 1.2, "hip_yaw": 0.6, "foot_roll": 0.9, "arm": 0.85, "step_lift": 0.85, "heel": 0.5, "toe": 0.8, "bob": 0.75, "weight": 0.75, "shoulder_roll": 0.7, "arm_lag": 0.9, "flight": 0.012, "head_stabilize": 1.4},
	},
	"staff": {
		# A wizard: long, gliding strides under a heavy robe.
		"idle": {"stance": 0.12, "crouch": 0.05, "sway": 0.016, "roll": 1.2, "twist": 0.8, "lean": 0.8, "head_bob": 1.1, "head_look": 1.2, "head_tilt": 0.06, "cape": 1.2, "hip_yaw": 0.8, "foot_roll": 1.1, "arm": 0.9, "step_lift": 0.75, "heel": 0.9, "toe": 1.0, "bob": 0.8, "weight": 1.1, "shoulder_roll": 1.15, "arm_lag": 1.15, "flight": 0.0, "head_stabilize": 1.0},
		"walk": {"stride": 1.1, "hip": 0.95, "knee": 1.05, "stance": 0.13, "crouch": 0.05, "sway": 0.018, "roll": 1.35, "twist": 0.9, "lean": 0.85, "head_bob": 1.15, "head_look": 1.0, "bounce": 1.15, "cape": 1.4, "hip_yaw": 0.85, "arm": 0.9, "step_lift": 1.0, "heel": 0.85, "toe": 1.05, "bob": 0.9, "weight": 1.2, "shoulder_roll": 1.3, "arm_lag": 1.25, "flight": 0.0, "head_stabilize": 1.05},
		"run": {"stride": 1.18, "hip": 1.05, "knee": 1.3, "stance": 0.11, "crouch": 0.03, "sway": 0.014, "roll": 1.2, "twist": 1.0, "lean": 1.1, "head_bob": 1.35, "head_look": 0.5, "bounce": 1.5, "cape": 1.8, "hip_yaw": 0.9, "arm": 1.0, "step_lift": 1.35, "heel": 0.7, "toe": 1.25, "bob": 1.2, "weight": 1.0, "shoulder_roll": 1.35, "arm_lag": 1.35, "flight": 0.018, "head_stabilize": 1.1},
	},
	"dagger": {
		# A rogue: low, fast, springy, with a lot of shoulder counter-roll.
		"idle": {"stance": 0.04, "crouch": 0.22, "sway": 0.016, "roll": 1.3, "twist": 1.25, "lean": 1.5, "head_bob": 1.2, "head_look": 1.5, "head_tilt": 0.08, "bounce": 1.4, "cape": 1.1, "hip_yaw": 1.25, "foot_roll": 1.2, "arm": 1.3, "step_lift": 0.7, "heel": 0.75, "toe": 1.2, "bob": 1.15, "weight": 1.1, "shoulder_roll": 1.25, "arm_lag": 1.1, "flight": 0.0, "head_stabilize": 1.0},
		"walk": {"stride": 0.78, "hip": 1.3, "knee": 1.15, "stance": 0.05, "crouch": 0.16, "sway": 0.018, "roll": 1.35, "twist": 1.3, "lean": 1.6, "head_bob": 1.4, "head_look": 1.2, "bounce": 1.6, "cape": 1.4, "hip_yaw": 1.3, "foot_roll": 1.25, "arm": 1.35, "step_lift": 1.15, "heel": 0.8, "toe": 1.5, "bob": 1.25, "weight": 1.3, "shoulder_roll": 1.45, "arm_lag": 1.3, "flight": 0.0, "head_stabilize": 1.0},
		"run": {"stride": 0.86, "hip": 1.45, "knee": 1.4, "stance": 0.04, "crouch": 0.10, "sway": 0.014, "roll": 1.1, "twist": 1.4, "lean": 1.8, "head_bob": 1.6, "head_look": 0.6, "bounce": 1.8, "cape": 1.8, "hip_yaw": 1.35, "foot_roll": 1.3, "arm": 1.4, "step_lift": 1.55, "heel": 0.7, "toe": 1.65, "bob": 1.55, "weight": 1.15, "shoulder_roll": 1.55, "arm_lag": 1.45, "flight": 0.030, "head_stabilize": 1.1},
	},
	"kitsune": {
		# A spirit: a light, high prance with a long airborne beat.
		"idle": {"stance": 0.14, "crouch": 0.02, "sway": 0.024, "roll": 1.5, "twist": 1.35, "lean": 0.75, "head_bob": 0.8, "head_look": 1.6, "head_tilt": 0.09, "bounce": 1.6, "float": 0.012, "cape": 1.6, "hip_yaw": 1.3, "foot_roll": 1.4, "arm": 1.1, "step_lift": 0.8, "heel": 0.85, "toe": 1.2, "bob": 1.1, "weight": 0.9, "shoulder_roll": 1.35, "arm_lag": 1.2, "flight": 0.0, "head_stabilize": 0.9},
		"walk": {"stride": 0.92, "hip": 1.1, "knee": 0.8, "stance": 0.16, "crouch": 0.015, "sway": 0.026, "roll": 1.6, "twist": 1.4, "lean": 0.8, "head_bob": 0.9, "head_look": 1.2, "bounce": 1.9, "float": 0.008, "cape": 1.9, "hip_yaw": 1.35, "foot_roll": 1.5, "arm": 1.2, "step_lift": 1.3, "heel": 0.9, "toe": 1.5, "bob": 1.4, "weight": 0.95, "shoulder_roll": 1.5, "arm_lag": 1.25, "flight": 0.008, "head_stabilize": 0.95},
		"run": {"stride": 1.0, "hip": 1.2, "knee": 1.0, "stance": 0.14, "crouch": 0.0, "sway": 0.020, "roll": 1.3, "twist": 1.5, "lean": 1.05, "head_bob": 1.1, "head_look": 0.6, "bounce": 2.2, "float": 0.006, "cape": 2.2, "hip_yaw": 1.4, "foot_roll": 1.45, "arm": 1.25, "step_lift": 1.7, "heel": 0.8, "toe": 1.7, "bob": 1.8, "weight": 0.9, "shoulder_roll": 1.6, "arm_lag": 1.4, "flight": 0.040, "head_stabilize": 1.0},
	},
}

## Lower-body language for each attack. Upper-body poses live in the `_pose_*`
## methods; these keys add the lead/back leg drive, hip yaw, body tilt and ground
## lift that turn an arm flourish into a whole-body strike.
const ATTACK_BODY := {
	"sword": {
		"lead": "left",
		"lead_hip": [[0.0, 0.0], [0.24, -0.12], [0.45, 0.34], [0.70, 0.18], [1.0, 0.0]],
		"back_hip": [[0.0, 0.0], [0.24, 0.08], [0.45, -0.26], [0.70, -0.14], [1.0, 0.0]],
		"lead_knee": [[0.0, 0.0], [0.24, -0.10], [0.45, -0.34], [0.70, -0.18], [1.0, 0.0]],
		"back_knee": [[0.0, 0.0], [0.24, -0.08], [0.45, -0.20], [0.70, -0.12], [1.0, 0.0]],
		"stance": [[0.0, 0.0], [0.30, 0.04], [0.50, 0.10], [0.80, 0.02], [1.0, 0.0]],
		"lunge": [[0.0, 0.0], [0.30, -0.05], [0.47, -0.16], [0.75, -0.02], [1.0, 0.0]],
		"lift": [[0.0, 0.0], [1.0, 0.0]],
		"body_yaw": [[0.0, 0.0], [0.24, -0.10], [0.46, 0.22], [0.72, 0.10], [1.0, 0.0]],
		"body_roll": [[0.0, 0.0], [0.24, 0.04], [0.46, -0.07], [0.72, -0.03], [1.0, 0.0]],
		"body_pitch": [[0.0, 0.0], [0.30, 0.04], [0.48, 0.12], [0.75, 0.04], [1.0, 0.0]],
		"foot_roll": [[0.0, 0.0], [1.0, 0.0]],
	},
	"bow": {
		"lead": "left",
		"lead_hip": [[0.0, 0.0], [0.24, 0.10], [0.60, 0.16], [0.82, 0.06], [1.0, 0.0]],
		"back_hip": [[0.0, 0.0], [0.24, -0.08], [0.60, -0.14], [0.82, -0.05], [1.0, 0.0]],
		"lead_knee": [[0.0, 0.0], [0.24, -0.10], [0.60, -0.20], [0.82, -0.08], [1.0, 0.0]],
		"back_knee": [[0.0, 0.0], [0.24, -0.14], [0.60, -0.24], [0.82, -0.10], [1.0, 0.0]],
		"stance": [[0.0, 0.0], [0.24, 0.08], [0.60, 0.14], [0.82, 0.04], [1.0, 0.0]],
		"lunge": [[0.0, 0.0], [1.0, 0.0]],
		"lift": [[0.0, 0.0], [0.30, -0.01], [0.62, -0.02], [0.80, 0.0], [1.0, 0.0]],
		"body_yaw": [[0.0, 0.0], [0.24, 0.08], [0.62, 0.12], [0.82, 0.03], [1.0, 0.0]],
		"body_roll": [[0.0, 0.0], [0.30, -0.03], [0.62, -0.04], [0.82, 0.0], [1.0, 0.0]],
		"body_pitch": [[0.0, 0.0], [0.30, -0.03], [0.62, -0.05], [0.82, 0.0], [1.0, 0.0]],
		"foot_roll": [[0.0, 0.0], [1.0, 0.0]],
	},
	"staff": {
		"lead": "right",
		"lead_hip": [[0.0, 0.0], [0.30, -0.10], [0.60, 0.24], [0.78, 0.12], [1.0, 0.0]],
		"back_hip": [[0.0, 0.0], [0.30, 0.08], [0.60, -0.18], [0.78, -0.10], [1.0, 0.0]],
		"lead_knee": [[0.0, 0.0], [0.30, -0.16], [0.60, -0.32], [0.78, -0.18], [1.0, 0.0]],
		"back_knee": [[0.0, 0.0], [0.30, -0.14], [0.60, -0.24], [0.78, -0.14], [1.0, 0.0]],
		"stance": [[0.0, 0.0], [0.30, 0.05], [0.60, 0.13], [0.82, 0.03], [1.0, 0.0]],
		"lunge": [[0.0, 0.0], [0.32, 0.02], [0.60, -0.09], [0.78, -0.03], [1.0, 0.0]],
		"lift": [[0.0, 0.0], [0.36, 0.02], [0.56, 0.04], [0.66, -0.05], [0.82, 0.0], [1.0, 0.0]],
		"body_yaw": [[0.0, 0.0], [0.30, -0.08], [0.62, 0.10], [0.80, 0.04], [1.0, 0.0]],
		"body_roll": [[0.0, 0.0], [0.30, 0.03], [0.62, -0.05], [0.80, -0.02], [1.0, 0.0]],
		"body_pitch": [[0.0, 0.0], [0.30, -0.05], [0.60, 0.10], [0.80, 0.03], [1.0, 0.0]],
		"foot_roll": [[0.0, 0.0], [1.0, 0.0]],
	},
	"dagger": {
		"lead": "right",
		"lead_hip": [[0.0, 0.0], [0.18, 0.10], [0.26, 0.42], [0.42, 0.18], [0.58, 0.44], [0.78, 0.14], [1.0, 0.0]],
		"back_hip": [[0.0, 0.0], [0.18, -0.08], [0.26, -0.30], [0.42, -0.14], [0.58, -0.32], [0.78, -0.10], [1.0, 0.0]],
		"lead_knee": [[0.0, 0.0], [0.18, -0.12], [0.26, -0.36], [0.42, -0.20], [0.58, -0.38], [0.78, -0.16], [1.0, 0.0]],
		"back_knee": [[0.0, 0.0], [0.18, -0.10], [0.26, -0.24], [0.42, -0.16], [0.58, -0.26], [0.78, -0.12], [1.0, 0.0]],
		"stance": [[0.0, 0.0], [0.20, 0.02], [0.30, 0.07], [0.60, 0.06], [0.82, 0.01], [1.0, 0.0]],
		"lunge": [[0.0, 0.0], [0.18, -0.04], [0.27, -0.13], [0.42, -0.04], [0.58, -0.15], [0.78, -0.02], [1.0, 0.0]],
		"lift": [[0.0, 0.0], [1.0, 0.0]],
		"body_yaw": [[0.0, 0.0], [0.24, -0.12], [0.36, 0.10], [0.58, -0.12], [0.80, 0.04], [1.0, 0.0]],
		"body_roll": [[0.0, 0.0], [0.24, 0.04], [0.40, -0.04], [0.58, 0.04], [1.0, 0.0]],
		"body_pitch": [[0.0, 0.0], [0.24, 0.08], [0.58, 0.10], [0.82, 0.02], [1.0, 0.0]],
		"foot_roll": [[0.0, 0.0], [1.0, 0.0]],
	},
	"kitsune": {
		"lead": "left",
		"lead_hip": [[0.0, 0.0], [0.28, 0.10], [0.52, 0.18], [0.78, 0.08], [1.0, 0.0]],
		"back_hip": [[0.0, 0.0], [0.28, -0.06], [0.52, -0.12], [0.78, -0.05], [1.0, 0.0]],
		"lead_knee": [[0.0, 0.0], [0.28, -0.06], [0.52, -0.12], [0.78, -0.05], [1.0, 0.0]],
		"back_knee": [[0.0, 0.0], [0.28, -0.05], [0.52, -0.10], [0.78, -0.04], [1.0, 0.0]],
		"stance": [[0.0, 0.0], [0.28, 0.08], [0.52, 0.16], [0.80, 0.04], [1.0, 0.0]],
		"lunge": [[0.0, 0.0], [0.32, -0.03], [0.60, -0.05], [0.82, 0.0], [1.0, 0.0]],
		"lift": [[0.0, 0.0], [0.30, 0.015], [0.60, 0.025], [0.82, 0.005], [1.0, 0.0]],
		"body_yaw": [[0.0, 0.0], [0.30, -0.10], [0.62, 0.08], [0.82, 0.02], [1.0, 0.0]],
		"body_roll": [[0.0, 0.0], [0.30, 0.05], [0.62, -0.06], [0.82, -0.02], [1.0, 0.0]],
		"body_pitch": [[0.0, 0.0], [0.30, -0.02], [0.62, 0.04], [0.82, 0.01], [1.0, 0.0]],
		"foot_roll": [[0.0, 0.0], [1.0, 0.0]],
	},
}

const DASH_SPEED := 11.5
const GUARD_DURATION := 2.2
## A small vertical lift for the brief airborne beat of a sprint.
const RUN_FLIGHT_HEIGHT := 0.10

@onready var _body: Node3D = $Visual/Body
@onready var _upper_body: Node3D = $Visual/Body/UpperBody
@onready var _head: Node3D = $Visual/Body/UpperBody/HeadPivot
@onready var _left_shoulder: Node3D = $Visual/Body/UpperBody/LeftShoulder
@onready var _right_shoulder: Node3D = $Visual/Body/UpperBody/RightShoulder
@onready var _left_elbow: Node3D = $Visual/Body/UpperBody/LeftShoulder/Elbow
@onready var _right_elbow: Node3D = $Visual/Body/UpperBody/RightShoulder/Elbow
@onready var _left_hip: Node3D = $Visual/Body/LeftHip
@onready var _right_hip: Node3D = $Visual/Body/RightHip
@onready var _left_knee: Node3D = $Visual/Body/LeftHip/Knee
@onready var _right_knee: Node3D = $Visual/Body/RightHip/Knee
@onready var _left_foot: Node3D = $Visual/Body/LeftHip/Knee/Foot
@onready var _right_foot: Node3D = $Visual/Body/RightHip/Knee/Foot
@onready var _left_hand: Node3D = $Visual/Body/UpperBody/LeftShoulder/Elbow/Hand
@onready var _right_hand: Node3D = $Visual/Body/UpperBody/RightShoulder/Elbow/Hand
@onready var _sword: Node3D = $Visual/Body/UpperBody/RightShoulder/Elbow/Hand/Mount/Sword
@onready var _dagger: Node3D = $Visual/Body/UpperBody/RightShoulder/Elbow/Hand/Mount/Dagger
@onready var _staff: Node3D = $Visual/Body/UpperBody/RightShoulder/Elbow/Hand/Mount/Staff
@onready var _bow: Node3D = $Visual/Body/UpperBody/LeftShoulder/Elbow/Hand/Mount/Bow
@onready var _kitsune: Node3D = $Visual/Body/UpperBody/LeftShoulder/Elbow/Hand/Mount/Kitsune
@onready var _offhand_mount: Node3D = $Visual/Body/UpperBody/LeftShoulder/Elbow/Hand/OffhandMount
@onready var _offhand_shield: Node3D = $Visual/Body/UpperBody/LeftShoulder/Elbow/Hand/OffhandMount/Shield
@onready var _offhand_gauntlet: Node3D = $Visual/Body/UpperBody/LeftShoulder/Elbow/Hand/OffhandMount/Gauntlet
@onready var _offhand_tome: Node3D = $Visual/Body/UpperBody/LeftShoulder/Elbow/Hand/OffhandMount/Tome
@onready var _offhand_charm: Node3D = $Visual/Body/UpperBody/LeftShoulder/Elbow/Hand/OffhandMount/Charm
@onready var _offhand_lantern: Node3D = $Visual/Body/UpperBody/LeftShoulder/Elbow/Hand/OffhandMount/Lantern
@onready var _torch_rig: Node3D = $Visual/Body/UpperBody/TorchRig
@onready var _torch_light: OmniLight3D = $Visual/Body/UpperBody/TorchRig/TorchLight
@onready var _blade_trail: BladeTrail = $BladeTrail
@onready var _bow_string: Node3D = $Visual/Body/UpperBody/LeftShoulder/Elbow/Hand/Mount/Bow/String
@onready var _staff_light: OmniLight3D = $Visual/Body/UpperBody/RightShoulder/Elbow/Hand/Mount/Staff/SpiritLight
@onready var _staff_crystal: MeshInstance3D = $Visual/Body/UpperBody/RightShoulder/Elbow/Hand/Mount/Staff/Crystal

var equipped_weapon := "sword"
var equipped_offhand := "shield"
var movement_locked := false

## Permanent forge upgrades bought from Bran. They are deliberately tiny, flat
## bonuses so the starter weapons still feel like the starter weapons.
var _weapon_power := 0.0
var _mitigation := 0.0

var _upper_leg_length := 0.0
var _lower_leg_length := 0.0
var _foot_drop := 0.0
var _walk_phase := 0.0
var _move_blend := 0.0
var _idle_time := 0.0

var _weapon_rest := {}
var _offhand_nodes := {}
var _offhand_rest := {}
var _offhand_carry_blend := 1.0
var _offhand_bob := 0.0
var _bow_string_rest_position := Vector3.ZERO
var _bow_string_rest_scale := Vector3.ONE
var _staff_crystal_rest_scale := Vector3.ONE
var _carry_blend := 1.0

var _cape_root: Node3D
var _cape_upper: Node3D
var _cape_mid: Node3D
var _cape_lower: Node3D
var _cape_rest := {}

var _spawn_position := Vector3.ZERO
var _spawn_rotation := 0.0

var _attack_active := false
var _attack_time := 0.0
var _attack_duration := 0.0
var _attack_cooldown := 0.0
var _event_flags := {}
var _wisp_remaining := 0
var _wisp_timer := 0.0

var _skill_active := false
var _skill_id := ""
var _skill_time := 0.0
var _skill_duration := 0.0
var _skill_data := {}
var _dash_time := 0.0
var _dash_direction := Vector3.ZERO
var _guard_time := 0.0
var _wisp_power := 12.0
var _wisp_gap := 0.09

## Spirit Orbs outlive the short cast that summons them, so they keep their own
## little orbit rig and fire on a timer.
var _orb_root: Node3D
var _orb_nodes: Array[Node3D] = []
var _orb_life := 0.0
var _orb_timer := 0.0
var _orb_gap := 0.55
var _orb_power := 14.0
var _orb_index := 0

## The HUD projects the mouse onto the ground and feeds the point here. The hero
## turns to it while standing still, so the centre box reticle and the character
## always agree about which way is "forward".
var _aim_point := Vector3.ZERO
var _has_aim := false
var _aim_facing := false

var _trail_tip_offsets := {
	"sword": Vector3(0.0, 0.86, 0.0),
	"dagger": Vector3(0.0, 0.52, 0.0),
	"staff": Vector3(0.0, 1.5, 0.0),
	"bow": Vector3(0.0, 0.0, 0.0),
	"kitsune": Vector3(0.0, 0.0, 0.0),
}
var _combat_nodes := {}

var _torch_on := false
var _interaction_target: Node3D
var _interaction_scan := 0.0
var _camera_yaw := 0.0

func set_camera_yaw(yaw: float) -> void:
	_camera_yaw = yaw
	if not _attack_active and not _skill_active and _dash_time <= 0.0 and movement_locked == false:
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if input.length_squared() < 0.001:
			rotation.y = _camera_yaw

func _ready() -> void:
	_upper_leg_length = absf(_left_knee.position.y)
	_lower_leg_length = absf(_left_foot.position.y)
	var foot_mesh: MeshInstance3D = _left_foot.get_node("FootMesh")
	_foot_drop = absf(foot_mesh.position.y) + foot_mesh.get_aabb().size.y * 0.5
	_spawn_position = global_position
	_spawn_rotation = rotation.y
	_combat_nodes = {
		"sword": _sword,
		"dagger": _dagger,
		"staff": _staff,
		"bow": _bow,
		"kitsune": _kitsune,
	}
	for id in _combat_nodes:
		var node := _combat_nodes[id] as Node3D
		_weapon_rest[id] = {
			"position": node.position,
			"rotation": node.rotation,
			"scale": node.scale,
		}
	_offhand_nodes = {
		"shield": _offhand_shield,
		"gauntlet": _offhand_gauntlet,
		"tome": _offhand_tome,
		"charm": _offhand_charm,
		"lantern": _offhand_lantern,
	}
	for id in _offhand_nodes:
		var node := _offhand_nodes[id] as Node3D
		_offhand_rest[id] = {
			"position": node.position,
			"basis": node.transform.basis,
		}
	_offhand_bob = randf() * TAU
	if _bow_string != null:
		_bow_string_rest_position = _bow_string.position
		_bow_string_rest_scale = _bow_string.scale
	if _staff_crystal != null:
		_staff_crystal_rest_scale = _staff_crystal.scale
	_resolve_cape()
	_apply_weapon_visibility()
	update_trail_tip()
	call_deferred("_broadcast_initial_state")

func _resolve_cape() -> void:
	_cape_root = _upper_body.get_node_or_null("CapeRoot") as Node3D
	if _cape_root == null:
		return
	_cape_upper = _cape_root.get_node_or_null("CapeUpper") as Node3D
	_cape_mid = _cape_root.get_node_or_null("CapeUpper/CapeMid") as Node3D
	_cape_lower = _cape_root.get_node_or_null("CapeUpper/CapeMid/CapeLower") as Node3D
	for entry in [["upper", _cape_upper], ["mid", _cape_mid], ["lower", _cape_lower], ["root", _cape_root]]:
		var node := entry[1] as Node3D
		if node != null:
			_cape_rest[entry[0]] = node.rotation

func _broadcast_initial_state() -> void:
	weapon_changed.emit(equipped_weapon)
	interaction_changed.emit("")

func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_update_attack(delta)
	_update_skill(delta)
	_update_wisps(delta)
	_update_orbs(delta)

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if movement_locked:
		input = Vector2.ZERO
	var move_direction := _camera_relative_direction(input)
	var has_input := move_direction.length_squared() > 0.001
	if has_input:
		move_direction = move_direction.normalized()

	if _dash_time > 0.0:
		velocity.x = _dash_direction.x * DASH_SPEED
		velocity.z = _dash_direction.z * DASH_SPEED
		rotation.y = atan2(-_dash_direction.x, -_dash_direction.z)
	else:
		var top_speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
		if _attack_active:
			top_speed *= 0.35
		if _skill_active:
			top_speed *= 0.45
		var target_velocity := move_direction * top_speed
		var current_velocity := Vector3(velocity.x, 0.0, velocity.z)
		current_velocity = current_velocity.move_toward(target_velocity, acceleration * delta)
		velocity.x = current_velocity.x
		velocity.z = current_velocity.z

	if is_on_floor():
		velocity.y = -0.1
	else:
		velocity.y -= gravity * delta

	move_and_slide()

	if allow_fall_rescue and global_position.y < -5.0:
		global_position = _spawn_position
		velocity = Vector3.ZERO

	if not _attack_active and not _skill_active and _dash_time <= 0.0 and not movement_locked:
		# Character faces camera direction during gameplay
		rotation.y = lerp_angle(rotation.y, _camera_yaw, 1.0 - exp(-turn_speed * delta))
	elif _aim_facing and _has_aim and not _attack_active and not _skill_active and _dash_time <= 0.0 and not has_input:
		_turn_toward_aim(delta)

	if _torch_on:
		var flicker := 1.55 + sin(_idle_time * 14.0) * 0.12 + sin(_idle_time * 23.0) * 0.06
		_torch_light.light_energy = flicker

	_scan_interactions(delta)
	_animate(delta)

## WASD moves relative to the active camera: W is the camera's horizontal
## forward. Falls back to world-relative input when no camera is active.
func _camera_relative_direction(input: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(input.x, 0.0, input.y)
	var cam_basis := camera.global_basis
	var cam_forward := -cam_basis.z
	cam_forward.y = 0.0
	var cam_right := cam_basis.x
	cam_right.y = 0.0
	cam_forward = cam_forward.normalized()
	cam_right = cam_right.normalized()
	return cam_right * input.x + cam_forward * -input.y

func _scan_interactions(delta: float) -> void:
	_interaction_scan -= delta
	if _interaction_scan > 0.0:
		return
	_interaction_scan = 0.18

	var best: Node3D = null
	var best_distance := interaction_range
	for candidate in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(candidate) or not candidate is Node3D:
			continue
		if candidate.has_method("can_interact") and not candidate.can_interact():
			continue
		var distance := global_position.distance_to((candidate as Node3D).global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate as Node3D

	if best == _interaction_target:
		return
	_interaction_target = best
	var prompt := ""
	if best != null and best.has_method("get_interaction_prompt"):
		prompt = str(best.get_interaction_prompt())
	interaction_changed.emit(prompt)

func interact() -> bool:
	if _interaction_target == null or not is_instance_valid(_interaction_target):
		return false
	if not _interaction_target.has_method("interact"):
		return false
	_interaction_target.interact(self)
	return true

func equip_weapon(weapon_id: String) -> bool:
	if not WeaponLibrary.WEAPONS.has(weapon_id):
		return false
	if equipped_weapon == weapon_id:
		return true
	if _attack_active:
		_finish_attack()
	if _skill_active:
		_finish_skill()
	equipped_weapon = weapon_id
	_carry_blend = minf(_carry_blend, 0.30)
	_offhand_carry_blend = minf(_offhand_carry_blend, 0.30)
	_apply_weapon_visibility()
	update_trail_tip()
	weapon_changed.emit(equipped_weapon)
	return true

## Off-hands are carried in the free left hand, so the two-handed bow and the
## floating kitsune relic simply put the left arm to work and the shield, book,
## glove, charm or lantern is stowed for the duration.
func equip_offhand(offhand_id: String) -> bool:
	if not OFFHAND_LIBRARY.has(offhand_id):
		return false
	if equipped_offhand == offhand_id:
		return true
	equipped_offhand = offhand_id
	_offhand_carry_blend = minf(_offhand_carry_blend, 0.30)
	_apply_offhand_visibility()
	offhand_changed.emit(equipped_offhand)
	return true

func offhand_in_use() -> bool:
	return equipped_weapon != "bow" and equipped_weapon != "kitsune"

func get_offhand_data(offhand_id := "") -> Dictionary:
	var id := offhand_id if not offhand_id.is_empty() else equipped_offhand
	return OFFHAND_LIBRARY.get_offhand(id)

func offhand_bonus(key: String, fallback := 0.0) -> float:
	if not offhand_in_use():
		return fallback
	var bonus: Dictionary = get_offhand_data().get("bonus", {})
	return float(bonus.get(key, fallback))

## The HUD owns health, so it asks the hero to translate a raw hit through the
## carried off-hand. A shield blunts every blow and turns aside much more while
## guarding; the lantern steadies the arm a little further.
func mitigate_damage(amount: float) -> float:
	var reduction := _mitigation
	if offhand_in_use():
		reduction += offhand_bonus("damage_reduction", 0.0)
		if is_guarding():
			reduction += offhand_bonus("guard_reduction", 0.0)
	reduction = clampf(reduction, 0.0, 0.85)
	return maxf(1.0, amount * (1.0 - reduction))

## Called by the HUD when Bran fits a new whetstone or rivet. Returns the new
## running total so the shop can show it.
func upgrade_weapon_power(amount: float) -> float:
	_weapon_power += amount
	return _weapon_power

func upgrade_mitigation(amount: float) -> float:
	_mitigation += amount
	return _mitigation

func weapon_power_bonus() -> float:
	return _weapon_power

func mitigation_bonus() -> float:
	return _mitigation

func offhand_damage_multiplier(kind: String) -> float:
	if not offhand_in_use():
		return 1.0
	match kind:
		"melee":
			return offhand_bonus("melee", 1.0)
		"spell", "missile":
			return offhand_bonus("spell", 1.0)
	return 1.0

func gold_multiplier() -> float:
	return offhand_bonus("gold", 1.0)

func xp_multiplier() -> float:
	return offhand_bonus("xp", 1.0)

func perform_skill(skill_id: String) -> bool:
	if not SKILL_LIBRARY.SKILLS.has(skill_id):
		return false
	if _attack_active or _skill_active or movement_locked:
		return false
	var data: Dictionary = SKILL_LIBRARY.SKILLS[skill_id]
	_skill_active = true
	_skill_id = skill_id
	_skill_time = 0.0
	_skill_duration = maxf(float(data.get("duration", 0.7)), 0.1)
	_skill_data = data
	_event_flags.clear()
	_face_aim_point()
	var effect := str(data.get("effect", ""))
	match effect:
		"dash":
			_dash_direction = _aim_direction()
			_dash_time = _skill_duration * 0.58
			_spawn_speed_lines()
		"dash_strike", "fox_dash", "shadow_dash":
			_dash_direction = _aim_direction()
			if effect == "shadow_dash":
				var victim := _find_nearest_dummy(12.0)
				if victim != null:
					var to_victim := victim.global_position - global_position
					to_victim.y = 0.0
					if to_victim.length_squared() > 0.04:
						_dash_direction = to_victim.normalized()
			rotation.y = atan2(-_dash_direction.x, -_dash_direction.z)
			_dash_time = _skill_duration * (0.52 if effect == "shadow_dash" else 0.42)
			_spawn_speed_lines()
		"guard":
			_guard_time = GUARD_DURATION
			_spawn_ward_ring(_skill_color(Color(0.7, 0.8, 0.95, 1.0)), GUARD_DURATION)
	skill_started.emit(skill_id)
	return true

func _update_skill(delta: float) -> void:
	_dash_time = maxf(0.0, _dash_time - delta)
	_guard_time = maxf(0.0, _guard_time - delta)
	if not _skill_active:
		return
	_skill_time += delta
	var t := clampf(_skill_time / maxf(_skill_duration, 0.01), 0.0, 1.0)
	_trigger_skill_event(t)
	if _skill_time >= _skill_duration:
		_finish_skill()

func _finish_skill() -> void:
	if not _skill_active:
		return
	var finished := _skill_id
	_skill_active = false
	_skill_id = ""
	_skill_time = 0.0
	_skill_data = {}
	_wisp_remaining = 0
	skill_finished.emit(finished)

## Cast data from `SkillLibrary` decides *when* a talent lands, so a three-hit
## flurry, a five-arrow volley and a single heavy shockwave all share one code
## path while still feeling different.
func _trigger_skill_event(t: float) -> void:
	if _skill_data.is_empty():
		return
	var effect := str(_skill_data.get("effect", ""))
	match effect:
		"strike":
			var hits := maxi(1, int(_skill_data.get("hits", 1)))
			var first := float(_skill_data.get("hit_time", 0.34))
			var gap := float(_skill_data.get("hit_gap", 0.0))
			var reach := float(_skill_data.get("reach", 2.8))
			var damage := float(_skill_data.get("damage", 30.0))
			var min_dot := float(_skill_data.get("min_dot", 0.0))
			for i in hits:
				if t >= first + gap * float(i) and _once("skill_hit_%d" % i):
					_melee_strike(reach, damage, min_dot)
					_spawn_arc_slash(_skill_color(), reach * 0.85, 0.3, 105.0)
		"shockwave":
			var hit_time := float(_skill_data.get("hit_time", 0.5))
			if t >= hit_time and _once("skill_wave"):
				var radius := float(_skill_data.get("radius", 3.4))
				var damage := float(_skill_data.get("damage", 40.0))
				_melee_strike(radius, damage, -0.25)
				_spawn_shockwave(Color(0.62, 0.9, 0.98, 0.92), radius, 0.62)
		"projectile":
			if t >= float(_skill_data.get("release_time", 0.55)) and _once("skill_shot"):
				_fire_projectile("arrow", float(_skill_data.get("damage", 30.0)))
		"volley":
			var count := maxi(1, int(_skill_data.get("count", 5)))
			var first := float(_skill_data.get("first_shot", 0.5))
			var gap := float(_skill_data.get("shot_gap", 0.08))
			var spread := float(_skill_data.get("spread", 0.12))
			for i in count:
				if t >= first + gap * float(i) and _once("skill_volley_%d" % i):
					var fan := (float(i) - float(count - 1) * 0.5) * spread
					var direction := _aim_direction().rotated(Vector3.UP, fan)
					_fire_projectile("arrow", float(_skill_data.get("damage", 20.0)), direction)
		"wisps":
			if t >= float(_skill_data.get("release_time", 0.3)) and _once("skill_wisps"):
				_wisp_remaining = maxi(1, int(_skill_data.get("count", 3)))
				_wisp_timer = 0.0
				_wisp_gap = 0.09
				_wisp_power = float(_skill_data.get("damage", 18.0))
		"whirlwind":
			# A spinning ring: every hit reaches all the way around the hero.
			var hits := maxi(1, int(_skill_data.get("hits", 2)))
			var first := float(_skill_data.get("hit_time", 0.28))
			var gap := float(_skill_data.get("hit_gap", 0.30))
			var radius := float(_skill_data.get("radius", 3.15))
			var damage := float(_skill_data.get("damage", 28.0))
			for i in hits:
				if t >= first + gap * float(i) and _once("skill_whirl_%d" % i):
					_melee_strike(radius, damage, -1.0)
					_spawn_arc_slash(_skill_color(), radius, 0.42, 360.0)
					_spawn_shockwave(Color(0.95, 0.88, 0.62, 0.8), radius, 0.45)
		"dash_strike", "shadow_dash":
			# The dash carries the cut: the strike lands mid-lunge.
			var hit_time := float(_skill_data.get("hit_time", 0.28))
			if t >= hit_time and _once("skill_dash_hit"):
				_melee_strike(
					float(_skill_data.get("reach", 2.9)),
					float(_skill_data.get("damage", 40.0)),
					float(_skill_data.get("min_dot", 0.0))
				)
				_spawn_arc_slash(_skill_color(), float(_skill_data.get("reach", 2.9)) * 0.85, 0.26, 130.0)
		"wave":
			if t >= float(_skill_data.get("release_time", 0.30)) and _once("skill_wave_shot"):
				_fire_projectile("wave", float(_skill_data.get("damage", 38.0)))
		"line":
			# Earth Splitter: a committed furrow straight ahead.
			var hit_time := float(_skill_data.get("hit_time", 0.52))
			if t >= hit_time and _once("skill_line"):
				_line_strike(
					float(_skill_data.get("length", 8.0)),
					float(_skill_data.get("width", 1.9)),
					float(_skill_data.get("damage", 54.0))
				)
				_spawn_dust_burst(float(_skill_data.get("length", 8.0)), float(_skill_data.get("width", 1.9)))
		"rain":
			# Loosed high: each arrow lands somewhere on the marked ground.
			var count := maxi(1, int(_skill_data.get("count", 7)))
			var first := float(_skill_data.get("first_shot", 0.44))
			var gap := float(_skill_data.get("shot_gap", 0.075))
			for i in count:
				if t >= first + gap * float(i) and _once("skill_rain_%d" % i):
					_fire_projectile("rain_arrow", float(_skill_data.get("damage", 17.0)), _rain_direction())
		"multishot":
			if t >= float(_skill_data.get("release_time", 0.46)) and _once("skill_multishot"):
				var count := maxi(1, int(_skill_data.get("count", 5)))
				var spread := float(_skill_data.get("spread", 0.17))
				var damage := float(_skill_data.get("damage", 20.0))
				for i in count:
					var fan := (float(i) - float(count - 1) * 0.5) * spread
					_fire_projectile("arrow", damage, _aim_direction().rotated(Vector3.UP, fan))
		"piercing":
			if t >= float(_skill_data.get("release_time", 0.55)) and _once("skill_pierce"):
				_fire_projectile("arrow", float(_skill_data.get("damage", 46.0)), Vector3.ZERO,
					{"pierce": maxi(1, int(_skill_data.get("pierce", 4)))})
		"explosive":
			if t >= float(_skill_data.get("release_time", 0.56)) and _once("skill_explosive"):
				_fire_projectile("arrow", float(_skill_data.get("damage", 34.0)), Vector3.ZERO, {
					"explode_radius": float(_skill_data.get("radius", 3.0)),
					"explode_damage": float(_skill_data.get("blast_damage", 30.0)),
				})
		"fireball":
			if t >= float(_skill_data.get("release_time", 0.48)) and _once("skill_fireball"):
				_fire_projectile("fireball", float(_skill_data.get("damage", 32.0)), Vector3.ZERO, {
					"explode_radius": float(_skill_data.get("radius", 2.8)),
					"explode_damage": float(_skill_data.get("blast_damage", 28.0)),
				}, Color(1.0, 0.52, 0.18, 1.0))
		"ice_lance":
			if t >= float(_skill_data.get("release_time", 0.46)) and _once("skill_ice"):
				_fire_projectile("ice_lance", float(_skill_data.get("damage", 34.0)), Vector3.ZERO, {
					"slow": float(_skill_data.get("slow", 0.45)),
					"slow_duration": float(_skill_data.get("slow_duration", 3.0)),
				}, Color(0.55, 0.82, 1.0, 1.0))
		"lightning":
			# Marked ground; the storm answers after a short call.
			if _once("skill_lightning_call"):
				var point := _aim_point
				var damage := float(_skill_data.get("damage", 48.0))
				var radius := float(_skill_data.get("radius", 2.8))
				var delay := float(_skill_data.get("delay", 0.38))
				_spawn_ground_mark(point, radius, delay + 0.15)
				get_tree().create_timer(delay).timeout.connect(func() -> void:
					if is_inside_tree():
						_lightning_strike(point, damage, radius)
				)
		"arcane":
			var hit_time := float(_skill_data.get("hit_time", 0.40))
			if t >= hit_time and _once("skill_arcane"):
				var radius := float(_skill_data.get("radius", 3.6))
				_melee_strike(radius, float(_skill_data.get("damage", 40.0)), -1.0)
				_spawn_shockwave(Color(0.72, 0.5, 0.98, 0.9), radius, 0.6)
		"fan":
			if t >= float(_skill_data.get("release_time", 0.28)) and _once("skill_fan"):
				var count := maxi(1, int(_skill_data.get("count", 5)))
				var spread := float(_skill_data.get("spread", 0.21))
				var damage := float(_skill_data.get("damage", 17.0))
				for i in count:
					var fan := (float(i) - float(count - 1) * 0.5) * spread
					_fire_projectile("dagger", damage, _aim_direction().rotated(Vector3.UP, fan), {}, Color(0.85, 0.88, 0.95, 1.0))
		"poison":
			var hit_time := float(_skill_data.get("hit_time", 0.24))
			if t >= hit_time and _once("skill_poison_hit"):
				_melee_strike(
					float(_skill_data.get("reach", 2.6)),
					float(_skill_data.get("damage", 18.0)),
					float(_skill_data.get("min_dot", 0.0)),
					float(_skill_data.get("poison_damage", 8.0)),
					float(_skill_data.get("poison_duration", 6.0))
				)
				_spawn_arc_slash(Color(0.45, 0.85, 0.4, 0.9), float(_skill_data.get("reach", 2.6)) * 0.85, 0.26, 120.0)
				_spawn_shockwave(Color(0.4, 0.85, 0.35, 0.6), float(_skill_data.get("reach", 2.6)) * 0.6, 0.3)
		"foxfire_bolt":
			if t >= float(_skill_data.get("release_time", 0.34)) and _once("skill_foxbolt"):
				_fire_projectile("wisp", float(_skill_data.get("damage", 36.0)), Vector3.ZERO, {}, Color(1.0, 0.62, 0.3, 1.0))
		"clone":
			if t >= float(_skill_data.get("release_time", 0.4)) and _once("skill_clone"):
				_spawn_clone(
					float(_skill_data.get("clone_duration", 5.0)),
					float(_skill_data.get("radius", 8.0))
				)
		"orbs":
			if t >= 0.3 and _once("skill_orbs"):
				_spawn_orbs(
					float(_skill_data.get("count", 3)),
					float(_skill_data.get("damage", 14.0)),
					float(_skill_data.get("orb_interval", 0.55)),
					float(_skill_data.get("orb_duration", 5.0))
				)
		"heal":
			# The HUD applies the vitals; the visuals live here so the mend has
			# a body: green motes climbing out of the ground.
			if _once("skill_motes"):
				_spawn_motes(Color(0.55, 0.95, 0.55, 1.0), 10, 0.9, "rise")
		"mana":
			# Focus: blue motes drift down and settle into the chest.
			if _once("skill_motes"):
				_spawn_motes(Color(0.5, 0.75, 1.0, 1.0), 10, 0.9, "converge")
		"recall":
			# Returning to the well: a column of gold light around the hero.
			if _once("skill_recall_fx"):
				_spawn_recall_beam()

func is_skill_active() -> bool:
	return _skill_active

func is_guarding() -> bool:
	return _guard_time > 0.0

func _apply_weapon_visibility() -> void:
	for id in _combat_nodes:
		(_combat_nodes[id] as Node3D).visible = id == equipped_weapon
	_torch_rig.visible = _torch_on
	_apply_offhand_visibility()

func _apply_offhand_visibility() -> void:
	var show_offhand := offhand_in_use()
	for id in _offhand_nodes:
		var node := _offhand_nodes[id] as Node3D
		node.visible = show_offhand and id == equipped_offhand
	if _offhand_lantern != null:
		var lamp := _offhand_lantern.get_node_or_null("FireLight") as OmniLight3D
		if lamp != null:
			lamp.visible = show_offhand and equipped_offhand == "lantern"
	if _offhand_charm != null:
		var glow := _offhand_charm.get_node_or_null("CharmGlow") as OmniLight3D
		if glow != null:
			glow.visible = show_offhand and equipped_offhand == "charm"

func update_trail_tip() -> void:
	var node := _combat_nodes.get(equipped_weapon) as Node3D
	if node != null:
		_blade_trail.set_tip(node, _trail_tip_offsets.get(equipped_weapon, Vector3(0.0, 0.7, 0.0)))

func get_weapon_data(weapon_id := "") -> Dictionary:
	var id := weapon_id if not weapon_id.is_empty() else equipped_weapon
	return WeaponLibrary.WEAPONS.get(id, {})

func can_attack() -> bool:
	return not _attack_active and not _skill_active and _dash_time <= 0.0 and _attack_cooldown <= 0.0 and not movement_locked

func attack() -> bool:
	if not can_attack():
		return false
	var data := get_weapon_data()
	if data.is_empty():
		return false

	_attack_active = true
	_attack_time = 0.0
	_attack_duration = float(data["anim_duration"])
	_attack_cooldown = float(data["cooldown"])
	_event_flags.clear()
	_wisp_remaining = 0
	_wisp_power = 12.0

	_face_aim_point()
	if not _has_aim:
		_face_nearest_target(float(data["range"]))
	var trail_color: Color = data["trail_color"]
	if trail_color.a > 0.01:
		_blade_trail.begin(trail_color, _attack_duration * 0.9)
	attack_started.emit(equipped_weapon)
	return true

func _update_attack(delta: float) -> void:
	if not _attack_active:
		return
	_attack_time += delta
	var t := clampf(_attack_time / maxf(_attack_duration, 0.01), 0.0, 1.0)
	_trigger_attack_event(t)
	if _attack_time >= _attack_duration:
		_finish_attack()

func _finish_attack() -> void:
	_attack_active = false
	_attack_time = 0.0
	_wisp_remaining = 0
	_blade_trail.end_trail()
	attack_finished.emit(equipped_weapon)

func _trigger_attack_event(t: float) -> void:
	match equipped_weapon:
		"sword":
			if t >= 0.36 and _once("sword_hit"):
				_melee_strike(2.9, 34.0, 0.15)
		"dagger":
			if t >= 0.2 and _once("dagger_hit_1"):
				_melee_strike(2.2, 16.0, 0.0)
			if t >= 0.58 and _once("dagger_hit_2"):
				_melee_strike(2.4, 18.0, 0.0)
		"staff":
			if t >= 0.56 and _once("staff_slam"):
				_melee_strike(3.1, 26.0, -0.2)
				_spawn_shockwave(Color(0.55, 0.96, 0.88, 0.9), 3.4, 0.6)
		"bow":
			if t >= 0.56 and _once("bow_release"):
				_fire_projectile("arrow", 30.0)
		"kitsune":
			if t >= 0.32 and _once("kitsune_cast"):
				_wisp_remaining = 3
				_wisp_timer = 0.0

func _once(flag: String) -> bool:
	if _event_flags.has(flag):
		return false
	_event_flags[flag] = true
	return true

func _update_wisps(delta: float) -> void:
	if _wisp_remaining <= 0:
		return
	_wisp_timer -= delta
	if _wisp_timer > 0.0:
		return
	_wisp_remaining -= 1
	_wisp_timer = _wisp_gap
	_fire_projectile("wisp", _wisp_power)

## Spirit Orbs: three little spirits circle the hero and take turns spitting an
## ember at the nearest foe, outliving the cast that summoned them.
func _update_orbs(delta: float) -> void:
	if _orb_nodes.is_empty():
		return
	_orb_life -= delta
	if _orb_life <= 0.0:
		for orb in _orb_nodes:
			if is_instance_valid(orb):
				orb.queue_free()
		_orb_nodes.clear()
		_orb_root = null
		return
	if _orb_root != null and is_instance_valid(_orb_root):
		_orb_root.rotation.y += 1.8 * delta
	_orb_timer -= delta
	if _orb_timer > 0.0:
		return
	_orb_timer = _orb_gap
	_orb_index += 1
	_fire_projectile("wisp", _orb_power, Vector3.ZERO, {}, Color(1.0, 0.62, 0.3, 1.0))

func _melee_strike(reach: float, damage: float, min_dot: float, poison_damage := 0.0, poison_duration := 0.0) -> void:
	var forward := -global_transform.basis.z
	var dealt := (damage + _weapon_power) * offhand_damage_multiplier("melee")
	var lingering := (poison_damage + _weapon_power * 0.25) * offhand_damage_multiplier("melee")
	for candidate in _hostiles():
		if not is_instance_valid(candidate) or not candidate.has_method("take_damage"):
			continue
		if candidate.has_method("is_defeated") and bool(candidate.call("is_defeated")):
			continue
		var offset: Vector3 = candidate.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > reach:
			continue
		if distance > 0.01 and forward.dot(offset / distance) < min_dot:
			continue
		candidate.take_damage(dealt, global_position + Vector3(0.0, 1.0, 0.0))
		if poison_damage > 0.0 and candidate.has_method("apply_poison"):
			candidate.call("apply_poison", lingering, poison_duration, global_position)
		enemy_hit.emit(candidate, dealt)

## Earth Splitter's furrow: a committed straight line ahead of the hero, hit by
## length and width rather than a facing cone.
func _line_strike(length: float, width: float, damage: float) -> void:
	var forward := _aim_direction()
	var dealt := (damage + _weapon_power) * offhand_damage_multiplier("melee")
	for candidate in _hostiles():
		if not is_instance_valid(candidate) or not candidate is Node3D:
			continue
		if candidate.has_method("is_defeated") and bool(candidate.call("is_defeated")):
			continue
		var offset: Vector3 = (candidate as Node3D).global_position - global_position
		offset.y = 0.0
		var along := forward.dot(offset)
		if along < 0.0 or along > length:
			continue
		var lateral := (offset - forward * along).length()
		if lateral > width * 0.5:
			continue
		(candidate as Node3D).take_damage(dealt, global_position + Vector3(0.0, 1.0, 0.0))
		enemy_hit.emit(candidate, dealt)
	_spawn_furrow(length, width)

## The visual half of Earth Splitter: a torn earthen seam that flares and fades.
func _spawn_furrow(length: float, width: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var seam := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width * 0.8, 0.1, length)
	seam.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.33, 0.2, 0.9)
	material.emission_enabled = true
	material.emission = Color(0.95, 0.6, 0.25)
	material.emission_energy_multiplier = 0.9
	seam.material_override = material
	seam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(seam)
	var forward := _aim_direction()
	var center := global_position + forward * (length * 0.5)
	center.y = 0.06
	seam.global_position = center
	seam.look_at(center + forward, Vector3.UP)
	var tween := seam.create_tween()
	tween.set_parallel(true)
	tween.tween_property(material, "emission_energy_multiplier", 0.0, 0.7)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.7)
	tween.chain().tween_callback(seam.queue_free)

## Lightning Strike: a white pillar cracks down on the marked ground, flashes,
## and hammers everything near it.
func _lightning_strike(point: Vector3, damage: float, radius: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var dealt := (damage + _weapon_power) * offhand_damage_multiplier("spell")
	var pillar := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.16
	mesh.bottom_radius = 0.42
	mesh.height = 14.0
	mesh.radial_segments = 7
	pillar.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
	material.emission_enabled = true
	material.emission = Color(0.92, 0.95, 1.0)
	material.emission_energy_multiplier = 3.2
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pillar.material_override = material
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(pillar)
	var strike_point := point
	strike_point.y = 7.0
	pillar.global_position = strike_point
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.9, 0.94, 1.0)
	flash.light_energy = 3.4
	flash.omni_range = radius + 3.0
	flash.shadow_enabled = false
	flash.position = point + Vector3(0.0, 1.6, 0.0)
	parent.add_child(flash)
	var tween := pillar.create_tween()
	tween.set_parallel(true)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.34)
	tween.tween_property(flash, "light_energy", 0.0, 0.34)
	tween.chain().tween_callback(pillar.queue_free)
	tween.chain().tween_callback(flash.queue_free)
	_spawn_shockwave(Color(0.92, 0.95, 1.0, 0.85), radius, 0.5)
	for candidate in _hostiles():
		if not is_instance_valid(candidate) or not candidate is Node3D:
			continue
		if candidate.has_method("is_defeated") and bool(candidate.call("is_defeated")):
			continue
		if (candidate as Node3D).global_position.distance_to(point) > radius + 0.4:
			continue
		if not candidate.has_method("take_damage"):
			continue
		(candidate as Node3D).take_damage(dealt, point + Vector3(0.0, 1.0, 0.0))
		enemy_hit.emit(candidate, dealt)

## Rain of Arrows: pick a landing spot on the marked ground and loft a shaft
## high enough that its fall carries it there.
func _rain_direction() -> Vector3:
	var radius := float(_skill_data.get("radius", 3.2))
	var offset := Vector3(randf_range(-radius, radius) * 0.8, 0.0, randf_range(-radius, radius) * 0.8)
	var goal := (_aim_point + offset)
	goal.y = 0.0
	var origin := _left_hand.global_position
	var flat := goal - origin
	flat.y = 0.0
	var distance := flat.length()
	# Rain arrows fall at gravity 16 while flying 20 m/s: aim the launch above
	# the mark so the drop lands the shaft on it.
	var lift := clampf(distance * distance * 16.0 / (2.0 * 20.0 * 20.0), 1.0, 4.0)
	var direction := (goal - origin + Vector3(0.0, lift + 0.4, 0.0)).normalized()
	if direction.length_squared() < 0.01:
		direction = Vector3.UP
	return direction

## Illusion Clone: a smiling copy stands in the road and nearby enemies argue
## with it instead of the hero, for a while.
func _spawn_clone(duration: float, radius: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var clone := MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.26
	body.height = 1.15
	clone.mesh = body
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.97, 0.76, 0.5, 0.6)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(1.0, 0.62, 0.3)
	material.emission_energy_multiplier = 0.7
	clone.material_override = material
	clone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(clone)
	var spot := global_position + _aim_direction() * 1.3
	spot.y = 0.85
	clone.global_position = spot
	var bob := clone.create_tween().set_loops()
	bob.tween_property(clone, "position:y", 0.95, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(clone, "position:y", 0.85, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Each second of the illusion, pull aggro from everything in reach.
	var elapsed := 0.0
	while elapsed < duration and is_inside_tree():
		var wait := minf(1.0, duration - elapsed)
		await get_tree().create_timer(wait).timeout
		if not is_inside_tree() or not is_instance_valid(clone):
			return
		elapsed += wait
		var point := clone.global_position
		for candidate in _hostiles():
			if not is_instance_valid(candidate) or not candidate is Node3D:
				continue
			if candidate.has_method("is_defeated") and bool(candidate.call("is_defeated")):
				continue
			if candidate.has_method("distract") and (candidate as Node3D).global_position.distance_to(point) <= radius:
				candidate.call("distract", point, 1.5)
	if is_instance_valid(clone):
		clone.queue_free()

## Spirit Orbs: a small orbit of embers that circles the hero and takes turns
## spitting foxfire at whatever comes close. They outlive the cast.
func _spawn_orbs(count: int, damage: float, interval: float, duration: float) -> void:
	for orb in _orb_nodes:
		if is_instance_valid(orb):
			orb.queue_free()
	_orb_nodes.clear()
	_orb_root = null
	_orb_power = damage
	_orb_gap = maxf(interval, 0.2)
	_orb_timer = 0.0
	_orb_life = duration
	_orb_index = 0
	var root := Node3D.new()
	add_child(root)
	root.position = Vector3(0.0, 1.05, 0.0)
	_orb_root = root
	var color := Color(1.0, 0.62, 0.3, 1.0)
	for i in maxi(1, count):
		var orb := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.13
		mesh.height = 0.26
		mesh.radial_segments = 8
		mesh.rings = 5
		orb.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.4
		orb.material_override = material
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ring_angle := TAU * (float(i) / float(maxi(1, count))) + 0.35
		orb.position = Vector3(cos(ring_angle) * 0.85, 0.0, sin(ring_angle) * 0.85)
		root.add_child(orb)
		_orb_nodes.append(orb)

## Every damageable target the hero may strike: practice dummies, wild monsters
## and the named elite all answer the same call, so one hit path serves the whole
## Reach.
func _hostiles() -> Array:
	var result := []
	for group in ["training_dummy", "enemy"]:
		for node in get_tree().get_nodes_in_group(group):
			if not result.has(node):
				result.append(node)
	return result

func _spawn_shockwave(color: Color, radius: float, duration: float) -> void:
	var wave := SHOCKWAVE.new()
	get_parent().add_child(wave)
	wave.global_position = global_position + (-global_transform.basis.z) * 0.7 + Vector3(0.0, 0.08, 0.0)
	wave.setup(color, radius, duration)

# ---------------------------------------------------------------------------
# Skill visual effects
# ---------------------------------------------------------------------------

## The color a skill should wear: its school's hue when it has one, otherwise
## the trail color of whatever is in hand.
func _skill_color(fallback := Color(0.9, 0.85, 0.6, 1.0)) -> Color:
	var school: Dictionary = SKILL_LIBRARY.school(str(_skill_data.get("school", "")))
	if school.has("color"):
		var color: Color = school["color"]
		if color.a > 0.01:
			return color
	var weapon := get_weapon_data()
	if weapon.has("trail_color"):
		var trail: Color = weapon["trail_color"]
		if trail.a > 0.01:
			return trail
	return fallback

## A sweeping crescent of light that traces the swing: short glowing segments
## ride a pivot that sweeps through `sweep_degrees` while the whole thing fades.
## A 360-degree sweep spins a full ring — the whirlwind's signature.
func _spawn_arc_slash(color: Color, radius: float, duration: float, sweep_degrees: float) -> void:
	var pivot := Node3D.new()
	add_child(pivot)
	pivot.position = Vector3(0.0, 1.0, 0.0)
	var forward := _aim_direction()
	var base_yaw := atan2(-forward.x, -forward.z)
	pivot.rotation.y = base_yaw
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, minf(color.a, 0.9))
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 2.2
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.24, 0.3)
	var full_circle := sweep_degrees >= 359.0
	var segments := 7
	var half := deg_to_rad(sweep_degrees) * 0.5
	for i in segments:
		var a := TAU * float(i) / float(segments) if full_circle \
			else lerpf(-half, half, float(i) / float(maxi(1, segments - 1)))
		var segment := MeshInstance3D.new()
		segment.mesh = mesh
		segment.material_override = material
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		segment.position = Vector3(sin(a) * radius, 0.0, -cos(a) * radius)
		segment.rotation.y = -a
		pivot.add_child(segment)
	var sweep := TAU if full_circle else deg_to_rad(sweep_degrees)
	var tween := pivot.create_tween()
	tween.set_parallel(true)
	tween.tween_property(pivot, "rotation:y", base_yaw + sweep, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.chain().tween_callback(pivot.queue_free)

## A ward pulse: a flat ring of light around the hero that beats like a heart
## while the guard holds, then fades.
func _spawn_ward_ring(color: Color, duration: float) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.82
	torus.outer_radius = 1.0
	torus.rings = 28
	torus.ring_segments = 4
	ring.mesh = torus
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, 0.7)
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 1.8
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.position = Vector3(0.0, 0.12, 0.0)
	ring.scale = Vector3.ONE * 0.8
	var beat := maxf(duration / 3.0, 0.15)
	var pulse := ring.create_tween().set_loops(3)
	pulse.tween_property(ring, "scale", Vector3.ONE * 1.2, beat) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(ring, "scale", Vector3.ONE * 0.8, beat) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var fade := ring.create_tween()
	fade.tween_property(material, "albedo_color:a", 0.0, duration)
	fade.tween_callback(ring.queue_free)

## Little lights that travel along the hero: they rise out of the ground for a
## mend ("rise") or drift down and inward for a focus ("converge").
func _spawn_motes(color: Color, count: int, duration: float, mode: String) -> void:
	for i in maxi(1, count):
		var mote := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.06
		mesh.height = 0.12
		mesh.radial_segments = 6
		mesh.rings = 3
		mote.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(color.r, color.g, color.b, 0.85)
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b)
		material.emission_energy_multiplier = 2.4
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mote.material_override = material
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mote)
		var angle := TAU * float(i) / float(maxi(1, count)) + randf() * 0.5
		var start_radius := randf_range(0.8, 1.3)
		var target_height := randf_range(0.7, 1.6)
		var start: Vector3
		var goal: Vector3
		if mode == "converge":
			start = Vector3(cos(angle) * (start_radius + 0.6), target_height + 1.3, sin(angle) * (start_radius + 0.6))
			goal = Vector3(cos(angle) * 0.2, target_height, sin(angle) * 0.2)
		else:
			start = Vector3(cos(angle) * start_radius, randf_range(0.05, 0.3), sin(angle) * start_radius)
			goal = Vector3(cos(angle) * 0.15, target_height + 0.6, sin(angle) * 0.15)
		mote.position = start
		var delay := randf_range(0.0, duration * 0.3)
		var travel := maxf(duration - delay, 0.1)
		var tween := mote.create_tween()
		tween.tween_interval(delay)
		tween.tween_property(mote, "position", goal, travel) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(mote.queue_free)
		var fade := mote.create_tween()
		fade.tween_interval(delay)
		fade.tween_property(material, "albedo_color:a", 0.0, travel)

## Returning to the well: a column of gold light around the hero plus motes
## climbing it, so the recall reads before the world lets go.
func _spawn_recall_beam() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var beam := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.62
	mesh.height = 5.5
	mesh.radial_segments = 10
	beam.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.85, 0.5, 0.45)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.85, 0.5)
	material.emission_energy_multiplier = 2.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(beam)
	beam.global_position = global_position + Vector3(0.0, 2.6, 0.0)
	var tween := beam.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.9)
	tween.tween_callback(beam.queue_free)
	_spawn_motes(Color(1.0, 0.85, 0.5, 1.0), 12, 1.0, "rise")

## Dash streaks: thin light lines ahead of the hero streaming backward, so the
## lunge has visible wind in it.
func _spawn_speed_lines() -> void:
	var direction := _dash_direction
	if direction.length_squared() < 0.01:
		direction = -global_transform.basis.z
	direction = direction.normalized()
	var lateral := direction.cross(Vector3.UP).normalized()
	for i in 6:
		var line := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.035, 0.035, randf_range(0.5, 0.9))
		line.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.95, 0.95, 1.0, 0.55)
		material.emission_enabled = true
		material.emission = Color(0.9, 0.92, 1.0)
		material.emission_energy_multiplier = 1.6
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		line.material_override = material
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(line)
		var spot := global_position \
			+ direction * randf_range(0.7, 1.7) \
			+ lateral * randf_range(-0.9, 0.9) \
			+ Vector3(0.0, randf_range(0.2, 1.4), 0.0)
		line.global_position = spot
		line.look_at(spot + direction, Vector3.UP)
		var tween := line.create_tween()
		tween.set_parallel(true)
		tween.tween_property(line, "global_position", spot - direction * 2.6, 0.28)
		tween.tween_property(material, "albedo_color:a", 0.0, 0.28)
		tween.chain().tween_callback(line.queue_free)

## Earth Splitter's dust: clods and grit puff up along the furrow as the ground
## tears open.
func _spawn_dust_burst(length: float, width: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var forward := _aim_direction()
	var lateral := Vector3(forward.z, 0.0, -forward.x)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.4, 0.28, 0.75)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 1.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	mesh.radial_segments = 7
	mesh.rings = 4
	for i in 9:
		var puff := MeshInstance3D.new()
		puff.mesh = mesh
		puff.material_override = material
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var along := (0.12 + 0.76 * float(i) / 8.0) * length + randf_range(-0.3, 0.3)
		var side := randf_range(-width, width) * 0.5
		var spot := global_position + forward * along + lateral * side
		spot.y = randf_range(0.1, 0.35)
		parent.add_child(puff)
		puff.global_position = spot
		puff.scale = Vector3.ONE * randf_range(0.5, 0.8)
		var tween := puff.create_tween()
		tween.set_parallel(true)
		tween.tween_property(puff, "scale", Vector3.ONE * randf_range(1.5, 2.1), 0.55)
		tween.tween_property(puff, "global_position", spot + Vector3(
			randf_range(-0.4, 0.4), randf_range(0.5, 0.9), randf_range(-0.4, 0.4)), 0.55)
		tween.tween_property(material, "albedo_color:a", 0.0, 0.55)
		tween.chain().tween_callback(puff.queue_free)

## The storm's promise: a faint ring burned onto the marked ground while the
## lightning gathers, then hammered by the strike itself.
func _spawn_ground_mark(point: Vector3, radius: float, duration: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var mark := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.86
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 4
	mark.mesh = torus
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.9, 1.0, 0.55)
	material.emission_enabled = true
	material.emission = Color(0.85, 0.9, 1.0)
	material.emission_energy_multiplier = 1.6
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mark.material_override = material
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mark)
	mark.global_position = point + Vector3(0.0, 0.09, 0.0)
	mark.scale = Vector3.ONE * radius * 0.35
	var tween := mark.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mark, "scale", Vector3.ONE * radius, duration * 0.7) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.chain().tween_callback(mark.queue_free)

## A brief bloom where a shot or spell leaves the hand — small, quick, colored
## like the projectile it launches.
func _spawn_cast_flash(spawn: Vector3, color: Color) -> void:
	var parent := get_parent()
	if parent == null or color.a <= 0.01:
		return
	var flash := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 8
	mesh.rings = 4
	flash.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, 0.7)
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 2.6
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.material_override = material
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flash)
	flash.global_position = spawn
	flash.scale = Vector3.ONE * 0.5
	var tween := flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * 1.5, 0.22)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.22)
	tween.chain().tween_callback(flash.queue_free)


func _fire_projectile(kind: String, damage: float, direction_override := Vector3.ZERO, options := {}, color_override := Color(0.0, 0.0, 0.0, 0.0)) -> void:
	var target := _find_nearest_dummy(18.0)
	var dealt := (damage + _weapon_power) * offhand_damage_multiplier("missile")
	var direction := _aim_direction()
	if direction_override.length_squared() > 0.001:
		direction = direction_override.normalized()
	elif kind == "arrow" or kind == "rain_arrow":
		# Arrows follow the box reticle. If the HUD has not supplied an aim
		# point, fall back to the nearest straw man, then to the hero's facing.
		direction = _aim_direction_3d(1.04, 0.92)
		if not _has_aim and target != null:
			direction = (target.global_position + Vector3(0.0, 0.9, 0.0) \
				- (global_position + Vector3(0.0, 1.04, 0.0))).normalized()
	elif kind == "wisp" or kind == "dagger":
		# Wisps and thrown knives curve after the nearest foe.
		if target != null:
			direction = (target.global_position + Vector3(0.0, 0.9, 0.0) \
				- (global_position + Vector3(0.0, 1.05, 0.0))).normalized()
	else:
		# Spells and energy waves fly the aimed line.
		direction = _aim_direction_3d(1.05, 0.95)
	var spawn := global_position + Vector3(0.0, 1.02, 0.0) + direction * 0.55
	if kind == "arrow" or kind == "rain_arrow":
		spawn = _left_hand.global_position + direction * 0.2
	var projectile := PROJECTILE.new()
	get_parent().add_child(projectile)
	projectile.global_position = spawn
	projectile.hit_target.connect(_on_projectile_hit)
	var color := color_override
	if color.a <= 0.01:
		color = _projectile_color(kind)
	projectile.configure(kind, direction, target, dealt, color, options)
	_spawn_cast_flash(spawn, color)

func _projectile_color(kind: String) -> Color:
	match kind:
		"wisp":
			return Color(0.62, 0.98, 0.9, 1.0)
		"wave":
			return Color(0.98, 0.92, 0.62, 1.0)
		"dagger":
			return Color(0.85, 0.88, 0.95, 1.0)
		"bolt":
			return Color(0.85, 0.92, 1.0, 1.0)
		"fireball":
			return Color(1.0, 0.52, 0.18, 1.0)
		"ice_lance":
			return Color(0.55, 0.82, 1.0, 1.0)
	return Color(0.96, 0.86, 0.55, 1.0)

func _on_projectile_hit(target: Node, amount: float) -> void:
	enemy_hit.emit(target, amount)

func _find_nearest_dummy(max_range: float) -> Node3D:
	var best: Node3D = null
	var best_distance := max_range
	for candidate in _hostiles():
		if not is_instance_valid(candidate) or not candidate is Node3D:
			continue
		if candidate.has_method("is_defeated") and bool(candidate.call("is_defeated")):
			continue
		var distance := global_position.distance_to((candidate as Node3D).global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate as Node3D
	return best

func _face_nearest_target(max_range: float) -> void:
	var target := _find_nearest_dummy(max_range)
	if target == null:
		return
	var direction := target.global_position - global_position
	if Vector2(direction.x, direction.z).length_squared() < 0.01:
		return
	rotation.y = atan2(-direction.x, -direction.z)

## The HUD owns the mouse-to-ground projection; the character only needs the
## resulting world point. Aiming is separate from movement so a walking hero can
## still shoot or cast at the box while the body keeps its travel heading.
func set_aim_point(point: Vector3) -> void:
	_aim_point = point
	_has_aim = true

func get_aim_point() -> Vector3:
	return _aim_point

func has_aim_point() -> bool:
	return _has_aim

func set_aim_facing(enabled: bool) -> void:
	_aim_facing = enabled

func is_aim_facing() -> bool:
	return _aim_facing

## Flat direction from the hero to the aim mark, falling back to the body's
## forward axis when the reticle is too close to resolve a heading.
func _aim_direction() -> Vector3:
	var direction := -global_transform.basis.z
	direction.y = 0.0
	if _has_aim:
		var offset := _aim_point - global_position
		offset.y = 0.0
		if offset.length_squared() > 0.04:
			direction = offset.normalized()
	if direction.length_squared() < 0.001:
		direction = Vector3.FORWARD
	return direction.normalized()

## A 3D aim vector for projectiles: the reticle lies on the ground, so lift the
## goal to chest height to avoid firing every arrow into the dirt.
func _aim_direction_3d(from_height: float, to_height: float) -> Vector3:
	var origin := global_position + Vector3(0.0, from_height, 0.0)
	var goal := _aim_point + Vector3(0.0, to_height, 0.0)
	if _has_aim and (goal - origin).length_squared() > 0.25:
		return (goal - origin).normalized()
	var flat := -global_transform.basis.z
	flat.y = 0.0
	if flat.length_squared() < 0.001:
		flat = Vector3.FORWARD
	return (flat.normalized() + Vector3(0.0, 0.04, 0.0)).normalized()

func _face_aim_point() -> void:
	var direction := _aim_direction()
	rotation.y = atan2(-direction.x, -direction.z)

func _turn_toward_aim(delta: float) -> void:
	var direction := _aim_direction()
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_speed * 0.65 * delta))

func _animate(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var target_blend := clampf(horizontal_speed / walk_speed, 0.0, 1.15)
	_move_blend = lerpf(_move_blend, target_blend, 1.0 - exp(-11.0 * delta))
	_idle_time += delta

	var amp := _move_blend
	var body_pose := _current_body_pose(horizontal_speed)
	var stride := maxf(stride_length * float(body_pose["stride"]), 0.35)
	if horizontal_speed > 0.05:
		_walk_phase = fmod(_walk_phase + TAU * (horizontal_speed / stride) * delta, TAU)

	var swing := sin(_walk_phase)
	var idle_weight := 1.0 - clampf(amp, 0.0, 1.0)
	var run_lean := clampf((horizontal_speed - walk_speed) / maxf(run_speed - walk_speed, 0.01), 0.0, 1.0)
	var bounce := float(body_pose["bounce"])
	var breath := sin(_idle_time * 1.7) * 0.007 * idle_weight
	var idle_sway := sin(_idle_time * 0.85) * idle_weight

	# --- Legs -------------------------------------------------------------
	# The cycle is read as four beats per foot: contact, mid-stance, toe-off and
	# swing. `swing` drives the hip; the raised cosines isolate the leg that is
	# actually off the ground, so each weapon can dial its own foot clearance.
	var hip_mult := float(body_pose["hip"])
	var knee_mult := float(body_pose["knee"])
	var crouch := float(body_pose["crouch"]) * (0.45 + 0.55 * amp)
	var stance := float(body_pose["stance"])
	var step_lift := float(body_pose["step_lift"])
	var heel := float(body_pose["heel"])
	var toe := float(body_pose["toe"])
	var pelvis_bob := float(body_pose["bob"])
	var weight_shift := float(body_pose["weight"])
	var shoulder_roll := float(body_pose["shoulder_roll"])
	var arm_lag := float(body_pose["arm_lag"])
	var flight := float(body_pose["flight"])
	var head_stabilize := float(body_pose["head_stabilize"])

	var left_swing := maxf(cos(_walk_phase), 0.0)
	var right_swing := maxf(-cos(_walk_phase), 0.0)
	var left_strike := clampf(sin(_walk_phase), 0.0, 1.0)
	var right_strike := clampf(-sin(_walk_phase), 0.0, 1.0)
	var left_push := clampf(-sin(_walk_phase), 0.0, 1.0)
	var right_push := clampf(sin(_walk_phase), 0.0, 1.0)

	var left_lift := pow(left_swing, 1.35) * step_lift
	var right_lift := pow(right_swing, 1.35) * step_lift
	var left_hip_angle := swing * hip_swing * amp * hip_mult
	var right_hip_angle := -swing * hip_swing * amp * hip_mult
	var left_knee_angle := -knee_bend * amp * knee_mult * left_lift - 0.035 * amp - crouch
	var right_knee_angle := -knee_bend * amp * knee_mult * right_lift - 0.035 * amp - crouch

	_left_hip.rotation.x = left_hip_angle
	_right_hip.rotation.x = right_hip_angle
	_left_hip.rotation.z = -stance
	_right_hip.rotation.z = stance
	_left_knee.rotation.x = left_knee_angle
	_right_knee.rotation.x = right_knee_angle

	# --- Feet -------------------------------------------------------------
	# Contact is a heel strike (toe up); push-off is a toe-off (toe down). A
	# swinging foot relaxes instead of holding the shin's angle, which is what
	# makes the step read as a step rather than a pendulum.
	var roll_mult := float(body_pose["foot_roll"])
	var left_foot_roll := foot_roll * amp * roll_mult * (left_strike * heel - left_push * 0.9 * toe)
	var right_foot_roll := foot_roll * amp * roll_mult * (right_strike * heel - right_push * 0.9 * toe)
	left_foot_roll *= 1.0 - left_swing * 0.35
	right_foot_roll *= 1.0 - right_swing * 0.35
	_left_foot.rotation.x = -(left_hip_angle + left_knee_angle) + left_foot_roll
	_right_foot.rotation.x = -(right_hip_angle + right_knee_angle) + right_foot_roll

	# --- Arms -------------------------------------------------------------
	# The arm swing lags the legs by a fraction of a beat. Elbows tighten on the
	# forward swing, and the run adds a compact, purposeful bend.
	var arm_phase := _walk_phase - 0.10 * arm_lag
	var arm_swing_value := sin(arm_phase)
	var arm_mult := float(body_pose["arm"])
	_left_shoulder.rotation.x = -arm_swing_value * arm_swing * amp * arm_mult
	_right_shoulder.rotation.x = arm_swing_value * arm_swing * amp * arm_mult
	_left_shoulder.rotation.z = -0.08 - 0.018 * amp
	_right_shoulder.rotation.z = 0.08 + 0.018 * amp
	_left_elbow.rotation.x = 0.25 + maxf(0.0, arm_swing_value) * 0.24 * amp + run_lean * 0.2
	_right_elbow.rotation.x = 0.25 + maxf(0.0, -arm_swing_value) * 0.24 * amp + run_lean * 0.2

	# --- Pelvis -----------------------------------------------------------
	# Keep the pelvis at the height of the longest leg so the planted foot stays
	# on the ground while the other swings through. Two bobs per cycle ride over
	# the stance leg; a sprint gets a light airborne lift.
	var left_leg_height := _upper_leg_length * cos(left_hip_angle) \
		+ _lower_leg_length * cos(left_hip_angle + left_knee_angle)
	var right_leg_height := _upper_leg_length * cos(right_hip_angle) \
		+ _lower_leg_length * cos(right_hip_angle + right_knee_angle)
	var hip_height := maxf(left_leg_height, right_leg_height) + _foot_drop + 0.003
	hip_height += foot_clearance * amp
	var bob_wave := 0.5 - 0.5 * cos(_walk_phase * 2.0)
	hip_height += bob_wave * 0.016 * amp * pelvis_bob
	hip_height += flight * RUN_FLIGHT_HEIGHT * amp * run_lean * (0.35 + 0.65 * bob_wave)
	var hover := float(body_pose["float"]) * (0.55 + 0.45 * idle_weight)
	hip_height += sin(_idle_time * 1.6) * hover

	var sway := float(body_pose["sway"])
	var roll := float(body_pose["roll"])
	_body.position.y = hip_height
	# Weight settles over whichever foot is planted, so the hips travel sideways
	# with the stance leg and the free hip drops.
	_body.position.x = cos(_walk_phase) * sway * amp * weight_shift + idle_sway * sway * 0.5
	_body.position.z = 0.0
	_body.rotation.y = -swing * 0.050 * amp * float(body_pose["hip_yaw"])
	_body.rotation.z = -swing * 0.032 * amp * roll * weight_shift + idle_sway * 0.006 * roll

	# --- Torso ------------------------------------------------------------
	_upper_body.position.y = breath + sin(_walk_phase * 2.0) * 0.009 * amp * bounce
	var lean_mult := float(body_pose["lean"])
	_upper_body.rotation.x = -0.050 * amp * lean_mult - 0.10 * run_lean * lean_mult
	_upper_body.rotation.y = swing * 0.140 * amp * float(body_pose["twist"])
	# The chest counter-rolls against the pelvis, keeping the shoulders square
	# while the hips do the walking.
	_upper_body.rotation.z = swing * 0.024 * amp * shoulder_roll

	# --- Head -------------------------------------------------------------
	# The gaze stays level: the neck counters most of the torso lean and pelvis
	# roll, then adds only as much bob as this weapon allows.
	var head_look := float(body_pose["head_look"])
	var head_bob := float(body_pose["head_bob"])
	var idle_look := sin(_idle_time * 0.55) * 0.22 * idle_weight * head_look
	var stabilize := clampf(head_stabilize, 0.0, 1.6)
	_head.rotation.y = -_upper_body.rotation.y * 0.70 + idle_look
	_head.rotation.x = 0.03 + run_lean * 0.075 * head_bob \
		+ sin(_walk_phase * 2.0) * 0.015 * amp * head_bob \
		- _upper_body.rotation.x * 0.55 * stabilize
	_head.rotation.z = -_body.rotation.z * 0.45 * stabilize + float(body_pose["head_tilt"]) * idle_weight \
		+ sin(_idle_time * 0.9 + 0.4) * 0.02 * idle_weight * head_look

	var carry := _current_carry_pose(horizontal_speed)
	_apply_carry_pose(carry, amp, delta, body_pose)

	var attack_t := 0.0
	if _attack_active:
		attack_t = clampf(_attack_time / maxf(_attack_duration, 0.01), 0.0, 1.0)
		_apply_attack_pose(attack_t)
	elif _skill_active:
		var skill_t := clampf(_skill_time / maxf(_skill_duration, 0.01), 0.0, 1.0)
		_apply_skill_pose(str(_skill_data.get("pose", _skill_id)), skill_t)
	_animate_cape(delta, body_pose, attack_t)
	_animate_weapon(delta, attack_t, carry, amp)
	_animate_offhand(delta, carry, amp)

func _current_body_pose(horizontal_speed: float) -> Dictionary:
	var profile: Dictionary = BODY_PROFILES.get(equipped_weapon, BODY_PROFILES["sword"])
	var idle := _body_state(profile, "idle")
	var walk := _body_state(profile, "walk")
	var run := _body_state(profile, "run")
	var run_w := clampf((horizontal_speed - walk_speed) / maxf(run_speed - walk_speed, 0.01), 0.0, 1.0)
	var move_w := clampf(_move_blend, 0.0, 1.0)
	var walk_w := move_w * (1.0 - run_w)
	var run_w_final := move_w * run_w
	var result := {}
	for key in BODY_DEFAULTS:
		var blend := lerpf(float(idle[key]), float(walk[key]), walk_w)
		result[key] = lerpf(blend, float(run[key]), run_w_final)
	return result

func _body_state(profile: Dictionary, state: String) -> Dictionary:
	var result := BODY_DEFAULTS.duplicate()
	var overrides: Dictionary = profile.get(state, {})
	result.merge(overrides, true)
	return result

func _current_carry_pose(horizontal_speed: float) -> Dictionary:
	var profile: Dictionary = CARRY_PROFILES.get(equipped_weapon, CARRY_PROFILES["sword"])
	var idle: Dictionary = profile["idle"]
	var walk: Dictionary = profile["walk"]
	var run: Dictionary = profile["run"]
	var run_w := clampf((horizontal_speed - walk_speed) / maxf(run_speed - walk_speed, 0.01), 0.0, 1.0)
	var move_w := clampf(_move_blend, 0.0, 1.0)
	var walk_w := move_w * (1.0 - run_w)
	var run_w_final := move_w * run_w
	var idle_w := 1.0 - move_w
	return {
		"main": profile["main"],
		"arm": idle["arm"] * idle_w + walk["arm"] * walk_w + run["arm"] * run_w_final,
		"elbow": float(idle["elbow"]) * idle_w + float(walk["elbow"]) * walk_w + float(run["elbow"]) * run_w_final,
		"support": idle["support"] * idle_w + walk["support"] * walk_w + run["support"] * run_w_final,
		"support_elbow": float(idle["support_elbow"]) * idle_w + float(walk["support_elbow"]) * walk_w + float(run["support_elbow"]) * run_w_final,
		"weapon_pos": idle["weapon_pos"] * idle_w + walk["weapon_pos"] * walk_w + run["weapon_pos"] * run_w_final,
		"weapon_rot": idle["weapon_rot"] * idle_w + walk["weapon_rot"] * walk_w + run["weapon_rot"] * run_w_final,
		"offset": idle["offset"] * idle_w + walk["offset"] * walk_w + run["offset"] * run_w_final,
		"scale": float(idle["scale"]) * idle_w + float(walk["scale"]) * walk_w + float(run["scale"]) * run_w_final,
		"energy": float(idle["energy"]) * idle_w + float(walk["energy"]) * walk_w + float(run["energy"]) * run_w_final,
		"cant": float(idle["cant"]) * idle_w + float(walk["cant"]) * walk_w + float(run["cant"]) * run_w_final,
		"pitch": float(idle["pitch"]) * idle_w + float(walk["pitch"]) * walk_w + float(run["pitch"]) * run_w_final,
		"swing": float(idle["swing"]) * idle_w + float(walk["swing"]) * walk_w + float(run["swing"]) * run_w_final,
		"support_swing": float(idle["support_swing"]) * idle_w + float(walk["support_swing"]) * walk_w + float(run["support_swing"]) * run_w_final,
	}

func _apply_carry_pose(carry: Dictionary, amp: float, delta: float, body_pose: Dictionary = {}) -> void:
	_carry_blend = lerpf(_carry_blend, 1.0, 1.0 - exp(-9.0 * delta))
	var gait := clampf(amp, 0.0, 1.0)
	var arm_phase := _walk_phase - 0.10 * float(body_pose.get("arm_lag", 1.0))
	var main_is_right := str(carry.get("main", "right")) == "right"
	var swing_sign := 1.0 if main_is_right else -1.0
	var arm_mult := float(body_pose.get("arm", 1.0))
	var main_swing := sin(arm_phase) * swing_sign * float(carry["swing"]) * gait * arm_mult
	var support_swing := -sin(arm_phase) * swing_sign * float(carry["support_swing"]) * gait * arm_mult
	var arm: Vector3 = carry["arm"]
	var support: Vector3 = carry["support"]
	var main_shoulder: Node3D = _right_shoulder if main_is_right else _left_shoulder
	var main_elbow: Node3D = _right_elbow if main_is_right else _left_elbow
	var support_shoulder: Node3D = _left_shoulder if main_is_right else _right_shoulder
	var support_elbow: Node3D = _left_elbow if main_is_right else _right_elbow
	var weight := _carry_blend

	main_shoulder.rotation.x = lerpf(main_shoulder.rotation.x, arm.x + main_swing, weight)
	main_shoulder.rotation.y = lerpf(main_shoulder.rotation.y, arm.y, weight)
	main_shoulder.rotation.z = lerpf(main_shoulder.rotation.z, arm.z, weight)
	main_elbow.rotation.x = lerpf(main_elbow.rotation.x, float(carry["elbow"]) + main_swing * 0.35, weight)

	support_shoulder.rotation.x = lerpf(support_shoulder.rotation.x, support.x + support_swing, weight)
	support_shoulder.rotation.y = lerpf(support_shoulder.rotation.y, support.y, weight)
	support_shoulder.rotation.z = lerpf(support_shoulder.rotation.z, support.z, weight)
	support_elbow.rotation.x = lerpf(support_elbow.rotation.x, float(carry["support_elbow"]) + support_swing * 0.30, weight)

func _level_feet(left_roll := 0.0, right_roll := 0.0) -> void:
	_left_foot.rotation.x = -(_left_hip.rotation.x + _left_knee.rotation.x) + left_roll
	_right_foot.rotation.x = -(_right_hip.rotation.x + _right_knee.rotation.x) + right_roll

func _ground_feet(extra_lift := 0.0) -> void:
	var left_height := _upper_leg_length * cos(_left_hip.rotation.x) \
		+ _lower_leg_length * cos(_left_hip.rotation.x + _left_knee.rotation.x)
	var right_height := _upper_leg_length * cos(_right_hip.rotation.x) \
		+ _lower_leg_length * cos(_right_hip.rotation.x + _right_knee.rotation.x)
	_body.position.y = maxf(left_height, right_height) + _foot_drop + 0.003 + extra_lift
	# A pitched foot or a rolled hip drops a boot corner below the ankle line, so
	# sample the actual soles and lift the hips just enough to keep them planted.
	var sole := _lowest_sole_offset()
	if sole < 0.003:
		_body.position.y += 0.003 - sole

## Lowest boot corner relative to the hero's own origin. The headless scene tree
## has no floor, so the character body itself can sit at a negative world Y.
func _lowest_sole_offset() -> float:
	var lowest := 999.0
	for foot in [_left_foot, _right_foot]:
		var mesh := foot.get_node_or_null("FootMesh") as MeshInstance3D
		if mesh == null:
			continue
		var bounds := mesh.get_aabb()
		var xform := mesh.global_transform
		for i in 8:
			var corner := bounds.position + Vector3(
				bounds.size.x * float(i & 1),
				bounds.size.y * float((i >> 1) & 1),
				bounds.size.z * float((i >> 2) & 1)
			)
			lowest = minf(lowest, (xform * corner).y)
	return lowest - global_position.y

## Cape reactions are keyed by the skill's effect and pose rather than by its
## id, so a talent added to `SkillLibrary` later still gets a sensible flare
## without another match arm here.
func _skill_flare() -> float:
	match str(_skill_data.get("effect", "")):
		"dash":
			return 0.58
		"guard":
			return 0.18
		"heal":
			return 0.14
		"mana":
			return 0.22
		"recall":
			return 0.48
		"shockwave":
			return 0.60
		"volley":
			return 0.34
		"projectile":
			return 0.26
		"wisps":
			return 0.50
		"strike":
			return 0.42
	match str(_skill_data.get("pose", "")):
		"slash":
			return 0.42
		"shot":
			return 0.24
		"volley":
			return 0.32
		"slam":
			return 0.58
		"flurry":
			return 0.44
		"spirit":
			return 0.50
		"mend":
			return 0.14
		"focus":
			return 0.20
		"dash":
			return 0.56
		"guard":
			return 0.18
	return 0.24

func _animate_cape(delta: float, body_pose: Dictionary, attack_t: float) -> void:
	if _cape_upper == null or _cape_mid == null or _cape_lower == null:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	var run_w := clampf((speed - walk_speed) / maxf(run_speed - walk_speed, 0.01), 0.0, 1.0)
	var gait := clampf(_move_blend, 0.0, 1.0)
	var strength := float(body_pose.get("cape", 1.0))
	var wave := sin(_walk_phase + 0.55)
	var lag_wave := sin(_walk_phase + 0.95)
	var drift := sin(_idle_time * 1.05) * (1.0 - gait)

	var attack_weight := _attack_weight(attack_t) if _attack_active else 0.0
	var skill_weight := 1.0
	if _skill_active:
		skill_weight = smoothstep(0.0, 0.18, _skill_time / maxf(_skill_duration, 0.01))
		skill_weight *= 1.0 - smoothstep(0.74, 1.0, _skill_time / maxf(_skill_duration, 0.01))
	else:
		skill_weight = 0.0
	var flare := 0.0
	if _attack_active:
		match equipped_weapon:
			"sword": flare = 0.30
			"dagger": flare = 0.36
			"staff": flare = 0.52
			"bow": flare = 0.22
			"kitsune": flare = 0.60
	if _skill_active:
		flare = _skill_flare()
	var extra := flare * (attack_weight + skill_weight)

	var upper_rest: Vector3 = _cape_rest.get("upper", Vector3.ZERO)
	var mid_rest: Vector3 = _cape_rest.get("mid", Vector3.ZERO)
	var lower_rest: Vector3 = _cape_rest.get("lower", Vector3.ZERO)
	var upper_target := upper_rest + Vector3(
		-0.035 * gait * strength - 0.11 * run_w * strength - extra * 0.42 + drift * 0.012,
		wave * 0.035 * gait * strength + drift * 0.010,
		-wave * 0.030 * gait * strength
	)
	var mid_target := mid_rest + Vector3(
		-0.060 * gait * strength - 0.18 * run_w * strength - extra * 0.55 + lag_wave * 0.018,
		wave * 0.025 * gait * strength + drift * 0.014,
		-wave * 0.042 * gait * strength
	)
	var lower_target := lower_rest + Vector3(
		-0.090 * gait * strength - 0.26 * run_w * strength - extra * 0.68 + lag_wave * 0.026,
		lag_wave * 0.030 * gait * strength + drift * 0.018,
		-lag_wave * 0.055 * gait * strength
	)
	var blend := 1.0 - exp(-8.5 * delta)
	_cape_upper.rotation = _cape_upper.rotation.lerp(upper_target, blend)
	_cape_mid.rotation = _cape_mid.rotation.lerp(mid_target, blend)
	_cape_lower.rotation = _cape_lower.rotation.lerp(lower_target, blend)

func _animate_weapon(delta: float, t: float, carry: Dictionary, amp: float) -> void:
	var weapon_id := equipped_weapon
	var weight := _attack_weight(t) if _attack_active else 0.0
	if weapon_id == "bow":
		_animate_bow(delta, t, weight, carry, amp)
		return
	if weapon_id == "kitsune":
		_animate_kitsune(delta, t, weight, carry, amp)
		return

	var node := _combat_nodes.get(weapon_id) as Node3D
	if node == null:
		return
	var gait := clampf(amp, 0.0, 1.0)
	var target_pos: Vector3 = carry["weapon_pos"]
	target_pos.y += absf(sin(_walk_phase)) * 0.008 * gait
	if weight > 0.0:
		var flourish := _weapon_flourish(weapon_id, t)
		target_pos += (flourish["position"] as Vector3) * weight * 0.55

	var rest: Dictionary = _weapon_rest.get(weapon_id, {})
	var rest_pos: Vector3 = rest.get("position", Vector3.ZERO)
	node.position = rest_pos.lerp(target_pos, _carry_blend)

	# Solve the grip in the hero's own frame instead of the forearm's. The arm
	# still swings and the torso still twists, but the blade's direction is read
	# from the character-space keys above, so a greatsword never rolls over in
	# the hand as the elbow bends.
	var desired := _grip_basis(weapon_id, t, weight, carry, gait)
	var parent := node.get_parent() as Node3D
	var hero_basis := Basis(Vector3.UP, rotation.y)
	var target_basis: Basis = parent.global_transform.basis.inverse() * (hero_basis * desired)
	var local := node.transform
	var current_quat := local.basis.get_rotation_quaternion()
	local.basis = Basis(current_quat.slerp(target_basis.get_rotation_quaternion(), _carry_blend))
	node.transform = local

	if weapon_id == "staff":
		if _staff_light != null:
			_staff_light.light_energy = 0.7 + 1.8 * weight + sin(_idle_time * 2.2) * 0.08
		if _staff_crystal != null:
			_staff_crystal.scale = _staff_crystal_rest_scale * (1.0 + 0.18 * weight)

## Character-space grip solved from the blade's own +Y direction. `roll` turns
## the flat of the blade around that axis, so an edge leads the cut instead of a
## random face.
func _grip_basis(weapon_id: String, t: float, weight: float, carry: Dictionary, gait: float) -> Basis:
	var profile: Dictionary = GRIP_PROFILES.get(weapon_id, GRIP_PROFILES["sword"])
	var direction: Vector3 = profile["carry"]
	if weight > 0.0:
		var attack_dir := _keys_vec(t, profile["attack"])
		direction = direction.normalized().lerp(attack_dir, weight).normalized()
	var sway := sin(_walk_phase) * 0.035 * gait + sin(_idle_time * 1.15 + 0.6) * 0.02 * (1.0 - gait)
	direction = direction.rotated(Vector3.UP, sway)
	var basis := _basis_from_y(direction, float(profile["roll"]))
	var torso_yaw := _upper_body.rotation.y * 0.55
	if absf(torso_yaw) > 0.0001:
		basis = Basis(Vector3.UP, torso_yaw) * basis
	return basis

## Builds a right-handed basis whose local +Y points along `direction` and whose
## local -Z faces forward. The blade roll is then applied around the local +Y
## axis so the edge follows the arc.
func _basis_from_y(direction: Vector3, roll: float) -> Basis:
	var y_axis := direction.normalized()
	if y_axis.length_squared() < 0.001:
		y_axis = Vector3.UP
	var reference := Vector3.BACK
	if absf(y_axis.dot(reference)) > 0.96:
		reference = Vector3.RIGHT
	var x_axis := y_axis.cross(reference).normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	var basis := Basis(x_axis, y_axis, z_axis)
	if absf(roll) > 0.0001:
		basis = basis * Basis(Vector3.UP, roll)
	return basis

func _keys_vec(t: float, keys: Array) -> Vector3:
	if keys.is_empty():
		return Vector3.ZERO
	if t <= float(keys[0][0]):
		return (keys[0][1] as Vector3).normalized()
	for i in range(1, keys.size()):
		var previous: Array = keys[i - 1]
		var current: Array = keys[i]
		if t <= float(current[0]):
			var span := maxf(float(current[0]) - float(previous[0]), 0.0001)
			var local := clampf((t - float(previous[0])) / span, 0.0, 1.0)
			local = local * local * (3.0 - 2.0 * local)
			return (previous[1] as Vector3).lerp(current[1] as Vector3, local).normalized()
	return (keys[keys.size() - 1][1] as Vector3).normalized()

## Poses the off-hand on the left arm. The shield and tome are stabilised in the
## hero's frame so they stay readable while the arm swings; the gauntlet stays
## welded to the hand; the charm and lantern hang from their cords and swing
## with the stride. Guarding (or bracing through an attack) draws the prop into
## its guard angle.
func _animate_offhand(delta: float, carry: Dictionary, amp: float) -> void:
	if not offhand_in_use():
		return
	var node := _offhand_nodes.get(equipped_offhand) as Node3D
	if node == null:
		return

	_offhand_carry_blend = lerpf(_offhand_carry_blend, 1.0, 1.0 - exp(-9.0 * delta))
	var blend := _offhand_carry_blend
	var pose: Dictionary = OFFHAND_POSES.get(equipped_offhand, OFFHAND_POSES["shield"])
	var gait := clampf(amp, 0.0, 1.0)
	var guard := 1.0 if is_guarding() else 0.0
	if _attack_active:
		var attack_t := clampf(_attack_time / maxf(_attack_duration, 0.01), 0.0, 1.0)
		guard = maxf(guard, _attack_weight(attack_t) * 0.35)
	guard = clampf(guard, 0.0, 1.0)

	var rest: Dictionary = _offhand_rest.get(equipped_offhand, {})
	var rest_position: Vector3 = rest.get("position", Vector3.ZERO)
	var idle_offset: Vector3 = pose.get("idle", Vector3.ZERO)
	var guard_offset: Vector3 = pose.get("guard", Vector3.ZERO)
	var target_position := rest_position + (idle_offset as Vector3).lerp(guard_offset as Vector3, guard)

	var sway := float(pose.get("sway", 0.02))
	var hang := bool(pose.get("hang", false))
	_offhand_bob += delta * (2.4 + gait * 2.2)
	var bob := (0.0035 + 0.008 * gait) * (1.0 + sway * 2.0)
	target_position.y += sin(_offhand_bob) * bob
	if hang:
		target_position.z += sin(_offhand_bob * 0.8 + 0.7) * 0.006 * (0.4 + gait)

	node.position = node.position.lerp(target_position, blend)

	if not bool(pose.get("follow", false)):
		var hero_basis := Basis(Vector3.UP, rotation.y)
		var desired := Basis.IDENTITY
		if hang:
			# A hanging prop keeps its cord pointing at the ground, then swings
			# against the stride like a real pendulum.
			var swing := sway * (0.18 + 0.82 * gait)
			var ease := sin(_walk_phase) * swing + sin(_idle_time * 1.3) * sway * 0.25
			var side := cos(_walk_phase * 0.5) * swing * 0.55 + sin(_idle_time * 0.9 + 1.1) * sway * 0.18
			desired = Basis(Vector3.RIGHT, ease) * Basis(Vector3.BACK, side)
		else:
			var idle_euler: Vector3 = pose.get("euler", Vector3.ZERO)
			var guard_euler: Vector3 = pose.get("guard_euler", Vector3.ZERO)
			var euler := (idle_euler as Vector3).lerp(guard_euler as Vector3, guard)
			euler.x += sin(_idle_time * 1.1 + 0.4) * sway * 0.30
			euler.z += sin(_idle_time * 0.8) * sway * 0.24
			desired = Basis.from_euler(euler)
		var parent := node.get_parent() as Node3D
		var target_basis_world := hero_basis * desired
		var target_local := parent.global_transform.basis.inverse() * target_basis_world
		var target_quat := target_local.get_rotation_quaternion()
		var local := node.transform
		var scale := local.basis.get_scale()
		var current_quat := local.basis.get_rotation_quaternion()
		local.basis = Basis(current_quat.slerp(target_quat, blend)) * Basis.from_scale(scale)
		node.transform = local

	if equipped_offhand == "lantern" and _offhand_lantern != null:
		var lamp := _offhand_lantern.get_node_or_null("FireLight") as OmniLight3D
		if lamp != null:
			lamp.light_energy = 1.05 + sin(_idle_time * 8.5) * 0.13 + sin(_idle_time * 14.0 + 1.7) * 0.07
	if equipped_offhand == "charm" and _offhand_charm != null:
		var glow := _offhand_charm.get_node_or_null("CharmGlow") as OmniLight3D
		if glow != null:
			glow.light_energy = 0.42 + sin(_idle_time * 2.3) * 0.09

func _animate_bow(delta: float, t: float, weight: float, carry: Dictionary, amp: float) -> void:
	var rest: Dictionary = _weapon_rest.get("bow", {})
	var target_pos: Vector3 = carry["weapon_pos"]
	var draw := 0.0
	if weight > 0.0:
		target_pos.z += _keys(t, [[0.0, 0.0], [0.24, 0.02], [0.6, 0.06], [0.72, 0.0], [1.0, 0.0]]) * weight
		draw = _keys(t, [[0.0, 0.0], [0.18, 0.25], [0.34, 0.85], [0.54, 1.0], [0.61, 0.0], [0.7, 0.28], [0.84, 0.0], [1.0, 0.0]]) * weight
	_bow.position = (rest.get("position", Vector3.ZERO) as Vector3).lerp(target_pos, _carry_blend)

	# Keep the bow upright in the character's frame no matter how the arm
	# swings. The local +Z axis points up, the string (+Y) faces the archer, and
	# the belly (-Y) faces the target.
	var gait := clampf(amp, 0.0, 1.0)
	var cant := float(carry["cant"]) + sin(_idle_time * 0.8) * 0.02 * (1.0 - gait)
	var pitch := float(carry["pitch"])
	if weight > 0.0:
		cant += _keys(t, [[0.0, 0.0], [0.24, -0.24], [0.6, -0.18], [0.82, 0.0], [1.0, 0.0]]) * weight
		pitch += _keys(t, [[0.0, 0.0], [0.24, -0.20], [0.6, -0.16], [0.82, 0.0], [1.0, 0.0]]) * weight
	var yaw := rotation.y + _upper_body.rotation.y * 0.35
	var desired := Basis(Vector3.UP, yaw) \
		* Basis(Vector3(0.0, 0.0, 1.0), cant) \
		* Basis(Vector3.RIGHT, pitch) \
		* Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, 1.0, 0.0))
	var parent := _bow.get_parent() as Node3D
	var parent_basis: Basis = parent.global_transform.basis
	var target_basis: Basis = parent_basis.inverse() * desired
	var local := _bow.transform
	var current_quat := local.basis.get_rotation_quaternion()
	local.basis = Basis(current_quat.slerp(target_basis.get_rotation_quaternion(), _carry_blend))
	_bow.transform = local

	if _bow_string != null:
		_bow_string.position = _bow_string_rest_position + Vector3(0.0, 0.15 * draw, 0.0)
		_bow_string.scale = Vector3(
			_bow_string_rest_scale.x,
			_bow_string_rest_scale.y * (1.0 - 0.26 * draw),
			_bow_string_rest_scale.z
		)

func _animate_kitsune(delta: float, t: float, weight: float, carry: Dictionary, amp: float) -> void:
	var offset: Vector3 = carry["offset"]
	var energy := float(carry["energy"])
	var target_scale := float(carry["scale"])
	if weight > 0.0:
		var surge := _keys(t, [[0.0, 0.0], [0.28, 0.8], [0.5, 1.25], [0.74, 0.55], [1.0, 0.0]]) * weight
		offset += Vector3(0.0, 0.06 * surge, -0.34 * surge)
		energy += 1.9 * surge
		target_scale += 0.28 * surge
	_kitsune.call("set_motion_offset", offset)
	_kitsune.call("set_energy", energy)
	_kitsune.scale = _kitsune.scale.lerp(Vector3.ONE * target_scale, 1.0 - exp(-10.0 * delta))
	_kitsune.rotation.z = sin(_idle_time * 1.2) * 0.08 + sin(_walk_phase) * 0.05 * clampf(amp, 0.0, 1.0)
	_kitsune.rotation.y = sin(_idle_time * 0.7) * 0.12

func _weapon_flourish(weapon_id: String, t: float) -> Dictionary:
	match weapon_id:
		"sword":
			return {
				"position": Vector3(
					_keys(t, [[0.0, 0.0], [0.2, 0.03], [0.45, -0.06], [1.0, 0.0]]),
					_keys(t, [[0.0, 0.0], [0.2, 0.05], [0.45, -0.02], [1.0, 0.0]]),
					_keys(t, [[0.0, 0.0], [0.2, 0.05], [0.45, -0.12], [1.0, 0.0]])
				),
				"rotation": Vector3(
					_keys(t, [[0.0, 0.0], [0.2, -0.9], [0.36, 0.55], [0.56, 0.35], [0.8, 0.1], [1.0, 0.0]]),
					_keys(t, [[0.0, 0.0], [0.2, 0.35], [0.4, -0.3], [0.7, -0.1], [1.0, 0.0]]),
					_keys(t, [[0.0, 0.0], [0.2, -0.6], [0.4, 0.7], [0.62, 0.35], [1.0, 0.0]])
				),
			}
		"dagger":
			return {
				"position": Vector3(
					_keys(t, [[0.0, 0.0], [0.2, 0.02], [0.3, -0.02], [1.0, 0.0]]),
					_keys(t, [[0.0, 0.0], [0.2, 0.02], [0.3, 0.0], [1.0, 0.0]]),
					_keys(t, [[0.0, 0.0], [0.2, -0.10], [0.3, 0.02], [0.55, -0.10], [0.65, 0.02], [1.0, 0.0]])
				),
				"rotation": Vector3(
					_keys(t, [[0.0, 0.0], [0.16, -0.35], [0.26, 0.40], [0.4, 0.0], [0.5, -0.30], [0.6, 0.45], [0.8, 0.0], [1.0, 0.0]]),
					_keys(t, [[0.0, 0.0], [0.2, 0.18], [0.4, -0.12], [0.6, 0.18], [0.8, 0.0], [1.0, 0.0]]),
					_keys(t, [[0.0, 0.0], [0.2, -0.5], [0.35, 0.35], [0.6, -0.4], [0.75, 0.2], [1.0, 0.0]])
				),
			}
		"staff":
			return {
				"position": Vector3(
					_keys(t, [[0.0, 0.0], [0.3, 0.02], [0.66, -0.04], [1.0, 0.0]]),
					_keys(t, [[0.0, 0.0], [0.35, 0.08], [0.66, -0.12], [1.0, 0.0]]),
					_keys(t, [[0.0, 0.0], [0.3, 0.03], [0.66, -0.08], [1.0, 0.0]])
				),
				"rotation": Vector3(
					_keys(t, [[0.0, 0.0], [0.3, -0.40], [0.55, -0.55], [0.66, 0.55], [0.8, 0.2], [1.0, 0.0]]),
					_keys(t, [[0.0, 0.0], [0.3, 0.5], [0.62, -0.3], [1.0, 0.0]]),
					_keys(t, [[0.0, 0.0], [0.3, -0.25], [0.66, 0.4], [1.0, 0.0]])
				),
			}
	return {"position": Vector3.ZERO, "rotation": Vector3.ZERO}

func _apply_attack_pose(t: float) -> void:
	var weight := _attack_weight(t)
	_apply_attack_lower_body(t, weight)
	match equipped_weapon:
		"sword":
			_pose_sword(t, weight)
		"bow":
			_pose_bow(t, weight)
		"staff":
			_pose_staff(t, weight)
		"dagger":
			_pose_dagger(t, weight)
		"kitsune":
			_pose_kitsune(t, weight)

func _attack_weight(t: float) -> float:
	return smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.86, 1.0, t))

## Turns the upper-body flourish into a full-body strike: the lead leg plants,
## the back leg drives, the hips counter-rotate and the whole stance drops into
## the blow. Hip heights are recomputed afterwards so a lunge never sinks the
## feet through the floor.
func _apply_attack_lower_body(t: float, weight: float) -> void:
	if weight <= 0.0:
		return
	var profile: Dictionary = ATTACK_BODY.get(equipped_weapon, ATTACK_BODY["sword"])
	var lead_left := str(profile.get("lead", "left")) == "left"
	var lead_hip := _left_hip if lead_left else _right_hip
	var back_hip := _right_hip if lead_left else _left_hip
	var lead_knee := _left_knee if lead_left else _right_knee
	var back_knee := _right_knee if lead_left else _left_knee
	var lead_sign := -1.0 if lead_left else 1.0

	lead_hip.rotation.x = lerpf(lead_hip.rotation.x, _keys(t, profile["lead_hip"]), weight)
	back_hip.rotation.x = lerpf(back_hip.rotation.x, _keys(t, profile["back_hip"]), weight)
	lead_knee.rotation.x = lerpf(lead_knee.rotation.x, _keys(t, profile["lead_knee"]), weight)
	back_knee.rotation.x = lerpf(back_knee.rotation.x, _keys(t, profile["back_knee"]), weight)
	var stance := _keys(t, profile["stance"]) * weight
	lead_hip.rotation.z += lead_sign * stance
	back_hip.rotation.z += -lead_sign * stance

	var roll := _keys(t, profile["foot_roll"]) * weight
	_level_feet(roll * -lead_sign, roll * lead_sign)
	_body.position.z += _keys(t, profile["lunge"]) * weight
	_body.rotation.y += _keys(t, profile["body_yaw"]) * weight
	_body.rotation.z += _keys(t, profile["body_roll"]) * weight
	_upper_body.rotation.x += _keys(t, profile["body_pitch"]) * weight
	_ground_feet(_keys(t, profile["lift"]) * weight)

## Assignable skills each have their own whole-body casting pose so the bar does
## not just replay a weapon swing when a non-combat skill is used. The HUD passes
## a `pose` archetype from `SkillLibrary`, not the skill id, so two schools can
## share a stance without sharing a spell.
func _apply_skill_pose(pose: String, t: float) -> void:
	var weight := smoothstep(0.0, 0.16, t) * (1.0 - smoothstep(0.76, 1.0, t))
	if weight <= 0.0:
		return
	var pulse := sin(t * PI)
	match pose:
		"dash":
			_left_hip.rotation.x = lerpf(_left_hip.rotation.x, 0.52, weight)
			_right_hip.rotation.x = lerpf(_right_hip.rotation.x, -0.34, weight)
			_left_knee.rotation.x = lerpf(_left_knee.rotation.x, -0.62, weight)
			_right_knee.rotation.x = lerpf(_right_knee.rotation.x, -0.44, weight)
			_left_shoulder.rotation.x = lerpf(_left_shoulder.rotation.x, -0.85, weight)
			_right_shoulder.rotation.x = lerpf(_right_shoulder.rotation.x, -0.95, weight)
			_left_shoulder.rotation.z = lerpf(_left_shoulder.rotation.z, -0.30, weight)
			_right_shoulder.rotation.z = lerpf(_right_shoulder.rotation.z, 0.34, weight)
			_left_elbow.rotation.x = lerpf(_left_elbow.rotation.x, 0.55, weight)
			_right_elbow.rotation.x = lerpf(_right_elbow.rotation.x, 0.60, weight)
			_upper_body.rotation.x += 0.34 * pulse * weight
			_head.rotation.x += 0.16 * weight
		"guard":
			_left_hip.rotation.z = lerpf(_left_hip.rotation.z, -0.18, weight)
			_right_hip.rotation.z = lerpf(_right_hip.rotation.z, 0.18, weight)
			_left_knee.rotation.x = lerpf(_left_knee.rotation.x, -0.34, weight)
			_right_knee.rotation.x = lerpf(_right_knee.rotation.x, -0.30, weight)
			_left_shoulder.rotation.x = lerpf(_left_shoulder.rotation.x, 1.18, weight)
			_right_shoulder.rotation.x = lerpf(_right_shoulder.rotation.x, 1.02, weight)
			_left_shoulder.rotation.z = lerpf(_left_shoulder.rotation.z, 0.34, weight)
			_right_shoulder.rotation.z = lerpf(_right_shoulder.rotation.z, -0.34, weight)
			_left_elbow.rotation.x = lerpf(_left_elbow.rotation.x, 1.95, weight)
			_right_elbow.rotation.x = lerpf(_right_elbow.rotation.x, 1.88, weight)
			_upper_body.rotation.x += 0.14 * weight
			_head.rotation.x += 0.12 * weight
		"mend":
			_left_hip.rotation.z = lerpf(_left_hip.rotation.z, -0.08, weight)
			_right_hip.rotation.z = lerpf(_right_hip.rotation.z, 0.08, weight)
			_left_knee.rotation.x = lerpf(_left_knee.rotation.x, -0.20, weight)
			_right_knee.rotation.x = lerpf(_right_knee.rotation.x, -0.24, weight)
			_right_shoulder.rotation.x = lerpf(_right_shoulder.rotation.x, 0.62, weight)
			_right_shoulder.rotation.z = lerpf(_right_shoulder.rotation.z, -0.58, weight)
			_right_elbow.rotation.x = lerpf(_right_elbow.rotation.x, 2.0, weight)
			_left_shoulder.rotation.x = lerpf(_left_shoulder.rotation.x, 0.35, weight)
			_left_elbow.rotation.x = lerpf(_left_elbow.rotation.x, 1.45, weight)
			_upper_body.rotation.x += 0.12 * weight
			_head.rotation.x += 0.26 * weight
			_head.rotation.z += 0.10 * weight
		"focus":
			_left_hip.rotation.z = lerpf(_left_hip.rotation.z, -0.16, weight)
			_right_hip.rotation.z = lerpf(_right_hip.rotation.z, 0.16, weight)
			_left_knee.rotation.x = lerpf(_left_knee.rotation.x, -0.14, weight)
			_right_knee.rotation.x = lerpf(_right_knee.rotation.x, -0.14, weight)
			_left_shoulder.rotation.x = lerpf(_left_shoulder.rotation.x, 0.28, weight)
			_right_shoulder.rotation.x = lerpf(_right_shoulder.rotation.x, 0.28, weight)
			_left_shoulder.rotation.z = lerpf(_left_shoulder.rotation.z, -1.05, weight)
			_right_shoulder.rotation.z = lerpf(_right_shoulder.rotation.z, 1.05, weight)
			_left_elbow.rotation.x = lerpf(_left_elbow.rotation.x, 0.42, weight)
			_right_elbow.rotation.x = lerpf(_right_elbow.rotation.x, 0.42, weight)
			_upper_body.rotation.x += -0.10 * weight
			_head.rotation.x += -0.12 * weight
		"recall":
			_left_hip.rotation.z = lerpf(_left_hip.rotation.z, -0.14, weight)
			_right_hip.rotation.z = lerpf(_right_hip.rotation.z, 0.14, weight)
			_left_knee.rotation.x = lerpf(_left_knee.rotation.x, -0.24, weight)
			_right_knee.rotation.x = lerpf(_right_knee.rotation.x, -0.18, weight)
			_left_shoulder.rotation.x = lerpf(_left_shoulder.rotation.x, 1.72, weight)
			_right_shoulder.rotation.x = lerpf(_right_shoulder.rotation.x, 1.72, weight)
			_left_shoulder.rotation.z = lerpf(_left_shoulder.rotation.z, -0.34, weight)
			_right_shoulder.rotation.z = lerpf(_right_shoulder.rotation.z, 0.34, weight)
			_left_elbow.rotation.x = lerpf(_left_elbow.rotation.x, 0.16, weight)
			_right_elbow.rotation.x = lerpf(_right_elbow.rotation.x, 0.16, weight)
			_upper_body.rotation.x += -0.16 * weight
			_head.rotation.x += -0.18 * weight
		"slash":
			_skill_pose_slash(t, weight)
		"shot":
			_skill_pose_shot(t, weight)
		"volley":
			_skill_pose_volley(t, weight)
		"slam":
			_skill_pose_slam(t, weight)
		"flurry":
			_skill_pose_flurry(t, weight)
		"spirit":
			_skill_pose_spirit(t, weight)
	_level_feet()
	_ground_feet()

func _skill_pose_slash(t: float, weight: float) -> void:
	_left_hip.rotation.x = lerpf(_left_hip.rotation.x, _keys(t, [[0.0, 0.0], [0.24, -0.10], [0.46, 0.34], [0.72, 0.16], [1.0, 0.0]]), weight)
	_right_hip.rotation.x = lerpf(_right_hip.rotation.x, _keys(t, [[0.0, 0.0], [0.24, 0.10], [0.46, -0.30], [0.72, -0.14], [1.0, 0.0]]), weight)
	_left_knee.rotation.x = lerpf(_left_knee.rotation.x, _keys(t, [[0.0, 0.0], [0.24, -0.16], [0.46, -0.42], [0.72, -0.22], [1.0, 0.0]]), weight)
	_right_knee.rotation.x = lerpf(_right_knee.rotation.x, _keys(t, [[0.0, 0.0], [0.24, -0.14], [0.46, -0.26], [0.72, -0.14], [1.0, 0.0]]), weight)
	_left_hip.rotation.z = lerpf(_left_hip.rotation.z, -0.10, weight)
	_right_hip.rotation.z = lerpf(_right_hip.rotation.z, 0.12, weight)
	_right_shoulder.rotation.x = lerpf(_right_shoulder.rotation.x, _keys(t, [[0.0, -0.2], [0.24, -2.3], [0.46, 1.02], [0.62, 1.24], [0.82, 0.34], [1.0, 0.0]]), weight)
	_right_shoulder.rotation.z = lerpf(_right_shoulder.rotation.z, _keys(t, [[0.0, 0.1], [0.24, 0.95], [0.46, -0.38], [0.66, -0.52], [1.0, 0.1]]), weight)
	_right_elbow.rotation.x = lerpf(_right_elbow.rotation.x, _keys(t, [[0.0, 0.25], [0.24, 0.88], [0.46, 0.10], [0.72, 0.22], [1.0, 0.25]]), weight)
	_left_shoulder.rotation.x = lerpf(_left_shoulder.rotation.x, _keys(t, [[0.0, 0.0], [0.24, 0.82], [0.46, -0.22], [1.0, 0.0]]), weight)
	_left_shoulder.rotation.z = lerpf(_left_shoulder.rotation.z, -0.42, weight)
	_left_elbow.rotation.x = lerpf(_left_elbow.rotation.x, 0.72, weight)
	var twist := _keys(t, [[0.0, 0.0], [0.24, -0.58], [0.46, 0.58], [0.72, 0.30], [1.0, 0.0]])
	_upper_body.rotation.y += twist * weight
	_upper_body.rotation.x += _keys(t, [[0.0, 0.0], [0.24, -0.08], [0.46, 0.18], [0.74, 0.06], [1.0, 0.0]]) * weight
	_head.rotation.y += twist * -0.35 * weight
	_body.position.z += _keys(t, [[0.0, 0.0], [0.30, 0.02], [0.48, -0.16], [0.78, -0.03], [1.0, 0.0]]) * weight

func _skill_pose_shot(t: float, weight: float) -> void:
	_left_hip.rotation.z = lerpf(_left_hip.rotation.z, -0.14, weight)
	_right_hip.rotation.z = lerpf(_right_hip.rotation.z, 0.14, weight)
	_left_knee.rotation.x = lerpf(_left_knee.rotation.x, -0.16, weight)
	_right_knee.rotation.x = lerpf(_right_knee.rotation.x, -0.20, weight)
	_left_shoulder.rotation.x = lerpf(_left_shoulder.rotation.x, _keys(t, [[0.0, 0.0], [0.20, 1.42], [0.66, 1.48], [0.80, 1.10], [1.0, 0.0]]), weight)
	_left_shoulder.rotation.z = lerpf(_left_shoulder.rotation.z, -0.18, weight)
	_left_elbow.rotation.x = lerpf(_left_elbow.rotation.x, 0.06, weight)
	_right_shoulder.rotation.x = lerpf(_right_shoulder.rotation.x, _keys(t, [[0.0, 0.0], [0.20, 1.0], [0.66, 1.16], [0.74, 0.22], [0.84, 0.45], [1.0, 0.0]]), weight)
	_right_shoulder.rotation.z = lerpf(_right_shoulder.rotation.z, 0.56, weight)
	_right_elbow.rotation.x = lerpf(_right_elbow.rotation.x, _keys(t, [[0.0, 0.25], [0.20, 1.42], [0.66, 1.72], [0.74, 0.14], [0.84, 0.62], [1.0, 0.25]]), weight)
	var twist := _keys(t, [[0.0, 0.0], [0.22, 0.34], [0.66, 0.40], [0.82, 0.12], [1.0, 0.0]])
	_upper_body.rotation.y += twist * weight
	_head.rotation.y += twist * -0.42 * weight
	_head.rotation.x += 0.05 * weight

func _skill_pose_volley(t: float, weight: float) -> void:
	var draw := 0.55 + 0.55 * sin(clampf((t - 0.30) / 0.50, 0.0, 1.0) * PI * 5.0)
	_left_hip.rotation.z = lerpf(_left_hip.rotation.z, -0.16, weight)
	_right_hip.rotation.z = lerpf(_right_hip.rotation.z, 0.16, weight)
	_left_knee.rotation.x = lerpf(_left_knee.rotation.x, -0.18, weight)
	_right_knee.rotation.x = lerpf(_right_knee.rotation.x, -0.22, weight)
	_left_shoulder.rotation.x = lerpf(_left_shoulder.rotation.x, 1.46, weight)
	_left_shoulder.rotation.z = lerpf(_left_shoulder.rotation.z, -0.20, weight)
	_left_elbow.rotation.x = lerpf(_left_elbow.rotation.x, 0.08, weight)
	_right_shoulder.rotation.x = lerpf(_right_shoulder.rotation.x, draw, weight)
	_right_shoulder.rotation.z = lerpf(_right_shoulder.rotation.z, 0.58, weight)
	_right_elbow.rotation.x = lerpf(_right_elbow.rotation.x, 0.55 + 0.95 * draw, weight)
	_upper_body.rotation.y += 0.38 * weight
	_upper_body.rotation.x += 0.05 * weight
	_head.rotation.y += -0.18 * weight

func _skill_pose_slam(t: float, weight: float) -> void:
	_left_hip.rotation.x = lerpf(_left_hip.rotation.x, _keys(t, [[0.0, 0.0], [0.40, -0.12], [0.62, 0.18], [0.82, 0.06], [1.0, 0.0]]), weight)
	_right_hip.rotation.x = lerpf(_right_hip.rotation.x, _keys(t, [[0.0, 0.0], [0.40, 0.06], [0.62, -0.16], [0.82, -0.05], [1.0, 0.0]]), weight)
	_left_knee.rotation.x = lerpf(_left_knee.rotation.x, _keys(t, [[0.0, 0.0], [0.40, -0.20], [0.62, -0.46], [0.82, -0.18], [1.0, 0.0]]), weight)
	_right_knee.rotation.x = lerpf(_right_knee.rotation.x, _keys(t, [[0.0, 0.0], [0.40, -0.24], [0.62, -0.40], [0.82, -0.16], [1.0, 0.0]]), weight)
	_right_shoulder.rotation.x = lerpf(_right_shoulder.rotation.x, _keys(t, [[0.0, -0.2], [0.22, -1.2], [0.42, -2.9], [0.56, -3.0], [0.66, 0.95], [0.80, 1.25], [1.0, 0.0]]), weight)
	_right_shoulder.rotation.z = lerpf(_right_shoulder.rotation.z, _keys(t, [[0.0, 0.08], [0.42, -0.16], [0.66, 0.28], [1.0, 0.08]]), weight)
	_right_elbow.rotation.x = lerpf(_right_elbow.rotation.x, _keys(t, [[0.0, 0.25], [0.42, 0.72], [0.60, 0.58], [0.68, 0.10], [1.0, 0.25]]), weight)
	_left_shoulder.rotation.x = lerpf(_left_shoulder.rotation.x, _keys(t, [[0.0, 0.0], [0.24, -1.0], [0.44, -2.5], [0.58, -2.62], [0.68, 0.82], [1.0, 0.0]]), weight)
	_left_shoulder.rotation.z = lerpf(_left_shoulder.rotation.z, -0.24, weight)
	_left_elbow.rotation.x = lerpf(_left_elbow.rotation.x, _keys(t, [[0.0, 0.25], [0.44, 1.10], [0.62, 0.95], [0.72, 0.20], [1.0, 0.25]]), weight)
	_upper_body.rotation.x += _keys(t, [[0.0, 0.0], [0.36, -0.24], [0.58, -0.28], [0.68, 0.30], [0.86, 0.10], [1.0, 0.0]]) * weight
	_head.rotation.x += _keys(t, [[0.0, 0.0], [0.40, 0.20], [0.66, -0.18], [1.0, 0.0]]) * weight

func _skill_pose_flurry(t: float, weight: float) -> void:
	_left_hip.rotation.x = lerpf(_left_hip.rotation.x, 0.22, weight)
	_right_hip.rotation.x = lerpf(_right_hip.rotation.x, -0.18, weight)
	_left_hip.rotation.z = lerpf(_left_hip.rotation.z, -0.16, weight)
	_right_hip.rotation.z = lerpf(_right_hip.rotation.z, 0.18, weight)
	_left_knee.rotation.x = lerpf(_left_knee.rotation.x, -0.38, weight)
	_right_knee.rotation.x = lerpf(_right_knee.rotation.x, -0.30, weight)
	var thrust := 0.35 + 1.10 * absf(sin(clampf((t - 0.10) / 0.72, 0.0, 1.0) * PI * 3.0))
	var elbow := 0.95 - 0.85 * absf(sin(clampf((t - 0.10) / 0.72, 0.0, 1.0) * PI * 3.0))
	_right_shoulder.rotation.x = lerpf(_right_shoulder.rotation.x, thrust, weight)
	_right_shoulder.rotation.z = lerpf(_right_shoulder.rotation.z, 0.05, weight)
	_right_elbow.rotation.x = lerpf(_right_elbow.rotation.x, elbow, weight)
	_left_shoulder.rotation.x = lerpf(_left_shoulder.rotation.x, 0.35, weight)
	_left_shoulder.rotation.z = lerpf(_left_shoulder.rotation.z, -0.42, weight)
	_left_elbow.rotation.x = lerpf(_left_elbow.rotation.x, 1.15, weight)
	var twist := sin(t * PI * 3.0) * 0.26
	_upper_body.rotation.y += twist * weight
	_head.rotation.y += twist * -0.4 * weight
	_body.position.z += _keys(t, [[0.0, 0.0], [0.18, -0.03], [0.30, -0.12], [0.62, -0.04], [0.76, -0.12], [1.0, 0.0]]) * weight

func _skill_pose_spirit(t: float, weight: float) -> void:
	_left_hip.rotation.z = lerpf(_left_hip.rotation.z, -0.10, weight)
	_right_hip.rotation.z = lerpf(_right_hip.rotation.z, 0.10, weight)
	_left_knee.rotation.x = lerpf(_left_knee.rotation.x, -0.18, weight)
	_right_knee.rotation.x = lerpf(_right_knee.rotation.x, -0.22, weight)
	var reach := _keys(t, [[0.0, 0.0], [0.22, 1.12], [0.38, 1.56], [0.70, 1.42], [1.0, 0.0]])
	_left_shoulder.rotation.x = lerpf(_left_shoulder.rotation.x, reach, weight)
	_left_shoulder.rotation.z = lerpf(_left_shoulder.rotation.z, -0.20, weight)
	_left_elbow.rotation.x = lerpf(_left_elbow.rotation.x, _keys(t, [[0.0, 0.25], [0.30, 0.16], [0.62, 0.10], [1.0, 0.25]]), weight)
	_right_shoulder.rotation.x = lerpf(_right_shoulder.rotation.x, _keys(t, [[0.0, 0.0], [0.26, 1.02], [0.50, 1.20], [0.75, 0.78], [1.0, 0.0]]), weight)
	_right_shoulder.rotation.z = lerpf(_right_shoulder.rotation.z, 0.42, weight)
	_right_elbow.rotation.x = lerpf(_right_elbow.rotation.x, 1.18 + 0.30 * sin(t * PI * 2.0), weight)
	_upper_body.rotation.x += -0.08 * weight
	_upper_body.rotation.y += _keys(t, [[0.0, 0.0], [0.30, -0.26], [0.70, -0.20], [1.0, 0.0]]) * weight
	_head.rotation.y += _keys(t, [[0.0, 0.0], [0.30, 0.22], [0.70, 0.16], [1.0, 0.0]]) * weight
	_head.rotation.z += 0.08 * weight

func _pose_sword(t: float, weight: float) -> void:
	var rx := _keys(t, [[0.0, -0.2], [0.24, -2.4], [0.42, 0.95], [0.58, 1.28], [0.8, 0.35], [1.0, 0.0]])
	var rz := _keys(t, [[0.0, 0.08], [0.24, 1.02], [0.44, -0.32], [0.66, -0.56], [1.0, 0.08]])
	var elbow := _keys(t, [[0.0, 0.25], [0.24, 0.85], [0.44, 0.1], [0.68, 0.24], [1.0, 0.25]])
	var torso_yaw := _keys(t, [[0.0, 0.0], [0.24, -0.62], [0.45, 0.55], [0.7, 0.34], [1.0, 0.0]])
	var lean := _keys(t, [[0.0, 0.0], [0.24, -0.1], [0.45, 0.2], [0.7, 0.1], [1.0, 0.0]])

	_right_shoulder.rotation.x = lerpf(_right_shoulder.rotation.x, rx, weight)
	_right_shoulder.rotation.z = lerpf(_right_shoulder.rotation.z, rz, weight)
	_right_elbow.rotation.x = lerpf(_right_elbow.rotation.x, elbow, weight)
	_left_shoulder.rotation.x = lerpf(_left_shoulder.rotation.x, _keys(t, [[0.0, 0.0], [0.24, 0.75], [0.45, -0.25], [1.0, 0.0]]), weight)
	_left_shoulder.rotation.z = lerpf(_left_shoulder.rotation.z, -0.42, weight)
	_left_elbow.rotation.x = lerpf(_left_elbow.rotation.x, 0.7, weight)
	_upper_body.rotation.y += torso_yaw * weight
	_upper_body.rotation.x += lean * weight
	_head.rotation.y += torso_yaw * -0.35 * weight

func _pose_bow(t: float, weight: float) -> void:
	var aim := _keys(t, [[0.0, 0.0], [0.22, 1.42], [0.62, 1.48], [0.8, 0.5], [1.0, 0.0]])
	var left_elbow := _keys(t, [[0.0, 0.25], [0.22, 0.05], [0.75, 0.08], [1.0, 0.25]])
	var draw := _keys(t, [[0.0, 0.0], [0.24, 1.05], [0.5, 1.2], [0.6, 0.65], [0.74, 0.9], [1.0, 0.0]])
	var draw_elbow := _keys(t, [[0.0, 0.25], [0.25, 1.5], [0.52, 1.75], [0.6, 0.15], [0.78, 0.6], [1.0, 0.25]])
	var torso_yaw := _keys(t, [[0.0, 0.0], [0.25, 0.32], [0.6, 0.38], [0.8, 0.1], [1.0, 0.0]])

	_left_shoulder.rotation.x = lerpf(_left_shoulder.rotation.x, aim, weight)
	_left_shoulder.rotation.z = lerpf(_left_shoulder.rotation.z, -0.16, weight)
	_left_elbow.rotation.x = lerpf(_left_elbow.rotation.x, left_elbow, weight)
	_right_shoulder.rotation.x = lerpf(_right_shoulder.rotation.x, draw, weight)
	_right_shoulder.rotation.z = lerpf(_right_shoulder.rotation.z, 0.55, weight)
	_right_elbow.rotation.x = lerpf(_right_elbow.rotation.x, draw_elbow, weight)
	_upper_body.rotation.y += torso_yaw * weight
	_head.rotation.y += torso_yaw * -0.4 * weight
	_head.rotation.x += 0.05 * weight

func _pose_staff(t: float, weight: float) -> void:
	var right_rx := _keys(t, [[0.0, -0.2], [0.28, -2.9], [0.52, -3.02], [0.63, 1.25], [0.78, 1.42], [1.0, 0.0]])
	var right_rz := _keys(t, [[0.0, 0.08], [0.3, -0.15], [0.55, -0.18], [0.65, 0.26], [1.0, 0.08]])
	var right_elbow := _keys(t, [[0.0, 0.25], [0.3, 0.75], [0.55, 0.55], [0.65, 0.08], [1.0, 0.25]])
	var left_rx := _keys(t, [[0.0, 0.0], [0.3, -2.5], [0.55, -2.65], [0.66, 0.95], [1.0, 0.0]])
	var left_elbow := _keys(t, [[0.0, 0.25], [0.3, 1.15], [0.6, 1.0], [0.7, 0.2], [1.0, 0.25]])
	var lean := _keys(t, [[0.0, 0.0], [0.3, -0.22], [0.52, -0.26], [0.66, 0.3], [1.0, 0.0]])

	_right_shoulder.rotation.x = lerpf(_right_shoulder.rotation.x, right_rx, weight)
	_right_shoulder.rotation.z = lerpf(_right_shoulder.rotation.z, right_rz, weight)
	_right_elbow.rotation.x = lerpf(_right_elbow.rotation.x, right_elbow, weight)
	_left_shoulder.rotation.x = lerpf(_left_shoulder.rotation.x, left_rx, weight)
	_left_shoulder.rotation.z = lerpf(_left_shoulder.rotation.z, -0.22, weight)
	_left_elbow.rotation.x = lerpf(_left_elbow.rotation.x, left_elbow, weight)
	_upper_body.rotation.x += lean * weight
	_upper_body.rotation.y += _keys(t, [[0.0, 0.0], [0.3, -0.18], [0.66, 0.2], [1.0, 0.0]]) * weight

func _pose_dagger(t: float, weight: float) -> void:
	var thrust := _keys(t, [[0.0, 0.0], [0.14, 0.52], [0.24, 1.4], [0.34, 0.58], [0.47, 0.48], [0.58, 1.48], [0.72, 0.6], [1.0, 0.0]])
	var elbow := _keys(t, [[0.0, 0.25], [0.14, 0.95], [0.24, 0.06], [0.36, 0.85], [0.56, 0.05], [0.74, 0.6], [1.0, 0.25]])
	var twist := _keys(t, [[0.0, 0.0], [0.24, 0.28], [0.34, 0.12], [0.58, 0.34], [0.8, 0.1], [1.0, 0.0]])

	_right_shoulder.rotation.x = lerpf(_right_shoulder.rotation.x, thrust, weight)
	_right_shoulder.rotation.z = lerpf(_right_shoulder.rotation.z, 0.04, weight)
	_right_elbow.rotation.x = lerpf(_right_elbow.rotation.x, elbow, weight)
	_left_shoulder.rotation.z = lerpf(_left_shoulder.rotation.z, -0.35, weight)
	_left_elbow.rotation.x = lerpf(_left_elbow.rotation.x, 0.85, weight)
	_upper_body.rotation.y += twist * weight
	_head.rotation.y += twist * -0.4 * weight

func _pose_kitsune(t: float, weight: float) -> void:
	var reach := _keys(t, [[0.0, 0.0], [0.22, 1.1], [0.36, 1.55], [0.7, 1.4], [1.0, 0.0]])
	var left_elbow := _keys(t, [[0.0, 0.25], [0.3, 0.18], [0.62, 0.12], [1.0, 0.25]])
	var support := _keys(t, [[0.0, 0.0], [0.26, 1.05], [0.5, 1.22], [0.75, 0.8], [1.0, 0.0]])

	_left_shoulder.rotation.x = lerpf(_left_shoulder.rotation.x, reach, weight)
	_left_shoulder.rotation.z = lerpf(_left_shoulder.rotation.z, -0.2, weight)
	_left_elbow.rotation.x = lerpf(_left_elbow.rotation.x, left_elbow, weight)
	_right_shoulder.rotation.x = lerpf(_right_shoulder.rotation.x, support, weight)
	_right_shoulder.rotation.z = lerpf(_right_shoulder.rotation.z, 0.42, weight)
	_right_elbow.rotation.x = lerpf(_right_elbow.rotation.x, 1.25, weight)
	_upper_body.rotation.y += _keys(t, [[0.0, 0.0], [0.3, -0.26], [0.7, -0.2], [1.0, 0.0]]) * weight
	_head.rotation.y += _keys(t, [[0.0, 0.0], [0.3, 0.22], [0.7, 0.16], [1.0, 0.0]]) * weight

func _keys(t: float, keys: Array) -> float:
	if keys.is_empty():
		return 0.0
	if t <= float(keys[0][0]):
		return float(keys[0][1])
	for i in range(1, keys.size()):
		var previous: Array = keys[i - 1]
		var current: Array = keys[i]
		if t <= float(current[0]):
			var span := maxf(float(current[0]) - float(previous[0]), 0.0001)
			var local := clampf((t - float(previous[0])) / span, 0.0, 1.0)
			local = local * local * (3.0 - 2.0 * local)
			return lerpf(float(previous[1]), float(current[1]), local)
	return float(keys[keys.size() - 1][1])

func set_movement_locked(locked: bool) -> void:
	movement_locked = locked
	if locked:
		velocity.x = 0.0
		velocity.z = 0.0

func set_torch(on: bool) -> void:
	_torch_on = on
	_torch_rig.visible = on

func is_torch_on() -> bool:
	return _torch_on

func return_to_spawn() -> void:
	var manager := get_tree().get_first_node_in_group("dungeon_manager")
	if manager != null and bool(manager.call("is_inside_dungeon")):
		allow_fall_rescue = true
		manager.call("exit_dungeon")
	global_position = _spawn_position
	rotation.y = _spawn_rotation
	velocity = Vector3.ZERO
