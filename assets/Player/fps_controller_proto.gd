extends CharacterBody3D

# --- Paramètres exposés dans l'inspecteur ---
@export var speed: float = 5.0             # Vitesse de déplacement normale
@export var sprint_speed: float = 8.0      # Vitesse de déplacement en sprint
@export var jump_speed: float = 5.0        # Force du saut
@export var mouse_sensitivity: float = 0.002 # Sensibilité de la souris
@export var max_step_height: float = 0.1   # Hauteur maximale des marches franchissables
@export var accel: float = 20.0            # Accélération / décélération

# --- Références aux noeuds enfants ---
@onready var _camera: Camera3D = $Head/Camera3D
@onready var anim_player = $AnimationPlayer
@onready var player_melee_hitbox = $Head/Camera3D/WeaponPivot/Basic_Mace_Model/HitBox

# Gravité récupérée depuis les paramètres du projet
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- Bob (oscillation de la caméra en marchant) ---
var _bob_time: float = 0.0         # Accumulateur de temps pour le sinus
var _bob_amplitude: float = 0.015  # Amplitude verticale du bob
var _bob_frequency: float = 8.0    # Fréquence du bob
var _camera_base_y: float = 0.0    # Position Y de référence de la caméra

# --- Impact à l'atterrissage ---
var _was_on_floor: bool = true      # État sol du frame précédent
var _landing_offset: float = 0.0   # Décalage vertical appliqué à l'atterrissage
var _velocity_y_before: float = 0.0 # Vélocité Y du frame précédent (pour calculer l'impact)

# --- Inclinaison latérale (strafe) ---
var _tilt_amount: float = deg_to_rad(3.0) # Angle d'inclinaison en radians

# --- Champ de vision ---
var _base_fov: float = 75.0    # FOV par défaut
var _sprint_fov: float = 85.0  # FOV élargi en sprint


func _ready() -> void:
	# Capture la souris pour le mode FPS
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Paramètres du CharacterBody3D pour la gestion des pentes et marches
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50)
	# Mémorisation de la position Y initiale de la caméra
	_camera_base_y = _camera.position.y
	_base_fov = _camera.fov
	# Lance l'animation idle au démarrage en boucle
	anim_player.play("idle")
	anim_player.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
	# Connecte le signal de fin d'animation
	anim_player.animation_finished.connect(_on_animation_finished)


# Appelé automatiquement à la fin de chaque animation
func _on_animation_finished(anim_name: String) -> void:
	# Retour à idle une fois l'attaque terminée
	if anim_name == "attack":
		anim_player.play("idle")
		player_melee_hitbox.monitoring = false

func _input(event: InputEvent) -> void:
	# Rotation de la caméra à la souris (mode capturé uniquement)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_camera.rotate_x(-event.relative.y * mouse_sensitivity)
		# Clamp pour éviter de retourner la caméra
		_camera.rotation.x = clampf(_camera.rotation.x, deg_to_rad(-70), deg_to_rad(70))

	# Clic gauche : déclenche l'animation d'attaque si elle n'est pas déjà en cours
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if anim_player.current_animation != "attack":
			anim_player.play("attack")
			player_melee_hitbox.monitoring = true


func _physics_process(delta: float) -> void:
	# --- Détection de l'atterrissage ---
	# Vrai uniquement le frame où le joueur touche le sol
	var just_landed: bool = not _was_on_floor and is_on_floor()
	if just_landed:
		# Calcule un décalage négatif proportionnel à la vitesse de chute
		_landing_offset = clampf(_velocity_y_before * 0.04, -0.12, 0.0)
	_was_on_floor = is_on_floor()
	_velocity_y_before = velocity.y

	# --- Gravité ---
	velocity.y -= gravity * delta

	# --- Lecture des entrées clavier (ZQSD + WASD) ---
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_W):
		input.y -= 1  # Avancer
	if Input.is_key_pressed(KEY_S):
		input.y += 1  # Reculer
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A):
		input.x -= 1  # Gauche
	if Input.is_key_pressed(KEY_D):
		input.x += 1  # Droite

	# --- Sprint (Shift + avancer uniquement) ---
	var is_sprinting: bool = Input.is_key_pressed(KEY_SHIFT) and input.y < 0
	var target_speed: float = sprint_speed if is_sprinting else speed

	# Convertit l'input 2D en direction 3D relative à l'orientation du joueur
	var direction = (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	if direction:
		# Accélération vers la vitesse cible
		velocity.x = move_toward(velocity.x, direction.x * target_speed, accel * delta)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, accel * delta)
	else:
		# Décélération jusqu'à l'arrêt
		velocity.x = move_toward(velocity.x, 0, accel * delta)
		velocity.z = move_toward(velocity.z, 0, accel * delta)

	# --- Saut ---
	if is_on_floor() and Input.is_key_pressed(KEY_SPACE):
		velocity.y = jump_speed

	_handle_step(delta)   # Gestion des marches
	move_and_slide()      # Application du mouvement avec détection de collision
	_update_camera(delta, input, is_sprinting)  # Effets caméra


func _update_camera(delta: float, input: Vector2, is_sprinting: bool) -> void:
	var horizontal_speed: float = Vector3(velocity.x, 0, velocity.z).length()
	# Le bob ne s'active que si le joueur se déplace au sol
	var is_moving: bool = horizontal_speed > 0.5 and is_on_floor()

	# --- Bob ---
	if is_moving:
		# Fréquence légèrement accélérée en sprint
		var freq: float = _bob_frequency * (1.3 if is_sprinting else 1.0)
		_bob_time += delta * freq
	else:
		# Retour progressif à zéro pour éviter un saut brusque
		_bob_time = move_toward(_bob_time, 0.0, delta * 5.0)

	var bob_y: float = sin(_bob_time) * _bob_amplitude * (1.0 if is_moving else 0.0)

	# --- Impact atterrissage : retour progressif à 0 ---
	_landing_offset = move_toward(_landing_offset, 0.0, delta * 6.0)

	# --- Position Y de la caméra : base + bob + impact ---
	_camera.position.y = _camera_base_y + bob_y + _landing_offset

	# --- Inclinaison latérale selon le strafe ---
	var target_tilt: float = -input.x * _tilt_amount
	_camera.rotation.z = lerp(_camera.rotation.z, target_tilt, delta * 8.0)

	# --- FOV dynamique : s'élargit en sprint ---
	var target_fov: float = _sprint_fov if is_sprinting else _base_fov
	_camera.fov = lerp(float(_camera.fov), target_fov, delta * 6.0)


func _handle_step(delta: float) -> void:
	# Pas de gestion des marches en l'air
	if not is_on_floor():
		return
	var horizontal_vel := Vector3(velocity.x, 0, velocity.z)
	# Rien à faire si le joueur est immobile
	if horizontal_vel.is_zero_approx():
		return

	# Test de collision physique en avançant légèrement au-dessus du sol
	var params := PhysicsTestMotionParameters3D.new()
	var result := PhysicsTestMotionResult3D.new()
	# Point de départ : position future du joueur, surélevée de max_step_height * 2
	var from := Transform3D(
		global_transform.basis,
		global_position + Vector3(0, max_step_height * 2, 0) + horizontal_vel * delta
	)
	params.from = from
	params.motion = Vector3(0, -max_step_height * 2, 0)  # Rayon vers le bas

	if PhysicsServer3D.body_test_motion(get_rid(), params, result):
		var step_up := result.get_collision_point().y - global_position.y
		# Franchit la marche uniquement si elle est dans la plage autorisée
		if step_up > 0.01 and step_up <= max_step_height:
			global_position.y += step_up

func _on_hitbox_area_entered(area: Area3D) -> void:
	if area.is_in_group("enemy"):
		print("enemy touched !")
