"""A plain 1 m tea-house wall segment: lime plaster infill set in a dark wood
frame of sill, mid-height rail and top beam (posts belong to the pillar piece)."""
from sakura_kit.contract import Piece, GRID, WALL_H


def build():
    p = Piece("sakura_wall_plain_1m", "wall")
    frame_t = 0.12      # full wall thickness, carried by the wood frame
    plaster_t = 0.10    # infill recessed 0.01 m each side so the frame reads as trim
    sill_h = 0.15
    rail_z, rail_h = 0.9, 0.04
    beam_h = 0.3
    beam_z = WALL_H - beam_h

    # Frame, bottom to top: sill on the ground, rail at 0.9 m, beam under the roof.
    p.box((GRID, frame_t, sill_h), at=(0, 0, 0), color="wood_dark")
    p.box((GRID, frame_t, rail_h), at=(0, 0, rail_z), color="wood_dark")
    p.box((GRID, frame_t, beam_h), at=(0, 0, beam_z), color="wood_dark")

    # Plaster panels filling the two bays between the frame members.
    p.box((GRID, plaster_t, rail_z - sill_h), at=(0, 0, sill_h), color="plaster")
    p.box((GRID, plaster_t, beam_z - (rail_z + rail_h)), at=(0, 0, rail_z + rail_h), color="plaster")
    return p.finish()
