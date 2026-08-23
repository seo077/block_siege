class_name FixedScenario
extends RefCounted

const MatchState = preload("res://scripts/core/match_state.gd")

static func build(player_ids: Array[int] = [1, 2]) -> MatchState:
	return MatchState.create_fixed_scenario(player_ids)
