class_name Animations
extends RefCounted

# ══════════════════════════════════════════════════════════════════════════════
# Clips
# ══════════════════════════════════════════════════════════════════════════════
static func make_clips(lunge_dir: Vector2) -> Dictionary:
	var attack            := AnimationClip.new()
	attack.clip_type       = AnimationClip.ClipType.LUNGE
	attack.lunge_offset    = lunge_dir
	attack.duration        = 0.30
	attack.trans_type      = Tween.TRANS_BACK
	attack.ease_type       = Tween.EASE_OUT

	var cast              := AnimationClip.new()
	cast.clip_type         = AnimationClip.ClipType.PULSE
	cast.pulse_scale       = Vector2(1.2, 1.2)
	cast.duration          = 0.4

	var hit               := AnimationClip.new()
	hit.clip_type          = AnimationClip.ClipType.SHAKE
	hit.shake_strength     = 9.0
	hit.shake_count        = 5
	hit.duration           = 0.28

	var hit_crit          := AnimationClip.new()
	hit_crit.clip_type     = AnimationClip.ClipType.SHAKE
	hit_crit.shake_strength = 18.0
	hit_crit.shake_count   = 7
	hit_crit.duration      = 0.38

	var heal_clip         := AnimationClip.new()
	heal_clip.clip_type    = AnimationClip.ClipType.PULSE
	heal_clip.pulse_scale  = Vector2(1.3, 1.3)
	heal_clip.duration     = 0.45

	var rest_clip         := AnimationClip.new()
	rest_clip.clip_type    = AnimationClip.ClipType.PULSE
	rest_clip.pulse_scale  = Vector2(1.15, 1.15)
	rest_clip.duration     = 0.5

	var die_clip          := AnimationClip.new()
	die_clip.clip_type     = AnimationClip.ClipType.FADE_OUT
	die_clip.fade_target_alpha = 0.0
	die_clip.duration      = 0.55
	die_clip.ease_type     = Tween.EASE_IN

	return {
		Enums.ClipRole.ATTACK:   attack,
		Enums.ClipRole.CAST:     cast,
		Enums.ClipRole.HIT:      hit,
		Enums.ClipRole.HEAL:     heal_clip,
		Enums.ClipRole.REST:     rest_clip,
		Enums.ClipRole.DIE:      die_clip,
	}