extends Control

class_name InventoryItemDropZone

export(bool) var remove_from_source = false;

var _mouse_event_sink = null;


func _ready():
	_mouse_event_sink = Control.new();
	add_child(_mouse_event_sink);
	
	_mouse_event_sink.set_drag_forwarding(self);
	_mouse_event_sink.set_anchors_and_margins_preset(Control.PRESET_WIDE);

func can_drop_data_fw(position, data, from_control):
	return true;
	
func drop_data_fw(position, data, from_control):
	print("DROPPED IN DROP ZONE");
	var source_node = data["source_node"];
	if(source_node && source_node.has_method("_on_drop_zone_drop")):
		source_node._on_drop_zone_drop(remove_from_source);

func can_drop_data(position, data):
	return true;
	
func drop_data(position, data):
	print(data);