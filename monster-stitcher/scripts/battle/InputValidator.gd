extends Node2D

func mouse_is_hitting_part(sprite: Sprite2D) -> bool:
	var mouse_pos := get_viewport().get_mouse_position()

	if not sprite:
		return false

	if not sprite.visible:
		return false

	if sprite != null and sprite.texture != null:
		# Use the sprite's actual texture rect in screen space
		var tex_size := sprite.texture.get_size()
		var center   := sprite.global_position

		return abs(mouse_pos.x - center.x) <= tex_size.x * 0.5 \
			and abs(mouse_pos.y - center.y) <= tex_size.y * 0.5

	else:
		push_error("Using placeholder in mouse_is_hitting_part")
		# Placeholder: use a fixed 30x30 box on the container
		return abs(mouse_pos.x - sprite.global_position.x) <= 15 and abs(mouse_pos.y - sprite.global_position.y) <= 15

# Sorted by size
func get_parts_under_cursor(all_parts: Array[BodyPartData]) -> Array[BodyPartData]:
	var hit_parts: Array[BodyPartData] = []

	for part in all_parts:

		if InputValidator.mouse_is_hitting_part(part.socket_node.get_part_sprite_node()):
			hit_parts.append(part)

	# Sort by sprite area (smallest on top)
	hit_parts.sort_custom(func(a, b):
		return get_sprite_area(a) < get_sprite_area(b)
	)

	return hit_parts

func get_sprite_area(part: BodyPartData) -> float:
	var sprite := part.socket_node.get_part_sprite_node()

	if sprite == null:
		return INF

	if sprite != null and sprite.texture != null:
		var s := sprite.texture.get_size()
		return s.x * s.y

	return 20.0 * 20.0  # placeholder fallback

func can_select_move(clicked_part: BodyPartData) -> bool:
	var monster = clicked_part.parent_monster

	if not monster.is_player_monster:
		print("Is not player monster")
		return false

	if not monster.can_afford(clicked_part.move):
		print("Can't afford")
		return false

	if monster.row_pos not in clicked_part.move.user_row_pos_req:
		print("Row position is invalid")
		return false

	return true

func is_valid_click_target(user_bodypart: BodyPartData, target_bodypart: BodyPartData):
	if target_bodypart.parent_monster.row_pos not in user_bodypart.move.target_row_pos_req:
		print("Enemy not in row position that lets you use this move")
		return false

	if StatusEffect.Stunned in user_bodypart.statuses + user_bodypart.parent_monster.monster_statuses:
		return false

	return true

func is_input_event_cancel(event: InputEvent) -> bool:
	var cancel := false

	if event is InputEventKey:
		cancel = (event as InputEventKey).keycode == KEY_ESCAPE \
			and (event as InputEventKey).pressed

	if event is InputEventMouseButton:
		cancel = (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT \
			and (event as InputEventMouseButton).pressed

	return cancel
