class_name Landmarks
extends RefCounted
## Procedural fallbacks for the landmark models (used with --no-assets or when a model is missing).
## Same footprint as the generated models: base pivot, front +z.


static func fallback(kind: String) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"mosque":
			_mosque(st)
		"yali":
			_yali(st)
		"galata":
			_galata(st)
		_:
			_maiden(st)
	st.set_material(MeshKit.vertex_material())
	return st.commit()


## A cream hall, a dome on top and two minarets with a balcony and a blue cap at the back corners.
static func _mosque(st: SurfaceTool) -> void:
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.0, 1.25, 0.0)), Vector3(6.4, 2.5, 6.4), Color.html("#EFE6D2"))
	var dome := SphereMesh.new()
	dome.radius = 1.0
	dome.height = 1.0
	dome.is_hemisphere = true
	MeshKit.add_primitive(st, dome, Transform3D(Basis.from_scale(Vector3(3.2, 2.6, 3.2)), Vector3(0.0, 2.5, 0.0)), Color.html("#E9C46A"))
	for sx: float in [-1.0, 1.0]:
		var at := Vector3(sx * 4.2, 0.0, -2.6)
		MeshKit.add_primitive(st, MeshKit.cylinder(0.25, 0.35, 16.0, 8), Transform3D(Basis(), at + Vector3(0.0, 8.0, 0.0)), Color.html("#F8FAFC"))
		MeshKit.add_primitive(st, MeshKit.cylinder(0.42, 0.42, 0.4, 8), Transform3D(Basis(), at + Vector3(0.0, 15.2, 0.0)), Color.html("#E9C46A"))
		MeshKit.add_primitive(st, MeshKit.cylinder(0.0, 0.4, 2.8, 8), Transform3D(Basis(), at + Vector3(0.0, 17.4, 0.0)), Color.html("#2563EB"))


## A wooden waterfront mansion: a two-storey main block with two wings and rows of windows at the front.
static func _yali(st: SurfaceTool) -> void:
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.0, 3.0, 0.0)), Vector3(10.0, 6.0, 4.0), Color.html("#F5E6C8"))
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.0, 6.3, 0.0)), Vector3(10.4, 0.6, 4.4), Color.html("#7C2D12"))
	for sx: float in [-7.0, 7.0]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx, 2.0, 0.0)), Vector3(4.0, 4.0, 3.4), Color.html("#EADBB8"))
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx, 4.2, 0.0)), Vector3(4.4, 0.5, 3.8), Color.html("#7C2D12"))
	for i in 6:
		for row: float in [1.5, 3.8]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(-4.0 + i * 1.6, row, 2.05)), Vector3(0.9, 1.1, 0.1), Color.html("#334155"))


## A round stone tower with a balcony ring and a pointed roof.
static func _galata(st: SurfaceTool) -> void:
	MeshKit.add_primitive(st, MeshKit.cylinder(3.2, 3.8, 22.0, 12), Transform3D(Basis(), Vector3(0.0, 11.0, 0.0)), Color.html("#D6C7A1"))
	MeshKit.add_primitive(st, MeshKit.cylinder(3.4, 3.4, 0.6, 12), Transform3D(Basis(), Vector3(0.0, 22.2, 0.0)), Color.html("#A8A29E"))
	MeshKit.add_primitive(st, MeshKit.cylinder(0.0, 3.8, 4.0, 12), Transform3D(Basis(), Vector3(0.0, 24.0, 0.0)), Color.html("#7C2D12"))


## A small tower on a rocky islet.
static func _maiden(st: SurfaceTool) -> void:
	MeshKit.add_primitive(st, MeshKit.cylinder(4.5, 5.5, 1.6, 10), Transform3D(Basis(), Vector3(0.0, 0.5, 0.0)), Color.html("#78716C"))
	MeshKit.add_primitive(st, MeshKit.cylinder(1.6, 2.0, 9.0, 10), Transform3D(Basis(), Vector3(0.0, 5.5, 0.0)), Color.html("#F5F5F4"))
	MeshKit.add_primitive(st, MeshKit.cylinder(1.4, 1.2, 2.0, 8), Transform3D(Basis(), Vector3(0.0, 11.0, 0.0)), Color.html("#FDE68A"))
	MeshKit.add_primitive(st, MeshKit.cylinder(0.0, 1.8, 1.6, 8), Transform3D(Basis(), Vector3(0.0, 12.8, 0.0)), Color.html("#475569"))
