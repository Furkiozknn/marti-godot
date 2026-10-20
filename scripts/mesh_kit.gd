class_name MeshKit
extends RefCounted
## Builds triangle meshes in code: boats, the bridge, flock birds. Godot treats clockwise
## triangles as front faces, so every quad is wound against its normal before it is emitted.


static func vertex_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.8
	return mat


## Adds an axis-aligned box of the given size, moved and rotated by xf.
static func add_box(st: SurfaceTool, xf: Transform3D, size: Vector3, color: Color) -> void:
	var h := size * 0.5
	add_quad(st, xf, color, Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3.RIGHT)
	add_quad(st, xf, color, Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3.LEFT)
	add_quad(st, xf, color, Vector3(-h.x, h.y, -h.z), Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3.UP)
	add_quad(st, xf, color, Vector3(-h.x, -h.y, h.z), Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3.DOWN)
	add_quad(st, xf, color, Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3.BACK)
	add_quad(st, xf, color, Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3.FORWARD)


## Adds one planar quad (a, b, c, d in order around the face) with the given outward normal.
static func add_quad(st: SurfaceTool, xf: Transform3D, color: Color, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	var wn := (xf.basis * normal).normalized()
	var pa := xf * a
	var pb := xf * b
	var pc := xf * c
	var pd := xf * d
	var flip := (pb - pa).cross(pc - pa).dot(wn) > 0.0
	if flip:
		_emit(st, pa, wn, color)
		_emit(st, pc, wn, color)
		_emit(st, pb, wn, color)
		_emit(st, pa, wn, color)
		_emit(st, pd, wn, color)
		_emit(st, pc, wn, color)
	else:
		_emit(st, pa, wn, color)
		_emit(st, pb, wn, color)
		_emit(st, pc, wn, color)
		_emit(st, pa, wn, color)
		_emit(st, pc, wn, color)
		_emit(st, pd, wn, color)


static func _emit(st: SurfaceTool, p: Vector3, n: Vector3, color: Color) -> void:
	st.set_normal(n)
	st.set_color(color)
	st.add_vertex(p)
