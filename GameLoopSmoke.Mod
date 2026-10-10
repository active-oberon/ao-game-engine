MODULE GameLoopSmoke;

IMPORT GameLoop;

TYPE
	Counter = OBJECT
	VAR value: SIGNED64;

		PROCEDURE &Init;
		BEGIN
			value := 0
		END Init;

		PROCEDURE Step(tick: SIGNED64);
		BEGIN
			ASSERT(tick = value + 1);
			value := tick
		END Step;

		PROCEDURE Value(): SIGNED64;
		BEGIN
			RETURN value
		END Value;
	END Counter;

TYPE
	Driver = OBJECT
	VAR simulation: GameLoop.Simulation;
		done, accepted: BOOLEAN;

		PROCEDURE &Init(loop: GameLoop.Simulation);
		BEGIN
			simulation := loop;
			done := FALSE;
			accepted := FALSE
		END Init;

		PROCEDURE Wait;
		BEGIN {EXCLUSIVE}
			AWAIT(done);
			ASSERT(accepted)
		END Wait;

	BEGIN {ACTIVE, EXCLUSIVE}
		accepted := simulation.Advance(2000);
		done := TRUE
	END Driver;

PROCEDURE Do*;
VAR simulation: GameLoop.Simulation;
	counter: Counter;
	first, second: Driver;
BEGIN
	NEW(counter);
	NEW(simulation, counter.Step);
	ASSERT(simulation.Advance(0));
	ASSERT(counter.Value() = 0);
	ASSERT(~simulation.Advance(-1));
	ASSERT(simulation.Advance(35));
	ASSERT(counter.Value() = 35);
	ASSERT(simulation.Advance(70));
	ASSERT(counter.Value() = 105);
	simulation.Close;
	simulation.Close;
	ASSERT(~simulation.Advance(1));
	ASSERT(counter.Value() = 105);
	NEW(counter);
	NEW(simulation, counter.Step);
	NEW(first, simulation);
	NEW(second, simulation);
	first.Wait;
	second.Wait;
	ASSERT(counter.Value() = 4000);
	simulation.Close;
	NEW(simulation, counter.Step);
	simulation.Close;
	ASSERT(~simulation.Advance(0))
END Do;

END GameLoopSmoke.
