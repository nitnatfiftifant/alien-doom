extends SceneTree

func _init() -> void:
	var appdata := OS.get_environment("APPDATA")
	var target_directories: Array[String] = []
	if not appdata.is_empty():
		target_directories.append(appdata.path_join("TrenchBroom/games/AlienDoom"))
	
	for candidate: String in ["D:/BeProgrammer/TrenchBroom/games/AlienDoom", "C:/Program Files/TrenchBroom/games/AlienDoom"]:
		var parent_dir: String = candidate.get_base_dir().get_base_dir()
		if DirAccess.dir_exists_absolute(parent_dir) and not target_directories.has(candidate):
			target_directories.append(candidate)
	
	if target_directories.is_empty():
		push_error("No TrenchBroom games directories found.")
		quit(1)
		return

	var project_path := ProjectSettings.globalize_path("res://")
	var primary_config_path := target_directories[0]
	DirAccess.make_dir_recursive_absolute(primary_config_path)

	var local_config_path := "res://addons/func_godot/func_godot_local_config.tres"
	if not FileAccess.file_exists(local_config_path):
		var template := "[gd_resource type=\"Resource\" script_class=\"FuncGodotLocalConfig\" format=3 uid=\"uid://bqjt7nyekxgog\"]\n\n[ext_resource type=\"Script\" uid=\"uid://xsjnhahhyein\" path=\"res://addons/func_godot/src/util/func_godot_local_config.gd\" id=\"1_g8kqj\"]\n\n[resource]\nscript = ExtResource(\"1_g8kqj\")\n"
		var cf := FileAccess.open(local_config_path, FileAccess.WRITE)
		if cf:
			cf.store_string(template)
			cf.close()

	var local_config := load(local_config_path) as FuncGodotLocalConfig
	if local_config:
		local_config.set("fgd_output_folder", primary_config_path)
		local_config.set("trenchbroom_game_config_folder", primary_config_path)
		local_config.set("map_editor_game_path", project_path)
		local_config.export_func_godot_settings()

	var game_config := load("res://fgd/game_config.tres") as TrenchBroomGameConfig
	if game_config:
		game_config.export_file()
	
	# Sanitize GameConfig.cfg: remove 'attribute: wad' and empty 'palette: ""' so TrenchBroom
	# treats textures as internal directory collections and auto-loads all subfolders.
	var cfg_path := primary_config_path.path_join("GameConfig.cfg")
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
	
	var initial_map_src := ProjectSettings.globalize_path("res://maps/ventilation_blockout.map")
	if FileAccess.file_exists(initial_map_src):
		DirAccess.copy_absolute(initial_map_src, primary_config_path.path_join("initial_valve.map"))

	# Synchronize all files and editor models across all target directories
	for target_dir: String in target_directories:
		DirAccess.make_dir_recursive_absolute(target_dir)
		if target_dir != primary_config_path:
			for file_name in ["GameConfig.cfg", "AlienDoom.fgd", "icon.png", "initial_valve.map", "GameEngineProfiles.cfg"]:
				var source := primary_config_path.path_join(file_name)
				if FileAccess.file_exists(source):
					DirAccess.copy_absolute(source, target_dir.path_join(file_name))
		
		var model_directory := target_dir.path_join("models/editor")
		DirAccess.make_dir_recursive_absolute(model_directory)
		for model_name in ["alien_spawn.glb", "human_spawn.glb", "nest.glb"]:
			var model_source := ProjectSettings.globalize_path("res://models/editor/" + model_name)
			if FileAccess.file_exists(model_source):
				DirAccess.copy_absolute(model_source, model_directory.path_join(model_name))

	print("ALIEN_DOOM_TRENCHBROOM_EXPORT_OK")
	quit(0)
