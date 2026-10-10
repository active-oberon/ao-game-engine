MODULE GameDisplay;

IMPORT Displays, Plugins, GameSurface;

TYPE
	Presenter* = OBJECT
	VAR display: Displays.Display;
		buffer: POINTER TO ARRAY OF CHAR;

		PROCEDURE &Init*(device: Displays.Display);
		BEGIN
			display := device;
			NEW(buffer, display.width * display.height * display.format)
		END Init;

		PROCEDURE Present*(frame: GameSurface.Frame): BOOLEAN;
		VAR scale, width, height, left, top, x, y, source, destination: SIGNED32;
		BEGIN
			scale := display.width DIV frame.width;
			IF display.height DIV frame.height < scale THEN
				scale := display.height DIV frame.height
			END;
			IF scale < 1 THEN
				RETURN FALSE
			END;
			width := frame.width * scale;
			height := frame.height * scale;
			left := (display.width - width) DIV 2;
			top := (display.height - height) DIV 2;
			FOR y := 0 TO height - 1 DO
				FOR x := 0 TO width - 1 DO
					source := ((y DIV scale) * frame.width + x DIV scale) * 4;
					destination := (y * width + x) * display.format;
					buffer[destination] := frame.pixels[source];
					buffer[destination + 1] := frame.pixels[source + 1];
					buffer[destination + 2] := frame.pixels[source + 2];
					IF display.format = Displays.color8888 THEN
						buffer[destination + 3] := 0X
					END
				END
			END;
			display.Transfer(buffer^, 0, width * display.format, left, top,
				width, height, Displays.set);
			display.Update;
			RETURN TRUE
		END Present;
	END Presenter;

PROCEDURE Open*(): Presenter;
VAR plugin: Plugins.Plugin;
	display: Displays.Display;
	presenter: Presenter;
BEGIN
	plugin := Displays.registry.Get("");
	IF (plugin = NIL) OR ~(plugin IS Displays.Display) THEN
		RETURN NIL
	END;
	display := plugin(Displays.Display);
	IF (display.format # Displays.color888) &
		(display.format # Displays.color8888) THEN
		RETURN NIL
	END;
	display.Fill(0, 0, 0, display.width, display.height);
	NEW(presenter, display);
	RETURN presenter
END Open;

END GameDisplay.
