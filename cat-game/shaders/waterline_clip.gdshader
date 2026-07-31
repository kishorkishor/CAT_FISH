shader_type canvas_item;
// Hides everything below the waterline while swimming.
//
// VERTEX here is node-local space *after* the sprite's offset is applied, so the
// sink offset, the rig swap and the hop all move the clip line with the art for
// free. The node origin is the cat's feet, which while swimming sit at the water
// surface - so waterline_y = 0 clips exactly at the surface. The same material
// can clip a boat hull later.

uniform bool clip_enabled = false;
uniform float waterline_y = 0.0;

varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	if (clip_enabled && local_y > waterline_y) {
		discard;
	}
}
