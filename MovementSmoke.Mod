MODULE MovementSmoke;

IMPORT GameGeometry;

TYPE Recorder = OBJECT
VAR x, y: FLOAT64;
	count*: SIGNED32;

	PROCEDURE &Init(px, py: FLOAT64);
	BEGIN
		x := px;
		y := py;
		count := 0
	END Init;

	PROCEDURE Changed(x0, y0, x1, y1: FLOAT64);
	BEGIN
		ASSERT((x0 = x) & (y0 = y));
		ASSERT((x0 = x1) # (y0 = y1));
		x := x1;
		y := y1;
		INC(count)
	END Changed;
END Recorder;

PROCEDURE BlockY(x, y, radius: FLOAT64): BOOLEAN;
BEGIN
	RETURN y <= 0
END BlockY;

PROCEDURE World(): GameGeometry.World;
VAR world: GameGeometry.World;
	regions: ARRAY 1 OF GameGeometry.Sector;
	wall: GameGeometry.Wall;
BEGIN
	NEW(world, 4);
	regions[0].ceiling := 2;
	ASSERT(world.SetSectors(regions));
	wall.neighbor := -1;
	wall.top := 2;
	wall.ax := -4;
	wall.ay := -4;
	wall.bx := 4;
	wall.by := -4;
	ASSERT(world.Add(wall));
	wall.ax := 4;
	wall.ay := -4;
	wall.bx := 4;
	wall.by := 4;
	ASSERT(world.Add(wall));
	wall.ax := 4;
	wall.ay := 4;
	wall.bx := -4;
	wall.by := 4;
	ASSERT(world.Add(wall));
	wall.ax := -4;
	wall.ay := 4;
	wall.bx := -4;
	wall.by := -4;
	ASSERT(world.Add(wall));
	world.Seal;
	RETURN world
END World;

PROCEDURE {TEST} AcceptedMovement*;
VAR world: GameGeometry.World;
	recorder: Recorder;
	x, y, feet: FLOAT64;
	count: SIGNED32;
BEGIN
	world := World();
	x := 0;
	y := 0;
	feet := 0;
	NEW(recorder, x, y);
	ASSERT(world.MovePlayerObserved(x, y, feet, 0.5, 0.5, 0.25, 0.875, 0.375, BlockY, recorder.Changed));
	ASSERT((ABS(x - 0.5) < 0.000001) & (y = 0) & (recorder.count > 1));
	count := recorder.count;
	ASSERT(world.MovePlayerObserved(x, y, feet, 0, 0, 0.25, 0.875, 0.375, NIL, recorder.Changed));
	ASSERT(recorder.count = count);
	ASSERT(~world.MovePlayerObserved(x, y, feet, 1000, 0, 0.25, 0.875, 0.375, NIL, recorder.Changed));
	ASSERT((recorder.count = count) & (ABS(x - 0.5) < 0.000001));
	x := 3.75;
	NEW(recorder, x, y);
	ASSERT(world.MovePlayerObserved(x, y, feet, 1, 0, 0.25, 0.875, 0.375, NIL, recorder.Changed));
	ASSERT((x = 3.75) & (recorder.count = 0))
END AcceptedMovement;

PROCEDURE {TEST} FiniteCrossings*;
VAR wall: GameGeometry.Wall;
	fraction: FLOAT64;
BEGIN
	wall.ay := -1;
	wall.by := 1;
	ASSERT(GameGeometry.Crossing(wall, -1, 0, 1, 0, fraction));
	ASSERT(fraction = 0.5);
	ASSERT(~GameGeometry.Crossing(wall, -1, 2, 1, 2, fraction));
	ASSERT(fraction = 0.5);
	ASSERT(~GameGeometry.Crossing(wall, -1, 0, -0.5, 0, fraction));
	ASSERT(~GameGeometry.Crossing(wall, 0, -1, 0, 1, fraction));
	ASSERT(GameGeometry.Crossing(wall, -1, 0, 0, 0, fraction));
	ASSERT(fraction = 1);
	ASSERT(~GameGeometry.Crossing(wall, 0, 0, 1, 0, fraction));
	ASSERT(GameGeometry.Crossing(wall, 1, 0, -1, 0, fraction));
	ASSERT(fraction = 0.5);
	ASSERT(~GameGeometry.Crossing(wall, MAX(FLOAT64), 0, 1, 0, fraction))
END FiniteCrossings;

PROCEDURE Do*;
BEGIN
	AcceptedMovement;
	FiniteCrossings
END Do;

END MovementSmoke.
