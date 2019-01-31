extends Control

class_name ItemDropZone

export(bool) var remove_from_source = false;
export(bool) var allow_drop_swapping = true;
export(Array, String) var inclusive_filter = [];

var _item_id    = -1;
var _stack_size = 1;

# A Control node that sinks all mouse events so the developer decorate the zone
# however.
var _mouse_sink_node = null;

var _dropped_internally = false;
var _drop_fw = false;


#==========================================================================
# Public
#==========================================================================

func get_curr_item_id():
	return _item_id;


#==========================================================================
# Public Callbacks
#==========================================================================

# Public callback for when drag hovering over the drop zone. Allow is true only if
# the zone will accept the hovering item.
func drag_hover(allow, data):
	pass;
	
# Public callback for when an item has been dropped from an inventory.
func dropped_item_from_inventory(item_id, stack_size = 1):
	pass;
	

#==========================================================================
# Events
#==========================================================================

func _ready():
	set_process(false);
	
	_mouse_sink_node = Control.new();
	add_child(_mouse_sink_node);
	
	_mouse_sink_node.set_drag_forwarding(self);
	_mouse_sink_node.set_anchors_and_margins_preset(Control.PRESET_WIDE);
	
func _process(delta):
	var viewport = get_viewport();
	if(!viewport.gui_is_dragging()):
		if(_dropped_internally == true):
			pass;
			#print("Dropped internally");
		elif(_drop_fw == true):
			pass;
			#print("Dropped externally");
		else:
			gutter_drop();
			
		_dropped_internally = false;
		_drop_fw = false;
		
		set_process(false);
		
	
	
#==========================================================================
# Drag Drop
#==========================================================================	

func get_drag_data_fw(position, from_control):
	set_process(true);
	
	return {
		"source_node": self,
		"source": "drop_zone",
		"item_id": _item_id
	};

func can_drop_data_fw(position, data, from_control):
	if(data.has("item_id")):
		var item_id = data["item_id"];
		drag_hover(_is_item_allowed(item_id), data);
	
	return true;
	
func drop_data_fw(position, data, from_control):
	_dropped_internally = true;
	var source_node = data["source_node"];
	
	if(data.has("item_id")):
		var allowed = _is_item_allowed(data["item_id"]);
		
		# If from inventory
		if(source_node && data["source"] == "inventory"):
			# Inform the inventory that we have dropped here
			var proceed_with_drop = source_node.drop_zone_drop(remove_from_source, allowed, data["inventory_id"], self);
			
			if(allowed && proceed_with_drop):
				# Deal with adding the item in to the drop zone memory
				_item_id = data["item_id"];
				dropped_item_from_inventory(data["item_id"]);
			
		# Otherwise just notify the source
		elif(source_node && source_node.has_method("_on_drop_zone_drop")):
			source_node._on_drop_zone_drop(remove_from_source, allowed);
		
# Curtesy call from controls that have had the item from this Node dropped into.
func drop_fw(from_control):
	_drop_fw = true;
	
# Occurs when an item is dropped in no man's land.
func gutter_drop():
	pass;

#==========================================================================
# Private Internal
#==========================================================================		

# Checks whether this item ID is allowed in this drop zone. Check is done by
# item type.
func _is_item_allowed(item_id):
	if(!allow_drop_swapping && get_curr_item_id() > -1):
		return false;
	
	var is_allowed = false;
	if(inclusive_filter.size() > 0):
		var item = ItemDatabase.get_item(item_id);
		if(inclusive_filter.find(item.get_type()) > -1):
			is_allowed = true;
	else:
		is_allowed = true;
		
	return is_allowed;