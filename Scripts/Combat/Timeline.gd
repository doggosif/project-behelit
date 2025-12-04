extends Object
class_name Timeline

var _entries: Array = []
var _index: int = -1

func build(entries: Array) -> void:
	_entries = entries.duplicate()
	_entries.sort_custom(Callable(self, "_compare_by_speed"))
	_index = -1


func get_size() -> int:
	return _entries.size()


func next_entry() -> Dictionary:
	if _entries.is_empty():
		return {}
	_index = (_index + 1) % _entries.size()
	return _entries[_index] as Dictionary


func _compare_by_speed(a: Dictionary, b: Dictionary) -> bool:
	var sa: int = int(a.get("speed", 0))
	var sb: int = int(b.get("speed", 0))
	# Higher speed acts first
	return sa > sb
