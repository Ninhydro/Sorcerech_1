shader_type canvas_item; // This shader is for 2D elements

// Uniforms (variables controlled by GDScript)
uniform bool is_highlighted = false;
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 0.0, 1.0); // Default: Yellow, opaque
uniform float highlight_width = 2.0; // Width of the highlight outline in pixels

void fragment() {
    vec4 base_color = texture(TEXTURE, UV); // Get the original pixel color from the icon's texture
    
    // If the icon IS highlighted, apply the highlight logic
    if (is_highlighted) {
        // Calculate distance from the edge of the texture's UV coordinates (0.0 to 1.0)
        vec2 uv_border_size = highlight_width * TEXTURE_PIXEL_SIZE;
        
        // Check if the current UV coordinate is within the border area
        bool in_horizontal_border = UV.x < uv_border_size.x || UV.x > (1.0 - uv_border_size.x);
        bool in_vertical_border = UV.y < uv_border_size.y || UV.y > (1.0 - uv_border_size.y);
        
        // Is this pixel within the border and also part of the original texture (not too transparent)?
        if ((in_horizontal_border || in_vertical_border) && base_color.a > 0.0) { // Changed threshold to 0.0
            // Blend the original color with the highlight color
            COLOR = mix(base_color, highlight_color, 0.7); // 0.7 means 70% highlight color, 30% original
        } else {
            // Not in border, draw original color
            COLOR = base_color; 
        }
    } else {
        // If the icon is NOT highlighted, just draw its original texture
        COLOR = base_color;
    }
}