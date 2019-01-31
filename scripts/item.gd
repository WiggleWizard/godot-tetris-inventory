extends Node

class_name ItemBase

var _uid            = "";
var _name           = "Unnamed Item";
var _type           = "item";
var _inventory_size = Vector2(1, 1);
var _max_stack_size = 1;

var _texture     = null;
var _clip_offset = Vector2(0, 0);
var _clip_size   = Vector2(0, 0);


func get_uid():
	return _uid;
	
func get_name():
	return _name;
	
func get_type():
	return _type;
	
func get_size():
	return _inventory_size;
	
func get_max_stack_size():
	return _max_stack_size;
	
func set_max_stack_size(new_size):
	_max_stack_size = new_size;
	
func set_size(new_size):
	if(new_size.x < 1):
		printerr("Item invalid width, must be greater than 0");
		return false;
		
	if(new_size.y < 1):
		printerr("Item invalid height, must be greater than 0");
		return false;
		
	_inventory_size = new_size;
	
	return true;
	
func set_texture(new_texture):
	_texture = new_texture;
	
func set_clip_offset(new_clip_offset : Vector2):
	_clip_offset = new_clip_offset;
	
func set_clip_size(new_clip_size : Vector2):
	_clip_size = new_clip_size;
	
func fetch_inventory_display_data():
	return {
		"texture":     _texture,
		"clip_offset": _clip_offset,
		"clip_size":   _clip_size
	};