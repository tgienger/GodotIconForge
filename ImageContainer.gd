extends Node3D
class_name ImageContainer

# const my_scene: PackedScene = preload("res://addons/icon_creator/ImageContainer.tscn")
var vp: SubViewport
var sprite3D: Sprite3D
var sprite2D: Sprite2D

func pixel_perfect(val: bool) -> void:
	if val:
		sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

static func new_image(texture: Texture2D) -> ImageContainer:
	# var n: ImageContainer = my_scene.instantiate()
	var n: ImageContainer = ImageContainer.new()
	n.sprite2D = Sprite2D.new()
	n.sprite2D.texture = texture
	n.sprite3D = Sprite3D.new()
	n.add_child(n.sprite3D)
	n.vp = SubViewport.new()
	n.vp.transparent_bg = true
	n.vp.add_child(n.sprite2D)
	n.sprite2D.position = n.vp.size / 2
	n.add_child(n.vp)
	n.sprite3D.texture = n.vp.get_texture()

	return n

