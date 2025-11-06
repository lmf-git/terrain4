# Spherical Terrain with Water - Godot 4.5

A complete spherical planetary terrain system with water for Godot 4.5, inspired by games like ARMA 3 and Kerbal Space Program.

## Six View Modes

**When you run the project, you'll see a launcher with six options:**

**Basic Modes (Smooth Terrain):**
- Press **O** for Orbital Camera mode (smooth simple terrain)
- Press **P** for Player Mode (smooth simple terrain)

**Tectonic Terrain (NEW - Realistic Geology):**
- Press **T** for Orbital Camera with tectonic plates
- Press **Y** for Player Mode with tectonic plates

**Optimized Modes (LOD System):**
- Press **L** for Orbital Camera with LOD optimizations
- Press **K** for Player Mode with LOD optimizations

## Features

### 🌋 Tectonic Plate System (NEW)
- **8 Tectonic Plates**: Randomly generated plate centers on the sphere
- **Realistic Mountains**: Form at plate collision boundaries
- **Continental vs Oceanic**: Two plate types with different elevations
  - Continental plates: Above sea level with moderate roughness
  - Oceanic plates: Below sea level, very smooth ocean floors
- **Polar Regions**: Flattened terrain at north and south poles
- **Smooth Transitions**: Realistic erosion and terrain smoothing
- **Procedural Cities**: 5 cities per planet with 5-15 buildings each
  - Buildings with random sizes, heights, and colors
  - Flattened terrain platforms for city placement
  - Collision-enabled buildings
  - Only placed on continental land masses
- **Cave Entrance Markers**: 10 procedurally placed cave markers
- **Advanced Triplanar Shader**: Seamless procedural textures
  - FBM noise-based texture generation
  - Biome-specific textures (water, sand, grass, rock, snow)
  - Smooth biome transitions
  - Detail noise for realistic surfaces
- **Configurable Parameters**:
  - Number of plates (default: 8)
  - Number of cities (default: 5)
  - Number of caves (default: 10)
  - Mountain height at boundaries
  - Ocean depth
  - Polar flatness and extent
  - Continental roughness vs oceanic smoothness
  - City flatten radius and strength

### ⚡ Advanced LOD System (NEW)
- **Frustum Culling**: Only renders terrain chunks visible to the camera
- **Distance-Based LOD**: Automatically reduces mesh detail for distant terrain
  - 4 LOD levels with configurable distances
  - Seamless transitions between detail levels
- **Chunk-Based Terrain**: Divides sphere into manageable chunks
- **Distance Culling**: Hides terrain beyond max view distance
- **Occlusion-Ready**: Framework supports occlusion culling
- **Performance Optimized**: Update frequency configurable (default: 10 FPS)
- **Perfect for large-scale planets** with thousands of triangles

### 🌍 Spherical Terrain Generation
- **Icosphere-based mesh generation** with customizable subdivision levels
- **Three terrain systems**:
  - **Basic**: Smooth noise-based terrain (6 subdivisions, Perlin noise)
  - **Tectonic**: Realistic plate tectonics with mountains and oceans
  - **LOD**: Advanced chunk-based system with culling (best for large planets)
- **Improved smoothness**: Reduced from 6 to 3 octaves, Perlin instead of Simplex
- **Higher detail**: Increased subdivisions from 5 to 6 for smoother curves
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

### 🚶 Enhanced Player Mode (NEW)
- **Spherical gravity system** aligned to planet center
- **WASD movement** with Sprint (Shift key)
- **Swimming mechanics** with buoyancy
  - Automatic detection when underwater
  - Free 3D movement while swimming
  - Swim upward with Space key
  - Water drag for realistic swimming
- **Mouse look** with captured cursor
- **Jump mechanics** working with planetary gravity
- **Character auto-aligns** to planet surface
- **Third-person camera toggle** (O key)
  - Visible magenta player capsule in third person
  - Adjustable third-person distance
- **Enhanced air control** for orbital movement
- **Powerful movement** with realistic physics
- Walk on any part of the spherical terrain
- Explore cities and find cave entrances

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
│   ├── main.tscn              # Orbital camera (smooth basic)
│   ├── player_mode.tscn       # Player mode (smooth basic)
│   ├── main_tectonic.tscn     # Orbital (tectonic plates)
│   ├── player_tectonic.tscn   # Player (tectonic plates)
│   ├── main_lod.tscn          # Orbital with LOD optimization
│   └── player_mode_lod.tscn   # Player with LOD optimization
├── scripts/
│   ├── spherical_terrain.gd   # Basic smooth terrain
│   ├── tectonic_terrain.gd    # Tectonic plate terrain
│   ├── spherical_terrain_lod.gd  # LOD terrain system
│   ├── terrain_chunk.gd       # Individual terrain chunk
│   ├── spherical_water.gd     # Water system controller
│   ├── orbital_camera.gd      # Orbital camera controller
│   ├── player_character.gd    # First-person player controller
│   ├── atmosphere.gd          # Atmosphere renderer
│   └── scene_selector.gd      # Mode launcher UI
├── shaders/
│   ├── water.gdshader         # Water shader with waves
│   ├── atmosphere.gdshader    # Atmospheric scattering
│   └── terrain_triplanar.gdshader  # Advanced triplanar terrain shader
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

### Tectonic Terrain Settings (Tectonic Scenes Only)
Edit in `TectonicTerrain` node:
- **num_plates**: Number of tectonic plates (default: 8)
- **plate_seed**: Random seed for plate generation (default: 12345)
- **mountain_height**: Height multiplier for mountains (default: 1.0)
- **ocean_depth**: Depth multiplier for ocean floors (default: 0.3)
- **polar_flatness**: How flat poles are, 0-1 (default: 0.7)
- **polar_extent**: How far from poles, 0-1 (default: 0.3)
- **continental_roughness**: Roughness of continents (default: 0.3)
- **oceanic_smoothness**: Smoothness of oceans (default: 0.9)
- **erosion_amount**: Overall terrain smoothing (default: 0.5)
- **num_cities**: Number of procedural cities (default: 5)
- **num_caves**: Number of cave entrance markers (default: 10)
- **city_flatten_radius**: Radius of flattened city platforms (default: 15.0)
- **city_flatten_strength**: How flat city terrain is, 0-1 (default: 0.9)

### Player Settings (Player Scenes Only)
Edit in `Player` node:
- **walk_speed**: Walking speed (default: 50.0)
- **sprint_speed**: Sprinting speed (default: 100.0)
- **jump_velocity**: Jump force (default: 250.0)
- **swim_speed**: Swimming speed (default: 30.0)
- **gravity_strength**: Gravity pull strength (default: 2.0)
- **air_control**: Movement control while airborne (default: 2.5)
- **water_level**: Height threshold for swimming (default: -8.0)

### LOD System Settings (LOD Scenes Only)
Edit in `SphericalTerrainLOD` node:
- **enable_lod**: Enable/disable LOD system (default: true)
- **lod_level_count**: Number of detail levels (default: 4)
- **lod_distance_0**: Distance for highest detail (default: 150.0)
- **lod_distance_1**: Distance for medium detail (default: 300.0)
- **lod_distance_2**: Distance for low detail (default: 600.0)
- **enable_frustum_culling**: Enable frustum culling (default: true)
- **enable_distance_culling**: Enable distance culling (default: true)
- **max_view_distance**: Maximum render distance (default: 2000.0)
- **update_frequency**: Seconds between LOD updates (default: 0.1)
- **chunk_divisions**: Number of terrain chunks (default: 12)

## Controls

### Launcher
- **O**: Launch Orbital Camera (smooth basic)
- **P**: Launch Player Mode (smooth basic)
- **T**: Launch Orbital Camera (tectonic plates)
- **Y**: Launch Player Mode (tectonic plates)
- **L**: Launch Orbital Camera with LOD (optimized)
- **K**: Launch Player Mode with LOD (optimized)
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
- **Space**: Jump (or swim upward when underwater)
- **O**: Toggle first-person/third-person camera
- **Mouse**: Look around (cursor is captured)
  - Free camera rotation when swimming or airborne
  - Grounded: Mouse look only (body follows movement)
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
