"""A closed 1 m shoji segment: a rice-paper panel set inside a dark kamachi frame
behind a 3 x 6 kumiko lattice, with a pale finger pull on the leading stile, on a
wood sill under the kamoi head rail, plaster strip and top beam of the wall piece."""
from sakura_kit.contract import Piece, DOOR_H, GRID, WALL_H


def build():
    p = Piece("sakura_door_shoji_1m", "door")
    frame_t = 0.12      # full segment thickness, carried by sill, kamoi and beam
    plaster_t = 0.10    # plaster strip recessed 0.01 m each side, as on the wall
    sill_h = 0.05       # shikii: the grooved sill the panel slides on
    kamoi_h = 0.08      # kamoi: head rail the panel slides under
    beam_h = 0.3        # top beam, same as sakura_wall_plain_1m so walls meet it
    beam_z = WALL_H - beam_h

    # Structure, bottom to top: sill, kamoi at 2.0, plaster strip, top beam.
    p.box((GRID, frame_t, sill_h), at=(0, 0, 0), color="wood_dark")
    p.box((GRID, frame_t, kamoi_h), at=(0, 0, DOOR_H), color="wood_dark")
    p.box((GRID, plaster_t, beam_z - (DOOR_H + kamoi_h)), at=(0, 0, DOOR_H + kamoi_h), color="plaster")
    p.box((GRID, frame_t, beam_h), at=(0, 0, beam_z), color="wood_dark")

    # Panel frame (kamachi): two full-height stiles with the rails tenoned
    # between them. 0.04 m deep, centred on y = 0, so the frame stands 0.01 m
    # proud of the paper on both faces and no frame face shares a plane with it.
    bar = 0.02
    frame_d = 2 * bar
    frame_y = 0.0                       # frame spans y = -0.02 .. 0.02
    stile_w, rail_top, rail_bot = 0.04, 0.04, 0.06
    panel_h = DOOR_H - sill_h
    x0, x1 = -GRID / 2 + stile_w, GRID / 2 - stile_w      # clear width between stiles
    for x in (-(GRID - stile_w) / 2, (GRID - stile_w) / 2):
        p.box((stile_w, frame_d, panel_h), at=(x, frame_y, sill_h), color="lattice")
    p.box((x1 - x0, frame_d, rail_bot), at=(0, frame_y, sill_h), color="lattice")
    p.box((x1 - x0, frame_d, rail_top), at=(0, frame_y, DOOR_H - rail_top), color="lattice")

    # Paper: 0.01 m thick, its front face on y = 0 so the kumiko sit on it. Its
    # four edges are buried inside the stiles and rails: nothing of the paper
    # reaches the frame's outer planes.
    paper_t = 0.01
    paper_z0, paper_z1 = sill_h + rail_bot / 2, DOOR_H - rail_top / 2
    p.box((GRID - stile_w, paper_t, paper_z1 - paper_z0), at=(0, paper_t / 2, paper_z0), color="paper")

    # Kumiko lattice: 0.02 m bars dividing the opening into 3 columns x 6 rows.
    # Vertical bars are flush with the frame front (y = -0.02); the horizontal
    # bars sit 0.005 m back, half-lapped into the paper, so the two bar families
    # never share a coplanar front face at the crossings.
    cols, rows = 3, 6
    z0, z1 = sill_h + rail_bot, DOOR_H - rail_top
    pane_w = (x1 - x0 - (cols - 1) * bar) / cols
    pane_h = (z1 - z0 - (rows - 1) * bar) / rows
    bar_y = -bar / 2
    lap = 0.005
    for i in range(1, cols):
        xc = x0 + i * pane_w + (i - 1) * bar + bar / 2
        p.box((bar, bar, z1 - z0), at=(xc, bar_y, z0), color="lattice")
    for j in range(1, rows):
        zc = z0 + j * pane_h + (j - 1) * bar
        p.box((x1 - x0, bar, bar), at=(0, bar_y + lap, zc), color="lattice")

    # Hikite: the pale finger pull on the leading stile at hand height, one on
    # each face since the panel is slid from either side of the room.
    pull_w, pull_d, pull_h, pull_z = 0.03, 0.004, 0.09, 0.85
    pull_x = (GRID - stile_w) / 2
    for y in (-frame_d / 2 - pull_d / 2, frame_d / 2 + pull_d / 2):
        p.box((pull_w, pull_d, pull_h), at=(pull_x, y, pull_z), color="wood_light")
    return p.finish()
