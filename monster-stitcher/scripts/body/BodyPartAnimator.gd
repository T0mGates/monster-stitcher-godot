# Attach to the Node2D that visually represents one body part.
# Handles looping idle bob, one-shot clips (lunge/shake/pulse/fade), and in-scene VFX spawning
class_name BodyPartAnimator
extends Node

@export var clips: Dictionary = {}

## Idle bob settings
@export var idle_bob_speed:      float   = 1.8   ## radians per second
@export var idle_bob_amplitude:  float   = 3.0   ## pixels vertical
@export var idle_bob_phase:      float   = 0.0   ## per-part phase offset to stagger

var _rest_position: Vector2 = Vector2.ZERO
var _rest_scale:    Vector2 = Vector2.ONE
var _rest_rotation: float   = 0.0
var _rest_modulate: Color   = Color.WHITE

var _active_tween: Tween  = null

# current non-idle role, -1 = none
var _playing_role: int    = -1

var _idle_active:  bool   = false
var _idle_time:    float  = 0.0

signal clip_started(role: Enums.ClipRole)
signal clip_finished(role: Enums.ClipRole)


func _ready() -> void:
	_capture_rest()
	# Stagger idle phase randomly so parts don't all bob in sync
	idle_bob_phase = randf() * TAU

func _capture_rest() -> void:
	var p := get_parent() as Node2D
	if p:
		_rest_position = p.position
		_rest_scale    = p.scale
		_rest_rotation = p.rotation
		_rest_modulate = p.modulate

func _process(delta: float) -> void:
	if not _idle_active:
		return

	var p = get_parent() as Node2D
	if p == null or not p.visible:
		return

	_idle_time 	+= delta
	var bob 	= sin(_idle_time * idle_bob_speed + idle_bob_phase) * idle_bob_amplitude
	p.position 	= _rest_position + Vector2(0, bob)


# ── Public API ────────────────────────────────────────────────────────────────
func play(role: Enums.ClipRole, target_node: Node2D = null) -> void:
	if role == Enums.ClipRole.IDLE:
		_idle_active = true
		_idle_time   = 0.0
		return

	if not clips.has(role):
		return

	_idle_active 	= false
	_playing_role 	= role

	await _play_clip(clips[role], role, target_node)

	_playing_role 	= -1

	# Resume idle after any clip
	_idle_active  	= true

func play_sequence(roles: Array[Enums.ClipRole], target_node: Node2D = null) -> void:
	for role in roles:
		await play(role, target_node)

func play_parallel(roles: Array[Enums.ClipRole], target_node: Node2D = null) -> void:
	var max_duration: float = 0.0

	for role in roles:
		if not clips.has(role): continue
		max_duration = maxf(max_duration, (clips[role] as AnimationClip).duration)
		play(role, target_node)

	if max_duration > 0.0:
		await get_tree().create_timer(max_duration).timeout

func has_clip(role: Enums.ClipRole) -> bool:
	return clips.has(role)

func reset_to_rest() -> void:
	if _active_tween:
		_active_tween.kill()

	var node = get_parent() as Node2D

	if node:
		node.position = _rest_position
		node.scale    = _rest_scale
		node.rotation = _rest_rotation
		node.modulate = _rest_modulate


# ── Clip dispatch ─────────────────────────────────────────────────────────────
func _play_clip(clip: AnimationClip, role: Enums.ClipRole, target_node: Node2D) -> void:
	emit_signal("clip_started", role)

	if clip.delay > 0.0:
		await get_tree().create_timer(clip.delay).timeout

	if _active_tween:
		_active_tween.kill()

	match clip.clip_type:
		AnimationClip.ClipType.LUNGE:            await _lunge(clip, target_node)
		AnimationClip.ClipType.SHAKE:            await _shake(clip)
		AnimationClip.ClipType.PULSE:            await _pulse(clip)
		AnimationClip.ClipType.FADE_OUT:         await _fade_out(clip)
		AnimationClip.ClipType.ANIMATION_PLAYER: await _anim_player(clip)
		AnimationClip.ClipType.SPAWN_VFX:        await _spawn_vfx(clip, target_node)
		AnimationClip.ClipType.TWEEN_PROPERTY:   await _tween_property(clip)
		AnimationClip.ClipType.CALL_METHOD:      await _call_method(clip)

	# Snap back to rest after action clip
	var node = get_parent() as Node2D

	if node and clip.clip_type != AnimationClip.ClipType.FADE_OUT:
		node.position = _rest_position
		node.scale    = _rest_scale
		node.rotation = _rest_rotation

	emit_signal("clip_finished", role)


# ── Implementations ───────────────────────────────────────────────────────────
func _lunge(clip: AnimationClip, target_node: Node2D) -> void:
	var node = get_parent() as Node2D

	if not node:
		return

	# If we have a target, lunge toward it; otherwise use clip.lunge_offset
	var offset = clip.lunge_offset

	if target_node:
		var dir = (target_node.global_position - node.global_position).normalized()
		offset = dir * clip.lunge_offset.length()

	var half = clip.duration * 0.5
	_active_tween = create_tween().set_ease(clip.ease_type).set_trans(clip.trans_type)
	_active_tween.tween_property(node, "position", _rest_position + offset, half)
	_active_tween.tween_property(node, "position", _rest_position, half)

	await _active_tween.finished

func _shake(clip: AnimationClip) -> void:
	var node = get_parent() as Node2D

	if not node:
		return

	var step 		= clip.duration / (clip.shake_count * 2)
	_active_tween 	= create_tween()

	for i in clip.shake_count:
		var dir = 1.0 if i % 2 == 0 else -1.0
		_active_tween.tween_property(node, "position",
			_rest_position + Vector2(clip.shake_strength * dir, 0.0), step
		)

	_active_tween.tween_property(node, "position", _rest_position, step)
	await _active_tween.finished

func _pulse(clip: AnimationClip) -> void:
	var node = get_parent() as Node2D

	if not node:
		return

	var half = clip.duration * 0.5
	_active_tween = create_tween().set_ease(clip.ease_type).set_trans(clip.trans_type)
	_active_tween.tween_property(node, "scale", clip.pulse_scale, half)
	_active_tween.tween_property(node, "scale", _rest_scale, half)
	await _active_tween.finished

func _fade_out(clip: AnimationClip) -> void:
	var node = get_parent() as Node2D

	if not node:
		return

	_active_tween = create_tween().set_ease(clip.ease_type).set_trans(clip.trans_type)
	_active_tween.tween_property(node, "modulate:a", clip.fade_target_alpha, clip.duration)
	await _active_tween.finished

func _anim_player(clip: AnimationClip) -> void:
	var ap = get_parent().get_node_or_null("AnimationPlayer") as AnimationPlayer

	if not ap or clip.animation_name == "":
		return

	ap.play(clip.animation_name)
	await ap.animation_finished

func _spawn_vfx(clip: AnimationClip, target_node: Node2D) -> void:
	if not clip.vfx_scene:
		return

	var vfx := clip.vfx_scene.instantiate()
	get_tree().current_scene.add_child(vfx)

	match clip.vfx_spawn_at:

		"local_origin":
			if get_parent() is Node2D:
				vfx.global_position = (get_parent() as Node2D).global_position

		"target_part":
			if target_node: vfx.global_position = target_node.global_position

		"world_position":
			vfx.global_position = clip.vfx_world_position

	await get_tree().create_timer(clip.duration).timeout

func _tween_property(clip: AnimationClip) -> void:
	var target = get_parent().get_node_or_null(clip.tween_node_path)

	if not target:
		return

	_active_tween = create_tween().set_ease(clip.ease_type).set_trans(clip.trans_type)
	var tw = _active_tween.tween_property(target, clip.tween_property, clip.tween_to, clip.duration)

	if clip.tween_from != null:
		tw.from(clip.tween_from)

	await _active_tween.finished

func _call_method(clip: AnimationClip) -> void:
	var target = get_parent().get_node_or_null(clip.call_node_path)

	if not target or clip.method_name == "":
		return

	target.callv(clip.method_name, clip.method_args)
	await get_tree().create_timer(clip.duration).timeout
