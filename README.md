# ao-game-engine

Reusable game mechanisms in Active Oberon, with ao-doom as the first consumer.
The current target is a reusable sector-based engine for complete classic Doom
and Doom II games. Quake, Doom 3 and Doom 3: BFG Edition are later projects.
The current engine runs a deterministic simulation, renders textured walls and
sector floor/ceiling planes and panoramic skies, and presents a software framebuffer through MiniA2's
display interface.
Two-sided middle materials render with binary coverage and retain the nearest
covered texel through multiple portal openings. Camera-facing sprites share
the same depth checks with walls, grilles and floor/ceiling planes.

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
wall bounds. Player checks distinguish tangent contact from penetration. Occupancy checks
cover game-provided obstacle rejection, sliding across a step, exact tangents,
invalid motion without mutation and the NIL callback path. Ceiling snapshot
checks reject invalid input, preserve earlier worlds and update rendering and
clearance together.
Masked checks distinguish transparent texels from opaque black, reject
unsealed materials and invalid texel density. Doom's integration checks cover
layer ordering, clipping, offsets, pegging, moving ceilings and same-sector lines.
Sprite checks cover depth ordering, reset, invisible occluders, transparent
holes, opaque black, mirrored columns, fullbright shading, overlapping sprites
and walls. Text checks cover glyph coverage, transparent spacing, unknown
characters and clipping at the frame edges. Animation checks cover exact frame
boundaries, looping, last-frame hold, copied input and large tick counts. Ray
checks cover sloped floor/ceiling clipping, portals, closed ceiling snapshots,
boundary starts and invalid inputs. Six executables each have a ten-second timeout. The display is checked through
`task gui-check` in ao-doom, using the actual scene and targeted X11 key events.

## Modules and ownership

- `GameLoop`: an active simulation object and a game-provided step delegate.
- `GameClock`: conversion of elapsed milliseconds to exact fractional ticks.
- `GameGeometry`: sealed sectors/wall segments, sloped ray clipping, circle movement and accepted-path observations.
- `GameAnimation`: immutable tick-based clips with looping and last-frame hold.
- `GameSurface`: reusable BGRX and depth buffers, clipped depth writes and PPM export.
- `GameMaterials`: sealed RGB textures with binary coverage and wrapping sample coordinates.
- `GameRenderer`: wall/plane/sprite projection, material mapping, light and distance shading.
- `GameText`: original 3-by-5 bitmap text for asset-free overlays.
- `GameDisplay`: integer scaling and presentation through MiniA2 `Displays`.
- `GameBytes`: bounded file reads and explicit little-endian integer decoding.

The engine does not import game modules or interpret Doom data. Games supply
animation timing and choose playback; the engine contains no default gameplay
rate, frame names, actor identifiers or damage rules. Build outputs
stay in each consumer's own directory. Framebuffer storage is allocated once
and reused; only diagnostic PPM export allocates an additional row buffer.
The FLOAT64 depth buffer adds eight bytes per pixel: 512000 bytes at 320 x 200.
`Background` resets depth, `DepthSpan` writes covered pixels only when they are
no farther away, and `Occlude` blocks later pixels without changing the color.
`Span` remains a color-only operation for backgrounds and overlays.

`GameText.Draw` writes uppercase ASCII letters, digits and basic punctuation
with a four-pixel advance and five-pixel height. Spaces and unsupported characters
advance without drawing. It uses clipped color-only spans, so overlays leave
scene depth intact and need no font files or per-frame allocation. Games own
labels, values, panel layout and state capture.

## Simulation contract

`GameAnimation.Read` copies 1-16 positive integer frame durations into a clip;
`Uniform` builds the same representation for constant-rate sequences. Invalid
input returns NIL. `count` and SIGNED64 `duration` are read-only; source edits
cannot change an existing clip. `Frame(elapsed, looping)` clamps negative
elapsed time to zero, loops at the complete duration when requested, or holds
the final frame indefinitely. Caller-provided durations use simulation ticks,
with no allocation or mutable clock during playback. Games own clip selection,
expiry, images, effect placement and actions such as delayed barrel damage.

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
`omitMiddle` suppresses solid or masked middle materials; rays still stop at
solid boundaries and traverse two-sided openings.
All three flags leave collision intact. FALSE flags retain solid-color fallback.
On a two-sided wall, `texture` supplies a masked middle material with
`texelsPerUnit`, world-unit offsets and `middleFromFloor` anchoring.
It anchors to the lower ceiling by default, or the higher floor plus texture
height. Vertical pixels do not repeat and stay inside the physical opening.
`Texture.SampleMasked` returns `-1` for untouched texels and RGB for covered
ones; setting black explicitly remains opaque. `Sample` preserves the opaque
RGB contract and returns black for untouched texels. Both methods wrap their
coordinates. Walls, planes, grilles and sprites use camera-forward depth.
Solid boundaries still occlude sprites when their middle material is omitted.
Rendering does not allocate per frame or store every crossed grille.
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

`GameRenderer.Sprite` supplies position, a sealed texture, texel density,
pixel offsets from its left/top anchor, sector light, mirroring and fullbright
flags. Call `DrawSprite` after `Render`; sprites can be submitted in any depth
order. Transparent texels preserve the scene beneath them. Equal-depth covered
pixels use the last submission. Sprite coordinates stay within one texture
height/width rather than wrapping. Image selection, playback start/mode, world
attachment and actor simulation belong to the game; GameAnimation computes frames.

`SetPartition` copies a bottom-up tree and its leaf-to-sector table. Nonnegative
children name earlier nodes; negative children encode leaf index as `-index-1`.
The last node is the root; an empty tree requires one leaf. Finite nonzero
partition directions and all references are checked before publication.
`Locate` and `Contains` use this tree within the wall bounds; without a tree
they retain the closed-contour test. This indexes region membership; ray casting
and collision continue to use the wall geometry. Rays choose the region
immediately ahead of the camera so exact portal starts still render.

`MovePlayerChecked` adds a `PositionCheck` delegate to the existing bounded
axis movement. It runs after world clearance accepts a proposed substep and
before position/floor updates; rejecting an axis leaves it unchanged while the
other axis can slide. `MovePlayer` keeps its existing interface and calls the
same implementation with NIL. The delegate receives valid candidate x/y and
radius and must return without mutating the movement state. Footprint shapes,
actor height policy and actor storage remain game-owned. The initial position
is validated against world geometry; occupancy checks apply to proposed moves,
so a blocked actor does not change the operation's success/error contract.

`MovePlayerObserved` additionally calls a `PositionChanged` delegate after each
accepted, nonzero axis substep, with old and new x/y. Rejected axes, zero motion
and invalid requests emit no observations. The callback must return without
mutating movement/world state; games may queue actions for processing after
the move. Existing movement entry points use a NIL observer.

`Crossing` detects a side change through a finite wall segment and returns the
movement fraction. Collinear, same-side and out-of-segment moves return FALSE
and preserve the output. Exact boundary positions use a deterministic side
convention; crossing onto that side fires once. Coordinates use the existing
finite world bounds. Movement checks cover accepted sliding paths, rejected
axes, invalid/zero moves, reverse crossing and endpoint ties. Games decide which
segments activate actions and choose the first relevant crossing.

`WithCeilings` and `WithFloors` return new sealed worlds with copied plane
heights and shared geometry, sectors, materials and partition data. Updating
one plane preserves the other plane snapshot. It returns NIL for an unsealed
or unsectored source, an incorrect array length or non-finite/out-of-range
heights. Earlier snapshots keep their heights, and input arrays are copied. Region reads, rays and player
clearance all use the same snapshot; callers publish it with their camera state.
Each moving plane currently copies eight bytes per sector plus a world object.

`World.WithWallTexture(index, part, texture)` replaces one directed wall's
middle, upper or lower material in a new sealed sector world. Use
`MiddleTexture`, `UpperTexture` or `LowerTexture` for the part, and the zero-based
wall insertion index. Geometry, partition data, plane snapshots, light and
omission flags stay intact. Middle scales/offsets and neighbor-pegged upper
anchors follow the new image dimensions. The method requires a sealed texture
and valid `texelsPerUnit`, and returns NIL for invalid inputs. It copies the
wall records only when called; games retain switch rules and button timing.
SectorSmoke covers validation, dimensions, pegging, snapshot preservation and
composition with moving floors/ceilings.

`World.TraceRay(x, y, dx, dy, eye, slope, range)` clips a sloped center ray to
solid boundaries, sector floors/ceilings and two-sided opening heights. x/y use
the supplied direction times the ray parameter; z is eye plus slope times that
parameter. Use a unit horizontal direction when the parameter must be horizontal
distance. Movement-blocking flags and masked material opacity do not block the
ray. The source height must be strictly inside its sector. An infinitesimal
forward sample resolves exact portal starts. Invalid finite-coordinate bounds
or range return zero; a sealed sector world is required. Traversal stops after
at most 256 wall crossings, conservatively returning zero if exhausted. Volume
sweeps, target selection, sight-cone rules and damage remain game-owned.

Wall `id` is opaque caller metadata returned with ray hits. Middle materials and
upper anchors follow their owning ceiling by default. `middleFromFloor` keeps
middle texture alignment fixed to the floor, `upperFromNeighbor` shifts upper
anchors with the neighbor ceiling, and `lowerFromCeiling` shifts lower anchors
with the owning ceiling. These flags preserve supplied base anchors and offsets.
Moving floors update owning wall bottoms and floor-pegged one-sided middle
offsets. Ordinary lower anchors track the neighbor floor; ceiling-pegged lower
anchors retain their ceiling reference. Motion, activation and obstruction
handling remain game policy.

`TouchesSector` reports circles whose center lies inside a sector or whose
footprint penetrates one of its boundaries. Tangent contact outside the sector
is excluded, matching `Stand`. Invalid coordinates/radii return FALSE. Games
use this bounded region query to limit moving-plane occupant checks.

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
all walls. The partition tree accelerates region lookup only. It has no wall spatial index. The presenter currently supports three- and four-byte desktop display formats.
File reads are capped at 64 MiB. Geometry is capped at 131072 directed walls,
65536 sectors and finite
coordinates within one million world units.

Add a spatial index when actual map costs justify it. Use
active objects for independent loading or rendering work only when ownership
and measured benefit justify another activity; preserve deterministic gameplay.

The implementation is original; no third-party engine code has been copied.
