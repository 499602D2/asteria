# Asteria
Asteria — kOS launch and landing guidance for Kerbal Space Program

### What is this?
Asteria is a kOS script capable of launching a two-staged craft to any specified orbit and recovering the first stage via RTLS or a downrange ASDS landing. The script performs a suicide burn, minimising fuel use and thus maximizing available delta-v.

### Quickstart
Your craft must have the following specifications:
- Grid fins and landing legs on S1 (don't use airbrakes - if you don't have grid fins, use regular fins)
- A kOS terminal on both S1 and S2
- This staging order: S1 engines -> launch clamps -> S2 sep + S2 engines

An example Falcon 9 craft file is provided - this craft requires the following mods:
- Tundra Exploration
- Kerbal Reusability Expansion

You _must_ have the following mods installed:
- Trajectories
- kOS

### Running
- Place the s1gnc and s2gnc files into /Ships/Script in your KSP installation folder.
- Open the Trajectories mod's menu and set entry to retrograde
- Open the kOS terminals for both S1 and S2. Type `switch to 0. run s1gnc.` in the S1 terminal, and `switch to 0. run s2gnc.` in the S2 terminal.
- Enter the run parameters into the terminal as the program asks for them, by simply typing the response and hitting enter afterwards. To cancel the execution, press ctrl+c.

### Common errors and fixes
- _S1 crashes into S2:_ add a kOS terminal to S2 and run the s2gnc.ks program in it. Also set S2 guidance to enabled.
- _Stage doesn't seem to control itself for landing:_ add regular steerable fins or grid fins.
- _Stage crashes into the ground:_ lower the aggressiveness. 
