class_name MonsterScene
extends Node2D

var aura: CPUParticles2D = null
var monster: MonsterBody	= null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	make_spotlight()

	add_child(aura)
	move_child(aura, 0)
	#aura.z_index = -1

func set_monster(monster_param: MonsterBody) -> void:
	monster = monster_param

func refresh_ui() -> void:
	get_node("ResourceBars").update_resources(monster)

func get_sockets() -> Array[Socket]:
	var ret: Array[Socket] = []
	for child in get_node("Sockets").get_children():
		ret.append(child as Socket)

	return ret

func set_turn_spotlight(on: bool) -> void:
	aura.emitting 	= on

func make_spotlight():
	aura = CPUParticles2D.new()
	aura.name = "TurnHighlight"
	# Start off
	aura.emitting = false
	aura.amount = 8
	aura.lifetime = 1.5
	aura.texture = generate_glow_texture()
	aura.gravity = Vector2.ZERO

	# Faint Yellow
	aura.color = Color(1.0, 0.9, 0.4, 0.3)

	# Randomize the appearance slightly
	aura.scale_amount_min = 2.0
	aura.scale_amount_max = 4.0
	aura.spread = 180.0

	# Gentle upward drift
	aura.gravity = Vector2(0, -10)

	# Fade in and out
	var fade_gradient = Gradient.new()

	# Set 3 points: Transparent (Start) -> Opaque (Middle) -> Transparent (End)
	fade_gradient.set_offsets(PackedFloat32Array([0.0, 0.5, 1.0]))
	fade_gradient.set_colors(PackedColorArray([
		Color(1, 1, 1, 0), # Fully transparent at birth
		Color(1, 1, 1, 1), # Fully visible at half-life
		Color(1, 1, 1, 0)  # Fully transparent at death
	]))

	aura.color_ramp = fade_gradient

	# Also, use a scale curve if you want them to grow as they rise
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 0.5)) # Start at half scale
	scale_curve.add_point(Vector2(1, 1.5)) # End at 1.5x scale
	var curve_tex = CurveTexture.new()
	curve_tex.curve = scale_curve
	aura.scale_amount_curve = scale_curve # Note: CPUParticles uses the Curve directly

func generate_glow_texture() -> GradientTexture2D:
	var tex := GradientTexture2D.new()
	tex.width = 96
	tex.height = 96
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)

	var grad := Gradient.new()
	# White to transparent. The particle's 'color' property will tint this.
	grad.colors = [Color(1, 1, 1, 1), Color(1, 1, 1, 0)]
	tex.gradient = grad

	return tex