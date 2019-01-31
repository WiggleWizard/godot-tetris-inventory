extends Node

class_name Inventory

export(Vector2) var inventory_size = Vector2(1, 1) setget set_inventory_size, get_inventory_size;
export(bool) var auto_stack = true;

var _inventory = [];

# Holds data about the item that's being dragged from the inventory.
var _dragging = null;

signal item_added;
signal item_moved;
signal item_removed;
signal item_stack_size_change;


# Special class to represent an inventory item
class InventoryItem:
	var _id         = -1;
	var _slot       = Vector2(-1, -1);
	var _item_uid   = "";
	var _stack_size = 1;
	
	func _init(id, item_uid):
		_id = id;
		_item_uid = item_uid;
		
	func get_id():
		return _id;
		
	func get_slot():
		return _slot;
		
	func get_stack_size():
		return _stack_size;
		
	func set_stack_size(new_size):
		_stack_size = new_size;
		
	func at_max_stack():
		return _stack_size >= get_item().get_max_stack_size();
		
	func get_item_uid():
		return _item_uid;
		
	func get_item():
		return ItemDatabase.get_item(_item_uid);
		
	# Purely for convenience
	func get_data():
		return {
			"id":         get_id(),
			"slot":       get_slot(),
			"stack_size": get_stack_size(),
			"item_uid":   get_item_uid()
		};
		
	func in_range():
		if(_slot.x < 0 || _slot.y < 0):
			return false;
		return true;
		
	func get_rect():
		var item = ItemDatabase.get_item(_item_uid);
		return Rect2(_slot, item.get_size());
		
	func intersects(inventory_item_b):
		return inventory_item_b.get_rect().intersects(get_rect());
		
	func _remove_from_stack(amount):
		_stack_size = _stack_size - amount;
		return _stack_size;
		
	func _set_slot(new_slot):
		_slot = new_slot;


#==========================================================================
# Public
#==========================================================================

func get_inventory_size():
	return inventory_size;

# Resizes the inventory, be careful with this as this will truncate your
# inventory if you make it smaller.
func set_inventory_size(new_size):
	inventory_size = new_size;
	
	# TODO: Truncate inventory
	
# Adds an item to the player's inventory at a specific slot, if successful then
# return true.
func add_item_at(item_uid, slot, amount = 1):
	if(ItemDatabase.get_item(item_uid) == null):
		return false;
		
	if(would_be_in_bounds(item_uid, slot) && can_item_fit(item_uid, slot)):
		var inventory_item_id = _add_to_inventory_list(item_uid, slot, amount);
		
		emit_signal("item_added", _inventory[inventory_item_id]);
		
		return true;
		
	return false;
	
# Appends an item to the inventory, attempting to find a spare slot for it.
# `item_id` should be a valid item ID that's been registered to the global item database.
func append_item(item_uid, amount = 1):
	var item = ItemDatabase.get_item(item_uid);
	if(item == null):
		return 0;
		
	var item_max_stack_size = item.get_max_stack_size();
		
	var amount_added = 0;
		
	# Stack onto existing items in the inventory as much as possible
	if(auto_stack && item.get_max_stack_size() > 1):
		for inventory_item in _inventory:
			# Only if it's the same item UID and it's not at max stack
			if(inventory_item.get_item_uid() == item_uid && !inventory_item.at_max_stack()):
				var stack_size = inventory_item.get_stack_size();
				var item_stack_remainder = item_max_stack_size - stack_size;
				
				# Can't put anymore on this stack
				if(item_stack_remainder == 0):
					continue;
					
				# Calculate amount left after we add to this stack
				var amount_left = amount - item_stack_remainder;
				if(amount_left <= 0):
					set_item_stack_size(inventory_item.get_id(), stack_size + amount);
					amount_added += amount;
					amount = 0;
				else:
					set_item_stack_size(inventory_item.get_id(), item_max_stack_size);
					amount_added += item_max_stack_size;
					amount = amount_left;
	
	if(amount > 0):
		# At this point, we know that all the existing same items have been stacked
		# fully. So we are adding new entries to the inventory now.
		var amount_left = amount;
		while true:
			var slot = find_slot_for_item(item_uid);
			if(slot.x > -1 && slot.y > -1):
				var inventory_item_id = -1;
				
				# Last of the stacks
				if(amount_left < item.get_max_stack_size()):
					inventory_item_id = _add_to_inventory_list(item_uid, slot, amount_left);
					amount_added += amount_left;
					amount_left = 0;
				else:
					inventory_item_id = _add_to_inventory_list(item_uid, slot, item.get_max_stack_size());
					amount_added += item.get_max_stack_size();
					amount_left -= item.get_max_stack_size();
					
				emit_signal("item_added", _inventory[inventory_item_id]);
				
				if(amount_left <= 0):
					break;
			# Cannot find a free slot for this new item stack
			else:
				break;
				
	return amount_added;
	
# Sets the inventory item stack size
func set_item_stack_size(inventory_item_id, new_size):
	if(!_inventory[inventory_item_id]):
		return false;
		
	_inventory[inventory_item_id].set_stack_size(new_size);
	
	emit_signal("item_stack_size_change", _inventory[inventory_item_id]);
	
# Moves inventory item from where it is currently to `slot`
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
func find_slot_for_item(item_uid, mask = []):
	if(ItemDatabase.get_item(item_uid) == null):
		return Vector2(-1, -1);
		
	for y in range(inventory_size.y):
		for x in range(inventory_size.x):
			var slot = Vector2(x, y);
			if(would_be_in_bounds(item_uid, slot) && can_item_fit(item_uid, slot, mask)):
				return slot;
				
	return Vector2(-1, -1);
	
# Checks if an item can fit at a specific slot.
func can_item_fit(item_uid, slot, mask = []):
	if(ItemDatabase.get_item(item_uid) == null):
		return false;
		
	if(!would_be_in_bounds(item_uid, slot)):
		return false;
		
	if(sweep(item_uid, slot, mask).size() == 0):
		return true;
	return false;
	
# Checks if an inventory item can fit into a specific slot. This function is mainly used for
# moving items that are already in the inventory around.
func can_inventory_item_fit(inventory_item_id, slot):
	var item_uid = _inventory[inventory_item_id].get_item_uid();
	
	if(!would_be_in_bounds(item_uid, slot)):
		return false;
		
	var sweep_result = sweep(item_uid, slot);
	
	# Not colliding with anything
	if(sweep_result.size() == 0):
		return true;
	# Colliding with only itself
	elif(sweep_result.size() == 1 && sweep_result[0] == inventory_item_id):
		return true;
	return false;
			

#==========================================================================
# Private
#==========================================================================	

# Checks to see if the item would be within the bounds of the inventory space.
func would_be_in_bounds(item_uid, slot):
	var item           = ItemDatabase.get_item(item_uid);
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
	
# Returns an array of collided inventory item IDs if this item were to be put in `slot`.
func sweep(item_uid, slot, mask = []):
	var collision_list = [];
	
	# Convenience variables
	var item           = ItemDatabase.get_item(item_uid);
	var item_sz        = item.get_size();
	var item_rect      = Rect2(slot, item_sz);
	
	# AABB testing against everything in inventory
	for i in range(_inventory.size()):
		if(_inventory[i] == null):
			continue;
			
		# Ignore inventory IDs that are in the mask list
		if(mask.find(i) > -1):
			continue;
			
		if(_inventory[i].in_range()):
			if(_inventory[i].get_rect().intersects(item_rect)):
				collision_list.append(i);
		
	return collision_list;
	
# Call this when the player begins a drag from the inventory.
func get_base_drag_data(slot):
	var inventory_id = get_id_at_slot(slot);
	var inventory_item = get_inventory_item(inventory_id);
	
	# If it's a legit item
	if(is_valid_id(inventory_id)):
		var mouse_down_slot_offset = slot - _inventory[inventory_id].get_slot();
		return {
			"source": "inventory",
			"inventory_id": inventory_id,
			"item_uid": inventory_item.get_item_uid(),
			"slot": slot,
			"stack_size": inventory_item.get_stack_size(),
			"mouse_down_slot_offset": mouse_down_slot_offset,
			"backend": self
		};
		
	return null;


#==========================================================================
# Private Internal
#==========================================================================	

# Adds the item ID to the inventory list and returns the inventory item ID.
func _add_to_inventory_list(item_uid, slot = Vector2(-1, -1), stack_size = 1):
	# Look for an empty slot to put this item
	for i in range(_inventory.size()):
		if(_inventory[i] == null):
			_inventory[i] = InventoryItem.new(i, item_uid);
			_inventory[i]._set_slot(slot);
			_inventory[i].set_stack_size(stack_size);
			
			return i;
			
	_inventory.append(InventoryItem.new(_inventory.size(), item_uid));
	var new_item_uid = _inventory.size() - 1;
	
	_inventory[new_item_uid]._set_slot(slot);
	_inventory[new_item_uid].set_stack_size(stack_size);
	
	return new_item_uid;