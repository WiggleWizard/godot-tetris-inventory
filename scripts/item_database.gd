extends Node

class_name ItemDB

var _database = {};


# Adds an item into the database. Returns true if successful.
func register_new_item(uid, new_item):
	if(!get_item(uid)):
		_database[uid] = new_item;
		new_item._uid = uid;
		
		return true;
		
	return false;
	
func get_item(uid):
	if(_database.has(uid)):
		return _database[uid];
	return null;