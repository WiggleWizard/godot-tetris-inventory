tool
extends Control

class_name InventoryFrontend


export(NodePath) var inventory_backend = null setget set_backend_path;
export(PackedScene) var inventory_component_scene = preload("res://addons/tetris-inventory/scenes/default_display_item.tscn");
export(PackedScene) var tooltip_scene = preload("res://addons/tetris-inventory/scenes/default_tooltip_scene.tscn");

export(Color) var valid_move_color   = Color(0, 1, 0, 0.5);
export(Color) var stack_move_color   = Color(1, 1, 0, 0.5);
export(Color) var invalid_move_color = Color(1, 0, 0, 0.5);
export(float) var drag_alpha         = 0;

export(float) var tooltip_time = 0.5;

export(bool) var enable_guides   = false setget set_enable_guides;
export(Color) var guide_color    = Color(1, 1, 1, 0.1) setget set_guide_color;
export(bool) var lock_rect_ratio = true setget set_lock_rect_ratio;
var slot_size = 64;


var _backend = null;
var _stack_node_mapping = {};

var _container       = null;
var _mouse_sink_node = null;
var _move_indicator  = null;

var _drag_data      = null;
var _prev_drag_slot = Vector2(-1, -1);

var _process_drop       = false;
var _dropped_internally = false;
var _drop_fw            = false;

var _curr_mouse_slot  = Vector2(-1, -1);
var _curr_hover_stack = null;

var _tooltip_timer = Timer.new();
var _tooltip_node;

var _prev_size = Vector2(0, 0);


#==========================================================================
# Public
#==========================================================================	
		
# Returns the actual node thats mapped to the inventory item ID
func get_mapped_node(stack_id):
	return _stack_node_mapping[stack_id];

func get_mapped_node_stack_id(node):
	for i in _stack_node_mapping:
		if(_stack_node_mapping[i] == node):
			return i;

	return -1;
	
func get_slot_from_position(position):
	return Vector2(floor(position.x / slot_size), floor(position.y / slot_size));

# Sets the backend node path and resets the backend to point to the new path
func set_backend_path(new_backend_path):
	inventory_backend = new_backend_path;

	# Disconnect signals of old backend
	if(_backend != null):
		_backend.disconnect("inventory_size_changed", self, "inventory_size_changed");
		_backend.disconnect("item_added",             self, "item_added");
		_backend.disconnect("stack_size_changed",     self, "stack_size_changed");
		_backend.disconnect("stack_moved",            self, "stack_moved");
		_backend.disconnect("stack_removed",          self, "stack_removed");

		_backend = null;
			
	if(inventory_backend != null && has_node(inventory_backend)):
		var temp_backend = get_node(inventory_backend);
		if(temp_backend != null && temp_backend.has_method("get_backend_type")):
			_backend = get_node(inventory_backend);
			if(!_backend.is_connected("inventory_size_changed", self, "inventory_size_changed")):
				_backend.connect("inventory_size_changed", self, "inventory_size_changed");
			if(!_backend.is_connected("item_added", self, "item_added")):
				_backend.connect("item_added", self, "item_added");
			if(!_backend.is_connected("stack_size_changed", self, "stack_size_changed")):
				_backend.connect("stack_size_changed", self, "stack_size_changed");
			if(!_backend.is_connected("stack_moved", self, "stack_moved")):
				_backend.connect("stack_moved", self, "stack_moved");
			if(!_backend.is_connected("stack_removed", self, "stack_removed")):
				_backend.connect("stack_removed", self, "stack_removed");

	update();

func get_backend():
	return _backend;

func set_enable_guides(b):
	enable_guides = b;
	update();

func set_guide_color(new_guide_color):
	guide_color = new_guide_color;
	update();

func set_lock_rect_ratio(lock_rect_ratio_on):
	lock_rect_ratio = lock_rect_ratio_on;
	
	if(lock_rect_ratio && !is_connected("resized", self, "_resized")):
		connect("resized", self, "_resized");
		emit_signal("resized");
	else:
		disconnect("resized", self, "_resized");
		
	property_list_changed_notify();
	update();


#==========================================================================
# Inventory Backend Events
#==========================================================================	

func inventory_size_changed(new_size):
	update();
	emit_signal("resized");

# Called when an item is added to the backend
func item_added(stack):
	var item     = stack.get_item();
	var slot     = stack.get_slot();
	var stack_id = stack.get_id();
	
	if(item):
		var inventory_size = item.get_size();
		
		var new_scene = inventory_component_scene.instance();
		new_scene.set_display_data(item.get_uid(), stack.get_stack_size(), stack.get_max_stack_size(), "inventory");
		
		# Map the scene to the inventory ID
		_stack_node_mapping[stack_id] = new_scene;
		
		# Append the scene to the tree
		_container.add_child(new_scene);
		new_scene.mouse_filter = MOUSE_FILTER_IGNORE;
		new_scene.set_size(Vector2(inventory_size.x * slot_size, inventory_size.y * slot_size));
		new_scene.set_position(Vector2(slot.x * slot_size, slot.y * slot_size));

# Called when a stack is moved within the backend
func stack_moved(stack):
	var slot       = stack.get_slot();
	var stack_id   = stack.get_id();
	var stack_node = get_mapped_node(stack_id);
	
	if(stack_node):
		stack_node.set_position(Vector2(slot.x * slot_size, slot.y * slot_size));
		stack_node.modulate.a = 1;

# Called when a stack size has changed (whether removing or adding from stack) in the backend
func stack_size_changed(stack):
	var stack_node = get_mapped_node(stack.get_id());
	if(stack_node.has_method("stack_size_changed")):
		stack_node.stack_size_changed(stack.get_stack_size());
	
# Called when a stack is removed from the backend
func stack_removed(stack):
	var stack_id = stack.get_id();
	
	# Remove the inventory item node from the scene
	var mapped_node = get_mapped_node(stack_id);
	if(mapped_node):
		mapped_node.queue_free();
		
	# Unmap the inventory item scene
	_stack_node_mapping.erase(stack_id);
	
	
#==========================================================================
# Events
#==========================================================================	
	
func _ready():
	set_backend_path(inventory_backend);

	if(Engine.is_editor_hint()):
		set_process(false);

	if(!Engine.is_editor_hint()):
		_container       = Container.new();
		_mouse_sink_node = Container.new();
		_move_indicator  = ColorRect.new();
		
		# Append necessary nodes, special attention to order
		add_child(_container);
		add_child(_mouse_sink_node);
		add_child(_move_indicator);
		
		# Presetup
		_container.set_anchors_and_margins_preset(PRESET_WIDE);
		_container.set_mouse_filter(MOUSE_FILTER_IGNORE);
		_mouse_sink_node.set_anchors_and_margins_preset(PRESET_WIDE);
		_mouse_sink_node.set_mouse_filter(MOUSE_FILTER_PASS);
		_mouse_sink_node.connect("mouse_exited", self, "_on_mouse_exited");
		_move_indicator.set_visible(false);
		_move_indicator.set_mouse_filter(MOUSE_FILTER_IGNORE);
	
		_tooltip_timer.one_shot = true;
		_tooltip_timer.stop();
		add_child(_tooltip_timer);
	
		if(!inventory_backend):
			printerr("Inventory Frontend has no Backend associated");
			return;
			
	if(lock_rect_ratio && !is_connected("resized", self, "_resized")):
		connect("resized", self, "_resized");

func _process(_delta):
	if(_process_drop):
		var viewport = get_viewport();
		if(!viewport.gui_is_dragging()):
			if(_dropped_internally == true):
				pass;
			elif(_drop_fw == true):
				pass;
			else:
				gutter_drop();
				
			_dropped_internally = false;
			_drop_fw            = false;
			_drag_data          = {};
			
			_process_drop = false;

func _on_mouse_exited():
	_move_indicator.set_visible(false);
	_prev_drag_slot   = Vector2(-1, -1);
	_curr_mouse_slot  = Vector2(-1, -1);
	_curr_hover_stack = null;

	# Remove the tooltip
	if(_tooltip_node):
		_tooltip_node.queue_free();
		_tooltip_node = null;

	_tooltip_timer.stop();

func _gui_input(event):
	if(event is InputEventMouseMotion):
		if(_tooltip_node):
			_tooltip_node.set_position(get_global_mouse_position() - _tooltip_node.get_rect().size);

		var curr_slot = (event.position/slot_size);
		curr_slot = curr_slot.floor();
		
		if(curr_slot != _curr_mouse_slot):
			_curr_mouse_slot = curr_slot;
			_mouse_change_slot(curr_slot);

# Called when the mouse cursor moves into a new slot.
func _mouse_change_slot(slot):
	var viewport = get_viewport();
	if(viewport && viewport.gui_is_dragging()):
		drag_hover(slot, viewport.gui_get_drag_data());
		
	# Check which stack node we are hovering over
	var valid_hover = false;
	for child in _container.get_children():
		if(child.get_rect().has_point(get_local_mouse_position())):
			if(_curr_hover_stack != child):
				_curr_hover_stack = child;
				_hover_change(_curr_hover_stack);

			valid_hover = true;

			break;

	if(!valid_hover):
		_curr_hover_stack = null;
		_hover_change(null);

func _hover_change(node):
	var stack_id = -1;
	if(node != null):
		stack_id = get_mapped_node_stack_id(node);
		if(_tooltip_node && stack_id != -1):
			_tooltip_node.queue_free();
			_tooltip_node = null;
		
	if(_tooltip_node):
		_tooltip_node.queue_free();
		_tooltip_node = null;

	_tooltip_timer.stop();
	_tooltip_timer.set_wait_time(tooltip_time);
	if(_tooltip_timer.is_connected("timeout", self, "_tooltip_timer_timeout")):
		_tooltip_timer.disconnect("timeout", self, "_tooltip_timer_timeout");
	_tooltip_timer.connect("timeout", self, "_tooltip_timer_timeout", [stack_id]);
	_tooltip_timer.start();

func _tooltip_timer_timeout(stack_id):
	if(!_tooltip_node && stack_id != -1):
		_tooltip_node = tooltip_scene.instance();
		_tooltip_node.set_mouse_filter(MOUSE_FILTER_IGNORE);
		
		# Fetch the top most node
		var top_most_node = self;
		var root = get_tree().get_root();
		while(top_most_node.get_parent() != root):
			top_most_node = top_most_node.get_parent();
		
		if(_tooltip_node.has_method("set_display_item")):
			var stack = _backend.get_stack_from_id(stack_id);
			var item = stack.get_item();
			_tooltip_node.set_display_item(item);
		
		top_most_node.add_child(_tooltip_node);
		_tooltip_node.set_position(get_global_mouse_position() - _tooltip_node.get_rect().size);
	

#==========================================================================
# Drag Drop
#==========================================================================
	
# Called when the player starts dragging
func get_drag_data(position):
	_process_drop = true;

	# Remove the tooltip
	if(_tooltip_node):
		_tooltip_node.queue_free();
		_tooltip_node = null;
	_tooltip_timer.stop();

	# Figure out which slot the player started dragging
	var drag_start_slot = Vector2(floor(position.x / slot_size), floor(position.y / slot_size));
	
	var stack_id = _backend.get_id_at_slot(drag_start_slot);
	if(_backend.is_valid_id(stack_id)):
		var mapped_node = get_mapped_node(stack_id);
		if(mapped_node):
			var stack          = _backend.get_stack_from_id(stack_id);
			var item           = stack.get_item();
			var inventory_size = item.get_size();
			
			# Get drag modifier (holding certain buttons can split the stack, etc)
			var drag_modifier = _backend.DragModifier.DRAG_ALL;
			if(Input.is_action_pressed("half_stack_modifier")):
				drag_modifier = _backend.DragModifier.DRAG_SPLIT_HALF;
			
			# Populate the drag data
			var base_drag_data = _backend.get_base_drag_data(drag_start_slot, drag_modifier);
			base_drag_data["frontend"]    = self;
			base_drag_data["mapped_node"] = mapped_node;
			_drag_data = base_drag_data;
			
			# If we are dragging the whole stack then hide it
			if(_drag_data["stack_size"] == stack.get_stack_size()):
				mapped_node.modulate.a = drag_alpha;
			elif(get_mapped_node(stack_id).has_method("stack_size_changed")):
				get_mapped_node(stack_id).stack_size_changed(stack.get_stack_size() - _drag_data["stack_size"]);
			
			# Create an outer for the preview so we can have an offset.
			var inner = inventory_component_scene.instance();
			
			# Callbacks for display node
			if(inner.has_method("set_display_data")):
				inner.set_display_data(stack.get_item_uid(), base_drag_data["stack_size"], item.get_max_stack_size(), "dragging");
			
			# Add drag preview
			var outer = Control.new();
			set_drag_preview(outer);
			outer.add_child(inner);
			outer.set_size(Vector2(inventory_size.x * slot_size, inventory_size.y * slot_size));
			inner.set_position(mapped_node.get_position() - position);
			
			return _drag_data;
	
	return null;
	
# Called while user is dragging the Node over the inventory
func can_drop_data(_position, _data):
	#var mouse_curr_slot = Vector2(floor(position.x / slot_size), floor(position.y / slot_size));
		
	# Since we don't need to run this code every time the mouse moves, we can do some
	# simple calculation to figure out if the mouse has changed slots.
	#if(_prev_drag_slot != mouse_curr_slot):
	#	drag_hover(position, mouse_curr_slot, data);
	
	#_prev_drag_slot = mouse_curr_slot;
			
	return true;
	
func drag_hover(slot, data):
	if(data["source"] == "inventory"):
		var frontend       = data["frontend"];
		var item           = ItemDatabase.get_item(data["item_uid"]);
		var item_slot_size = item.get_size();
		var offset_slot    = slot - Vector2(0, 0);

		# Draw move indicator in the right place
		_move_indicator.set_visible(true);
		_move_indicator.set_position(Vector2(offset_slot.x * slot_size, offset_slot.y * slot_size));
		_move_indicator.set_size(Vector2(item_slot_size.x * slot_size, item_slot_size.y * slot_size));
		
		var can_item_fit = false;
		# Inventory item being dragged around the same inventory it originated from
		if(frontend == self):
			can_item_fit = _backend.can_stack_fit(data["stack_id"], offset_slot);
		# Different inventory origin
		elif(data.has("source") && data["source"] == "inventory"):
			can_item_fit = _backend.can_item_fit(data["item_uid"], offset_slot);

		# Check if we are hovering over an inventory entry that has the same UID
		var can_stack  = false;
		var stack_id   = _backend.get_id_at_slot(slot);
		var stack_item = _backend.get_stack_from_id(stack_id);
		if(stack_item != null):
			# If hovering over the same item that was picked up
			if(stack_id == data["stack_id"]):
				# If we aren't dragging the entire stack then allow stack
				if(stack_item.get_stack_size() != data["stack_size"]):
					can_stack = true;
			elif(stack_item.get_item_uid() == data["item_uid"] && !stack_item.at_max_stack()):
				can_stack = true;
			
		# Set move indicator to different colors depending on whether item can fit
		# or not.
		# TODO: Make this more customizable.
		if(can_stack == true):
			_move_indicator.set_frame_color(stack_move_color);
		elif(can_item_fit == true):
			_move_indicator.set_frame_color(valid_move_color);
		else:
			_move_indicator.set_frame_color(invalid_move_color);

func drop_data(position, data):
	if(!_is_drop_data_valid(data)):
		return;

	var slot = get_slot_from_position(position);

	_tooltip_timer.start();
	
	var from_frontend = data["frontend"];
	var from_backend  = data["backend"];
	
	# Compile appropriate transfer data
	var transfer_data = {};
	if(data.has("stack_id")):
		transfer_data["stack_id"] = data["stack_id"];

	_backend.transfer(from_backend, slot, data["stack_size"], data["item_uid"], transfer_data);
	
	# If the source of the drag was internal then set flag
	if(from_frontend == self):
		_dropped_internally = true;
	elif(from_frontend != self && from_frontend.has_method("drop_fw")):
		# Curtesy call source node
		from_frontend.drop_fw(self);

	_move_indicator.set_visible(false);
	
# Curtesy call from controls that have had the item from this Node dropped into.	
func drop_fw(_from_control):
	_drop_fw = true;

	var viewport = get_viewport();
	var drag_data = viewport.gui_get_drag_data();
	if(drag_data["mapped_node"]):
		drag_data["mapped_node"].modulate.a = 1;
	
# Occurs when an item is dropped in no man's land.
func gutter_drop():
	_move_indicator.set_visible(false);
	if(_drag_data && _drag_data["mapped_node"]):
		_drag_data["mapped_node"].modulate.a = 1;
	
func get_drag_data_fw(position, _from_control):
	return get_drag_data(position);

func can_drop_data_fw(position, data, _from_control):
	return can_drop_data(position, data);
	
func drop_data_fw(position, data, _from_control):
	return drop_data(position, data);
	
	
#==========================================================================
# Internal
#==========================================================================

func _is_drop_data_valid(data):
	if(!data && (!data.has("source") || !data.has("frontend"))):
		return false;
	if(data["frontend"] == null):
		return false;
		
	return true;


#==========================================================================
# Tool
#==========================================================================

func _resized():
	if(lock_rect_ratio && _backend):
		var inventory_size = _backend.get_inventory_size();
		
		# Changing width
		if(_prev_size.x != rect_size.x):
			var ratio = inventory_size.y / inventory_size.x;
			rect_size.y = rect_size.x * ratio;
		elif(_prev_size.y != rect_size.y):
			var ratio = inventory_size.x / inventory_size.y;
			rect_size.x = rect_size.y * ratio;
			
	_prev_size = rect_size;

func _draw():
	# Draw inventory grid lines for debug
	if(enable_guides && _backend):
		if(lock_rect_ratio):
			# Calculate slot size
			var local_rect = get_rect();
			local_rect.position.x = 0;
			local_rect.position.y = 0;
			
			var inventory_width  = _backend.get_inventory_size().x;
			var inventory_height = _backend.get_inventory_size().y;
			slot_size = min(local_rect.size.x / inventory_width, local_rect.size.y / inventory_height);
			
		var inventory_size = _backend.get_inventory_size();
		for i in range(inventory_size.x):
			if(i == 0):
				continue;
				
			var start = Vector2(i * slot_size, 0);
			var end   = Vector2(i * slot_size, inventory_size.y * slot_size);
			draw_line(start, end, guide_color);
			
		for i in range(inventory_size.y):
			if(i == 0):
				continue;
				
			var start = Vector2(0, i * slot_size);
			var end   = Vector2(inventory_size.x * slot_size, i * slot_size);
			draw_line(start, end, guide_color);
			
		draw_rect(Rect2(1, 1, inventory_size.x * slot_size, inventory_size.y * slot_size), guide_color, false);
		
func _get_property_list():
	if(!lock_rect_ratio):
		return [
			{
				"name": "slot_size",
				"type": TYPE_INT
			}
		];
	else:
		return [];

func _get_configuration_warning():
	if(!_backend):
		return "A valid backend must be associated with this node";
	
	return "";