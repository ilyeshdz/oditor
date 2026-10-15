package editor

import sdl "vendor:sdl3"

EVENT_TIMEOUT_MS :: 16

poll_events :: proc(buf: ^Buffer, r: ^FontRenderer) -> bool {
	event: sdl.Event

	if !sdl.WaitEventTimeout(&event, EVENT_TIMEOUT_MS) {
		return true
	}

	for {
		#partial switch event.type {
		case .QUIT, .WINDOW_CLOSE_REQUESTED:
			return false
		case .KEY_DOWN:
			handle_key(&event.key, buf)
		case .TEXT_INPUT:
			insert_text(buf, string(event.text.text))
		case .MOUSE_BUTTON_DOWN:
			handle_mouse_button(&event.button, buf, r)
		case .MOUSE_WHEEL:
			handle_mouse_wheel(&event.wheel, buf)
		}
		if !sdl.PollEvent(&event) {
			break
		}
	}

	return true
}

handle_key :: proc(key: ^sdl.KeyboardEvent, buf: ^Buffer) {
	mod := key.mod & sdl.KMOD_ALT != {} || key.mod & sdl.KMOD_CTRL != {}

	switch key.key {
	case sdl.K_LEFT:
		if mod {
			cursor_word_left(buf)
		} else {
			cursor_left(buf)
		}
	case sdl.K_RIGHT:
		if mod {
			cursor_word_right(buf)
		} else {
			cursor_right(buf)
		}
	case sdl.K_UP:
		cursor_up(buf)
	case sdl.K_DOWN:
		cursor_down(buf)
	case sdl.K_HOME:
		cursor_home(buf)
	case sdl.K_END:
		cursor_end(buf)
	case sdl.K_BACKSPACE:
		if mod {
			delete_to_line_start(buf)
		} else {
			backspace(buf)
		}
	case sdl.K_DELETE:
		delete_forward(buf)
	case sdl.K_RETURN, sdl.K_KP_ENTER:
		insert_newline(buf)
	}
}

handle_mouse_button :: proc(button: ^sdl.MouseButtonEvent, buf: ^Buffer, r: ^FontRenderer) {
	if button.button != sdl.BUTTON_LEFT {
		return
	}

	line, col, ok := cursor_at_point(r, buf, button.x, button.y)
	if !ok {
		return
	}

	buf.cursor_y = line
	buf.cursor_x = col
	buf.goal_x = col
}

handle_mouse_wheel :: proc(wheel: ^sdl.MouseWheelEvent, buf: ^Buffer) {
	steps := int(wheel.y)
	for _ in 0 ..< abs(steps) {
		if steps > 0 {
			cursor_up(buf)
		} else {
			cursor_down(buf)
		}
	}
}
