class_name FiringCases
extends RefCounted

static func cases() -> Array[Dictionary]:
	return [
		{"kind": &"valid", "player_index": 0, "weapon_index": 0, "drag": Vector2(80, -30), "expected": true},
		{"kind": &"inactive", "player_index": 1, "weapon_index": 0, "drag": Vector2(80, -30), "expected": false},
		{"kind": &"unloaded", "player_index": 0, "weapon_index": 1, "drag": Vector2(80, -30), "expected": false},
		{"kind": &"repeated", "player_index": 0, "weapon_index": 0, "drag": Vector2(80, -30), "expected": false},
	]
