@tool
extends Resource
class_name IconForgeData

signal file_location_changed(directory: String)
## The location where the newly created icon will be saved
@export var file_location: String = "res://":
	set(new_location):
		file_location = new_location
		file_location_changed.emit(new_location)
		save()

signal file_type_changed(type: int)
## The chosen file type for the image (png, jpg, webp)
@export var file_type: int = 0:
	set(new_type):
		file_type = new_type
		file_type_changed.emit(new_type)
		save()

signal show_bg_toggled(toggled: bool)
## Toggle the background
@export var show_bg: bool = false:
	set(show):
		show_bg = show
		show_bg_toggled.emit(show)
		save()


signal bg_color_changed(color: Color)
## Change the color of the background
@export var bg_color: Color = Color.TURQUOISE:
	set(color):
		bg_color = color
		bg_color_changed.emit(color)
		save()

@export var bg_color_presets: PackedColorArray:
	set(new_color):
		bg_color_presets = new_color
		save()

signal bg_scale_changed
## Change the scale of the background image
@export var bg_scale: float = 1.0:
	set(new_scale):
		bg_scale = new_scale
		bg_scale_changed.emit()
		save()

## set the background image
@export var bg_image: String:
	set(path):
		bg_image = path
		save()

@export var use_mask: bool:
	set(use):
		use_mask = use
		save()

@export var mask_image: String:
	set(path):
		mask_image = path
		save()

signal use_border_changed(use: bool)
## Show or hide a border around the icon
@export var use_border: bool = false:
	set(use):
		use_border = use
		use_border_changed.emit(use)
		save()

signal border_style_changed
@export var border_style: Texture2D:
	set(style):
		border_style = style
		border_style_changed.emit()
		save()

signal border_margin_changed
@export var border_margin: int = 20:
	set(margin):
		border_margin = margin
		border_margin_changed.emit()
		save()

signal border_color_changed
@export var border_color: Color = Color.WHITE:
	set(color):
		border_color = color
		border_color_changed.emit()
		save()

@export var border_color_presets: PackedColorArray:
	set(new_color):
		border_color_presets = new_color
		save()

signal image_size_changed
@export var img_size: Vector2 = Vector2(512, 512):
	set(size):
		img_size = size
		image_size_changed.emit()
		save()

signal image_uniform_changed
@export var img_uniform: bool:
	set(uni):
		img_uniform = uni
		image_uniform_changed.emit()
		save()

signal show_preview_changed
@export var show_preview: bool = false:
	set(show):
		show_preview = show
		show_preview_changed.emit()
		save()

signal create_bitmask_changed
@export var create_bitmask: bool = false:
	set(create):
		create_bitmask = create
		create_bitmask_changed.emit()
		save()

@export var light_type: Enums.LightType:
	set(light):
		light_type = light
		save()

@export var ambient_energy: float = 1.0:
	set(val):
		ambient_energy = val
		save()

var save_file_path: String = "user://save/"
var save_file_name: String = "IconForgeSave.tres"

var save_timer: Timer

static var _data: IconForgeData
static var data: IconForgeData:
	get():
		if _data == null:
			_data = IconForgeData.new()
			_data.load_data()
		return _data

func _init() -> void:
	verify_save_dir()

func init_timer(node: Node) -> void:
	save_timer = Timer.new()
	save_timer.wait_time = .25
	save_timer.one_shot = true
	save_timer.connect("timeout", _on_save_timer_timeout)
	node.add_child(save_timer)

func save() -> void:
	if save_timer == null || save_timer.time_left > 0:
		return

	save_timer.start()

func load_data():
	if ResourceLoader.exists(save_file_path + save_file_name):
		var path: String = save_file_path + save_file_name
		_data = ResourceLoader.load(path, "IconForgeData")

func verify_save_dir() -> void:
	DirAccess.make_dir_absolute(save_file_path)

func _on_save_timer_timeout() -> void:
	ResourceSaver.save(data, save_file_path + save_file_name)
