extends SceneTree

const SOURCE_PATH := "res://assets/models/PixelTexturePack/PixelTexturePack/Textures"
const TARGET_TEXTURE_ROOT := "res://textures"
const TARGET_MATERIAL_ROOT := "res://materials"

func _init() -> void:
	call_deferred("process_textures")

func process_textures() -> void:
	var da := DirAccess.open(SOURCE_PATH)
	if da == null:
		push_error("Cannot open source textures folder: " + SOURCE_PATH)
		quit(1)
		return
	
	da.list_dir_begin()
	var cat_name := da.get_next()
	var count := 0
	while not cat_name.is_empty():
		if da.current_is_dir() and not cat_name.begins_with("."):
			var cat_dir_path := SOURCE_PATH.path_join(cat_name)
			var cat_da := DirAccess.open(cat_dir_path)
			if cat_da != null:
				var dest_tex_dir := TARGET_TEXTURE_ROOT.path_join(cat_name)
				var dest_mat_dir := TARGET_MATERIAL_ROOT.path_join(cat_name)
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest_tex_dir))
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest_mat_dir))
				
				cat_da.list_dir_begin()
				var file_name := cat_da.get_next()
				while not file_name.is_empty():
					if not cat_da.current_is_dir() and file_name.ends_with(".png"):
						var src_file := cat_dir_path.path_join(file_name)
						var dst_tex_file := dest_tex_dir.path_join(file_name)
						DirAccess.copy_absolute(ProjectSettings.globalize_path(src_file), ProjectSettings.globalize_path(dst_tex_file))
						
						var base_name := file_name.get_basename()
						var dst_mat_file := dest_mat_dir.path_join(base_name + ".tres")
						
						var mat := StandardMaterial3D.new()
						var tex := load(dst_tex_file) as Texture2D
						if tex != null:
							mat.albedo_texture = tex
						mat.metallic_specular = 0.0
						mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
						ResourceSaver.save(mat, dst_mat_file)
						count += 1
					file_name = cat_da.get_next()
				cat_da.list_dir_end()
		cat_name = da.get_next()
	da.list_dir_end()
	
	print("ALIEN_DOOM_PIXEL_TEXTURES_IMPORTED count=%d" % count)
	quit(0)
