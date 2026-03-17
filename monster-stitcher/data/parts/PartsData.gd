extends Node2D
# ══════════════════════════════════════════════════════════════════════════════
# Art config — fill these in as you make sprites
# ══════════════════════════════════════════════════════════════════════════════

var data = {}

enum Monster { GRASSHOPPER, HORSE }

static func get_monster_json_name(monster: Monster) -> String:
    match monster:

        Monster.GRASSHOPPER:
            return "grasshopper"

        Monster.HORSE:
            return "horse"

    return ""

func _ready() -> void:
    data[Enums.Slot.ARM]   = load_json_file("res://data/parts/arms.json")
    data[Enums.Slot.LEG]   = load_json_file("res://data/parts/legs.json")
    data[Enums.Slot.HEAD]  = load_json_file("res://data/parts/heads.json")
    data[Enums.Slot.TAIL]  = load_json_file("res://data/parts/tails.json")
    data[Enums.Slot.TORSO] = load_json_file("res://data/parts/torsos.json")

func get_sprite_texture_path(monster: Monster, slot: Enums.Slot) -> String:
    return data[slot][get_monster_json_name(monster)]["spritePath"]

func get_socket_offset(monster: Monster, slot: Enums.Slot) -> Vector2:
    var offset_arr = data[slot][get_monster_json_name(monster)]["socketOffset"]
    return Vector2(float(offset_arr[0]), float(offset_arr[1]))

const TYPE_COLOR: Dictionary = {
	Enums.PartType.FLESH:  Color(0.85, 0.62, 0.50),
	Enums.PartType.DEMON:  Color(0.80, 0.18, 0.18),
	Enums.PartType.HOLY:   Color(0.95, 0.95, 0.55),
	Enums.PartType.BUG:    Color(0.35, 0.75, 0.28),
	Enums.PartType.SHARP:  Color(0.55, 0.78, 0.95),
	Enums.PartType.ARCANE: Color(0.68, 0.38, 0.92),
}

func load_json_file(path: String):
    if not FileAccess.file_exists(path):
        print("Error: File not found at: " + path)
        return null

    # Read the file content as text
    var file_text = FileAccess.get_file_as_string(path)

    # Parse the JSON string
    var json_result = JSON.parse_string(file_text)

    if json_result == null:
        # JSON.parse_string returns null on failure
        print("Error: Failed to parse JSON from file: " + path)
        return null
    else:
        # The result is the data in a Godot native type (Dictionary or Array)
        return json_result