# Drives all BodyPartAnimator nodes. Pure presentation, no game logic
class_name BattleAnimationPlayer
extends Node

# id to BodyPartAnimator
var _part_animators: Dictionary[int, BodyPartAnimator] = {}

signal animations_finished()

func connect_signals() -> void:
	BattleManager.action_resolved.connect(_on_action_resolved)
	BattleManager.battle_started.connect(_on_battle_started)
	BattleManager.battle_ended.connect(_on_battle_ended)


func register_part_animator(part_id: int, animator: BodyPartAnimator) -> void:
	_part_animators[part_id] = animator

func get_animator(part_id: int) -> BodyPartAnimator:
	return _part_animators.get(part_id, null)

# ── Signal handlers ───────────────────────────────────────────────────────────
func _on_battle_started() -> void:
	_play_all_idle()

func _on_battle_ended(_winner: String) -> void:
	pass

func _on_action_resolved(result: ActionResolver.ResolutionResult) -> void:
	if result.type == ActionResolver.ResolutionType.REST:
		_handle_rest(result)
	else:
		await _handle_action(result)

	emit_signal("animations_finished")

func _find_target_part_for_monster(monster: MonsterBody) -> BodyPartData:
	var target_part: BodyPartData = null

	var torsos = monster.get_parts_by_slot_type(Enums.Slot.TORSO)

	# No torsos, grab first available alive part
	if 0 == len(torsos):
		for part in monster.parts:
			target_part = part
			break

	else:
		target_part = torsos[0]

	return target_part

# ── Action animation ──────────────────────────────────────────────────────────
func _handle_action(result: ActionResolver.ResolutionResult) -> void:
	var user_anim = _part_animators.get(result.user_part.part_id, null)

	# Choose attack or cast role
	var role = result.user_part.move.user_animation

	# Find target part first, will tell us where to focus
	var target_part: BodyPartData = null
	if len(result.target_monsters) > 0:
		target_part = _find_target_part_for_monster(result.target_monsters[0])

	if not target_part:
		target_part = result.target_parts[0]

	# Find first target node for lunge direction
	var target_node: Node2D 		= null
	var t_anim: BodyPartAnimator 	=  _part_animators.get(target_part.part_id, null)

	if t_anim:
		target_node = t_anim.get_parent() as Node2D

	if user_anim:
		user_anim.play(role, target_node)

	await get_tree().create_timer(0.12).timeout

	# Hit reactions
	# See if we have more than one target
	var targets: Array[BodyPartData] = []

	if len(result.target_monsters) > 0:
		for monster in result.target_monsters:
			var part = _find_target_part_for_monster(monster)
			if part:
				targets.append(part)

	else:
		var unique_monsters: Array[MonsterBody] = []
		for part in result.target_parts:
			if part.parent_monster not in unique_monsters:
				unique_monsters.append(part.parent_monster)

		for monster in unique_monsters:
			var part = _find_target_part_for_monster(monster)
			if part:
				targets.append(part)

	var hit_duration: float = 0.0

	for part in targets:
		var anim = _part_animators.get(part.part_id, null)

		if anim == null:
			continue

		var hit_role = result.user_part.move.target_animation

		anim.play(hit_role)

		if anim.clips.has(hit_role):
			hit_duration = maxf(hit_duration, (anim.clips[hit_role] as AnimationClip).duration)

	if hit_duration > 0.0:
		await get_tree().create_timer(hit_duration).timeout

	#await _play_deaths(result)

func _handle_rest(result: ActionResolver.ResolutionResult) -> void:
	if result.user_part:
		(_part_animators[result.user_part.part_id] as BodyPartAnimator).play(Enums.ClipRole.REST)

'''
func _play_deaths(result: ActionResolver.ResolutionResult) -> void:
	var death_duration: float = 0.0
	var destroyed_parts: Array[BodyPartData] = []

	# See which parts died this turn
	var parts: Array[BodyPartData] = []
	if len(result.target_monsters) > 0:
		for monster in result.target_monsters:
			for part in monster.parts:
				parts.append(part)

	else:
		parts = result.target_parts

	for part in parts:
		var anim := _part_animators[part.part_id] as BodyPartAnimator

		# Part is destroyed here
		# Check if it is still visible
		var node = anim.get_parent() as Node2D
		if node:
			if node.visible:
				# Part was just destroyed
				destroyed_parts.append(part)
				if anim.clips.has(Enums.ClipRole.DIE):
					anim.play(Enums.ClipRole.DIE)
					var clip := anim.clips[Enums.ClipRole.DIE] as AnimationClip
					death_duration = maxf(death_duration, clip.duration)

	# Wait for longest anim to finish
	if death_duration > 0.0:
		await get_tree().create_timer(death_duration).timeout

	# Clean up
	for part in destroyed_parts:
		var anim = _part_animators.get(part.part_id)

		if anim:
			var node = anim.get_parent() as Node2D

			if node:
				node.visible = false
				print("Removed part: " + part.part_name)
'''

# ── Helpers ───────────────────────────────────────────────────────────────────
func _play_all_idle() -> void:
	for anim in _part_animators.values():
		(anim as BodyPartAnimator).play(Enums.ClipRole.IDLE)
