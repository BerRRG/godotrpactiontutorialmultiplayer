extends CharacterBody2D

const PlayerHurtSound = preload("res://Player/scenes/PlayerHurtSound.tscn")

var clickPosition = Vector2()
var targetPosition = Vector2()

@export var ACCELERATION = 500
@export var MAX_SPEED = 80
@export var ROLL_SPEED = 120
@export var FRICTION = 500

enum {
	MOVE,
	ROLL,
	ATTACK,
	IDDLE
}

enum ANIMATIONS {
	MOVE,
	ROLL,
	ATTACK,
	IDDLE
}

@export var current_animation := ANIMATIONS.IDDLE
@export var syncPos = Vector2(0,0)

var state = MOVE
var roll_vector = Vector2.DOWN
var stats = PlayerStats

@onready var animationPlayer = $AnimationPlayer
@onready var animationTree = $AnimationTree
@onready var animationState = animationTree.get("parameters/playback")
@onready var swordHitbox = $HitboxPivot/SwordHitbox
@onready var hurtbox = $Hurtbox
@onready var blinkAnimationPlayer = $BlinkAnimationPlayer

func _ready():
	$MultiplayerSynchronizer.set_multiplayer_authority(str(name).to_int())
	randomize()
	stats.connect("no_health", Callable(self, "queue_free"))
	animationTree.active = true
	swordHitbox.knockback_vector = roll_vector

func _physics_process(delta):
	if $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id():
		current_animation = state
		match state:
			MOVE:
				move_state(delta)
			
			ROLL:
				roll_state()
			
			ATTACK:
				attack_state()
	else:
		global_position = global_position.lerp(syncPos, .2)
		animate(state, delta)

func animate(animation, delta):
	var animate = "Idle"
	if current_animation == ANIMATIONS.IDDLE:
		animate = "Idle"
	if current_animation == ANIMATIONS.MOVE:
		animate = "Run"
	if current_animation == ANIMATIONS.ROLL:
		animate = "Roll"
		velocity = roll_vector * ROLL_SPEED
	if current_animation == ANIMATIONS.ATTACK:
		animate = "Attack"
	animationState.travel(animate)

func move_state(delta):
	var input_vector = position
	syncPos = input_vector
	
	if Input.is_action_just_pressed("mouse_click"):
		clickPosition = get_global_mouse_position()

	if position.distance_to(clickPosition) > 3:
		input_vector = (clickPosition - position).normalized()
	
	if input_vector != position:
		roll_vector = input_vector
		swordHitbox.knockback_vector = input_vector
		animationTree.set("parameters/Idle/blend_position", input_vector)
		animationTree.set("parameters/Run/blend_position", input_vector)
		animationTree.set("parameters/Attack/blend_position", input_vector)
		animationTree.set("parameters/Roll/blend_position", input_vector)
		animationState.travel("Run")
		velocity = velocity.move_toward(input_vector * MAX_SPEED, ACCELERATION * delta)
	else:
		animationState.travel("Idle")
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	
	move()
	
	if Input.is_action_just_pressed("roll"):
		state = ROLL
	
	if Input.is_action_just_pressed("attack"):
		state = ATTACK

func roll_state():
	velocity = roll_vector * ROLL_SPEED
	animationState.travel("Roll")
	move()

func attack_state():
	velocity = Vector2.ZERO
	animationState.travel("Attack")

func move():
	set_velocity(velocity)
	move_and_slide()
	velocity = velocity

func roll_animation_finished():
	velocity = velocity * 0.8
	state = MOVE

func attack_animation_finished():
	state = MOVE

func _on_Hurtbox_area_entered(area):
	stats.health -= area.damage
	hurtbox.start_invincibility(0.6)
	hurtbox.create_hit_effect()
	var playerHurtSound = PlayerHurtSound.instantiate()
	get_tree().current_scene.add_child(playerHurtSound)
	
func _on_Hurtbox_invincibility_started():
	blinkAnimationPlayer.play("Start")

func _on_Hurtbox_invincibility_ended():
	blinkAnimationPlayer.play("Stop")
