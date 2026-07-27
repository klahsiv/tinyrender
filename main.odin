package main

import "core:fmt"
import "core:math"
import "core:os"

Width :: 800
Height :: 800

Framebuffer :: struct {
	width, height: int,
	pixels:        []u8,
}

Coord :: struct {
	x, y: int,
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
	vertices := [3]Coord{{x = 7, y = 3}, {x = 12, y = 37}, {x = 62, y = 53}}

	buf := make([]u8, Width * Height * 3)
	defer delete(buf)
	framerbuffer := Framebuffer{Width, Height, buf}

	mesh: Mesh = Mesh{}
	defer delete(mesh.faces)
	defer delete(mesh.vertices)

	diablo := parse_obj("diablo3_pose.obj", &mesh)
	//render(vertices, buf)
	render_mesh(mesh, &framerbuffer)

	err := write_ppm("Diablo.ppm", Width, Height, buf)
	if err != nil {
		fmt.println(err)
		panic("Error in writing ppm file")
	}

}

render :: proc(vertices: [3]Coord, frameBuffer: ^Framebuffer) {

	a, b, c := vertices[0], vertices[1], vertices[2]
	line(a, b, frameBuffer, Red)
	line(b, c, frameBuffer, Blue)
	line(c, a, frameBuffer, Green)

	for coord in vertices {
		set_pixel(int(coord.x), int(coord.y), frameBuffer, White)
	}
}

render_mesh :: proc(mesh: Mesh, frameBuffer: ^Framebuffer) {

	vertices := mesh.vertices
	faces := mesh.faces

	for face in faces {
		a := project_vertex(vertices[face.x])
		b := project_vertex(vertices[face.y])
		c := project_vertex(vertices[face.z])

		line(a, b, frameBuffer, Red)
		line(b, c, frameBuffer, Red)
		line(c, a, frameBuffer, Red)
	}


	for coord in vertices {
		a := project_vertex(coord)
		set_pixel(int(a.x), int(a.y), frameBuffer, White)
	}


}
project_vertex :: proc(v: Vertex) -> Coord {
	return Coord {
		x = int(((v.x + 1.0) * 0.5) * f64(Width - 1)),
		y = int((1.0 - (v.y + 1.0) * 0.5) * f64(Height - 1)),
	}
}

set_pixel :: proc(x, y: int, frameBuffer: ^Framebuffer, rgb: [3]u8) {
	if x < 0 || x >= frameBuffer.width do return
	if y < 0 || y >= frameBuffer.height do return

	idx := (y * frameBuffer.width) + x
	idx *= 3
	frameBuffer.pixels[idx + 0] = rgb[0]
	frameBuffer.pixels[idx + 1] = rgb[1]
	frameBuffer.pixels[idx + 2] = rgb[2]
}

line :: proc(start, end: Coord, frameBuffer: ^Framebuffer, rgb: [3]u8) {
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
			set_pixel(int(y), int(x), frameBuffer, rgb)
		} else {
			set_pixel(int(x), int(y), frameBuffer, rgb)
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
