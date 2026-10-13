MODULE AnimationSmoke;

IMPORT GameAnimation;

PROCEDURE {TEST} BoundariesAndCopies*;
VAR ticks: ARRAY 3 OF SIGNED32;
	clip: GameAnimation.Clip;
BEGIN
	ticks[0] := 8;
	ticks[1] := 6;
	ticks[2] := 4;
	clip := GameAnimation.Read(ticks);
	ASSERT((clip # NIL) & (clip.count = 3) & (clip.duration = 18));
	ASSERT((clip.Frame(-1, FALSE) = 0) & (clip.Frame(7, FALSE) = 0));
	ASSERT((clip.Frame(8, FALSE) = 1) & (clip.Frame(13, FALSE) = 1));
	ASSERT((clip.Frame(14, FALSE) = 2) & (clip.Frame(18, FALSE) = 2));
	ASSERT(clip.Frame(MAX(SIGNED64), FALSE) = 2);
	ASSERT((clip.Frame(18, TRUE) = 0) & (clip.Frame(26, TRUE) = 1));
	ticks[0] := 1;
	ASSERT((clip.duration = 18) & (clip.Frame(7, FALSE) = 0));
	ticks[1] := 0;
	ASSERT(GameAnimation.Read(ticks) = NIL);
	ticks[1] := -1;
	ASSERT(GameAnimation.Read(ticks) = NIL)
END BoundariesAndCopies;

PROCEDURE {TEST} UniformAndBounds*;
VAR clip: GameAnimation.Clip;
	ticks: ARRAY GameAnimation.MaximumFrames + 1 OF SIGNED32;
	i: SIGNED32;
BEGIN
	clip := GameAnimation.Uniform(4, 3);
	ASSERT((clip # NIL) & (clip.duration = 12));
	ASSERT((clip.Frame(2, TRUE) = 0) & (clip.Frame(3, TRUE) = 1));
	ASSERT((clip.Frame(12, TRUE) = 0) & (clip.Frame(120, FALSE) = 3));
	ASSERT(GameAnimation.Uniform(0, 3) = NIL);
	ASSERT(GameAnimation.Uniform(GameAnimation.MaximumFrames + 1, 3) = NIL);
	ASSERT(GameAnimation.Uniform(4, 0) = NIL);
	FOR i := 0 TO GameAnimation.MaximumFrames DO
		ticks[i] := 1
	END;
	ASSERT(GameAnimation.Read(ticks) = NIL);
	clip := GameAnimation.Uniform(1, MAX(SIGNED32));
	ASSERT((clip.duration = MAX(SIGNED32)) & (clip.Frame(MAX(SIGNED64), TRUE) = 0));
	clip := GameAnimation.Uniform(GameAnimation.MaximumFrames, MAX(SIGNED32));
	ASSERT(clip.duration = SIGNED64(GameAnimation.MaximumFrames) * MAX(SIGNED32));
	ASSERT(clip.Frame(clip.duration - 1, FALSE) = GameAnimation.MaximumFrames - 1)
END UniformAndBounds;

PROCEDURE Do*;
BEGIN
	BoundariesAndCopies;
	UniformAndBounds
END Do;

END AnimationSmoke.
