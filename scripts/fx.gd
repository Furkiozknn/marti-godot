class_name Fx
extends RefCounted
## Particle helpers: the soft round sprite (never square dots) shared by the gull's feather trail and the
## Sparks pool that draws every burst.

static var _quad: QuadMesh
static var _sprite_mat: StandardMaterial3D


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
		# The same sprite for the Sparks pool (a MultiMesh): every instance faces the camera and keeps its scale.
		_sprite_mat = mat.duplicate() as StandardMaterial3D
		_sprite_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_sprite_mat.billboard_keep_scale = true
	return _quad


static func sprite_material() -> StandardMaterial3D:
	_mesh()
	return _sprite_mat


## Continuous feather trail that follows its parent (the gull).
static func trail(parent: Node3D, color: Color, amount: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = _mesh()
	p.amount = maxi(1, amount)
	# Short-lived: the gull flies 27-58 units/s, and older puffs would reach the chase camera
	# (19 units behind) and fill the screen as big blurred blobs.
	p.lifetime = 0.3
	p.local_coords = false
	# +z is the gull's forward: the puffs drift ahead slowly and the gull outruns them.
	p.direction = Vector3.BACK
	p.spread = 25.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.5
	p.gravity = Vector3(0.0, -0.6, 0.0)
	p.scale_amount_min = 0.2
	p.scale_amount_max = 0.35
	p.color = color
	parent.add_child(p)
	p.position = Vector3(0.0, 0.0, -0.4)
	p.emitting = true
	return p
