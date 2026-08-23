class_name RetryCases
extends RefCounted

static func cases() -> Array[Dictionary]:
	return [
		{"kind": &"timeout_then_success", "timeouts": 1},
		{"kind": &"timeout_twice_then_success", "timeouts": 2},
		{"kind": &"input_and_callback_spam", "timeouts": 1},
	]
