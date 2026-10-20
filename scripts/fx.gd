class_name Fx
extends RefCounted
## Particle helpers. Particles use a soft round sprite (never square dots); the sprite and
## material are created once and shared by every burst.

static var _quad: QuadMesh


static func _mesh() -> QuadMesh:
	if _quad == null:
		var grad := Gradient.new()
		grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		grad.offsets = PackedFloat32Array([0.0, 1.0])
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_quad = QuadMesh.new()
		_quad.size = Vector2(0.6, 0.6)
		_quad.material = mat
	return _quad


## One-shot puff at a world position. The node frees itself when it is done.
static func burst(host: Node3D, pos: Vector3, color: Color, amount: int, speed: float, life: float, gravity: float) -> void:
	var p := CPUParticles3D.new()
	p.mesh = _mesh()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = maxi(1, amount)
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0.0, -gravity, 0.0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	p.color = color
	host.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


## Continuous feather trail that follows its parent (the gull).
static func trail(parent: Node3D, color: Color, amount: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = _mesh()
	p.amount = maxi(1, amount)
	p.lifetime = 1.1
	p.local_coords = false
	p.direction = Vector3.BACK
	p.spread = 25.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.5
	p.gravity = Vector3(0.0, -0.6, 0.0)
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.5
	p.color = color
	parent.add_child(p)
	p.position = Vector3(0.0, 0.0, -0.4)
	p.emitting = true
	return p
