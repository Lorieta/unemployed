# Technical Design

## Engine

- **Godot 4.3** or latest stable
- **Jolt Physics** for 3D physics
- **GLES3** rendering backend

## Architecture

- **Node-based scene system** Godot style
- **Singleton managers** for game systems
- **Component-based** design for characters

## Key Systems

- **Dungeon Generator** - Procedural room generation
- **Combat System** - Damage, hitboxes, status effects
- **Skill System** - Data-driven skill definitions
- **Progression System** - Meta-progression between runs
- **Save/Load System** - JSON-based persistence

## Input

- **Input Map** for action-based inputs
- **Gamepad support** via Godot Input system

## Audio

- **Ogg Vorbis** for music
- **WAV** for short SFX

## Graphics

- **Sprite-based** 2D with 3D elements
- **CanvasItem shading** for UI effects