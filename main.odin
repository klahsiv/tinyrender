package main

import "core:fmt"
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
	render(buf, Width, Height)

	err := write_ppm("Sample.ppm", Width, Height, buf)
	if err != nil {
		fmt.println(err)
		panic("Error in writing ppm file")
	}

}

render :: proc(buf: []u8, width, height: int) {

	for i := 0; i < width; i += 1 {
		for j := 0; j < height; j += 1 {
			r := f64(i) / f64(Width - 1)
			g := f64(j) / f64(Height - 1)
			b := 0.0

			ir := int(255.999 * r)
			ig := int(255.999 * g)
			ib := int(255.999 * b)

			set_pixel(i, j, width, buf, u8(ir), u8(ig), u8(ib))
		}
	}
}

set_pixel :: proc(x, y, width: int, buf: []u8, r, g, b: u8) {
	idx := (y * width) + x
	idx *= 3
	buf[idx] = r
	buf[idx + 1] = g
	buf[idx + 2] = b
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
