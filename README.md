# ao-game-engine

Reusable game mechanisms in Active Oberon, with ao-doom as the first consumer.
The current engine runs a deterministic simulation, renders textured walls and
sector floor/ceiling planes and panoramic skies, and presents a software framebuffer through MiniA2's
display interface.

## Build and check

Install the MiniA2 Linux64 SDK (`ob`), Task, and `timeout`, then run:

```sh
task check
```

The checks cover ordered ticks, concurrent callers, shutdown, ray intersections,
wall endpoints, sliding collision, movement without tunneling, pixel clipping,
signed binary decoding, hostile byte ranges, fractional tick accumulation, sealed materials, light levels, and wrapping texture coordinates.
Sector checks cover copied immutable regions, portal ray traversal, bounded
steps, player clearance, descent, projected floor pixels, sealed sky materials,
fullbright panorama mapping, shared sky across different ceiling heights and
physical ceiling clearance beneath sky. Partition checks cover copied trees,
node/leaf references, cycles, axis/diagonal decisions, exact boundary ties and
wall bounds. Player checks distinguish tangent contact from penetration.
Every executable has a ten-second timeout. The display is checked through
`task gui-check` in ao-doom, using the actual scene and targeted X11 key events.

## Modules and ownership

- `GameLoop`: an active simulation object and a game-provided step delegate.
- `GameClock`: conversion of elapsed milliseconds to exact fractional ticks.
- `GameGeometry`: sealed sectors/wall segments, ray intersections and circle movement.
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

Build a `World`, optionally call `SetSectors` and `SetPartition`, add validated
walls, then `Seal` it before reading. Each sector wall names its owning sector and its neighbor, or
`-1` for a solid boundary. Shared edges need a directed wall for each side.
`omitUpper` and `omitLower` suppress wall tiers and their clipping;
`omitMiddle` suppresses a solid wall material while the ray still stops there.
All three flags leave collision intact. FALSE flags retain solid-color fallback.
Sectored worlds accept inverted floor/ceiling heights to represent closed
regions; those regions cannot provide player clearance. Unsectored walls still
require positive height.
A sector can supply a sealed `skyTexture` with positive `skyUScale`/`skyVScale`
and finite `skyVOffset`. Sky sampling depends on viewing angle and screen row;
it ignores position and lighting. Caller-provided mapping keeps game constants
out of the engine. Adjacent sky sectors omit their upper boundary even when
their physical ceiling heights differ. After sealing
it is immutable through the public API and can be shared by simulation and
rendering activities. Take an atomic copy of the world reference and camera
state before rendering; rendering then holds no simulation monitor.

`SetPartition` copies a bottom-up tree and its leaf-to-sector table. Nonnegative
children name earlier nodes; negative children encode leaf index as `-index-1`.
The last node is the root; an empty tree requires one leaf. Finite nonzero
partition directions and all references are checked before publication.
`Locate` and `Contains` use this tree within the wall bounds; without a tree
they retain the closed-contour test. This indexes region membership; ray casting
and collision continue to use the wall geometry. Rays choose the region
immediately ahead of the camera so exact portal starts still render.

`World.Move` divides movement into steps shorter than half the player radius
and slides along blocked axes. It rejects invalid coordinates and moves longer
than 2047 radii. It checks all walls, regardless of their vertical extent: this
is planar collision. Sectored worlds use `Stand` and `MovePlayer` instead: these
check nearby openings against the caller's radius, height and step limit,
combine contacted floor/ceiling bounds and update feet height. Player contact
may be exactly tangent to a wall; penetration is blocked. Drop height snaps
to the floor; gravity, jumping and smoothing remain game policy.

## Limits and next steps

The renderer casts one ray per column with a fixed field of view. Sectored worlds
traverse openings in increasing distance, clip upper/lower walls and project
floor/ceiling textures. Walls are grouped by their sector; collision still scans
all walls. The partition tree accelerates region lookup only. It has no masked
surfaces, sprites or wall spatial index. The presenter currently supports three- and four-byte desktop display formats.
File reads are capped at 64 MiB. Geometry is capped at 131072 directed walls,
65536 sectors and finite
coordinates within one million world units.

Next: masked surfaces and sprites. Add a spatial index when actual map costs
justify it. Use
active objects for independent loading or rendering work only when ownership
and measured benefit justify another activity; preserve deterministic gameplay.

The implementation is original; no third-party engine code has been copied.
