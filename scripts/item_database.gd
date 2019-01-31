extends Node

class_name ItemDB

var _item_type_script_map = {};
var _item_map             = {};
var _item_database        = {};

var _generic_db_path = "res://item_database.json";


func _ready():
	# Attempt to load a generic path
	if(File.file_exists(_generic_db_path)):
		load_json_db(_generic_db_path);
	
func get_item(uid):
	if(_item_database.has(uid)):
		return _item_database[uid];
	return null;
	
func map_type_to_script_path(type):
	if(_item_type_script_map.has(type)):
		return _item_type_script_map[type];
	return null;
		
func load_json_db(path):
	var file = File.new();
	file.open(path, file.READ);
	var data = file.get_as_text();
	var parse_result = JSON.parse(data);
	file.close();
	
	if(parse_result.error == OK):
		if(parse_result.result.has("item_type_script_map")):
			_item_type_script_map = parse_result.result["item_type_script_map"];
		if(parse_result.result.has("items")):
			_item_map = parse_result.result["items"];
	else:
		print("Error parsing item database on line " + str(parse_result.error_line) + ": ", parse_result.error);
		return false;
		
	# Map all the items in the map to instanced objects within the database
	for key in _item_map:
		var item_instance = null;
		
		# Figure out the script mapping for this object and create a new 
		var item_script_path = map_type_to_script_path(_item_map[key]["type"]);
		if(item_script_path != null):
			item_instance = load(item_script_path).new();
		else:
			item_instance = ItemBase.new();
			
		# Pour the base properties into the item
		var item_dict = _item_map[key];
		item_instance._uid  = key;
		item_instance._type = item_dict["type"];
		item_instance._name = item_dict["name"];
		
		item_instance._inventory_size = Vector2(item_dict["slots_in_inventory"]["width"], item_dict["slots_in_inventory"]["height"]);
		
		_item_database[key] = item_instance;
			
	return true;