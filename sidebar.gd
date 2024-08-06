@tool
extends VSplitContainer

var data: IconForgeData

signal on_save_icon_pressed(save_directory: String)
signal on_file_location_changed
signal on_image_size_changed
signal on_show_preview_changed(show: bool)
signal on_show_background_changed(show: bool)
signal on_background_scale_changed(scale: float)
signal on_background_image_selected(path: String)
signal on_background_color_changed(color: Color)
signal on_mask_file_changed
signal on_border_toggled(toggled: bool)
signal on_border_margin_changed(value: float)
signal prev_border_pressed
signal next_border_pressed
signal border_color_changed(color: Color)
signal light_type_changed()
signal on_ambient_energy_changed()

@export var default_bg_image: String

var snapshot_timer: Timer
var save_file_path: String = "user://save/"
var save_file_name: String = "IconForgeSave.tres"
var border_index: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	data = IconForgeData.data
	data.load_data()
	data.init_timer(self)
	data.save_timer = Timer.new()
	data.save_timer.wait_time = .25
	data.save_timer.one_shot = true
	data.save_timer.connect("timeout", data._on_save_timer_timeout)
	add_child(data.save_timer)

	var path = data.file_location
	if !path.ends_with("/"):
		path = path + "/"
	%FileLocation.text = path + "{image}.png"


	%ChangeDirectories.pressed.connect(%FileLocationDialog.show)
	%FileLocationDialog.dir_selected.connect(func(path: String):
		data.file_location = path
		if !path.ends_with("/"):
			path = path + "/"
		%FileLocation.text = path + "{image}.png"
		on_file_location_changed.emit()
	)

	%FileType.item_selected.connect(func(index: int):
		data.file_type = index
	)

	%FileType.selected = data.file_type

	%SaveAs.pressed.connect(func():
		if %FileNameEdit.text == "":
			printerr("FileName cannot be blank")
			return

		on_save_icon_pressed.emit(data.file_location + "/" + %FileNameEdit.text)
	)

	%SizeX.value = data.img_size.x
	%SizeX.value_changed.connect(_on_size_changed)
	%SizeY.value = data.img_size.y
	%SizeY.value_changed.connect(_on_size_changed)
	%SizeY.editable = !data.img_uniform

	%UniformToggle.toggled.connect(func(toggled: bool):
		data.img_uniform = !toggled
		%SizeY.editable = toggled

		if data.img_uniform:
			%SizeY.value = %SizeX.value
	)
	%UniformToggle.button_pressed = !data.img_uniform

	%ShowPreviewCheck.button_pressed = data.show_preview
	%ShowPreviewCheck.toggled.connect(func(toggled: bool):
		data.show_preview = toggled
		on_show_preview_changed.emit(toggled)
	)

	%BitmaskCheck.button_pressed = data.create_bitmask
	%BitmaskCheck.toggled.connect(func(checked: bool):
		data.create_bitmask = checked
	)

	%ShowBackgroundCheck.button_pressed = data.show_bg
	%ShowBackgroundCheck.toggled.connect(func(toggled: bool):
		data.show_bg = toggled
		on_show_background_changed.emit(toggled)
	)

	%BackgroundScale.value = data.bg_scale
	%BackgroundScale.value_changed.connect(func(value: float):
		data.bg_scale = value
		on_background_scale_changed.emit(value)
	)

	%ChangeBackgroundImage.pressed.connect(%BackgroundImageDialog.show)
	%BackgroundImageDialog.file_selected.connect(_on_background_image_selected)
	%ResetBackgroundImage.pressed.connect(func():
		data.bg_image = default_bg_image
		_on_background_image_selected(default_bg_image)
	)

	# Background image mask
	%ChangeBackgroundMask.pressed.connect(func():
		%MaskFileDialog.show()
	)
	%MaskFileDialog.file_selected.connect(func(path: String):
		data.mask_image = path
		on_mask_file_changed.emit()
	)
	%ResetBackgroundMask.pressed.connect(func():
		data.mask_image = default_bg_image
		on_mask_file_changed.emit()
	)

	# background color 
	%BgColorPicker.color = data.bg_color
	%BgColorPicker.color_changed.connect(func(color: Color):
		data.bg_color = color
		on_background_color_changed.emit(color)
	)
	%BgColorPicker.picker_created.connect(func():
		var p: ColorPicker = %BgColorPicker.get_picker()
		var colors: PackedColorArray = data.bg_color_presets
		for c in colors:
			p.add_preset(c)

		p.preset_removed.connect(func(color: Color):
			var i: int = data.bg_color_presets.find(color)
			data.bg_color_presets.remove_at(i)
			data.save()
		)
		p.preset_added.connect(func(color: Color):
			if data.bg_color_presets.append(color):
				data.save()
			else:
				printerr("Error setting background color presets")
		)
	)

	# Border
	%ShowBorderCheck.button_pressed = data.use_border
	%ShowBorderCheck.toggled.connect(func(toggled: bool):
		data.use_border = toggled
		on_border_toggled.emit(toggled)
	)

	%BorderMarginSpinbox.value = data.border_margin
	%BorderMarginSpinbox.value_changed.connect(func(value: float):
		data.border_margin = value
		on_border_margin_changed.emit(value)
	)

	%PrevBorder.pressed.connect(prev_border_pressed.emit)
	%NextBorder.pressed.connect(next_border_pressed.emit)

	%BorderColorPicker.color = data.border_color
	%BorderColorPicker.color_changed.connect(func(color: Color):
		data.border_color = color
		border_color_changed.emit(color)
	)
	%BorderColorPicker.picker_created.connect(_on_border_colorpicker_created)

	%AmbientLightButton.button_pressed = data.light_type == Enums.LightType.AMBIENT
	%OmniLightButton.button_pressed = data.light_type == Enums.LightType.OMNI
	%SpotLIghtButton.button_pressed = data.light_type == Enums.LightType.SPOT
	%DirectionalLightButton.button_pressed = data.light_type == Enums.LightType.DIRECTIONAL

	%AmbientLightButton.button_group.pressed.connect(_light_group_changed)

	# %AmbientEnergySlider.value = data.ambient_energy
	# %AmbientEnergySpinBox.value = %AmbientEnergySlider.value
	# %AmbientEnergySlider.value_changed.connect(func(new_value: float):
	# 	data.ambient_energy = new_value
	# 	%AmbientEnergySpinBox.set_value_no_signal(new_value)
	# 	on_ambient_energy_changed.emit()
	# )
	#
	# %AmbientEnergySpinBox.value_changed.connect(func(new_value: float):
	# 	data.ambient_energy = new_value
	# 	%AmbientEnergySlider.value = new_value
	# )
	# %AmbientEnergyReset.pressed.connect(func():
	# 	%AmbientEnergySlider.value = 1
	# )


func _on_size_changed(value: float) -> void:
	if data.img_uniform:
		data.img_size = Vector2(%SizeX.value, %SizeX.value)
		%SizeY.value = value
	else:
		data.img_size = Vector2(%SizeX.value, %SizeY.value)

	on_image_size_changed.emit()

func _on_background_image_selected(path: String) -> void:
	data.bg_image = path
	on_background_image_selected.emit(path)

func _on_border_margin_changed(value: float) -> void:
	data.border_margin = value
	on_border_margin_changed.emit(value)

func _on_border_colorpicker_created() -> void:
	var b: ColorPicker = %BorderColorPicker.get_picker()
	var border_colors: PackedColorArray = data.border_color_presets
	for c in border_colors:
		b.add_preset(c)

	b.preset_added.connect(func(color: Color):
		if data.border_color_presets.append(color):
			data.save()
		else:
			printerr("Error setting border color presets")
	)
	b.preset_removed.connect(func(color: Color):
		var i: int = data.border_color_presets.find(color)
		data.border_color_presets.remove_at(i)
		data.save()
	)

func _light_group_changed(button: BaseButton):
	if button == %AmbientLightButton:
		data.light_type = Enums.LightType.AMBIENT
	if button == %OmniLightButton:
		data.light_type = Enums.LightType.OMNI
	if button == %SpotLIghtButton:
		data.light_type = Enums.LightType.SPOT
	if button == %DirectionalLightButton:
		data.light_type = Enums.LightType.DIRECTIONAL
	light_type_changed.emit()
