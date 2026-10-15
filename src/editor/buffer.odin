package editor

import "core:os"
import "core:strings"
import "core:unicode"
import "core:unicode/utf8"

Buffer :: struct {
	data:       [dynamic]string,
	path:       string,
	cursor_x:   int,
	cursor_y:   int,
	goal_x:     int,
	dirty:      bool,
	dirty_from: int,
	dirty_to:   int,
}

init :: proc(buf: ^Buffer, path := "") {
	buf^ = {}

	if path != "" {
		buf.path = strings.clone(path)
	}
	append(&buf.data, "")
	mark_dirty(buf, 0, 0)
}

init_from_file :: proc(
	buf: ^Buffer,
	file_path: string,
	allocator := context.allocator,
) -> os.Error {
	buf^ = {}

	content, err := os.read_entire_file(file_path, allocator)
	if err != nil {
		return err
	}
	defer delete(content, allocator)

	buf.path = strings.clone(file_path, allocator)

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

	mark_dirty(buf, 0, len(buf.data) - 1)

	return nil
}

destroy_buffer :: proc(buf: ^Buffer) {
	for line in buf.data {
		delete(line)
	}
	delete(buf.data)
	delete(buf.path)
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

mark_dirty :: proc(buf: ^Buffer, from, to: int) {
	if !buf.dirty {
		buf.dirty_from = from
		buf.dirty_to = to
		buf.dirty = true
		return
	}
	buf.dirty_from = min(buf.dirty_from, from)
	buf.dirty_to = max(buf.dirty_to, to)
}

is_word_rune :: proc(r: rune) -> bool {
	return unicode.is_letter(r) || unicode.is_digit(r) || r == '_'
}

rune_at :: proc(line: string, col: int) -> rune {
	offset := rune_to_byte_offset(line, col)
	if offset >= len(line) {
		return 0
	}
	r, _ := utf8.decode_rune_in_string(line[offset:])
	return r
}

set_line :: proc(buf: ^Buffer, index: int, new_line: string) {
	delete(buf.data[index])
	buf.data[index] = new_line
	mark_dirty(buf, index, index)
}

insert_rune :: proc(buf: ^Buffer, r: rune) {
	line := current_line(buf)
	offset := rune_to_byte_offset(line, buf.cursor_x)

	encoded, size := utf8.encode_rune(r)
	new_line := make([]u8, len(line) + size)
	copy(new_line, line[:offset])
	copy(new_line[offset:], encoded[:size])
	copy(new_line[offset + size:], line[offset:])

	set_line(buf, buf.cursor_y, string(new_line))
	buf.cursor_x += 1
	buf.goal_x = buf.cursor_x
}

insert_text :: proc(buf: ^Buffer, text: string) {
	for r in text {
		if r == '\n' {
			insert_newline(buf)
		} else if r != '\r' {
			insert_rune(buf, r)
		}
	}
}

insert_newline :: proc(buf: ^Buffer) {
	line := current_line(buf)
	offset := rune_to_byte_offset(line, buf.cursor_x)

	head := strings.clone(line[:offset])
	tail := strings.clone(line[offset:])

	set_line(buf, buf.cursor_y, head)

	append(&buf.data, "")
	copy(buf.data[buf.cursor_y + 2:], buf.data[buf.cursor_y + 1 : len(buf.data) - 1])
	buf.data[buf.cursor_y + 1] = tail
	mark_dirty(buf, buf.cursor_y, len(buf.data) - 1)

	buf.cursor_y += 1
	buf.cursor_x = 0
	buf.goal_x = 0
}

backspace :: proc(buf: ^Buffer) {
	if buf.cursor_x > 0 {
		line := current_line(buf)
		end := rune_to_byte_offset(line, buf.cursor_x)
		_, size := utf8.decode_last_rune_in_string(line[:end])

		new_line := make([]u8, len(line) - size)
		copy(new_line, line[:end - size])
		copy(new_line[end - size:], line[end:])

		set_line(buf, buf.cursor_y, string(new_line))
		buf.cursor_x -= 1
		buf.goal_x = buf.cursor_x
	} else if buf.cursor_y > 0 {
		prev := buf.data[buf.cursor_y - 1]
		line := buf.data[buf.cursor_y]

		joined := make([]u8, len(prev) + len(line))
		copy(joined, prev)
		copy(joined[len(prev):], line)

		buf.cursor_x = utf8.rune_count(prev)

		delete(prev)
		delete(line)
		buf.data[buf.cursor_y - 1] = string(joined)
		ordered_remove(&buf.data, buf.cursor_y)
		mark_dirty(buf, buf.cursor_y - 1, len(buf.data) - 1)
		buf.cursor_y -= 1
		buf.goal_x = buf.cursor_x
	}
}

delete_forward :: proc(buf: ^Buffer) {
	line := current_line(buf)
	if buf.cursor_x < utf8.rune_count(line) {
		start := rune_to_byte_offset(line, buf.cursor_x)
		_, size := utf8.decode_rune_in_string(line[start:])

		new_line := make([]u8, len(line) - size)
		copy(new_line, line[:start])
		copy(new_line[start:], line[start + size:])

		set_line(buf, buf.cursor_y, string(new_line))
	} else if buf.cursor_y + 1 < len(buf.data) {
		next := buf.data[buf.cursor_y + 1]

		joined := make([]u8, len(line) + len(next))
		copy(joined, line)
		copy(joined[len(line):], next)

		delete(line)
		delete(next)
		buf.data[buf.cursor_y] = string(joined)
		ordered_remove(&buf.data, buf.cursor_y + 1)
		mark_dirty(buf, buf.cursor_y, len(buf.data) - 1)
	}
}

delete_to_line_start :: proc(buf: ^Buffer) {
	if buf.cursor_x == 0 {
		return
	}
	line := current_line(buf)
	end := rune_to_byte_offset(line, buf.cursor_x)

	new_line := make([]u8, len(line) - end)
	copy(new_line, line[end:])

	set_line(buf, buf.cursor_y, string(new_line))
	buf.cursor_x = 0
	buf.goal_x = 0
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

cursor_word_left :: proc(buf: ^Buffer) {
	line := current_line(buf)

	for buf.cursor_x > 0 && !is_word_rune(rune_at(line, buf.cursor_x - 1)) {
		buf.cursor_x -= 1
	}
	for buf.cursor_x > 0 && is_word_rune(rune_at(line, buf.cursor_x - 1)) {
		buf.cursor_x -= 1
	}

	buf.goal_x = buf.cursor_x
}

cursor_word_right :: proc(buf: ^Buffer) {
	line := current_line(buf)
	count := utf8.rune_count(line)

	for buf.cursor_x < count && !is_word_rune(rune_at(line, buf.cursor_x)) {
		buf.cursor_x += 1
	}
	for buf.cursor_x < count && is_word_rune(rune_at(line, buf.cursor_x)) {
		buf.cursor_x += 1
	}

	buf.goal_x = buf.cursor_x
}
