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
DepthBuffer :: struct {
	width, height: int,
	depth:         []f64,
}

ScreenVertex :: struct {
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

	vertices := [3]ScreenVertex{{x = 7, y = 3}, {x = 12, y = 37}, {x = 62, y = 53}}
	vertices1 := [3]ScreenVertex{{x = 7, y = 45}, {x = 35, y = 100}, {x = 45, y = 60}}
	vertices2 := [3]ScreenVertex{{x = 120, y = 35}, {x = 90, y = 5}, {x = 45, y = 110}}
	vertices3 := [3]ScreenVertex{{x = 115, y = 83}, {x = 80, y = 90}, {x = 85, y = 120}}

	buf := make([]u8, Width * Height * 3)
	defer delete(buf)
	framerbuffer := Framebuffer{Width, Height, buf}

	zbuf := make([]f64, Width * Height)
	for i := 0; i < len(zbuf); i += 1 {
		zbuf[i] = -math.INF_F64
	}
	defer delete(zbuf)
	zbuffer := DepthBuffer{Width, Height, zbuf}

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
	err = write_depth_ppm("Head_Triangles_z.ppm", &zbuffer)
	if err != nil {
		fmt.println(err)
		panic("Error in writing ppm file")
	}

}

triangle :: proc(
	vertices: [3]ScreenVertex,
	frameBuffer: ^Framebuffer,
	zbuffer: ^DepthBuffer,
	colour: [3]u8,
) {

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
			cur := ScreenVertex{x, y, 0}
			alpha := signed_triangle_area(cur, b, c) / total_area
			beta := signed_triangle_area(cur, c, a) / total_area
			gamma := signed_triangle_area(cur, a, b) / total_area

			if alpha < 0 || beta < 0 || gamma < 0 {
				continue
			}

			z := (alpha * f64(a.z) + beta * f64(b.z) + gamma * f64(c.z))
			if z <= get_depth(x, y, zbuffer) {
				continue
			}
			set_pixel(x, y, frameBuffer, colour)
			set_depth(x, y, zbuffer, z)
		}
	}

}

signed_triangle_area :: proc(a, b, c: ScreenVertex) -> f64 {
	return 0.5 * f64((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x))
}

render :: proc(vertices: [3]ScreenVertex, frameBuffer: ^Framebuffer) {

	a, b, c := vertices[0], vertices[1], vertices[2]
	line(a, b, frameBuffer, Red)
	line(b, c, frameBuffer, Blue)
	line(c, a, frameBuffer, Green)

	for coord in vertices {
		set_pixel(int(coord.x), int(coord.y), frameBuffer, White)
	}
}

render_mesh :: proc(mesh: Mesh, frameBuffer: ^Framebuffer, zbuffer: ^DepthBuffer) {

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
		coords := [3]ScreenVertex{a, b, c}

		triangle(coords, frameBuffer, zbuffer, col)

	}
}

project_vertex :: proc(v: Vertex) -> ScreenVertex {
	return ScreenVertex {
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

get_depth :: proc(x, y: int, frameBuffer: ^DepthBuffer) -> f64 {
	if x < 0 || x >= frameBuffer.width do return -math.INF_F64
	if y < 0 || y >= frameBuffer.height do return -math.INF_F64

	idx := (y * frameBuffer.width) + x
	return frameBuffer.depth[idx]
}

set_depth :: proc(x, y: int, frameBuffer: ^DepthBuffer, col: f64) {
	if x < 0 || x >= frameBuffer.width do return
	if y < 0 || y >= frameBuffer.height do return

	idx := (y * frameBuffer.width) + x
	frameBuffer.depth[idx + 0] = col
}

line :: proc(start, end: ScreenVertex, frameBuffer: ^Framebuffer, rgb: [3]u8) {
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

write_ppm :: proc(filename: string, width, height: int, buf: []u8) -> os.Error {
	// P6 header
	header := fmt.tprintf("P6\n%d %d\n255\n", width, height)

	data := make([]u8, len(header) + len(buf))
	defer delete(data)

	copy(data[:len(header)], transmute([]u8)header)
	copy(data[len(header):], buf)

	return os.write_entire_file(filename, data)
}

write_depth_ppm :: proc(filename: string, db: ^DepthBuffer) -> os.Error {
	// P6 header

	data := make([]u8, db.width * db.height * 3)
	defer delete(data)

	for y in 0 ..< db.height {
		for x in 0 ..< db.width {
			d := get_depth(x, y, db)
			v := u8(math.clamp(d, 0, 255))

			idx := (y * db.width + x) * 3
			data[idx + 0] = v
			data[idx + 1] = v
			data[idx + 2] = v
		}
	}

	return write_ppm(filename, db.width, db.height, data)
}
