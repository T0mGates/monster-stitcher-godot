class_name DismemberedNode
extends RigidBody2D

var part: BodyPartData

func initialize(part_param: BodyPartData) -> void:
	part = part_param

	var tex_path : String = PartsData.get_sprite_texture_path(part.origin_monster_type, part.slot)
	if tex_path != "" and ResourceLoader.exists(tex_path):
		var sprite_node = get_node("Sprite2D")
		sprite_node.texture 	= load(tex_path)
		sprite_node.modulate 	= Socket.DEAD_COLOR

		var tex_size = sprite_node.texture.get_size()
		get_node("CollisionShape2D").shape.radius = tex_size.x / 2.0
		get_node("CollisionShape2D").shape.height = tex_size.y

		global_position = part.socket_node.get_part_sprite_node().global_position

	else:
		push_error("Couldn't find texture for " + part.part_name + ", tex_path: " + tex_path)

func do_animation() -> void:
	# Shoot the bodypart
	# Force
	apply_central_impulse(Vector2(randf_range(-1000, 1000), randf_range(-1000, 1000)))

	# Spin
	apply_torque_impulse(randf_range(-1000, 1000))

	await get_tree().create_timer(1.0).timeout