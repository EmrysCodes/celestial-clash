extends Node

## Persistent session state between menus and matches.

signal hero_selected(hero_id: String)

## 4v4 phone slice — lives pool shared per team (classic AA DNA).
const LIVES_PER_TEAM := 20
const DUEL_LIFE_PENALTY := 4
const TEAM_SIZE := 4
const TEAM_LIGHT := 0 ## Seraphim / Angel side
const TEAM_DARK := 1 ## Ashen / Devil side

var selected_hero_id: String = "seraph"
var player_team: int = TEAM_LIGHT
var last_result: Dictionary = {}


func select_hero(hero_id: String) -> void:
	selected_hero_id = hero_id
	hero_selected.emit(hero_id)


func team_name(team: int) -> String:
	return "Seraphim" if team == TEAM_LIGHT else "Ashen"


func reset_result() -> void:
	last_result = {}
