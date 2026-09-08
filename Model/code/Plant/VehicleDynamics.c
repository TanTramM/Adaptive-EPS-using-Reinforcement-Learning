/*
 * VehicleDynamics.c
 * -----------------
 * Block 3: Lateral Vehicle Dynamics - Bicycle 2-DOF model (thesis section 3.4).
 * This file only holds the port/param/state configuration and the physics
 * equations. All the Simulink-facing plumbing (mdlInitializeSizes, mdlOutputs,
 * mdlDerivatives, ...) lives in "SFunctionSetup.h", included at the bottom.
 */

#define S_FUNCTION_NAME  VehicleDynamics
#define S_FUNCTION_LEVEL 2

/* Params: [m, l_f, l_r, C_r, I_z] */
#define N_PARAMS  5
/* States: [beta, gamma] */
#define N_STATES  2
/* Inputs: [Fyf, v] */
#define N_INPUTS  2
/* Outputs: [beta, gamma] */
#define N_OUTPUTS 2

/* Both outputs are read directly from the states (see BlockOutputs below) -
 * neither Fyf nor v is used there, only in BlockDerivatives. Marking both as
 * non-feedthrough keeps this block from being treated as an algebraic link
 * back to TirePacejka (whose Fyf output depends on beta/gamma). */
#define INPUT_FEEDTHROUGH {0, 0}

enum { P_M, P_LF, P_LR, P_CR, P_IZ };
enum { ST_BETA, ST_GAMMA };
enum { IN_FYF, IN_V };
enum { OUT_BETA, OUT_GAMMA };

/* y = [beta, gamma] - straight passthrough of the states */
void BlockOutputs(const double *params, const double *states, const double *inputs, double *outputs) {
    outputs[OUT_BETA]  = states[ST_BETA];
    outputs[OUT_GAMMA] = states[ST_GAMMA];
}

/*
 * beta_dot  = (Fyf + Fyr) / (m*v) - gamma
 * gamma_dot = (l_f*Fyf - l_r*Fyr) / I_z
 * Fyr       = C_r * alpha_r
 * alpha_r   = -beta + l_r*gamma/v
 */
void BlockDerivatives(const double *params, const double *states, const double *inputs, double *derivatives) {
    double m   = params[P_M];
    double l_f = params[P_LF];
    double l_r = params[P_LR];
    double C_r = params[P_CR];
    double I_z = params[P_IZ];

    double beta  = states[ST_BETA];
    double gamma = states[ST_GAMMA];

    double Fyf = inputs[IN_FYF];
    double v   = inputs[IN_V];

    double alpha_r, Fyr;

    /* Rear tire slip angle (linear tire model: no direct steering input at the rear) */
    alpha_r = -beta + (l_r * gamma) / v;

    /* Rear lateral tire force */
    Fyr = C_r * alpha_r;

    derivatives[ST_BETA]  = (Fyf + Fyr) / (m * v) - gamma;
    derivatives[ST_GAMMA] = (l_f * Fyf - l_r * Fyr) / I_z;
}

#include "SFunctionSetup.h"
