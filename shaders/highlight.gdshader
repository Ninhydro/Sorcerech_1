shader_type canvas_item;

// Uniforms
uniform bool is_highlighted = false;
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width = 0.1;
uniform vec4 modulate : source_color = vec4(1.0);
uniform bool apply_modulate = true;

void fragment() {
    vec4 base_color = texture(TEXTURE, UV);
    vec4 final_color = base_color;
    
    // Apply modulation first (if enabled)
    if (apply_modulate) {
        final_color *= modulate;
    }
    
    // Apply highlight/outline effect on top
    if (is_highlighted && base_color.a > 0.0) {
        vec2 center = vec2(0.5, 0.5);
        float dist = distance(UV, center);
        float radius = 0.5;
        
        // Outline effect
        if (dist <= radius && dist > radius - outline_width) {
            float edge = smoothstep(radius - outline_width, radius, dist);
            final_color = mix(final_color, highlight_color, edge);
        }
        // Optional inner glow (remove if not needed)
        else if (dist <= radius - outline_width && dist > radius - outline_width * 1.5) {
            float inner_edge = smoothstep(radius - outline_width * 1.5, radius - outline_width, dist);
            final_color = mix(final_color, highlight_color, inner_edge * 0.3);
        }
    }
    
    COLOR = final_color;
}