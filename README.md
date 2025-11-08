# Spherical Terrain with Water - Godot 4.5

A complete spherical planetary terrain system with water for Godot 4.5, inspired by games like ARMA 3 and Kerbal Space Program.

## Single Unified Experience

**The project starts directly in the game - no launcher needed!**

- Press **V** to toggle between Orbital and Player views at any time
- Switch seamlessly between perspectives during gameplay

**All features included:**
- Tectonic plates with realistic geology
- Procedural cities with buildings
- Cave entrance markers
- Advanced triplanar shader with biomes
- Swimming mechanics with buoyancy
- Polar regions
- First/third person toggle in player mode
- All features are configurable via export parameters

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

### ⚡ Advanced LOD System (FULLY IMPLEMENTED)
- **Cubesphere-Based Terrain**: 6-face cube sphere with quadtree subdivision
- **Dynamic Chunk Management**: Chunks subdivide/merge based on camera distance
- **Frustum Culling**: Only renders terrain chunks visible to the camera
- **Distance-Based LOD**: 6 LOD levels with configurable distance thresholds
  - Close: 150m, Medium-Close: 300m, Medium: 600m, Medium-Far: 1200m, Far: 2400m, Very Far: 4800m
  - Seamless transitions between detail levels
- **Chunk Stitching**: Prevents seams between different LOD levels
- **Quadtree Subdivision**: Each chunk splits into 4 children when needed
- **Chunk-Based Features**: Cities, airports, and caves placed consistently across chunks
- **Performance Optimized**: Only generates visible, required detail levels
- **Scalable**: Perfect for massive planets with millions of triangles

### 🌍 Spherical Terrain Generation
- **Cubesphere with Quadtree LOD**:
  - 6-face cube sphere subdivided dynamically based on camera distance
  - Tectonic plates, cities, airports, and roads fully integrated
  - Frustum culling and distance-based detail management
  - Optimized for massive planetary scales
- **Improved smoothness**: 3 octaves of Perlin noise
- **5-layer noise system**: Mountains, chains, hills, valleys, and fine detail
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

### 🚶 Enhanced Player System
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
│   └── main.tscn                   # Main game scene
├── scripts/
│   ├── planet_terrain_lod.gd       # LOD chunk-based terrain
│   ├── spherical_water.gd          # Water system controller
│   ├── orbital_camera.gd           # Orbital camera controller
│   ├── player_character.gd         # Enhanced player controller
│   ├── atmosphere.gd               # Atmosphere renderer
│   └── view_switcher.gd            # Handles view mode switching
├── shaders/
│   ├── water.gdshader              # Water shader with waves
│   ├── atmosphere.gdshader         # Inner atmosphere scattering
│   ├── atmosphere_outer.gdshader   # Outer atmosphere glow
│   └── terrain_triplanar.gdshader  # Advanced triplanar terrain shader
└── project.godot                   # Godot project configuration
```

## Configuration

### Terrain Settings
Edit in `PlanetTerrain` node:

**Planet Properties:**
- **planet_radius**: Base radius of planet (default: 500.0)
- **terrain_height**: Maximum height variation (default: 40.0)
- **max_lod_level**: Maximum subdivision depth (default: 6)
- **lod_distances**: Array of distance thresholds for each LOD level
  - Default: [150.0, 300.0, 600.0, 1200.0, 2400.0, 4800.0]
  - Lower values = more detail at closer distances

**Feature Toggles:**
- **enable_tectonic_plates**: Use tectonic system vs simple noise (default: true)
- **enable_cities**: Generate procedural cities (default: true)
- **enable_caves**: Place cave entrance markers (default: true)
- **enable_advanced_shader**: Use triplanar shader vs simple material (default: true)

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

**Tectonic Plates Settings** (when enable_tectonic_plates = true):
- **num_plates**: Number of tectonic plates (default: 8)
- **plate_seed**: Random seed for plate generation (default: 12345)
- **mountain_height**: Height multiplier for mountains (default: 1.0)
- **ocean_depth**: Depth multiplier for ocean floors (default: 0.3)
- **polar_flatness**: How flat poles are, 0-1 (default: 0.7)
- **polar_extent**: How far from poles, 0-1 (default: 0.3)
- **continental_roughness**: Roughness of continents (default: 0.3)
- **oceanic_smoothness**: Smoothness of oceans (default: 0.9)
- **erosion_amount**: Overall terrain smoothing (default: 0.5)

**Cities and Caves Settings** (when enable_cities/enable_caves = true):
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

## Controls

### View Switching
- **V**: Toggle between Orbital and Player views
- **ESC**: Quit (when in Orbital view) / Release mouse (when in Player view)

### Orbital View
- **Right Mouse Button + Drag**: Rotate camera around planet
- **Middle Mouse Button + Drag**: Pan camera
- **Mouse Wheel**: Zoom in/out
- **Arrow Keys**: Rotate camera

### Player View
- **WASD**: Move (forward/left/back/right)
- **Shift**: Sprint
- **Space**: Jump (or swim upward when underwater)
- **O**: Toggle first-person/third-person camera
- **Mouse**: Look around (cursor is captured)
  - Free camera rotation when swimming or airborne
  - Grounded: Mouse look only (body follows movement)
- **ESC**: Release cursor (press again to quit)

## Technical Details

### Terrain Generation Algorithm (Cubesphere LOD)
1. Creates 6 root chunks (one per cube face)
2. Each chunk is a quadtree node with UV bounds on its face
3. Every frame, for each visible chunk:
   - Calculate distance from camera to chunk center
   - Compare distance against LOD threshold array
   - Subdivide into 4 children if camera is too close
   - Merge children back if camera is far enough
   - Perform frustum culling to hide off-screen chunks
4. When generating chunk mesh:
   - Convert cube UV coordinates to sphere positions
   - Apply tectonic height calculation at each vertex
   - Generate normals and tangents with SurfaceTool
   - Add chunk stitching for seamless LOD transitions
   - Place cities/airports/caves if they fall within chunk bounds
5. Chunk resolution scales with LOD level (8-128 vertices per edge)

### Water Shader Features
- **Vertex displacement**: Animated using 3D noise functions
- **Normal perturbation**: Wave normals calculated from height differences
- **Fresnel effect**: Angle-dependent transparency and color
- **Foam rendering**: Based on wave height peaks
- **Multi-layer waves**: Combined noise at different scales

## Performance Tips

- **LOD system is now default** and provides excellent performance for large planets
- **Adjust LOD distances** to balance quality vs performance
  - Increase distances for better FPS (less detail)
  - Decrease for more detail (lower FPS)
- **max_lod_level** controls maximum detail - reduce to 4-5 for lower-end systems
- **Adjust water mesh quality** via subdivisions parameter (default: 5)
- **Lower noise octaves** if terrain generation is slow
- **Disable volumetric fog** for better FPS on lower-end hardware
- **Use wireframe mode (G key)** to see LOD system in action

## Future Enhancements

Completed:
- ✅ Chunk-based terrain generation for larger planets
- ✅ Dynamic LOD based on camera distance
- ✅ Collision detection for terrain

Potential improvements:
- Advanced texture splatting based on height/slope/biome
- Underwater rendering effects (caustics, fog)
- Cloud layer generation with weather simulation
- More advanced atmospheric scattering (Rayleigh/Mie)
- Climate-based biome system (temperature/precipitation)
- Crater generation for moons
- Compute shader optimization for height calculations
- Occlusion culling for further performance gains

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
