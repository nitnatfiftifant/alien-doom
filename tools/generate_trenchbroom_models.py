import bpy
import os

OUT = r"C:\Users\nit\Documents\Demos\Jams\alien-doom\models\editor"
os.makedirs(OUT, exist_ok=True)

def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

def mat(name, color):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1.0)
    return material

def cube(name, location, scale, material):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(material)

def sphere(name, location, scale, material):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(material)

def export(name):
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", use_selection=False)

reset()
green = mat("Creature", (0.08, 0.65, 0.16))
cube("Body", (0, 0.28, 0), (0.36, 0.22, 0.52), green)
for x in (-0.32, 0.32):
    for z in (-0.34, 0.34):
        cube("Leg", (x, 0.10, z), (0.10, 0.10, 0.22), green)
export("alien_spawn")

reset()
orange = mat("Human", (0.9, 0.35, 0.08))
cube("Torso", (0, 1.18, 0), (0.28, 0.45, 0.18), orange)
sphere("Head", (0, 1.82, 0), (0.20, 0.20, 0.20), orange)
for x in (-0.36, 0.36):
    cube("Arm", (x, 1.18, 0), (0.09, 0.42, 0.09), orange)
for x in (-0.14, 0.14):
    cube("Leg", (x, 0.48, 0), (0.11, 0.48, 0.12), orange)
export("human_spawn")

reset()
red = mat("Nest", (0.55, 0.03, 0.12))
sphere("Nest", (0, 0.45, 0), (0.9, 0.45, 0.9), red)
export("nest")
