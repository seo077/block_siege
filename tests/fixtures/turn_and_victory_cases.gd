class_name TurnAndVictoryCases
extends RefCounted

static func cases() -> Array[Dictionary]:
	return [
		{"kind": &"ordered_turns", "players": [10, 20, 30], "expected": [[1, 10], [1, 20], [1, 30], [2, 10], [2, 20], [2, 30], [3, 10]]},
		{"kind": &"rejected_turns"},
		{"kind": &"fortress_all", "destroyed": 6, "final": true},
		{"kind": &"fortress_partial", "destroyed": 5, "final": false},
		{"kind": &"round_boundary"},
		{"kind": &"total_score", "totals": [101, 99], "fortress": [6, 6], "winner": 1},
		{"kind": &"fortress_score", "totals": [100, 100], "fortress": [7, 6], "winner": 1},
		{"kind": &"draw_score", "totals": [100, 100], "fortress": [6, 6], "winner": -1},
	]
