package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "editor"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

main :: proc() {
	file_path := "README.md"
	if len(os.args) > 1 {
		file_path = os.args[1]
	}

	buffer: editor.Buffer
	if os.exists(file_path) {
		if err := editor.init_from_file(&buffer, file_path); err != nil {
			fmt.eprintln("Couldn't read ", file_path, ": ", err)
			return
		}
	} else {
		editor.init(&buffer, file_path)
	}
	defer editor.destroy_buffer(&buffer)

	base := filepath.base(file_path)
	title := fmt.ctprintf("%s - oditor", base)

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

	if !sdl.CreateWindowAndRenderer(title, 640, 480, {.RESIZABLE}, &window, &renderer) {
		fmt.eprintln("Couldn't create window/renderer: ", sdl.GetError())
		return
	}

	defer sdl.DestroyRenderer(renderer)
	defer sdl.DestroyWindow(window)

	if !sdl.StartTextInput(window) {
		fmt.eprintln("Couldn't start text input: ", sdl.GetError())
		return
	}
	defer _ = sdl.StopTextInput(window)

	font_renderer: editor.FontRenderer
	if !editor.font_renderer_init(&font_renderer, renderer) {
		return
	}
	defer editor.destroy_font_renderer(&font_renderer)

	for editor.poll_events(&buffer, &font_renderer) {
		sdl.SetRenderDrawColor(renderer, 30, 30, 30, 255)
		sdl.RenderClear(renderer)

		editor.draw(&font_renderer, &buffer)

		sdl.RenderPresent(renderer)
	}
}
