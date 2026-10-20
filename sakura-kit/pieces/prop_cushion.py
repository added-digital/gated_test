"""A zabuton: a square 0.55 m mauve floor cushion 7 cm thick, its edge stepped like a puffed seam, with a darker inset panel on top and four thread tufts at the corners."""
from sakura_kit.contract import Piece

SIZE = 0.55         # full footprint of the cushion
H = 0.07            # total thickness
BASE_H = 0.04       # lower, slightly larger box (the puffed edge)
TOP_SIZE = 0.50     # upper box, inset so the edge reads as a shallow bevel
INSET = 0.36        # darker square panel on the top face
INSET_T = 0.004     # the panel is cloth, so it stands barely proud
TUFT = 0.03         # thread tufts at the four corners
TUFT_H = 0.012
TUFT_AT = 0.215     # tuft centres: in the pale border between inset and edge


def build():
    p = Piece("sakura_prop_cushion", "prop")
    # Two stacked boxes: a wider low one and a narrower upper one, so the
    # silhouette has the soft stepped edge of a stuffed cushion.
    p.box((SIZE, SIZE, BASE_H), at=(0, 0, 0), color="cushion")
    p.box((TOP_SIZE, TOP_SIZE, H - BASE_H), at=(0, 0, BASE_H), color="cushion")
    # Darker inset panel sitting on the top face.
    p.box((INSET, INSET, INSET_T), at=(0, 0, H), color="cushion_dark")
    # Four tiny tufts on the top, one near each corner, outside the inset.
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((TUFT, TUFT, TUFT_H), at=(sx * TUFT_AT, sy * TUFT_AT, H), color="cushion_dark")
    return p.finish()
