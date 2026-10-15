package main

import "core:c"
import "core:fmt"
import "editor"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

FONT_PATH :: "JetBrainsMono-Regular.ttf"
FONT_FALLBACKS :: [2]cstring{
	"/System/Library/Fonts/Menlo.ttc",
	"/System/Library/Fonts/Monaco.ttf",
}
FONT_SIZE :: 18
MARGIN :: 20

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

main :: proc() {
	buffer: editor.Buffer
	editor.init_from_file(&buffer, "README.md")

	if !sdl.Init({.VIDEO}) {
		fmt.eprintln("Couldn't initialize SDL3: ", sdl.GetError())
		return
	}
	defer sdl.Quit()

	if !ttf.Init() {
		fmt.eprintln("Couldn't initialize SDL3_ttf: ", sdl.GetError())
		return
	}
	defer ttf.Quit()

	window: ^sdl.Window
	renderer: ^sdl.Renderer

	if !sdl.CreateWindowAndRenderer("oditor", 640, 480, {.RESIZABLE}, &window, &renderer) {
		fmt.eprintln("Couldn't create window/renderer: ", sdl.GetError())
		return
	}

	defer sdl.DestroyRenderer(renderer)
	defer sdl.DestroyWindow(window)

	font := open_font(FONT_SIZE)
	if font == nil {
		fmt.eprintln("Couldn't open a font for ", FONT_PATH)
		return
	}
	defer ttf.CloseFont(font)

	engine := ttf.CreateRendererTextEngine(renderer)
	if engine == nil {
		fmt.eprintln("Couldn't create text engine: ", sdl.GetError())
		return
	}
	defer ttf.DestroyRendererTextEngine(engine)

	line_height := f32(ttf.GetFontLineSkip(font))

	line_texts: [dynamic]^ttf.Text
	defer {
		for text in line_texts {
			ttf.DestroyText(text)
		}
		delete(line_texts)
	}

	for line in buffer.data {
		text := ttf.CreateText(engine, font, cstring(raw_data(line)), c.size_t(len(line)))
		if text == nil {
			fmt.eprintln("Couldn't create text: ", sdl.GetError())
			return
		}

		ttf.SetTextColor(text, 255, 255, 255, 255)
		append(&line_texts, text)
	}

	main_loop: for {
		for event: sdl.Event; sdl.PollEvent(&event); {
			#partial switch event.type {
			case .QUIT, .WINDOW_CLOSE_REQUESTED:
				break main_loop
			}
		}

		sdl.SetRenderDrawColor(renderer, 30, 30, 30, 255)
		sdl.RenderClear(renderer)

		for text, index in line_texts {
			ttf.DrawRendererText(
				text,
				f32(MARGIN),
				f32(MARGIN) + line_height * f32(index),
			)
		}

		sdl.RenderPresent(renderer)
	}
}
