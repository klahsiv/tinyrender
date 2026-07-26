package main

import "core:fmt"
import "core:math"
import "core:os"

Width :: 800
Height :: 800

Coord :: struct {
	x, y: i32,
}

Vertex :: struct {
	x, y, z: f64,
}

Face :: struct {
	x, y, z: int,
}

Mesh :: struct {
	vertices: [dynamic]Vertex,
	faces:    [dynamic]Face,
}

main :: proc() {
	fmt.println("Hello World")
	buf := make([]u8, Width * Height * 3)
	defer delete(buf)

	vertices := [3]Coord{{x = 7, y = 3}, {x = 12, y = 37}, {x = 62, y = 53}}
	mesh: Mesh = Mesh{}
	defer delete(mesh.faces)
	defer delete(mesh.vertices)
	
	diablo := parse_obj("diablo3_pose.obj", &mesh)
	//render(vertices, buf)
	render_mesh(mesh, buf)

	err := write_ppm("Diablo.ppm", Width, Height, buf)
	if err != nil {
		fmt.println(err)
		panic("Error in writing ppm file")
	}

}

render :: proc(vertices: [3]Coord, buf: []u8) {

	a, b, c := vertices[0], vertices[1], vertices[2]
	line(a, b, buf, Red)
	line(b, c, buf, Blue)
	line(c, a, buf, Green)

	for coord in vertices {
		set_pixel(int(coord.x), int(coord.y), Width, buf, White)
	}
}

render_mesh :: proc(mesh: Mesh, buf: []u8) {

	vertices := mesh.vertices
	faces := mesh.faces

	for face in faces {
		a := vertices[face.x]
		b := vertices[face.y]
		c := vertices[face.z]
		transform_vertex(&a)
		transform_vertex(&b)
		transform_vertex(&c)

		line_mesh(a, b, buf, Red)
		line_mesh(b, c, buf, Red)
		line_mesh(c, a, buf, Red)
	}

	/*
	for coord in vertices {
		set_pixel(int(coord.x), int(coord.y), Width, buf, White)
	}
	*/

}

transform_vertex :: proc(vertex: ^Vertex) {
	vertex.x = ((vertex.x + 1.0) * 0.5) * f64(Width - 1)
	vertex.y = (1.0 - (vertex.y + 1.0) * 0.5) * f64(Height - 1)
}

set_pixel :: proc(x, y, width: int, buf: []u8, rgb: [3]u8) {
	//fmt.println(x, y)
	idx := (y * width) + x
	idx *= 3
	buf[idx + 0] = rgb[0]
	buf[idx + 1] = rgb[1]
	buf[idx + 2] = rgb[2]
}

line :: proc(start, end: Coord, buf: []u8, rgb: [3]u8) {
	ax, bx := start.x, end.x
	ay, by := start.y, end.y

	steep := math.abs(ax - bx) < math.abs(ay - by)
	if steep {
		swap(&ax, &ay)
		swap(&bx, &by)
	}

	if (ax > bx) {
		swap(&ax, &bx)
		swap(&ay, &by)
	}

	for x := ax; x <= bx; x += 1 {
		t := f32(x - ax) / f32(bx - ax)
		y := f32(ay) + (f32(by - ay) * t)

		if steep {
			set_pixel(int(y), int(x), Width, buf, rgb)
		} else {
			set_pixel(int(x), int(y), Width, buf, rgb)
		}
	}
}

line_mesh :: proc(start, end: Vertex, buf: []u8, rgb: [3]u8) {
	ax, bx := start.x, end.x
	ay, by := start.y, end.y

	steep := math.abs(ax - bx) < math.abs(ay - by)
	if steep {
		swap(&ax, &ay)
		swap(&bx, &by)
	}

	if (ax > bx) {
		swap(&ax, &bx)
		swap(&ay, &by)
	}

	for x := ax; x <= bx; x += 1 {
		t := f32(x - ax) / f32(bx - ax)
		y := f32(ay) + (f32(by - ay) * t)

		if steep {
			set_pixel(int(y), int(x), Width, buf, rgb)
		} else {
			set_pixel(int(x), int(y), Width, buf, rgb)
		}
	}
}

swap :: proc(a, b: ^$T) {
	tmp := a^
	a^ = b^
	b^ = tmp
}

write_ppm :: proc(filename: string, width, height: u32, buf: []u8) -> os.Error {
	// P6 header
	header := fmt.tprintf("P6\n%d %d\n255\n", width, height)

	data := make([]u8, len(header) + len(buf))
	defer delete(data)

	copy(data[:len(header)], transmute([]u8)header)
	copy(data[len(header):], buf)

	return os.write_entire_file(filename, data)
}
