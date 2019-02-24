extends Resource

class_name DragDropResource


export(String) var source = "";
export(int) var stack_id  = -1;
export(String) var item_uid = "";
export(Vector2) var slot      = Vector2(-1, -1);
export(int) var stack_size    = -1;
export(PackedScene) var backend = null;

export(PackedScene) var frontend = null;
export(PackedScene) var mapped_node = null;
export(Vector2) var mouse_down_offset = Vector2(0, 0);