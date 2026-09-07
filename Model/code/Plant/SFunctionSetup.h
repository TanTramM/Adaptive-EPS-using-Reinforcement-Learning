/*
 * SFunctionSetup.h
 * -----------------
 * Shared "setup" scaffold for every Level-2 C S-Function under Plant
 * (SteeringColumn, Tire, VehicleDynamics, ...). This file only handles the
 * Simulink-facing plumbing (param/state/port counts, the mdlXXX lifecycle,
 * MEX/RTW includes) — it contains NO physics equations at all.
 *
 * How to use it from a block file (e.g. SteeringColumn.c):
 *   1) #define S_FUNCTION_NAME <BlockName>   and   S_FUNCTION_LEVEL 2
 *   2) #define N_PARAMS / N_STATES / N_INPUTS / N_OUTPUTS (omit if 0)
 *   3) Define BlockOutputs(...) — required
 *      Define BlockDerivatives(...) — only needed if N_STATES > 0
 *      Define BlockInitConditions(...) — optional, states default to 0 if omitted
 *      All of the above take plain "double" arrays only — no need to include simstruc.h.
 *   4) #include "SFunctionSetup.h" AT THE END of the file (must come after the
 *      functions above are defined).
 *
 * Algebraic blocks (no state, e.g. the Tire block in Block 2) simply omit
 * N_STATES / BlockDerivatives.
 */

#ifndef SFUNCTION_SETUP_H
#define SFUNCTION_SETUP_H

#include "simstruc.h"

/* ---------- Default configuration if the block file doesn't declare it ---------- */
#ifndef N_PARAMS
#define N_PARAMS 0
#endif
#ifndef N_STATES
#define N_STATES 0
#endif
#ifndef N_INPUTS
#define N_INPUTS 0
#endif
#ifndef N_OUTPUTS
#define N_OUTPUTS 0
#endif

/*
 * Per-input direct-feedthrough flags (1 = mdlOutputs may read this input's
 * current value, 0 = it may not). Defaults to "all 1" which is safe for
 * algebraic blocks (no state, e.g. Tire), but a block whose BlockOutputs()
 * only uses SOME inputs (e.g. SteeringColumn: T_s = T_d only) MUST override
 * this to mark the unused ones as 0 — otherwise Simulink treats the output
 * as depending on every input and can report a false ALGEBRAIC LOOP once the
 * model closes a feedback loop through that unused input (e.g. T_a).
 */
#ifndef INPUT_FEEDTHROUGH
#define INPUT_FEEDTHROUGH {1,1,1,1,1,1,1,1}
#endif

/* Minimum local array size is 1 to avoid declaring an empty array (illegal in C) */
#define SFS_PARAM_LEN  (N_PARAMS  > 0 ? N_PARAMS  : 1)
#define SFS_STATE_LEN  (N_STATES  > 0 ? N_STATES  : 1)
#define SFS_INPUT_LEN  (N_INPUTS  > 0 ? N_INPUTS  : 1)
#define SFS_OUTPUT_LEN (N_OUTPUTS > 0 ? N_OUTPUTS : 1)

/* ---------- Read params / states / inputs out of the SimStruct ---------- */
static void SFS_ReadParams(SimStruct *S, double *params) {
    int_T i;
    for (i = 0; i < N_PARAMS; i++) {
        params[i] = mxGetScalar(ssGetSFcnParam(S, i));
    }
}

static void SFS_ReadStates(SimStruct *S, double *states) {
    int_T i;
    const real_T *xc = ssGetContStates(S);
    for (i = 0; i < N_STATES; i++) {
        states[i] = xc[i];
    }
}

/* Unconditional read of every input's current value: safe in mdlDerivatives,
 * which Simulink always calls with fresh input data regardless of the
 * direct-feedthrough flag. */
static void SFS_ReadInputs(SimStruct *S, double *inputs) {
    int_T i;
    for (i = 0; i < N_INPUTS; i++) {
        InputRealPtrsType uPtrs = ssGetInputPortRealSignalPtrs(S, i);
        inputs[i] = *uPtrs[0];
    }
}

/* Feedthrough-aware read for mdlOutputs: only touches inputs flagged as
 * direct feedthrough in INPUT_FEEDTHROUGH; others are left at 0.0 and must
 * not be relied on by BlockOutputs(). */
static void SFS_ReadInputsForOutputs(SimStruct *S, double *inputs) {
    static const int_T feedthrough[] = INPUT_FEEDTHROUGH;
    int_T i;
    for (i = 0; i < N_INPUTS; i++) {
        if (feedthrough[i]) {
            InputRealPtrsType uPtrs = ssGetInputPortRealSignalPtrs(S, i);
            inputs[i] = *uPtrs[0];
        } else {
            inputs[i] = 0.0;
        }
    }
}

/* ---------- Mandatory Simulink S-Function lifecycle ---------- */
static void mdlInitializeSizes(SimStruct *S) {
    static const int_T feedthrough[] = INPUT_FEEDTHROUGH;
    int_T i;

    ssSetNumSFcnParams(S, N_PARAMS);
    ssSetNumContStates(S, N_STATES);
    ssSetNumDiscStates(S, 0);

    if (!ssSetNumInputPorts(S, N_INPUTS)) return;
    for (i = 0; i < N_INPUTS; i++) {
        ssSetInputPortWidth(S, i, 1);
        ssSetInputPortDirectFeedThrough(S, i, feedthrough[i]);
    }

    if (!ssSetNumOutputPorts(S, N_OUTPUTS)) return;
    for (i = 0; i < N_OUTPUTS; i++) {
        ssSetOutputPortWidth(S, i, 1);
    }

    ssSetNumSampleTimes(S, 1);
    ssSetOptions(S, SS_OPTION_EXCEPTION_FREE_CODE);
}

static void mdlInitializeSampleTimes(SimStruct *S) {
    ssSetSampleTime(S, 0, CONTINUOUS_SAMPLE_TIME);
    ssSetOffsetTime(S, 0, 0.0);
}

#if N_STATES > 0
#define MDL_INITIALIZE_CONDITIONS
static void mdlInitializeConditions(SimStruct *S) {
    real_T *xc = ssGetContStates(S);
    int_T i;

#ifdef BLOCK_HAS_INIT_CONDITIONS
    double params[SFS_PARAM_LEN];
    double states[SFS_STATE_LEN];
    SFS_ReadParams(S, params);
    BlockInitConditions(params, states);
    for (i = 0; i < N_STATES; i++) xc[i] = states[i];
#else
    for (i = 0; i < N_STATES; i++) xc[i] = 0.0;
#endif
}
#endif

static void mdlOutputs(SimStruct *S, int_T tid) {
    double params[SFS_PARAM_LEN];
    double states[SFS_STATE_LEN];
    double inputs[SFS_INPUT_LEN];
    double outputs[SFS_OUTPUT_LEN];
    int_T i;

    SFS_ReadParams(S, params);
    SFS_ReadStates(S, states);
    SFS_ReadInputsForOutputs(S, inputs);

    BlockOutputs(params, states, inputs, outputs);

    for (i = 0; i < N_OUTPUTS; i++) {
        ssGetOutputPortRealSignal(S, i)[0] = outputs[i];
    }
}

#if N_STATES > 0
#define MDL_DERIVATIVES
static void mdlDerivatives(SimStruct *S) {
    double params[SFS_PARAM_LEN];
    double states[SFS_STATE_LEN];
    double inputs[SFS_INPUT_LEN];
    double derivatives[SFS_STATE_LEN];
    real_T *dx = ssGetdX(S);
    int_T i;

    SFS_ReadParams(S, params);
    SFS_ReadStates(S, states);
    SFS_ReadInputs(S, inputs);

    BlockDerivatives(params, states, inputs, derivatives);

    for (i = 0; i < N_STATES; i++) {
        dx[i] = derivatives[i];
    }
}
#endif

static void mdlTerminate(SimStruct *S) {}

#ifdef MATLAB_MEX_FILE
#include "simulink.c"
#else
#include "cg_sfun.h"
#endif

#endif /* SFUNCTION_SETUP_H */
