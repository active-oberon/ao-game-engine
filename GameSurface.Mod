MODULE GameSurface;

IMPORT Files, Streams;

TYPE
	Frame* = OBJECT
	VAR width-, height-: SIGNED32;
		pixels-: POINTER TO ARRAY OF CHAR;

		PROCEDURE &Init*(w, h: SIGNED32);
		BEGIN
			ASSERT((w > 0) & (w <= 4096) & (h > 0) & (h <= 4096));
			width := w;
			height := h;
			NEW(pixels, w * h * 4)
		END Init;

		PROCEDURE Pixel*(x, y: SIGNED32): SIGNED32;
		VAR offset, red, green, blue: SIGNED32;
		BEGIN
			ASSERT((x >= 0) & (x < width) & (y >= 0) & (y < height));
			offset := (y * width + x) * 4;
			blue := ORD(pixels[offset]);
			green := ORD(pixels[offset + 1]);
			red := ORD(pixels[offset + 2]);
			RETURN blue + green * 256 + red * 65536
		END Pixel;

		PROCEDURE Span*(x, top, bottom, color: SIGNED32);
		VAR y, offset: SIGNED32;
			red, green, blue: CHAR;
		BEGIN
			IF (x < 0) OR (x >= width) THEN
				RETURN
			END;
			IF top < 0 THEN
				top := 0
			END;
			IF bottom >= height THEN
				bottom := height - 1
			END;
			blue := CHR(color MOD 256);
			green := CHR(color DIV 256 MOD 256);
			red := CHR(color DIV 65536 MOD 256);
			offset := (top * width + x) * 4;
			FOR y := top TO bottom DO
				pixels[offset] := blue;
				pixels[offset + 1] := green;
				pixels[offset + 2] := red;
				pixels[offset + 3] := 0X;
				INC(offset, width * 4)
			END
		END Span;

		PROCEDURE Background*(ceiling, floor: SIGNED32);
		VAR x: SIGNED32;
		BEGIN
			FOR x := 0 TO width - 1 DO
				Span(x, 0, height DIV 2 - 1, ceiling);
				Span(x, height DIV 2, height - 1, floor)
			END
		END Background;

		PROCEDURE Save*(CONST path: ARRAY OF CHAR): BOOLEAN;
		VAR file: Files.File;
			writer: Files.Writer;
			row: POINTER TO ARRAY OF CHAR;
			x, y, offset, result: SIGNED32;
		BEGIN
			file := Files.New(path);
			IF file = NIL THEN
				RETURN FALSE
			END;
			Files.OpenWriter(writer, file, 0);
			writer.String("P6");
			writer.Char(0AX);
			writer.Int(width, 0);
			writer.Char(" ");
			writer.Int(height, 0);
			writer.Char(0AX);
			writer.String("255");
			writer.Char(0AX);
			NEW(row, width * 3);
			FOR y := 0 TO height - 1 DO
				FOR x := 0 TO width - 1 DO
					offset := (y * width + x) * 4;
					row[x * 3] := pixels[offset + 2];
					row[x * 3 + 1] := pixels[offset + 1];
					row[x * 3 + 2] := pixels[offset]
				END;
				writer.Bytes(row^, 0, LEN(row^));
				IF writer.res # Streams.Ok THEN
					RETURN FALSE
				END
			END;
			writer.Update;
			IF writer.res # Streams.Ok THEN
				RETURN FALSE
			END;
			file.Register0(result);
			RETURN result = Files.Ok
		END Save;
	END Frame;

END GameSurface.
