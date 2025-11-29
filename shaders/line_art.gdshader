shader_type canvas_item;

uniform float strength = 0.01;
uniform vec4 color : source_color;

void fragment() {
    vec3 current_color = texture(TEXTURE, UV).rgb;
    vec3 right_color = texture(TEXTURE, UV + vec2(SCREEN_PIXEL_SIZE.x, 0.0)).rgb;
    vec3 bottom_color = texture(TEXTURE, UV - vec2(0.0, SCREEN_PIXEL_SIZE.y)).rgb;

    float r_distance = length(current_color - right_color);
    float b_distance = length(current_color - bottom_color);

    vec4 result = (r_distance > strength || b_distance > strength) ? color : vec4(0.0);
    COLOR = result;
}

