import unreal
import os

BP_PATH = "/Game/Creepwood_Carnival_Meshingun/Environment/Blueprint/Ride/BP_FerrisWheel_Ride_01a"
OUT = r"D:\Exports\actors"

os.makedirs(OUT, exist_ok=True)

bp = unreal.EditorAssetLibrary.load_asset(BP_PATH)
if bp is None:
    raise RuntimeError("Could not load blueprint: " + BP_PATH)

cls = bp.generated_class()
ea = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()

actor = ea.spawn_actor_from_class(cls, unreal.Vector(0.0, 0.0, 0.0), unreal.Rotator(0.0, 0.0, 0.0))
try:
    opts = unreal.GLTFExportOptions()
    opts.bake_material_inputs = unreal.GLTFMaterialBakeMode.USE_MESH_DATA
    opts.adjust_normalmaps = True
    out = os.path.join(OUT, os.path.basename(BP_PATH) + ".glb")
    unreal.GLTFExporter.export_to_gltf(world, out, opts, {actor})
    print("exported " + out)
finally:
    ea.destroy_actor(actor)
