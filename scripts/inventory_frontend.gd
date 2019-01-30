extends Control

class_name InventoryFrontend


export(bool) var enable_guides = false;
export(Color) var guide_color = Color(1, 1, 1, 0.1);
export(int) var slot_size = 30;
export(NodePath) var inventory_backend = NodePath("./Inventory");
export(Color) var valid_move_color = Color(0, 1, 0, 0.5);
export(Color) var invalid_move_color = Color(1, 0, 0, 0.5);
export(float) var drag_alpha = 0;
export(PackedScene) var inventory_component_scene = load("res://addons/tetris-inventory/scenes/default_display_item.tscn");

var _inventory_backend = null;
var _inventory_node_mapping = {};

onready var _move_indicator = get_node("MoveIndicator");
onready var _container      = get_node("Container");

var _drag_data = null;
var _dragging_from_inventory = false;
var _dropped_in_drop_zone = false;
var _process_drop_next_frame = false;
var _prev_drag_slot = Vector2(-1, -1);


#==========================================================================
# Public
#==========================================================================	
		
# Returns the actual node thats mapped to the inventory item ID
func get_mapped_node(inventory_item_id):
	return _inventory_node_mapping[inventory_item_id];
	
func get_slot_from_position(position):
	return Vector2(floor(position.x / slot_size), floor(position.y / slot_size));


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
		new_scene.set_display_data(display_data["texture"], display_data["clip_offset"], display_data["clip_size"]);
		
		# Map the scene to the inventory ID
		_inventory_node_mapping[inventory_id] = new_scene;
		
		# Append the scene to the tree
		_container.add_child(new_scene);
		new_scene.mouse_filter = MOUSE_FILTER_IGNORE;
		new_scene.set_size(Vector2(inventory_size.x * slot_size, inventory_size.y * slot_size));
		new_scene.set_position(Vector2(slot.x * slot_size, slot.y * slot_size));
		new_scene.set_meta("inventory_id", inventory_id);

func item_moved(inventory_item):
	var slot                = inventory_item.get_slot();
	var inventory_item_id   = inventory_item.get_id();
	var inventory_item_node = get_mapped_node(inventory_item_id);
	
	if(inventory_item_node):
		inventory_item_node.set_position(Vector2(slot.x * slot_size, slot.y * slot_size));
		inventory_item_node.modulate.a = 1;

func item_stack_size_change(inventory_item):
	print("Stack size changed");
	
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
	set_process_input(false);
	set_process(false);
	
	connect("mouse_entered", self, "on_mouse_enter");
	connect("mouse_exited", self, "on_mouse_exit");
	
	if(!inventory_backend):
		printerr("Inventory Frontend has no Backend associated");
		return;
	
	if(inventory_backend):
		_inventory_backend = get_node(inventory_backend);
		
	if(_inventory_backend):
		_inventory_backend.connect("item_added", self, "item_added");
		_inventory_backend.connect("item_stack_size_change", self, "item_stack_size_change");
		_inventory_backend.connect("item_moved", self, "item_moved");
		_inventory_backend.connect("item_removed", self, "item_removed");
		
func _process(delta):
	if(_process_drop_next_frame):
		if(!_dropped_in_drop_zone):
			gutter_drop();
			
		# Reset drop related variables
		_process_drop_next_frame = false;
		_dragging_from_inventory = false;
		_dropped_in_drop_zone    = false;
		_drag_data               = null;
		
		set_process(false);
	
func _input(event):
	if(event is InputEventMouseButton):
		var viewport = get_viewport();
	
		# Mouse events occur first before drag events
		if(event.button_index == BUTTON_LEFT && !event.is_pressed() && viewport.gui_is_dragging()):
			# If the cursor is positioned outside the inventory space
			if(_dragging_from_inventory && !get_rect().has_point(event.position)):
				set_process_input(false);
				
				# Process the drop data on the next frame
				_process_drop_next_frame = true;
				set_process(true);

func _on_mouse_exited():
	_move_indicator.set_visible(false);
	
func _draw():
	# Draw inventory grid lines for debug
	if(enable_guides && _inventory_backend):
		var inventory_size = _inventory_backend.get_inventory_size();
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
	_dragging_from_inventory = true;
	set_process_input(true);
	
	# Figure out which slot the player started dragging
	var drag_start_slot = Vector2(floor(position.x / slot_size), floor(position.y / slot_size));
	
	var inventory_id = _inventory_backend.get_id_at_slot(drag_start_slot);
	if(_inventory_backend.is_valid_id(inventory_id)):
		var mapped_node = get_mapped_node(inventory_id);
		if(mapped_node):
			mapped_node.modulate.a = drag_alpha;
			
			var inventory_item = _inventory_backend.get_inventory_item(inventory_id);
			var item           = inventory_item.get_item();
			var inventory_size = item.get_size();
			
			# Create an outer for the preview so we can have an offset.
			var outer = Control.new();
			var inner = inventory_component_scene.instance();
			set_drag_preview(outer);
			
			outer.add_child(inner);
			outer.set_size(Vector2(inventory_size.x * slot_size, inventory_size.y * slot_size));
			inner.set_position(mapped_node.get_position() - position);

			# Populate the drag data
			var base_drag_data = _inventory_backend.begin_drag(drag_start_slot);
			base_drag_data["source_node"] = self;
			base_drag_data["mapped_node"] = mapped_node;
			_drag_data = base_drag_data;
			
			return _drag_data;
	
	return null;
	
# Called while user is dragging the Node over the inventory
func can_drop_data(position, data):
	if(!data):
		return false;
		
	# Since we don't need to run this code every time the mouse moves, we can do some
	# simple calculation to figure out if the mouse has changed slots.
	var mouse_curr_slot = Vector2(floor(position.x / slot_size), floor(position.y / slot_size));
	if(_prev_drag_slot != mouse_curr_slot):
		var item = _inventory_backend.get_inventory_item(data["inventory_id"]).get_item();
		var item_slot_size = item.get_size();
		
		var offset_slot = mouse_curr_slot - data["mouse_down_slot_offset"];

		# Draw move indicator
		_move_indicator.set_visible(true);
		_move_indicator.set_position(Vector2(offset_slot.x * slot_size, offset_slot.y * slot_size));
		_move_indicator.set_size(Vector2(item_slot_size.x * slot_size, item_slot_size.y * slot_size));
		
		if(!_inventory_backend.can_inventory_item_fit(data["inventory_id"], offset_slot)):
			_move_indicator.set_frame_color(invalid_move_color);
		else:
			_move_indicator.set_frame_color(valid_move_color);
		
	_prev_drag_slot = mouse_curr_slot;
		
	return true;
	
func drop_data(position, data):
	if(data["source"] == "inventory"):
		# Ensure that it comes from the same inventory
		if(data["source_node"] == self):
			var new_slot = get_slot_from_position(position) - data["mouse_down_slot_offset"];
			_inventory_backend.move_item(data["inventory_id"], new_slot);
			_move_indicator.set_visible(false);
	
# Called when an item is dropped in a drop zone. Return true to accept the drop
# Return false to deny it.
func drop_zone_drop(remove_from_source, accepted, dropped_inventory_item_id, dest):
	_dropped_in_drop_zone = true;
	
	if(remove_from_source && accepted):
		var curr_item_id = dest.get_curr_item_id();
		if(curr_item_id != -1):
			# If the drop zone already has something in it, then we need to swap it out.
			# So first we attempt to find space in the inventory for the item (while ignoring
			# the item that was dropped as it's still in the inventory). If there's
			# no available slot then we refuse the drop.
			var fittable_slot = _inventory_backend.find_slot_for_item(curr_item_id, [dropped_inventory_item_id]);
			if(fittable_slot.x > -1 && fittable_slot.y > -1):
				# Remove dropped item
				_inventory_backend.remove_item(dropped_inventory_item_id);
				
				# Add item that was in the drop zone
				_inventory_backend.add_item_at(curr_item_id, fittable_slot);
				
				return true;
			else:
				_drag_data["mapped_node"].modulate.a = 1;
				return false;
		else:
			_inventory_backend.remove_item(dropped_inventory_item_id);
			return true;
		
		return false;
	else:
		_drag_data["mapped_node"].modulate.a = 1;
		return false;
	
# Occurs when an item is dropped in no man's land.
func gutter_drop():
	_move_indicator.set_visible(false);
	_drag_data["mapped_node"].modulate.a = 1;
