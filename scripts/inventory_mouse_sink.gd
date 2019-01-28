extends Control

# Forward to parent
func get_drag_data(position):
	return get_parent().get_drag_data(position);
	
func can_drop_data(position, data):
	return get_parent().can_drop_data(position, data);
	
func drop_data(position, data):
	return get_parent().drop_data(position, data);