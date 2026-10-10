MODULE GameRenderer;

IMPORT GameGeometry, GameSurface, GameMaterials, MathL;

PROCEDURE Shade(color, light: SIGNED32; distance: FLOAT64): SIGNED32;
VAR shade: SIGNED32;
BEGIN
	shade := ENTIER(256.0 * light / 255 / (1 + distance * 0.08));
	RETURN (color DIV 65536 MOD 256 * shade DIV 256) * 65536 +
		(color DIV 256 MOD 256 * shade DIV 256) * 256 + color MOD 256 * shade DIV 256
END Shade;

PROCEDURE Row(frame: GameSurface.Frame; z, eye, projection, distance: FLOAT64): SIGNED32;
VAR position: FLOAT64;
BEGIN
	position := frame.height / 2.0 - (z - eye) * projection / distance;
	RETURN ENTIER(MAX(-1.0, MIN(FLOAT64(frame.height), position)))
END Row;

PROCEDURE BoundaryRow(frame: GameSurface.Frame; z, eye, projection, distance: FLOAT64;
	ceiling: BOOLEAN): SIGNED32;
VAR position: FLOAT64;
BEGIN
	position := frame.height / 2.0 - (z - eye) * projection / distance - 0.5;
	position := MAX(-1.0, MIN(FLOAT64(frame.height), position));
	IF ceiling THEN
		RETURN -ENTIER(-position)
	END;
	RETURN ENTIER(position)
END BoundaryRow;

PROCEDURE WallU(CONST wall: GameGeometry.Wall; x, y, rx, ry, distance: FLOAT64): FLOAT64;
VAR wx, wy, length: FLOAT64;
BEGIN
	wx := x + rx * distance - wall.ax;
	wy := y + ry * distance - wall.ay;
	length := MathL.sqrt((wall.bx - wall.ax) * (wall.bx - wall.ax) +
		(wall.by - wall.ay) * (wall.by - wall.ay));
	RETURN (wx * (wall.bx - wall.ax) + wy * (wall.by - wall.ay)) / length
END WallU;

PROCEDURE DrawWall(CONST wall: GameGeometry.Wall; frame: GameSurface.Frame;
	column, top, bottom: SIGNED32; x, y, rx, ry, distance, projection, eye: FLOAT64);
VAR row, texel: SIGNED32;
	u, v: FLOAT64;
BEGIN
	top := MAX(0, top);
	bottom := MIN(frame.height - 1, bottom);
	IF top > bottom THEN
		RETURN
	END;
	IF wall.texture = NIL THEN
		frame.Span(column, top, bottom, Shade(wall.color, wall.light, distance))
	ELSE
		u := WallU(wall, x, y, rx, ry, distance);
		FOR row := top TO bottom DO
			v := wall.top - eye - (frame.height / 2.0 - row - 0.5) * distance / projection;
			texel := wall.texture.Sample(u * wall.uScale + wall.uOffset,
				v * wall.vScale + wall.vOffset);
			frame.Span(column, row, row, Shade(texel, wall.light, distance))
		END
	END
END DrawWall;

(* Masked keeps the nearest covered texel until the rooms behind it have rendered. *)
PROCEDURE Masked(CONST wall: GameGeometry.Wall; frame: GameSurface.Frame;
	VAR pixels: ARRAY OF SIGNED32; top, bottom: SIGNED32;
	x, y, rx, ry, distance, projection, eye: FLOAT64);
VAR row, texel: SIGNED32;
	u, v: FLOAT64;
BEGIN
	u := WallU(wall, x, y, rx, ry, distance) * wall.uScale + wall.uOffset;
	FOR row := MAX(0, top) TO MIN(frame.height - 1, bottom) DO
		IF pixels[row] < 0 THEN
			v := (wall.top - eye - (frame.height / 2.0 - row - 0.5) * distance / projection) *
				wall.vScale + wall.vOffset;
			IF (v >= 0) & (v < 1) THEN
				texel := wall.texture.SampleMasked(u, v);
				IF texel >= 0 THEN
					pixels[row] := Shade(texel, wall.light, distance)
				END
			END
		END
	END
END Masked;

PROCEDURE Plane(frame: GameSurface.Frame; column, top, bottom, light, color: SIGNED32;
	texture: GameMaterials.Texture; x, y, rx, ry, z, eye, projection, near, far: FLOAT64);
VAR row, texel: SIGNED32;
	denominator, distance: FLOAT64;
BEGIN
	FOR row := MAX(0, top) TO MIN(frame.height - 1, bottom) DO
		denominator := frame.height / 2.0 - row - 0.5;
		IF ABS(denominator) > 0.000000001 THEN
			distance := (z - eye) * projection / denominator;
			IF (distance > 0) & (distance >= near) & (distance <= far) THEN
				texel := color;
				IF texture # NIL THEN
					texel := texture.Sample(x + rx * distance, -y - ry * distance)
				END;
				frame.Span(column, row, row, Shade(texel, light, distance))
			END
		END
	END
END Plane;

PROCEDURE Sky(CONST sector: GameGeometry.Sector; frame: GameSurface.Frame;
	column, top, bottom: SIGNED32; angle: FLOAT64);
VAR row, texel: SIGNED32;
	u, v: FLOAT64;
BEGIN
	u := -angle / (2 * MathL.pi) * sector.skyUScale;
	FOR row := MAX(0, top) TO MIN(frame.height - 1, bottom) DO
		v := sector.skyVOffset + (row + 0.5 - frame.height / 2.0) * sector.skyVScale / frame.height;
		texel := sector.skyTexture.Sample(u, v);
		frame.Span(column, row, row, texel)
	END
END Sky;

PROCEDURE Face(CONST wall: GameGeometry.Wall; texture: GameMaterials.Texture;
	anchor: FLOAT64): GameGeometry.Wall;
VAR face: GameGeometry.Wall;
BEGIN
	face := wall;
	face.texture := texture;
	face.top := anchor;
	IF texture # NIL THEN
		face.uScale := wall.texelsPerUnit / texture.width;
		face.vScale := wall.texelsPerUnit / texture.height;
		face.uOffset := wall.xOffset * face.uScale;
		face.vOffset := wall.yOffset * face.vScale
	END;
	RETURN face
END Face;

PROCEDURE Sectors(world: GameGeometry.World; frame: GameSurface.Frame;
	x, y, angle, eye: FLOAT64);
VAR column, sector, start, top, bottom, ceilingRow, floorRow, upperRow, lowerRow, step, row: SIGNED32;
	dx, dy, camera, rx, ry, distance, projectedDistance, projection, near, ceiling: FLOAT64;
	wall, face: GameGeometry.Wall;
	front, back: GameGeometry.Sector;
	sharedSky, hasMasked: BOOLEAN;
	masked: ARRAY 4096 OF SIGNED32;
BEGIN
	start := world.Locate(x, y);
	IF start < 0 THEN
		RETURN
	END;
	dx := MathL.cos(angle);
	dy := MathL.sin(angle);
	projection := frame.width / 1.32;
	FOR column := 0 TO frame.width - 1 DO
		camera := (2.0 * column + 1) / frame.width - 1;
		rx := dx - dy * camera * 0.66;
		ry := dy + dx * camera * 0.66;
		(* Choose the sector ahead of a boundary camera because casting skips zero-distance hits. *)
		sector := world.Locate(x + rx * 0.000002, y + ry * 0.000002);
		IF sector < 0 THEN
			sector := start
		END;
		top := 0;
		bottom := frame.height - 1;
		near := 0;
		step := 0;
		hasMasked := FALSE;
		LOOP
			IF step = world.Count() THEN
				EXIT
			END;
			INC(step);
			IF (top > bottom) OR ~world.CastSector(sector, x, y, rx, ry, near, distance, wall) THEN
				EXIT
			END;
			projectedDistance := MAX(0.01, distance);
			front := world.Region(sector);
			sharedSky := FALSE;
			ceiling := front.ceiling;
			IF wall.neighbor >= 0 THEN
				back := world.Region(wall.neighbor);
				sharedSky := (front.skyTexture # NIL) & (back.skyTexture # NIL);
				IF sharedSky THEN
					ceiling := back.ceiling
				END
			END;
			ceilingRow := BoundaryRow(frame, ceiling, eye, projection, projectedDistance, TRUE);
			floorRow := BoundaryRow(frame, front.floor, eye, projection, projectedDistance, FALSE);
			IF front.skyTexture # NIL THEN
				Sky(front, frame, column, top, MIN(bottom, ceilingRow - 1), angle + MathL.arctan(camera * 0.66))
			ELSE
				Plane(frame, column, top, MIN(bottom, ceilingRow - 1), front.light, 0202938H,
					front.ceilingTexture, x, y, rx, ry, front.ceiling, eye, projection, near, distance)
			END;
			Plane(frame, column, MAX(top, floorRow + 1), bottom, front.light, 035302CH,
				front.floorTexture, x, y, rx, ry, front.floor, eye, projection, near, distance);
			IF wall.neighbor < 0 THEN
				IF ~wall.omitMiddle THEN
					DrawWall(wall, frame, column, MAX(top, ceilingRow), MIN(bottom, floorRow),
						x, y, rx, ry, projectedDistance, projection, eye)
				END;
				EXIT
			END;
			upperRow := BoundaryRow(frame, MIN(front.ceiling, back.ceiling), eye, projection, projectedDistance, TRUE);
			IF sharedSky THEN
				upperRow := ceilingRow
			END;
			lowerRow := BoundaryRow(frame, MAX(front.floor, back.floor), eye, projection, projectedDistance, FALSE);
			IF (back.ceiling < front.ceiling) & ~sharedSky & ~wall.omitUpper THEN
				face := Face(wall, wall.upper, wall.upperAnchor);
				DrawWall(face, frame, column, MAX(top, ceilingRow), MIN(bottom, MIN(floorRow, upperRow - 1)),
					x, y, rx, ry, projectedDistance, projection, eye)
			END;
			IF (back.floor > front.floor) & ~wall.omitLower THEN
				face := Face(wall, wall.lower, wall.lowerAnchor);
				DrawWall(face, frame, column, MAX(top, MAX(ceilingRow, lowerRow + 1)), MIN(bottom, floorRow),
					x, y, rx, ry, projectedDistance, projection, eye)
			END;
			IF MAX(front.floor, back.floor) >= MIN(front.ceiling, back.ceiling) THEN
				IF ~wall.omitUpper THEN
					face := Face(wall, wall.upper, wall.upperAnchor);
					DrawWall(face, frame, column, MAX(top, MAX(ceilingRow, upperRow)), MIN(bottom, MIN(floorRow, lowerRow)),
						x, y, rx, ry, projectedDistance, projection, eye)
				END;
				EXIT
			END;
			IF (wall.texture # NIL) & ~wall.omitMiddle THEN
				IF ~hasMasked THEN
					FOR row := 0 TO frame.height - 1 DO
						masked[row] := -1
					END;
					hasMasked := TRUE
				END;
				ceiling := MIN(front.ceiling, back.ceiling);
				IF wall.middleFromFloor THEN
					ceiling := MAX(front.floor, back.floor) + wall.texture.height / wall.texelsPerUnit
				END;
				face := Face(wall, wall.texture, ceiling);
				Masked(face, frame, masked,
					MAX(top, BoundaryRow(frame, MIN(front.ceiling, back.ceiling), eye, projection, projectedDistance, TRUE)),
					MIN(bottom, lowerRow), x, y, rx, ry, projectedDistance, projection, eye)
			END;
			IF wall.omitUpper THEN
				upperRow := ceilingRow
			END;
			IF wall.omitLower THEN
				lowerRow := floorRow
			END;
			top := MAX(top, upperRow);
			bottom := MIN(bottom, lowerRow);
			near := distance;
			sector := wall.neighbor
		END;
		IF hasMasked THEN
			FOR row := 0 TO frame.height - 1 DO
				IF masked[row] >= 0 THEN
					frame.Span(column, row, row, masked[row])
				END
			END
		END
	END
END Sectors;

PROCEDURE Render*(world: GameGeometry.World; frame: GameSurface.Frame;
	x, y, angle, eye: FLOAT64);
VAR column, top, bottom: SIGNED32;
	dx, dy, camera, rx, ry, distance, projection: FLOAT64;
	wall: GameGeometry.Wall;
BEGIN
	ASSERT((angle >= -MathL.pi * 2) & (angle <= MathL.pi * 2));
	ASSERT((eye >= -1000000) & (eye <= 1000000));
	frame.Background(0202938H, 035302CH);
	IF world.SectorCount() > 0 THEN
		Sectors(world, frame, x, y, angle, eye);
		RETURN
	END;
	dx := MathL.cos(angle);
	dy := MathL.sin(angle);
	projection := frame.width / 1.32;
	FOR column := 0 TO frame.width - 1 DO
		camera := (2.0 * column + 1) / frame.width - 1;
		rx := dx - dy * camera * 0.66;
		ry := dy + dx * camera * 0.66;
		IF world.Cast(x, y, rx, ry, distance, wall) THEN
			distance := MAX(0.01, distance);
			top := Row(frame, wall.top, eye, projection, distance);
			bottom := Row(frame, wall.bottom, eye, projection, distance);
			DrawWall(wall, frame, column, top, bottom, x, y, rx, ry, distance, projection, eye)
		END
	END
END Render;

END GameRenderer.
