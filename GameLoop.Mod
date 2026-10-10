MODULE GameLoop;

TYPE
	Step* = PROCEDURE {DELEGATE} (tick: SIGNED64);

	Simulation* = OBJECT
	VAR step: Step;
		pending: SIGNED64;
		tick: SIGNED64;
		stopping, dead: BOOLEAN;

		PROCEDURE &Init*(update: Step);
		BEGIN
			ASSERT(update # NIL);
			step := update;
			pending := 0;
			tick := 0;
			stopping := FALSE;
			dead := FALSE
		END Init;

		PROCEDURE Advance*(count: SIGNED64): BOOLEAN;
		BEGIN {EXCLUSIVE}
			IF (count < 0) OR stopping THEN
				RETURN FALSE
			END;
			AWAIT((pending = 0) OR stopping);
			IF stopping OR (count > MAX(SIGNED64) - tick) THEN
				RETURN FALSE
			END;
			pending := count;
			AWAIT(pending = 0);
			RETURN TRUE
		END Advance;

		PROCEDURE Close*;
		BEGIN {EXCLUSIVE}
			stopping := TRUE;
			AWAIT(dead)
		END Close;

	BEGIN {ACTIVE, EXCLUSIVE}
		LOOP
			AWAIT((pending > 0) OR stopping);
			IF pending > 0 THEN
				INC(tick);
				step(tick);
				DEC(pending)
			ELSIF stopping THEN
				EXIT
			END
		END;
		step := NIL;
		dead := TRUE
	END Simulation;

END GameLoop.
