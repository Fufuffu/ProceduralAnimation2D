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
            linalg.normalize0(next_point.pos - reference_point.pos) * f32(reference_point.radius) + reference_point.pos
    }

    if rl.IsKeyPressed(.ESCAPE) {
        g_mem.run = false
    }
}

draw :: proc() {
    rl.BeginDrawing()
    rl.ClearBackground(rl.Color{0x24, 0x24, 0x24, 0xFF})

    segment_points := make([dynamic]rl.Vector2, 0, 6, allocator = context.temp_allocator)
    for i in 0 ..< len(g_mem.body.points) {
        reference_point := g_mem.body.points[i]

        if i != len(g_mem.body.points) - 1 {
            next_point := g_mem.body.points[i + 1]

            dir := linalg.normalize0(next_point.pos - reference_point.pos) * f32(reference_point.radius)

            if i == 0 {
                // Specific case, body head
                rl.DrawCircleV(reference_point.pos, f32(reference_point.radius), rl.RED)

                // Draw nose
                append(&segment_points, rl.Vector2Rotate(dir, linalg.to_radians(f32(90.0))) + reference_point.pos)
                append(&segment_points, rl.Vector2Rotate(dir, linalg.to_radians(f32(-90.0))) + reference_point.pos)
                append(&segment_points, (rl.Vector2Rotate(dir, linalg.to_radians(f32(160.0))) * 1.3) + reference_point.pos)
                append(&segment_points, (rl.Vector2Rotate(dir, linalg.to_radians(f32(-160.0))) * 1.3) + reference_point.pos)
                append(&segment_points, (-dir * 1.5) + reference_point.pos)
                draw_body_segment(segment_points[:])
                clear(&segment_points)

                // Draw eyes
                left_eye_pos := (rl.Vector2Rotate(dir, linalg.to_radians(f32(150.0))) * 0.6) + reference_point.pos
                right_eye_pos := (rl.Vector2Rotate(dir, linalg.to_radians(f32(-150.0))) * 0.6) + reference_point.pos

                rl.DrawCircleV(left_eye_pos, 5, rl.WHITE)
                rl.DrawCircleV(right_eye_pos, 5, rl.WHITE)
                rl.DrawCircleV(left_eye_pos, 2, rl.BLACK)
                rl.DrawCircleV(right_eye_pos, 2, rl.BLACK)

                // Prepare to draw next segments
                append(&segment_points, rl.Vector2Rotate(dir, linalg.to_radians(f32(60.0))) + reference_point.pos)
                append(&segment_points, rl.Vector2Rotate(dir, linalg.to_radians(f32(-60.0))) + reference_point.pos)
            } else {
                // General case, any body segment
                dir_clockwise := rl.Vector2{-dir.y, dir.x} + reference_point.pos
                dir_counterclockwise := rl.Vector2{dir.y, -dir.x} + reference_point.pos

                append(&segment_points, dir_clockwise)
                append(&segment_points, dir_counterclockwise)

                draw_body_segment(segment_points[:])
                clear(&segment_points)

                append(&segment_points, dir_clockwise)
                append(&segment_points, dir_counterclockwise)
            }
        } else {
            // Last segment
            last_point := g_mem.body.points[i - 1]

            dir := linalg.normalize0(reference_point.pos - last_point.pos) * f32(reference_point.radius)

            dir_clockwise := rl.Vector2{-dir.y, dir.x} + reference_point.pos
            dir_counterclockwise := rl.Vector2{dir.y, -dir.x} + reference_point.pos

            append(&segment_points, dir + reference_point.pos)
            append(&segment_points, dir_clockwise)
            append(&segment_points, dir_counterclockwise)

            draw_body_segment(segment_points[:])
        }
    }

    rl.EndDrawing()
}

draw_body_segment :: proc(points: []rl.Vector2) {
    center, sorted_vertices := sort_vertices(points[:])
    rl.DrawTriangleFan(raw_data(sorted_vertices), i32(len(sorted_vertices)), rl.RED)
    //rl.DrawCircleV(center, 3, rl.GREEN)
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
        for j := i; j > 0 && compute_key(points[j], center) < compute_key(points[j - 1], center); j -= 1 {
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
    radius: i32 = 30

    body_segments: i32 : 30
    points := make([]Point, body_segments, allocator = context.allocator)

    for i in 0 ..< body_segments {
        if i > body_segments - 3 {
            radius -= 5
        }

        pos := initial_pos - rl.Vector2{f32(i * radius), 0}
        points[i] = Point{pos, radius}

        if i == 0 {
            radius = 20
        }
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
