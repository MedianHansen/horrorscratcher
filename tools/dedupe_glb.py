import json
import struct
import sys

JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942
GLB_MAGIC = 0x46546C67


def read_glb(path):
    data = open(path, "rb").read()
    magic, version, length = struct.unpack("<III", data[:12])
    if magic != GLB_MAGIC:
        raise ValueError("not a GLB file")
    pos = 12
    doc = None
    bin_chunk = b""
    while pos < length:
        clen, ctype = struct.unpack("<II", data[pos:pos + 8])
        chunk = data[pos + 8:pos + 8 + clen]
        if ctype == JSON_CHUNK:
            doc = json.loads(chunk)
        elif ctype == BIN_CHUNK:
            bin_chunk = chunk
        pos += 8 + clen
    return doc, bin_chunk


def write_glb(path, doc, bin_chunk):
    js = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    bc = bin_chunk
    if bin_chunk:
        bc = bin_chunk + b"\x00" * ((4 - len(bin_chunk) % 4) % 4)
    total = 12 + 8 + len(js) + (8 + len(bc) if bc else 0)
    out = struct.pack("<III", GLB_MAGIC, 2, total)
    out += struct.pack("<II", len(js), JSON_CHUNK) + js
    if bc:
        out += struct.pack("<II", len(bc), BIN_CHUNK) + bc
    open(path, "wb").write(out)


def dedupe(doc):
    materials = doc.get("materials", [])
    mat_key = {}
    mat_remap = [0] * len(materials)
    new_materials = []
    for i, m in enumerate(materials):
        key = json.dumps({k: v for k, v in m.items() if k != "name"}, sort_keys=True)
        if key in mat_key:
            mat_remap[i] = mat_key[key]
        else:
            mat_key[key] = len(new_materials)
            mat_remap[i] = len(new_materials)
            new_materials.append(m)

    meshes = doc.get("meshes", [])
    mesh_key = {}
    mesh_remap = [0] * len(meshes)
    new_meshes = []
    for i, m in enumerate(meshes):
        prims = []
        for p in m["primitives"]:
            pp = dict(p)
            if "material" in pp:
                pp["material"] = mat_remap[pp["material"]]
            prims.append(pp)
        key = json.dumps(prims, sort_keys=True)
        if key in mesh_key:
            mesh_remap[i] = mesh_key[key]
        else:
            mesh_key[key] = len(new_meshes)
            mesh_remap[i] = len(new_meshes)
            new_meshes.append({"name": m.get("name", "mesh"), "primitives": prims})

    for n in doc.get("nodes", []):
        if "mesh" in n:
            n["mesh"] = mesh_remap[n["mesh"]]

    doc["materials"] = new_materials
    doc["meshes"] = new_meshes
    return len(materials), len(new_materials), len(meshes), len(new_meshes)


def main():
    src = sys.argv[1]
    dst = sys.argv[2] if len(sys.argv) > 2 else src
    doc, bin_chunk = read_glb(src)
    before = (len(doc.get("materials", [])), len(doc.get("meshes", [])))
    mb, ab, mm, am = dedupe(doc)
    write_glb(dst, doc, bin_chunk)
    print("materials %d -> %d | meshes %d -> %d" % (mb, ab, mm, am))
    if src != dst:
        print("wrote " + dst)


if __name__ == "__main__":
    main()
