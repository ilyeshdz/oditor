package editor

import "core:c"
import "core:fmt"
import "core:unicode/utf8"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

FONT_PATH :: "JetBrainsMono-Regular.ttf"
FONT_FALLBACKS :: [2]cstring{
	"/System/Library/Fonts/Menlo.ttc",
	"/System/Library/Fonts/Monaco.ttf",
}
FONT_SIZE :: 18
MARGIN :: 20

TEXT_COLOR :: [4]u8{255, 255, 255, 255}
CURSOR_COLOR :: [4]u8{255, 255, 255, 255}
CURRENT_LINE_COLOR :: [4]u8{45, 45, 45, 255}
LINE_NUMBER_COLOR :: [4]u8{110, 110, 110, 255}
CURRENT_LINE_NUMBER_COLOR :: [4]u8{190, 190, 190, 255}

CURSOR_WIDTH :: 2.0
GUTTER_PADDING :: 14.0

FontRenderer :: struct {
	sdl_renderer:    ^sdl.Renderer,
	font:            ^ttf.Font,
	engine:          ^ttf.TextEngine,
	texts:           [dynamic]^ttf.Text,
	gutter:          [dynamic]^ttf.Text,
	gutter_width:    f32,
	current_number:  int,
	line_height:     f32,
	glyph_height:    f32,
}

open_font :: proc(ptsize: f32) -> ^ttf.Font {
	if font := ttf.OpenFont(FONT_PATH, ptsize); font != nil {
		return font
	}

	fmt.eprintf("Couldn't open %s: %s\n", FONT_PATH, sdl.GetError())

	for path in FONT_FALLBACKS {
		if font := ttf.OpenFont(path, ptsize); font != nil {
			return font
		}
	}

	return nil
}

font_renderer_init :: proc(r: ^FontRenderer, sdl_renderer: ^sdl.Renderer) -> bool {
	r^ = {sdl_renderer = sdl_renderer}

	r.font = open_font(FONT_SIZE)
	if r.font == nil {
		fmt.eprintln("Couldn't open a font for ", FONT_PATH)
		return false
	}

	r.engine = ttf.CreateRendererTextEngine(sdl_renderer)
	if r.engine == nil {
		fmt.eprintln("Couldn't create text engine: ", sdl.GetError())
		ttf.CloseFont(r.font)
		r.font = nil
		return false
	}

	r.line_height = f32(ttf.GetFontLineSkip(r.font))
	r.glyph_height = f32(ttf.GetFontHeight(r.font))
	r.texts = make([dynamic]^ttf.Text)
	r.current_number = -1

	return true
}

destroy_font_renderer :: proc(r: ^FontRenderer) {
	for text in r.texts {
		ttf.DestroyText(text)
	}
	delete(r.texts)
	for text in r.gutter {
		ttf.DestroyText(text)
	}
	delete(r.gutter)
	if r.engine != nil {
		ttf.DestroyRendererTextEngine(r.engine)
	}
	if r.font != nil {
		ttf.CloseFont(r.font)
	}
	r^ = {}
}

sync_texts :: proc(r: ^FontRenderer, buf: ^Buffer) {
	sync_gutter(r, buf)

	if !buf.dirty {
		return
	}

	from := clamp(buf.dirty_from, 0, len(buf.data) - 1)
	to := clamp(buf.dirty_to, from, len(buf.data) - 1)

	if len(r.texts) == len(buf.data) {
		for i in from ..= to {
			create_line_text(r, i, buf)
		}
	} else {
		for i in from ..< len(r.texts) {
			ttf.DestroyText(r.texts[i])
		}
		resize(&r.texts, len(buf.data))
		for i in from ..< len(buf.data) {
			create_line_text(r, i, buf)
		}
	}

	buf.dirty = false
}

sync_gutter :: proc(r: ^FontRenderer, buf: ^Buffer) {
	if len(r.gutter) == len(buf.data) {
		return
	}

	for text in r.gutter {
		ttf.DestroyText(text)
	}
	resize(&r.gutter, len(buf.data))

	digits := len(fmt.tprintf("%d", len(buf.data)))
	width: c.int
	label: [16]u8

	for _, index in r.gutter {
		n := fmt.bprintf(label[:], "%*d", digits, index + 1)
		text := ttf.CreateText(r.engine, r.font, cstring(raw_data(n)), c.size_t(len(n)))
		if text == nil {
			fmt.eprintln("Couldn't create line number text: ", sdl.GetError())
			continue
		}
		ttf.SetTextColor(text, LINE_NUMBER_COLOR[0], LINE_NUMBER_COLOR[1], LINE_NUMBER_COLOR[2], LINE_NUMBER_COLOR[3])

		text_size: c.int
		if ttf.GetTextSize(text, &text_size, nil) {
			width = max(width, text_size)
		}
		r.gutter[index] = text
	}

	r.gutter_width = f32(width) + GUTTER_PADDING
	r.current_number = -1
}

create_line_text :: proc(r: ^FontRenderer, index: int, buf: ^Buffer) {
	if r.texts[index] != nil {
		ttf.DestroyText(r.texts[index])
		r.texts[index] = nil
	}

	line := buf.data[index]
	text := ttf.CreateText(r.engine, r.font, cstring(raw_data(line)), c.size_t(len(line)))
	if text == nil {
		fmt.eprintln("Couldn't create text: ", sdl.GetError())
		return
	}
	ttf.SetTextColor(text, TEXT_COLOR[0], TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3])
	r.texts[index] = text
}

cursor_rect :: proc(r: ^FontRenderer, buf: ^Buffer) -> sdl.FRect {
	if len(r.texts) == 0 {
		return {}
	}

	line_index := clamp(buf.cursor_y, 0, len(r.texts) - 1)
	offset := rune_to_byte_offset(current_line(buf), buf.cursor_x)

	x: f32
	if text := r.texts[line_index]; text != nil {
		substring: ttf.SubString
		if ttf.GetTextSubString(text, c.int(offset), &substring) {
			x = f32(substring.rect.x)
		}
	}

	height := max(r.glyph_height, 1)
	y := MARGIN + r.line_height * f32(line_index) + (r.line_height - height) / 2

	return sdl.FRect{
		x = MARGIN + r.gutter_width + x,
		y = y,
		w = CURSOR_WIDTH,
		h = height,
	}
}

cursor_at_point :: proc(r: ^FontRenderer, buf: ^Buffer, window_x, window_y: f32) -> (line, col: int, ok: bool) {
	sync_texts(r, buf)

	if len(r.texts) == 0 {
		return 0, 0, false
	}

	x, y: f32
	if !sdl.RenderCoordinatesFromWindow(r.sdl_renderer, window_x, window_y, &x, &y) {
		return 0, 0, false
	}

	line = int((y - MARGIN) / r.line_height)
	line = clamp(line, 0, len(r.texts) - 1)

	text := r.texts[line]
	if text == nil {
		return line, 0, true
	}

	substring: ttf.SubString
	if !ttf.GetTextSubStringForPoint(text, c.int(x - (MARGIN + r.gutter_width)), 0, &substring) {
		return line, 0, true
	}

	offset := int(substring.offset)
	line_text := buf.data[line]
	if offset > len(line_text) {
		offset = len(line_text)
	}

	col = utf8.rune_count(line_text[:offset])
	return line, col, true
}

draw :: proc(r: ^FontRenderer, buf: ^Buffer) {
	sync_texts(r, buf)

	if len(r.texts) > 0 {
		line_index := clamp(buf.cursor_y, 0, len(r.texts) - 1)

		width, height: c.int
		sdl.GetRenderOutputSize(r.sdl_renderer, &width, &height)

		band := sdl.FRect{
			x = 0,
			y = MARGIN + r.line_height * f32(line_index),
			w = f32(width),
			h = r.line_height,
		}
		sdl.SetRenderDrawColor(
			r.sdl_renderer,
			CURRENT_LINE_COLOR[0], CURRENT_LINE_COLOR[1], CURRENT_LINE_COLOR[2], CURRENT_LINE_COLOR[3],
		)
		sdl.RenderFillRect(r.sdl_renderer, &band)
	}

	if len(r.gutter) > 0 {
		line_index := clamp(buf.cursor_y, 0, len(r.gutter) - 1)
		if r.current_number != line_index {
			if r.current_number >= 0 {
				if prev := r.gutter[r.current_number]; prev != nil {
					ttf.SetTextColor(prev, LINE_NUMBER_COLOR[0], LINE_NUMBER_COLOR[1], LINE_NUMBER_COLOR[2], LINE_NUMBER_COLOR[3])
				}
			}
			if cur := r.gutter[line_index]; cur != nil {
				ttf.SetTextColor(cur, CURRENT_LINE_NUMBER_COLOR[0], CURRENT_LINE_NUMBER_COLOR[1], CURRENT_LINE_NUMBER_COLOR[2], CURRENT_LINE_NUMBER_COLOR[3])
			}
			r.current_number = line_index
		}
	}

	for text, index in r.gutter {
		if text == nil {
			continue
		}
		number_width: c.int
		ttf.GetTextSize(text, &number_width, nil)
		ttf.DrawRendererText(
			text,
			MARGIN + r.gutter_width - GUTTER_PADDING - f32(number_width),
			MARGIN + r.line_height * f32(index),
		)
	}

	for text, index in r.texts {
		if text == nil {
			continue
		}
		ttf.DrawRendererText(
			text,
			MARGIN + r.gutter_width,
			MARGIN + r.line_height * f32(index),
		)
	}

	cursor := cursor_rect(r, buf)
	sdl.SetRenderDrawColor(
		r.sdl_renderer,
		CURSOR_COLOR[0], CURSOR_COLOR[1], CURSOR_COLOR[2], CURSOR_COLOR[3],
	)
	sdl.RenderFillRect(r.sdl_renderer, &cursor)
}
