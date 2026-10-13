MODULE GameAnimation;

CONST MaximumFrames* = 16;

TYPE
	Clip* = OBJECT
	VAR count-: SIGNED32;
		duration-: SIGNED64;
		ends: POINTER TO ARRAY OF SIGNED64;

		(* Frame derives playback from elapsed ticks so rendering needs no mutable animation clock. *)
		PROCEDURE Frame*(elapsed: SIGNED64; looping: BOOLEAN): SIGNED32;
		VAR frame: SIGNED32;
		BEGIN
			ASSERT((count > 0) & (duration > 0));
			elapsed := MAX(0, elapsed);
			IF looping THEN
				elapsed := elapsed MOD duration
			END;
			frame := 0;
			WHILE (frame < count - 1) & (elapsed >= ends[frame]) DO
				INC(frame)
			END;
			RETURN frame
		END Frame;
	END Clip;

(* Read copies positive durations so callers cannot change a published clip through their source array. *)
PROCEDURE Read*(CONST ticks: ARRAY OF SIGNED32): Clip;
VAR clip: Clip;
	i: SIGNED32;
BEGIN
	IF (LEN(ticks) = 0) OR (LEN(ticks) > MaximumFrames) THEN
		RETURN NIL
	END;
	FOR i := 0 TO SIGNED32(LEN(ticks)) - 1 DO
		IF ticks[i] <= 0 THEN
			RETURN NIL
		END
	END;
	NEW(clip);
	clip.count := SIGNED32(LEN(ticks));
	clip.duration := 0;
	NEW(clip.ends, clip.count);
	FOR i := 0 TO clip.count - 1 DO
		clip.duration := clip.duration + ticks[i];
		clip.ends[i] := clip.duration
	END;
	RETURN clip
END Read;

(* Uniform stores constant-rate playback once instead of rebuilding timing arrays during rendering. *)
PROCEDURE Uniform*(frames, ticks: SIGNED32): Clip;
VAR clip: Clip;
	i: SIGNED32;
BEGIN
	IF (frames < 1) OR (frames > MaximumFrames) OR (ticks < 1) THEN
		RETURN NIL
	END;
	NEW(clip);
	clip.count := frames;
	clip.duration := SIGNED64(frames) * ticks;
	NEW(clip.ends, frames);
	FOR i := 0 TO frames - 1 DO
		clip.ends[i] := SIGNED64(i + 1) * ticks
	END;
	RETURN clip
END Uniform;

END GameAnimation.
