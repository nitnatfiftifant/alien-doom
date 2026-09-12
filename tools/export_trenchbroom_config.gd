extends SceneTree

const TARGET_DIRECTORIES: Array[String] = [
	"C:/Users/nit/AppData/Roaming/TrenchBroom/games/AlienDoom",
	"C:/Users/nit/Documents/TrenchBroom-Win64-AMD64-v2026.2-Release/games/AlienDoom"
]

func _init() -> void:
	var project_path := ProjectSettings.globalize_path("res://")
	var config_path := TARGET_DIRECTORIES[0]
	var local_config := load("res://addons/func_godot/func_godot_local_config.tres") as FuncGodotLocalConfig
	local_config.set("fgd_output_folder", config_path)
	local_config.set("trenchbroom_game_config_folder", config_path)
	local_config.set("map_editor_game_path", project_path)
	local_config.export_func_godot_settings()
	var game_config := load("res://fgd/game_config.tres") as TrenchBroomGameConfig
	game_config.export_file()
	
	# Sanitize GameConfig.cfg: remove 'attribute: wad' and empty 'palette: ""' so TrenchBroom
	# treats textures as internal directory collections and auto-loads all subfolders.
	var cfg_path := config_path.path_join("GameConfig.cfg")
	if FileAccess.file_exists(cfg_path):
		var cfg_content := FileAccess.get_file_as_string(cfg_path)
		var regex := RegEx.new()
		regex.compile(',?\\s*"palette":\\s*""')
		cfg_content = regex.sub(cfg_content, "", true)
		regex.compile(',?\\s*"attribute":\\s*"wad"')
		cfg_content = regex.sub(cfg_content, "", true)
		var f := FileAccess.open(cfg_path, FileAccess.WRITE)
		if f:
			f.store_string(cfg_content)
			f.close()
	
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://maps/ventilation_blockout.map"), config_path + "/initial_valve.map")
	DirAccess.make_dir_recursive_absolute(TARGET_DIRECTORIES[1])
	for file_name in ["GameConfig.cfg", "AlienDoom.fgd", "icon.png", "initial_valve.map"]:
		var source := config_path.path_join(file_name)
		if FileAccess.file_exists(source):
			var error := DirAccess.copy_absolute(source, TARGET_DIRECTORIES[1].path_join(file_name))
			if error != OK:
				push_error("Failed to copy %s to bundled TrenchBroom: %s" % [file_name, error_string(error)])
	print("ALIEN_DOOM_TRENCHBROOM_EXPORT_OK")
	quit(0)
