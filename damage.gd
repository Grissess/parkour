extends TextureRect

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Global.active_pawn:
		self_modulate.a = 1.0 - clamp(Global.active_pawn.health, 0.0, 1.0)
