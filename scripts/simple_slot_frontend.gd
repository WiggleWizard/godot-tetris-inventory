tool
extends Control

class_name SimpleSlot


export(Color) var valid_color         = Color(0, 1, 0, 0.5);
export(Color) var invalid_color       = Color(1, 0, 0, 0.5);
export(PackedScene) var display_scene = preload("res://addons/tetris-inventory/scenes/default_display_item.tscn");

export(NodePath) var linked_inventory setget set_linked_inventory;
export(int) var drag_slot_size = 64;

var backend             = null setget backend_set;
var allow_drop_swapping = true;
var inclusive_filter    = PoolStringArray();

var _backend = null;

var _linked_inventory = null;

# A Control node that sinks all mouse events so the developer decorate the zone
# however.
var _container       = null;
var _mouse_sink_node = null;
var _move_indicator  = null;

var _dropped_internally = false;
var _drop_fw            = false;


#==========================================================================
# Public
#==========================================================================

func get_backend():
	return _backend;

func set_linked_inventory(node_path):
	# Disconnect from previously assigned inventory
	if(_linked_inventory):
		_linked_inventory.disconnect("slot_size_changed", self, "linked_inventory_slot_size_changed");

	linked_inventory = node_path;

	if(linked_inventory && has_node(linked_inventory)):
		_linked_inventory = get_node(node_path);
		if(_linked_inventory):
			drag_slot_size = _linked_inventory.slot_size;

			if(!_linked_inventory.is_connected("slot_size_changed", self, "linked_inventory_slot_size_changed")):
				_linked_inventory.connect("slot_size_changed", self, "linked_inventory_slot_size_changed");


#==========================================================================
# Public Callbacks
#==========================================================================

# Public callback for when drag hovering over the drop zone. Allow is true only if
# the zone will accept the hovering item.
func drag_hover(_allow, _data):
	pass;
	
# Public callback for when an item has been dropped from an inventory.
func dropped_item_from_inventory(_item_uid, _stack_size = 1):
	pass;
	

#==========================================================================
# Events
#==========================================================================

func _init():
	property_list_changed_notify();

func _ready():
	set_linked_inventory(linked_inventory);
	
	if(Engine.is_editor_hint()):
		set_process(false);

	if(!Engine.is_editor_hint()):
		_container = Container.new();
		_container.set_name("Container");
		add_child(_container);
		_mouse_sink_node = Control.new();
		_mouse_sink_node.set_name("Mouse Sink");
		add_child(_mouse_sink_node);
		_move_indicator = ColorRect.new();
		_move_indicator.set_name("Move Indicator");
		add_child(_move_indicator);
		
		_container.set_anchors_and_margins_preset(PRESET_WIDE);
		_container.set_mouse_filter(MOUSE_FILTER_IGNORE);
		_mouse_sink_node.set_drag_forwarding(self);
		_mouse_sink_node.set_mouse_filter(MOUSE_FILTER_STOP);
		_mouse_sink_node.set_anchors_and_margins_preset(Control.PRESET_WIDE);
		_mouse_sink_node.connect("mouse_exited", self, "mouse_exited");
		_move_indicator.set_visible(false);
		_move_indicator.set_mouse_filter(MOUSE_FILTER_IGNORE);
		_move_indicator.set_anchors_and_margins_preset(Control.PRESET_WIDE);
	
		if(!backend):
			_backend = SimpleSlotBackend.new();
			_backend.allow_drop_swapping = allow_drop_swapping;
			_backend.inclusive_filter    = inclusive_filter;
		else:
			_backend = get_node(backend);

		_backend.connect("item_changed", self, "item_changed");

func _process(_delta):
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
		
func backend_set(new_backend):
	backend = new_backend;
	property_list_changed_notify();

func mouse_exited():
	_move_indicator.set_visible(false);


#==========================================================================
# Drag Drop
#==========================================================================	

func get_drag_data_fw(position, _from_control):
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
	outer.set_size(Vector2(size.x * drag_slot_size, size.y * drag_slot_size));
	inner.set_position(-(inner.get_rect().size / 2));
	
	_container.set_visible(false);

	# Populate the drag data 
	var base_drag_data = _backend.get_base_drag_data();
	base_drag_data.frontend = self;
	base_drag_data.mouse_down_offset = inner.get_rect().size / 2;
	return base_drag_data;

func can_drop_data_fw(_position, data, _from_control):
	_move_indicator.set_visible(true);

	var is_item_allowed = _backend.is_item_allowed(data.item_uid);
	if(is_item_allowed):
		_move_indicator.color = valid_color;
	else:
		_move_indicator.color = invalid_color;

	return true;
	
func drop_data_fw(_position, data, _from_control):
	_dropped_internally = true;
	
	# Request a transfer from the backend
	var transfer_data = {}
	transfer_data["stack_id"] = data.stack_id;
	_backend.transfer(data.backend, data.item_uid, transfer_data);
	
	# Notify the frontend
	var frontend = data.frontend;
	if(frontend && frontend.has_method("drop_fw")):
		frontend.drop_fw(self);

	_move_indicator.set_visible(false);
		
# Curtesy call from controls that have had the item from this Node dropped into.
func drop_fw(_from_control):
	_drop_fw = true;

	_move_indicator.set_visible(false);
	_container.set_visible(true);
	
# Occurs when an item is dropped in no man's land.
func gutter_drop():
	_container.set_visible(true);
	
	
#==========================================================================
# Simple Slot Backend Events
#==========================================================================	

func item_changed(item_uid):
	if(item_uid == "" || _container.get_child_count() > 0):
		for child in _container.get_children():
			child.queue_free();
			
	if(item_uid != ""):
		var new_scene = display_scene.instance();
		new_scene.set_display_data(item_uid, 1, 1, "simple_slot");
		_container.add_child(new_scene);
		

#==========================================================================
# Private Internal
#==========================================================================

func _is_drop_data_valid(data):
	if(!data && (!data.has("source") || !data.has("source_node") || !data.has("item_uid"))):
		return false;
		
	if(data.source_node == null):
		return false;
		
	return true;


#==========================================================================
# Tool
#==========================================================================

func _get_property_list():
	var prop_list = [];
	if(!backend):
		prop_list.append({
			"name": "backend",
			"type": TYPE_NODE_PATH
		});
		prop_list.append({
			"name": "remove_from_source",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT
		});
		prop_list.append({
			"name": "allow_drop_swapping",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT
		});
		prop_list.append({
			"name": "inclusive_filter",
			"type": TYPE_STRING_ARRAY,
			"usage": PROPERTY_USAGE_DEFAULT
		});
	else:
		prop_list.append({
			"name": "backend",
			"type": TYPE_NODE_PATH
		});
		
	return prop_list;

func linked_inventory_slot_size_changed(new_size):
	drag_slot_size = new_size;


#==========================================================================
# Heirarchy Mangling
#==========================================================================	

func get_children():
	var result = [];
	for child in .get_children():
		if(child != _container && child != _mouse_sink_node && child != _move_indicator):
			result.append(child);
	return result;
	
func get_child_count():
	var result = 0;
	for child in .get_children():
		if(child != _container && child != _mouse_sink_node && child != _move_indicator):
			result += 1;
	return result;

func get_child(idx):
	var child = .get_child(idx);
	if(child == _container && child == _mouse_sink_node && child == _move_indicator):
		return null;
	return child;