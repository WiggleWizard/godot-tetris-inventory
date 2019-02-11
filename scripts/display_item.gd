extends Control


var _item_uid       = -1;
var _stack_size     = 1;
var _max_stack_size = 1;
var _location       = "";


# Called before this node is put in the tree
func set_display_data(item_uid, stack_size, max_stack_size, location = ""):
	_item_uid       = item_uid;
	_stack_size     = stack_size;
	_max_stack_size = max_stack_size;
	_location       = location;
	
func stack_size_changed(new_size):
	_stack_size = new_size;
	$Label.set_text(str(_stack_size));
	
func _ready():
	$Label.set_text(str(_stack_size));
	

		
	if(_max_stack_size == 1):
		$Label.set_visible(false);