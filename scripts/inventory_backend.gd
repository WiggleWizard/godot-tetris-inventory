##
# InventoryBackend
#
# Glossary/Notes:
#     - A Stack's Slot is the Stack's top left placement.
##
tool
extends Node

class_name InventoryBackend

export(Vector2) var inventory_size = Vector2(1, 1) setget set_inventory_size, get_inventory_size;
export(bool) var auto_stack_on_append = true;

const DragDropResource = preload("res/drag_drop.gd");

var _backend_type = "Inventory";
var _inventory = [];

signal inventory_size_changed;
signal item_added;
signal stack_size_changed;
signal stack_moved;
signal stack_removed;

enum DragModifier {
	DRAG_ALL,
	DRAG_SPLIT_HALF
}

enum DryRunStrategy {
	STRAT_NONE,
	STRAT_ADD,
	STRAT_MERGE
}

enum TransferStrategy {
	STRAT_ADD,
	STRAT_SWAP
}


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

	func get_max_stack_size():
		return get_item().get_max_stack_size();
		
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
		
	# Removes from stack, returns how much has actually been removed
	func _remove_from_stack(amount):
		var real_amount = clamp(amount, 0, get_max_stack_size());
		_stack_size = _stack_size - real_amount;
		return real_amount;

	# Adds to the entry's stack, returns the amount remaining.
	func add_to_stack(amount):
		var max_stack_size = get_item().get_max_stack_size();

		# If adding the amount would put the stack size over the limit then
		# just set the stack size to max.
		if(_stack_size + amount > max_stack_size):
			var remaining_amount = amount - _stack_size;
			_stack_size = max_stack_size;
			return remaining_amount;
		else:
			_stack_size += amount;
			return 0;
		
	func _set_slot(new_slot):
		_slot = new_slot;


#==========================================================================
# Public
#==========================================================================

func get_backend_type():
	return _backend_type;

func get_inventory_size():
	return inventory_size;

# Resizes the inventory, be careful with this as this will truncate your
# inventory if you make it smaller.
func set_inventory_size(new_size):
	inventory_size = new_size;
	# TODO: Truncate inventory

	emit_signal("inventory_size_changed", new_size);
	
# Adds an item to the player's inventory at a specific slot. If all items were added successfully to the slot
# then this function returns 0. Any value above 0 is how many items are left over from a stack merge.
func add_item_at(item_uid, slot, amount = 1):
	if(ItemDatabase.get_item(item_uid) == null):
		return amount;

	# If we have the same item UID at the slot, then attempt to stack
	var inventory_entry = get_stack_at(slot);
	if(inventory_entry != null):
		if(inventory_entry.get_item_uid() == item_uid):
			return add_to_stack(inventory_entry.get_id(), amount);
		
	if(would_be_in_bounds(item_uid, slot) && can_item_fit(item_uid, slot)):
		var inventory_item_id = _add_to_inventory_list(item_uid, slot, amount);
		emit_signal("item_added", _inventory[inventory_item_id]);
		return 0;
		
	return amount;

# Adds an item into the "offscreen" buffer. Most commonly used to push an item
# into the inventory then use `move_item` to move it into the correct location.
func add_item(item_uid, amount = 1):
	return _add_to_inventory_list(item_uid, Vector2(-1, -1), amount);
	
# Appends an item to the inventory, attempting to find a spare slot for it.
# `item_id` should be a valid item ID that's been registered to the global item database.
func append_item(item_uid, amount = 1):
	var item = ItemDatabase.get_item(item_uid);
	if(item == null):
		return 0;
		
	var item_max_stack_size = item.get_max_stack_size();
		
	var amount_added = 0;
		
	# Stack onto existing items in the inventory as much as possible
	if(auto_stack_on_append && item.get_max_stack_size() > 1):
		for y in range(inventory_size.y):
			for x in range(inventory_size.x):
				var stack_id = get_id_at_slot(Vector2(x, y));
				if(stack_id == -1):
					continue;

				var stack = get_stack_from_id(stack_id);

				# Only if it's the same item UID and it's not at max stack
				if(stack.get_item_uid() == item_uid && !stack.at_max_stack()):
					var stack_size = stack.get_stack_size();
					var item_stack_remainder = item_max_stack_size - stack_size;
					
					# Can't put any more on this stack
					if(item_stack_remainder == 0):
						continue;
						
					# Calculate amount left after we add to this stack
					var amount_left = amount - item_stack_remainder;
					if(amount_left <= 0):
						set_stack_size(stack.get_id(), stack_size + amount);
						amount_added += amount;
						amount = 0;
					else:
						set_stack_size(stack.get_id(), item_max_stack_size);
						amount_added += item_max_stack_size;
						amount = amount_left;
	
	if(amount > 0):
		# At this point, we know that all the existing same items have been stacked
		# fully. So we are adding new entries to the inventory now.
		var amount_left = amount;
		while true:
			var slot = find_slot_for_item(item_uid);
			if(slot.x > -1 && slot.y > -1):
				var stack_id = -1;
				
				# Last of the stacks
				if(amount_left < item.get_max_stack_size()):
					stack_id = _add_to_inventory_list(item_uid, slot, amount_left);
					amount_added += amount_left;
					amount_left = 0;
				else:
					stack_id = _add_to_inventory_list(item_uid, slot, item.get_max_stack_size());
					amount_added += item.get_max_stack_size();
					amount_left -= item.get_max_stack_size();
					
				emit_signal("item_added", _inventory[stack_id]);
				
				if(amount_left <= 0):
					break;
			# Cannot find a free slot for this new item stack
			else:
				break;
				
	return amount_added;
	
# Sets the inventory item stack size
func set_stack_size(stack_id, new_size):
	if(!_inventory[stack_id]):
		return false;
		
	_inventory[stack_id].set_stack_size(new_size);
	
	emit_signal("stack_size_changed", _inventory[stack_id]);
	
# Moves inventory item from where it is currently to `slot`. Can split a stack by specifying the amount
# that is required to move. Function also attempts to stack ontop of destination.
func move_stack(stack_id, to_slot, amount = -1):
	var from_stack = get_stack_from_id(stack_id);
	var item_uid   = from_stack.get_item_uid();

	# If amount is left default then it means we should move the entire stack
	if(amount == -1):
		amount = from_stack.get_stack_size();

	var result = {
		"remaining": from_stack.get_stack_size(),
		"moved": 0
	};

	# Stops the amount to be moved from being over the size of the stack
	amount = clamp(amount, 0, from_stack.get_stack_size());

	# Moving from and to the exact same slot then return same amount
	if(from_stack.get_slot() == to_slot):
		# If moving the entire stack then it's a move
		if(amount == from_stack.get_stack_size()):
			emit_signal("stack_moved", _inventory[stack_id]);
		else:
			emit_signal("stack_size_changed", _inventory[stack_id]);

		result["moved"]     = amount;
		result["remaining"] = 0;

		return result;

	# Moved to the exact slot that has the same item UID then attempt to stack
	var to_stack = get_stack_in(to_slot); # Could be null if moving to an empty slot
	if(to_stack != null && to_stack.get_item_uid() == item_uid):
		if(!to_stack.at_max_stack()):
			var amount_remaining = add_to_stack(to_stack.get_id(), amount);
			var amount_transferred = amount - amount_remaining;
			remove_from_stack(stack_id, amount_transferred);

			result["moved"]     = amount;
			result["remaining"] = from_stack.get_stack_size();

			return result;
		else:
			# No real move, item just moved back to where it came from
			emit_signal("stack_moved", _inventory[stack_id]);
			return result;

	# Moved out of bounds (item boundry breaches inventory bounds)
	if(!would_be_in_bounds(item_uid, to_slot)):
		emit_signal("stack_moved", _inventory[stack_id]);
		return result;

	# If we hit nothing, then we are free to move the amount into the slot
	var sweep_result = sweep(item_uid, to_slot);
	if(sweep_result.size() == 0):
		if(amount == from_stack.get_stack_size()):
			# Move then entire stack
			set_stack_slot(stack_id, to_slot);

			result["moved"]     = amount;
			result["remaining"] = 0;
		else:
			# Remove the amount off the stack. If the entire stack is removed then the stack
			# itself will be removed from the inventory.
			var amount_left = remove_from_stack(stack_id, amount);
	
			# Add it to the destination
			add_item_at(from_stack.get_item_uid(), to_slot, amount);
	
			result["moved"]     = amount;
			result["remaining"] = amount_left;
	elif(sweep_result.size() == 1):
		if(sweep_result[0] == stack_id && amount == from_stack.get_stack_size()):
			# We hit the same stack, and we are moving the whole stack then it's a valid placement
			set_stack_slot(stack_id, to_slot);

			result["moved"]     = amount;
			result["remaining"] = 0;
			
	emit_signal("stack_size_changed", _inventory[stack_id]);
	emit_signal("stack_moved", _inventory[stack_id]);

	return result;
	
# Removes an item at specific ID. This ID can be fetched by using
# get_id_at_slot().
func remove_stack(stack_id):
	if(!_inventory[stack_id]):
		return false;
		
	var item_to_be_removed = _inventory[stack_id];
	
	_inventory[stack_id] = null;
	
	emit_signal("stack_removed", item_to_be_removed);
	
# Attempts to find a physical slot for the item. Ignores stackables.
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
	
# Checks if an item can physically fit at a specific slot. Ignores stackables altogether.
func can_item_fit(item_uid, slot, mask = []):
	if(ItemDatabase.get_item(item_uid) == null):
		return false;
		
	if(!would_be_in_bounds(item_uid, slot)):
		return false;
		
	if(sweep(item_uid, slot, mask).size() == 0):
		return true;
	return false;

# Does a dry run to see if the item will fit where
func dry_run_item_at(item_uid, slot, amount):
	var results = {
		"strategy": DryRunStrategy.STRAT_NONE,
		"amount": 0
	};

	# No such item or item would be out of bounds in this slot
	if(ItemDatabase.get_item(item_uid) == null):
		return results;
	if(!would_be_in_bounds(item_uid, slot)):
		return results;

	# If the stack directly at the slot is the same item UID and the stack is not full then
	# automatically merge and calculate how many could fit onto the stack.
	var stack_at_slot = get_stack_at(slot);
	if(stack_at_slot && item_uid == stack_at_slot.get_item_uid() && !stack_at_slot.at_max_stack()):
		results["strategy"] = DryRunStrategy.STRAT_MERGE;
		
		var available_amount = stack_at_slot.get_max_stack_size() - stack_at_slot.get_stack_size();
		if(available_amount - amount < 0):
			results["amount"] = available_amount;
		else:
			results["amount"] = amount;

		return results;
		
	var sweep_results = sweep(item_uid, slot);

	# If sweep came up with nothing
	if(sweep_results.size() == 0):
		results["strategy"] = DryRunStrategy.STRAT_ADD;
		results["amount"]   = amount;

	return results;

	
# Checks if an inventory item can fit into a specific slot. This function is mainly used for
# moving items that are already in the inventory around.
func can_stack_fit(stack_id, slot, mask = []):
	var item_uid = _inventory[stack_id].get_item_uid();
	
	if(!would_be_in_bounds(item_uid, slot)):
		return false;
		
	var sweep_result = sweep(item_uid, slot, mask);
	
	# Not colliding with anything
	if(sweep_result.size() == 0):
		return true;
	# Colliding with only itself
	elif(sweep_result.size() == 1 && sweep_result[0] == stack_id):
		return true;

	return false;

func get_item_uid(stack_id):
	var stack = get_stack_from_id(stack_id);
	if(stack):
		return stack.get_item_uid();
	return "";
	
func clear_inventory():
	# TODO: Cleaner cleanup; send corresponding signal out to inform listeners of 
	#       each stack that was removed.
	_inventory.clear();


#==========================================================================
# Generic Backend Functions
#==========================================================================

func transfer(from_backend, to_slot, amount, item_uid, transfer_data):
	# Different strategy if moving internally
	if(from_backend == self):
		move_stack(transfer_data["stack_id"], to_slot, amount);
	else:
		# Confer with the originating backend that this is a valid transfer
		var validate_result = from_backend.validate_transfer(amount, item_uid, transfer_data);
		if(validate_result == true):
			# Check if the item fit will in here
			var dry_run_results = dry_run_item_at(item_uid, to_slot, amount);
			if(dry_run_results["amount"] > 0):
				from_backend.handle_transfer(dry_run_results["amount"], transfer_data);
				
				# Handle the different strategies
				if(dry_run_results["strategy"] == DryRunStrategy.STRAT_ADD):
					add_item_at(item_uid, to_slot, amount);
				elif(dry_run_results["strategy"] == DryRunStrategy.STRAT_MERGE):
					var stack_id = get_id_at_slot(to_slot);
					add_to_stack(stack_id, amount);

func validate_transfer(amount, _item_uid, transfer_data):
	if(!transfer_data.has("stack_id")):
		return false;

	var stack = get_stack_from_id(transfer_data["stack_id"]);
	if(amount > stack.get_stack_size()):
		return false;

	if(transfer_data.has("strategy") && transfer_data["strategy"] == TransferStrategy.STRAT_SWAP && transfer_data.has("item_uid")):
		# Look for a space to put this item
		var slot = find_slot_for_item(transfer_data["item_uid"]);
		if(slot == Vector2(-1, -1)):
			return false;
		else:
			return true;
	
	return true;

func handle_transfer(amount, transfer_data):
	if(transfer_data.has("stack_id")):
		remove_from_stack(transfer_data["stack_id"], amount);

		if(transfer_data.has("strategy") && transfer_data["strategy"] == TransferStrategy.STRAT_SWAP && transfer_data.has("item_uid")):
			append_item(transfer_data["item_uid"], 1);


#==========================================================================
# Private
#==========================================================================	

func add_to_stack(stack_id, amount):
	if(_inventory[stack_id] == null):
		return 0;
		
	var remaining_amount = _inventory[stack_id].add_to_stack(amount);
	
	emit_signal("stack_size_changed", _inventory[stack_id]);

	return remaining_amount;

# Warning: This does not check for collisions, do this manually.
func set_stack_slot(stack_id, new_slot):
	if(_inventory[stack_id] == null):
		return false;

	_inventory[stack_id]._set_slot(new_slot);
	emit_signal("stack_moved", _inventory[stack_id]);

	return true;
	
# Removes `amount` from stack. Will remove from inventory if removing more than
func remove_from_stack(stack_id, amount):
	if(!_inventory[stack_id]):
		return 0;
		
	_inventory[stack_id]._remove_from_stack(amount);

	# If we have removed everything from the stack then remove it from the inventory
	# entirely.
	if(_inventory[stack_id].get_stack_size() <= 0):
		remove_stack(stack_id);
		return 0;
	else:
		emit_signal("stack_size_changed", _inventory[stack_id]);
	
	return _inventory[stack_id].get_stack_size();

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

# Gets the stack that occupies this physical slot.
func get_stack_at(slot):
	var id = get_id_at_slot(slot);
	if(id == -1):
		return null;

	return _inventory[id];

# Gets the stack that is located in this slot.
func get_stack_in(slot):
	for stack in _inventory:
		if(stack != null && stack.get_slot() == slot):
			return stack;

	return null;

func get_stack_from_id(stack_id):
	if(stack_id < 0 || stack_id >= _inventory.size()):
		return null;
		
	return _inventory[stack_id];
	
# Returns an array of collided stack IDs if this item were to be put in `slot`.
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
			
		# Ignore stack IDs that are in the mask list
		if(mask.find(i) > -1):
			continue;
			
		if(_inventory[i].in_range()):
			if(_inventory[i].get_rect().intersects(item_rect)):
				collision_list.append(i);
		
	return collision_list;
	
# Call this when the player begins a drag from the inventory.
func get_base_drag_data(slot, drag_modifier = DragModifier.DRAG_ALL):
	var stack_id = get_id_at_slot(slot);

	if(!is_valid_id(stack_id)):
		return null;

	var stack = get_stack_from_id(stack_id);
	
	var stack_size = stack.get_stack_size();
	if(drag_modifier == DragModifier.DRAG_SPLIT_HALF):
		stack_size = ceil(stack_size / 2);
		
	var drag_drop_res = DragDropResource.new();
	drag_drop_res.source     = "inventory";
	drag_drop_res.stack_id   = stack_id;
	drag_drop_res.item_uid   = stack.get_item_uid();
	drag_drop_res.slot       = slot;
	drag_drop_res.stack_size = stack_size;
	drag_drop_res.backend    = self;
	
	return drag_drop_res;


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