package editor

import "core:fmt"
import "core:os"
import "core:strings"

Buffer :: struct {
	data:     [dynamic]string,
	cursor_y: int,
	cursor_x: int,
}

init :: proc(buf: ^Buffer) {
	buf.cursor_x = 0
	buf.cursor_y = 0
	buf.data = {}
}

init_from_file :: proc(
	buf: ^Buffer,
	file_path: string,
	allocator := context.allocator,
) -> os.Error {
	buf.cursor_x = 0
	buf.cursor_y = 0

	content, err := os.read_entire_file(file_path, allocator)
	if err != nil {
		return err
	}
	defer delete(content)

	lines := strings.split_lines(string(content), allocator)
	defer delete(lines)

	buf.data = make([dynamic]string, allocator = allocator)
	for line in lines {
		append(&buf.data, strings.clone(line, allocator))
	}

	return nil
}
