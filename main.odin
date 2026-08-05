package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:os"

Width :: 800
Height :: 800

Framebuffer :: struct {
	width, height: int,
	pixels:        []u8,
}

Coord :: struct {
	x, y, z: int,
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
	vertices1 := [3]Coord{{x = 7, y = 45}, {x = 35, y = 100}, {x = 45, y = 60}}
	vertices2 := [3]Coord{{x = 120, y = 35}, {x = 90, y = 5}, {x = 45, y = 110}}
	vertices3 := [3]Coord{{x = 115, y = 83}, {x = 80, y = 90}, {x = 85, y = 120}}

	buf := make([]u8, Width * Height * 3)
	defer delete(buf)
	framerbuffer := Framebuffer{Width, Height, buf}

	zbuf := make([]u8, Width * Height * 3)
	defer delete(zbuf)
	zbuffer := Framebuffer{Width, Height, zbuf}

	diabloMesh: Mesh = Mesh{}
	defer delete(diabloMesh.faces)
	defer delete(diabloMesh.vertices)
	body := parse_obj("Assets/Diablo/diablo3_pose.obj", &diabloMesh)

	africanHeadMesh: Mesh = Mesh{}
	defer delete(africanHeadMesh.faces)
	defer delete(africanHeadMesh.vertices)
	eyes := parse_obj("Assets/African_Head/african_head.obj", &africanHeadMesh)

	headMesh: Mesh = Mesh{}
	defer delete(headMesh.faces)
	defer delete(headMesh.vertices)
	head := parse_obj("Assets/African_Head/african_head_eye_outer.obj", &headMesh)

	render_mesh(africanHeadMesh, &framerbuffer, &zbuffer)

	err := write_ppm("Head_Triangles.ppm", Width, Height, buf)
	err = write_ppm("Head_Triangles_z.ppm", Width, Height, zbuf)
	if err != nil {
		fmt.println(err)
		panic("Error in writing ppm file")
	}

}

triangle :: proc(vertices: [3]Coord, frameBuffer, zbuffer: ^Framebuffer, colour: [3]u8) {

	a, b, c := vertices[0], vertices[1], vertices[2]

	bbminx := min(a.x, b.x, c.x)
	bbminy := min(a.y, b.y, c.y)

	bbmaxx := max(a.x, b.x, c.x)
	bbmaxy := max(a.y, b.y, c.y)

	total_area := signed_triangle_area(a, b, c)
	if total_area == 0 {
		return
	}

	for x := bbminx; x <= bbmaxx; x += 1 {
		for y := bbminy; y <= bbmaxy; y += 1 {
			cur := Coord{x, y, 0}
			alpha := signed_triangle_area(cur, b, c) / total_area
			beta := signed_triangle_area(cur, c, a) / total_area
			gamma := signed_triangle_area(cur, a, b) / total_area

			if alpha < 0 || beta < 0 || gamma < 0 {
				continue
			}

			z := u8((alpha * f64(a.z) + beta * f64(b.z) + gamma * f64(c.z)))
			if z <= get_pixel(x, y, zbuffer)[0] {
				continue
			}
			set_pixel(x, y, frameBuffer, colour)
			set_pixel(x, y, zbuffer, [3]u8{z, z, z})
		}
	}

}

signed_triangle_area :: proc(a, b, c: Coord) -> f64 {
	return 0.5 * f64((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x))
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

render_mesh :: proc(mesh: Mesh, frameBuffer, zbuffer: ^Framebuffer) {

	vertices := mesh.vertices
	faces := mesh.faces

	for face in faces {
		a := project_vertex(vertices[face.x])
		b := project_vertex(vertices[face.y])
		c := project_vertex(vertices[face.z])

		col := [3]u8{0, 0, 0}
		for i := 0; i < 3; i += 1 {
			col[i] = u8(rand.int31_max(256))
		}
		coords := [3]Coord{a, b, c}

		triangle(coords, frameBuffer, zbuffer, col)

	}
}

project_vertex :: proc(v: Vertex) -> Coord {
	return Coord {
		x = int(((v.x + 1.0) * 0.5) * f64(Width - 1)),
		y = int((1.0 - (v.y + 1.0) * 0.5) * f64(Height - 1)),
		z = int((v.z + 1.0) * 255.0 * 0.5),
	}
}

get_pixel :: proc(x, y: int, frameBuffer: ^Framebuffer) -> [3]u8 {
	if x < 0 || x >= frameBuffer.width do return [3]u8{}
	if y < 0 || y >= frameBuffer.height do return [3]u8{}

	idx := (y * frameBuffer.width) + x
	idx *= 3
	return [3]u8 {
		frameBuffer.pixels[idx + 0],
		frameBuffer.pixels[idx + 1],
		frameBuffer.pixels[idx + 2],
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
