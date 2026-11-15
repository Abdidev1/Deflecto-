extends CanvasLayer

const MENU_SCENE := "res://main_menu.tscn"
const SAVE_PATH := "user://highscores.cfg" 

@export var max_health := 100
@export var bounce_damage := 5       
@export var hit_cooldown := 0.25    
@export var score_per_pixel := 0.01  

@onready var boat: CharacterBody2D = get_parent().get_node("Boat")
@onready var health_bar: ProgressBar = $HealthBar
@onready var health_text: Label = $HealthBar/HealthText
@onready var time_label: Label = $TopInfo/TimeLabel
@onready var score_label: Label = $TopInfo/ScoreLabel
@onready var game_over: Control = $GameOver
@onready var time_result: Label = $GameOver/Box/TimeResult
@onready var score_result: Label = $GameOver/Box/ScoreResult
@onready var bounces_result: Label = $GameOver/Box/BouncesResult
@onready var best_result: Label = $GameOver/Box/BestResult
@onready var try_again_button: Button = $GameOver/Box/TryAgainButton
@onready var menu_button: Button = $GameOver/Box/MenuButton

var health := 100
var time_alive := 0.0
var bounces := 0
var start_y := 0.0
var furthest_y := 0.0
var last_hit_time := -10.0
var is_over := false
var best_score := 0
var best_time := 0.0

func _ready() -> void:
	health = max_health
	health_bar.max_value = max_health
	health_bar.value = health
	_update_health_text()
	start_y = boat.position.y
	furthest_y = start_y
	game_over.visible = false
	_load_best()
	boat.bounced.connect(_on_boat_bounced)
	try_again_button.pressed.connect(_on_try_again_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

func _process(delta: float) -> void:
	if is_over:
		return
	time_alive += delta
	furthest_y = max(furthest_y, boat.position.y)
	time_label.text = "Time: " + _format_time(time_alive)
	score_label.text = "Score: " + str(_get_score())

func _get_score() -> int:
	return int((furthest_y - start_y) * score_per_pixel)

func _format_time(t: float) -> String:
	var minutes := floori(t / 60.0)
	var seconds := int(t) % 60
	return "%02d:%02d" % [minutes, seconds]

func _on_boat_bounced(_strength: float) -> void:
	if is_over:
		return
	if time_alive - last_hit_time < hit_cooldown:
		return
	last_hit_time = time_alive
	bounces += 1
	health = max(0, health - bounce_damage)
	health_bar.value = health
	_update_health_text()
	if health <= 0:
		_end_game()

func _update_health_text() -> void:
	health_text.text = "Health: " + str(health) + " / " + str(max_health)

func _end_game() -> void:
	is_over = true
	boat.set_physics_process(false)  
	var score := _get_score()

	
	var new_record := false
	if score > best_score:
		best_score = score
		new_record = true
	if time_alive > best_time:
		best_time = time_alive
		new_record = true
	if new_record:
		_save_best()

	time_result.text = "Time survived: " + _format_time(time_alive)
	score_result.text = "Score: " + str(score)
	bounces_result.text = "Bounces: " + str(bounces)
	best_result.text = "Best time: " + _format_time(best_time) + "   Best score: " + str(best_score)
	if new_record:
		best_result.text = "NEW RECORD!   " + best_result.text
	game_over.visible = true
	try_again_button.grab_focus()

func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_score = int(cfg.get_value("normal", "best_score", 0))
		best_time = float(cfg.get_value("normal", "best_time", 0.0))

func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  
	cfg.set_value("normal", "best_score", best_score)
	cfg.set_value("normal", "best_time", best_time)
	cfg.save(SAVE_PATH)

func _on_try_again_pressed() -> void:
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
