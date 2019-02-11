extends Node

class_name ItemBase

var _uid            = "";
var _name           = "Unnamed Item";
var _type           = "item";
var _inventory_size = Vector2(1, 1);
var _max_stack_size = 1;

var _texture           = null;
var _clip_pixel_offset = Vector2(0, 0);
var _clip_pixel_size   = Vector2(0, 0);


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
	
func get_texture():
	return _texture;
	
func set_texture(new_texture):
	_texture = new_texture;

func get_clip_pixel_offset():
	return _clip_pixel_offset;
	
func set_clip_pixel_offset(new_clip_pixel_offset):
	_clip_pixel_offset = new_clip_pixel_offset;
	
func get_clip_pixel_size():
	return _clip_pixel_size;
	
func set_clip_pixel_size(new_clip_pixel_size):
	_clip_pixel_size = new_clip_pixel_size;
	
func fetch_inventory_display_data():
	return {
		"texture":           _texture,
		"clip_pixel_offset": _clip_pixel_offset,
		"clip_pixel_size":   _clip_pixel_size
	};