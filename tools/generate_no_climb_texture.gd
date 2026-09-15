extends SceneTree

const OUTPUT_PATH := "res://textures/special/no_climb.png"
const SIZE := 128
const CELL := 16

func _init() -> void:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var checker := (int(x / CELL) + int(y / CELL)) % 2
			var color := Color("d51f2e") if checker == 0 else Color("4b0710")
			if absf(float((x + y) % 32) - 16.0) < 3.0:
				color = Color("ffd166")
			image.set_pixel(x, y, color)
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("Failed to save no-climb editor texture: %s" % error_string(error))
		quit(1)
		return
	print("NO_CLIMB_TEXTURE_OK")
	quit()
