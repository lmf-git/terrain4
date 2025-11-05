# Spherical Terrain with Water - Godot 4.5

A complete spherical planetary terrain system with water for Godot 4.5, inspired by games like ARMA 3 and Kerbal Space Program.

## Two View Modes

**When you run the project, you'll see a launcher with two options:**
- Press **O** for Orbital Camera mode (KSP-style view from space)
- Press **P** for Player Mode (first-person character on the planet surface)

## Features

### 🌍 Spherical Terrain Generation
- **Icosphere-based mesh generation** with customizable subdivision levels
- **Noise-based heightmap** using FastNoiseLite for realistic terrain variation
- **Multi-octave noise** for varied terrain features (mountains, valleys, plains)
- **LOD system ready** - Framework in place for Level of Detail optimization
- **PBR materials** with proper normal mapping and lighting

### 🌊 Realistic Water System
- **Spherical water shell** that conforms to planet surface
- **Animated wave system** with layered noise for realistic ocean movement
- **Advanced water shader** featuring:
  - Fresnel effect for realistic water appearance
  - Dynamic wave displacement in vertex shader
  - Foam generation on wave peaks
  - Transparency and depth-based color mixing
  - Specular highlights and reflections

### 🎥 Orbital Camera Controller
- **KSP-style camera controls**:
  - Right-click drag to rotate around planet
  - Mouse wheel to zoom in/out
  - Middle-click drag to pan
  - Arrow keys for keyboard rotation
- **Smooth interpolated movement**
- **Configurable distances and speeds**

### 🚶 First-Person Player Mode
- **Spherical gravity system** aligned to planet center
- **WASD movement** with Sprint (Shift key)
- **Mouse look** with captured cursor
- **Jump mechanics** working with planetary gravity
- **Character auto-aligns** to planet surface
- Walk on any part of the spherical terrain

### 🌅 Atmospheric Effects
- **Atmospheric scattering shader** creates blue halo around planet
- **Procedural sky** with proper horizon colors
- **Volumetric fog** for atmospheric depth
- **Directional sunlight** with shadows
- **HDR rendering** with glow/bloom effects

## Project Structure

```
terrain4/
├── scenes/
│   ├── launcher.tscn          # Mode selection launcher
│   ├── main.tscn              # Orbital camera mode
│   └── player_mode.tscn       # First-person player mode
├── scripts/
│   ├── spherical_terrain.gd   # Terrain generation system
│   ├── spherical_water.gd     # Water system controller
│   ├── orbital_camera.gd      # Orbital camera controller
│   ├── player_character.gd    # First-person player controller
│   ├── atmosphere.gd          # Atmosphere renderer
│   └── scene_selector.gd      # Mode launcher UI
├── shaders/
│   ├── water.gdshader         # Water shader with waves
│   └── atmosphere.gdshader    # Atmospheric scattering
└── project.godot              # Godot project configuration
```

## Configuration

### Terrain Settings
Edit in `SphericalTerrain` node:
- **planet_radius**: Base radius of planet (default: 100.0)
- **terrain_height**: Maximum height variation (default: 10.0)
- **subdivisions**: Icosphere subdivision level (default: 5)
- **noise_scale**: Scale of noise patterns (default: 0.5)
- **noise_octaves**: Number of noise layers (default: 6)
- **seed_value**: Random seed for terrain generation (default: 12345)

### Water Settings
Edit in `SphericalWater` node:
- **planet_radius**: Should match terrain radius (default: 100.0)
- **water_level**: Height above planet surface (default: 2.0)
- **wave_speed**: Animation speed of waves (default: 0.5)
- **wave_scale**: Size of wave patterns (default: 1.0)
- **wave_height**: Amplitude of waves (default: 0.3)

### Camera Settings
Edit in `OrbitalCamera` node:
- **distance**: Initial distance from planet (default: 250.0)
- **min_distance**: Minimum zoom distance (default: 50.0)
- **max_distance**: Maximum zoom distance (default: 1000.0)
- **rotation_speed**: Keyboard rotation speed (default: 0.3)
- **zoom_speed**: Zoom speed (default: 20.0)

## Controls

### Launcher
- **O**: Launch Orbital Camera mode
- **P**: Launch Player Mode
- **ESC**: Quit

### Orbital Camera Mode
- **Right Mouse Button + Drag**: Rotate camera around planet
- **Middle Mouse Button + Drag**: Pan camera
- **Mouse Wheel**: Zoom in/out
- **Arrow Keys**: Rotate camera
- **ESC**: Quit application

### Player Mode
- **WASD**: Move (forward/left/back/right)
- **Shift**: Sprint
- **Space**: Jump
- **Mouse**: Look around (cursor is captured)
- **ESC**: Release cursor (press again to quit)

## Technical Details

### Terrain Generation Algorithm
1. Creates base icosahedron (20 faces)
2. Subdivides faces recursively for desired detail level
3. Normalizes vertices to sphere surface
4. Applies 3D noise for seamless heightmap
5. Generates proper normals and UVs
6. Creates mesh with PBR material

### Water Shader Features
- **Vertex displacement**: Animated using 3D noise functions
- **Normal perturbation**: Wave normals calculated from height differences
- **Fresnel effect**: Angle-dependent transparency and color
- **Foam rendering**: Based on wave height peaks
- **Multi-layer waves**: Combined noise at different scales

### LOD System (Framework Ready)
The terrain generation system is designed to support LOD:
- LOD distances configured in terrain script
- _process() function ready for distance-based LOD switching
- Can be extended to generate multiple mesh levels

## Performance Tips

- **Reduce subdivisions** (4-5 recommended for testing, 6-7 for production)
- **Adjust water mesh quality** via subdivisions parameter
- **Use LOD system** for large-scale terrains (implementation available)
- **Lower noise octaves** if terrain generation is slow
- **Disable volumetric fog** for better FPS on lower-end hardware

## Future Enhancements

Potential improvements:
- Chunk-based terrain generation for larger planets
- Dynamic LOD based on camera distance
- Terrain texture splatting based on height/slope
- Underwater rendering effects
- Cloud layer generation
- Atmospheric scattering with Rayleigh/Mie scattering
- Collision detection for terrain
- Biome system with varied terrain types

## Requirements

- Godot 4.3+ (tested with 4.3)
- Forward Plus rendering mode
- Shader support for modern GPU features

## Credits

Inspired by:
- **Kerbal Space Program** - Orbital mechanics and camera system
- **ARMA 3** - Large-scale terrain rendering
- Sebastian Lague's procedural planet tutorials

Created for spherical planetary terrain exploration and game development.

## License

MIT License - Feel free to use in your own projects!
