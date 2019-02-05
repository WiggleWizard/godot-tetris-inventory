extends Control

class_name InventoryFrontend


export(bool) var enable_guides = false;
export(Color) var guide_color = Color(1, 1, 1, 0.1);
export(int) var slot_size = 30;
export(NodePath) var inventory_backend = NodePath("./Inventory");
export(Color) var valid_move_color = Color(0, 1, 0, 0.5);
export(Color) var stack_move_color = Color(1, 1, 0, 0.5);
export(Color) var invalid_move_color = Color(1, 0, 0, 0.5);
export(float) var drag_alpha = 0;
export(PackedScene) var inventory_component_scene = preload("res://addons/tetris-inventory/scenes/default_display_item.tscn");

var _backend = null;
var _inventory_node_mapping = {};

var _container       = null;
var _mouse_sink_node = null;
var _move_indicator  = null;


var _drag_data = null;
var _dropped_in_drop_zone = false;
var _prev_drag_slot = Vector2(-1, -1);

var _dropped_internally = false;
var _drop_fw = false;


#==========================================================================
# Public
#==========================================================================	
		
# Returns the actual node thats mapped to the inventory item ID
func get_mapped_node(inventory_item_id):
	return _inventory_node_mapping[inventory_item_id];
	
func get_slot_from_position(position):
	return Vector2(floor(position.x / slot_size), floor(position.y / slot_size));

func get_backend():
	return _backend;


#==========================================================================
# Inventory Backend Events
#==========================================================================	

func item_added(inventory_item):
	var item = inventory_item.get_item();
	var slot = inventory_item.get_slot();
	var inventory_id = inventory_item.get_id();
	
	if(item):
		var inventory_size = item.get_size();
		
		var display_data = item.fetch_inventory_display_data();
		var new_scene = inventory_component_scene.instance();
		new_scene.set_display_data(item.get_uid(), inventory_item.get_stack_size(), "inventory");
		
		# Map the scene to the inventory ID
		_inventory_node_mapping[inventory_id] = new_scene;
		
		# Append the scene to the tree
		_container.add_child(new_scene);
		new_scene.mouse_filter = MOUSE_FILTER_IGNORE;
		new_scene.set_size(Vector2(inventory_size.x * slot_size, inventory_size.y * slot_size));
		new_scene.set_position(Vector2(slot.x * slot_size, slot.y * slot_size));

func item_moved(inventory_item):
	var slot                = inventory_item.get_slot();
	var inventory_item_id   = inventory_item.get_id();
	var inventory_item_node = get_mapped_node(inventory_item_id);
	
	if(inventory_item_node):
		inventory_item_node.set_position(Vector2(slot.x * slot_size, slot.y * slot_size));
		inventory_item_node.modulate.a = 1;

func item_stack_size_change(inventory_item):
	var inventory_item_node = get_mapped_node(inventory_item.get_id());
	if(inventory_item_node.has_method("stack_size_changed")):
		inventory_item_node.stack_size_changed(inventory_item.get_stack_size());
	
func item_removed(inventory_item):
	var inventory_id = inventory_item.get_id();
	
	# Remove the inventory item node from the scene
	var mapped_node = get_mapped_node(inventory_id);
	if(mapped_node):
		mapped_node.queue_free();
		
	# Unmap the inventory item scene
	_inventory_node_mapping.erase(inventory_id);
	
	
#==========================================================================
# Events
#==========================================================================	
	
func _ready():
	set_process(false);
	
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
	_mouse_sink_node.set_drag_forwarding(self);
	_mouse_sink_node.set_mouse_filter(MOUSE_FILTER_STOP);
	_mouse_sink_node.connect("mouse_exited", self, "_on_mouse_exited");
	_move_indicator.set_visible(false);
	_move_indicator.set_mouse_filter(MOUSE_FILTER_IGNORE);
	
	if(!inventory_backend):
		printerr("Inventory Frontend has no Backend associated");
		return;
	
	if(inventory_backend):
		_backend = get_node(inventory_backend);
		
	if(_backend):
		_backend.connect("item_added", self, "item_added");
		_backend.connect("item_stack_size_change", self, "item_stack_size_change");
		_backend.connect("item_moved", self, "item_moved");
		_backend.connect("item_removed", self, "item_removed");
		

func _process(delta):
	var viewport = get_viewport();
	if(!viewport.gui_is_dragging()):
		if(_dropped_internally == true):
			print("Dropped internally");
		elif(_drop_fw == true):
			print("Dropped externally");
		else:
			print("Gutter drop");
			gutter_drop();
			
		_dropped_internally = false;
		_drop_fw = false;
		_drag_data = {};
		
		set_process(false);

func _on_mouse_exited():
	_move_indicator.set_visible(false);
	_prev_drag_slot = Vector2(-1, -1);
	
func _draw():
	# Draw inventory grid lines for debug
	if(enable_guides && _backend):
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
			
		draw_rect(Rect2(0, 0, inventory_size.x * slot_size, inventory_size.y * slot_size), guide_color, false);
	

#==========================================================================
# Drag Drop
#==========================================================================
	
# Called when the player starts dragging
func get_drag_data(position):
	set_process(true);

	# Figure out which slot the player started dragging
	var drag_start_slot = Vector2(floor(position.x / slot_size), floor(position.y / slot_size));
	
	var inventory_id = _backend.get_id_at_slot(drag_start_slot);
	if(_backend.is_valid_id(inventory_id)):
		var mapped_node = get_mapped_node(inventory_id);
		if(mapped_node):
			var inventory_item = _backend.get_inventory_item(inventory_id);
			var item           = inventory_item.get_item();
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
			if(_drag_data["stack_size"] == inventory_item.get_stack_size()):
				mapped_node.modulate.a = drag_alpha;
			elif(get_mapped_node(inventory_id).has_method("stack_size_changed")):
				get_mapped_node(inventory_id).stack_size_changed(inventory_item.get_stack_size() - _drag_data["stack_size"]);
			
			# Create an outer for the preview so we can have an offset.
			var inner = inventory_component_scene.instance();
			
			# Callbacks for display node
			if(inner.has_method("set_display_data")):
				inner.set_display_data(inventory_item.get_item_uid(), base_drag_data["stack_size"], "dragging");
			
			# Add drag preview
			var outer = Control.new();
			set_drag_preview(outer);
			outer.add_child(inner);
			outer.set_size(Vector2(inventory_size.x * slot_size, inventory_size.y * slot_size));
			inner.set_position(mapped_node.get_position() - position);
			
			return _drag_data;
	
	return null;
	
# Called while user is dragging the Node over the inventory
func can_drop_data(position, data):
	var mouse_curr_slot = Vector2(floor(position.x / slot_size), floor(position.y / slot_size));
		
	# Since we don't need to run this code every time the mouse moves, we can do some
	# simple calculation to figure out if the mouse has changed slots.
	if(_prev_drag_slot != mouse_curr_slot):
		drag_hover(position, mouse_curr_slot, data);
	
	_prev_drag_slot = mouse_curr_slot;
			
	return true;
	
func drag_hover(position, slot, data):
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
		var can_stack     = false;
		var hovering_id   = _backend.get_id_at_slot(slot);
		var hovering_item = _backend.get_inventory_item(hovering_id);
		if(hovering_item != null):
			# If hovering over the same item that was picked up
			if(hovering_id == data["stack_id"]):
				# If we aren't dragging the entire stack then allow stack
				if(hovering_item.get_stack_size() != data["stack_size"]):
					can_stack = true;
			elif(hovering_item.get_item_uid() == data["item_uid"] && !hovering_item.at_max_stack()):
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
			
	elif(data["source"] == "drop_zone"):
		var item           = ItemDatabase.get_item(data["item_uid"]);
		var item_slot_size = item.get_size();
		
		# Draw move indicator in the right place
		_move_indicator.set_visible(true);
		_move_indicator.set_position(Vector2(slot.x * slot_size, slot.y * slot_size));
		_move_indicator.set_size(Vector2(item_slot_size.x * slot_size, item_slot_size.y * slot_size));
		
		var can_item_fit = _backend.can_item_fit(data["item_uid"], slot);
		if(can_item_fit == true):
			_move_indicator.set_frame_color(valid_move_color);
		else:
			_move_indicator.set_frame_color(invalid_move_color);

func drop_data(position, data):
	if(!_is_drop_data_valid(data)):
		return;

	var slot = get_slot_from_position(position);
		
	var from_frontend = data["frontend"];
	var from_backend  = data["backend"];
	var from_stack_id = 0;
	if(data.has("stack_id")):
		from_stack_id = data["stack_id"];

	var transfer_data = {
		"stack_id": from_stack_id
	};
	_backend.transfer(from_backend, slot, data["stack_size"], data["item_uid"], transfer_data);
	
	# If the source of the drag was internal then set flag
	if(from_frontend == self):
		_dropped_internally = true;
	# Curtesy call source node
	elif(from_frontend != self && from_frontend.has_method("drop_fw")):
		from_frontend.drop_fw(self);

	_move_indicator.set_visible(false); 
	
# Curtesy call from controls that have had the item from this Node dropped into.	
func drop_fw(from_control):
	_drop_fw = true;

	var viewport = get_viewport();
	var drag_data = viewport.gui_get_drag_data();
	if(drag_data["mapped_node"]):
		drag_data["mapped_node"].modulate.a = 1;

# Callback for when a drop is "acknowledged" from a third party node
func validate_drop(valid = true):
	if(valid):
		_dropped_in_drop_zone = true;
	else:
		_move_indicator.set_visible(false);
		_drag_data["mapped_node"].modulate.a = 1;
	
# Called when an item is dropped in a drop zone. Return true to accept the drop
# Return false to deny it.
func drop_zone_drop(remove_from_source, accepted, dropped_inventory_item_id, dest):
	validate_drop(true);
	
	if(remove_from_source && accepted):
		var curr_item_uid = dest.get_curr_item_uid();
		if(curr_item_uid != ""):
			# If the drop zone already has something in it, then we need to swap it out.
			# So first we attempt to find space in the inventory for the item (while ignoring
			# the item that was dropped as it's still in the inventory). If there's
			# no available slot then we refuse the drop.
			var fittable_slot = _backend.find_slot_for_item(curr_item_uid, [dropped_inventory_item_id]);
			if(fittable_slot.x > -1 && fittable_slot.y > -1):
				# Remove dropped item
				_backend.remove_item(dropped_inventory_item_id);
				
				# Add item that was in the drop zone
				_backend.add_item_at(curr_item_uid, fittable_slot);
				
				return true;
			else:
				_drag_data["mapped_node"].modulate.a = 1;
				return false;
		else:
			_backend.remove_item(dropped_inventory_item_id);
			return true;
		
		return false;
	else:
		_drag_data["mapped_node"].modulate.a = 1;
		return false;
	
# Occurs when an item is dropped in no man's land.
func gutter_drop():
	_move_indicator.set_visible(false);
	if(_drag_data && _drag_data["mapped_node"]):
		_drag_data["mapped_node"].modulate.a = 1;
	
func get_drag_data_fw(position, from_control):
	return get_drag_data(position);

func can_drop_data_fw(position, data, from_control):
	return can_drop_data(position, data);
	
func drop_data_fw(position, data, from_control):
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