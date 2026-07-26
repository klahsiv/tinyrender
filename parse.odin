package main

import "core:os"
import "core:strconv"
import "core:strings"

parse_obj :: proc(filename: string, mesh: ^Mesh) -> os.Error {
	data, err := os.read_entire_file_from_path(filename, context.allocator)
	if err != nil {
		return err
	}
	defer delete(data)

	text := string(data)
	for line in strings.split_lines_iterator(&text) {

		switch {
		case strings.has_prefix(line, "v "):
			fields := strings.fields(line[2:])

			x, _ := strconv.parse_f64(fields[0])
			y, _ := strconv.parse_f64(fields[1])
			z, _ := strconv.parse_f64(fields[2])

			append(&mesh.vertices, Vertex{x, y, z}) or_return
		case strings.has_prefix(line, "f "):
			fields := strings.fields(line[2:])
			x, _ := strconv.parse_int(strings.split(fields[0], "//", context.allocator)[0])
			y, _ := strconv.parse_int(strings.split(fields[1], "//", context.allocator)[0])
			z, _ := strconv.parse_int(strings.split(fields[2], "//", context.allocator)[0])

			append(&mesh.faces, Face{x - 1, y - 1, z - 1}) or_return
		}
	}

	return nil
}

//parse_face_vertex(data: string) ->
