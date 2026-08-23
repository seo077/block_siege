class_name StabilityCases
extends RefCounted

static func cases() -> Array[Dictionary]:
	return [
		{"kind": &"threshold", "linear": 0.12, "angular": 0.2, "quiet": true},
		{"kind": &"linear_over", "linear": 0.121, "angular": 0.2, "quiet": false},
		{"kind": &"angular_over", "linear": 0.12, "angular": 0.201, "quiet": false},
		{"kind": &"moving_timeout", "linear": 0.121, "angular": 0.201, "quiet": false},
	]
