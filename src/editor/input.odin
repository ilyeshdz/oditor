package editor

import sdl "vendor:sdl3"

// How long we block waiting for an event before rendering a fresh frame
// anyway. Keeps an idle editor at ~60fps without spinning the CPU.
EVENT_TIMEOUT_MS :: 16

// poll_events reads the input coming from the user and applies it to the
// buffer. It returns false when the application should quit.
poll_events :: proc(buf: ^Buffer) -> bool {
	event: sdl.Event

	// Block until something happens, with a short timeout so the display
	// still refreshes while the editor is idle.
	if !sdl.WaitEventTimeout(&event, EVENT_TIMEOUT_MS) {
		return true
	}

	// Drain everything that is already queued so a burst of events only
	// costs a single frame.
	for {
		#partial switch event.type {
		case .QUIT, .WINDOW_CLOSE_REQUESTED:
			return false
		case .KEY_DOWN:
			handle_key(event.key, buf)
		}
		if !sdl.PollEvent(&event) {
			break
		}
	}

	return true
}

handle_key :: proc(key: sdl.KeyboardEvent, buf: ^Buffer) {
	switch key.key {
	case sdl.K_LEFT:
		cursor_left(buf)
	case sdl.K_RIGHT:
		cursor_right(buf)
	case sdl.K_UP:
		cursor_up(buf)
	case sdl.K_DOWN:
		cursor_down(buf)
	case sdl.K_HOME:
		cursor_home(buf)
	case sdl.K_END:
		cursor_end(buf)
	}
}
