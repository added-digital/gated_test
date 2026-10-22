class_name PinchLabel
extends RefCounted
## Labels that can be read over grey boxes (toy 4, PINCH, the readability
## pass). make() builds a Label of a given box (`width` px wide, one line
## tall) with a small dark backing rect behind the text, sized to the text
## (the "Backing" child, drawn behind its parent); `wrap` turns autowrap on
## and the backing covers the whole box instead. The intended width is kept
## in the metadata max_width (a Label grows past its box when its text is
## wider, so the box itself cannot be read back). set_text() changes the
## words and refits the backing; text_width() measures the words in the
## label's own font, for the fit checks. Nothing here holds any words.

const LINE := 22.0                        # px: one line's box
const BACKING := Color(0, 0, 0, 0.55)
const PAD := Vector2(4, 1)                # px around the text inside the backing


## A one-line label (or a wrapped one) at `at`, `width` wide, backed.
static func make(text: String, at: Vector2, width: float, align := HORIZONTAL_ALIGNMENT_CENTER, font_size := 0, backed := true, wrap := false) -> Label:
	var label := Label.new()
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(width, 0)
	label.text = text
	label.position = at
	label.horizontal_alignment = align
	label.set_meta("max_width", width)
	label.size = Vector2(width, LINE)
	# Outside the tree a Label's minimum size is reckoned with the default
	# font, not its override, and a Control never shrinks on its own, so
	# the box is set again (and the backing refitted) once it is ready in
	# the tree, where the stale minimum has been thrown away.
	label.ready.connect(func() -> void:
		label.update_minimum_size()
		label.size = Vector2(width, LINE)
		refit(label))
	if backed:
		back(label)
	return label


## A backing rect behind an existing label's text (idempotent).
static func back(label: Label) -> ColorRect:
	var backing: ColorRect = label.get_node_or_null("Backing")
	if backing == null:
		backing = ColorRect.new()
		backing.name = "Backing"
		backing.color = BACKING
		backing.show_behind_parent = true
		backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_child(backing)
	refit(label)
	return backing


## New words, and the backing follows them.
static func set_text(label: Label, text: String) -> void:
	label.text = text
	refit(label)


## The backing sized to the text: tight around one line, the whole box when wrapped.
static func refit(label: Label) -> void:
	var backing: ColorRect = label.get_node_or_null("Backing")
	if backing == null:
		return
	if label.text == "":
		backing.visible = false
		return
	backing.visible = true
	if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		backing.position = Vector2.ZERO
		backing.size = label.size
		return
	var text_size := text_size_of(label)
	var x := 0.0
	match label.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			x = (label.size.x - text_size.x) / 2.0
		HORIZONTAL_ALIGNMENT_RIGHT:
			x = label.size.x - text_size.x
	backing.position = Vector2(x, (label.size.y - text_size.y) / 2.0) - PAD
	backing.size = text_size + PAD * 2.0


## The text's width in the label's own font and size, in px.
static func text_width(label: Label) -> float:
	return text_size_of(label).x


## The text's size in the label's own font and size, in px.
static func text_size_of(label: Label) -> Vector2:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	return font.get_string_size(label.text, label.horizontal_alignment, -1, font_size)


## The box the label was made for (max_width), or its size when unknown.
static func box_width(label: Label) -> float:
	return float(label.get_meta("max_width")) if label.has_meta("max_width") else label.size.x
