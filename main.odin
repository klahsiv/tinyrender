package main

import "core:fmt"
import "core:math"
import "core:os"

Width :: 64
Height :: 64

Coord :: struct {
	x, y: i32,
}

main :: proc() {
	fmt.println("Hello World")
	buf := make([]u8, Width * Height * 3)
	defer delete(buf)

	vertices := [3]Coord{{x = 7, y = 3}, {x = 12, y = 37}, {x = 62, y = 53}}
	render(vertices, buf)

	err := write_ppm("Sample.ppm", Width, Height, buf)
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

set_pixel :: proc(x, y, width: int, buf: []u8, rgb: [3]u8) {
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

swap :: proc(a, b: ^i32) {
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
