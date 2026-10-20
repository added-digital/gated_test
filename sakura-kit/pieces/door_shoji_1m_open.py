"""An open 1 m shoji bay: the sill, kamoi head rail, plaster strip and top beam of
the closed segment with the paper panel slid away, and a jamb post at each side
tying sill to kamoi, leaving a 0.88 m clear opening 2 m tall. It is the only
way into a room built from closed panels."""
from sakura_kit.contract import Piece, DOOR_H, GRID, WALL_H


def build():
    p = Piece("sakura_door_shoji_1m_open", "door")
    frame_t = 0.12      # full segment thickness, same as the closed panel and the wall
    plaster_t = 0.10    # plaster strip recessed 0.01 m each side
    sill_h = 0.05       # shikii: the grooved sill the panel would slide on
    kamoi_h = 0.08      # kamoi: head rail at the top of the opening
    beam_h = 0.3        # top beam shared with the wall piece
    beam_z = WALL_H - beam_h

    # Sill, kamoi at DOOR_H, plaster strip, top beam: identical to the closed segment.
    sill = p.box((GRID, frame_t, sill_h), at=(0, 0, 0), color="wood_dark")
    p.box((GRID, frame_t, kamoi_h), at=(0, 0, DOOR_H), color="wood_dark")
    p.box((GRID, plaster_t, beam_z - (DOOR_H + kamoi_h)), at=(0, 0, DOOR_H + kamoi_h), color="plaster")
    p.box((GRID, frame_t, beam_h), at=(0, 0, beam_z), color="wood_dark")

    # Jamb posts at both edges of the bay, sill to kamoi, so the head rail is
    # carried and the opening reads as a doorway. Clear width = 1.0 - 2 * 0.06.
    jamb_w = 0.06
    for x in (-(GRID - jamb_w) / 2, (GRID - jamb_w) / 2):
        p.box((jamb_w, frame_t, DOOR_H - sill_h), at=(x, 0, sill_h), color="wood_dark")

    # Two shallow grooves along the sill top where the panel runs, so the open
    # bay still reads as a sliding door and not a plain gap.
    groove_w, groove_d = 0.012, 0.004
    for y in (-0.03, 0.03):
        p.box((GRID - 2 * jamb_w, groove_w, groove_d), at=(0, y, sill_h - groove_d), color="lattice")
    return p.finish()
