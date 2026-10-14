package main

import "core:fmt"
import "editor"
import sdl "vendor:sdl3"

main :: proc() {
	buffer: editor.Buffer
	editor.init_from_file(&buffer, "README.md")

	if !sdl.Init({.VIDEO}) {
		fmt.eprintln("Couldn't initialize SDL3: ", sdl.GetError())
		return
	}
	defer sdl.Quit()

	window: ^sdl.Window
	renderer: ^sdl.Renderer

	if !sdl.CreateWindowAndRenderer("oditor", 640, 480, {.RESIZABLE}, &window, &renderer) {
		fmt.eprintln("Couldn't create window/renderer: ", sdl.GetError())
		return
	}

	defer sdl.DestroyRenderer(renderer)
	defer sdl.DestroyWindow(window)

	main_loop: for {
		for event: sdl.Event; sdl.PollEvent(&event); {
			#partial switch event.type {
			case .QUIT, .WINDOW_CLOSE_REQUESTED:
				break main_loop
			}
		}

		sdl.SetRenderDrawColor(renderer, 30, 30, 30, 255)
		sdl.RenderClear(renderer)

		sdl.RenderPresent(renderer)
	}
}
