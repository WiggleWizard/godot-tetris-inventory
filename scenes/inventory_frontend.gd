extends Control

class_name InventoryFrontend


export(bool) var enable_guides = false;
export(Color) var guide_color = Color(1, 1, 1, 0.1);
export(int) var slot_size = 30;
export(NodePath) var inventory_backend;
export(Color) var valid_move_color = Color(0, 1, 0, 0.5);
export(Color) var invalid_move_color = Color(1, 0, 0, 0.5);
export(float) var drag_alpha = 0;
export(PackedScene) var inventory_component_scene = load("res://addons/tetris-inventory/scenes/default_inventory_item.tscn");

var _inventory_backend = null;

onready var _move_indicator = get_node("MoveIndicator");
onready var _container      = get_node("Container");

var _dragging_from_inventory = false;
var _prev_drag_slot = Vector2(-1, -1);


func _ready():
	set_process_input(false);
	
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
			
# Called when the player starts dragging
func get_drag_data(position):
	_dragging_from_inventory = true;
	set_process_input(true);
	
	# Figure out which slot the player started dragging
	var slot = Vector2(floor(position.x / slot_size), floor(position.y / slot_size));
	
	var inventory_id = _inventory_backend.get_id_at_slot(slot);
	if(_inventory_backend.is_valid_id(inventory_id)):
		# Go through all child nodes and find which one belongs to this item
		for child in _container.get_children():
			if(child.get_meta("inventory_id") == inventory_id):
				child.modulate.a = drag_alpha;
				var inventory_item = _inventory_backend.get_inventory_item(inventory_id);
				var item = inventory_item.get_item();
				var inventory_size = item.get_size();
				
				# Create an outer for the preview so we can have an offset.
				var outer = Control.new();
				var inner = inventory_component_scene.instance();
				set_drag_preview(outer);
				outer.add_child(inner);
				
				inner.set_size(Vector2(inventory_size.x * slot_size, inventory_size.y * slot_size));
				#inner.set_position();
				
				return _inventory_backend.begin_drag(slot, child);
	
	return null;
	
# Called while user is dragging the Node over the inventory
func can_drop_data(position, data):
	if(!data):
		return false;
		
	# Since we don't need to run this code every time the mouse moves, we can do some
	# simple calculation to figure out if the mouse has changed slots.
	var slot = Vector2(floor(position.x / slot_size), floor(position.y / slot_size));
	if(_prev_drag_slot != slot):
		var item = _inventory_backend.get_inventory_item(data["inventory_id"]).get_item();
		var item_slot_size = item.get_size();

		# Draw validation boxes
		_move_indicator.set_visible(true);
		_move_indicator.set_position(Vector2(slot.x * slot_size, slot.y * slot_size));
		_move_indicator.set_size(Vector2(item_slot_size.x * slot_size, item_slot_size.y * slot_size));
		
		if(!_inventory_backend.can_inventory_item_fit(data["inventory_id"], slot)):
			_move_indicator.set_frame_color(invalid_move_color);
		else:
			_move_indicator.set_frame_color(valid_move_color);
		
	_prev_drag_slot = slot;
		
	return true;
	
func drop_data(position, data):
	print("Dropped in inventory");
	if(data["source"] == "inventory"):
		var new_slot = get_slot_from_position(position);
		_inventory_backend.move_item(data["inventory_id"], new_slot);
		_move_indicator.set_visible(false);
		
func drop(position, data):
	# If dropped outside the inventory bounds
	if(get_rect().has_point(position)):
		print("Dropped inside");
	else:
		print("Dropped outside");
	
func get_slot_from_position(position):
	return Vector2(floor(position.x / slot_size), floor(position.y / slot_size));
	
func item_added(inventory_item):
	var item = inventory_item.get_item();
	var slot = inventory_item.get_slot();
	
	if(item):
		var inventory_size = item.get_size();
		print(item.fetch_inventory_display_data());
		
		var display_data = item.fetch_inventory_display_data();
		var new_scene = inventory_component_scene.instance();
		new_scene.set_display_data(display_data["texture"], display_data["clip_offset"], display_data["clip_size"]);
		
		_container.add_child(new_scene);
		new_scene.mouse_filter = MOUSE_FILTER_IGNORE;
		new_scene.set_size(Vector2(inventory_size.x * slot_size, inventory_size.y * slot_size));
		new_scene.set_position(Vector2(slot.x * slot_size, slot.y * slot_size));
		new_scene.set_meta("inventory_id", inventory_item.get_id());

func item_moved(inventory_item):
	var inventory_item_id = inventory_item.get_id();
	var slot = inventory_item.get_slot();
	
	for child in _container.get_children():
		if(child.get_meta("inventory_id") == inventory_item_id):
			child.set_position(Vector2(slot.x * slot_size, slot.y * slot_size));
			child.modulate.a = 1;
			
			return;

func item_stack_size_change(item):
	print(item);
	
func item_removed(item):
	print(item);
	
func on_mouse_enter():
	pass;
	
func on_mouse_exit():
	print("Exit");
	
func _input(event):
	if(event is InputEventMouse):
		var viewport = get_viewport();
		
		# Listen out for mouse events that occur so we can determine when the player
		# has dropped outside the inventory.
		if(_dragging_from_inventory && !viewport.gui_is_dragging()):
			set_process_input(false);
			_dragging_from_inventory = false;
			drop(event.position, {});

func _on_mouse_exited():
	on_mouse_exit();
