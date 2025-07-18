// highlight.gdshader
shader_type canvas_item;

uniform vec4 highlight_color : source_color = vec4(0.5, 0.8, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 2.0;
uniform float glow_intensity : hint_range(0.0, 5.0) = 1.5;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
    
    float alpha = -4.0 * color.a;
    alpha += texture(TEXTURE, UV + vec2(0.0, size.y)).a;
    alpha += texture(TEXTURE, UV + vec2(0.0, -size.y)).a;
    alpha += texture(TEXTURE, UV + vec2(size.x, 0.0)).a;
    alpha += texture(TEXTURE, UV + vec2(-size.x, 0.0)).a;
    
    vec4 outline = vec4(highlight_color.rgb, clamp(alpha, 0.0, 1.0));
    vec4 glow = outline * glow_intensity;
    
    COLOR = mix(color, glow, outline.a);
}