@tool
extends Sprite2D
class_name Socket

# Dark red
const DEAD_COLOR 	= Color(0.2, 0.0, 0.0)
const HEALTHY_COLOR = Color.WHITE

@export var allowed_slots: Array[Enums.Slot]:
    set(value):
        allowed_slots = value
        if Engine.is_editor_hint():
            _update_editor_visuals()

var socket_id: int                  = 0
@export var flip_sprite: bool       = false

var inserted_part : BodyPartData    = null

const TEX_HOLE_ROUND  = preload("res://art/icon.svg")
const TEX_HOLE_SQUARE = preload("res://art/icon.svg")

static var next_socket_id           = 1

func _ready() -> void:
    socket_id       = next_socket_id
    next_socket_id += 1

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

func get_parent_socket() -> Socket:
    var parent = get_parent()

    if parent is Socket:
        return parent as Socket

    return null

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
    var parent_socket = get_parent_socket()

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

# Returns all child sockets
func get_child_sockets() -> Array[Socket]:
    var sockets: Array[Socket] = []

    for child in get_children():
        if child is Socket:
            sockets.append(child as Socket)

            if child.get_child_count() > 0:
                sockets.append_array(child.get_child_sockets())

    return sockets

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
