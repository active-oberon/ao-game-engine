MODULE GameMaterials;

TYPE
	Texture* = OBJECT
	VAR width-, height-: SIGNED32;
		pixels: POINTER TO ARRAY OF SIGNED32;
		sealed-: BOOLEAN;

		PROCEDURE &Init*(w, h: SIGNED32);
		BEGIN
			ASSERT((w > 0) & (w <= 1024) & (h > 0) & (h <= 1024));
			width := w;
			height := h;
			NEW(pixels, w * h);
			sealed := FALSE
		END Init;

		PROCEDURE Set*(x, y, color: SIGNED32);
		BEGIN
			ASSERT(~sealed);
			ASSERT((x >= 0) & (x < width) & (y >= 0) & (y < height));
			ASSERT((color >= 0) & (color <= 0FFFFFFH));
			pixels[y * width + x] := color
		END Set;

		PROCEDURE Seal*;
		BEGIN
			sealed := TRUE
		END Seal;

		PROCEDURE Sample*(u, v: FLOAT64): SIGNED32;
		VAR x, y: SIGNED32;
		BEGIN
			ASSERT(sealed);
			ASSERT((u >= -1000000000000000.0) & (u <= 1000000000000000.0));
			ASSERT((v >= -1000000000000000.0) & (v <= 1000000000000000.0));
			u := u - ENTIER(u);
			v := v - ENTIER(v);
			x := ENTIER(u * width);
			y := ENTIER(v * height);
			RETURN pixels[y * width + x]
		END Sample;
	END Texture;

END GameMaterials.
