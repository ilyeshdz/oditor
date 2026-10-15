package editor

import sdl "vendor:sdl3"

EVENT_TIMEOUT_MS :: 16

poll_events :: proc(buf: ^Buffer) -> bool {
	event: sdl.Event

	if !sdl.WaitEventTimeout(&event, EVENT_TIMEOUT_MS) {
		return true
	}

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
