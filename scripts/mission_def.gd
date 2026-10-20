class_name MissionDef
extends Resource
## A daily mission. Instances live in res://data/missions/*.tres.

@export var id: String = ""
## Which run statistic counts for this mission: simit, fish, dist, power or combo (max in one run).
@export var stat: String = ""
@export var goal: int = 1
## Text with one %d for the goal number.
@export var text_tr: String = ""
@export var text_en: String = ""


func text(lang: String) -> String:
	return (text_en if lang == "en" else text_tr) % goal
