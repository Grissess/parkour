extends Node3D

@onready var limits = $Limits
@onready var spawns = $Spawns
@onready var pawns = $Pawns

const Pawn = preload("res://pawn.gd")

func spawn_pawn(pawn: Pawn) -> void:
	var spawnpoint: Node3D = spawns.get_children().pick_random()
	pawn.global_position = spawnpoint.global_position
	pawn.is_teleport = true
	pawn.look = Vector2(
		(Vector3.BACK * spawnpoint.global_basis).angle_to(Vector3.BACK),
		0.0
	)
	pawn.update_look()
	pawn.velocity = Vector3()
	pawn.health = 1.0
	
func hit_limit(b: PhysicsBody3D) -> void:
	if b is Pawn:
		b.health = 0.0
		
func on_dead(pawn: Pawn) -> void:
	get_tree().create_timer(0.5).timeout.connect(spawn_pawn.bind(pawn))

func _ready() -> void:
	for pawn in pawns.get_children():
		pawn.died.connect(on_dead.bind(pawn))
	for child in limits.get_children():
		if child is Area3D:
			child.body_entered.connect(hit_limit)
