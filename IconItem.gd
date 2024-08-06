extends Node3D
class_name IconItem

var items: Array[Node3D]

func add_item(item: Node3D) -> void:
	items.append(item)

func remove_item(item:Node3D) -> void:
	var i: int = items.find(item)
	items.remove_at(i)
