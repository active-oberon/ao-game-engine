MODULE GameClock;

TYPE
	Clock* = OBJECT
	VAR rate, remainder: SIGNED32;

		PROCEDURE &Init*(ticksPerSecond: SIGNED32);
		BEGIN
			ASSERT((ticksPerSecond > 0) & (ticksPerSecond <= 1000));
			rate := ticksPerSecond;
			remainder := 0
		END Init;

		PROCEDURE Consume*(milliseconds: SIGNED32): SIGNED32;
		VAR ticks: SIGNED32;
		BEGIN
			ASSERT((milliseconds >= 0) & (milliseconds <= 1000));
			INC(remainder, milliseconds * rate);
			ticks := remainder DIV 1000;
			remainder := remainder MOD 1000;
			RETURN ticks
		END Consume;
	END Clock;

END GameClock.
