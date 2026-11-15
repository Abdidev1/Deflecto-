extends CanvasLayer


const MENU_SCENE := "res://main_menu.tscn"
const SAVE_PATH := "user://highscores.cfg"  

@export var time_limit := 180.0        
@export var max_health := 100
@export var bounce_damage := 5          
@export var hit_cooldown := 0.25        
@export var score_per_pixel := 0.03   
@export var win_bonus_per_second := 10  
@export var win_bonus_per_health := 5   
@export var pixels_per_meter := 10.0   
@export var fallback_length := 30000.0  
@onready var boat: CharacterBody2D = get_parent().get_node("Boat")
@onready var health_bar: ProgressBar = $HealthBar
@onready var health_text: Label = $HealthBar/HealthText
@onready var time_label: Label = $TopInfo/TimeLabel
@onready var score_label: Label = $TopInfo/ScoreLabel
@onready var distance_label: Label = $TopInfo/DistanceLabel
@onready var finish_bar: ProgressBar = $TopInfo/FinishBar
@onready var game_over: Control = $GameOver
@onready var title_label: Label = $GameOver/Box/TitleLabel
@onready var time_result: Label = $GameOver/Box/TimeResult
@onready var score_result: Label = $GameOver/Box/ScoreResult
@onready var bounces_result: Label = $GameOver/Box/BouncesResult
@onready var best_result: Label = $GameOver/Box/BestResult
@onready var try_again_button: Button = $GameOver/Box/TryAgainButton
@onready var menu_button: Button = $GameOver/Box/MenuButton

var health := 100
var time_left := 180.0
var elapsed := 0.0
var bounces := 0
var start_y := 0.0
var furthest_y := 0.0
var finish_y := 0.0
var level_length := 0.0
var last_hit_time := -10.0
var is_over := false
var best_score := 0
var best_time := 0.0 

func _ready() -> void:
	health = max_health
	health_bar.max_value = max_health
	health_bar.value = health
	_update_health_text()
	time_left = time_limit


	start_y = boat.position.y
	furthest_y = start_y
	var length = get_parent().get("level_length")
	level_length = float(length) if length != null else 0.0
	if level_length <= 0.0:
		level_length = fallback_length
	finish_y = start_y + level_length

	finish_bar.min_value = 0.0
	finish_bar.max_value = level_length
	finish_bar.value = 0.0
	finish_bar.show_percentage = false

	game_over.visible = false
	_load_best()
	_create_finish_line()
	boat.bounced.connect(_on_boat_bounced)
	try_again_button.pressed.connect(_on_try_again_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

func _create_finish_line() -> void:

	var line := ColorRect.new()
	line.color = Color(1.0, 0.9, 0.2)
	line.size = Vector2(1400.0, 24.0)
	line.position = Vector2(-700.0, finish_y)
	line.z_index = -5
	var text := Label.new()
	text.text = "FINISH"
	text.add_theme_font_size_override("font_size", 48)
	text.position = Vector2(580.0, 30.0)
	line.add_child(text)
	get_parent().add_child.call_deferred(line)

func _process(delta: float) -> void:
	if is_over:
		return
	elapsed += delta
	time_left -= delta
	furthest_y = max(furthest_y, boat.position.y)


	if boat.position.y >= finish_y:
		_end_game(true, "")
		return

	if time_left <= 0.0:
		time_left = 0.0
		_end_game(false, "OUT OF TIME!")
		return

	time_label.text = "Time left: " + _format_time(ceil(time_left))
	if time_left <= 30.0:
		time_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	score_label.text = "Score: " + str(_get_score())

	var traveled := clampf(boat.position.y - start_y, 0.0, level_length)
	finish_bar.value = traveled
	var meters_left := int((level_length - traveled) / pixels_per_meter)
	distance_label.text = "Distance to finish: " + str(meters_left) + " m"

func _get_score() -> int:
	return int((furthest_y - start_y) * score_per_pixel)

func _format_time(t: float) -> String:
	var minutes := floori(t / 60.0)
	var seconds := int(t) % 60
	return "%02d:%02d" % [minutes, seconds]

func _update_health_text() -> void:
	health_text.text = "Health: " + str(health) + " / " + str(max_health)

func _on_boat_bounced(_strength: float) -> void:
	if is_over:
		return

	if elapsed - last_hit_time < hit_cooldown:
		return
	last_hit_time = elapsed
	bounces += 1
	health = max(0, health - bounce_damage)
	health_bar.value = health
	_update_health_text()
	if health <= 0:
		_end_game(false, "OUT OF HEALTH!")

func _end_game(won: bool, reason: String) -> void:
	is_over = true
	boat.set_physics_process(false)  
	var time_used := time_limit - time_left
	var score := _get_score()
	if won:
		score += int(time_left) * win_bonus_per_second + health * win_bonus_per_health

	
	var new_record := false
	if score > best_score:
		best_score = score
		new_record = true
	if won and (best_time <= 0.0 or time_used < best_time):
		best_time = time_used
		new_record = true
	if new_record:
		_save_best()

	if won:
		title_label.text = "YOU WON!"
		time_result.text = "Time taken: " + _format_time(time_used)
	else:
		title_label.text = reason
		var meters_left := int(maxf(0.0, finish_y - boat.position.y) / pixels_per_meter)
		time_result.text = "Distance left: " + str(meters_left) + " m"
	score_result.text = "Score: " + str(score)
	bounces_result.text = "Bounces: " + str(bounces)

	var best_time_text := "--:--"
	if best_time > 0.0:
		best_time_text = _format_time(best_time)
	best_result.text = "Fastest win: " + best_time_text + "   Best score: " + str(best_score)
	if new_record:
		best_result.text = "NEW RECORD!   " + best_result.text

	game_over.visible = true
	try_again_button.grab_focus()

func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_score = int(cfg.get_value("hard", "best_score", 0))
		best_time = float(cfg.get_value("hard", "best_time", 0.0))

func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  
	cfg.set_value("hard", "best_score", best_score)
	cfg.set_value("hard", "best_time", best_time)
	cfg.save(SAVE_PATH)

func _on_try_again_pressed() -> void:
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
