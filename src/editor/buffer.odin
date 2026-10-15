package editor

import "core:os"
import "core:strings"
import "core:unicode/utf8"

Buffer :: struct {
	data:     [dynamic]string,
	cursor_x: int,
	cursor_y: int,
	goal_x:   int,
	revision: int,
}

init :: proc(buf: ^Buffer) {
	buf^ = {}

	append(&buf.data, "")
	buf.revision = 1
}

init_from_file :: proc(
	buf: ^Buffer,
	file_path: string,
	allocator := context.allocator,
) -> os.Error {
	buf^ = {}
	buf.revision = 1

	content, err := os.read_entire_file(file_path, allocator)
	if err != nil {
		return err
	}
	defer delete(content, allocator)

	lines := strings.split_lines(string(content), allocator)
	defer delete(lines, allocator)

	buf.data = make([dynamic]string, allocator)
	if len(lines) == 0 {
		append(&buf.data, "")
	} else {
		for line in lines {
			append(&buf.data, strings.clone(line, allocator))
		}
	}

	return nil
}

destroy_buffer :: proc(buf: ^Buffer) {
	for line in buf.data {
		delete(line)
	}
	delete(buf.data)
	buf^ = {}
}

current_line :: proc(buf: ^Buffer) -> string {
	if buf.cursor_y < 0 || buf.cursor_y >= len(buf.data) {
		return ""
	}
	return buf.data[buf.cursor_y]
}

clamp_cursor :: proc(buf: ^Buffer) {
	if len(buf.data) == 0 {
		append(&buf.data, "")
	}
	buf.cursor_y = clamp(buf.cursor_y, 0, len(buf.data) - 1)
	buf.cursor_x = clamp(buf.cursor_x, 0, utf8.rune_count(buf.data[buf.cursor_y]))
	buf.goal_x = buf.cursor_x
}

rune_to_byte_offset :: proc(line: string, col: int) -> int {
	if col <= 0 {
		return 0
	}
	offset := 0
	for _ in 0 ..< col {
		if offset >= len(line) {
			return len(line)
		}
		_, size := utf8.decode_rune_in_string(line[offset:])
		offset += size
	}
	return offset
}

cursor_left :: proc(buf: ^Buffer) {
	if buf.cursor_x > 0 {
		buf.cursor_x -= 1
	} else if buf.cursor_y > 0 {
		buf.cursor_y -= 1
		buf.cursor_x = utf8.rune_count(buf.data[buf.cursor_y])
	}
	buf.goal_x = buf.cursor_x
}

cursor_right :: proc(buf: ^Buffer) {
	if buf.cursor_x < utf8.rune_count(current_line(buf)) {
		buf.cursor_x += 1
	} else if buf.cursor_y + 1 < len(buf.data) {
		buf.cursor_y += 1
		buf.cursor_x = 0
	}
	buf.goal_x = buf.cursor_x
}

cursor_up :: proc(buf: ^Buffer) {
	if buf.cursor_y > 0 {
		buf.cursor_y -= 1
	}
	buf.cursor_x = min(buf.goal_x, utf8.rune_count(current_line(buf)))
}

cursor_down :: proc(buf: ^Buffer) {
	if buf.cursor_y + 1 < len(buf.data) {
		buf.cursor_y += 1
	}
	buf.cursor_x = min(buf.goal_x, utf8.rune_count(current_line(buf)))
}

cursor_home :: proc(buf: ^Buffer) {
	buf.cursor_x = 0
	buf.goal_x = 0
}

cursor_end :: proc(buf: ^Buffer) {
	buf.cursor_x = utf8.rune_count(current_line(buf))
	buf.goal_x = buf.cursor_x
}
