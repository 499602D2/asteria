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

function dispupdate {

}

function gnc {
	PARAMETER AP.
	PARAMETER ECC.
	PARAMETER INCL.

	LOCAL t0 IS TIME:SECONDS.

	LOCK STEERING TO STEER. 

	IF SHIP:VERTICALSPEED > 0 {
		SET STEER TO SHIP:PROGRADE.
	} ELSE {
		SET STEER TO HEADING(INCL+90, 45).
	}
	
	WAIT 0.5.

	RCS ON.
	SAS OFF.

	// Periapsis from eccentricity and apoapsis
	//SET PE TO (-ecc*Ap+Ap-2*ecc*R)/(1+ecc).

	//SET sma TO R + (AP+PE)/2. // Circular orbit; sma = R + (AP+PA)/2

	//PRINT " ".
	//PRINT "ORBIT DELTA-V: " + round(dvAP,0) + " m/s".
	//PRINT "DELTA-V REQUIRED: " + round(dvAP-SHIP:AIRSPEED,0) + " m/s".

	LOCK THROTTLE TO THROTT. SET THROTT TO 1.
	LOCAL tStart IS TIME:SECONDS.
	WHEN TIME:SECONDS - tStart > 20 THEN {
		//STAGE. // Pop the fairings
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
			SET THROTT TO 1.
		}
	}

	SET THROTT TO 0.

	// Create a maneuver node
	SET t0 TO TIME:SECONDS.
	SET tAP TO ETA:APOAPSIS. // Seconds until we reach apoapsis

	// Calculate orbital dv
	SET radius TO Kerbin:radius.
	SET Mkerbin TO Kerbin:Mass. 
	SET const_G TO constant:G.

	SET Ra TO radius + AP.
	SET SMA TO Ra/(1+ECC).

	SET Rp1 TO 2*SMA - Ra. // Final periapsis
	SET Rp0 TO SHIP:PERIAPSIS + radius. // Initial periapsis

	SET vOrbit0 TO SQRT(mu*(2/Ra - 2/(Ra+Rp0))). // orbital velocity of initial trajectory
	SET vOrbit1 TO SQRT(mu*(2/Ra - 2/(Ra+Rp1))). // orbital velocity of final orbit
	SET burndv TO vOrbit1 - vOrbit0. 

	PRINT " ".
	CLEARSCREEN.
	PRINT "Target orbit:".
	PRINT "ECC: " + ECC.
	PRINT "SMA: " + round(SMA/1000,2) + " km".
	PRINT "AP: " + ROUND((Ra-radius)/1000,2) + " km".
	PRINT "PE: " + ROUND((Rp1-radius)/1000,2) + " km".
	PRINT "Orbital velocity: " + round(vOrbit1,2) + " m/s".

	PRINT " ".
	PRINT "Current orbit:".
	PRINT "ECC: " + round(ORBIT:Eccentricity,2).
	PRINT "SMA: " + round(ORBIT:SEMIMAJORAXIS/1000,2) + " km".
	PRINT "AP: " + round(SHIP:APOAPSIS/1000,2) + " km".
	PRINT "Orbital velocity: " + round(vOrbit0,2) + " m/s".
	PRINT "Delta-v required: " + round(burndv,2) + " m/s".

	PRINT " ".
	PRINT "CREATING NODE FOR INSERTION BURN".
	PRINT "COASTING UNTIL BURN START".

	SET PARKNODE TO NODE(TIME:SECONDS+tAP, 0, 0, burndv).
	ADD PARKNODE.

	SET STEER TO PARKNODE:DELTAV.
	SET a TO SHIP:AVAILABLETHRUST/SHIP:MASS.
	SET tburn TO burndv/a.
	SET t0 TO TIME:SECONDS.

	WHEN TIME:SECONDS - t0 > 20 THEN {
		SET kuniverse:timewarp:rate TO 50.
	}

	WHEN PARKNODE:ETA < tburn+60 THEN {
		SET kuniverse:timewarp:rate TO 10.
	}

	WHEN PARKNODE:ETA < tburn+15 THEN {
		SET kuniverse:timewarp:rate TO 1.
	}

	UNTIL PARKNODE:ETA < tburn {
		SET STEER TO PARKNODE:DELTAV.
	}

	SET THROTT TO 1.
	UNTIL PARKNODE:DELTAV:MAG <= 0 {
		SET STEER TO PARKNODE:DELTAV.

		IF PARKNODE:DELTAV:MAG < 20 AND PARKNODE:DELTAV:MAG > 2 {
			SET THROTT TO 0.1.
		}

		IF PARKNODE:DELTAV:MAG < 2 {
			SET THROTT TO 0.05.
		}

		//IF STAGE:LIQUIDFUEL < 0.2 {
		//	SET THROTT TO 0.
		//	PRINT "STAGE OUT OF FUEL - GUIDANCE ENDING".
		//	STAGE.
		//}
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
// Debug
//SET LAUNCH TO FALSE. SET AP TO 2868.75*1000. SET ECC TO 0. SET INCL TO 90.

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
PRINT "ORBIT STATUS:".
PRINT "SMA: " + round(ORBIT:SEMIMAJORAXIS,2).
PRINT "ECC: " + round(ORBIT:Eccentricity,2).
PRINT "AP: " + round(ORBIT:APOAPSIS,2).
PRINT "PE: " + round(ORBIT:PERIAPSIS,2).
PRINT "".
PRINT "EXITING PROGRAM.".
PRINT "THANK YOU FOR FLYING WITH ASTERIA".