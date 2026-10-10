MODULE GameRenderer;

IMPORT GameGeometry, GameSurface, MathL;

PROCEDURE Render*(world: GameGeometry.World; frame: GameSurface.Frame;
	x, y, angle, eye: FLOAT64);
VAR column, row, top, bottom, color, shade, texel: SIGNED32;
	dx, dy, camera, rx, ry, distance, projection, upper, lower: FLOAT64;
	wall: GameGeometry.Wall;
	u, v, wx, wy, length: FLOAT64;
BEGIN
	ASSERT((angle >= -MathL.pi * 2) & (angle <= MathL.pi * 2));
	ASSERT((eye >= -1000000) & (eye <= 1000000));
	frame.Background(0202938H, 035302CH);
	dx := MathL.cos(angle);
	dy := MathL.sin(angle);
	projection := frame.width / 1.32;
	FOR column := 0 TO frame.width - 1 DO
		camera := (2.0 * column + 1) / frame.width - 1;
		rx := dx - dy * camera * 0.66;
		ry := dy + dx * camera * 0.66;
		IF world.Cast(x, y, rx, ry, distance, wall) THEN
			IF distance < 0.01 THEN
				distance := 0.01
			END;
			upper := frame.height / 2.0 - (wall.top - eye) * projection / distance;
			lower := frame.height / 2.0 - (wall.bottom - eye) * projection / distance;
			IF upper < 0 THEN
				upper := 0
			ELSIF upper > frame.height THEN
				upper := frame.height
			END;
			IF lower < -1 THEN
				lower := -1
			ELSIF lower >= frame.height THEN
				lower := frame.height - 1
			END;
			top := ENTIER(upper);
			bottom := ENTIER(lower);
			shade := ENTIER(256.0 * wall.light / 255 / (1 + distance * 0.08));
			color := (wall.color DIV 65536 MOD 256 * shade DIV 256) * 65536 +
				(wall.color DIV 256 MOD 256 * shade DIV 256) * 256 +
				(wall.color MOD 256 * shade DIV 256);
			IF wall.texture = NIL THEN
				frame.Span(column, top, bottom, color)
			ELSE
				wx := x + rx * distance - wall.ax;
				wy := y + ry * distance - wall.ay;
				length := MathL.sqrt((wall.bx - wall.ax) * (wall.bx - wall.ax) +
					(wall.by - wall.ay) * (wall.by - wall.ay));
				u := (wx * (wall.bx - wall.ax) + wy * (wall.by - wall.ay)) / length;
				FOR row := top TO bottom DO
					v := wall.top - eye - (frame.height / 2.0 - row - 0.5) * distance / projection;
					texel := wall.texture.Sample(u * wall.uScale + wall.uOffset,
						v * wall.vScale + wall.vOffset);
					color := (texel DIV 65536 MOD 256 * shade DIV 256) * 65536 +
						(texel DIV 256 MOD 256 * shade DIV 256) * 256 +
						(texel MOD 256 * shade DIV 256);
					frame.Span(column, row, row, color)
				END
			END
		END
	END
END Render;

END GameRenderer.
