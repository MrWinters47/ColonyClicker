shader_type canvas_item;

// --- Colors ---
uniform vec4 shadow_core_color : source_color = vec4(0.05, 0.1, 0.2, 0.6);
uniform vec4 sun_rim_color : source_color = vec4(1.0, 0.9, 0.6, 0.4);

// --- Master Controls ---
uniform float cloud_scale : hint_range(1.0, 20.0) = 4.0;
uniform float cloud_density : hint_range(0.0, 1.0) = 0.55;
uniform float time_speed = 0.5;
uniform vec2 wind_vector = vec2(0.2, 0.1);

// --- Chaos & Performance ---
uniform float warp_intensity : hint_range(0.0, 3.0) = 1.2;
uniform int fbm_octaves : hint_range(1, 6) = 4; // High cost, keep at 3 or 4

// --------------------------------------------------
// Core Math: Vector Hash & Quintic Noise
// --------------------------------------------------
vec2 hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    // THE ARTIFACT KILLER: Quintic Interpolation Curve
    // Smooths out the 2nd derivative to absolutely destroy any lingering grid artifacts
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0); 
    
    float n = mix(mix(dot(hash(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
                      dot(hash(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
                  mix(dot(hash(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
                      dot(hash(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
    return n * 0.5 + 0.5; 
}

// FBM loop modified to accept dynamic octaves for optimization
float fbm(vec2 uv, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < octaves; i++) {
        value += amplitude * noise(uv);
        uv *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

void fragment() {
    vec2 uv = UV * cloud_scale;
    vec2 movement = wind_vector * TIME * time_speed;

    // OPTIMIZATION: Decoupled Octaves
    // We run the warp pass with 1 fewer octave than the main cloud. 
    // You cannot see high-frequency detail in a distortion map, so this saves massive GPU cycles.
    int warp_octaves = max(1, fbm_octaves - 1); 
    
    vec2 warp = vec2(0.0);
    warp.x = fbm(uv + movement, warp_octaves);
    warp.y = fbm(uv + movement + vec2(5.2, 1.3), warp_octaves);
    
    vec2 warped_uv = uv + (warp * warp_intensity);

    // 1. Generate Core Cloud Shape
    float cloud_val = fbm(warped_uv + movement * 0.5, fbm_octaves);

    // 2. Generate Rim Lighting
    float sun_offset = 0.05;
    float cloud_val_up = fbm(warped_uv + movement * 0.5 - vec2(0.0, sun_offset), fbm_octaves); 
    float edge_rim = max(0.0, cloud_val - cloud_val_up);

    // 3. INNOVATION: Volumetric Thickness
    // The deeper inside the cloud you go, the darker/thicker the shadow becomes.
    float volume_darkness = smoothstep(cloud_density, cloud_density + 0.3, cloud_val);

    // 4. Assemble Masks
    float shadow_mask = smoothstep(cloud_density, cloud_density + 0.1, cloud_val);
    float rim_mask = smoothstep(0.0, 0.1, edge_rim) * shadow_mask;

    // 5. Output Construction
    // Mix the base color with itself slightly darkened based on the volume thickness
    vec4 base_shadow = mix(shadow_core_color, shadow_core_color * 1.5, volume_darkness);
    
    vec4 final_color = mix(vec4(0.0), base_shadow, shadow_mask);
    final_color = mix(final_color, sun_rim_color, rim_mask * 2.0); 

    COLOR = final_color;
}