extends Node

var _backend = null;

func _ready():
	# Register the test items first
	var load_result = ItemDatabase.load_json_db("res://addons/tetris-inventory/tests/test_database.json");
	if(!load_result):
		print("Failed to load test database from disk");
		return false;

	_backend = Inventory.new();
	_backend.set_inventory_size(Vector2(10, 10));
	
	var test_pass = false;
	for method in get_method_list():
		if(method["name"].begins_with("test")):
			var m = funcref(self, method["name"]);

			# Run the test
			var test_state = m.call_func();

			# Confirm the inventory is in a state we expected
			test_pass = confirm_inventory_state(test_state["expected_state"]);
			_backend.clear_inventory();

			if(test_pass == true):
				print("[+] " + test_state["test"] + " [PASSED]");
			else:
				print("[!] " + test_state["test"] + " [FAILED]");
				print("/!\\ Deprecated");
				break;
		
	if(test_pass):
		print("Tests passed");


func test1():
	_backend.append_item("test_1", 75);

	return {
		"test": "Appending",
		"expected_state": [
			{
				"uid": "test_1",
				"slot": Vector2(0, 0),
				"stack_size": 50
			},
			{
				"uid": "test_1",
				"slot": Vector2(1, 0),
				"stack_size": 25
			}
		]
	};

func test2():
	_backend.append_item("test_1", 50);
	_backend.move_item(_backend.get_id_at_slot(Vector2(0, 0)), Vector2(1, 0));

	return {
		"test": "Moving full stack to open slot",
		"expected_state": [
			{
				"uid": "test_1",
				"slot": Vector2(1, 0),
				"stack_size": 50
			}
		]
	};

func test3():
	_backend.append_item("test_1", 50);
	_backend.move_item(_backend.get_id_at_slot(Vector2(0, 0)), Vector2(1, 0), 25);

	return {
		"test": "Halving stack",
		"expected_state": [
			{
				"uid": "test_1",
				"slot": Vector2(0, 0),
				"stack_size": 25
			},
			{
				"uid": "test_1",
				"slot": Vector2(1, 0),
				"stack_size": 25
			}
		]
	};

func test4():
	_backend.append_item("test_1", 50);
	_backend.move_item(_backend.get_id_at_slot(Vector2(0, 0)), Vector2(1, 0), 9999);

	return {
		"test": "Overmoving",
		"expected_state": [
			{
				"uid": "test_1",
				"slot": Vector2(1, 0),
				"stack_size": 50
			},
		]
	};

func test5():
	_backend.append_item("test_1", 50);
	_backend.move_item(_backend.get_id_at_slot(Vector2(0, 0)), Vector2(1, 0), 25);
	_backend.move_item(_backend.get_id_at_slot(Vector2(0, 0)), Vector2(1, 0), 25);

	return {
		"test": "Halving then remerging",
		"expected_state": [
			{
				"uid": null,
				"slot": Vector2(0, 0)
			},
			{
				"uid": "test_1",
				"slot": Vector2(1, 0),
				"stack_size": 50
			}
		]
	};

func test6():
	_backend.append_item("test_1", 75);
	_backend.append_item("test_1", 75);
	_backend.move_item(_backend.get_id_at_slot(Vector2(0, 0)), Vector2(0, 1), 20);
	_backend.append_item("test_1", 10);

	return {
		"test": "Appending after modification",
		"expected_state": [
			{
				"uid": "test_1",
				"slot": Vector2(0, 0),
				"stack_size": 40
			},
			{
				"uid": "test_1",
				"slot": Vector2(1, 0),
				"stack_size": 50
			},
			{
				"uid": "test_1",
				"slot": Vector2(2, 0),
				"stack_size": 50
			},
			{
				"uid": "test_1",
				"slot": Vector2(0, 1),
				"stack_size": 20
			}
		]
	};

func confirm_inventory_state(state):
	for state_entry in state:
		var stack = _backend.get_inventory_item_at_slot(state_entry["slot"]);
		if(!stack):
			if(state_entry["uid"] == null):
				continue;

			return false;

		if(stack != null && state_entry["uid"] == null):
			return false;

		if(stack.get_item_uid() != state_entry["uid"] || stack.get_stack_size() != state_entry["stack_size"]):
			return false;

	return true;
