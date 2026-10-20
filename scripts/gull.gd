class_name Gull
extends Node3D
## The seagull, built in code: a white teardrop body with a grey back, a white head, a yellow beak
## with a red spot, a fan tail, and long tapered wings (grey on top, black at the tips). The wings
## flap from the shoulder and fold at the wrist. Faces +z (the direction of flight).

signal flapped

var _body: Node3D
var _wing_l: Node3D
var _wing_r: Node3D
var _wrist_l: Node3D
var _wrist_r: Node3D
var _trail: CPUParticles3D
var _phase: float = 0.0
var _cycle: int = 0
var _clock: float = 0.0

## The wings rise in a shallow V and their leading edge tilts up, so the broad top side shows from
## behind, even when the camera is level with the gull.
const DIHEDRAL := 0.3
const PITCH := 0.5


func _ready() -> void:
	var white := _material(Color(0.97, 0.97, 0.96), 0.55)
	var grey := _material(Color(0.5, 0.56, 0.64), 0.7)
	var black := _material(Color(0.06, 0.06, 0.07), 0.6)
	var yellow := _material(Color(0.98, 0.78, 0.12), 0.5)
	var red := _material(Color(0.86, 0.15, 0.12), 0.5)

	_body = Node3D.new()
	add_child(_body)
	# Teardrop: a round chest at the back that narrows towards the head.
	_piece(_body, _sphere(1.0), Vector3(0.0, -0.02, -0.1), white, Vector3(0.36, 0.32, 0.8))
	# Grey back: a second, shifted ellipsoid that shows above the white belly.
	_piece(_body, _sphere(1.0), Vector3(0.0, 0.14, -0.1), grey, Vector3(0.34, 0.2, 0.74))
	_piece(_body, _sphere(1.0), Vector3(0.0, 0.12, 0.72), white, Vector3(0.27, 0.27, 0.27))
	_piece(_body, _sphere(1.0), Vector3(-0.15, 0.2, 0.9), black, Vector3(0.06, 0.06, 0.06))
	_piece(_body, _sphere(1.0), Vector3(0.15, 0.2, 0.9), black, Vector3(0.06, 0.06, 0.06))
	var beak := CylinderMesh.new()
	beak.top_radius = 0.02
	beak.bottom_radius = 0.055
	beak.height = 0.42
	_piece(_body, beak, Vector3(0.0, 0.1, 1.16), yellow, Vector3.ONE, Vector3(PI * 0.5, 0.0, 0.0))
	_piece(_body, _sphere(1.0), Vector3(0.0, 0.03, 1.2), red, Vector3(0.05, 0.05, 0.05))
	# Tail fan: a flat pentagon behind the body.
	_panel(_body, [Vector3(0.0, 0.0, -0.6), Vector3(-0.42, 0.0, -1.2), Vector3(-0.2, 0.0, -1.42),
		Vector3(0.2, 0.0, -1.42), Vector3(0.42, 0.0, -1.2)], grey)

	_wing_r = Node3D.new()
	_wing_r.position = Vector3(0.3, 0.12, 0.2)
	_body.add_child(_wing_r)
	_wrist_r = _wing(_wing_r, 1.0, grey, black)
	_wing_l = Node3D.new()
	_wing_l.position = Vector3(-0.3, 0.12, 0.2)
	_body.add_child(_wing_l)
	_wrist_l = _wing(_wing_l, -1.0, grey, black)
	_wing_r.rotation.x = -PITCH
	_wing_l.rotation.x = -PITCH

	_trail = Fx.trail(self, Color(1.0, 1.0, 1.0, 0.9), 8)


## One wing: the inner part hangs from the shoulder, the outer part from the wrist, and the tip is black.
## side is +1 for the right wing and -1 for the left, so the same shape is mirrored.
## Returns the wrist node, which the wing fold turns.
func _wing(shoulder: Node3D, side: float, grey: Material, black: Material) -> Node3D:
	_panel(shoulder, [Vector3(0.0, 0.0, 0.5), Vector3(1.25, 0.0, 0.4), Vector3(1.2, 0.0, -0.4),
		Vector3(0.0, 0.0, -0.5)], grey, side)
	var wrist := Node3D.new()
	wrist.position = Vector3(1.25 * side, 0.0, 0.0)
	shoulder.add_child(wrist)
	_panel(wrist, [Vector3(0.0, 0.0, 0.32), Vector3(1.45, 0.0, 0.05), Vector3(1.35, 0.0, -0.42),
		Vector3(0.0, 0.0, -0.32)], grey, side)
	# The black tip is a separate panel, so only the outer part of the wing is black.
	_panel(wrist, [Vector3(1.1, 0.0, 0.13), Vector3(1.45, 0.0, 0.05), Vector3(1.35, 0.0, -0.42),
		Vector3(1.12, 0.0, -0.4)], black, side)
	return wrist


## A flat polygon (convex, listed in order) in the xz plane, facing up. Both faces are drawn.
func _panel(parent: Node3D, pts: Array, mat: Material, side: float = 1.0) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	st.set_material(mat)
	for i in range(1, pts.size() - 1):
		for p in [pts[0], pts[i], pts[i + 1]]:
			st.add_vertex(Vector3(p.x * side, p.y, p.z))
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(m)


func _sphere(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _piece(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, scale_v: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.scale = scale_v
	m.rotation = rot
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(m)
	return m


## Wing and body motion. diving folds the wings faster and tilts the nose down.
func animate(dt: float, diving: bool, speed_ratio: float, bank: float, pitch: float) -> void:
	_clock += dt
	_phase += dt * (4.5 if diving else 10.0) * (0.85 + 0.15 * speed_ratio)
	var amp := 0.15 if diving else 0.7 + 0.1 * sin(_clock * 0.9)
	var flap := amp * sin(_phase)
	_wing_r.rotation.z = flap + DIHEDRAL
	_wing_l.rotation.z = -flap - DIHEDRAL
	var wrist := 0.45 * flap - (0.35 if diving else 0.12)
	_wrist_r.rotation.z = wrist
	_wrist_l.rotation.z = -wrist
	_body.rotation = Vector3(pitch, 0.0, -bank * 0.8)
	var cycle := floori(_phase / TAU)
	if cycle != _cycle:
		_cycle = cycle
		if not diving:
			flapped.emit()


func set_trail(on: bool) -> void:
	_trail.emitting = on
