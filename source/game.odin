package game

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:slice"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

SCREEN_WIDTH :: 960
SCREEN_HEIGHT :: 540

Point :: struct {
	pos:    rl.Vector2,
	radius: i32,
}

Body :: struct {
	points: []Point,
}

Game_Memory :: struct {
	body: Body,
	run:  bool,
}

g_mem: ^Game_Memory

update :: proc() {
	input: rl.Vector2

	if rl.IsKeyDown(.UP) || rl.IsKeyDown(.W) {
		input.y -= 1
	}
	if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S) {
		input.y += 1
	}
	if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
		input.x -= 1
	}
	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
		input.x += 1
	}

	speed: f32 : 200
	input = linalg.normalize0(input)
	g_mem.body.points[0].pos += input * rl.GetFrameTime() * speed

	// Update body
	for i in 0 ..< len(g_mem.body.points) - 1 {
		reference_point := g_mem.body.points[i]
		next_point := g_mem.body.points[i + 1]

		g_mem.body.points[i + 1].pos =
			linalg.normalize0(next_point.pos - reference_point.pos) * f32(reference_point.radius) +
			reference_point.pos
	}

	if rl.IsKeyPressed(.ESCAPE) {
		g_mem.run = false
	}
}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.Color{0x24, 0x24, 0x24, 0xFF})

	for i in 0 ..< len(g_mem.body.points) {
		reference_point := g_mem.body.points[i]
		// Draw basic points
		rl.DrawCircleV(reference_point.pos, 5, rl.WHITE)
		rl.DrawCircleLinesV(reference_point.pos, f32(reference_point.radius), rl.RED)

		if i != len(g_mem.body.points) - 1 {
			next_point := g_mem.body.points[i + 1]

			dir :=
				linalg.normalize0(next_point.pos - reference_point.pos) *
				f32(reference_point.radius)

			if i == 0 {
				// Specific case, body head
				rl.DrawCircleV(-dir + reference_point.pos, 3, rl.YELLOW)
				for deg := -150; deg <= 150; deg += 30 {
					if abs(deg) == 30 do continue
					rotated_vec :=
						rl.Vector2Rotate(dir, linalg.to_radians(f32(deg))) + reference_point.pos
					rl.DrawCircleV(rotated_vec, 3, rl.YELLOW)
				}
			} else {
				// General case, any body segment
				dir_clockwise := rl.Vector2{-dir.y, dir.x} + reference_point.pos
				dir_counterclockwise := rl.Vector2{dir.y, -dir.x} + reference_point.pos

				rl.DrawCircleV(dir_clockwise, 3, rl.YELLOW)
				rl.DrawCircleV(dir_counterclockwise, 3, rl.YELLOW)
			}
		} else {
			// Last segment
			last_point := g_mem.body.points[i - 1]

			dir :=
				linalg.normalize0(reference_point.pos - last_point.pos) *
				f32(reference_point.radius)

			dir_clockwise := rl.Vector2{-dir.y, dir.x} + reference_point.pos
			dir_counterclockwise := rl.Vector2{dir.y, -dir.x} + reference_point.pos

			rl.DrawCircleV(dir + reference_point.pos, 3, rl.YELLOW)
			rl.DrawCircleV(dir_clockwise, 3, rl.YELLOW)
			rl.DrawCircleV(dir_counterclockwise, 3, rl.YELLOW)
		}
	}

	points: []rl.Vector2 = {
		rl.Vector2{10, 10},
		rl.Vector2{0, 100},
		rl.Vector2{100, 100},
		rl.Vector2{40, 10},
		rl.Vector2{80, 50},
		rl.Vector2{60, 20},
		rl.Vector2{100, 150},
		rl.Vector2{50, 140},
	}
	center, sorted_vertices := sort_vertices(points[:])
	rl.DrawTriangleFan(raw_data(points), i32(len(points)), rl.RED)
	rl.DrawCircleV(center, 3, rl.GREEN)

	for point in points {
		rl.DrawCircleV(point, 3, rl.PINK)
	}

	rl.EndDrawing()
}

sort_vertices :: proc(points: []rl.Vector2) -> (center: rl.Vector2, sorted_points: []rl.Vector2) {
	// Calculate polygon centroid
	center = rl.Vector2(0)
	for point in points {
		center += point
	}
	center = center / f32(len(points))

	compute_key :: proc(a: rl.Vector2, center: rl.Vector2) -> f32 {
		return math.mod((math.to_degrees(math.atan2(a.x - center.x, a.y - center.y)) + 360), 360)
	}

	// Insertion sort by key
	for i in 1 ..< len(points) {
		for j := i;
		    j > 0 && compute_key(points[j], center) < compute_key(points[j - 1], center);
		    j -= 1 {
			tmp := points[j]
			points[j] = points[j - 1]
			points[j - 1] = tmp
		}
	}

	return center, points
}

@(export)
game_update :: proc() {
	update()
	draw()
}

@(export)
game_init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Procedural animation")
	rl.SetTargetFPS(144)
	rl.SetExitKey(nil)
}

@(export)
game_init :: proc() {
	g_mem = new(Game_Memory)

	initial_pos := rl.Vector2{SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2}
	radius: i32 = 60

	body_segments: i32 : 5
	points := make([]Point, body_segments, allocator = context.allocator)

	for i in 0 ..< body_segments {
		pos := initial_pos - rl.Vector2{f32(i * radius), 0}
		points[i] = Point{pos, radius}
	}

	g_mem^ = Game_Memory {
		body = Body{points = points},
		run = true,
	}

	game_hot_reloaded(g_mem)
}

@(export)
game_should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		// Never run this proc in browser. It contains a 16 ms sleep on web!
		if rl.WindowShouldClose() {
			return false
		}
	}

	return g_mem.run
}

@(export)
game_shutdown :: proc() {
	delete(g_mem.body.points)

	free(g_mem)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseWindow()
}

@(export)
game_memory :: proc() -> rawptr {
	return g_mem
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(Game_Memory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	g_mem = (^Game_Memory)(mem)

	// Here you can also set your own global variables. A good idea is to make
	// your global variables into pointers that point to something inside
	// `g_mem`.
}

@(export)
game_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.F6)
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
game_parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(i32(w), i32(h))
}
