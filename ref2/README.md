# FPS Planet Explorer

Walk on procedurally generated planets in first person!

## Features
✅ First-person controls
✅ Walk on spherical planets
✅ Gravity always pulls to planet center
✅ Procedural terrain with biomes
✅ Mouse look

## Controls

### Movement
- **WASD** - Move
- **Mouse** - Look around
- **Space** - Jump
- **Shift** - Sprint
- **ESC** - Release mouse

### Camera & Other
- **O** - Toggle first/third person camera
- **R** - Regenerate planet

## Files
- `planet.gd` - Planet with terrain
- `player.gd` - FPS player controller
- `main.gd` - Main scene setup

## How It Works

The player:
1. Always oriented "up" away from planet center
2. Gravity pulls toward planet center
3. Can walk in any direction on the sphere
4. Camera follows player rotation

Press **F5** to play!
