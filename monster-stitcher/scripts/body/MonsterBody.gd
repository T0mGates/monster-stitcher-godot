class_name MonsterBody
extends Resource

const SPEED_BAR_MAX: float = 100.0

# ─── Identity & configuration ─────────────────────────────────────────────────
var monster_name		: String 				= "Unknown"

var ai_personality		: Enums.AIPersonality 	= Enums.AIPersonality.RANDOM

var heart				: HeartData           	= null
var parts				: Array[BodyPartData] 	= []

var monster_id			: int 					= -1

# The body scene (PackedScene) for this monster
# Instantiated at battle start, contains the body Sprite2D and sockets
# RigLayout reads the socket nodes to place parts
var body_scene			: PackedScene    		= null

# ─── Runtime state ────────────────────────────────────────────────────────────
# Instantiated body scene root, set by BattleScene after instantiation (created at runtime)
var body_scene_instance : MonsterScene			= null

var speed_bar			: float 				= 0.0
var current_energy		: int   				= 0

## Monster-level statuses. Separate from per-part statuses
var monster_statuses	: Array[StatusEffect] 	= []
var row_pos	    		: Enums.RowPosition 	= Enums.RowPosition.FRONT

var is_player_monster	: bool 					= false

# ══════════════════════════════════════════════════════════════════════════════
# Helpers/Getters
# ══════════════════════════════════════════════════════════════════════════════

# ─── Computed stats ───────────────────────────────────────────────────────────

var max_energy: int:
    get:
        return aggregate(Enums.Stat.CHARISMA) * 2 + 10

var energy_regen: int:
    get:
        return max(1, aggregate(Enums.Stat.RESOURCEFULNESS))

var crit_rate: float:
    get:
        return 0.05 + aggregate(Enums.Stat.LUCK) * 0.01

static var next_id = 0
static func get_next_monster_id():
    var to_return = next_id
    next_id += 1

    return to_return

# ─── Signals ─────────────────────────────────────────────────────────────────
signal monster_died(monster: MonsterBody)
signal energy_changed(monster: MonsterBody, new_val: int)

# ══════════════════════════════════════════════════════════════════════════════
# Initialization
# ══════════════════════════════════════════════════════════════════════════════
func _init(
    name_param					: String,
    ai_personality_param		: Enums.AIPersonality,
    heart_param					: HeartData,
    parts_param					: Array[BodyPartData],
    body_scene_param			: PackedScene
) -> void:
    parts 				= parts_param

    monster_name		= name_param
    ai_personality 		= ai_personality_param
    heart 				= heart_param

    body_scene 			= body_scene_param

    monster_id 			= get_next_monster_id()

    for part in parts:
        part.set_parent_body(self)

func initialize() -> void:
    current_energy   = 0
    speed_bar        = 0.0
    monster_statuses = []

    if heart:
        heart.initialize(self)

    for part in parts:
        part.initialize(self)
        part.part_destroyed.connect(_on_part_destroyed.bind(part))

func get_parts_by_slot_type(slot_type: Enums.Slot) -> Array[BodyPartData]:
    var ret_parts: Array[BodyPartData] = []

    for part in parts:
        if part.type == slot_type:
            ret_parts.append(part)

    return ret_parts

# ══════════════════════════════════════════════════════════════════════════════
# 'Scene' Related
# ══════════════════════════════════════════════════════════════════════════════
func refresh_resources_ui():
    body_scene_instance.refresh_ui()

# ══════════════════════════════════════════════════════════════════════════════
# Alive / death
# ══════════════════════════════════════════════════════════════════════════════
func is_alive() -> bool:
    if 0 == len(parts):
        return false
    return true

func force_die() -> void:
    for part in parts:
        part.force_die()

    check_death()


# ══════════════════════════════════════════════════════════════════════════════
# Turn lifecycle
# ══════════════════════════════════════════════════════════════════════════════

## Called at the start of this monster's turn
func process_turn_start() -> void:
    body_scene_instance.set_turn_spotlight(true)

    # Status effects tick first
    for part in parts:
        part.tick_statuses()

    # Heart passive: on_turn_start
    _fire_passive_turn_start()

    # Heart destroyed check
    if _all_hearts_destroyed():
        _log("Hearts destroyed — %s dies!" % monster_name)
        force_die()

func check_death() -> void:
    if not is_alive():
        emit_signal("monster_died")

func on_turn_end() -> void:
    body_scene_instance.set_turn_spotlight(false)
    check_death()


# ══════════════════════════════════════════════════════════════════════════════
# Damage
# ══════════════════════════════════════════════════════════════════════════════

# Primary entry point for dealing damage to a part
# Pass attacker/attacker part so Thorns and similar passives can reflect back
# Returns final damage dealt
func damage_part(
    target_part		: BodyPartData,
    amount			: int,
    user_part   	: BodyPartData 	 = null
) -> int:
    if not target_part:
        return -1

    var type_mult = target_part.get_type_multiplier(user_part.type)
    var raw       = int(amount * type_mult)

    # Heart passive: on_damage_received (may modify final_damage)
    var final_dmg = _fire_passive_damage_received(raw, target_part, user_part)

    target_part.take_damage(final_dmg)

    return final_dmg

# ══════════════════════════════════════════════════════════════════════════════
# Energy
# ══════════════════════════════════════════════════════════════════════════════
func spend_energy(amount: int) -> bool:
    if amount > 0 and current_energy < amount:
        return false

    current_energy = clampi(current_energy - amount, 0, max_energy)
    emit_signal("energy_changed", self, current_energy)
    return true

func can_afford(move: MoveData) -> bool:
    if null == move:
        return false

    return current_energy >= move.energy_cost


# ══════════════════════════════════════════════════════════════════════════════
# Part queries
# ══════════════════════════════════════════════════════════════════════════════
func get_alive_parts() -> Array[BodyPartData]:
    var r: Array[BodyPartData] = []
    for p in parts:
        r.append(p)
    return r

func get_all_moves() -> Array[MoveData]:
    var r: Array[MoveData] = []
    for p in get_alive_parts():
        if p.move != null: r.append(p.move)
    return r

## Returns the BodyPartData that owns a given MoveData, for actor_part lookup.
func get_part_for_move(move: MoveData) -> BodyPartData:
    for p in get_alive_parts():
        if p.move == move:
            return p
    return null

func get_part_with_socket_id(id: int) -> BodyPartData:
    for part in parts:
        if id == part.socket_id:
            return part
    return null

# ══════════════════════════════════════════════════════════════════════════════
# Type set bonuses
# ══════════════════════════════════════════════════════════════════════════════

## Counts alive parts per type and returns all qualifying bonus stats.
## Thresholds and bonuses are defined in Enums.TYPE_SET_BONUSES.
func get_type_set_bonuses() -> Dictionary:
    var counts: Dictionary[Enums.PartType, int] = {}
    for p in get_alive_parts():
        counts[p.type] = counts.get(p.type, 0) + 1

    var bonuses: Dictionary[Enums.Stat, int] = {}
    for ptype in counts:
        if not Enums.TYPE_SET_BONUSES.has(ptype):
            continue
        for threshold in Enums.TYPE_SET_BONUSES[ptype]:
            if counts[ptype] >= threshold:
                for stat in Enums.TYPE_SET_BONUSES[ptype][threshold]:
                    bonuses[stat] = bonuses.get(stat, 0) + Enums.TYPE_SET_BONUSES[ptype][threshold][stat]

    return bonuses


# ══════════════════════════════════════════════════════════════════════════════
# Aggregate stat
# ══════════════════════════════════════════════════════════════════════════════

## Sums body base_stats + heart passive_stats + all alive part passive_stats
## + type set bonuses. Used everywhere a raw stat number is needed.
func aggregate(stat: Enums.Stat) -> int:
    var total := 0

    if heart:
        total += heart.get_stat(stat)

    for p in get_alive_parts():
        total += p.get_stat(stat)

    total += get_type_set_bonuses().get(stat, 0)
    return total


# ══════════════════════════════════════════════════════════════════════════════
# Heart passive hook firing
# ══════════════════════════════════════════════════════════════════════════════
func _fire_passive_damage_received(
    raw			: int,
    target_part	: BodyPartData,
    user_part	: BodyPartData
) -> int:
    if heart == null or heart.passive == null:
        return raw

    var ctx            := HeartPassive.PassiveContext.new(
        raw,
        null,
        user_part,
        target_part
    )

    return heart.passive.on_damage_received(ctx)

func _fire_passive_turn_start() -> void:
    if heart == null or heart.passive == null:
        return

    var ctx            := HeartPassive.PassiveContext.new(
        0,
        self,
        null,
        null
    )

    heart.passive.on_turn_start(ctx)

func _fire_passive_part_destroyed(part: BodyPartData) -> void:
    if heart == null or heart.passive == null:
        return
    var ctx            := HeartPassive.PassiveContext.new(
        0,
        null,
        part,
        null
    )

    heart.passive.on_part_destroyed(ctx)

# ══════════════════════════════════════════════════════════════════════════════
# Internal
# ══════════════════════════════════════════════════════════════════════════════
func find_all_child_parts(parent_part: BodyPartData):
    var ret: Array[BodyPartData] = []

    for socket in parent_part.socket_node.get_child_sockets():
        ret.append(socket.inserted_part)

    return ret

func _on_part_destroyed(destroyed_part: BodyPartData) -> void:
    print("Part destroyed: " + destroyed_part.part_name)

    _fire_passive_part_destroyed(destroyed_part)

    var count = 0
    for part in parts:
        if part.part_id == destroyed_part.part_id:
            break
        count += 1

    parts.pop_at(count)

    var child_parts = find_all_child_parts(destroyed_part)

    for part in child_parts:
        part.force_die()

    check_death()

func _all_hearts_destroyed() -> bool:
    for p in parts:
        if p.slot == Enums.Slot.TORSO:
            return false

    return true

func _log(text: String) -> void:
    print("[Monster] " + text)

# ══════════════════════════════════════════════════════════════════════════════
# Debug
# ══════════════════════════════════════════════════════════════════════════════
func to_debug_string() -> String:
    var passive_label = ""
    if heart and heart.passive:
        passive_label = " [♥ %s]" % Enums.get_passive_label(heart.passive.get_id())

    var s = "[%s%s | E:%d/%d | Row:%d | %s]\n" % [
        monster_name, passive_label,
        current_energy, max_energy, row_pos,
        Enums.get_personality_label(ai_personality)
    ]

    for p in parts:
        s += "  " + p.to_debug_string() + "\n"

    var bonuses := get_type_set_bonuses()

    if not bonuses.is_empty():
        s += "  SetBonuses: %s\n" % str(bonuses)

    return s

# ══════════════════════════════════════════════════════════════════════════════
# Monster-level status
# ══════════════════════════════════════════════════════════════════════════════
func apply_monster_status(status: StatusEffect) -> void:
    for existing in monster_statuses:
        if existing.get_id() == status.get_id():
            existing.on_stack(status)
            return
    monster_statuses.append(status)

func tick_monster_statuses() -> void:
    for s in monster_statuses:
        s.tick()

    for i in range(len(monster_statuses)):
        if monster_statuses[i].is_expired():
            monster_statuses.pop_at(i)

func clear_monster_status(id: Enums.StatusID) -> void:
    for i in range(len(monster_statuses)):
        if id == monster_statuses[i].get_id():
            monster_statuses.pop_at(i)
            return

# ══════════════════════════════════════════════════════════════════════════════
# Visuals
# ══════════════════════════════════════════════════════════════════════════════
func build_monster_scene(scene_parent: Node2D) -> Node2D:
    # ── Instantiate body scene ──────────────────
    body_scene_instance = body_scene.instantiate() as MonsterScene

    scene_parent.add_child(body_scene_instance)

    body_scene_instance.set_monster(self)

    # Flip for enemies
    #if flip:
    #	rig.scale.x = -1.0

    var sockets = body_scene_instance.get_sockets()
    for socket in sockets:
        var part : BodyPartData = get_part_with_socket_id(socket.socket_id)
        socket.insert_part(part)

    return body_scene_instance
