class_name AIController
extends Node

##
## To add a new personality:
##   1. Add to Enums.AIPersonality (+ label/description there).
##   2. Add match cases in pick_move(), pick_enemy_monster(),
##      pick_enemy_part(), pick_ally_monster() as needed.
##   3. Done.


static func run_turn(monster: MonsterBody) -> void:
	var p: Enums.AIPersonality = monster.ai_personality

	if _should_rest(monster):
		BattleManager.do_rest(monster)
		return

	var chosen_move = pick_move(monster, p)
	if chosen_move == null or not monster.can_afford(chosen_move):
		BattleManager.do_rest(monster); return

	var user_part = monster.get_part_for_move(chosen_move)
	if user_part == null:
		BattleManager.do_rest(monster); return

	var target_m:     MonsterBody   = null
	var primary_part: BodyPartData  = null

	if chosen_move.targets_allies():
		target_m     = pick_ally_monster(monster, p)
		primary_part = _pick_ally_part(target_m, p)

	else:
		target_m     = pick_enemy_monster(monster, p)
		primary_part = pick_enemy_part(target_m, p)

	if target_m == null:
		BattleManager.do_rest(monster); return

	var ret 			= ActionResolver.expand_targets(user_part, primary_part)

	var target_parts 	= ret[0]
	var monsters 		= ret[1]

	if target_parts.is_empty():
		BattleManager.do_rest(monster); return

	ActionResolver.resolve(user_part, monsters, target_parts)


# ── Rest check ────────────────────────────────────────────────────────────────
static func _should_rest(monster: MonsterBody) -> bool:
	var threshold = max(2, monster.aggregate(Enums.Stat.RESOURCEFULNESS))

	if monster.current_energy > threshold:
		return false

	for move in monster.get_all_moves():
		if monster.can_afford(move):
			return false

	return true


# ── Move selection ────────────────────────────────────────────────────────────
static func pick_move(monster: MonsterBody, p: Enums.AIPersonality) -> MoveData:
	var usable: Array[MoveData] = []

	for move in monster.get_all_moves():
		if monster.can_afford(move):
			usable.append(move)

	if usable.is_empty():
		return null

	match p:
		Enums.AIPersonality.HEALER:
			# Prefer heal moves above all else
			for move in usable:
				if move.is_heal_move():
					return move

		Enums.AIPersonality.BERSERKER:
			# Pick highest-damage move
			usable.sort_custom(func(a, b): return _move_max_damage(a) > _move_max_damage(b))
			return usable[0]

	return usable[randi() % usable.size()]


static func _move_max_damage(move: MoveData) -> int:
	for e in move.effects:
		if e is MoveEffect.Damage:
			return (e as MoveEffect.Damage).base_damage
	return 0


# ── Enemy monster selection ───────────────────────────────────────────────────
static func pick_enemy_monster(
	actor: MonsterBody, p: Enums.AIPersonality
) -> MonsterBody:
	var enemies = BattleManager.player_monsters if not BattleManager.is_player_monster(actor) else BattleManager.enemy_monsters
	var alive   = []

	for monster in enemies:
		if monster.is_alive():
			alive.append(monster)

	if alive.is_empty():
		return null

	match p:
		Enums.AIPersonality.HEARTBREAKER:
			# Prefer monsters that still have a head
			for m in alive:
				if m.get_parts_by_slot(Enums.Slot.HEAD).size() > 0:
					return m

			return alive[0]

		Enums.AIPersonality.COWARD:
			# Target the enemy with the lowest current HP
			alive.sort_custom(func(a, b): return a.current_hp < b.current_hp)
			return alive[0]

		Enums.AIPersonality.BERSERKER:
			# Target the enemy with the highest current HP
			alive.sort_custom(func(a, b): return a.current_hp > b.current_hp)
			return alive[0]

		Enums.AIPersonality.VULTURE, Enums.AIPersonality.BODYBREAKER:
			# Any alive enemy is fine — part selection below does the real work
			pass

	return alive[randi() % alive.size()]


# ── Enemy part selection ──────────────────────────────────────────────────────
static func pick_enemy_part(target_m: MonsterBody, p: Enums.AIPersonality) -> BodyPartData:
	if target_m == null:
		return null

	var alive = target_m.get_alive_parts()

	if alive.is_empty():
		return null

	match p:
		Enums.AIPersonality.HEARTBREAKER:
			var heads = target_m.get_parts_by_slot(Enums.Slot.HEAD)

			if not heads.is_empty():
				return heads[0]

		Enums.AIPersonality.VULTURE:
			# Pick the part with the lowest current HP
			alive.sort_custom(func(a, b): return a.current_hp < b.current_hp)
			return alive[0]

		Enums.AIPersonality.BODYBREAKER:
			# Target torso, arms, or legs to strip away moves and stats
			for part in alive:
				if part.slot in [Enums.Slot.TORSO, Enums.Slot.ARM, Enums.Slot.LEG]:
					return part

	return alive[randi() % alive.size()]


# ── Ally selection ────────────────────────────────────────────────────────────
static func pick_ally_monster(
	actor: MonsterBody, p: Enums.AIPersonality
) -> MonsterBody:
	var allies = BattleManager.player_monsters if BattleManager.is_player_monster(actor) else BattleManager.enemy_monsters
	var alive   = []

	for monster in allies:
		if monster.is_alive():
			alive.append(monster)

	if p == Enums.AIPersonality.HEALER:
		# Target the ally with the lowest HP ratio
		alive.sort_custom(func(a, b):
			return float(a.current_hp) / a.max_hp < float(b.current_hp) / b.max_hp)

		return alive[0]

	return alive[randi() % alive.size()]


static func _pick_ally_part(target_m: MonsterBody, p: Enums.AIPersonality) -> BodyPartData:
	if target_m == null:
		return null

	var alive = target_m.get_alive_parts()

	if alive.is_empty():
		return null

	if p == Enums.AIPersonality.HEALER:
		alive.sort_custom(func(a, b): return a.current_hp < b.current_hp)
		return alive[0]

	return alive[randi() % alive.size()]
