class_name Sparks
extends MultiMeshInstance3D
## A pool of soft round sprites for every burst (splashes, pickups, hits, fireworks), as in the
## browser version: one MultiMesh, so all bursts together cost one draw call, and no node is created
## per burst. A ring buffer reuses the oldest sprite when the pool is full.

var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _life := PackedFloat32Array()
var _life0 := PackedFloat32Array()
var _grav := PackedFloat32Array()
var _size := PackedFloat32Array()
var _col := PackedColorArray()
var _next: int = 0


## capacity: number of sprites; fog: false for bursts far away (fireworks); sprite: world size.
func _init(capacity: int, fog: bool, sprite: float) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(sprite, sprite)
	var mat := (Fx.sprite_material() as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat.disable_fog = not fog
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	multimesh = mm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pos.resize(capacity)
	_vel.resize(capacity)
	_life.resize(capacity)
	_life0.resize(capacity)
	_grav.resize(capacity)
	_size.resize(capacity)
	_col.resize(capacity)
	_life.fill(0.0)


## n sprites fly out of pos in every direction (mostly up), slow down under gravity and fade out.
func burst(pos: Vector3, color: Color, n: int, speed: float, life: float, gravity: float) -> void:
	for _k in n:
		var i := _next
		_next = (_next + 1) % _life.size()
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 1.0), randf_range(-1.0, 1.0)).normalized()
		_pos[i] = pos
		_vel[i] = dir * speed * randf_range(0.4, 1.0)
		_life0[i] = life * randf_range(0.6, 1.0)
		_life[i] = _life0[i]
		_grav[i] = gravity
		_size[i] = randf_range(0.5, 1.0)
		_col[i] = color


func clear() -> void:
	_life.fill(0.0)
	multimesh.visible_instance_count = 0


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	if GameState.phase == GameState.Phase.PAUSED:
		dt = 0.0
	var n := 0
	for i in _life.size():
		if _life[i] <= 0.0:
			continue
		_life[i] -= dt
		var v := _vel[i]
		v.y -= _grav[i] * dt
		_vel[i] = v
		_pos[i] += v * dt
		var k := clampf(_life[i] / _life0[i], 0.0, 1.0)
		var c := _col[i]
		c.a = k
		multimesh.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3.ONE * _size[i]), _pos[i]))
		multimesh.set_instance_color(n, c)
		n += 1
	multimesh.visible_instance_count = n
