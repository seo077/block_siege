class_name FullRegression
extends RefCounted

static func scenarios() -> Array[Dictionary]:
	return [
		{"requirement": "REQ-001", "fixture": "fixed initialization and 200-block conservation"},
		{"requirement": "REQ-003", "fixture": "firing success and failure guards"},
		{"requirement": "REQ-004", "fixture": "fixed-tick stability and exact timeout"},
		{"requirement": "REQ-005", "fixture": "collapse baselines and thresholds"},
		{"requirement": "REQ-006", "fixture": "miss, single, and simultaneous destruction"},
		{"requirement": "REQ-007", "fixture": "ownership conservation through every stage"},
		{"requirement": "REQ-008", "fixture": "fortress and all round-20 outcomes"},
		{"requirement": "REQ-009", "fixture": "timeout hold, retry, and eventual resolution"},
		{"requirement": "REQ-010-UI", "fixture": "adjudication, totals, error, and retry UI"},
	]
