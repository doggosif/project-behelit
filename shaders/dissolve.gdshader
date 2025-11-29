shader_type spatial;
render_mode blend_mix, cull_disabled, depth_prepass_alpha;

uniform sampler2D noise_texture : source_color;            // Grayscale noise
uniform sampler2D screen_fade_texture : source_color;      // Mask in screen space
uniform float fade_range : hint_range(0.0, 1.0) = 0.5;    // Control how much to dissolve
uniform vec4 color : source_color = vec4(1.0);            // Tint / color

void fragment() {
    // Map [0..1] -> [-0.5..0.5], then shrink it a bit
    float adjust_fade = (fade_range * 2.0 - 1.0) * 0.25;

    // Sample noise in UV and fade mask in screen space
    float n = texture(noise_texture, UV).r;
    float m = texture(screen_fade_texture, SCREEN_UV).r;

    float noise_value = (1.0 - (n * m)) - adjust_fade;

    // Small tweak to push the threshold
    noise_value = 1.0 - (noise_value - 0.02);

    // Hard dissolve mask: either 0 or 1
    float mask = clamp(round(noise_value), 0.0, 1.0);

    // Basic material outputs
    ALBEDO = color.rgb;
    EMISSION = color.rgb * mask;
    ALPHA = color.a * mask;
}
