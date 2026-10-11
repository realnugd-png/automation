"""
Builds the low-poly luxury props for "Become An Millionaire RNG" in Blender
and exports one FBX per prop for Roblox Studio's 3D Importer.

Run (Blender 3.6+ / 4.x / 5.x):
    blender --background --python blender/build_models.py
or with the standalone bpy module:
    python blender/build_models.py

Outputs (relative to the roblox/ folder):
    assets/models/<Prop>.fbx     one file per prop, import into ServerStorage.Models
    assets/models/Props.blend    editable source scene with every prop
    assets/models/preview.png    rendered preview of all props

Every mesh object is named "<Palette>_<Part>" (e.g. "Gold_Bowl"). MapService
recolours imported MeshParts from that prefix, so colours/materials are right
in Roblox even if the importer drops material colours.

Prop names must match MapService PROP names: Fountain, Tree, PalmTree, Lamp,
GoldBars, VaultDoor, SlotMachine, Dice, PortalArch.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "assets", "models"))

# Palette shared with MapService (sRGB 0-255).
PALETTE = {
    "Gold": (255, 196, 64),
    "Marble": (236, 232, 224),
    "Dark": (28, 26, 32),
    "Water": (80, 170, 230),
    "Leaf": (70, 140, 60),
    "Palm": (60, 150, 70),
    "Wood": (110, 75, 45),
    "Bark": (150, 110, 70),
    "Steel": (150, 155, 165),
    "Red": (150, 20, 40),
    "White": (245, 245, 245),
    "Pip": (200, 20, 40),
    "Glow": (255, 236, 180),
    "Neon": (60, 230, 255),
}


def srgb_to_linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(name):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    r, g, b = (srgb_to_linear(v) for v in PALETTE[name])
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (r, g, b, 1.0)
    metallic = name in ("Gold", "Steel")
    bsdf.inputs["Metallic"].default_value = 0.9 if metallic else 0.0
    bsdf.inputs["Roughness"].default_value = 0.25 if metallic else 0.6
    if name in ("Glow", "Neon"):
        emission = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
        emission.default_value = (r, g, b, 1.0)
        strength = bsdf.inputs.get("Emission Strength")
        if strength:
            strength.default_value = 3.0
    mat.diffuse_color = (r, g, b, 1.0)  # viewport / workbench colour
    return mat


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def finish(obj, palette, part, collection, location=None, rotation=None, smooth=False):
    obj.name = f"{palette}_{part}"
    obj.data.name = obj.name
    obj.data.materials.clear()
    obj.data.materials.append(material(palette))
    if location is not None:
        obj.location = location
    if rotation is not None:
        obj.rotation_euler = rotation
    if smooth:
        for poly in obj.data.polygons:
            poly.use_smooth = True
    for c in obj.users_collection:
        c.objects.unlink(obj)
    collection.objects.link(obj)
    return obj


def cylinder(collection, palette, part, radius, depth, location, vertices=24, rotation=None, smooth=True):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth)
    return finish(bpy.context.active_object, palette, part, collection, location, rotation, smooth)


def cone(collection, palette, part, r1, r2, depth, location, vertices=24, rotation=None):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2, depth=depth)
    return finish(bpy.context.active_object, palette, part, collection, location, rotation, True)


def box(collection, palette, part, size, location, rotation=None, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.active_object
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj, palette, part, collection, location, rotation)


def sphere(collection, palette, part, radius, location, subdivisions=2, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius)
    obj = bpy.context.active_object
    obj.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return finish(obj, palette, part, collection, location, None, True)


def torus(collection, palette, part, major, minor, location, rotation=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=32, minor_segments=10)
    return finish(bpy.context.active_object, palette, part, collection, location, rotation, True)


# ---------------------------------------------------------------------------
# Props (Blender Z-up; 1 unit ~ 1 stud; MapService rescales to fit anyway)
# ---------------------------------------------------------------------------

def build_fountain(c):
    cylinder(c, "Marble", "Basin", 13, 2.4, (0, 0, 1.2), 40)
    cylinder(c, "Water", "Water", 11.6, 0.4, (0, 0, 2.3), 40)
    torus(c, "Gold", "Rim", 13, 0.35, (0, 0, 2.4))
    cylinder(c, "Marble", "Column", 2.6, 5, (0, 0, 4.9), 24)
    cylinder(c, "Gold", "Bowl", 6, 1.0, (0, 0, 7.8), 32)
    cone(c, "Gold", "BowlUnder", 2.6, 6, 1.6, (0, 0, 6.6), 32)
    cylinder(c, "Gold", "Coin", 4, 1.2, (0, 0, 13), 40, rotation=(math.radians(90), 0, 0))
    box(c, "Gold", "CoinStand", (1.2, 1.2, 3.2), (0, 0, 9.6))


def build_tree(c):
    cylinder(c, "Wood", "Trunk", 0.8, 9, (0, 0, 4.5), 10)
    sphere(c, "Leaf", "Crown", 4.5, (0, 0, 10.5), 2)
    sphere(c, "Leaf", "CrownSide", 3, (2.4, 1, 9), 1)
    sphere(c, "Leaf", "CrownBack", 3, (-2, -1.5, 9.4), 1)


def build_palm(c):
    # Curved trunk from stacked, slightly offset segments.
    for i in range(6):
        cylinder(c, "Bark", f"Trunk{i}", 0.75 - i * 0.05, 3, (i * 0.25, 0, 1.5 + i * 2.6), 8, rotation=(0, math.radians(5), 0))
    top = Vector((1.5, 0, 16))
    for i in range(7):
        angle = i * (2 * math.pi / 7)
        frond_dir = Vector((math.cos(angle), math.sin(angle), 0))
        center = top + frond_dir * 3 + Vector((0, 0, -0.8))
        box(c, "Palm", f"Frond{i}", (6.5, 1.4, 0.2), center, rotation=(0, math.radians(18), angle))
    sphere(c, "Wood", "Coconuts", 0.9, top + Vector((0, 0, -0.6)), 1)


def build_lamp(c):
    cylinder(c, "Dark", "Base", 0.9, 0.6, (0, 0, 0.3), 12)
    cylinder(c, "Dark", "Pole", 0.3, 11.5, (0, 0, 6), 12)
    torus(c, "Gold", "Collar", 0.45, 0.12, (0, 0, 11.6))
    sphere(c, "Glow", "Globe", 1.0, (0, 0, 12.6), 2)
    cone(c, "Gold", "Cap", 0.9, 0.05, 0.7, (0, 0, 13.6), 12)


def build_gold_bars(c):
    index = 0
    for layer in range(3):
        for row in range(3 - layer):
            index += 1
            x = (row - (2 - layer) / 2) * 1.8
            box(c, "Gold", f"Bar{index}", (1.6, 3.2, 0.8), (x, 0, 0.4 + layer * 0.8), bevel=0.12)


def build_vault_door(c):
    rot = (math.radians(90), 0, 0)
    cylinder(c, "Steel", "Door", 11, 3, (0, 0, 11), 48, rotation=rot)
    torus(c, "Gold", "Ring", 10.4, 0.5, (0, -1.6, 11), rotation=rot)
    cylinder(c, "Gold", "Hub", 1.6, 1.2, (0, -2.0, 11), 24, rotation=rot)
    for i in range(3):
        box(c, "Gold", f"Spoke{i}", (7.5, 0.5, 0.5), (0, -2.2, 11), rotation=(0, math.radians(i * 60), 0))
    for i in range(12):
        angle = i * math.pi / 6
        cylinder(c, "Steel", f"Bolt{i}", 0.45, 0.6, (math.cos(angle) * 8.6, -1.7, 11 + math.sin(angle) * 8.6), 8, rotation=rot)


def build_slot_machine(c):
    box(c, "Red", "Body", (8, 6, 12), (0, 0, 6), bevel=0.3)
    box(c, "Neon", "Screen", (6, 0.3, 4), (0, -3.05, 8))
    for i in range(3):
        box(c, "White", f"Reel{i}", (1.6, 0.35, 3.2), (-2 + i * 2, -3.2, 8))
    box(c, "Gold", "Top", (8.4, 6.4, 1.4), (0, 0, 12.7), bevel=0.2)
    box(c, "Gold", "Tray", (6, 1.6, 1.2), (0, -3.4, 3))
    cylinder(c, "Steel", "Lever", 0.25, 5, (4.4, 0, 8), 10)
    sphere(c, "Red", "Knob", 0.75, (4.4, 0, 10.6), 2)


def build_dice(c):
    box(c, "White", "Cube", (10, 10, 10), (0, 0, 5), bevel=0.8)
    pips = {
        "front": [(-1, 1), (0, 0), (1, -1)],  # -Y face shows 3
        "top": [(-1, 1), (1, 1), (0, 0), (-1, -1), (1, -1)],  # +Z face shows 5
    }
    for i, (u, v) in enumerate(pips["front"]):
        cylinder(c, "Pip", f"PipF{i}", 0.9, 0.3, (u * 2.6, -5.0, 5 + v * 2.6), 16, rotation=(math.radians(90), 0, 0))
    for i, (u, v) in enumerate(pips["top"]):
        cylinder(c, "Pip", f"PipT{i}", 0.9, 0.3, (u * 2.6, v * 2.6, 10.0), 16)


def build_portal_arch(c):
    for x in (-7, 7):
        box(c, "Gold", f"Post{'L' if x < 0 else 'R'}", (2.4, 2.4, 20), (x, 0, 10), bevel=0.25)
        box(c, "Marble", f"Plinth{'L' if x < 0 else 'R'}", (3.4, 3.4, 1.2), (x, 0, 0.6))
    # Semi-circular top made of segments
    for i in range(9):
        angle = math.pi * i / 8
        x, z = math.cos(angle) * 7, 20 + math.sin(angle) * 4
        box(c, "Gold", f"Arc{i}", (2.6, 2.4, 2.4), (x, 0, z), rotation=(0, -angle + math.pi / 2, 0))
    sphere(c, "Glow", "Gem", 1.3, (0, 0, 25.2), 2)


PROPS = {
    "Fountain": build_fountain,
    "Tree": build_tree,
    "PalmTree": build_palm,
    "Lamp": build_lamp,
    "GoldBars": build_gold_bars,
    "VaultDoor": build_vault_door,
    "SlotMachine": build_slot_machine,
    "Dice": build_dice,
    "PortalArch": build_portal_arch,
}


def export_fbx(collection, path):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.all_objects:
        obj.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"MESH"},
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="FACE",
        use_mesh_modifiers=True,
        path_mode="AUTO",
    )


def render_preview(path):
    scene = bpy.context.scene
    # Lay props out in a row for the preview.
    collections = [bpy.data.collections[name] for name in PROPS]
    x = 0.0
    for col in collections:
        for obj in col.all_objects:
            obj.location.x += x
        x += 32
    bpy.ops.object.camera_add(location=(x / 2 - 16, -175, 34), rotation=(math.radians(83), 0, 0))
    camera = bpy.context.active_object
    camera.data.lens = 17
    scene.camera = camera
    bpy.ops.object.light_add(type="SUN", location=(0, 0, 50), rotation=(math.radians(40), math.radians(10), math.radians(30)))
    bpy.context.active_object.data.energy = 4
    world = bpy.data.worlds.new("World") if not scene.world else scene.world
    scene.world = world
    world.color = (0.05, 0.045, 0.06)
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    if background:
        background.inputs["Color"].default_value = (0.35, 0.3, 0.32, 1.0)
        background.inputs["Strength"].default_value = 0.6
    # Cycles on CPU works headless (no GPU/EGL needed).
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = False
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 520
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    # Move props back so the saved .blend has them at their origins? Keep the
    # row layout: it is easier to browse in the editable scene.


def main():
    os.makedirs(OUT, exist_ok=True)
    reset_scene()
    for name, builder in PROPS.items():
        collection = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(collection)
        builder(collection)
        export_fbx(collection, os.path.join(OUT, f"{name}.fbx"))
        tris = 0
        for obj in collection.all_objects:
            obj.data.calc_loop_triangles()
            tris += len(obj.data.loop_triangles)
        print(f"  exported {name}.fbx ({len(collection.all_objects)} meshes, {tris} triangles)")
    try:
        render_preview(os.path.join(OUT, "preview.png"))
    except Exception as error:  # rendering is optional (e.g. no GPU in CI)
        print("  preview render skipped:", error)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "Props.blend"))
    print("Done:", OUT)


if __name__ == "__main__":
    main()
