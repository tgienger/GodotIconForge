extends Resource
class_name IconCreatorData

@export var file_location: String = "res://"
@export var file_type: int = 0
@export var show_bg: bool = false
@export var bg_color: Color = Color.TURQUOISE
@export var bg_color_presets: PackedColorArray
@export var bg_scale: float = 1.0
@export var use_border: bool = false
@export var border_style: Texture2D
@export var border_margin: int = 20
@export var border_color: Color = Color.WHITE
@export var img_size: Vector2 = Vector2(512, 512)
@export var img_uniform: bool
@export var show_preview: bool = false
@export var create_bitmask: bool = false

var save_file_path: String = "user://save/"
var save_file_name: String = "IconCreateSave.tres"

var _data: IconCreatorData

var data:
	get():
		if !_data:
			_data = IconCreatorData.new()
			_data.load()
		return _data

func save():
	verify_save_dir()
	ResourceSaver.save(data, save_file_path + save_file_name)

func load():
	if ResourceLoader.exists(save_file_path + save_file_name):
		data = ResourceLoader.load(save_file_path + save_file_name, "IconCreatorData")

func verify_save_dir() -> void:
	DirAccess.make_dir_absolute(save_file_path)
