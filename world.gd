extends Node3D

@onready var limits = $Limits
@onready var spawns = $Spawns

const Pawn = preload("res://pawn.gd")

func spawn_pawn(pawn: Pawn) -> void:
	var spawnpoint: Node3D = spawns.get_children().pick_random()
	pawn.global_position = spawnpoint.global_position
	pawn.look = Vector2(
		(Vector3.BACK * spawnpoint.global_basis).angle_to(Vector3.BACK),
		0.0
	)
	pawn.update_look()
	pawn.velocity = Vector3()
	
func hit_limit(b: PhysicsBody3D) -> void:
	if b is Pawn:
		spawn_pawn(b)

func _ready() -> void:
	for child in limits.get_children():
		if child is Area3D:
			child.body_entered.connect(self.hit_limit)
