extends Control


var _item_uid = -1;
var _stack_size = 1;
var _location = "";


# Called before this node is put in the tree
func set_display_data(item_uid, stack_size, location = ""):
	_item_uid = item_uid;
	_stack_size = stack_size;
	_location = location;
	
func stack_size_changed(new_size):
	_stack_size = new_size;
	$Label.set_text(str(_stack_size));
	
func _ready():
	$Label.set_text(str(_stack_size));
	
	if(_location == "dragging"):
		$Border.set_visible(false);
		
	var item = ItemDatabase.get_item(_item_uid);
	#var display_data = item.fetch_inventory_display_data();
		
	#$Sprite.set_texture(display_data["texture"]);
	#$Sprite.region_enabled = true;
	#$Sprite.set_region_rect(Rect2(display_data["clip_pixel_offset"], display_data["clip_pixel_position"]));