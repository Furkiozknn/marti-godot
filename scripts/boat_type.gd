class_name BoatType
extends Resource
## One kind of boat: how fast it sails, how big its collision box is and how it looks.
## Instances live in res://data/boats/*.tres.

@export var id: String = "ferry"
@export var speed: float = 11.0
@export var length: float = 15.0
@export var width: float = 6.0
@export var height: float = 2.6
@export var hull_color: Color = Color(0.97, 0.98, 0.99)
@export var deck_color: Color = Color(0.86, 0.15, 0.15)
@export var cabin_size: Vector3 = Vector3(5.0, 2.2, 8.0)
@export var cabin_z: float = -1.5
@export var cabin_color: Color = Color(0.99, 0.90, 0.54)
@export var has_mast: bool = false
@export var mast_height: float = 0.0


## Returns the boat as one vertex-coloured mesh (one draw call per boat).
func build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.0, height * 0.5, 0.0)), Vector3(width, height, length), hull_color)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.0, height * 0.75, 0.0)), Vector3(width + 0.1, 0.3, length + 0.1), deck_color)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.0, height + cabin_size.y * 0.5, cabin_z)), cabin_size, cabin_color)
	if has_mast:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.0, height + mast_height * 0.5, length * 0.1)), Vector3(0.2, mast_height, 0.2), Color(0.8, 0.84, 0.88))
	var mesh := st.commit()
	mesh.surface_set_material(0, MeshKit.vertex_material())
	return mesh


## Collision boxes in boat space (origin at the waterline centre of the hull).
func collision_boxes() -> Array[AABB]:
	var boxes: Array[AABB] = [AABB(Vector3(-width * 0.5, 0.0, -length * 0.5), Vector3(width, height, length))]
	if has_mast:
		boxes.append(AABB(Vector3(-0.3, 0.0, -0.3), Vector3(0.6, height + mast_height, 0.6)))
	return boxes
