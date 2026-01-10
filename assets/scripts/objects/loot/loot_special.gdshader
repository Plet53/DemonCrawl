shader_type canvas_item;

uniform float speed = 1.0;
uniform float amplitude = 1.0;

void vertex() {
	VERTEX.y += amplitude * sin(2.0 * PI * speed * TIME);
}
