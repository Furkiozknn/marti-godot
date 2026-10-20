class_name Models
extends RefCounted
## The generated models in res://assets/models (Higgsfield Tripo, shared with the browser version).
## Every file is already normalised: +Y up, +Z forward, metres, base or centre pivot, so they are used
## 1:1. Each model is merged into one mesh with one textured material and cached. The material uses the
## vertex colour as albedo too, so MultiMesh instance colours still tint the texture.
## With --no-assets (or when a file is missing) mesh() returns null and the caller keeps its
## procedural mesh.

const DIR := "res://assets/models/"

static var _cache: Dictionary = {}


static func enabled() -> bool:
	return not Cli.has_flag("--no-assets")


## The merged mesh of a model (for example "simit"), or null when it cannot be used.
static func mesh(model_name: String) -> ArrayMesh:
	if _cache.has(model_name):
		return _cache[model_name]
	var result: ArrayMesh = null
	var path := DIR + model_name + ".glb"
	if enabled() and ResourceLoader.exists(path):
		var scene := load(path) as PackedScene
		if scene:
			result = _merge(scene.instantiate())
	_cache[model_name] = result
	return result


## A copy of a model's material with a tint and a glow (the golden simit).
static func tinted_material(model_name: String, tint: Color, glow: Color) -> StandardMaterial3D:
	var m := mesh(model_name)
	if m == null:
		return null
	var mat := (m.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat.albedo_color = tint
	mat.emission_enabled = true
	mat.emission = glow
	return mat


static func _merge(root: Node) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tex: Texture2D = null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var xf := _global_xf(mi, root)
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nor: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count := idx.size() if not idx.is_empty() else pos.size()
			for k in count:
				var i := idx[k] if not idx.is_empty() else k
				verts.append(xf * pos[i])
				normals.append((xf.basis * nor[i]).normalized() if i < nor.size() else Vector3.UP)
				uvs.append(uv[i] if i < uv.size() else Vector2.ZERO)
			var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if tex == null and src and src.albedo_texture:
				tex = src.albedo_texture
	root.free()
	if verts.is_empty():
		return null
	# White vertex colours: the material multiplies them (and any MultiMesh instance colour) into the texture.
	var colors := PackedColorArray()
	colors.resize(verts.size())
	colors.fill(Color.WHITE)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	out.surface_set_material(0, mat)
	return out


## The transform of a node relative to the scene root (the instance is not in the tree yet).
static func _global_xf(n: Node3D, root: Node) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	if root is Node3D:
		xf = (root as Node3D).transform * xf
	return xf
