MODULE GameGeometry;

IMPORT MathL, GameMaterials;

CONST Limit = 1000000.0;

TYPE
	Wall* = RECORD
		ax*, ay*, bx*, by*: FLOAT64;
		bottom*, top*: FLOAT64;
		color*, light*: SIGNED32;
		texture*: GameMaterials.Texture;
		uScale*, vScale*, uOffset*, vOffset*: FLOAT64
	END;

	World* = OBJECT
	VAR walls: POINTER TO ARRAY OF Wall;
		count: SIGNED32;
		sealed: BOOLEAN;

		PROCEDURE &Init*(capacity: SIGNED32);
		BEGIN
			ASSERT((capacity > 0) & (capacity <= 65536));
			NEW(walls, capacity);
			count := 0;
			sealed := FALSE
		END Init;

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
				(wall.top <= wall.bottom) OR (wall.color < 0) OR
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

		PROCEDURE Cast*(x, y, dx, dy: FLOAT64; VAR distance: FLOAT64;
			VAR hit: Wall): BOOLEAN;
		VAR i: SIGNED32;
			sx, sy, qx, qy, denominator, t, u: FLOAT64;
			found: BOOLEAN;
		BEGIN
			ASSERT(sealed);
			ASSERT(Coordinate(x) & Coordinate(y));
			ASSERT(Coordinate(dx) & Coordinate(dy));
			distance := MAX(FLOAT64);
			found := FALSE;
			FOR i := 0 TO count - 1 DO
				sx := walls[i].bx - walls[i].ax;
				sy := walls[i].by - walls[i].ay;
				denominator := dx * sy - dy * sx;
				IF ABS(denominator) > 0.000000001 THEN
					qx := walls[i].ax - x;
					qy := walls[i].ay - y;
					t := (qx * sy - qy * sx) / denominator;
					u := (qx * dy - qy * dx) / denominator;
					IF (t > 0.000001) & (t < distance) & (u >= 0) & (u <= 1) THEN
						distance := t;
						hit := walls[i];
						found := TRUE
					END
				END
			END;
			RETURN found
		END Cast;

		PROCEDURE Free*(x, y, radius: FLOAT64): BOOLEAN;
		VAR i: SIGNED32;
			sx, sy, t, qx, qy: FLOAT64;
		BEGIN
			ASSERT(sealed);
			IF ~Coordinate(x) OR ~Coordinate(y) OR
				~((radius > 0) & (radius <= Limit)) THEN
				RETURN FALSE
			END;
			FOR i := 0 TO count - 1 DO
				sx := walls[i].bx - walls[i].ax;
				sy := walls[i].by - walls[i].ay;
				t := ((x - walls[i].ax) * sx + (y - walls[i].ay) * sy) /
					(sx * sx + sy * sy);
				IF t < 0 THEN
					t := 0
				ELSIF t > 1 THEN
					t := 1
				END;
				qx := x - (walls[i].ax + t * sx);
				qy := y - (walls[i].ay + t * sy);
				IF qx * qx + qy * qy <= radius * radius THEN
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

PROCEDURE Coordinate(value: FLOAT64): BOOLEAN;
BEGIN
	RETURN (value >= -Limit) & (value <= Limit)
END Coordinate;

END GameGeometry.
