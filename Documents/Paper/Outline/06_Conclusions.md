## 6. Conclusions

**[6.1]** An assist map gives the intended steering effort only near the road and driving conditions it was built for.
**[6.2]** MapPID keeps that map and its lead–lag compensator unchanged and adds a PID branch in parallel, and the simulations of this study support the following
conclusions.

- **[6.3]** The branch corrects the torque error with respect to a target set by speed and lateral acceleration, so it needs no estimate of road friction. Only its four parameters are tuned
  for each vehicle.
- **[6.4]** Map left a holding bias of up to +32.3% at the strongest dry-road levels and −13.9% at $\mu=0.24$, while MapPID held it within 0.43%, as expected from integral action while the
  loop remains stable and the assist command stays below its limit.
- **[6.5]** Over each complete test, MapPID lowered the RMS tracking error of Map by factors of 4.24, 3.51 and 6.54 in STEADY, SLIP and WEAVE, at the price of a larger fast component in the
  assist torque.
- **[6.6]** Compared with PID, MapPID tracked about equally well in STEADY, with a small gain in SLIP and a 10.9% higher RMS error in WEAVE.
- **[6.7]** Its assist-torque residual was 8.9% smaller in STEADY and 15.1% lower in WEAVE, with no clear difference in SLIP. This residual also contains the response to rapid steering, so
  it is not a direct measure of steering comfort.
- **[6.8]** The evidence covers one simulated vehicle with a prescribed steering-wheel angle and five sensor-noise seeds. Tests with a driver in the loop, with parameter variations and on
  hardware are still needed.
- **[6.9]** Further analysis should separate the contributions of the two branches during fast reversals, to explain why MapPID tracked less closely than PID there.
