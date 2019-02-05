extends Control

class_name ItemDropZone


export(NodePath) var backend;
export(bool) var remove_from_source = false;
export(bool) var allow_drop_swapping = true;
export(Array, String) var inclusive_filter = [];
export(PackedScene) var display_scene = preload("res://addons/tetris-inventory/scenes/default_display_item.tscn");
export(Vector2) var drag_slot_size = Vector2(64, 64);

signal item_dropped;
signal item_removed;

var _backend = null;

var _item_uid   = "";
var _stack_size = 1;

# A Control node that sinks all mouse events so the developer decorate the zone
# however.
var _container       = null;
var _mouse_sink_node = null;

var _dropped_internally = false;
var _drop_fw = false;


#==========================================================================
# Public
#==========================================================================

func get_curr_item_uid():
	return _item_uid;


#==========================================================================
# Public Callbacks
#==========================================================================

# Public callback for when drag hovering over the drop zone. Allow is true only if
# the zone will accept the hovering item.
func drag_hover(allow, data):
	pass;
	
# Public callback for when an item has been dropped from an inventory.
func dropped_item_from_inventory(item_uid, stack_size = 1):
	pass;
	
	

#==========================================================================
# Events
#==========================================================================

func _ready():
	set_process(false);
	
	_container       = Container.new();
	_mouse_sink_node = Control.new();
	
	add_child(_container);
	add_child(_mouse_sink_node);
	
	_container.set_anchors_and_margins_preset(PRESET_WIDE);
	_container.set_mouse_filter(MOUSE_FILTER_IGNORE);
	_mouse_sink_node.set_drag_forwarding(self);
	_mouse_sink_node.set_anchors_and_margins_preset(Control.PRESET_WIDE);

	if(backend):
		_backend = get_node(backend);
	
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
	# Don't allow the user to drag when nothing in here
	if(!_backend.has_valid_item()):
		return null;
		
	set_process(true);
	
	var item = ItemDatabase.get_item(_backend.get_item_uid());
	var size = item.get_size();
	
	# Create an outer for the preview so we can have an offset.
	var outer = Control.new();
	var inner = display_scene.instance();
	set_drag_preview(outer);
	
	outer.add_child(inner);
	outer.set_size(Vector2(size.x * drag_slot_size.x, size.y * drag_slot_size.y));
	inner.set_position(-position);

	# Populate the drag data
	var base_drag_data = _backend.get_base_drag_data();
	base_drag_data["frontend"] = self;
	return base_drag_data;

func can_drop_data_fw(position, data, from_control):
	# TODO
	return true;
	
func drop_data_fw(position, data, from_control):
	_dropped_internally = true;
	
	# Request a transfer from the backend
	_backend.transfer_from_simple_slot(data["backend"], data["stack_size"], data["stack_id"]);
	
	# Notify the source
	var frontend = data["frontend"];
	if(frontend && frontend.has_method("drop_fw")):
		frontend.drop_fw(self);
		
# Curtesy call from controls that have had the item from this Node dropped into.
func drop_fw(from_control):
	_drop_fw = true;
	
# Occurs when an item is dropped in no man's land.
func gutter_drop():
	pass;


#==========================================================================
# Private Internal
#==========================================================================

func _is_drop_data_valid(data):
	if(!data && (!data.has("source") || !data.has("source_node") || !data.has("item_uid"))):
		return false;
		
	if(data["source_node"] == null):
		return false;
		
	return true;