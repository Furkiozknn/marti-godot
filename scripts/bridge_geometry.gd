class_name BridgeGeometry
extends RefCounted
## The bridge: two red towers, a deck and a suspension cable with hangers. Built once and shared by every bridge.

const TOWER_X := 25.5
const DECK_Y0 := 19.6
const DECK_Y1 := 22.8
const CABLE_MID := 27.0
const CABLE_END := 44.0
const SEGMENTS := 26

static var _mesh: ArrayMesh


static func cable_y(x: float) -> float:
	var k := x / TOWER_X
	return CABLE_MID + (CABLE_END - CABLE_MID) * k * k


static func shared_mesh() -> ArrayMesh:
	if _mesh == null:
		_mesh = _build()
	return _mesh


static func _build() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var red := Color.html("#DC2626")
	for sx: float in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * TOWER_X, 22.0, 0.0)), Vector3(3.6, 44.0, 6.2), red)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.0, (DECK_Y0 + DECK_Y1) * 0.5, 0.0)), Vector3(140.0, DECK_Y1 - DECK_Y0, 8.0), Color.html("#B91C1C"))
	var step := TOWER_X * 2.0 / SEGMENTS
	var cable := Color.html("#E5E7EB")
	for i in SEGMENTS:
		var xa := -TOWER_X + i * step
		var xb := xa + step
		var ya := cable_y(xa)
		var yb := cable_y(xb)
		var ang := atan2(yb - ya, step)
		var length := step * 1.04 / cos(ang)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, ang), Vector3((xa + xb) * 0.5, (ya + yb) * 0.5, 0.0)), Vector3(length, 0.55, 0.55), cable)
	var x := -24.0
	while x <= 24.1:
		var len_v := cable_y(x) - DECK_Y1
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(x, DECK_Y1 + len_v * 0.5, 0.0)), Vector3(0.18, len_v, 0.18), cable)
		x += 3.0
	st.set_material(MeshKit.vertex_material())
	return st.commit()
