/*
 * TirePacejka.c
 * -----------------
 * Block 2: Nonlinear Tire Interaction Dynamics - Pacejka Magic Formula
 * (thesis section 3.3).
 *
 * Purely algebraic block: no continuous state, the outputs are computed
 * directly from the current inputs every step (no BlockDerivatives needed).
 * This file only holds the port/param configuration and the physics
 * equations; all Simulink-facing plumbing lives in "SFunctionSetup.h",
 * included at the bottom.
 */

#define S_FUNCTION_NAME  TirePacejka
#define S_FUNCTION_LEVEL 2

/* Params: [r_p, l_am, l_f, Bf, Cf, Df, Ef, K_torque_ratio] */
#define N_PARAMS  8
/* Inputs: [theta, beta, gamma, v, mu] */
#define N_INPUTS  5
/* Outputs: [Fyf, Tr] */
#define N_OUTPUTS 2
/* No N_STATES: this block has no ODE, see thesis section 3.3 */

enum { P_RP, P_LAM, P_LF, P_BF, P_CF, P_DF, P_EF, P_KTORQUE_RATIO };
enum { IN_THETA, IN_BETA, IN_GAMMA, IN_V, IN_MU };
enum { OUT_FYF, OUT_TR };

#include <math.h>

/*
 * Fyf, Tr = f(theta, beta, gamma, v, mu) - every input is used directly here,
 * so the default INPUT_FEEDTHROUGH (all 1) from SFunctionSetup.h is already
 * correct; no override needed.
 */
void BlockOutputs(const double *params, const double *states, const double *inputs, double *outputs) {
    double r_p            = params[P_RP];
    double l_am           = params[P_LAM];
    double l_f            = params[P_LF];
    double Bf             = params[P_BF];
    double Cf             = params[P_CF];
    double Df             = params[P_DF];
    double Ef             = params[P_EF];
    double K_torque_ratio = params[P_KTORQUE_RATIO];

    double theta = inputs[IN_THETA];
    double beta  = inputs[IN_BETA];
    double gamma = inputs[IN_GAMMA];
    double v     = inputs[IN_V];
    double mu    = inputs[IN_MU];

    double delta_f, alpha_f, Bf_af, Fyf, Tr;

    /* Front wheel steer angle, geared down from the rigid steering shaft angle */
    delta_f = (r_p / l_am) * theta;

    /* Front tire slip angle (assumes v is the constant forward speed for this maneuver) */
    alpha_f = delta_f - beta - (l_f * gamma) / v;

    /* Pacejka Magic Formula: nonlinear lateral tire force, scaled by the
     * road friction coefficient mu (mu ~= 1.0 on dry road, mu <= 0.2 on ice) */
    Bf_af = Bf * alpha_f;
    Fyf = mu * Df * sin(Cf * atan(Bf_af - Ef * (Bf_af - atan(Bf_af))));

    /* Road feedback torque fed back to the steering column (T_r input of Block 1) */
    Tr = K_torque_ratio * Fyf;

    outputs[OUT_FYF] = Fyf;
    outputs[OUT_TR]  = Tr;
}

#include "SFunctionSetup.h"
