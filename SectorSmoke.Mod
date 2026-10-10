MODULE SectorSmoke;

IMPORT GameGeometry, GameSurface, GameRenderer, GameMaterials, MathL;

PROCEDURE Wall(world: GameGeometry.World; sector, neighbor: SIGNED32; ax, ay, bx, by: FLOAT64);
VAR wall: GameGeometry.Wall;
BEGIN
	wall.ax := ax;
	wall.ay := ay;
	wall.bx := bx;
	wall.by := by;
	wall.bottom := 0;
	wall.top := 2;
	wall.color := 0D08040H;
	wall.light := 255;
	wall.texture := NIL;
	wall.upper := NIL;
	wall.lower := NIL;
	wall.sector := sector;
	wall.neighbor := neighbor;
	wall.blocking := FALSE;
	wall.omitMiddle := FALSE;
	wall.omitUpper := FALSE;
	wall.omitLower := FALSE;
	wall.upperAnchor := 2;
	wall.lowerAnchor := 0;
	wall.xOffset := 0;
	wall.yOffset := 0;
	ASSERT(world.Add(wall))
END Wall;

PROCEDURE RoomWalls(world: GameGeometry.World);
BEGIN
	Wall(world, 0, -1, -4, -2, 0, -2);
	Wall(world, 0, -1, 0, 2, -4, 2);
	Wall(world, 0, -1, -4, 2, -4, -2);
	Wall(world, 1, -1, 0, -2, 4, -2);
	Wall(world, 1, -1, 4, -2, 4, 2);
	Wall(world, 1, -1, 4, 2, 0, 2);
	Wall(world, 0, 1, 0, -2, 0, 2);
	Wall(world, 1, 0, 0, 2, 0, -2)
END RoomWalls;

PROCEDURE Partition;
VAR world: GameGeometry.World;
	regions: ARRAY 2 OF GameGeometry.Sector;
	nodes: ARRAY 1 OF GameGeometry.Partition;
	leaves: ARRAY 2 OF SIGNED32;
	direction: SIGNED32;
BEGIN
	FOR direction := 0 TO 2 DO
		NEW(world, 8);
		regions[0].ceiling := 2;
		regions[1] := regions[0];
		leaves[0] := 0;
		leaves[1] := 1;
		nodes[0].x := 0;
		nodes[0].dx := 0;
		nodes[0].dy := -4;
		nodes[0].front := -2;
		nodes[0].back := -1;
		ASSERT(~world.SetPartition(nodes, leaves));
		ASSERT(world.SetSectors(regions));
		leaves[1] := 2;
		ASSERT(~world.SetPartition(nodes, leaves));
		leaves[1] := 1;
		nodes[0].front := 0;
		ASSERT(~world.SetPartition(nodes, leaves));
		nodes[0].front := -3;
		ASSERT(~world.SetPartition(nodes, leaves));
		nodes[0].front := MIN(SIGNED32);
		ASSERT(~world.SetPartition(nodes, leaves));
		nodes[0].front := -2;
		nodes[0].dy := 0;
		ASSERT(~world.SetPartition(nodes, leaves));
		nodes[0].dy := -4;
		nodes[0].x := 1000001;
		ASSERT(~world.SetPartition(nodes, leaves));
		nodes[0].x := 0;
		IF direction > 0 THEN
			nodes[0].dx := 4
		END;
		IF direction = 1 THEN
			nodes[0].dy := 0
		END;
		ASSERT(world.SetPartition(nodes, leaves));
		ASSERT(~world.SetPartition(nodes, leaves));
		nodes[0].front := -1;
		leaves[1] := 0;
		RoomWalls(world);
		world.Seal;
		ASSERT(~world.SetPartition(nodes, leaves));
		ASSERT(world.Locate(0, 0) = direction MOD 2);
		ASSERT(world.Locate(20, 0) = -1);
		IF direction = 0 THEN
			ASSERT(world.Locate(2, 0) = 1);
			ASSERT(world.Locate(-2, 0) = 0)
		ELSE
			ASSERT(world.Locate(2, 1) = 1);
			ASSERT(world.Locate(-2, -1) = 0)
		END
	END
END Partition;

PROCEDURE Heights;
VAR world, closed, reopened: GameGeometry.World;
	regions: ARRAY 2 OF GameGeometry.Sector;
	heights: ARRAY 2 OF FLOAT64;
	short: ARRAY 1 OF FLOAT64;
	region: GameGeometry.Sector;
	frame: GameSurface.Frame;
	floor: FLOAT64;
	pixel: SIGNED32;
BEGIN
	NEW(world, 8);
	heights[0] := 2;
	heights[1] := 0;
	ASSERT(world.WithCeilings(heights) = NIL);
	regions[0].ceiling := 2;
	regions[1] := regions[0];
	ASSERT(world.SetSectors(regions));
	RoomWalls(world);
	ASSERT(world.WithCeilings(heights) = NIL);
	world.Seal;
	ASSERT(world.WithCeilings(short) = NIL);
	heights[1] := 1000001;
	ASSERT(world.WithCeilings(heights) = NIL);
	heights[1] := 0;
	closed := world.WithCeilings(heights);
	ASSERT(closed # NIL);
	heights[1] := 2;
	region := closed.Region(1);
	ASSERT(region.ceiling = 0);
	ASSERT(~closed.Stand(0, 0, 0.25, 0, 1, 0, floor));
	ASSERT(world.Stand(0, 0, 0.25, 0, 1, 0, floor));
	NEW(frame, 32, 20);
	GameRenderer.Render(world, frame, -2, 0, 0, 0.64);
	pixel := frame.Pixel(16, 10);
	GameRenderer.Render(closed, frame, -2, 0, 0, 0.64);
	ASSERT(frame.Pixel(16, 10) # pixel);
	reopened := closed.WithCeilings(heights);
	ASSERT(reopened # NIL);
	ASSERT(reopened.Stand(0, 0, 0.25, 0, 1, 0, floor));
	ASSERT(reopened.Count() = world.Count());
	ASSERT(reopened.Locate(2, 0) = 1);
	GameRenderer.Render(world, frame, -2, 0, 0, 0.64);
	ASSERT(frame.Pixel(16, 10) = pixel);
	region := closed.Region(1);
	ASSERT(region.ceiling = 0);
	region := world.Region(1);
	ASSERT(region.ceiling = 2)
END Heights;

PROCEDURE Sky;
VAR world: GameGeometry.World;
	regions: ARRAY 2 OF GameGeometry.Sector;
	texture: GameMaterials.Texture;
	frame: GameSurface.Frame;
	x, y, feet: FLOAT64;
BEGIN
	NEW(world, 8);
	NEW(texture, 2, 2);
	texture.Set(0, 0, 0102030H);
	texture.Set(1, 0, 0A0B0C0H);
	texture.Set(0, 1, 0203040H);
	texture.Set(1, 1, 0B0C0D0H);
	regions[0].floor := 0;
	regions[0].ceiling := 2;
	regions[0].light := 0;
	regions[0].skyTexture := texture;
	regions[0].skyUScale := 1;
	regions[0].skyVScale := 1;
	regions[0].skyVOffset := 0.5;
	regions[1] := regions[0];
	regions[1].ceiling := 1;
	ASSERT(~world.SetSectors(regions));
	texture.Seal;
	regions[0].skyUScale := 0;
	ASSERT(~world.SetSectors(regions));
	regions[0].skyUScale := 1;
	regions[0].skyVScale := -1;
	ASSERT(~world.SetSectors(regions));
	regions[0].skyVScale := 1;
	regions[0].skyVOffset := 1000001;
	ASSERT(~world.SetSectors(regions));
	regions[0].skyVOffset := 0.5;
	ASSERT(world.SetSectors(regions));
	RoomWalls(world);
	world.Seal;
	NEW(frame, 32, 20);
	GameRenderer.Render(world, frame, -2, 0, 0, 0.64);
	ASSERT(frame.Pixel(16, 0) = 0A0B0C0H);
	ASSERT(frame.Pixel(16, 6) = 0A0B0C0H);
	GameRenderer.Render(world, frame, -1, 0, 0, 0.8);
	ASSERT(frame.Pixel(16, 0) = 0A0B0C0H);
	GameRenderer.Render(world, frame, 2, 0, -MathL.pi / 2, 0.64);
	ASSERT(frame.Pixel(16, 0) = 0102030H);
	x := -2;
	y := 0;
	feet := 0;
	ASSERT(world.MovePlayer(x, y, feet, 4, 0, 0.25, 1.1, 0.375));
	ASSERT(x < -0.25)
END Sky;

PROCEDURE Do*;
VAR world: GameGeometry.World;
	regions: ARRAY 2 OF GameGeometry.Sector;
	region: GameGeometry.Sector;
	wall: GameGeometry.Wall;
	texture: GameMaterials.Texture;
	frame: GameSurface.Frame;
	x, y, feet, floor, distance: FLOAT64;
BEGIN
	Partition;
	Heights;
	Sky;
	NEW(world, 8);
	regions[0].floor := 0;
	regions[0].ceiling := 2;
	regions[0].light := 255;
	regions[1] := regions[0];
	regions[1].floor := 0.25;
	regions[1].ceiling := 1.75;
	regions[1].light := -1;
	ASSERT(~world.SetSectors(regions));
	regions[1].light := 255;
	NEW(texture, 1, 1);
	regions[1].floorTexture := texture;
	ASSERT(~world.SetSectors(regions));
	texture.Set(0, 0, 000FF00H);
	texture.Seal;
	ASSERT(world.SetSectors(regions));
	ASSERT(~world.SetSectors(regions));
	regions[0].floor := -10;
	RoomWalls(world);
	world.Seal;
	ASSERT(~world.SetSectors(regions));
	ASSERT(world.SectorCount() = 2);
	region := world.Region(0);
	ASSERT(region.floor = 0);
	ASSERT(world.Locate(-2, 0) = 0);
	ASSERT(world.Locate(2, 0) = 1);
	ASSERT(world.Locate(5, 0) = -1);
	ASSERT(~world.Stand(-4, 0, 0.25, 0, 0.875, 0.375, floor));
	ASSERT(world.Stand(-3.75, 0, 0.25, 0, 0.875, 0.375, floor));
	ASSERT(~world.Stand(-3.750001, 0, 0.25, 0, 0.875, 0.375, floor));
	ASSERT(~world.Stand(0, 0, 0.25, 0, 0.875, 0.2, floor));
	ASSERT(~world.Stand(0, 0, 0.25, 0, 1.8, 0.375, floor));
	ASSERT(world.Stand(0, 0, 0.25, 0, 0.875, 0.375, floor));
	ASSERT(floor = 0.25);
	x := -2;
	y := 0;
	feet := 0;
	ASSERT(world.MovePlayer(x, y, feet, 4, 0, 0.25, 0.875, 0.375));
	ASSERT(ABS(x - 2) < 0.000001);
	ASSERT(feet = 0.25);
	ASSERT(world.MovePlayer(x, y, feet, -4, 0, 0.25, 0.875, 0.375));
	ASSERT(ABS(x + 2) < 0.000001);
	ASSERT(feet = 0);
	ASSERT(~world.MovePlayer(x, y, feet, 1000, 0, 0.25, 0.875, 0.375));
	ASSERT(world.CastSector(0, -2, 0, 1, 0, 0, distance, wall));
	ASSERT((distance = 2) & (wall.neighbor = 1));
	ASSERT(world.CastSector(1, -2, 0, 1, 0, 2, distance, wall));
	ASSERT((distance = 6) & (wall.neighbor = -1));
	NEW(frame, 32, 20);
	GameRenderer.Render(world, frame, -2, 0, 0, 0.64);
	ASSERT(frame.Pixel(16, 10) # 0202938H);
	ASSERT(frame.Pixel(16, 10) # 035302CH);
	GameRenderer.Render(world, frame, 2, 0, 0, 0.89);
	ASSERT(frame.Pixel(16, 19) MOD 256 = 0);
	ASSERT(frame.Pixel(16, 19) DIV 65536 = 0);
	ASSERT(frame.Pixel(16, 19) DIV 256 > 0)
END Do;

END SectorSmoke.
