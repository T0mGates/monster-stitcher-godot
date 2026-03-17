## BattleManager.gd
## Autoload as "Battle" in Project > AutoLoad.
extends Node

enum BattlePhase { INACTIVE, TICKING, PLAYER_INPUT, RESOLVING, ENDED }
var phase: BattlePhase = BattlePhase.INACTIVE

var player_monsters: Array[MonsterBody] = []
var enemy_monsters:  Array[MonsterBody] = []
var turn_queue:      Array[MonsterBody] = []
var _pending_monster: MonsterBody       = null

const BASE_SPEED_PER_TICK: float = 5.0

signal battle_started()
signal player_turn_started(monster: MonsterBody)
signal action_resolved(result: ActionResolver.ResolutionResult)
signal battle_ended(winner: String)
signal log_message(text: String)

# ══════════════════════════════════════════════════════════════════════════════
# Setup
# ══════════════════════════════════════════════════════════════════════════════
func start_battle(players: Array[MonsterBody], enemies: Array[MonsterBody]) -> void:
	player_monsters  = players
	enemy_monsters   = enemies
	turn_queue       = []
	_pending_monster = null

	for m in all_monsters():
		m.initialize()
		m.monster_died.connect(_on_monster_died.bind(m))

	phase = BattlePhase.TICKING
	emit_signal("battle_started")
	BattleManager.log("⚔  Battle started!")
	_tick()


# ══════════════════════════════════════════════════════════════════════════════
# Speed bar tick
# ══════════════════════════════════════════════════════════════════════════════
func _tick() -> void:

	if phase == BattlePhase.ENDED:
		return

	await get_tree().create_timer(Globals.tick_delay).timeout

	for monster in all_monsters():
		if not monster.is_alive():
			continue

		monster.speed_bar += BASE_SPEED_PER_TICK + monster.aggregate(Enums.Stat.SPEED) * 0.5

		if monster.speed_bar >= MonsterBody.SPEED_BAR_MAX:
			monster.speed_bar -= MonsterBody.SPEED_BAR_MAX
			turn_queue.append(monster)

		monster.refresh_resources_ui()

	_process_turn_queue()

# ══════════════════════════════════════════════════════════════════════════════
# Turn queue
# ══════════════════════════════════════════════════════════════════════════════
func _process_turn_queue() -> void:
	while turn_queue.size() > 0:
		var monster: MonsterBody = turn_queue.pop_front()

		if not monster.is_alive():
			continue

		# process_turn_start ticks statuses, fires on_turn_start passive, checks heart death
		monster.process_turn_start()

		if not monster.is_alive():

			if _check_battle_over():
				return

			continue

		if is_player_monster(monster):
			_pending_monster = monster
			phase = BattlePhase.PLAYER_INPUT
			emit_signal("player_turn_started", monster)
			return

		else:
			AIController.run_turn(monster)
			monster.on_turn_end()

			if _check_battle_over():
				return

			# Add a delay
			await get_tree().create_timer(Globals.between_turn_delay).timeout

	if phase != BattlePhase.ENDED:
		phase = BattlePhase.TICKING
		_tick()


# ══════════════════════════════════════════════════════════════════════════════
# Player API
# ══════════════════════════════════════════════════════════════════════════════
func submit_player_action(
	user_part		: BodyPartData,
	target_monsters	: Array[MonsterBody],
	target_parts	: Array[BodyPartData]
) -> void:
	ActionResolver.resolve(user_part, target_monsters, target_parts)
	user_part.parent_monster.on_turn_end()

	if not _check_battle_over():
		phase = BattlePhase.TICKING
		# Add a delay
		await get_tree().create_timer(Globals.between_turn_delay).timeout
		_process_turn_queue()

func submit_rest() -> void:
	if phase != BattlePhase.PLAYER_INPUT or _pending_monster == null:
		return

	phase 				= BattlePhase.RESOLVING
	var monster 		= _pending_monster
	_pending_monster	= null

	do_rest(monster)
	monster.on_turn_end()

	if not _check_battle_over():
		phase = BattlePhase.TICKING
		# Add a delay
		await get_tree().create_timer(Globals.between_turn_delay).timeout
		_process_turn_queue()

func do_rest(monster: MonsterBody) -> void:
	var regen = max(1, monster.aggregate(Enums.Stat.RESOURCEFULNESS))
	monster.spend_energy(-regen)

	BattleManager.log("💤 %s rests +%d energy (%d/%d)" % [
		monster.monster_name, regen, monster.current_energy, monster.max_energy]
	)

	var result = ActionResolver.ResolutionResult.new(
		ActionResolver.ResolutionType.REST,
		null,
		[monster],
		[],
		regen
	)

	emit_signal("action_resolved", result)


# ══════════════════════════════════════════════════════════════════════════════
# Win / Loss
# ══════════════════════════════════════════════════════════════════════════════
func _check_battle_over() -> bool:
	var p = player_monsters.any(func(m): return m.is_alive())
	var e = enemy_monsters.any(func(m): return m.is_alive())

	if   not p and not e:
		_end_battle("draw")

	elif not p:
		_end_battle("enemy")

	elif not e:
		_end_battle("player")

	else:
		return false

	return true

func _end_battle(winner: String) -> void:
	phase = BattlePhase.ENDED
	BattleManager.log("🏆 Winner: %s" % winner)
	emit_signal("battle_ended", winner)

func _on_monster_died(monster: MonsterBody) -> void:
	BattleManager.log("💀 %s has fallen." % monster.monster_name)
	_check_battle_over()

# ══════════════════════════════════════════════════════════════════════════════
# Helpers
# ══════════════════════════════════════════════════════════════════════════════
func all_monsters() -> Array[MonsterBody]:
	var all: Array[MonsterBody] = []
	all.append_array(player_monsters)
	all.append_array(enemy_monsters)
	return all

func is_player_monster(monster: MonsterBody) -> bool:
	return player_monsters.has(monster)

func _log_status_result(entry: Dictionary, monster: MonsterBody) -> void:
	var sid  = entry.get("status")
	var pname: String = entry["part"].part_name if entry.get("part") else "?"
	match sid:
		Enums.StatusID.BLEED:
			BattleManager.log("🩸 %s.%s bleeds %d" % [monster.monster_name, pname, entry.get("damage", 0)])
		Enums.StatusID.POISON:
			BattleManager.log("🟢 %s.%s poisoned %d" % [monster.monster_name, pname, entry.get("damage", 0)])
		Enums.StatusID.REGENERATING:
			BattleManager.log("💚 %s.%s regen +%d" % [monster.monster_name, pname, entry.get("healed", 0)])
		Enums.StatusID.STUNNED:
			BattleManager.log("⚡ %s.%s stunned" % [monster.monster_name, pname])

func log(text: String) -> void:
	print("[Battle] " + text)
	emit_signal("log_message", text)
