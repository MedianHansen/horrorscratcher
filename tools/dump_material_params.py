import unreal
import json

OUT = r"D:\Exports\material_params.json"

mel = unreal.MaterialEditingLibrary

ar = unreal.AssetRegistryHelpers.get_asset_registry()
assets = ar.get_assets(unreal.ARFilter(
    class_paths=[unreal.TopLevelAssetPath("/Script/Engine", "MaterialInstanceConstant")],
    package_paths=["/Game"],
    recursive_paths=True,
))

out = {}
for a in assets:
    m = unreal.EditorAssetLibrary.load_asset(str(a.package_name))
    if m is None:
        continue
    entry = {"textures": {}, "vectors": {}, "scalars": {}, "parent": str(m.get_editor_property("parent"))}
    for group, names_fn, getter_fn, fallback_fn in (
        ("textures", "get_texture_parameter_names", "get_material_instance_texture_parameter_value", "get_texture_parameter_value"),
        ("vectors", "get_vector_parameter_names", "get_material_instance_vector_parameter_value", "get_vector_parameter_value"),
        ("scalars", "get_scalar_parameter_names", "get_material_instance_scalar_parameter_value", "get_scalar_parameter_value"),
    ):
        try:
            names = getattr(mel, names_fn)(m)
        except Exception:
            names = []
        for n in names:
            value = None
            for fn in (getter_fn, fallback_fn):
                try:
                    value = getattr(mel, fn)(m, n)
                    break
                except Exception:
                    value = None
            entry[group][str(n)] = str(value)
    out[str(a.asset_name)] = entry

with open(OUT, "w") as fh:
    json.dump(out, fh, indent=1)
print("wrote", OUT, "with", len(out), "material instances")
