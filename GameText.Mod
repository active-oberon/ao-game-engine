MODULE GameText;

IMPORT GameSurface;

PROCEDURE Glyph(c: CHAR): SIGNED32;
BEGIN
	CASE c OF
	"0":
		RETURN 07B6FH
	| "1":
		RETURN 02C97H
	| "2":
		RETURN 073E7H
	| "3":
		RETURN 073CFH
	| "4":
		RETURN 05BC9H
	| "5":
		RETURN 079CFH
	| "6":
		RETURN 079EFH
	| "7":
		RETURN 07249H
	| "8":
		RETURN 07BEFH
	| "9":
		RETURN 07BCFH
	| "A":
		RETURN 02BEDH
	| "B":
		RETURN 06BAEH
	| "C":
		RETURN 07927H
	| "D":
		RETURN 06B6EH
	| "E":
		RETURN 079A7H
	| "F":
		RETURN 079A4H
	| "G":
		RETURN 0796FH
	| "H":
		RETURN 05BEDH
	| "I":
		RETURN 07497H
	| "J":
		RETURN 0126FH
	| "K":
		RETURN 05BADH
	| "L":
		RETURN 04927H
	| "M":
		RETURN 05FEDH
	| "N":
		RETURN 06B6DH
	| "O":
		RETURN 02B6AH
	| "P":
		RETURN 06BA4H
	| "Q":
		RETURN 02B7BH
	| "R":
		RETURN 06BADH
	| "S":
		RETURN 079CFH
	| "T":
		RETURN 07492H
	| "U":
		RETURN 05B6FH
	| "V":
		RETURN 05B6AH
	| "W":
		RETURN 05BFDH
	| "X":
		RETURN 05AADH
	| "Y":
		RETURN 05A92H
	| "Z":
		RETURN 072A7H
	| "%":
		RETURN 052A5H
	| "-":
		RETURN 001C0H
	| ".":
		RETURN 00002H
	ELSE
		RETURN 0
	END
END Glyph;

(* Draw uses an original 3-by-5 uppercase font for asset-free status displays. *)
PROCEDURE Draw*(frame: GameSurface.Frame; x, y, color: SIGNED32; CONST text: ARRAY OF CHAR);
VAR i, row, column, glyph, bit: SIGNED32;
BEGIN
	i := 0;
	WHILE (i < LEN(text)) & (text[i] # 0X) DO
		glyph := Glyph(text[i]);
		bit := 16384;
		FOR row := 0 TO 4 DO
			FOR column := 0 TO 2 DO
				IF glyph DIV bit MOD 2 = 1 THEN
					frame.Span(x + column, y + row, y + row, color)
				END;
				bit := bit DIV 2
			END
		END;
		INC(x, 4);
		INC(i)
	END
END Draw;

END GameText.
