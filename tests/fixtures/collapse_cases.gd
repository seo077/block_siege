class_name CollapseCases
extends RefCounted

static func cases() -> Array[Dictionary]:
	return [
		{"kind": &"translation_below", "offset": Vector3(0.099, 0.0, 0.0), "degrees": 0.0, "fallen": false},
		{"kind": &"translation_boundary", "offset": Vector3(0.100, 0.0, 0.0), "degrees": 0.0, "fallen": true},
		{"kind": &"rotation_below", "offset": Vector3.ZERO, "degrees": 29.9, "fallen": false},
		{"kind": &"rotation_boundary", "offset": Vector3.ZERO, "degrees": 30.0, "fallen": true},
	]
