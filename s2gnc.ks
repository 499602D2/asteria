// S2 guidance for use with Asteria's main program
// v0.01: 15.09.2018

// Notes:
// You MUST have two kOS CPU's on the vessel - one for S1, one for S2.

// Constants
SET g TO 9.80665.
SET mu TO 3.5316*10^12. // Standard gravitational parameter

// Functions
function msgq {
	SET QUEUE TO CORE:MESSAGES.

	IF QUEUE:LENGTH = 0 { // Go through core's and ship's messages at the same time
		SET QUEUE TO SHIP:MESSAGES.
	}

	PRINT "MESSAGES IN QUEUE: " + QUEUE:LENGTH.

	UNTIL QUEUE:EMPTY {
		SET RECEIVED TO QUEUE:POP.
		PRINT "MESSAGE RECEIVED: " + RECEIVED:CONTENT.

		IF RECEIVED:CONTENT = "MECO" {
			SET n TO 0.
			UNTIL QUEUE:EMPTY {
				SET RECEIVED TO QUEUE:POP.
				IF n = 0 {
					SET AP TO RECEIVED:CONTENT.
					PRINT "AP RECEIVED".
				} ELSE IF n = 1 {
					SET ECC TO RECEIVED:CONTENT.
					PRINT "ECC RECEIVED".
				} ELSE IF n = 2{
					SET INCL TO RECEIVED:CONTENT.
					PRINT "INCL RECEIVED".
				}
				SET n TO n + 1.
			}
			SET GNCSTART TO 1.
			WAIT 0.5.
		}
	} 
}

function dispinit {
	PRINT "|ASTERIA S2 GNC - v0.01". // 0,0
	PRINT "|".
	PRINT "|ORBIT".
	PRINT "|".
	PRINT "|VEHICLE".

}

function dispupdate {

}

function gnc {
	PARAMETER AP.
	PARAMETER ECC.
	PARAMETER INCL.

	LOCAL t0 IS TIME:SECONDS.

	RCS ON.
	SAS OFF.

	LOCK STEERING TO STEER. 

	IF SHIP:VERTICALSPEED > 0 {
		SET STEER TO SHIP:PROGRADE + R(0,0,270).
	} ELSE {
		SET STEER TO HEADING(INCL+90, 45).
	}
	
	WAIT 0.5.

	// Calculate orbital dv
	SET R TO AP + 600000. // Radius of kerbin + apoapsis + altitude
	SET Mkerbin TO 5.2915158*10^22. // kg
	SET const_G TO 6.674 * 10^(-11).
	SET a_Ap TO mu/R^2. // Gravitational acceleration at apoapsis

	// Periapsis from eccentricity and apoapsis
	SET PE TO (-ecc*Ap+Ap-2*ecc*R)/(1+ecc).

	SET sma TO R + (AP+PE)/2. // Circular orbit; sma = R + (AP+PA)/2
	SET dvAP TO SQRT(const_G * Mkerbin *(2/R - 1/sma)). // Calculate dv from vis-viva equation

	//PRINT " ".
	//PRINT "ORBIT DELTA-V: " + round(dvAP,0) + " m/s".
	//PRINT "DELTA-V REQUIRED: " + round(dvAP-SHIP:AIRSPEED,0) + " m/s".

	LOCK THROTTLE TO THROTT. SET THROTT TO 1.
	LOCAL tStart IS TIME:SECONDS.
	WHEN TIME:SECONDS - tStart > 10 THEN {
		//STAGE.
	}

	//PRINT " ".
	//PRINT "CURRENT APOAPSIS: " + round(SHIP:APOAPSIS/1000,0) + " km".
	//PRINT "TARGET APOAPSIS: " + round(AP/1000,0) + " km".
	//PRINT "CALCULATED PERIAPSIS: " + round(PE/1000,0) + " km".

	UNTIL SHIP:APOAPSIS >= AP {
		SET STEER TO SHIP:PROGRADE + R(0,0,270).

		IF AP - SHIP:APOAPSIS < 10000 AND SHIP:AVAILABLETHRUST/(SHIP:MASS*g) > 1.45 {
			SET THROTT TO 1/(SHIP:AVAILABLETHRUST/(SHIP:MASS*g)). // TWR = 1 thrust
		} ELSE {
			SET THROTT TO 0.75.
		}
	}

	SET THROTT TO 0.

	// Create a maneuver node
	SET t0 TO TIME:SECONDS.
	SET tAP TO ETA:APOAPSIS. // Seconds until we reach apoapsis

	SET R TO 600000 + SHIP:APOAPSIS.
	SET targetAP TO AP.
	SET targetPE TO (-ECC*AP+AP-2*ECC*R)/(1+ECC).
	SET smatarget TO R + (targetAP+targetPE)/2. // Circular orbit; sma = R + (AP+PA)/2

	SET vOrbit TO SQRT(mu*(2/R - 1/ORBIT:SEMIMAJORAXIS)).
	SET vTarget TO SQRT(mu*(2/R - 1/(smatarget))).
	SET targetdeltav TO vTarget - vOrbit.

	SET PElift TO PE - SHIP:ORBIT:PERIAPSIS.
	//SET burndv2 TO SQRT(2*a_Ap*PElift).
	SET burndv TO dvAP - vOrbit.

	PRINT " ".
	//PRINT "SHIP:ORBIT:PERIAPSIS: " + round(SHIP:ORBIT:PERIAPSIS/1000,2) + " km".
	//PRINT "PElift: " + round(PElift/1000,2) + " km".
	//PRINT "CALCULATED DV TO PE (1): " + round(burndv,0) + " m/s".
	//PRINT "CALCULATED DV TO PE: " + round(burndv,0) + " m/s".
	//PRINT "ORBITAL SPEED (AP): " + round(vorbit,0) + " m/s".
	//PRINT "---".
	//PRINT "NEW ORBITAL CALCS:".
	CLEARSCREEN.
	PRINT "Debug prints:".
	PRINT "Target SMA: " + round(smatarget,2).
	PRINT "----------".
	PRINT "Orbital parameters:".
	PRINT "INCL: " + INCL.
	PRINT "ECC: " + ECC.
	PRINT "AP: " + ROUND(AP/1000,2) + " km".
	PRINT "PE: " + ROUND((targetPE+600000)/1000,2) + " km".
	PRINT " ".
	PRINT "Current orbital velocity: " + round(vOrbit,2) + " m/s".
	PRINT "Target orbit velocity: " + round(vTarget,2) + " m/s".
	PRINT "Delta-v required: " + round(targetdeltav,2) + " m/s".

	PRINT " ".
	PRINT "CREATING NODE FOR INSERTION BURN".
	PRINT "COASTING UNTIL BURN START".

	SET PARKNODE TO NODE(TIME:SECONDS+tAP, 0, 0, targetdeltav).
	ADD PARKNODE.

	SET STEER TO PARKNODE:DELTAV.

	SET a TO SHIP:AVAILABLETHRUST/SHIP:MASS.
	SET tburn TO burndv/a.

	UNTIL PARKNODE:ETA < tburn {
		SET STEER TO PARKNODE:DELTAV.
	}

	UNTIL PARKNODE:DELTAV:MAG <= 0.5 {
		SET STEER TO PARKNODE:DELTAV.
		SET THROTT TO 1.

		PRINT PARKNODE:DELTAV:MAG.

		IF PARKNODE:DELTAV:MAG < 100 {
			SET THROTT TO 0.1.
		}

		IF STAGE:LIQUIDFUEL < 0.2 {
			PRINT "STAGE OUT OF FUEL - GUIDANCE ENDING".
			STAGE.
		}
	}

	SET THROTT TO 0.
	REMOVE PARKNODE.

	// Stabilise stage
	SET STEER TO SHIP:PROGRADE.
	WAIT 5.

	SAS ON.
}

// If launch is true, we monitor the messages received for an indication of MECO
CLEARSCREEN.
SET LAUNCH to TRUE.
//SET LAUNCH TO FALSE. SET AP TO 300000. SET ECC TO 0.32. SET INCL TO 0.

// Monitor message queue
SET t0 TO TIME:SECONDS.
SET t1 TO t0 + 2.
IF LAUNCH = TRUE {
	SET GNCSTART TO 0.
	SET i TO 0.
	UNTIL GNCSTART = 1 {
		SET t0 TO TIME:SECONDS.
		IF t0 > t1 + 1 AND i = 0 {
			CLEARSCREEN.
			PRINT ".------------------------------------------------.".
			PRINT "|                     ORBEX                  v0.1|".
			PRINT "|---------------- MISSION STATUS ----------------|".
			PRINT "WAITING FOR S2 GUIDANCE START".
			msgq().
			SET i TO 1.
		}

		IF t0 > t1 + 2 AND i = 1 {
			PRINT "." AT (29,3).
			SET i TO 2.
		}

		IF t0 > t1 + 3 AND i = 2 {
			PRINT "." AT (30,3).
			SET i TO 3.
		}

		IF t0 > t1 + 4 AND i = 3 {
			PRINT "." AT (31,3).
			SET i TO 0.
			SET t1 TO t0.
		}
	}
}

CLEARSCREEN.
PRINT "STARTING S2 GUIDANCE".
PRINT " ".

SET THROTTLE TO 0.15.
WAIT 0.25.

// Eccentricity: circular = 0, elliptical = [0,1], parabolic = 1, hyperbolic > 1
gnc(AP, ECC, INCL).

PRINT " ".
PRINT "S2 ORBIT INJECTION COMPLETE".
PRINT "".
PRINT "EXITING PROGRAM.".
PRINT "THANK YOU FOR FLYING WITH ASTERIA".