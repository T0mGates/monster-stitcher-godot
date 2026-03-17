## AnimationClip.gd
## Pure data resource describing one animation. No scene nodes.
class_name AnimationClip
extends Resource

enum ClipType {
	LUNGE, SHAKE, PULSE, FADE_OUT,
	ANIMATION_PLAYER, SPAWN_VFX, TWEEN_PROPERTY, CALL_METHOD,
}

@export var clip_name: String   = "unnamed"
@export var clip_type: ClipType = ClipType.LUNGE
@export var duration:  float    = 0.25
@export var delay:     float    = 0.0
@export var ease_type:  Tween.EaseType       = Tween.EASE_IN_OUT
@export var trans_type: Tween.TransitionType = Tween.TRANS_QUAD

# LUNGE
@export var lunge_offset: Vector2 = Vector2(80, 0)

# SHAKE
@export var shake_strength: float = 8.0
@export var shake_count:    int   = 6

# PULSE
@export var pulse_scale: Vector2 = Vector2(1.3, 1.3)

# FADE_OUT
@export var fade_target_alpha: float = 0.0

# ANIMATION_PLAYER
@export var animation_name: String = ""

# SPAWN_VFX
@export var vfx_scene: PackedScene = null
@export_enum("local_origin", "target_part", "world_position") var vfx_spawn_at: String = "local_origin"
@export var vfx_world_position: Vector2 = Vector2.ZERO

# TWEEN_PROPERTY
@export var tween_node_path: NodePath = NodePath(".")
@export var tween_property:  String   = "modulate:a"
@export var tween_from:      Variant  = null
@export var tween_to:        Variant  = 1.0

# CALL_METHOD
@export var call_node_path: NodePath = NodePath(".")
@export var method_name:    String   = ""
@export var method_args:    Array    = []
