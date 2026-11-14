extends Node2D

signal collected    # orb-ul anunță nivelul că a fost luat


func _ready() -> void:
	$Area2D.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):   
		collected.emit()
		queue_free()                 
