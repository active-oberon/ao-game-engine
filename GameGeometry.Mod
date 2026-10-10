MODULE GameGeometry;

IMPORT MathL, GameMaterials;

CONST Limit = 1000000.0;

TYPE
	Sector* = RECORD
		floor*, ceiling*: FLOAT64;
		light*: SIGNED32;
		floorTexture*, ceilingTexture*, skyTexture*: GameMaterials.Texture;
		skyUScale*, skyVScale*, skyVOffset*: FLOAT64
	END;

	Wall* = RECORD
		ax*, ay*, bx*, by*: FLOAT64;
		bottom*, top*: FLOAT64;
		color*, light*: SIGNED32;
		texture*: GameMaterials.Texture;
		uScale*, vScale*, uOffset*, vOffset*: FLOAT64;
		id*, sector*, neighbor*: SIGNED32;
		blocking*, omitMiddle*, omitUpper*, omitLower*: BOOLEAN;
		middleFromFloor*, upperFromNeighbor*, lowerFromCeiling*: BOOLEAN;
		upper*, lower*: GameMaterials.Texture;
		upperAnchor*, lowerAnchor*, xOffset*, yOffset*, texelsPerUnit*: FLOAT64
	END;

	Partition* = RECORD
		x*, y*, dx*, dy*: FLOAT64;
		front*, back*: SIGNED32
	END;

	World* = OBJECT
	VAR walls: POINTER TO ARRAY OF Wall;
		sectors: POINTER TO ARRAY OF Sector;
		heads, next, leaves: POINTER TO ARRAY OF SIGNED32;
		partitions: POINTER TO ARRAY OF Partition;
		ceilings: POINTER TO ARRAY OF FLOAT64;
		minX, minY, maxX, maxY: FLOAT64;
		count: SIGNED32;
		sealed: BOOLEAN;

		PROCEDURE &Init*(capacity: SIGNED32);
		BEGIN
			ASSERT((capacity > 0) & (capacity <= 131072));
			NEW(walls, capacity);
			NEW(next, capacity);
			sectors := NIL;
			partitions := NIL;
			leaves := NIL;
			ceilings := NIL;
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
					(source[i].light < 0) OR (source[i].light > 255) THEN
					RETURN FALSE
				END;
				IF ((source[i].floorTexture # NIL) & ~source[i].floorTexture.sealed) OR
					((source[i].ceilingTexture # NIL) & ~source[i].ceilingTexture.sealed) OR
					((source[i].skyTexture # NIL) & ~source[i].skyTexture.sealed) THEN
					RETURN FALSE
				END;
				IF source[i].skyTexture # NIL THEN
					IF ~((source[i].skyUScale > 0) & (source[i].skyUScale <= 1024)) OR
						~((source[i].skyVScale > 0) & (source[i].skyVScale <= 1024)) OR
						~Coordinate(source[i].skyVOffset) THEN
						RETURN FALSE
					END
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

		(* SetPartition copies a bottom-up tree to keep sector lookup bounded and immutable. *)
		PROCEDURE SetPartition*(CONST nodes: ARRAY OF Partition; CONST regions: ARRAY OF SIGNED32): BOOLEAN;
		VAR i: SIGNED32;
		BEGIN
			IF sealed OR (count # 0) OR (sectors = NIL) OR (partitions # NIL) OR
				(LEN(nodes) > 65536) OR (LEN(regions) = 0) OR (LEN(regions) > 65536) OR
				((LEN(nodes) = 0) & (LEN(regions) # 1)) THEN
				RETURN FALSE
			END;
			FOR i := 0 TO SIGNED32(LEN(regions)) - 1 DO
				IF (regions[i] < 0) OR (regions[i] >= LEN(sectors^)) THEN
					RETURN FALSE
				END
			END;
			FOR i := 0 TO SIGNED32(LEN(nodes)) - 1 DO
				IF ~Coordinate(nodes[i].x) OR ~Coordinate(nodes[i].y) OR
					~Coordinate(nodes[i].dx) OR ~Coordinate(nodes[i].dy) OR
					((nodes[i].dx = 0) & (nodes[i].dy = 0)) OR
					~Child(nodes[i].front, i, SIGNED32(LEN(regions))) OR
					~Child(nodes[i].back, i, SIGNED32(LEN(regions))) THEN
					RETURN FALSE
				END
			END;
			NEW(partitions, LEN(nodes));
			NEW(leaves, LEN(regions));
			FOR i := 0 TO SIGNED32(LEN(nodes)) - 1 DO
				partitions[i] := nodes[i]
			END;
			FOR i := 0 TO SIGNED32(LEN(regions)) - 1 DO
				leaves[i] := regions[i]
			END;
			RETURN TRUE
		END SetPartition;

		PROCEDURE SectorCount*(): SIGNED32;
		BEGIN
			IF sectors = NIL THEN
				RETURN 0
			END;
			RETURN SIGNED32(LEN(sectors^))
		END SectorCount;

		PROCEDURE Ceiling(index: SIGNED32): FLOAT64;
		BEGIN
			IF ceilings # NIL THEN
				RETURN ceilings[index]
			END;
			RETURN sectors[index].ceiling
		END Ceiling;

		PROCEDURE Region*(index: SIGNED32): Sector;
		VAR region: Sector;
		BEGIN
			ASSERT(sealed & (index >= 0) & (index < SectorCount()));
			region := sectors[index];
			region.ceiling := Ceiling(index);
			RETURN region
		END Region;

		(* WithCeilings copies heights while sharing sealed geometry so old render snapshots stay stable. *)
		PROCEDURE WithCeilings*(CONST heights: ARRAY OF FLOAT64): World;
		VAR snapshot: World;
			i: SIGNED32;
		BEGIN
			IF ~sealed OR (sectors = NIL) OR (LEN(heights) # LEN(sectors^)) THEN
				RETURN NIL
			END;
			FOR i := 0 TO SIGNED32(LEN(heights)) - 1 DO
				IF ~Coordinate(heights[i]) THEN
					RETURN NIL
				END
			END;
			NEW(snapshot, 1);
			snapshot.walls := walls;
			snapshot.sectors := sectors;
			snapshot.heads := heads;
			snapshot.next := next;
			snapshot.partitions := partitions;
			snapshot.leaves := leaves;
			snapshot.minX := minX;
			snapshot.minY := minY;
			snapshot.maxX := maxX;
			snapshot.maxY := maxY;
			snapshot.count := count;
			NEW(snapshot.ceilings, LEN(heights));
			FOR i := 0 TO SIGNED32(LEN(heights)) - 1 DO
				snapshot.ceilings[i] := heights[i]
			END;
			snapshot.sealed := TRUE;
			RETURN snapshot
		END WithCeilings;

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
				((sectors = NIL) & (wall.top <= wall.bottom)) OR (wall.color < 0) OR
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
			IF count = 0 THEN
				minX := MIN(wall.ax, wall.bx);
				maxX := MAX(wall.ax, wall.bx);
				minY := MIN(wall.ay, wall.by);
				maxY := MAX(wall.ay, wall.by)
			ELSE
				minX := MIN(minX, MIN(wall.ax, wall.bx));
				maxX := MAX(maxX, MAX(wall.ax, wall.bx));
				minY := MIN(minY, MIN(wall.ay, wall.by));
				maxY := MAX(maxY, MAX(wall.ay, wall.by))
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
			IF partitions # NIL THEN
				RETURN Locate(x, y) = sector
			END;
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
			front: BOOLEAN;
			partition: Partition;
		BEGIN
			ASSERT(sealed);
			IF ~Coordinate(x) OR ~Coordinate(y) THEN
				RETURN -1
			END;
			IF partitions # NIL THEN
				(* shortcut: only wall bounds exclude void; add leaf coverage checks for edited BSP maps. *)
				IF (count = 0) OR (x < minX) OR (x > maxX) OR (y < minY) OR (y > maxY) THEN
					RETURN -1
				END;
				i := SIGNED32(LEN(partitions^)) - 1;
				WHILE i >= 0 DO
					partition := partitions[i];
					IF partition.dx = 0 THEN
						front := (x <= partition.x) = (partition.dy > 0)
					ELSIF partition.dy = 0 THEN
						front := (y >= partition.y) = (partition.dx > 0)
					ELSE
						front := (x - partition.x) * partition.dy < (y - partition.y) * partition.dx
					END;
					IF front THEN
						i := partition.front
					ELSE
						i := partition.back
					END
				END;
				RETURN leaves[-(i + 1)]
			END;
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
			sx, sy, qx, qy, denominator, t, u, shift: FLOAT64;
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
						IF ceilings # NIL THEN
							shift := Ceiling(hit.sector) - sectors[hit.sector].ceiling;
							hit.top := hit.top + shift;
							IF hit.middleFromFloor THEN
								hit.vOffset := hit.vOffset - shift * hit.vScale
							END;
							IF hit.lowerFromCeiling THEN
								hit.lowerAnchor := hit.lowerAnchor + shift
							END;
							IF hit.upperFromNeighbor & (hit.neighbor >= 0) THEN
								shift := Ceiling(hit.neighbor) - sectors[hit.neighbor].ceiling
							END;
							hit.upperAnchor := hit.upperAnchor + shift
						END;
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
			ceiling := Ceiling(sector);
			FOR i := 0 TO count - 1 DO
				IF DistanceSquared(walls[i], x, y) < radius * radius THEN
					IF (walls[i].neighbor < 0) OR walls[i].blocking THEN
						RETURN FALSE
					END;
					floor := MAX(floor, MAX(sectors[walls[i].sector].floor, sectors[walls[i].neighbor].floor));
					ceiling := MIN(ceiling, MIN(Ceiling(walls[i].sector), Ceiling(walls[i].neighbor)))
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

PROCEDURE Child(index, parent, leaves: SIGNED32): BOOLEAN;
BEGIN
	IF index >= 0 THEN
		RETURN index < parent
	END;
	RETURN -(index + 1) < leaves
END Child;

PROCEDURE Coordinate(value: FLOAT64): BOOLEAN;
BEGIN
	RETURN (value >= -Limit) & (value <= Limit)
END Coordinate;

END GameGeometry.
