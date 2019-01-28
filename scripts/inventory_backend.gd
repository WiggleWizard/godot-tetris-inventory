extends Node

class_name Inventory

export(Vector2) var inventory_size = Vector2(1, 1) setget set_inventory_size, get_inventory_size;

var _inventory      = [];

# Holds data about the item that's being dragged from the inventory.
var _dragging = null;

# Special class to represent additional information about an item in the inventory.
class InventoryItem:
	var _id         = -1;
	var _slot       = Vector2(-1, -1);
	var _item_id    = null;
	var _stack_size = 1;
	
	func _init(id, item_id):
		_id = id;
		_item_id = item_id;
		
	func get_id():
		return _id;
		
	func get_slot():
		return _slot;
		
	func get_stack_size():
		return _stack_size;
		
	func at_max_stack():
		return _stack_size >= get_item().get_max_stack_size();
		
	func get_item_id():
		return _item_id;
		
	func get_item():
		return ItemDatabase.get_item(_item_id);
		
	func in_range():
		if(_slot.x < 0 || _slot.y < 0):
			return false;
		return true;
		
	func get_rect():
		var item = ItemDatabase.get_item(_item_id);
		return Rect2(_slot, item.get_size());
		
	func intersects(inventory_item_b):
		return inventory_item_b.get_rect().intersects(get_rect());
		
	func _remove_from_stack(amount):
		_stack_size = _stack_size - amount;
		return _stack_size;
		
	func _set_slot(new_slot):
		_slot = new_slot;

signal item_added;
signal item_moved;
signal item_removed;
signal item_stack_size_change;


func get_inventory_size():
	return inventory_size;

# Resizes the inventory, be careful with this as this will truncate your
# inventory if you make it smaller.
func set_inventory_size(new_size):
	inventory_size = new_size;
	
	# TODO: Truncate inventory
	
# Adds an item to the player's inventory at a specific slot, if successful then
# return true.
func add_item_at(item_id, slot):
	if(would_be_in_bounds(item_id, slot) && can_item_fit(item_id, slot)):
		var id = _add_to_inventory_list(item_id, slot);
		
		emit_signal("item_added", id, slot);
		
		return true;
		
	return false;
	
# Appends an item to the inventory, attempting to find a spare slot for it.
func append_item(item_id):
	var slot = find_slot_for_item(item_id);
	if(slot.x > -1 && slot.y > -1):
		var inventory_item_id = _add_to_inventory_list(item_id, slot);
		
		emit_signal("item_added", _inventory[inventory_item_id]);
		
		return true;
		
	return false;
	
func set_item_stack_size(inventory_item_id, new_size):
	if(!_inventory[inventory_item_id]):
		return false;
		
	_inventory[inventory_item_id]._set_stack_size(new_size);
	
	emit_signal("item_stack_size_change", _inventory[inventory_item_id]);
	
func move_item(inventory_item_id, to_slot):
	if(can_inventory_item_fit(inventory_item_id, to_slot)):
		_inventory[inventory_item_id]._set_slot(to_slot);
		
		emit_signal("item_moved", _inventory[inventory_item_id]);
		
	emit_signal("item_moved", _inventory[inventory_item_id]);
	
# Removes an item at specific ID. This ID can be fetched by using
# get_id_at_slot().
func remove_item(inventory_item_id):
	if(!_inventory[inventory_item_id]):
		return false;
		
	var item_to_be_removed = _inventory[inventory_item_id];
	
	_inventory[inventory_item_id] = null;
	
	emit_signal("item_removed", item_to_be_removed);
	
# Attempts to find a slot for the item.
# Returns the slot as Vector2, if either component is below 0 then
# no appropriate slot was found for the item.
func find_slot_for_item(item_id):
	for y in range(inventory_size.y):
		for x in range(inventory_size.x):
			var slot = Vector2(x, y);
			
			# Slot already occupied with the beginning of an item
			if(get_id_at_slot(slot) > -1):
				continue;
				
			if(would_be_in_bounds(item_id, slot) && can_item_fit(item_id, slot)):
				return slot;
				
	return Vector2(-1, -1);
	
# Returns an array of collided inventory item IDs if this item were to be put in `slot`.
func sweep(item_id, slot):
	var collision_list = [];
	
	# Convenience variables
	var item           = ItemDatabase.get_item(item_id);
	var item_sz        = item.get_size();
	var item_rect      = Rect2(slot, item_sz);
	
	# AABB testing against everything in inventory
	for i in range(_inventory.size()):
		if(_inventory[i] == null):
			continue;
			
		if(_inventory[i].in_range()):
			if(_inventory[i].get_rect().intersects(item_rect)):
				collision_list.append(i);
		
	return collision_list;
	
# Checks if an item can fit at a specific slot. Does not do boundary check.
func can_item_fit(item_id, slot):
	if(sweep(item_id, slot).size() == 0):
		return true;
	return false;
	
# Checks if an inventory item can fit into a specific slot. This function is mainly used for
# moving items that are already in the inventory around.
func can_inventory_item_fit(inventory_item_id, slot):
	var item_id = _inventory[inventory_item_id].get_item_id();
	
	if(!would_be_in_bounds(item_id, slot)):
		return false;
		
	var sweep_result = sweep(item_id, slot);
	
	# Not colliding with anything
	if(sweep_result.size() == 0):
		return true;
	# Colliding with only itself
	elif(sweep_result.size() == 1 && sweep_result[0] == inventory_item_id):
		return true;
	return false;
			
# Checks to see if the item would be within the bounds of the inventory space.
func would_be_in_bounds(item_id, slot):
	var item           = ItemDatabase.get_item(item_id);
	var item_sz        = item.get_size();
	var item_rect      = Rect2(slot, item_sz);
	var inventory_rect = Rect2(0, 0, inventory_size.x + 1, inventory_size.y + 1);
	
	return inventory_rect.encloses(item_rect);
	
func is_valid_id(id):
	if(id > _inventory.size() || id < 0):
		return false;
	return true;
	
# Fetches the ID of the item at slot. Returns -1 if no item found.
func get_id_at_slot(slot):
	var t = Rect2(slot, Vector2(1, 1));
	for i in range(_inventory.size()):
		if(_inventory[i] == null):
			continue;
			
		if(_inventory[i].in_range()):
			if(_inventory[i].get_rect().intersects(t)):
				return i;
				
	return -1;
	
func get_inventory_item(inventory_item_id):
	if(inventory_item_id < 0 || inventory_item_id >= _inventory.size()):
		return null;
		
	return _inventory[inventory_item_id];
	
# Returns all items in the player's inventory.
func get_all_inventory_items():
	return _inventory;
	
# Call this when the player begins a drag from the inventory.
func begin_drag(slot, node):
	var inventory_id = get_id_at_slot(slot);
	
	# If it's a legit item
	if(is_valid_id(inventory_id)):
		var mouse_down_slot_offset = slot - _inventory[inventory_id].get_slot();
		return {
			"source": "inventory",
			"inventory_id": inventory_id,
			"slot": slot,
			"node": node,
			"mouse_down_slot_offset": mouse_down_slot_offset
		};
		
	return null;
	
# Call this when the above has been dropped somewhere.
func drop(dest):
	if(dest != "inventory"):
		return;
	
# Adds the item ID to the inventory list and returns the inventory item ID.
func _add_to_inventory_list(item_id, slot = Vector2(-1, -1)):
	# Look for an empty slot to put this item
	for i in range(_inventory.size()):
		if(_inventory[i] == null):
			_inventory[i] = InventoryItem.new(i, item_id);
			_inventory[i]._set_slot(slot);
			_inventory[i]._set_id(i);
			
			return i;
			
	_inventory.append(InventoryItem.new(_inventory.size(), item_id));
	var new_item_id = _inventory.size() - 1;
	
	_inventory[new_item_id]._set_slot(slot);
	
	return new_item_id;