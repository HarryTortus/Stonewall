shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float line_thickness : hint_range(0.0, 10.0) = 2.0;

void fragment() {
    vec2 size = TEXTURE_PIXEL_SIZE * line_thickness;
    float outline = texture(TEXTURE, UV + vec2(-size.x, 0.0)).a +
                    texture(TEXTURE, UV + vec2(size.x, 0.0)).a +
                    texture(TEXTURE, UV + vec2(0.0, -size.y)).a +
                    texture(TEXTURE, UV + vec2(0.0, size.y)).a;
    outline = clamp(outline, 0.0, 1.0);
    vec4 color = texture(TEXTURE, UV);
    COLOR = mix(vec4(line_color.rgb, line_color.a * outline), color, color.a);
}