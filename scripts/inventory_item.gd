extends Control


func set_display_data(texture, clip_offset, clip_size):
	$Sprite.set_texture(texture);
	$Sprite.region_enabled = true;
	$Sprite.set_region_rect(Rect2(clip_offset, clip_size));