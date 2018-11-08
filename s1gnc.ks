// Asteria
// kOS-based guidance script for Kerbal Space Program
// Made with hate and pure agony by 0x12e

// Version history
// 0.01: 2018/02/13
// 0.99: 2018/02/17
// 1.0b1 2018/03/10
// 1.0b4 2018/06/08
// 1.2 2018/07/20
// 1.3 2018/09/14
// 1.31 2018/10
// 1.32 2018/11

// ORBIT PARAMETERS
IF ALT:RADAR < 1000 {
	PRINT "Perform a full launch? (y/n): ". SET input TO terminal:input:getchar().
	IF input = "y" {
		SET LAUNCH TO 1.
		SET BOOSTBACK TO 1.
	} ELSE {
		SET LAUNCH TO 0.
	}

	PRINT "Run S2 guidance? (y/n): ". SET input to terminal:input:getchar().
	IF input = "y" {
		SET S2GUIDANCE TO 1.
	} ELSE {
		SET S2GUIDANCE TO 0.
	}
} ELSE {
	PRINT "Boostback S1? (y/n): ". SET input to terminal:input:getchar().
	IF input = "y" {
		SET BOOSTBACK TO 1.
	} ELSE {
		SET BOOSTBACK TO 0.
	}
}

IF LAUNCH = 1 {
	PRINT "Enter apoapsis: ". SET AP TO terminal:input:getchar().
	PRINT "Enter eccentricity: ". SET ECC TO terminal:input:getchar(). // Eccentricity: circular = 0, elliptical = [0,1], parabolic = 1, hyperbolic > 1
	PRINT "Enter inclination: ". SET INCL TO terminal:input:getchar(). // 0 = due north, 90 = east, 180 = south, etc.
}

PRINT "Recover S1? (y/n): ". SET input TO terminal:input:getchar().
IF input = "y" {
	SET EXPEND TO 0.
} ELSE {
	SET EXPEND TO 1. { SET MODE TO "EXPENDABLE". } // Expendable mode

// Vehicle
IF EXPEND = 0 {
	PRINT "Does the engine have modes? (y/n): ". SET input TO terminal:input:getchar(). 
	IF input = "y" { 
		SET ENGINEMODES TO 1. 
	} ELSE {
		SET ENGINEMODES TO 0.
	}

	PRINT "Allow switching from RTLS to ASDS? (y/n): ". SET input TO terminal:input:getchar().
	IF input = "y" {
		SET MODESWITCH TO 1. // Allow switching from RTLS to ASDS
	} ELSE {
		SET MODESWITCH TO 0.
	}
}

// Debug? (Suppresses OUTPUT())
SET DEBUG TO 1.

// Define constants.
SET g TO 9.80665.
IF LAUNCH = 1 {
	SET h TO ALT:RADAR*0.75.
} ELSE {
	PRINT "Enter the approx height of S1 (meters): ". SET h TO terminal:input:getchar().
}

// Start MET, fuel consumption, initialise some values
SET t0ref TO TIME:SECONDS.
SET start_time TO TIME:SECONDS.
SET lf0 TO SHIP:LIQUIDFUEL.
SET initialmass TO SHIP:MASS.
SET recov_dv TO 0.
SET recov_lf TO 0.
SET tInterval TO 0.
SET BURN TO 0.
SET outputinitialisation TO TRUE.
SET propulsive_landing TO 0.
SET entryburnstart TO 0.
SET entryburnend TO 0.
SET postlanding TO 0.
SET landingburn TO 0.
SET geardeploy TO 0.
SET landed TO 0.
SET end TO 2.
SET ran TO 0.
SET recov_dv TO 0.
SET recov_lf TO 0.
SET MECO TO 0.

// Mission status
SET missionstatus TO "AWAITING LIFTOFF".

// PID-loop and control function inits
SET thrott_loop_initialised TO FALSE.
SET flightThrottleInitialised TO FALSE.
SET CONTROLINIT TO FALSE.
SET CONTROLINITIALISED TO FALSE.
SET bbinitialised TO FALSE.

// Define some target positions, choose target by commenting out the line of code after the coordinates
SET LZ1 TO LATLNG(-0.115551384009776,-74.5681799085477). //SET targeted TO LZ1. SET MODE to "RTLS".
SET LZ2 TO LATLNG(-0.0970402811341319,-74.5397113868808). SET targeted TO LZ2. SET MODE to "RTLS".
SET LPAD TO LATLNG(-0.0972030750580504,-74.5576793237724). //SET targeted TO LPAD. SET MODE to "RTLS".
SET VAB1 TO LATLNG(-0.096779141835831,-74.6173961940554). //SET targeted TO VAB1. SET MODE to "RTLS".
SET VAB2 TO LATLNG(-0.0967667872308891,-74.6200422643941). //SET targeted TO VAB2. SET MODE to "RTLS". SET h TO h + 100.
SET TRCKST TO LATLNG(-0.127201122059944,-74.605370914838). //SET targeted TO TRCKST. SET MODE to "RTLS". 
SET ASTRO TO LATLNG(-0.0925716174970505,-74.6630942590381). //SET targeted TO ASTRO. SET MODE TO "RTLS".
SET RADAR TO LATLNG(-0.122499220824709,-74.6522854766593). //SET targeted TO RADAR. SET MODE TO "RTLS". SET h TO h + 35.
SET POOL TO LATLNG(-0.0868689418624337,-74.6614596133055). //SET targeted TO POOL. SET MODE TO "RTLS".
SET TRIANGLE TO LATLNG(-0.102062495776151,-74.6512243417649). //SET targeted TO TRIANGLE. SET MODE TO "RTLS".
SET FLAGPOLE TO LATLNG(-0.0941386551432377,-74.6535134350793). //SET targeted TO FLAGPOLE. SET MODE TO "RTLS". SET h TO h + 50.
SET OCISLY TO LATLNG(-0.319454412032009,-52.1849479434307). //SET targeted TO OCISLY. SET MODE TO "ASDS".

// Set target
ADDONS:TR:SETTARGET(targeted).

// Make the stage turn quicker than default.
SET STEERINGMANAGER:MAXSTOPPINGTIME TO 8.
SET STEERINGMANAGER:PITCHPID:KD TO 1.35.
SET STEERINGMANAGER:YAWPID:KD TO 1.35.
SET STEERINGMANAGER:ROLLPID:KP TO 1.45.

// Lock throttle
SET thrott TO 0.
LOCK THROTTLE TO thrott.

// Functions
function getEngines {
	IF LAUNCH = 1 AND SHIP:AVAILABLETHRUST = 0 {
		STAGE. }

	list engines in engineList.
	set engine to engineList[0].
	SET ISP TO engine:ISP.
	IF ISP = 0 {
		SET n TO 0.
		UNTIL ISP > 0 {
			SET engine TO engineList[n].
			SET ISP TO engine:ISP.
			SET n TO n + 1.
		}
	}
}

function groundDist {
	PARAMETER POINT1.
	PARAMETER POINT2.
	RETURN (POINT1:POSITION - POINT2:POSITION):MAG.
}

function groundDir {
	PARAMETER POINT1.
	PARAMETER POINT2.
	return ARCTAN2(POINT1:LNG - POINT2:LNG, POINT1:LAT - POINT2:LAT).
}

function getaoa { // Angle of attack
	SET up_vec TO SHIP:UP:VECTOR.
	SET forw_tr_vec TO VXCL(up_vec,SHIP:VELOCITY:SURFACE).
	SET pitch_factor TO VDOT(SHIP:VELOCITY:SURFACE,UP:VECTOR)/ABS(VDOT(SHIP:VELOCITY:SURFACE,UP:VECTOR)).
	SET star_tr_vec TO VCRS(up_vec,forw_tr_vec).
	SET aoa_vec TO VXCL(star_tr_vec,SHIP:FACING:VECTOR).
	SET aoa TO ABS(VANG(aoa_vec, forw_tr_vec )*pitch_factor).
	RETURN aoa.
}

function trueMaxAcceleration {
	//SET aoa TO getaoa().
	SET initialmass TO SHIP:MASS.

	SET Isp TO engine:ISP.
	IF Isp = 0 {
		SET n TO 0.
		UNTIL Isp > 0 {
			SET engine TO engineList[n].
			SET Isp TO engine:Isp.
			SET n TO n + 1.
		}
	} 

	// All this, just so we can get a more accurate average max acceleration.
	SET mfrate TO (SHIP:AVAILABLETHRUST/(Isp)*(SHIP:BODY:MU/(SHIP:BODY:RADIUS + ALT:RADAR)^2)). // Mass flow-rate
	//SET dv1 TO SQRT(2*g*(ALT:RADAR-h)+SHIP:VERTICALSPEED^2). 
	SET t_impact TO ABS(targeted:DISTANCE/SHIP:AIRSPEED). 
	SET dv TO SHIP:AIRSPEED. // SET dv TO SHIP:GROUNDSPEED + ABS(SHIP:VERTICALSPEED) + g/t_impact.
	SET finalMass TO (initialmass*constant:e^(-dv/(ISP*(SHIP:BODY:MU/(SHIP:BODY:RADIUS + ALT:RADAR)^2)))). 
	SET burntime TO ((initialmass-finalMass)/mfrate). // Time required for above dv burn
	SET gdv TO ((SHIP:BODY:MU/(SHIP:BODY:RADIUS + ALT:RADAR)^2)*burntime). // How much gravity fucks us over
	SET trueMass TO (initialmass*constant:e^(-(dv+gdv)/(ISP*(SHIP:BODY:MU/(SHIP:BODY:RADIUS + ALT:RADAR)^2)))). 
	
	// Average maximum acceleration calculation.
	//SET a1 TO ((SHIP:AVAILABLETHRUST/SHIP:MASS)-g).
	//SET a2 TO ((SHIP:AVAILABLETHRUST/trueMass)-g).
	//SET amax TO (((a1+a2)/1.8))*SIN(aoa). // <------/ moved here

	// Land purely based on maximum acceleration
	SET a2 TO ((SHIP:AVAILABLETHRUST/trueMass)-g).
	SET amax TO a2. //*SIN(aoa).

	// Return maximum acceleration
	RETURN amax.
}

function control {
	IF EXPEND = 1 {
		RETURN.
	}

	LOCAL t0 IS TIME:SECONDS.

	IF CONTROLINIT = FALSE {
		SET dir TO -1. // Aerodynamic guidance
		LOCAL t1 IS TIME:SECONDS.
		SET CONTROLINIT TO TRUE.
	}

	// Get xOffset and yOffset
	IF ADDONS:TR:HASIMPACT {
		SET xOffset TO dir * (ADDONS:TR:IMPACTPOS:LNG - TARGETED:LNG).
		SET yOffset TO dir * (ADDONS:TR:IMPACTPOS:LAT - TARGETED:LAT).
	}

	// Preserve current offset in MEM0
	IF t0 > t1 + 0.2  AND ADDONS:TR:HASIMPACT {
		SET xOffsetMEM0 TO ABS(ADDONS:TR:IMPACTPOS:LNG - TARGETED:LNG).
	}

	// 0.2 seconds later, preserver current offset in MEM1, compare to MEM0
	IF t0 > t1 + 0.4 {
		SET xOffsetMEM1 TO ABS(ADDONS:TR:IMPACTPOS:LNG - TARGETED:LNG).
		LOCAL t1 IS TIME:SECONDS. // Reset timing

		IF MODE = "RTLS" {
			IF h > 20 {
				SET TOGGLING TO 1.5.
			} ELSE {
				SET TOGGLING TO 1.
			}
		} ELSE {
			SET TOGGLING TO 2.5.
		}
		IF TOGGLING*xOffsetMEM1 > xOffsetMEM0 AND THROTT > 0 { // Propulsive force > aerodynamic forces
			SET dir TO 1.
			SET t1 TO TIME:SECONDS + 9999. // Never update again
		}
	}

	// Set multipliers
	IF ALT:RADAR > 4000 {
		IF MODE = "RTLS" {
			SET dCoe TO 20. // 6 --> 5 --> 8 --> 10 --> 14 --> 18 in an attempt to minimise final approach sway.
		} ELSE {
			SET dCoe TO 30. // 8 --> 6 --> 8 --> 4 Dropped back to four after a substantial increase above
			}
	} ELSE {
		IF MODE = "RTLS" {
			IF ALT:RADAR > h+20 {
				SET dCoe to 2. // 2 --> 1.5
			} ELSE {
				SET dCoe TO 0.5. // 1 --> 0.75 --> 0.5 --> 1
			}
		} ELSE {
			SET dCoe TO 6. // 8
		}
	}
	
	SET corrX TO TARGETED:LNG + xOffset*dCoe.
	SET corrY TO TARGETED:LAT + yOffset*dCoe.
	SET corrPos TO LATLNG(corrY, corrX).

	SET corrVec TO -1 * corrPos:POSITION.
	SET STEER TO corrVec:DIRECTION + R(0,0,SHIP:FACING:ROLL).
	RETURN. 
}

function throttlePID {
	// Kinetics
	SET a TO (SHIP:AVAILABLETHRUST/SHIP:MASS). //*SIN(getaoa()). // Accounts for cosine losses during the burn.
	SET a_max TO a-g.
	SET t_impact TO ABS((ALT:RADAR-h)/SHIP:VERTICALSPEED).
	SET t_decel TO ABS(SHIP:VERTICALSPEED/a_max).
	SET t_decelt TO ABS(SHIP:VERTICALSPEED/(a_max*thrott)).

	// Throttle PID initialisation
	IF thrott_loop_initialised = FALSE {
		// Throttle gain 0.01, 0.001, 0.15 --> 0.03/0.02/0.02 (worked fine)
		SET throttKp TO 0.021.
		SET throttKi TO 0.06.
		SET throttKd TO 0.15. // 0.1

		SET throttPID TO PIDLOOP(throttKp, throttKi, throttKd).
		SET throttPID:MAXOUTPUT TO 0.01.
		SET throttPID:MINOUTPUT TO -0.01.

		IF MODE = "RTLS" {
			SET throttPID:SETPOINT TO -1.2. // -0.5 --> -0.8715 --> [-0.9] --> -1.4 --> -1.6 --> -1.3
		} ELSE {
			SET throttPID:SETPOINT TO -1.5.
		}

		SET throttOUT TO throttPID:UPDATE(TIME:SECONDS, (t_decel - t_decelt)).
		SET throttOUT TO throttPID:OUTPUT.
		SET thrott TO thrott + throttOUT.

		SET thrott_loop_initialised TO TRUE. }

	// Throttle PID
	SET throttOUT TO throttPID:UPDATE(TIME:SECONDS, (t_impact - t_decelt)).
	SET throttOUT TO throttPID:OUTPUT.
	SET thrott TO thrott + throttOUT.

	IF ENGINEMODES = 1 { // Toggling engine modes
		IF engine:MODE = "AllEngines" AND thrott < 0.45 AND ABS(t_impact) - ABS(t_decelt) > -1 { //0.45
			engine:TOGGLEMODE.
			WAIT 0.01.
			SET thrott TO 0.75. // So that the loop notices a change in throttle 
		} }

	RETURN.
}

function recdv { // Function calculates delta-v required for stage recovery, and returns said value in m/s
	PARAMETER recoverytarget.

	// Get free-fall time from apoapsis
	SET t_apgFF TO SQRT(2*(SHIP:APOAPSIS-15000)/g). 
	
	SET frac TO t_apgFF / 21600. // fraction of a 360 degree rotation of the planet; 1 would be 360 degrees
	SET kerbincirc TO 2 * 3.14159 * 600000. // Circ. of Kerbin
	SET arclen TO kerbincirc * frac. // How much we're going to move above ground; 14400 seconds would be 360 degrees, etc.

	// At this point, horizontal velocity = 0 and we've calculated how much we're flying back thanks to kerbin's rotation
	// Get current ground distance from Kerbin, at this exact point in time. Calculate if kerbin's spin + 0 horizontal velocity is enough

	IF recoverytarget = OCISLY AND ADDONS:TR:IMPACTPOS:LNG < OCISLY:LNG {
		SET curr_Dist TO groundDist(ADDONS:TR:IMPACTPOS, recoverytarget).
		SET flyback_dv TO (curr_dist/t_apgff).
	} ELSE {
		SET flyback_dv TO SHIP:GROUNDSPEED + (groundDist(SHIP:GEOPOSITION, recoverytarget))/t_apgff. // m/s, assuming 0 horizontal velocity
	}
	
	// Assume constant acceleration
	SET v_ff TO (SHIP:BODY:MU/(SHIP:BODY:RADIUS + ALT:RADAR)^2)*t_apgFF.
	SET rec_dv TO flyback_dv + v_ff.
	RETURN rec_dv.
}


function reclf { // Function calculates liquid fuel expended on stage recovery, returning the amount of LF required in units
	PARAMETER recoverytarget.
	SET Isp TO engine:ISP.
	IF Isp = 0 {
		SET n TO 0.
		UNTIL Isp > 0 {
			SET engine TO engineList[n].
			SET Isp TO engine:Isp.
			SET n TO n + 1.
		} }

	SET initialmass TO 0.
	FOR PART IN SHIP:PARTS {
		IF PART:STAGE = STAGE:NUMBER OR PART:STAGE = STAGE:NUMBER-1 OR PART:STAGE = STAGE:NUMBER+1 {
			SET initialmass TO initialmass + PART:MASS.
		} }

	SET mfrate TO SHIP:AVAILABLETHRUST/engine:ISP*(SHIP:BODY:MU/(SHIP:BODY:RADIUS + ALT:RADAR)^2).
	SET dv TO recdv(recoverytarget).

	SET finalMass TO initialmass*constant:e^(-dv/(engine:ISP*(SHIP:BODY:MU/(SHIP:BODY:RADIUS + ALT:RADAR)^2))).
	SET BURNtime TO (initialmass-finalMass)/mfrate.
	SET dmass TO initialmass - finalMass.

	// Liquid fuel density: 5 kg / 1 unit
	// So, from mass change, and knowing that LF/OX runs at a ratio of 9/11, we can get the LF expenditure
	SET dlfmass TO 9/20*dmass. // 9 + 11 = 20 
	SET dlf TO dlfmass/5.

	RETURN dlf*1000. // dlf in tons? Who knows, but seems about right.
}

function launch {
	// Calculate orbital dv
	SET r TO AP + 600000. // Radius of kerbin + apoapsis + altitude
	SET Mkerbin TO 5.2915158*10^22. // kg
	SET const_G TO 6.674 * 10^(-11).
	SET sma TO r + AP. // Circular orbit; sma = R + (AP+PA)/2
	SET dvAP TO SQRT(const_G * Mkerbin *(2/r - 1/sma)). // Calculate dv from vis-viva equation

	// Lock steering
	SET steer TO SHIP:UP + R(0,0,270).
	LOCK STEERING TO steer.

	// LAUNCH
	CLEARSCREEN.
	SET voffset TO 0.
	IF S2GUIDANCE = 1 {
		PRINT "INITIALISING CONNECTION WITH S2".
		S2connect().
	}

	WAIT 1.
	PRINT "PROCEEDING WITH LAUNCH SEQUENCE".
	PRINT "STARTING TERMINAL COUNT".

	SET countdown TO 5.
	UNTIL countdown < 0 {
		PRINT countdown.
		WAIT 1.
		SET countdown TO countdown - 1.
	}

	PRINT "IGNITION".
	SET thrott TO 100.
	WAIT 1.5.
	STAGE.
	PRINT "LIFTOFF".
	RCS ON.

	SET missionstatus TO "FLYING".
	//LOCK updir TO SHIP:UP + R(0,0,90).
	//SET steer TO updir.

	SET STEER TO HEADING(INCL,90).

	SET t0 TO TIME:SECONDS.
	SET t1 TO TIME:SECONDS + 2.

	UNTIL ALT:RADAR > 200 {
		SET t0 TO TIME:SECONDS.

		IF t0 > t1 + 2 {
			OUTPUT().
			SET t1 TO TIME:SECONDS.
		}
	}

	CLEARSCREEN.

	UNTIL ALT:RADAR > 600 {
		SET STEER TO HEADING(INCL,87). // 87

		SET t0 TO TIME:SECONDS.
		IF t0 > t1 + 2 {
			OUTPUT().
			SET t1 TO TIME:SECONDS.
		}
	}

	UNTIL ALT:RADAR > 1000 {
		SET STEER TO HEADING(INCL,84). // 85

		SET t0 TO TIME:SECONDS.
		IF t0 > t1 + 2 {
			OUTPUT().
			SET t1 TO TIME:SECONDS.
		}
	}

	RCS OFF.
	UNTIL SHIP:VERTICALSPEED > 200 {
		SET STEER TO HEADING(INCL,83). // 84 (354 good for RTLS, 352 for ASDS)

		SET t0 TO TIME:SECONDS.
		IF t0 > t1 + 2 {
			OUTPUT().
			SET t1 TO TIME:SECONDS.
		}
	}

	UNTIL SHIP:APOAPSIS > AP OR MECO = 1 {
		SET steer TO SHIP:SRFPROGRADE. // Start gravity turn

		SET t0 TO TIME:SECONDS.
		IF t0 > t1 + 2 {
			OUTPUT().
			SET t1 TO TIME:SECONDS.
		}

		IF ALT:RADAR > 15000 {
			SET recov_lf TO reclf(LZ1).
			SET asdsrecov_lf TO reclf(OCISLY).
			IF EXPEND = 0 {
				IF (recov_lf*(5/9))*0.9 > STAGE:LIQUIDFUEL { // 1.25
					//SET MECO TO 1. // IF RTLS ONLY
					IF asdsrecov_lf < recov_lf AND MODESWITCH = 1 {
						SET MECO TO 0.
						SET targeted TO OCISLY. SET MODE TO "ASDS".
					} ELSE {
						SET MECO TO 1.
					}
				}
			} ELSE {
				IF STAGE:LIQUIDFUEL < 50 {
					SET thrott TO 0.
					SET MECO TO 1.
				}
			}
		}
	}

	RCS ON.
	SET thrott TO 0.
	engine:SHUTDOWN.
	WAIT 1.

	SAS ON.
	WAIT 0.5.
	SET thrott TO 0.01.
	WAIT 0.05.
	STAGE.
	SAS OFF.
	SET thrott TO 0.

	CLEARSCREEN.
	IF S2GUIDANCE = 1 {
		MECOconnect().
	}

	WAIT 1.

	// Re-get engines
	engine:ACTIVATE.
	WAIT 1.
	getEngines().
	WAIT 3.
}

function run_boostback { // Calculates optimal boostback direction (ASDS/RTLS) and runs it
	SET missionstatus TO "PERFORMING BOOSTBACK".
	IF EXPEND = 1 {
		RETURN. }

	// Target acq.
	LOCK targetDist TO groundDist(targeted, ADDONS:TR:IMPACTPOS).
	LOCK targetDir TO groundDir(ADDONS:TR:IMPACTPOS, targeted).

	// Pointing towards target
	SET steeringDir TO targetDir - 180. // Points towards target
	SET steeringPitch to 0. // Boostback, so pitch = 0 for optimal burn.
	SET steer TO HEADING(steeringDir, steeringPitch).
	LOCK STEERING TO steer.

	// Start the engine in single-engine mode for flip
	IF ENGINEMODES = 1 {
		IF engine:MODE = "AllEngines" {
			engine:TOGGLEMODE.
			WAIT 0.01.
		} }

	SET thrott TO 0.2. // 0.1

	IF MODE = "RTLS" {
		SET bbangle TO 6.5. // 5 --> 6.5 --> 6
	} ELSE {
		SET bbangle TO 1.5. }

	// Orient vehicle for boostback
	until VANG(HEADING(steeringDir,steeringPitch):VECTOR, SHIP:FACING:VECTOR) < bbangle { // 0.05 --> 0.25 --> 2.5 --> 3.5
		SET steer TO HEADING(steeringDir, steeringPitch). }

	// All engines for the burn
	IF ENGINEMODES = 1 AND groundDist(targeted, ADDONS:TR:IMPACTPOS()) > 10000 {
		IF engine:MODE = "CenterOnly" {
			engine:TOGGLEMODE.
			WAIT 0.01.
		} }

	// Ground distance between target and impact position
	SET dist TO groundDist(targeted, ADDONS:TR:IMPACTPOS()).
	SET dist0 TO dist.
	SET distDelta TO -1. // dist should always be smaller than dist0, which is the original value.

	IF dist > 10000 { // 10000
		SET thrott TO 1.
	} ELSE {
		SET thrott TO 0.1. // 0.2 
	}

	IF ENGINEMODES = 1 {
		IF engine:MODE = "AllEngines" {
			WHEN dist < 2500 THEN {
				ENGINE:TOGGLEMODE.
				WAIT 0.01.
				SET thrott TO 0.1. // 0.05 --> 0.025
			} } }

	SET bbt0 TO TIME:SECONDS.
	UNTIL dist < 50 OR distDelta > 0 {
		IF TIME:SECONDS - bbt0 > 0.22 { // Update dist0 every 0.15/0.2/0.22 seconds, lower values seem to not work.
			SET bbt0 TO TIME:SECONDS.
			SET dist0 TO dist + 10. }

		LOCK targetDist TO groundDist(targeted, ADDONS:TR:IMPACTPOS).
		LOCK targetDir TO groundDir(ADDONS:TR:IMPACTPOS, targeted).

		IF targetDist < 5000 {
			SET thrott TO 0.075. }

		// Calculate angle between impact position and target, if we are starting to get close
		IF dist < 10000 AND MODE = "RTLS" {
			SET xOffset TO (ADDONS:TR:IMPACTPOS:LNG - TARGETED:LNG).	
			SET yOffset TO (ADDONS:TR:IMPACTPOS:LAT - TARGETED:LAT).
			SET ALPHA TO ABS(ARCTAN(yOffset/xOffset)).
		}

		IF dist < 10000 AND dist > 2000 AND MODE = "RTLS" {
			SET steeringDir TO targetDir - (180+(ALPHA/2)). // Points towards target; (directly towards) - alpha
		} ELSE {
			SET steeringDir TO targetDir - 180. } 

		SET steeringPitch to 0. // Boostback, so pitch = 0 for optimal burn.
		SET steer TO HEADING(steeringDir, steeringPitch).

		SET dist TO groundDist(targeted, ADDONS:TR:IMPACTPOS()).
		SET distDelta TO dist - dist0. }

	// Boostback performed, exit function
	SET thrott TO 0.
	IF ENGINEMODES = 1 {
		ENGINE:TOGGLEMODE.
	}

	WAIT 2.
}

function entryBurn {
	IF ENGINEMODES = 1 {
		IF engine:mode = "CenterOnly" {
		engine:TOGGLEMODE.
		WAIT 0.01. // So that the program doesn't go nuts over missing thrust.
		}
	}
		
	SET steer TO ADDONS:TR:CORRECTEDVEC.
	SET entryburnstart TO 1.
	SET missionstatus TO "ENTRY BURN".
	OUTPUT().

	SET v0 TO ABS(SHIP:VERTICALSPEED).
	UNTIL v0-ABS(SHIP:VERTICALSPEED) > 250 { // 250 originally
		SET thrott TO 1.0.
		control().
	}

	SET thrott TO 0.
	SET entryburnend TO 1.
	OUTPUT().

	SET initialmass TO SHIP:MASS.
}

function S2connect {
	SET S1 TO PROCESSOR("S1").
	SET S2 TO PROCESSOR("S2").

	SET S2connection TO S2:CONNECTION.

	PRINT " ".
	PRINT "TESTING CONNECTION...".
	IF S2connection:ISCONNECTED {
		PRINT "CONNECTION ESHABLISHED!".
		PRINT "CONNECTION DELAY: " + S2connection:DELAY + " s".
	} ELSE {
		PRINT "CONNECTION FAILURE!".
	}

	PRINT " ".
	RETURN.
}

function MECOconnect {
	CLEARSCREEN.
	PRINT "RE-ESTABLISHING CONNECTION WITH S2...".
	SET S2name TO VESSEL(SHIP:NAME + " Relay").
	SET S2connection TO S2name:CONNECTION.

	PRINT " ".
	PRINT "TESTING CONNECTION...".
	IF S2connection:ISCONNECTED {
		PRINT "CONNECTION ESHABLISHED!".
		PRINT "CONNECTION DELAY: " + S2connection:DELAY + " s".
	} ELSE {
		PRINT "CONNECTION FAILURE!".
	}

	PRINT " ".

	// Telling S2 we've had MECO, giving orbital parameters
	S2connection:SENDMESSAGE("MECO").
	S2connection:SENDMESSAGE(AP).
	S2connection:SENDMESSAGE(ECC).
	S2connection:SENDMESSAGE(INCL).

	OUTPUT().
}

function targetOvershoot {
	IF MODE = "RTLS" {
		SET overshoot TO (ABS(SHIP:GROUNDSPEED*ABS(SHIP:AIRSPEED/trueMaxAcceleration())*cos(getaoa()))/(2*3.14159*600000))*360/8.25. 
		SET targeted TO LATLNG(target0:LAT, target0:LNG - overshoot). // - for RTLS overshoot, + for ASDS
	} ELSE {
		SET overshoot TO (ABS(SHIP:GROUNDSPEED*ABS(SHIP:AIRSPEED/trueMaxAcceleration())*cos(getaoa()))/(2*3.14159*600000))*360/4. 
		SET targeted TO LATLNG(target0:LAT, target0:LNG + overshoot). // 
	}
}

function output {
	IF DEBUG = 1 {
		RETURN.
	}

	SET vesselq TO SHIP:DYNAMICPRESSURE.
	SET twr TO SHIP:AVAILABLETHRUST/(SHIP:MASS*9.81).
	SET amax TO ((SHIP:AVAILABLETHRUST/SHIP:MASS)-9.81).
	SET lf1 TO SHIP:LIQUIDFUEL.
	IF outputinitialisation = TRUE {
		CLEARSCREEN.
		SET outputinitialisation TO FALSE.
		PRINT ".------------------------------------------------.".
		PRINT "|ASTERIA v1.32                                    ".
		PRINT "|LAUNCH AND RECOVERY GUIDANCE                     ".
		PRINT "|---------------- MISSION STATUS ----------------.".
		PRINT "|MET: " + round(TIME:SECONDS-t0ref,0) + " s".
		PRINT "|STATUS: " + missionstatus.
		PRINT "|RECOVERY: " + MODE.
		PRINT "|---------------- VEHICLE STATUS ---------------.".
		PRINT "|ALTITUDE: " + round(ALT:RADAR/1000,1) + " km".
		PRINT "|VELOCITY: " + round(SHIP:AIRSPEED,1) + " m/s".
		PRINT "|APOAPSIS: " + round(SHIP:APOAPSIS/1000,2) + " km".
		PRINT "|TWR: " + round(twr,2).
		PRINT "|Q: " + round(vesselq,2) + " atm".

		IF addons:tr:hasimpact AND ALT:RADAR > 17000 {
			PRINT "|------------------ RECOVERY -------------------.".
			PRINT "|RTLS DELTA-V (m/s): " + round(recdv(LZ1),0).
			PRINT "|ASDS DELTA-V (m/s): " + round(recdv(OCISLY),0).
		} 

		IF CONTROLINITIALISED = TRUE {
			PRINT "|------------------- ATTITUDE -------------------.".
			PRINT "|>x-offset: " + xOffset.
			PRINT "|>y-offset: " + yOffset.
		} 
		
		IF thrott_loop_initialised = TRUE {
			PRINT "|------------------- THROTTLE -------------------.".
			PRINT "|Throttle (%): " + round(thrott*100,2).
			PRINT "|throttOUT: " + throttOUT.
			PRINT "|tDiff: " + round((ABS(t_impact) - ABS(t_decelt)),4).
			PRINT "|v_vertical (m/s): " + round(SHIP:VERTICALSPEED,1).
		}

		PRINT "|---------------- MISSION EVENTS ----------------.".
		IF entryburnstart = 1 { PRINT "> ENTRY BURN STARTUP.". }
		IF entryburnend = 1 { PRINT "> ENTRY BURN SHUTDOWN.". }
		IF landingBURN = 1 { PRINT "> LANDING BURN STARTUP.". }
		IF geardeploy = 1 { PRINT "> LANDING GEARS HAVE DEPLOYED.". }
		IF landed = 1 { PRINT "> STAGE ONE HAS LANDED.". }
		IF postlanding = 1 {
			SET lf1 TO STAGE:LIQUIDFUEL.
			PRINT "|------------------------------------------------.".
			PRINT "|Fuel used for recovery: " + round(lf2-lf1,1) + " units.".
			PRINT "|Fuel left in tanks: " + round(lf1,1) + " units.".
			PRINT "|% used: " + round(((lf2-lf1)/lf2)*100,2).
		}
		SET t1output TO TIME:SECONDS.
	} ELSE {
		// Updates values instead of whole display to avoid stutter
		// AT (COLUMN, ROW)
		PRINT round(TIME:SECONDS-t0ref,0) + " s" AT (6,4).
		PRINT missionstatus AT (9,5).
		PRINT MODE AT (11,6).

		PRINT round(ALT:RADAR/1000,1) + " km" AT (11,8).
		PRINT round(SHIP:AIRSPEED,1) + " m/s" AT (11,9).
		PRINT round(SHIP:APOAPSIS/1000,2) + " km" AT (11,10).
		PRINT round(twr,2) AT (6,11).
		PRINT round(vesselq,2) + " atm" AT (4,12).

		SET t0output TO TIME:SECONDS.
		IF t0output > t1output + 10 {
			SET outputinitialisation TO TRUE.
		}
	}

	RETURN.
}

// Initialise vehicle, launch
getEngines().
IF LAUNCH = 1 {
	launch().
}

// Post-launch
SET lf2 TO STAGE:LIQUIDFUEL.
BRAKES ON.
RCS ON.
SAS OFF.

// Exit if expending
IF EXPEND = 1 {
	CLEARSCREEN.
	PRINT "EXPENDABLE MODE - GOODBYE STAGE ONE.".
	WAIT 4.
	SET BOOSTBACK TO 0.
	SET MODE TO "EXPEND".
}

// Overshoot target
IF MODE = "ASDS" {
	SET target0 TO targeted.
	targetOvershoot().
}

IF BOOSTBACK = 1 {
	OUTPUT().
	run_boostback().
}

RCS ON.
SET initialmass TO SHIP:MASS.
SET steer TO ADDONS:TR:CORRECTEDVEC. LOCK STEERING TO steer.
SET thrott TO 0. LOCK THROTTLE TO thrott.

// Get engines again
CLEARSCREEN.
getEngines().
OUTPUT().

SET STEERINGMANAGER:PITCHPID:KD TO 1.4. // 1.35 --> 1.25 --> 1.55
SET STEERINGMANAGER:YAWPID:KD TO 1.4. // 1.35
SET STEERINGMANAGER:MAXSTOPPINGTIME TO 11.
SET STEERINGMANAGER:YAWPID:KP TO 1.9.
SET STEERINGMANAGER:PITCHPID:KP TO 1.9.

SET t0 TO TIME:SECONDS.
SET t1 TO TIME:SECONDS + 2.
SET missionstatus TO "STAGE 1 COAST".
IF MODE = "RTLS" {
	UNTIL ALT:RADAR < 65000 AND SHIP:VERTICALSPEED < 0 { // 26500
		SET t0 TO TIME:SECONDS.
		SET steer TO ADDONS:TR:CORRECTEDVEC.

		IF t0 > t1 + 2 {
			SET tInterval TO TIME:SECONDS.
			OUTPUT().
			SET t1 TO TIME:SECONDS.
		}
	}
} ELSE {
	UNTIL ALT:RADAR < 65000 {
		SET t0 TO TIME:SECONDS.
		SET steer TO SHIP:SRFRETROGRADE.

		IF t0 > t1 + 2 {
			SET tInterval TO TIME:SECONDS.
			OUTPUT().
			SET t1 TO TIME:SECONDS.
		}
	}
}


// 8/2.2/2.2 for first landing.
SET STEERINGMANAGER:MAXSTOPPINGTIME TO 12. // 4 --> 5
SET STEERINGMANAGER:PITCHPID:KD TO 1.1.
SET STEERINGMANAGER:YAWPID:KD TO 1.1.
SET STEERINGMANAGER:PITCHPID:KP TO 2.4.
SET STEERINGMANAGER:YAWPID:KP TO 2.4.

IF CONTROLINITIALISED = FALSE {
	SET CONTROLINITIALISED TO TRUE.
}

SET missionstatus TO "GUIDING TOWARDS LANDING SITE".
SET entryaoa TO getaoa().
SET tInterval TO TIME:SECONDS.
SET t0 TO TIME:SECONDS.
SET t1 TO t0 + 2.
SET t2 TO t0 + 10.

WHEN ALT:RADAR < 65000 THEN {
	SET STEERINGMANAGER:PITCHPID:KD TO 1.4. // 1.35 --> 1.25 --> 1.55
	SET STEERINGMANAGER:YAWPID:KD TO 1.4. // 1.35
	SET STEERINGMANAGER:MAXSTOPPINGTIME TO 11.
	SET STEERINGMANAGER:YAWPID:KP TO 1.95. // 1.9
	SET STEERINGMANAGER:PITCHPID:KP TO 1.95. // 1.9
}

WHEN ALT:RADAR < h+45 THEN { // 70 --> 50 --> 70 --> 100 --> 120
	SET throttPID:SETPOINT TO -0.6. // --> -0.9 --> -1.0 --> -0.85
	SET thrott TO thrott + 0.1.
} 

IF MODE = "ASDS" {
	WHEN ALT:RADAR < 3500 THEN {
		SET targeted TO target0.
	}
} ELSE {
	SET target0 TO targeted.
	targetOvershoot().
}

SET v_peak TO ABS(SHIP:VERTICALSPEED).
UNTIL BURN = 1 OR EXPEND = 1 {
	// Store peak velocity for drag approximation
	IF ABS(SHIP:VERTICALSPEED) > v_peak {
		SET v_peak TO ABS(SHIP:VERTICALSPEED).
	}

	// Time for console refresh
	SET t0 TO TIME:SECONDS.

	// Burn start calculation
	SET a_max TO trueMaxAcceleration().
	SET t_impact TO ABS(targeted:DISTANCE/SHIP:AIRSPEED).
	SET t_decel TO ABS(SHIP:AIRSPEED/a_max).

	// Conditional to start the burn
	IF SHIP:VERTICALSPEED < 0 {
		IF 2*t_impact - t_decel < -0.1 AND ALT:RADAR < 15000 { // Add time to t_decel if need more room for error
			SET BURN TO 1.
			SET missionstatus TO "LANDING BURN".
			OUTPUT().
		}
	} 

	// Control
	control().

	// Entry burn - performed if Q goes above threshold.
	IF ALT:RADAR > 22000 AND SHIP:DYNAMICPRESSURE > 0.3 AND mode = "RTLS" { // Q changed from 0.35 to 0.275.
		entryBurn(). }

	IF ALT:RADAR > 15000 AND ALT:RADAR < 10000 {
		SET approxlf TO reclf(TARGETED).
		SET landinglf0 TO STAGE:LIQUIDFUEL. }


	// Refresh console every 3 seconds
	IF t0 > t1 + 3 {
		// Get loop time
		SET t1 TO TIME:SECONDS.
		SET tInterval TO TIME:SECONDS.
		IF DEBUG = 0 {
			OUTPUT().
		}

		LOG t_impact TO impactlog.txt.
		LOG t_decel TO decellog.txt.
	}
}


// Gear deployment
WHEN (ALT:RADAR < 400) AND (GEAR = FALSE) THEN { 
	GEAR ON.
	SET geardeploy TO 1.
	OUTPUT().
	PRESERVE.
}

SET targeted TO target0.
SET t0 TO TIME:SECONDS.
SET t1 TO t0 + 2.
SET thrott TO 1. // Manual engine startup
UNTIL SHIP:STATUS = "LANDED" OR EXPEND = 1 {
	// Time for prints
	SET t0 TO TIME:SECONDS.

	// Control functions if not landed
	IF ADDONS:TR:HASIMPACT {
		control().
	}

	// Throttle control
	throttlePID().

	// Refresh console every 2 seconds
	IF t0 > t1 + 2 {
		SET tInterval TO TIME:SECONDS.
		SET t1 TO TIME:SECONDS.
		IF DEBUG = 0 {
			OUTPUT().
		}
	}
}

// If we've touched down, do post-landing operations.
IF SHIP:STATUS = "LANDED" OR SHIP:VERTICALSPEED >= 0 {
	RCS ON.
	SAS ON.
	SET missionstatus TO "LANDED".

	SET thrott TO 0.
	FOR engine IN engineList {
		engine:SHUTDOWN. }

	SET landed TO 1.
	BRAKES OFF.

	WAIT 4.
	OUTPUT().

	SET postlanding TO 1.
	OUTPUT().

	PRINT ".------------------------------------------------.".
	PRINT "Thank you for flying with Asteria!".
	PRINT "Exiting program.".
}

// End of file.
