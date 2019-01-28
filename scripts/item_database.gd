extends Node

class_name ItemDB

var _database = [];


# Adds an item into the database, and returns its ID.
func register_new_item(new_item):
	for i in range(_database.size()):
		if(_database[i] == null):
			_database[i] = new_item;
			new_item._id = i;
			
			return new_item._id;
			
	_database.append(new_item);
	new_item._id = _database.size() - 1;
	return new_item._id;
	
func get_item(id):
	return _database[id];