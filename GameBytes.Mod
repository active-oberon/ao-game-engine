MODULE GameBytes;

IMPORT Files;

CONST MaximumFile* = 64 * 1024 * 1024;

TYPE Buffer* = POINTER TO ARRAY OF CHAR;

PROCEDURE Range*(CONST data: ARRAY OF CHAR; offset, size: SIGNED32): BOOLEAN;
BEGIN
	RETURN (offset >= 0) & (size >= 0) & (offset <= LEN(data)) &
		(size <= LEN(data) - offset)
END Range;

PROCEDURE U16*(CONST data: ARRAY OF CHAR; offset: SIGNED32): SIGNED32;
VAR low, high: SIGNED32;
BEGIN
	ASSERT(Range(data, offset, 2));
	low := ORD(data[offset]);
	high := ORD(data[offset + 1]);
	RETURN low + high * 256
END U16;

PROCEDURE I16*(CONST data: ARRAY OF CHAR; offset: SIGNED32): SIGNED32;
VAR value: SIGNED32;
BEGIN
	value := U16(data, offset);
	IF value >= 32768 THEN
		DEC(value, 65536)
	END;
	RETURN value
END I16;

PROCEDURE I32*(CONST data: ARRAY OF CHAR; offset: SIGNED32): SIGNED32;
VAR low, middle, high: SIGNED32;
BEGIN
	ASSERT(Range(data, offset, 4));
	low := U16(data, offset);
	middle := ORD(data[offset + 2]);
	high := ORD(data[offset + 3]);
	IF high >= 128 THEN
		DEC(high, 256)
	END;
	RETURN low + middle * 65536 + high * 16777216
END I32;

PROCEDURE Load*(CONST path: ARRAY OF CHAR): Buffer;
VAR file: Files.File;
	rider: Files.Rider;
	data: Buffer;
	size: Files.Size;
BEGIN
	file := Files.Old(path);
	IF file = NIL THEN
		RETURN NIL
	END;
	size := file.Length();
	IF (size < 0) OR (size > MaximumFile) THEN
		RETURN NIL
	END;
	NEW(data, size);
	file.Set(rider, 0);
	file.ReadBytes(rider, data^, 0, size);
	IF rider.res # 0 THEN
		RETURN NIL
	END;
	RETURN data
END Load;

END GameBytes.
