shader_type canvas_item;

// This uniform will control the alpha (transparency) of the sprite.
// It will be set from your GDScript.
uniform float camouflage_alpha_override : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    // Get the base color of the sprite (including its original texture and modulate)
    vec4 base_color = texture(TEXTURE, UV);

    // Multiply the base color's alpha by our camouflage_alpha_override.
    // This makes the entire sprite more or less transparent based on the uniform.
    COLOR = vec4(base_color.rgb, base_color.a * camouflage_alpha_override);
}
