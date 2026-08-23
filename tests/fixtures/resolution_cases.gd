class_name ResolutionCases
extends RefCounted

static func cases() -> Array[Dictionary]:
	return [
		{"kind": &"failure", "destroyed_weapon_indices": []},
		{"kind": &"single", "destroyed_weapon_indices": [0]},
		{"kind": &"multiple", "destroyed_weapon_indices": [0, 1]},
		{"kind": &"invalid_plan", "destroyed_weapon_indices": [0]},
	]
