## Socket.gd
## Place these as children of a Body scene node (on top of the body Sprite2D).
## Position the node in the editor to set where a part attaches.
## RigLayout reads socket positions directly from the node tree at runtime.
##
## Scene setup for a body:
##   BodyRoot (Node2D)            ← MonsterRig points here
##   ├── BodySprite (Sprite2D)    ← your body art, centered at (0,0)
##   ├── Socket (socket_id=0, allowed_slots=[HEAD])     @ (0, -80)
##   ├── Socket (socket_id=1, allowed_slots=[ARM])      @ (55, -15)
##   ├── Socket (socket_id=2, allowed_slots=[ARM])      @ (-55, -15)
##   ├── Socket (socket_id=3, allowed_slots=[LEG])      @ (25, 80)
##   └── ...
##
## socket_id (int) must match BodyPartData.socket_id (int) — just use 0,1,2,3...
## parent_socket_id: set to the socket_id of the socket this bone connects TO.
##   Leave -1 to connect to the body root (0,0).
##   Example: an eye socket parented to a head socket = head→eye bone.

@tool
extends Sprite2D
class_name Socket

# Dark red
const DEAD_COLOR 	= Color(0.2, 0.0, 0.0)
const HEALTHY_COLOR = Color.WHITE
const ANIMATOR_NAME = "BodyPartAnimator"

@export var allowed_slots: Array[Enums.Slot]:
	set(value):
		allowed_slots = value
		if Engine.is_editor_hint():
			_update_editor_visuals()

## Integer ID — matches BodyPartData.socket_id.
## Unique per body scene (0, 1, 2, 3...).
@export var socket_id: int = 0

## Which socket_id this socket's bone runs TO.
## -1 = connect to body root (0, 0). Set to another socket's id for chained bones.
## Example: head socket has parent=-1 (connects to torso).
##          eye socket has parent=<head socket_id> (connects to head).
@export var parent_socket_id: int = -1

@export var flip_sprite: bool = false

var inserted_part : BodyPartData = null

var parent_socket : Socket 		 = null

const TEX_HOLE_ROUND  = preload("res://art/icon.svg")
const TEX_HOLE_SQUARE = preload("res://art/icon.svg")

func _ready() -> void:
	update_socket_texture()
	if Engine.is_editor_hint():
		_update_editor_visuals()

	else:
		# invisible at runtime — parts render on top
		texture = null

	set_flip_sprite(flip_sprite)

func insert_part(part: BodyPartData) -> void:
	# ── Sprite or placeholder ──────────────────────────────────────────────
	var tex_path : String = PartsData.get_sprite_texture_path(part.origin_monster_type, part.slot)
	if tex_path != "" and ResourceLoader.exists(tex_path):
		update_socket_texture(tex_path)

		var sprite_offset     = PartsData.get_socket_offset(part.origin_monster_type, part.slot)
		if flip_sprite:
			sprite_offset.x = -1 * sprite_offset.x

		get_part_sprite_node().position += sprite_offset

	else:
		push_error("Could not find sprite for part_name: " + part.part_name)

	inserted_part 		= part
	part.socket_node 	= self

	part.part_damaged.connect(func(_p, _a): part_damaged())

	# ── Animator ──────────────────────────────────────────────────────────
	var anim_node   := Node.new()
	anim_node.name   = ANIMATOR_NAME
	anim_node.set_script(load("res://scripts/body/BodyPartAnimator.gd"))
	add_child(anim_node)
	# Lunge toward the opponent (player lunges right, enemy lunges left)
	var lunge_x     := 55.0 if not flip_sprite else -55.0
	(anim_node as BodyPartAnimator).clips = Animations.make_clips(Vector2(lunge_x, 0))

func get_body_part_animator() -> BodyPartAnimator:
	return get_node(ANIMATOR_NAME)

func update_parent_socket(new_parent: Socket) -> void:
	parent_socket = new_parent

func get_part_sprite_node() -> Sprite2D:
	return get_node("Sprites/BodypartSprite");

func part_damaged() -> void:
	_spawn_hit_flash()
	update_sprite_status()

func _spawn_hit_flash() -> void:
	# This is bad, fix later
	var ui 			= null
	var cur_node 	= self
	while true:
		cur_node = cur_node.get_parent()
		if not cur_node:
			break

		if cur_node.name == "UI":
			ui = cur_node
			break

	if not ui:
		return

	var gp 	  = global_position
	var count := 5

	for i in count:
		var spark     := Polygon2D.new()
		spark.polygon  = PackedVector2Array([
			Vector2(-3,-3), Vector2(3,-3), Vector2(3,3), Vector2(-3,3)])
		spark.color    = Color(1.0, 0.85, 0.1)
		spark.position = gp + Vector2(randf_range(-12, 12), randf_range(-12, 12))
		ui.add_child(spark)
		var tw  := spark.create_tween().set_parallel(true)
		var dir := Vector2(randf_range(-1,1), randf_range(-1.5,0)).normalized() * randf_range(20,50)
		tw.tween_property(spark, "position",   spark.position + dir, 0.35)
		tw.tween_property(spark, "modulate:a", 0.0, 0.35)
		tw.tween_callback(spark.queue_free).set_delay(0.36)

func update_socket_texture(part_texture_path: String = "") -> void:
	var _texture = null

	if allowed_slots.has(Enums.Slot.HEAD) or allowed_slots.has(Enums.Slot.TORSO):
		_texture = TEX_HOLE_SQUARE
	else:
		_texture = TEX_HOLE_ROUND

	if _texture:
		get_node("Sprites/SocketSprite").texture = _texture

	if part_texture_path:
		get_part_sprite_node().texture = load(part_texture_path)

func set_flip_sprite(flip: bool) -> void:
	get_part_sprite_node().flip_h = flip

func update_sprite_status():
	# Modulate sprite based off hp
	var sprite = get_part_sprite_node()
	if sprite:
		var hp_ratio 		= clampf(float(inserted_part.current_hp) / float(inserted_part.max_hp), 0.0, 1.0)

		# ratio = 1 means healthy color, 0 means dead_color
		sprite.modulate 	= DEAD_COLOR.lerp(HEALTHY_COLOR, hp_ratio)

# Called when inserted part dies
func destroy_inserted_part() -> void:
	print("in socket destroy inserted part")
	if parent_socket:
		if parent_socket.inserted_part:
			var status = StatusEffect.Dismembered.new(
				parent_socket.inserted_part,
				10
			)
			parent_socket.inserted_part.apply_status(status)

	inserted_part 	= null

	var sprite_node = get_part_sprite_node()
	sprite_node.texture = null
	sprite_node.visible = false

func _update_editor_visuals() -> void:
	update_socket_texture()
	modulate = Color(1, 1, 1, 0.85)
	# Tint by primary slot type
	if allowed_slots.is_empty(): return
	match allowed_slots[0]:
		Enums.Slot.HEAD:   modulate = Color(1.0, 0.7, 0.7, 0.85)
		Enums.Slot.TORSO:  modulate = Color(0.7, 0.7, 1.0, 0.85)
		Enums.Slot.ARM:    modulate = Color(0.7, 1.0, 0.7, 0.85)
		Enums.Slot.LEG:    modulate = Color(1.0, 1.0, 0.6, 0.85)
		Enums.Slot.TAIL:   modulate = Color(0.9, 0.7, 1.0, 0.85)

## Returns true if this socket accepts the given slot type.
func accepts(slot: Enums.Slot) -> bool:
	return allowed_slots.has(slot)

## Returns the world-space position of this socket.
## Use local_position() when building rigs (positions relative to body root).
func local_position() -> Vector2:
	return position   # Socket is a direct child of the body root, so position = local pos
