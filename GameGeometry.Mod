MODULE GameGeometry;

IMPORT MathL, GameMaterials;

CONST Limit = 1000000.0;

TYPE
	Sector* = RECORD
		floor*, ceiling*: FLOAT64;
		light*: SIGNED32;
		floorTexture*, ceilingTexture*: GameMaterials.Texture
	END;

	Wall* = RECORD
		ax*, ay*, bx*, by*: FLOAT64;
		bottom*, top*: FLOAT64;
		color*, light*: SIGNED32;
		texture*: GameMaterials.Texture;
		uScale*, vScale*, uOffset*, vOffset*: FLOAT64;
		sector*, neighbor*: SIGNED32;
		blocking*: BOOLEAN;
		upper*, lower*: GameMaterials.Texture;
		upperAnchor*, lowerAnchor*, xOffset*, yOffset*, texelsPerUnit*: FLOAT64
	END;

	World* = OBJECT
	VAR walls: POINTER TO ARRAY OF Wall;
		sectors: POINTER TO ARRAY OF Sector;
		heads, next: POINTER TO ARRAY OF SIGNED32;
		count: SIGNED32;
		sealed: BOOLEAN;

		PROCEDURE &Init*(capacity: SIGNED32);
		BEGIN
			ASSERT((capacity > 0) & (capacity <= 131072));
			NEW(walls, capacity);
			NEW(next, capacity);
			sectors := NIL;
			count := 0;
			sealed := FALSE
		END Init;

		PROCEDURE SetSectors*(CONST source: ARRAY OF Sector): BOOLEAN;
		VAR i: SIGNED32;
		BEGIN
			IF sealed OR (count # 0) OR (sectors # NIL) OR
				(LEN(source) = 0) OR (LEN(source) > 65536) THEN
				RETURN FALSE
			END;
			FOR i := 0 TO SIGNED32(LEN(source)) - 1 DO
				IF ~Coordinate(source[i].floor) OR ~Coordinate(source[i].ceiling) OR
					(source[i].ceiling < source[i].floor) OR
					(source[i].light < 0) OR (source[i].light > 255) THEN
					RETURN FALSE
				END;
				IF ((source[i].floorTexture # NIL) & ~source[i].floorTexture.sealed) OR
					((source[i].ceilingTexture # NIL) & ~source[i].ceilingTexture.sealed) THEN
					RETURN FALSE
				END
			END;
			NEW(sectors, LEN(source));
			NEW(heads, LEN(source));
			FOR i := 0 TO SIGNED32(LEN(source)) - 1 DO
				sectors[i] := source[i];
				heads[i] := -1
			END;
			RETURN TRUE
		END SetSectors;

		PROCEDURE SectorCount*(): SIGNED32;
		BEGIN
			IF sectors = NIL THEN
				RETURN 0
			END;
			RETURN SIGNED32(LEN(sectors^))
		END SectorCount;

		PROCEDURE Region*(index: SIGNED32): Sector;
		BEGIN
			ASSERT(sealed & (index >= 0) & (index < SectorCount()));
			RETURN sectors[index]
		END Region;

		PROCEDURE Add*(CONST wall: Wall): BOOLEAN;
		BEGIN
			IF sealed OR (count = LEN(walls^)) THEN
				RETURN FALSE
			END;
			IF ~Coordinate(wall.ax) OR ~Coordinate(wall.ay) OR
				~Coordinate(wall.bx) OR ~Coordinate(wall.by) OR
				~Coordinate(wall.bottom) OR ~Coordinate(wall.top) THEN
				RETURN FALSE
			END;
			IF ((wall.ax = wall.bx) & (wall.ay = wall.by)) OR
				(wall.top < wall.bottom) OR ((sectors = NIL) & (wall.top = wall.bottom)) OR (wall.color < 0) OR
				(wall.color > 0FFFFFFH) OR (wall.light < 0) OR (wall.light > 255) THEN
				RETURN FALSE
			END;
			IF wall.texture # NIL THEN
				IF ~wall.texture.sealed OR ~((wall.uScale > 0) & (wall.uScale <= 1024)) OR
					~((wall.vScale > 0) & (wall.vScale <= 1024)) OR
					~Coordinate(wall.uOffset) OR ~Coordinate(wall.vOffset) THEN
					RETURN FALSE
				END
			END;
			IF sectors # NIL THEN
				IF (wall.sector < 0) OR (wall.sector >= LEN(sectors^)) OR
					(wall.neighbor < -1) OR (wall.neighbor >= LEN(sectors^)) OR
					~Coordinate(wall.upperAnchor) OR ~Coordinate(wall.lowerAnchor) OR
					~Coordinate(wall.xOffset) OR ~Coordinate(wall.yOffset) THEN
					RETURN FALSE
				END;
				IF ((wall.upper # NIL) & ~wall.upper.sealed) OR
					((wall.lower # NIL) & ~wall.lower.sealed) OR
					(((wall.upper # NIL) OR (wall.lower # NIL)) &
					~((wall.texelsPerUnit > 0) & (wall.texelsPerUnit <= 1024))) THEN
					RETURN FALSE
				END;
				next[count] := heads[wall.sector];
				heads[wall.sector] := count
			END;
			walls[count] := wall;
			INC(count);
			RETURN TRUE
		END Add;

		PROCEDURE Seal*;
		BEGIN
			sealed := TRUE
		END Seal;

		PROCEDURE Count*(): SIGNED32;
		BEGIN
			RETURN count
		END Count;

		PROCEDURE Contains*(sector: SIGNED32; x, y: FLOAT64): BOOLEAN;
		VAR i: SIGNED32;
			crossing: FLOAT64;
			inside: BOOLEAN;
		BEGIN
			ASSERT(sealed & (sector >= 0) & (sector < SectorCount()));
			inside := FALSE;
			i := heads[sector];
			WHILE i >= 0 DO
				IF (walls[i].neighbor # sector) & ((walls[i].ay > y) # (walls[i].by > y)) THEN
					crossing := walls[i].ax + (y - walls[i].ay) *
						(walls[i].bx - walls[i].ax) / (walls[i].by - walls[i].ay);
					IF crossing > x THEN
						inside := ~inside
					END
				END;
				i := next[i]
			END;
			RETURN inside
		END Contains;

		PROCEDURE Locate*(x, y: FLOAT64): SIGNED32;
		VAR i: SIGNED32;
		BEGIN
			ASSERT(sealed);
			FOR i := 0 TO SectorCount() - 1 DO
				IF Contains(i, x, y) THEN
					RETURN i
				END
			END;
			RETURN -1
		END Locate;

		PROCEDURE Cast*(x, y, dx, dy: FLOAT64; VAR distance: FLOAT64;
			VAR hit: Wall): BOOLEAN;
		BEGIN
			RETURN CastSector(-1, x, y, dx, dy, 0, distance, hit)
		END Cast;

		PROCEDURE CastSector*(sector: SIGNED32; x, y, dx, dy, near: FLOAT64;
			VAR distance: FLOAT64; VAR hit: Wall): BOOLEAN;
		VAR i: SIGNED32;
			sx, sy, qx, qy, denominator, t, u: FLOAT64;
			found: BOOLEAN;
		BEGIN
			ASSERT(sealed);
			ASSERT(Coordinate(x) & Coordinate(y));
			ASSERT(Coordinate(dx) & Coordinate(dy));
			distance := MAX(FLOAT64);
			found := FALSE;
			ASSERT((sector >= -1) & (sector < SectorCount()));
			i := 0;
			IF sector >= 0 THEN
				i := heads[sector]
			END;
			WHILE (i >= 0) & (i < count) DO
				sx := walls[i].bx - walls[i].ax;
				sy := walls[i].by - walls[i].ay;
				denominator := dx * sy - dy * sx;
				IF ABS(denominator) > 0.000000001 THEN
					qx := walls[i].ax - x;
					qy := walls[i].ay - y;
					t := (qx * sy - qy * sx) / denominator;
					u := (qx * dy - qy * dx) / denominator;
					IF (t > near + 0.000001) & (t < distance) & (u >= 0) & (u <= 1) THEN
						distance := t;
						hit := walls[i];
						found := TRUE
					END
				END;
				IF sector < 0 THEN
					INC(i)
				ELSE
					i := next[i]
				END
			END;
			RETURN found
		END CastSector;

		PROCEDURE Stand*(x, y, radius, feet, height, step: FLOAT64; VAR floor: FLOAT64): BOOLEAN;
		VAR sector, i: SIGNED32;
			ceiling: FLOAT64;
		BEGIN
			IF ~Coordinate(x) OR ~Coordinate(y) OR ~Coordinate(feet) OR
				~((radius > 0) & (radius <= Limit)) OR
				~((height > 0) & (height <= Limit)) OR ~((step >= 0) & (step <= Limit)) THEN
				RETURN FALSE
			END;
			sector := Locate(x, y);
			IF sector < 0 THEN
				RETURN FALSE
			END;
			floor := sectors[sector].floor;
			ceiling := sectors[sector].ceiling;
			FOR i := 0 TO count - 1 DO
				IF DistanceSquared(walls[i], x, y) <= radius * radius THEN
					IF (walls[i].neighbor < 0) OR walls[i].blocking THEN
						RETURN FALSE
					END;
					floor := MAX(floor, MAX(sectors[walls[i].sector].floor, sectors[walls[i].neighbor].floor));
					ceiling := MIN(ceiling, MIN(sectors[walls[i].sector].ceiling, sectors[walls[i].neighbor].ceiling))
				END
			END;
			RETURN (floor - feet <= step) & (ceiling - floor >= height) & (ceiling - feet >= height)
		END Stand;

		PROCEDURE MovePlayer*(VAR x, y, feet: FLOAT64; dx, dy, radius, height, step: FLOAT64): BOOLEAN;
		VAR i, steps: SIGNED32;
			length, sx, sy, floor: FLOAT64;
		BEGIN
			IF ~Stand(x, y, radius, feet, height, step, floor) OR ~Coordinate(dx) OR ~Coordinate(dy) THEN
				RETURN FALSE
			END;
			length := MathL.sqrt(dx * dx + dy * dy);
			IF length / radius > 2047 THEN
				RETURN FALSE
			END;
			steps := ENTIER(length * 2 / radius) + 1;
			sx := dx / steps;
			sy := dy / steps;
			FOR i := 1 TO steps DO
				IF Stand(x + sx, y, radius, feet, height, step, floor) THEN
					x := x + sx;
					feet := floor
				END;
				IF Stand(x, y + sy, radius, feet, height, step, floor) THEN
					y := y + sy;
					feet := floor
				END
			END;
			RETURN TRUE
		END MovePlayer;

		PROCEDURE Free*(x, y, radius: FLOAT64): BOOLEAN;
		VAR i: SIGNED32;
		BEGIN
			ASSERT(sealed);
			IF ~Coordinate(x) OR ~Coordinate(y) OR
				~((radius > 0) & (radius <= Limit)) THEN
				RETURN FALSE
			END;
			FOR i := 0 TO count - 1 DO
				IF DistanceSquared(walls[i], x, y) <= radius * radius THEN
					RETURN FALSE
				END
			END;
			RETURN TRUE
		END Free;

		PROCEDURE Move*(VAR x, y: FLOAT64; dx, dy, radius: FLOAT64): BOOLEAN;
		VAR i, steps: SIGNED32;
			length, sx, sy: FLOAT64;
		BEGIN
			IF ~Free(x, y, radius) OR ~Coordinate(dx) OR ~Coordinate(dy) THEN
				RETURN FALSE
			END;
			length := MathL.sqrt(dx * dx + dy * dy);
			IF length / radius > 2047 THEN
				RETURN FALSE
			END;
			steps := ENTIER(length * 2 / radius) + 1;
			sx := dx / steps;
			sy := dy / steps;
			FOR i := 1 TO steps DO
				IF Free(x + sx, y, radius) THEN
					x := x + sx
				END;
				IF Free(x, y + sy, radius) THEN
					y := y + sy
				END
			END;
			RETURN TRUE
		END Move;
	END World;

PROCEDURE DistanceSquared(CONST wall: Wall; x, y: FLOAT64): FLOAT64;
VAR sx, sy, t, qx, qy: FLOAT64;
BEGIN
	sx := wall.bx - wall.ax;
	sy := wall.by - wall.ay;
	t := ((x - wall.ax) * sx + (y - wall.ay) * sy) / (sx * sx + sy * sy);
	t := MAX(0.0, MIN(1.0, t));
	qx := x - (wall.ax + t * sx);
	qy := y - (wall.ay + t * sy);
	RETURN qx * qx + qy * qy
END DistanceSquared;

PROCEDURE Coordinate(value: FLOAT64): BOOLEAN;
BEGIN
	RETURN (value >= -Limit) & (value <= Limit)
END Coordinate;

END GameGeometry.
