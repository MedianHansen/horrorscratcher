import unreal
import os
import glob
import time

OUT = r"D:\Exports\actors"

os.makedirs(OUT, exist_ok=True)
for existing in glob.glob(os.path.join(OUT, "*.glb")):
    os.remove(existing)

world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
ea = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)

opts = unreal.GLTFExportOptions()
opts.bake_material_inputs = unreal.GLTFMaterialBakeMode.USE_MESH_DATA
opts.adjust_normalmaps = True

actors = ea.get_selected_level_actors()
print("selected actors:", len(actors))

stamp = time.strftime("%Y%m%d_%H%M%S")
for actor in actors:
    label = actor.get_actor_label()
    out = os.path.join(OUT, label + "_" + stamp + ".glb")
    unreal.GLTFExporter.export_to_gltf(world, out, opts, {actor})
    size = os.path.getsize(out) if os.path.exists(out) else "MISSING"
    print("exported", out, size)
