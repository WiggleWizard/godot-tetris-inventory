tool
extends MarginContainer

export(Color) var outline_color = Color(1, 1, 1, 0.5) setget set_color;
export(int) var outline_width = 1 setget set_width;
export(Color) var background_color = Color(0, 0, 0, 0.5) setget set_bg_color;

func _draw():
	var rect = get_rect();
	var local_rect = get_rect();
	local_rect.position = Vector2(0, 0);
	
	draw_rect(local_rect, background_color);
	
	var f_outline_width = float(outline_width);
	# Left
	draw_line(Vector2(f_outline_width / 2, f_outline_width), Vector2(f_outline_width / 2, rect.size.y - f_outline_width), outline_color, outline_width);
	# Right
	draw_line(Vector2(rect.size.x - f_outline_width / 2, f_outline_width), Vector2(rect.size.x - f_outline_width / 2, rect.size.y - f_outline_width), outline_color, outline_width);
	
	# Top
	draw_line(Vector2(0, f_outline_width / 2), Vector2(rect.size.x, f_outline_width / 2), outline_color, outline_width);
	# Bottom
	draw_line(Vector2(0, rect.size.y - f_outline_width / 2), Vector2(rect.size.x, rect.size.y - f_outline_width / 2), outline_color, outline_width);
	
	
func set_color(color):
    outline_color = color;
    update();
	
func set_width(new_width):
	outline_width = new_width;
	update();
	
func set_bg_color(new_color):
	background_color = new_color;
	update();
	
func set_display_item(item):
	$Label.set_text(item.get_name());