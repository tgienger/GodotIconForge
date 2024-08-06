@tool
extends Control

signal texture_baked(image : Image)
signal item_changed
signal external_value_changed(new_value: float)

@export var camera: Camera3D
@export_group("Folder and file")
@export var file_dialog: FileDialog
@export var file_location_label: Label
@export var save_as_edit: TextEdit

@export_group("Loading")
@export var item_file_dialog: FileDialog

@export_group("Image")
@export var add_item: Button
# @export var img_spinbox: SpinBox
@export var zoom_step: float = .1
@export var bitmask_check: CheckButton
@export var scale_option: SpinBox
@export var show_preview_checkbox: CheckButton

@export_group("background")
@export var bg_toggle: CheckButton
@export var color_picker: ColorPickerButton
@export var bg_image_dialog: FileDialog

@export_group("Borders")
@export var border_checkbox: CheckButton
@export var margin_spinbox: SpinBox
@export var border_color_picker: ColorPickerButton
@export var borders: Array[CompressedTexture2D]

@export_group("Sensitivity")
@export var move_sens: float = 0.005
@export var move_sens_low: float = 0.001
@export var degree_spinbox: SpinBox
@export var movement_speed: float = 0.01

@onready var item_container: Node3D = %ItemContainer
@onready var directional_light: DirectionalLight3D = %SceneLight
@onready var spot_light: SpotLight3D = %Spotlight
@onready var omni_light: OmniLight3D = %OmniLight
@onready var omni_light_btn: MarginContainer = %OmniLightButton

@onready var border_canvas: CanvasLayer = %BorderCanvas
@onready var border_rect: NinePatchRect = %BorderRect
@onready var main_view: SubViewport = %MainView
@onready var preview: TextureRect = %Preview

## SpinBox for img preview size Y Value
@onready var size_y: SpinBox = %SizeY
## SpinBox for img preview size X Value
@onready var size_x: SpinBox = %SizeX
@onready var link_toggle: TextureButton = %UniformToggle
@onready var file_type_options: OptionButton = %FileType
@onready var context_menu: VBoxContainer = %ContextMenu
@onready var background: Sprite3D = %BackgroundImage
@onready var background_scale: HSlider = %BackgroundScale

var _delta: float
var snapshot_timer: Timer
var move_timer: Timer

var light_on: bool = true

# var current_lights: Array[Light3D]

var save_file_path: String = "user://save/"
var save_file_name: String = "IconCreateSave.tres"
var border_path: String = "res://addons/icon_creator/borders/"

var rotate_item_y: bool
var rotate_item_x: bool
var rotate_item_z: bool

var prev_pos: Vector2
var current_item: Node3D:
	set(new_item):
		if current_item:
			current_item.visible = false
		current_item = new_item
		if current_item:
			current_item.visible = true
			external_value_changed.emit(current_item.rotation_degrees.z)
		item_changed.emit()
		
	get():
		return current_item
		
var cur_index: int = -1

var border_index: int = -1

var save_data: IconForgeData

var move_slower: bool
var move_faster: bool
var zoom_scale_step: float = .01

var current_scale: float = 1
var file_save_name: String
var file_save_path: String

var move_left: bool
var move_right: bool
var move_up: bool
var move_down: bool
var move_pressed: bool
var move_light_pressed: bool
var move_light_hovered: bool

var move_repeat: bool

var light_ctx: Array[String] = [
	"Reset",
]

func _ready() -> void:
	snapshot_timer = Timer.new()
	snapshot_timer.wait_time = 0.05
	snapshot_timer.one_shot = true
	snapshot_timer.connect("timeout", _on_timer_timeout)
	add_child(snapshot_timer)

	move_timer = Timer.new()
	move_timer.wait_time = 0.5
	move_timer.one_shot = true
	move_timer.connect("timeout", _on_move_timer_timeout)
	add_child(move_timer)

	texture_baked.connect(_on_texture_baked)
	verify_save_dir(save_file_path)

	save_data = IconForgeData.data
	# if ResourceLoader.exists(save_file_path + save_file_name):
	# 	save_data = ResourceLoader.load(save_file_path + save_file_name, "IconCreatorData")

	var dir: DirAccess = DirAccess.open(border_path)
	if dir:
		dir.list_dir_begin()
		for path in dir.get_files():
			if !path.begins_with(".") && !path.ends_with(".import"):
				borders.append(load(border_path + "/" + path))

		dir.list_dir_end()

	bitmask_check.button_pressed = save_data.create_bitmask
	link_toggle.button_pressed = !save_data.img_uniform
	bg_toggle.button_pressed = save_data.show_bg
	file_type_options.selected = save_data.file_type

	background_scale.value = save_data.bg_scale
	_bg_scale_changed(save_data.bg_scale)

	_toggle_background()

	# img_spinbox.value = save_data.img_size.x
	size_x.value = save_data.img_size.x
	size_y.value = save_data.img_size.y

	file_location_label.text = save_data.file_location + "/{item_name}.png"

	color_picker.color = save_data.bg_color
	if !save_data.border_style:
		border_index = 0
		# save_data.border_style = borders[border_index]
	_set_use_border(save_data.use_border)

	_on_light_type_changed()

	show_preview_checkbox.button_pressed = save_data.show_preview
	_show_preview()

func verify_save_dir(file_path: String) -> void:
	DirAccess.make_dir_absolute(file_path)

func _next_item() -> bool:
	if item_container.get_child_count() == 0:
		return false

	if current_item:
		current_item.visible = false

	cur_index = cur_index + 1
	if cur_index >= item_container.get_children().size():
		cur_index = 0

	current_item = item_container.get_child(cur_index)
	if !current_item:
		push_error("No Object Found!")
		return false

	current_item.visible = true

	return true

func _prev_item() -> bool:
	if item_container.get_child_count() == 0:
		return false

	if current_item:
		current_item.visible = false

	cur_index = cur_index - 1
	if cur_index < 0:
		cur_index = item_container.get_children().size() - 1

	current_item = item_container.get_child(cur_index)
	if current_item:
		current_item.visible = true

	return true

func _process(delta: float) -> void:
	_delta = delta
	move_faster = Input.is_key_pressed(KEY_SHIFT)
	move_slower = Input.is_key_pressed(KEY_CTRL)

	zoom_scale_step = zoom_step * 5 if move_faster else zoom_step 
	if move_slower:
		zoom_scale_step = zoom_step * .1

	var mouse_delta: Vector2 = prev_pos - get_local_mouse_position()

	if current_item:
		# roate item on y axis dragging on button
		if rotate_item_y:
			var y_speed: float = 4.0 if move_faster else .1
			if move_slower:
				y_speed = .01
			current_item.rotate(Vector3.UP, -mouse_delta.x * y_speed)
			# current_item.rotate_object_local(Vector3.UP, -mouse_delta.x * y_speed)

		# rotate item on x axis dragging on button
		if rotate_item_x:
			# var x_speed: float = .01
			var x_speed: float= .04 if move_faster else .01
			if move_slower:
				x_speed = .001
			current_item.rotate(Vector3.RIGHT, -mouse_delta.y * x_speed)

		# rotate item on z axis dragging on button
		if rotate_item_z:
			var z_speed: float = 4.0 if move_faster else 1.0
			if move_slower:
				z_speed = .1
			var new_rotate: float = mouse_delta.x * z_speed * delta
			# print(mouse_click_position.distance_to(get_local_mouse_position()))
			current_item.rotate(-Vector3.FORWARD, new_rotate)
			external_value_changed.emit(-rad_to_deg(current_item.rotation.z))

		# move item with mouse
		if move_pressed:
			var move_speed: float = .01 if move_faster else .001
			if move_slower:
				move_speed = .0001
			current_item.global_translate(Vector3(-mouse_delta.x * move_speed, mouse_delta.y * move_speed, 0))

	if move_repeat:
		if move_left:
			_move_left_pressed()
		elif move_right:
			_move_right_pressed()
		elif move_up:
			_move_up_pressed()
		elif move_down:
			_move_down_pressed()
		else:
			move_repeat = false

	if move_light_pressed:
		_move_omni_light(Vector3(-mouse_delta.x * .01, mouse_delta.y * .01, 0))
		_rotate_light(Vector3.UP, -mouse_delta.x * .01)
		_rotate_light(Vector3.RIGHT, -mouse_delta.y * .01)

	prev_pos = get_local_mouse_position()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT && event.is_released():
			reset_context_menu()
			context_menu.show()

		if event.button_index == MOUSE_BUTTON_LEFT && event.is_released():
			if move_pressed:
				_move_released()
		if event.button_index == MOUSE_BUTTON_MIDDLE && event.is_pressed():
			if move_light_hovered:
				_reset_light_position()

func _reset_light_position():
	directional_light.rotation = Vector3.ZERO

	var new_pos := omni_light.position
	new_pos.x = 0
	new_pos.y = 0
	omni_light.position = new_pos

	spot_light.rotation = Vector3.ZERO

var anchor_point: Vector2
func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_item_in()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_item_out()

func _on_light_type_changed():
	match save_data.light_type:
		Enums.LightType.AMBIENT:
			%OmniLight.hide()
			%Spotlight.hide()
			%SceneLight.hide()
		Enums.LightType.OMNI:
			%OmniLight.show()
			%Spotlight.hide()
			%SceneLight.hide()
		Enums.LightType.SPOT:
			%OmniLight.hide()
			%Spotlight.show()
			%SceneLight.hide()
		Enums.LightType.DIRECTIONAL:
			%OmniLight.hide()
			%Spotlight.hide()
			%SceneLight.show()

func _on_ambient_energy_changed():
	print(save_data.ambient_energy)
	%WorldEnvironment.environment.background_energy_multiplier = save_data.ambient_energy

func _on_light_button_mouse_entered() -> void:
	move_light_hovered = true

func _on_light_button_mouse_exited() -> void:
	move_light_hovered = false

func _light_button_pressed() -> void:
	mouse_click_position = get_viewport().get_mouse_position()
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
	move_light_pressed = true

func _light_button_released() -> void:
	Input.warp_mouse(mouse_click_position)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	move_light_pressed = false

func _rotate_light(axis: Vector3, radians: float) -> void:
	if directional_light:
		directional_light.rotate(axis, -radians)
		spot_light.rotate(axis, -radians)
		axis = axis * radians

func _move_omni_light(translation: Vector3) -> void:
	if omni_light:
		omni_light.translate(translation)

func _mouse_move_item(translation: Vector3) -> void:
	if !current_item:
		return
	current_item.global_translate(translation)

func _show_preview() -> void:
	if save_data.show_preview:
		omni_light_btn.hide()
		main_view.size = save_data.img_size
		preview.show()
		preview.size = save_data.img_size
		return

	omni_light_btn.show()
	# else:
	# 	main_view.size = Vector2(512, 512)
		# preview.hide()

	# adjust main window ratio size
	if save_data.img_uniform:
		main_view.size = Vector2(512, 512)
	else:
		var new_size := Vector2(512, 512)
		var ratio: float = save_data.img_size.x / save_data.img_size.y
		if save_data.img_size.x > save_data.img_size.y:
			new_size = Vector2(512, 512 / ratio)
		else:
			new_size = Vector2(512 * ratio, 512)

		main_view.size = new_size

func zoom_item_in() -> void:
	var new_scale := Vector3(1 + zoom_scale_step, 1 + zoom_scale_step, 1 + zoom_scale_step)
	_zoom_item(new_scale)

func zoom_item_out() -> void:
	var new_scale := Vector3(1 - zoom_scale_step, 1 - zoom_scale_step, 1 - zoom_scale_step)
	_zoom_item(new_scale)

func _zoom_item(new_scale: Vector3) -> void:
	if !current_item:
		return

	current_item.transform = current_item.transform.scaled(new_scale)
	current_scale = current_item.scale.x
	scale_option.value = current_scale


func _on_texture_baked(img: Image) -> void:
	if !current_item:
		printerr("No item selected!")
		return
	_texture_baked(img, save_data.file_location + "/" + file_save_name)

func _texture_baked(img : Image, save_path: String) -> void:
	match save_data.file_type:
		0:
			img.save_png(save_path + ".png")
			print("saving png " + save_path + ".png")
		1:
			img.save_jpg(save_path + ".jpg")
			print("saving jpg " + save_path + ".jpg")
		2:
			img.save_webp(save_path + ".webp")
			print("saving webp " + save_path + ".webp")
		_:
			printerr("Invalid file type selected")

	if save_data.create_bitmask:
		var bitmask: BitMap = generate_mask(img)
		var bmsk: Image = bitmask.convert_to_image() 
		bmsk.save_jpg(file_save_path + "_m.jpg")

	_show_preview()

# func _on_save_as_pressed() -> void:
# 	file_save_name = save_as_edit.text
# 	if file_save_name == "":
# 		printerr("No save file name found")
# 		return
# 	_save()

func _on_save_icon_pressed(path: String) -> void:
	if path == "":
		printerr("Path cannot be empty")
		return

	main_view.size = save_data.img_size
	file_save_path = path
	snapshot_timer.start()

# snapshot
func _on_create_button_pressed() -> void:
	file_save_name = current_item.name
	_save()

func _save() -> void:
	main_view.size = save_data.img_size
	snapshot_timer.start()

func _on_move_timer_timeout() -> void:
	move_repeat = true

func _on_timer_timeout() -> void:
	var image := main_view.get_texture().get_image()
	if !current_item:
		printerr("No item selected!")
		return
	_texture_baked(image, file_save_path)

func _on_zoom_in_button_pressed() -> void:
	zoom_item_in()

func _on_zoom_out_pressed() -> void:
	zoom_item_out()

func _on_bg_toggled(toggle_on: bool) -> void:
	_toggle_background()

func _change_directories() -> void:
	file_dialog.show()

func _bg_color_changed(color: Color) -> void:
	# save_data.bg_color = color
	_toggle_background()

func _on_mask_file_changed() -> void:
	if save_data.mask_image.get_extension() == "":
		return

	var new_image := load(save_data.mask_image)
	background.material_override.set_shader_parameter("mask", new_image)
	# _on_bg_selected(save_data.bg_image)


# func _bg_picker_created() -> void:
# 	var p: ColorPicker = color_picker.get_picker()
	# p.preset_added.connect(_bg_preset_added)
	# p.preset_removed.connect(_bg_preset_removed)
	# var colors: PackedColorArray = save_data.bg_color_presets
	# for c in colors:
		# p.add_preset(c)

# func _bg_preset_added(color: Color) -> void:
# 	save_data.bg_color_presets.append(color)
#
# func _bg_preset_removed(color: Color) -> void:
# 	var i: int = save_data.bg_color_presets.find(color)
	
func rotate_right_down() -> void:
	rotate_item_y = true

func rotate_right_up() -> void:
	rotate_item_y = false

func rotate_x_down() -> void:
	rotate_item_x = true

func rotate_x_up() -> void:
	rotate_item_x = false

func rotate_z_down() -> void:
	mouse_click_position = get_local_mouse_position()
	rotate_item_z = true

func rotate_z_up() -> void:
	rotate_item_z = false

func _toggle_background() -> void:
	background.visible = save_data.show_bg
	background.material_override.set_shader_parameter("bg_color", save_data.bg_color)

func _bg_scale_changed(val: float) -> void:
	background.scale = Vector3(val, val, val)

func _change_background_image_pressed() -> void:
	bg_image_dialog.show()

func _reset_background_image_pressed() -> void:
	pass

func _set_use_border(use_border: bool) -> void:
	border_rect.visible = use_border
	border_rect.texture = save_data.border_style
	margin_spinbox.value = save_data.border_margin
	_set_border_margin(save_data.border_margin)
	border_color_picker.color = save_data.border_color
	_set_border_color(save_data.border_color)

func _set_border_margin(val: int) -> void:
	border_rect.patch_margin_top = val
	border_rect.patch_margin_left = val
	border_rect.patch_margin_bottom = val
	border_rect.patch_margin_right = val

# func _border_color_changed(color: Color) -> void:
# 	border_rect.material.set("shader_parameter/BorderColor", color)

func prev_border_clicked() -> void:
	border_index = border_index - 1
	if border_index < 0:
		border_index = borders.size() - 1

	save_data.border_style = borders[border_index]
	border_rect.texture = save_data.border_style

func next_border_clicked() -> void:
	border_index = border_index + 1
	if border_index > borders.size() - 1:
		border_index = 0

	save_data.border_style = borders[border_index]
	border_rect.texture = save_data.border_style

func _set_border_color(color: Color) -> void:
	border_rect.material.set("shader_parameter/BorderColor", color)

func border_margin_changed(val: float) -> void:
	# save_data.border_margin = int(val)
	_set_border_margin(int(val))

func _show_preview_checked(show_preview: bool) -> void:
	# save_data.show_preview = show_preview
	_show_preview()

func _rotate_pressed() -> void:
	if !current_item:
		return
	current_item.rotate(Vector3.FORWARD, deg_to_rad(degree_spinbox.value))

var mouse_click_position: Vector2
func _move_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
	mouse_click_position = get_viewport().get_mouse_position()
	move_pressed = true	

func _move_released() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.warp_mouse(mouse_click_position)
	move_pressed = false

func _move_right_pressed() -> void:
	if !current_item:
		return
	var translation: Vector3 = Vector3(movement_speed, 0, 0)
	current_item.global_translate(translation)

func _move_right_down() -> void:
	move_right = true
	move_timer.start()

func _move_right_up() -> void:
	move_right = false

func _move_left_pressed() -> void:
	if !current_item:
		return
	var translation: Vector3 = Vector3(-movement_speed, 0, 0)
	current_item.global_translate(translation)

func _move_left_down() -> void:
	move_left = true
	move_timer.start()

func _move_left_up() -> void:
	move_left = false

func _move_up_pressed() -> void:
	if !current_item:
		return
	var translation: Vector3 = Vector3(0, movement_speed, 0)
	current_item.global_translate(translation)

func _move_up_down() -> void:
	move_up = true
	move_timer.start()

func _move_up_up() -> void:
	move_up = false

func _move_down_pressed() -> void:
	if !current_item:
		return
	var translation: Vector3 = Vector3(0, -movement_speed, 0)
	current_item.global_translate(translation)

func _move_down_down() -> void:
	move_down = true
	move_timer.start()

func _move_down_up() -> void:
	move_down = false

func _center_pressed() -> void:
	_center_object_to_camera()

func _scale_option_selected(new_scale: float) -> void:
	if !current_item:
		return

	current_item.scale = Vector3(new_scale, new_scale, new_scale)
	current_scale = current_item.scale.x

func _compute_aabb(n : Node3D) -> AABB:
	var aabb: AABB = AABB()
	if n is VisualInstance3D:
		aabb = n.get_aabb()
	for child in n.get_children():
		if child is Node3D:
			var child_aabb: AABB = _compute_aabb(child)
			aabb = aabb.merge(child_aabb)
	return aabb

func _center_object_to_camera() -> void:
	if !current_item:
		return

	var aabb: AABB = _compute_aabb(current_item) # _calculate_spatial_bounds(current_item, true)
	var ofs: Vector3 = aabb.get_center()

	var xform := Transform3D()
	var m_aabb: AABB = xform * aabb

	var m: float = max(m_aabb.size.x, m_aabb.size.y)
	m = max(m, m_aabb.size.z)

	if m == 0:
		return

	m = 1.0 / (0.5 * m)
	m *= 0.5
	xform.basis = xform.basis.scaled(Vector3(m, m, m))
	
	# Center the object
	xform.origin = -(xform.basis * ofs)
	xform.origin.z = -2 # -= (m_aabb.size.z-ofs.z)  * 8.0
	current_item.global_transform = xform
	if current_item is  ImageContainer:
		current_item.scale = Vector3(1, 1, 1)
	current_scale = current_item.scale.x
	scale_option.value = current_scale

	degree_spinbox.value = 0
	external_value_changed.emit(0)

func _on_degree_spinbox_changed(deg: float) -> void:
	if !current_item:
		# degree_spinbox.value = 0
		return

	# if deg > 360:
	# 	deg = 0
	# 	degree_spinbox.value = 0
	# elif deg < 0:
	# 	deg = 360
	# 	degree_spinbox.value = 360
	current_item.rotation_degrees = Vector3(0, 0, deg)

func _on_load_items_clicked() -> void:
	item_file_dialog.show()

func _on_bg_selected(path: String) -> void:
	if path.get_extension() == "":
		return

	var new_image := load(path)
	background.material_override.set_shader_parameter("image", new_image)

func _on_remove_item_clicked() -> void:
	for i in item_container.get_children().size():
		var item := item_container.get_child(i)
		if item == current_item:
			item_container.remove_child(item)
			item.queue_free()
			current_item = null
			_prev_item()
			return

func _on_items_loaded(items: PackedStringArray) -> void:
	for path in items:
		if path.get_extension() == "":
			return
		var new_item := load(path)
		var item: Node3D
		if new_item is ArrayMesh:
			item = MeshInstance3D.new()
			item.mesh = new_item
		elif new_item is Texture2D:
			item = ImageContainer.new_image(new_item)
		else:
			item = new_item.instantiate()

		item_container.add_child(item)
		item.visible = false

		# if current_item:
		# 	current_item.visible = false

		current_item = item
		# current_item.visible = true
		_center_object_to_camera()

func _on_add_item_clicked() -> void:
	printerr("'add item' is not yet implemented")

func _on_add_item(path: String) -> void:
	if path.get_extension() == "":
		return
	var new_item := load(path)
	var item: Node3D
	if new_item is ArrayMesh:
		item = MeshInstance3D.new()
		item.mesh = new_item
	elif new_item is Texture2D:
		item = ImageContainer.new_image(new_item)
	else:
		item = new_item.instantiate()

	item_container.add_child(item)
	item.visible = false

	current_item = item
	_center_object_to_camera()

		
func generate_mask(image: Image) -> BitMap:
	var bitmap: BitMap = BitMap.new()
	bitmap.create_from_image_alpha(image)
	return bitmap

func reset_context_menu():
	for child in context_menu.get_children():
		child.hide()
		child.queue_free()

	if move_light_hovered:
		for name in light_ctx:
			var btn := Button.new()
			btn.text = name
			btn.pressed.connect(func new():
				_reset_light_position()
				context_menu.hide()
			)
			context_menu.add_child(btn)


	if context_menu.get_child_count() > 0:
		context_menu.position = get_local_mouse_position() + Vector2(5,0)
		context_menu.show()


func _on_sidebar_on_background_image_selected(path:String) -> void:
	pass # Replace with function body.

