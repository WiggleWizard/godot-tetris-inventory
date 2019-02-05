extends Node

var _backend = null;

func _ready():
	# Register the test items first
	var load_result = ItemDatabase.load_json_db("res://addons/tetris-inventory/tests/test_database.json");
	if(!load_result):
		print("Failed to load test database from disk");
		return false;

	_backend = InventoryBackend.new();
	_backend.set_inventory_size(Vector2(10, 10));
	
	var test_pass = false;
	for method in get_method_list():
		if(method["name"].begins_with("test")):
			var m = funcref(self, method["name"]);

			# Run the test
			var test_state = m.call_func();

			if(test_state.has("dry_run_pass")):
				test_pass = test_state["dry_run_pass"];
			else:
				# Confirm the inventory is in a state we expected
				test_pass = confirm_inventory_state(test_state["expected_state"]);
				
			_backend.clear_inventory();

			if(test_pass == true):
				print("[+] " + test_state["test"] + " [PASSED]");
			else:
				print("[!] " + test_state["test"] + " [FAILED]");
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
	_backend.move_stack(_backend.get_id_at_slot(Vector2(0, 0)), Vector2(1, 0));

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
	_backend.move_stack(_backend.get_id_at_slot(Vector2(0, 0)), Vector2(1, 0), 25);

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
	_backend.move_stack(_backend.get_id_at_slot(Vector2(0, 0)), Vector2(1, 0), 9999);

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
	_backend.move_stack(_backend.get_id_at_slot(Vector2(0, 0)), Vector2(1, 0), 25);
	_backend.move_stack(_backend.get_id_at_slot(Vector2(0, 0)), Vector2(1, 0), 25);

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
	_backend.move_stack(_backend.get_id_at_slot(Vector2(0, 0)), Vector2(0, 1), 20);
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

func test7():
	_backend.append_item("test_2", 1);
	_backend.move_stack(_backend.get_id_at_slot(Vector2(0, 0)), Vector2(1, 0));
	
	return {
		"test": "Can move ontop of self",
		"expected_state": [
			{
				"uid": "test_2",
				"slot": Vector2(1, 0),
				"stack_size": 1
			}
		]
	};

func test8():
	var dry_run_result = _backend.dry_run_item_at("test_2", Vector2(0, 0), 1);

	var dry_run_pass = false;
	if(dry_run_result["amount"] == 1 && dry_run_result["strategy"] == InventoryBackend.DryRunStrategy.STRAT_ADD):
		dry_run_pass = true;

	return {
		"test": "Dry run with nothing in inventory",
		"dry_run_pass": dry_run_pass
	};

func test9():
	_backend.append_item("test_2", 1);
	var dry_run_result = _backend.dry_run_item_at("test_2", Vector2(0, 1), 1);

	var dry_run_pass = false;
	if(dry_run_result["amount"] == 0):
		dry_run_pass = true;

	return {
		"test": "Dry run with something in inventory",
		"dry_run_pass": dry_run_pass
	};

func test10():
	var dry_run_result = _backend.dry_run_item_at("test_2", Vector2(0, 8), 1);

	var dry_run_pass = false;
	if(dry_run_result["amount"] == 0):
		dry_run_pass = true;

	return {
		"test": "Dry run item not within bounds",
		"dry_run_pass": dry_run_pass
	};

func confirm_inventory_state(state):
	for state_entry in state:
		var stack = _backend.get_stack_in(state_entry["slot"]);
		if(!stack):
			if(state_entry["uid"] == null):
				continue;

			return false;

		if(stack != null && state_entry["uid"] == null):
			return false;

		if(stack.get_item_uid() != state_entry["uid"] || stack.get_stack_size() != state_entry["stack_size"]):
			return false;

	return true;
