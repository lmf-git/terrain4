shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Terrain heights for biome transitions
// Oceanic: -0.3, Continental: 3.75+, Mountains: up to ~14
uniform float water_level = -0.3;
uniform float sand_level = 0.5;
uniform float grass_level = 3.0;
uniform float rock_level = 7.0;
uniform float snow_level = 11.0;

// Triplanar texture scale
uniform float texture_scale = 0.1;
uniform float detail_scale = 20.0;

// FBM (Fractional Brownian Motion) for procedural textures
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < 5; i++) {
        value += amplitude * noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }

    return value;
}

// Triplanar mapping function
vec3 triplanar_texture(vec3 world_pos, vec3 blend_weights, vec2 uv_x, vec2 uv_y, vec2 uv_z, vec3 color) {
    // Generate procedural texture for each axis
    float tex_x = fbm(uv_x);
    float tex_y = fbm(uv_y);
    float tex_z = fbm(uv_z);

    // Blend textures based on surface normal
    float combined = tex_x * blend_weights.x + tex_y * blend_weights.y + tex_z * blend_weights.z;

    return color * (0.7 + combined * 0.6);
}

void fragment() {
    // World position for triplanar mapping
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 vertex_normal = normalize(NORMAL);

    // Calculate height from world position (distance from origin)
    float height = length(world_pos) - 100.0;  // Assuming planet radius 100

    // Triplanar blend weights based on normal
    vec3 blend_weights = abs(vertex_normal);
    blend_weights = blend_weights / (blend_weights.x + blend_weights.y + blend_weights.z);

    // Triplanar UVs
    vec2 uv_x = world_pos.zy * texture_scale;
    vec2 uv_y = world_pos.xz * texture_scale;
    vec2 uv_z = world_pos.xy * texture_scale;

    // Detail UVs for fine patterns
    vec2 detail_uv_x = world_pos.zy * texture_scale * detail_scale;
    vec2 detail_uv_y = world_pos.xz * texture_scale * detail_scale;
    vec2 detail_uv_z = world_pos.xy * texture_scale * detail_scale;

    // Base colors for different biomes
    vec3 water_color = vec3(0.0, 0.3, 0.6);
    vec3 sand_color = vec3(0.8, 0.7, 0.5);
    vec3 grass_color = vec3(0.2, 0.5, 0.2);
    vec3 rock_color = vec3(0.4, 0.35, 0.3);
    vec3 snow_color = vec3(0.9, 0.9, 0.95);

    vec3 base_color;
    float roughness_value;
    float metallic_value = 0.0;

    // Biome selection based on height
    if (height < water_level) {
        // Water - animated ripples
        float ripple = fbm(uv_x * 10.0 + TIME * 0.1) * blend_weights.x +
                       fbm(uv_y * 10.0 + TIME * 0.1) * blend_weights.y +
                       fbm(uv_z * 10.0 + TIME * 0.1) * blend_weights.z;
        base_color = water_color * (0.8 + ripple * 0.4);
        roughness_value = 0.1;
        metallic_value = 0.3;
    } else if (height < sand_level) {
        // Sand - grainy texture
        float sand_noise = fbm(detail_uv_x) * blend_weights.x +
                          fbm(detail_uv_y) * blend_weights.y +
                          fbm(detail_uv_z) * blend_weights.z;
        base_color = sand_color * (0.85 + sand_noise * 0.3);
        roughness_value = 0.9;
    } else if (height < grass_level) {
        // Grass - patches and dirt
        float grass_pattern = fbm(detail_uv_x * 0.5) * blend_weights.x +
                             fbm(detail_uv_y * 0.5) * blend_weights.y +
                             fbm(detail_uv_z * 0.5) * blend_weights.z;
        vec3 dirt_color = vec3(0.4, 0.3, 0.2);
        base_color = mix(dirt_color, grass_color, grass_pattern * 0.7 + 0.3);

        // Add fine grass detail
        float grass_detail = fbm(detail_uv_x) * blend_weights.x +
                            fbm(detail_uv_y) * blend_weights.y +
                            fbm(detail_uv_z) * blend_weights.z;
        base_color *= (0.9 + grass_detail * 0.2);
        roughness_value = 0.85;
    } else if (height < rock_level) {
        // Rock - cracks and variations
        float rock_cracks = fbm(detail_uv_x * 0.3) * blend_weights.x +
                           fbm(detail_uv_y * 0.3) * blend_weights.y +
                           fbm(detail_uv_z * 0.3) * blend_weights.z;
        base_color = rock_color * (0.7 + rock_cracks * 0.6);

        // Add fine detail
        float rock_detail = noise(detail_uv_x * 2.0) * blend_weights.x +
                           noise(detail_uv_y * 2.0) * blend_weights.y +
                           noise(detail_uv_z * 2.0) * blend_weights.z;
        base_color *= (0.85 + rock_detail * 0.3);
        roughness_value = 0.8;
    } else {
        // Snow - sparkle effect
        float snow_sparkle = fbm(detail_uv_x) * blend_weights.x +
                            fbm(detail_uv_y) * blend_weights.y +
                            fbm(detail_uv_z) * blend_weights.z;
        base_color = snow_color * (0.9 + snow_sparkle * 0.2);
        roughness_value = 0.3;
        metallic_value = 0.1;
    }

    // Smooth biome transitions
    float transition_blend = 2.0;

    if (height > water_level - transition_blend && height < water_level + transition_blend) {
        float blend = (height - (water_level - transition_blend)) / (2.0 * transition_blend);
        blend = smoothstep(0.0, 1.0, blend);
        vec3 water = water_color;
        vec3 sand = triplanar_texture(world_pos, blend_weights, detail_uv_x, detail_uv_y, detail_uv_z, sand_color);
        base_color = mix(water, sand, blend);
        roughness_value = mix(0.1, 0.9, blend);
    }

    if (height > sand_level - transition_blend && height < sand_level + transition_blend) {
        float blend = (height - (sand_level - transition_blend)) / (2.0 * transition_blend);
        blend = smoothstep(0.0, 1.0, blend);
        vec3 sand = triplanar_texture(world_pos, blend_weights, detail_uv_x, detail_uv_y, detail_uv_z, sand_color);
        vec3 grass = triplanar_texture(world_pos, blend_weights, detail_uv_x, detail_uv_y, detail_uv_z, grass_color);
        base_color = mix(sand, grass, blend);
        roughness_value = mix(0.9, 0.85, blend);
    }

    if (height > grass_level - transition_blend && height < grass_level + transition_blend) {
        float blend = (height - (grass_level - transition_blend)) / (2.0 * transition_blend);
        blend = smoothstep(0.0, 1.0, blend);
        vec3 grass = triplanar_texture(world_pos, blend_weights, detail_uv_x, detail_uv_y, detail_uv_z, grass_color);
        vec3 rock = triplanar_texture(world_pos, blend_weights, detail_uv_x, detail_uv_y, detail_uv_z, rock_color);
        base_color = mix(grass, rock, blend);
        roughness_value = mix(0.85, 0.8, blend);
    }

    if (height > rock_level - transition_blend && height < rock_level + transition_blend) {
        float blend = (height - (rock_level - transition_blend)) / (2.0 * transition_blend);
        blend = smoothstep(0.0, 1.0, blend);
        vec3 rock = triplanar_texture(world_pos, blend_weights, detail_uv_x, detail_uv_y, detail_uv_z, rock_color);
        vec3 snow = triplanar_texture(world_pos, blend_weights, detail_uv_x, detail_uv_y, detail_uv_z, snow_color);
        base_color = mix(rock, snow, blend);
        roughness_value = mix(0.8, 0.3, blend);
    }

    ALBEDO = base_color;
    ROUGHNESS = roughness_value;
    METALLIC = metallic_value;
}
