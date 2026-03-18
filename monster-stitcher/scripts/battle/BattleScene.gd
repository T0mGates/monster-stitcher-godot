extends Node2D

@onready var battle_log   : RichTextLabel         = $UI/BattleLog
@onready var action_label : Label                 = $UI/ActionLabel
@onready var tooltip_node : Control               = $UI/Tooltip
@onready var tooltip_text : RichTextLabel         = $UI/Tooltip/Label
@onready var player_rig   : Node2D                = $UI/PlayerSide/MonsterRig
@onready var enemy_rig    : Node2D                = $UI/EnemySide/MonsterRig

# ══════════════════════════════════════════════════════════════════════════════
# Runtime state
# ══════════════════════════════════════════════════════════════════════════════

var _all_parts    		: Array[BodyPartData] = []

var _targeting          : bool         = false
var _pending_user_part  : BodyPartData = null
var _pending_user      	: MonsterBody  = null

var dismember_scene		: PackedScene  = preload("res://scenes/utils/DismemberedNode.tscn")

# ══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
    var pm = ActiveMonsters.player_monster
    var em = ActiveMonsters.enemy_monster

    for part in pm.parts + em.parts:
        _all_parts.append(part)
        part.part_destroyed.connect(_on_part_destroyed.bind(part))

    pm.build_monster_scene(player_rig)
    em.build_monster_scene(enemy_rig)

    BattleManager.player_turn_started.connect(_on_player_turn_started)
    BattleManager.action_resolved.connect(_on_action_resolved)
    BattleManager.battle_ended.connect(_on_battle_ended)
    BattleManager.log_message.connect(_append_log)

    tooltip_node.visible = false
    action_label.text    = "Battle starting..."

    BattleManager.start_battle([pm], [em])
    pm.current_energy = pm.max_energy / 2.0
    em.current_energy = em.max_energy / 2.0

    _refresh_all(pm)
    _refresh_all(em)

# ── Part destroyed ────────────────────────────────────────────────────────────
func _on_part_destroyed(part: BodyPartData) -> void:
    var new_obj = dismember_scene.instantiate() as DismemberedNode
    new_obj.initialize(part)
    get_node("UI").add_child(new_obj)
    get_node("UI").move_child(new_obj, 1)

    new_obj.do_animation()

func _refresh_all(monster: MonsterBody) -> void:
    monster.refresh_resources_ui()

    for part in monster.parts:
        part.socket_node.update_sprite_status()

# ══════════════════════════════════════════════════════════════════════════════
# Hover tooltip
# ══════════════════════════════════════════════════════════════════════════════
func _process(_delta: float) -> void:
    if BattleManager.phase == BattleManager.BattlePhase.ENDED:
        tooltip_node.visible = false
        return

    var hovered 	: BodyPartData = null
    var parts 		= InputValidator.get_parts_under_cursor(_all_parts)

    if parts:
        hovered = parts[0]

    if hovered:
        _show_tooltip(hovered)
    else:
        tooltip_node.visible = false

func _show_tooltip(part: BodyPartData) -> void:
    var mouse_pos := get_viewport().get_mouse_position()

    var lines: Array[String] = []
    lines.append("[b]%s[/b]  [%s]" % [part.part_name, Enums.get_slot_label(part.slot)])
    lines.append("HP: %d / %d" % [part.current_hp, part.max_hp])
    lines.append("Type: %s" % Enums.get_type_label(part.type))
    if part.move != null:
        lines.append("─────")
        lines.append("[b]%s[/b]  (%dE)" % [part.move.move_name, part.move.energy_cost])
        lines.append(Enums.get_target_label(part.move.target_mode))

        for fx in part.move.get_effect_descriptions():
            lines.append("  • " + fx)

    if not part.statuses.is_empty():
        lines.append("─────")
        for s in part.statuses:
            lines.append("%s %s (%dt)" % [
                Enums.get_status_icon(s.get_id()),
                Enums.get_status_label(s.get_id()),
                s.turns_remaining])

    tooltip_text.text    = "\n".join(lines)
    tooltip_node.visible = true
    var tp := mouse_pos + Vector2(14, 14)
    var vp := get_viewport().get_visible_rect().size

    if tp.x + tooltip_node.size.x > vp.x:
        tp.x = mouse_pos.x - tooltip_node.size.x - 6

    if tp.y + tooltip_node.size.y > vp.y:
        tp.y = mouse_pos.y - tooltip_node.size.y - 6

    tooltip_node.position = tp


# ══════════════════════════════════════════════════════════════════════════════
# Input
# ══════════════════════════════════════════════════════════════════════════════
func _input(event: InputEvent) -> void:

    if BattleManager.phase == BattleManager.BattlePhase.ENDED:
        return

    if BattleManager.phase != BattleManager.BattlePhase.PLAYER_INPUT:
        return

    # ALREADY CLICKED A MOVE, look to cancel
    if _targeting:
        if InputValidator.is_input_event_cancel(event):
            _cancel_targeting()
            return

    if not (event is InputEventMouseButton):
        return

    var mb := event as InputEventMouseButton

    if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
        return

    # Phase 1: choose a move
    if not _targeting:

        if _pending_user == null:
            return

        for part in InputValidator.get_parts_under_cursor(_all_parts):

            if InputValidator.can_select_move(part):
                _enter_targeting(part)

    # Phase 2: choose target(s)
    else:

        for part in InputValidator.get_parts_under_cursor(_all_parts):
            if _confirm_target(part):
                return

func _enter_targeting(user_part: BodyPartData) -> void:
    _pending_user_part = user_part
    _targeting         = true
    action_label.text  = "Click target for [%s]  ·  RMB/Esc = cancel" % user_part.move.move_name

    user_part.socket_node.get_part_sprite_node().modulate = Color(1.6, 1.4, 0.3)

# Returns success status
func _confirm_target(part: BodyPartData) -> bool:
    var result 		= ActionResolver.expand_targets(_pending_user_part, part)

    var parts 		= result[0]
    var monsters 	= result[1]

    if 0 == len(parts) and 0 == len(monsters):
        return false

    # Success
    _clear_highlights()
    _targeting = false
    BattleManager.submit_player_action(_pending_user_part, monsters, parts)
    _pending_user_part = null

    return true


func _cancel_targeting() -> void:
    _targeting 			= false
    _pending_user_part 	= null

    if _pending_user:
        _on_player_turn_started(_pending_user)


func _clear_highlights() -> void:
    for part in _all_parts:
        if part.socket_node.get_part_sprite_node().visible:
            part.socket_node.update_sprite_status()


func _monster_owning(part: BodyPartData, is_player: bool) -> MonsterBody:
    var list := BattleManager.player_monsters if is_player else BattleManager.enemy_monsters
    for m in list:
        for p in m.parts:
            if p == part:
                return m
    return null

# ══════════════════════════════════════════════════════════════════════════════
# Player turn
# ══════════════════════════════════════════════════════════════════════════════
func _on_player_turn_started(monster: MonsterBody) -> void:
    _pending_user = monster
    _clear_highlights()
    for part in _all_parts:

        if not part.parent_monster.is_player_monster:
            continue

        if part.move == null:
            continue

        # Cool but messes with color based injuries
        #part.socket_node.get_part_sprite_node().modulate = Color.WHITE if monster.can_afford(part.move) else Color(0.5, 0.5, 0.5)

    action_label.text = "%s · Click a part to act · R = Rest" % [
        monster.monster_name
    ]


func _on_action_resolved(_result: ActionResolver.ResolutionResult) -> void:
    _refresh_all(ActiveMonsters.player_monster)
    _refresh_all(ActiveMonsters.enemy_monster)

func _on_battle_ended(winner: String) -> void:
    _targeting = false
    _clear_highlights()
    match winner:
        "player": action_label.text = "🏆 Victory!"
        "enemy":  action_label.text = "💀 Defeated..."
        _:        action_label.text = "Draw."


# ══════════════════════════════════════════════════════════════════════════════
# Rest
# ══════════════════════════════════════════════════════════════════════════════
func _unhandled_input(event: InputEvent) -> void:
    if BattleManager.phase != BattleManager.BattlePhase.PLAYER_INPUT:
        return
    if _targeting:
        return

    if event is InputEventKey and (event as InputEventKey).pressed:
        if (event as InputEventKey).keycode == KEY_R:
            _clear_highlights()
            BattleManager.submit_rest()

# ══════════════════════════════════════════════════════════════════════════════
# Helpers
# ══════════════════════════════════════════════════════════════════════════════

func _append_log(text: String) -> void:
    battle_log.append_text(text + "\n")

static func _rect_poly(hw: float, hh: float) -> PackedVector2Array:
    return PackedVector2Array([
        Vector2(-hw,-hh), Vector2(hw,-hh), Vector2(hw,hh), Vector2(-hw,hh)])
