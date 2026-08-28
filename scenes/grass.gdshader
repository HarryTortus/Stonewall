shader_type canvas_item;

uniform float saturation : hint_range(0.0, 3.0) = 1.0;
uniform float brightness : hint_range(0.0, 1.0) = 1.0; // 1.0 is normal, 0.0 is completely black

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Calculate saturation
    vec3 grayscale = vec3(dot(tex_color.rgb, vec3(0.299, 0.587, 0.114)));
    vec3 saturated_color = mix(grayscale, tex_color.rgb, saturation);
    
    // Apply darkness/brightness
    COLOR.rgb = saturated_color * brightness;
    COLOR.a = tex_color.a;
}
