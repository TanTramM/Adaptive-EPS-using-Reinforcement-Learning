/*
 * TirePacejka.c
 * -----------------
 * Block 2: Nonlinear Tire Interaction Dynamics - Pacejka Magic Formula
 * (thesis Block 2, eq. 13-24).
 *
 * Purely algebraic block: no continuous state, the outputs are computed
 * directly from the current inputs every step (no BlockDerivatives needed).
 * This file only holds the port/param configuration and the physics
 * equations; all Simulink-facing plumbing lives in "SFunctionSetup.h",
 * included at the bottom.
 */

#define S_FUNCTION_NAME  TirePacejka
#define S_FUNCTION_LEVEL 2

/* Params: [r_p, l_am, l_f, C_alpha_f, Cf, F_zf, Ef, K_torque_ratio] */
#define N_PARAMS  8
/* Inputs: [theta, beta, gamma, v, mu] */
#define N_INPUTS  5
/* Outputs: [Fyf, Tr] */
#define N_OUTPUTS 2
/* No N_STATES: this block has no ODE, only algebraic equations */

enum { P_RP, P_LAM, P_LF, P_C_ALPHA_F, P_CF, P_FZF, P_EF, P_KTORQUE_RATIO };
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
    double C_alpha_f      = params[P_C_ALPHA_F];
    double Cf             = params[P_CF];
    double F_zf           = params[P_FZF];
    double Ef             = params[P_EF];
    double K_torque_ratio = params[P_KTORQUE_RATIO];

    double theta = inputs[IN_THETA];
    double beta  = inputs[IN_BETA];
    double gamma = inputs[IN_GAMMA];
    double v     = inputs[IN_V];
    double mu    = inputs[IN_MU];

    double delta_f, alpha_f, Df, Bf, Bf_af, Fyf, Tr;

    /* Front wheel steer angle, geared down from the rigid steering shaft angle (eq. 8) */
    delta_f = (r_p / l_am) * theta;

    /* Front tire slip angle (eq. 14/15); v is the constant forward speed */
    alpha_f = delta_f - beta - (l_f * gamma) / v;

    /* Pacejka peak factor (eq. 18) and stiffness factor (eq. 19), both recomputed
     * every step because mu is a live input (road condition can change
     * mid-simulation), not a fixed parameter. C_alpha_f (the tire's own cornering
     * stiffness) stays constant - only the peak D_f moves with mu, so the tire
     * keeps its normal initial slope and just saturates sooner/lower on a
     * slippery road. */
    Df = mu * F_zf;
    Bf = C_alpha_f / (Cf * Df);

    /* Pacejka Magic Formula: nonlinear lateral tire force, per wheel (eq. 17/23) */
    Bf_af = Bf * alpha_f;
    Fyf = Df * sin(Cf * atan(Bf_af - Ef * (Bf_af - atan(Bf_af))));

    /* Road feedback torque fed back to the steering column, T_r input of Block 1.
     * K_torque_ratio (eq. 22) already carries a factor 2 for both front wheels,
     * so it consumes the PER-WHEEL Fyf computed above (eq. 24). */
    Tr = K_torque_ratio * Fyf;

    outputs[OUT_FYF] = Fyf;
    outputs[OUT_TR]  = Tr;
}

#include "SFunctionSetup.h"
