extends Node

class_name SimpleSlotBackend

export(bool) var remove_from_source = false;
export(bool) var allow_drop_swapping = true;
export(Array, String) var inclusive_filter = [];

var _backend_type = "SimpleSlot";

var _item_uid = "";
var _stack_size = 0;

signal item_changed;


#==========================================================================
# Generic Overrides
#==========================================================================

# Fetches the item UID that's in this slot
func get_item_uid():
	return _item_uid;


#==========================================================================
# Public
#==========================================================================

# Returns true if there's a valid item in this slot
func has_valid_item():
	return _item_uid != "";

# Checks whether this specific item UID is allowed in this slot
func is_item_allowed(item_uid):
	if(!allow_drop_swapping && get_item_uid() > -1):
		return false;
	
	var is_allowed = false;
	if(inclusive_filter.size() > 0):
		var item = ItemDatabase.get_item(item_uid);
		if(inclusive_filter.find(item.get_type()) > -1):
			is_allowed = true;
	else:
		is_allowed = true;
		
	return is_allowed;

func transfer(from_backend, item_uid, transfer_data):
	if(!is_item_allowed(item_uid)):
		return false;
		
	var validate_result = from_backend.validate_transfer(1, item_uid, transfer_data);
	if(validate_result == true):
		from_backend.handle_transfer(1, transfer_data);

		_item_uid = item_uid;
		emit_signal("item_changed", item_uid);
		
	return true;

func validate_transfer(amount, item_uid, transfer_data):
	if(amount == 1 && _item_uid == item_uid):
		return true;
	return false;

func handle_transfer(amount, transfer_data):
	_item_uid = "";
	emit_signal("item_changed", "");

func get_base_drag_data():
	if(!has_valid_item()):
		return null;

	return {
		"source":     "simple_slot",
		"item_uid":   _item_uid,
		"stack_size": 1,
		"backend":    self
	};