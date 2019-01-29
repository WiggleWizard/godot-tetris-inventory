extends Control

class_name ItemDropZone

export(bool) var remove_from_source = false;
export(Array, String) var inclusive_filter = [];

var _item_id    = -1;
var _stack_size = 1;

# A Control node that sinks all mouse events so the developer decorate the zone
# however.
var _mouse_event_sink_node = null;


func _ready():
	_mouse_event_sink_node = Control.new();
	add_child(_mouse_event_sink_node);
	
	_mouse_event_sink_node.set_drag_forwarding(self);
	_mouse_event_sink_node.set_anchors_and_margins_preset(Control.PRESET_WIDE);
	
# Callback for when an item has been dropped from an inventory.
func dropped_item_from_inventory(item_id, stack_size = 1):
	pass;
	
func get_drag_data_fw(position, from_control):
	print(_item_id);
	return null;

func can_drop_data_fw(position, data, from_control):
	return true;
	
func drop_data_fw(position, data, from_control):
	var source_node = data["source_node"];
	
	if(data.has("item_id")):
		var allowed = _is_item_allowed(data["item_id"]);
		
		# If from inventory
		if(source_node && data["source"] == "inventory"):
			source_node._on_drop_zone_drop(remove_from_source, allowed, data["inventory_id"]);
			
			if(allowed):
				dropped_item_from_inventory(data["item_id"]);
			
		# Otherwise just notify the source
		elif(source_node && source_node.has_method("_on_drop_zone_drop")):
			source_node._on_drop_zone_drop(remove_from_source, allowed);
		
# Checks whether this item ID is allowed in this drop zone. Check is done by
# item type.
func _is_item_allowed(item_id):
	var is_allowed = false;
	if(inclusive_filter.size() > 0):
		var item = ItemDatabase.get_item(item_id);
		if(inclusive_filter.find(item.get_type()) > -1):
			is_allowed = true;
	else:
		is_allowed = true;
		
	return is_allowed;