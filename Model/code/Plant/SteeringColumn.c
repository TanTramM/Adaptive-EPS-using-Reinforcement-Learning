/*
 * SteeringColumn.c
 * -----------------
 * Block 1: Rigid Steering Dynamics (thesis section 3.2).
 * This file ONLY holds the port/param/state configuration and the physics
 * equations. All the Simulink-facing plumbing (mdlInitializeSizes, mdlOutputs,
 * mdlDerivatives, ...) lives in "SFunctionSetup.h", included at the bottom.
 */

#define S_FUNCTION_NAME  SteeringColumn
#define S_FUNCTION_LEVEL 2

/* Params: [J_total, B_total, Tf_total] - read once at init, not per step */
#define N_PARAMS  3
/* States: [theta, theta_dot] */
#define N_STATES  2
/* Inputs: [T_d, T_a, T_r] */
#define N_INPUTS  3
/* Outputs: [theta, theta_dot, T_s] */
#define N_OUTPUTS 3

/* Only T_d feeds through to the outputs (T_s = T_d); T_a and T_r are only
 * used in BlockDerivatives, not BlockOutputs. Marking them as non-feedthrough
 * prevents Simulink from reporting a false algebraic loop when T_a comes
 * back from a Controller that itself depends on this block's T_s output. */
#define INPUT_FEEDTHROUGH {1, 0, 0}

enum { P_J_TOTAL, P_B_TOTAL, P_TF_TOTAL };
enum { ST_THETA, ST_THETA_DOT };
enum { IN_TD, IN_TA, IN_TR };
enum { OUT_THETA, OUT_THETA_DOT, OUT_TS };

#include <math.h>

/* Coulomb dry friction: opposes the direction of motion.
 * A hard sign() is discontinuous at theta_dot = 0, which makes a continuous
 * variable-step solver chatter (repeatedly halve its step) trying to resolve
 * the jump exactly, stalling the simulation near t = 0 (theta_dot(0) = 0).
 * tanh() gives a smooth approximation: it saturates to +-1 for |val| >> eps,
 * so the physics is essentially unchanged away from zero velocity, but the
 * transition through zero is continuous and solver-friendly. */
static double sign(double val) {
    const double eps = 1e-3; /* rad/s, smoothing width around zero velocity */
    return tanh(val / eps);
}

/* y = [theta, theta_dot, T_s = T_d] (rigid shaft assumption, see Block 1 - section 3.2) */
void BlockOutputs(const double *params, const double *states, const double *inputs, double *outputs) {
    outputs[OUT_THETA]     = states[ST_THETA];
    outputs[OUT_THETA_DOT] = states[ST_THETA_DOT];
    outputs[OUT_TS]        = inputs[IN_TD];
}

/* theta_ddot = (T_d + T_a - B*theta_dot - Tf*sign(theta_dot) - T_r) / J */
void BlockDerivatives(const double *params, const double *states, const double *inputs, double *derivatives) {
    double J_total  = params[P_J_TOTAL];
    double B_total  = params[P_B_TOTAL];
    double Tf_total = params[P_TF_TOTAL];
    double theta_dot = states[ST_THETA_DOT];
    double T_d = inputs[IN_TD];
    double T_a = inputs[IN_TA];
    double T_r = inputs[IN_TR];

    derivatives[ST_THETA]     = theta_dot;
    derivatives[ST_THETA_DOT] = (T_d + T_a - B_total * theta_dot - Tf_total * sign(theta_dot) - T_r) / J_total;
}

#include "SFunctionSetup.h"
