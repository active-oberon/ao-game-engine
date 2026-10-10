# ao-game-engine

Reusable game mechanisms in Active Oberon, with ao-doom as the first consumer.
The current engine runs a deterministic simulation, renders textured or flat colored walls,
and presents a software framebuffer through MiniA2's display interface.

## Build and check

Install the MiniA2 Linux64 SDK (`ob`), Task, and `timeout`, then run:

```sh
task check
```

The checks cover ordered ticks, concurrent callers, shutdown, ray intersections,
wall endpoints, sliding collision, movement without tunneling, pixel clipping,
signed binary decoding, hostile byte ranges, fractional tick accumulation, sealed materials, light levels, and wrapping texture coordinates.
Every executable has a ten-second timeout. The display is checked through
`task gui-check` in ao-doom, using the actual scene and targeted X11 key events.

## Modules and ownership

- `GameLoop`: an active simulation object and a game-provided step delegate.
- `GameClock`: conversion of elapsed milliseconds to exact fractional ticks.
- `GameGeometry`: sealed wall segments, ray intersections, and circle movement.
- `GameSurface`: a reusable BGRX framebuffer and checked PPM export.
- `GameMaterials`: sealed RGB textures with wrapping sample coordinates.
- `GameRenderer`: perspective projection, material scale/offset, light and distance shading.
- `GameDisplay`: integer scaling and presentation through MiniA2 `Displays`.
- `GameBytes`: bounded file reads and explicit little-endian integer decoding.

The engine does not import game modules or interpret Doom data. Build outputs
stay in each consumer's own directory. Framebuffer storage is allocated once
and reused; only diagnostic PPM export allocates an additional row buffer.

## Simulation contract

`GameLoop.Simulation` owns an activity. `Advance(count)` submits an exact number
of ticks and waits for completion; ticks start at one and do not depend on wall
clock time. Negative requests, counter overflow, and requests after shutdown
return `FALSE`. `Close` drains accepted work and waits for activity termination.
Concurrent callers are serialized; no ordering between callers is promised.

The step delegate runs under the simulation's exclusive lock. It must return,
must not trap, and must not call back into the simulation or wait on another
activity that needs this lock. This version has no callback failure recovery.

`GameClock` preserves sub-tick remainders. The caller decides how to handle a
long pause and owns input snapshots. Doom clamps a frame delay to 250 ms and
runs at 35 ticks per second; those choices are game policy.

Build a `World`, add validated walls, then `Seal` it before reading. After sealing
it is immutable through the public API and can be shared by simulation and
rendering activities. Take an atomic copy of the world reference and camera
state before rendering; rendering then holds no simulation monitor.

`World.Move` divides movement into steps shorter than half the player radius
and slides along blocked axes. It rejects invalid coordinates and moves longer
than 2047 radii. It checks all walls, regardless of their vertical extent: this
is planar collision, not a model of stairs, jumping, or sector transitions.

## Limits and next steps

The renderer casts one ray per column and scans every wall. It supports textured or flat
colored vertical walls, a flat background, and a fixed field of view. It has no
sprites, portals, floor projection, or spatial acceleration. The
presenter currently supports three- and four-byte desktop display formats.
File reads are capped at 64 MiB. Geometry is capped at 65536 walls and finite
coordinates within one million world units.

Next: loading image materials, then sector portals and
floor projection. Add a spatial index when actual map costs justify it. Use
active objects for independent loading or rendering work only when ownership
and measured benefit justify another activity; preserve deterministic gameplay.

The implementation is original; no third-party engine code has been copied.
