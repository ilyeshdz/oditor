package main

import "core:fmt"
import "editor"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

main :: proc() {
	buffer: editor.Buffer
	if err := editor.init_from_file(&buffer, "README.md"); err != nil {
		fmt.eprintln("Couldn't read README.md: ", err)
		return
	}
	defer editor.destroy_buffer(&buffer)

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

	font_renderer: editor.FontRenderer
	if !editor.font_renderer_init(&font_renderer, renderer) {
		return
	}
	defer editor.destroy_font_renderer(&font_renderer)

	for editor.poll_events(&buffer) {
		sdl.SetRenderDrawColor(renderer, 30, 30, 30, 255)
		sdl.RenderClear(renderer)

		editor.draw(&font_renderer, &buffer)

		sdl.RenderPresent(renderer)
	}
}
