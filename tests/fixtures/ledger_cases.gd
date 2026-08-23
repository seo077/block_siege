class_name LedgerCases
extends RefCounted

static func cases() -> Array[Dictionary]:
	return [
		{"kind": &"initialized"},
		{"kind": &"fired"},
		{"kind": &"delete_pending"},
		{"kind": &"timeout"},
		{"kind": &"retry"},
		{"kind": &"resolved"},
		{"kind": &"duplicate"},
		{"kind": &"duplicate_reference"},
	]
