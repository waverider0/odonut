package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:time"

PI :: 3.14159265359

R :: 1.0
r :: 0.5
N :: 100

LIGHT :: [3]f32{0, -5, 0} // reverse y

Z_PRIME :: 3.0 // focal length

WIDTH :: 100
HEIGHT :: 100

ASCII_CHARS := [11]rune{'.', '-', '~', ':', ';', '=', '!', '*', '#', '$', '@'}

main :: proc() {
        theta_x, theta_y: f32 = 0.0, 0.0

        for {
                fmt.print("\x1b[2J\x1b[H") // clear terminal
                fmt.print("\x1B[?25l") // hide cursor
                update(&theta_x, &theta_y)
        }
}

update :: proc(theta_x: ^f32, theta_y: ^f32) {
        // compute torus and lighting

        rot_x := matrix[3, 3]f32{
                1, 0, 0,
                0, math.cos(theta_x^), -math.sin(theta_x^),
                0, math.sin(theta_x^), math.cos(theta_x^),
        }
        rot_y := matrix[3, 3]f32{
                math.cos(theta_y^), 0, -math.sin(theta_y^),
                0, 1, 0,
                math.sin(theta_y^), 0, math.cos(theta_y^),
        }

        theta_x^ = 0 if (theta_x^ >= 2 * PI) else theta_x^ + 0.03;
        theta_y^ = 0 if (theta_y^ >= 2 * PI) else theta_y^ + 0.06;

        depth_buffer: [WIDTH][HEIGHT]f32 = max(f32)
        compute_torus(&depth_buffer, &rot_x, &rot_y)

        // draw torus

        for x in 1..<WIDTH {
                for y in 1..<HEIGHT {
                        brightness := depth_buffer[x][y]
                        brightness_adjusted := uint((brightness + 1) * 5) if brightness != max(f32) else max(uint) // continuous [-1, 1] -> discrete [0, 10]
                        if (brightness_adjusted >= 0 && brightness_adjusted <= 10) {
                                ascii := ASCII_CHARS[brightness_adjusted]
                                fmt.printf("\x1B[%d;%dH", HEIGHT - y, x) // move cursor
                                fmt.printf("%c", ascii)
                        }
                }
        }

        time.sleep(20 * time.Millisecond)
}

compute_torus :: proc(depth_buffer: ^[WIDTH][HEIGHT]f32, rot_x: ^matrix[3, 3]f32, rot_y: ^matrix[3, 3]f32) {
        // oversample points
        for a in 0..<N {
                // big circle
                theta := f32(2) * PI * f32(a) / N
                cos_theta := math.cos(theta)
                sin_theta := math.sin(theta)

                for b in 0..<N {
                        // small circle
                        phi := f32(2) * PI * f32(b) / N
                        cos_phi := math.cos(phi)
                        sin_phi := math.sin(phi)

                        // rotated point

                        point := [3]f32{
                                (R + r * cos_phi) * cos_theta,   // x
                                r * sin_phi,                     // y
                                (R + r * cos_phi) * sin_theta,   // z
                        } * rot_x^ * rot_y^

                        // lighting

                        t_theta := [3]f32{
                                -(R + r * cos_phi) * sin_theta,  // dx/d_theta
                                0,                               // dy/d_theta
                                (R + r * cos_phi) * cos_theta ,  // dz/d_theta
                        } * rot_x^ * rot_y^

                        t_phi := [3]f32{
                                -r * sin_phi * cos_theta,        // dx/d_phi
                                r * cos_phi,                     // dy/d_phi
                                -r * sin_phi * sin_theta,        // dz/d_phi
                        } * rot_x^ * rot_y^

                        normal := linalg.normalize(linalg.cross(t_theta, t_phi))
                        brightness := linalg.dot(normal, LIGHT) / (linalg.length(normal) * linalg.length(LIGHT)) // cosine similarity

                        // perspective projection

                        z_translated := point[2] + 10 // manually offset by 10 units

                        // convert from unit-space coordinates to pixel-space coordinates (scale the normalized coordinates to fit a 100x100 pixel grid with (50,50) as the center)
                        x := (Z_PRIME * point[0] / z_translated) * 50
                        y := (Z_PRIME * point[1] / z_translated) * 50

                        // manually offset the pixels so the donut fits in the terminal
                        pixel_x := uint(x + 25)
                        pixel_y := uint(y + 75)

                        // NOTE: depth_buffer[pixel_x][pixel_y] is set to max(f32) by default unless it's updated
                        if (pixel_x >= 0 && pixel_x <= WIDTH && pixel_y >= 0 && pixel_y <= HEIGHT) {
                                if (z_translated < depth_buffer^[pixel_x][pixel_y]) {
                                        depth_buffer^[pixel_x][pixel_y] = brightness
                                }
                        }
                }
        }
}

