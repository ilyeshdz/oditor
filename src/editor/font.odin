package editor

import "core:c"
import "core:fmt"
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

CURSOR_WIDTH :: 2.0

FontRenderer :: struct {
	sdl_renderer: ^sdl.Renderer,
	font:         ^ttf.Font,
	engine:       ^ttf.TextEngine,
	texts:        [dynamic]^ttf.Text,
	line_height:  f32,
	glyph_height: f32,
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

	return true
}

destroy_font_renderer :: proc(r: ^FontRenderer) {
	for text in r.texts {
		ttf.DestroyText(text)
	}
	delete(r.texts)
	if r.engine != nil {
		ttf.DestroyRendererTextEngine(r.engine)
	}
	if r.font != nil {
		ttf.CloseFont(r.font)
	}
	r^ = {}
}

sync_texts :: proc(r: ^FontRenderer, buf: ^Buffer) {
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
		x = MARGIN + x,
		y = y,
		w = CURSOR_WIDTH,
		h = height,
	}
}

draw :: proc(r: ^FontRenderer, buf: ^Buffer) {
	sync_texts(r, buf)

	for text, index in r.texts {
		if text == nil {
			continue
		}
		ttf.DrawRendererText(
			text,
			f32(MARGIN),
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
