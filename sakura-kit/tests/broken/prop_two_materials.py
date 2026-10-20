"""BROKEN ON PURPOSE: a prop with a second material slot. Must fail single_palette_material."""
import bpy

from sakura_kit.contract import Piece

MUST_FAIL = "single_palette_material"


def build():
    p = Piece("sakura_prop_two_materials", "prop")
    p.box((0.4, 0.4, 0.4), color="wood")
    obj = p.finish()
    obj.data.materials.append(bpy.data.materials.new("stray_material"))
    return obj
