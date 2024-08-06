@tool
class_name MouseInteract
extends Area2D

signal zoom_item_in
signal zoom_item_out
signal light_rotate(axis: Vector3, radians: float) 
signal move_item(translation: Vector3)

@export var move_sens: float = 0.005
@export var move_sens_low: float = 0.001

var move_slower: bool
var move_faster: bool

var prev_pos: Vector2 = Vector2()

func _ready() -> void:
	mouse_entered.connect(_mouse_entered)

func _process(_delta: float) -> void:
	# prev_pos = get_parent().get_mouse_position()
	pass


func _mouse_entered() -> void:
	move_item.emit(Vector3(1, 0, 0))

func _input(event: InputEvent) -> void:
	move_faster = Input.is_key_pressed(KEY_SHIFT)
	move_slower = Input.is_key_pressed(KEY_CTRL)

	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_item_in.emit()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_item_out.emit()

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) && event is InputEventMouseMotion:
		light_rotate.emit(Vector3.UP, -event.relative.x * .01)
		light_rotate.emit(Vector3.RIGHT, -event.relative.y * .01)

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) && event is InputEventMouseMotion:
		var sens := move_sens
		if move_slower:
			sens = move_sens_low
		# sens *= current_scale
		# var mouse_delta: Vector2 = prev_pos - get_parent().get_mouse_position()
		# var translation: Vector3 = Vector3(-mouse_delta.x * sens, mouse_delta.y * sens, 0)
		# move_item.emit(translation)
