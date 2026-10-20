"""A square hinoki corner post, 0.15 x 0.15 x 2.5 m, standing on a thin
0.2 x 0.2 x 0.02 m dark stone base plate that keeps the wood off the ground."""
from sakura_kit.contract import Piece, WALL_H

POST = 0.15        # square section of the post
PLATE = 0.20       # square base plate, inside the 0.25 pillar footprint
PLATE_T = 0.02     # plate thickness; the post stands on top of it


def build():
    p = Piece("sakura_pillar_post", "pillar")
    # Stone foot: sits on the ground, top face at z = PLATE_T.
    p.box((PLATE, PLATE, PLATE_T), at=(0, 0, 0), color="stone_dark")
    # The post rises from the plate to exactly WALL_H, so the whole piece is 2.5 m.
    post = p.box((POST, POST, WALL_H - PLATE_T), at=(0, 0, PLATE_T), color="wood")
    # End grain on the cut top is paler than the planed sides.
    p.paint(p.faces_facing(post, (0, 0, 1)), "wood_light")
    return p.finish()
