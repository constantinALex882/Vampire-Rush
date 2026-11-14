extends Node2D


const TIME_LIMIT = 15.0

@onready var player = $Vampire/Player
@onready var timer_label: Label = $CanvasLayer/TimeLabel

var time_left := TIME_LIMIT	
var dead := false


func _process(delta: float) -> void:
	if dead:
		return
	time_left -= delta
	timer_label.text = "%.1f" % max(time_left, 0.0)
	if time_left <= 0.0:
		dead = true
		player.die()
