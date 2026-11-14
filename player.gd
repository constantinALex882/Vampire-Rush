extends CharacterBody2D

# Mișcare
const SPEED = 350.0
const JUMP_VELOCITY = -1100.0
const GRAVITY_UP = 1.8
const GRAVITY_DOWN = 3.0
const MAX_FALL_SPEED = 1500.0

# Slam
const SLAM_SPEED = 2200.0
const SLAM_JUMP_BOOST = 1.35
const SLAM_BOUNCE_WINDOW = 0.25

# Slide
const SLIDE_SPEED = 800.0     # viteza de start a slide-ului
const SLIDE_TIME = 0.7        # cât durează maxim (ții Ctrl apăsat)
const SLIDE_TILT_DEG = 15.0   # cât se înclină personajul

# Moarte
const MAX_FALL_TIME = 2.0

# NOU: tragere (recoil) + blast
const RECOIL_FORCE = 1100.0   # cât de tare te aruncă pistolul
const RECOIL_TIME = 0.25      # cât timp nu controlezi orizontal după tragere
const MAX_BOOSTS = 1          # câte trageri în aer (se reîncarcă pe sol)
const MUZZLE_POS = Vector2(100, -18)  # de unde iese blast-ul, față de GunPivot

var fall_time := 0.0
var is_slamming := false
var is_sliding := false
var slide_timer := 0.0
var slide_dir := 1.0
var bounce_timer := 0.0
var recoil_timer := 0.0       # NOU
var boosts_left := MAX_BOOSTS # NOU

@onready var sprite: Sprite2D = $Sprite2D
@onready var cam: Camera2D = $Camera2D
@onready var col: CollisionShape2D = $CollisionShape2D
@onready var gun_pivot: Node2D = $GunPivot   # NOU
var dust: CPUParticles2D
var blast: CPUParticles2D                     # NOU
var air_trail: CPUParticles2D                 # NOU: dâra de aer


func _ready() -> void:
	add_to_group("player")   # NOU: ventilatorul/launch pad-ul te recunoaște
	_add_action("left", [KEY_A, KEY_LEFT])
	_add_action("right", [KEY_D, KEY_RIGHT])
	_add_action("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_add_action("crouch", [KEY_CTRL, KEY_S])
	_setup_dust()
	_setup_blast()   # NOU
	_setup_air_trail()   # NOU


func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _setup_dust() -> void:
	dust = CPUParticles2D.new()
	dust.emitting = false
	dust.amount = 30
	dust.lifetime = 0.5
	dust.local_coords = false          # particulele rămân în lume, nu te urmăresc
	dust.direction = Vector2(-1, -0.5)
	dust.spread = 30.0
	dust.gravity = Vector2(0, 900)
	dust.initial_velocity_min = 120.0
	dust.initial_velocity_max = 320.0
	dust.scale_amount_min = 4.0
	dust.scale_amount_max = 10.0

	# Se estompează pe parcurs
	var g := Gradient.new()
	g.set_color(0, Color(0.9, 0.85, 0.75, 1.0))
	g.set_color(1, Color(0.9, 0.85, 0.75, 0.0))
	dust.color_ramp = g

	# Poziția: la picioare (baza coliziunii)
	var half_h = (col.shape as RectangleShape2D).size.y / 2.0
	dust.position = Vector2(col.position.x, col.position.y + half_h)
	add_child(dust)


# ---------- NOU: dâra de aer ----------
func _setup_air_trail() -> void:
	air_trail = CPUParticles2D.new()
	air_trail.emitting = false
	air_trail.amount = 24
	air_trail.lifetime = 0.35
	air_trail.local_coords = false          # particulele rămân în aer, în urma ta
	air_trail.spread = 12.0
	air_trail.gravity = Vector2.ZERO
	air_trail.initial_velocity_min = 20.0
	air_trail.initial_velocity_max = 60.0
	air_trail.scale_amount_min = 3.0
	air_trail.scale_amount_max = 7.0

	var g := Gradient.new()                 # alb care se estompează
	g.set_color(0, Color(1, 1, 1, 0.6))
	g.set_color(1, Color(1, 1, 1, 0.0))
	air_trail.color_ramp = g

	air_trail.position = col.position       # din centrul corpului
	add_child(air_trail)


# ---------- NOU: blast de particule la tragere ----------
func _setup_blast() -> void:
	blast = CPUParticles2D.new()
	blast.emitting = false
	blast.one_shot = true
	blast.explosiveness = 1.0
	blast.amount = 28
	blast.lifetime = 0.35
	blast.local_coords = false     # particulele rămân în lume
	blast.direction = Vector2(1, 0)
	blast.spread = 28.0
	blast.initial_velocity_min = 500.0
	blast.initial_velocity_max = 1100.0
	blast.damping_min = 600.0
	blast.damping_max = 900.0
	blast.scale_amount_min = 6.0
	blast.scale_amount_max = 14.0
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 0.9, 0.4, 1), Color(1, 0.4, 0.1, 0.8), Color(0.3, 0.1, 0.0, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	blast.color_ramp = g
	gun_pivot.add_child(blast)


func _fire_blast() -> void:
	var gun: Sprite2D = gun_pivot.get_node("Gun")
	var pos := MUZZLE_POS
	if gun.flip_v:
		pos.y = -pos.y             # oglindește când pistolul e întors
	blast.position = pos
	blast.restart()
	blast.emitting = true


# ---------- NOU: click stânga = tragi și ești aruncat invers ----------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_apply_recoil()


func _apply_recoil() -> void:
	if boosts_left <= 0:
		return
	boosts_left -= 1
	var aim := (get_global_mouse_position() - gun_pivot.global_position).normalized()
	velocity = -aim * RECOIL_FORCE
	recoil_timer = RECOIL_TIME
	is_slamming = false
	is_sliding = false
	fall_time = 0.0
	_fire_blast()


func _physics_process(delta: float) -> void:
	if is_on_floor():            # NOU: reîncarcă tragerea pe sol
		boosts_left = MAX_BOOSTS
	if recoil_timer > 0.0:       # NOU
		recoil_timer -= delta
	if bounce_timer > 0.0:
		bounce_timer -= delta

	var direction := Input.get_axis("left", "right")

	# Ctrl: pe sol = slide, în aer = slam
	if Input.is_action_just_pressed("crouch") and not is_slamming:
		if is_on_floor():
			_start_slide(direction)
		else:
			is_slamming = true
			is_sliding = false

	# Sfârșitul slide-ului
	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0.0 or not Input.is_action_pressed("crouch") or not is_on_floor():
			is_sliding = false

	# Gravitație
	if is_slamming:
		velocity.x = 0
		velocity.y = SLAM_SPEED
	elif not is_on_floor():
		var mult = GRAVITY_DOWN if velocity.y > 0 else GRAVITY_UP
		velocity += get_gravity() * mult * delta
		velocity.y = min(velocity.y, MAX_FALL_SPEED)

	# Moarte la cădere lungă
	if is_on_floor():
		fall_time = 0.0
	elif velocity.y > 0:
		fall_time += delta
		if fall_time >= MAX_FALL_TIME:
			die()
			return

	# Săritura (poți sări și din slide)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		is_sliding = false
		if bounce_timer > 0.0:
			velocity.y = JUMP_VELOCITY * SLAM_JUMP_BOOST
			bounce_timer = 0.0
		else:
			velocity.y = JUMP_VELOCITY
	if Input.is_action_just_released("jump") and velocity.y < 0 and not is_slamming and recoil_timer <= 0.0:
		velocity.y *= 0.6

	# Mișcare pe orizontală
	if is_slamming or recoil_timer > 0.0:   # NOU: în recoil nu suprascriem viteza
		pass
	elif is_sliding:
		var t = slide_timer / SLIDE_TIME            # 1 -> 0 pe parcurs
		velocity.x = slide_dir * lerp(SPEED, SLIDE_SPEED, t)
	else:
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED * 3.0)

	# Înclinarea imaginii (doar vizual, coliziunea nu se rotește)
	var target_tilt := 0.0
	if is_sliding:
		target_tilt = -slide_dir * deg_to_rad(SLIDE_TILT_DEG)
	sprite.rotation = lerp_angle(sprite.rotation, target_tilt, 14.0 * delta)

	# Particule doar cât timp te târăști pe sol
	dust.emitting = is_sliding and is_on_floor()

	# NOU: dâra de aer, doar în aer și când te miști destul de repede
	air_trail.emitting = not is_on_floor() and velocity.length() > 400.0
	if velocity.length() > 1.0:
		air_trail.direction = -velocity.normalized()   # dâra rămâne în urma mișcării

	move_and_slide()

	# Aterizare după slam
	if is_slamming and is_on_floor():
		is_slamming = false
		bounce_timer = SLAM_BOUNCE_WINDOW
		_slam_impact()


func _start_slide(direction: float) -> void:
	if direction != 0.0:
		slide_dir = direction
	else:
		slide_dir = -1.0 if sprite.flip_h else 1.0
	is_sliding = true
	slide_timer = SLIDE_TIME
	sprite.flip_h = slide_dir < 0
	dust.direction = Vector2(-slide_dir, -0.5)   # praful zboară în spatele tău


func _slam_impact() -> void:
	var tween = create_tween()
	for i in 6:
		tween.tween_property(cam, "offset", Vector2(randf_range(-14, 14), randf_range(-14, 14)), 0.03)
	tween.tween_property(cam, "offset", Vector2.ZERO, 0.03)


func die() -> void:
	get_tree().reload_current_scene.call_deferred()
