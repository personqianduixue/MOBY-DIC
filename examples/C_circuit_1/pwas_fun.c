#include "pwas_fun.h"
const int Npartition[nDim] = {9,9,1,9};

const float mm[nDim] = {0.000450,0.000493,0.250000,1.500000};
const float qq[nDim] = {4.500000,4.066729,-0.000000,-0.000000};


const float weigthVector[nY][nWeight] = {{0.371935,5.962552,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.249204,3.214923,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200003,0.200000,0.223157,2.263850,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,0.200000,0.200000,0.548547,0.000000,0.000000,0.000000,0.000000,0.000000,0.381930,0.503725,0.498362,0.493511,0.499100,0.800000,0.000000,0.000000,0.000000,0.000000,0.800000,0.800000,0.800000,0.800000,0.800000,0.800000,0.799990,0.000000,0.000000,0.000000,0.799997,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799994,0.000000,0.000000,-0.200654,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799994,0.000000,0.000000,0.799979,0.799999,0.799998,0.799998,0.799999,0.799999,0.799999,0.799999,0.799993,0.000000,0.000000,0.799979,0.799993,0.799993,0.799993,0.799985,0.799990,0.799991,0.799985,0.734066,5.990695,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.246415,3.312411,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200008,0.200000,0.200000,2.263920,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,0.200000,0.204435,1.395121,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.225649,0.200000,0.200000,0.278096,0.800000,0.000000,0.000000,0.000000,0.000000,0.800000,0.800000,0.800000,0.800000,0.800000,0.800000,0.799986,0.000000,0.000000,0.000000,0.799992,0.799995,0.799995,0.799995,0.799995,0.799995,0.799995,0.799990,0.000000,0.000000,-0.361564,0.799994,0.799995,0.799995,0.799995,0.799995,0.799995,0.799995,0.799992,0.000000,0.000000,0.799966,0.799995,0.799995,0.799995,0.799995,0.799995,0.799995,0.799995,0.799993,0.000000,0.000000,0.799979,0.799993,0.799993,0.799993,0.799989,0.799985,0.799986,0.799980,0.399598,6.129703,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.231371,3.263293,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200002,0.200000,0.211603,2.274579,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,0.200000,0.200000,0.626245,0.000000,0.000000,0.000000,0.000000,0.000000,0.354388,0.448443,0.437336,0.438561,0.439971,0.800000,0.000000,0.000000,0.000000,0.000000,0.800000,0.800000,0.800000,0.800000,0.800000,0.800000,0.799989,0.000000,0.000000,0.000000,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799994,0.000000,0.000000,-0.268498,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799994,0.000000,0.000000,0.799979,0.799999,0.799998,0.799998,0.799999,0.799999,0.799999,0.799999,0.799993,0.000000,0.000000,0.799983,0.799995,0.799995,0.799995,0.799990,0.799990,0.799990,0.799986,0.704223,6.425814,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,3.312411,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200005,0.200000,0.200000,2.274820,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200005,0.200004,0.200000,0.200000,1.451026,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,0.200000,0.200000,0.200000,0.783071,0.000000,0.000000,0.000000,0.000000,0.800000,0.800000,0.800000,0.800000,0.800000,0.800000,0.799986,0.000000,0.000000,0.000000,0.799995,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799990,0.000000,0.000000,-0.488092,0.799996,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799993,0.000000,0.000000,0.799972,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799993,0.000000,0.000000,0.799983,0.799996,0.799996,0.799996,0.799993,0.799986,0.799987,0.799983,0.397709,6.133662,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.230948,3.263293,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200002,0.200000,0.211603,2.274579,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,0.200000,0.200000,0.625298,0.000000,0.000000,0.000000,0.000000,0.000000,0.356007,0.452937,0.443347,0.444556,0.442616,0.800000,0.000000,0.000000,0.000000,0.000000,0.800000,0.800000,0.800000,0.800000,0.800000,0.800000,0.799989,0.000000,0.000000,0.000000,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799993,0.000000,0.000000,-0.268080,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799994,0.000000,0.000000,0.799979,0.799999,0.799998,0.799998,0.799999,0.799999,0.799999,0.799999,0.799993,0.000000,0.000000,0.799983,0.799995,0.799995,0.799995,0.799990,0.799990,0.799990,0.799985,0.703258,6.425814,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,3.312411,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200005,0.200000,0.200000,2.274820,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200005,0.200004,0.200000,0.200000,1.452008,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,0.200000,0.200000,0.200000,0.800000,0.000000,0.000000,0.000000,0.000000,0.800000,0.800000,0.800000,0.800000,0.800000,0.800000,0.799986,0.000000,0.000000,0.000000,0.799995,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799990,0.000000,0.000000,-0.488002,0.799996,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799992,0.000000,0.000000,0.799972,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799993,0.000000,0.000000,0.799982,0.799996,0.799996,0.799996,0.799993,0.799986,0.799987,0.799983,0.397840,6.133662,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.230948,3.263293,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200002,0.200000,0.211603,2.274579,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,0.200000,0.200000,0.625439,0.000000,0.000000,0.000000,0.000000,0.000000,0.355917,0.452602,0.442795,0.443932,0.442232,0.800000,0.000000,0.000000,0.000000,0.000000,0.800000,0.800000,0.800000,0.800000,0.800000,0.800000,0.799989,0.000000,0.000000,0.000000,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799993,0.000000,0.000000,-0.268123,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799994,0.000000,0.000000,0.799979,0.799999,0.799998,0.799998,0.799999,0.799999,0.799999,0.799999,0.799993,0.000000,0.000000,0.799983,0.799995,0.799995,0.799995,0.799990,0.799990,0.799990,0.799985,0.703323,6.425814,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,3.312411,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200005,0.200000,0.200000,2.274820,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200005,0.200004,0.200000,0.200000,1.452008,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,0.200000,0.200000,0.200000,0.800000,0.000000,0.000000,0.000000,0.000000,0.800000,0.800000,0.800000,0.800000,0.800000,0.800000,0.799986,0.000000,0.000000,0.000000,0.799995,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799990,0.000000,0.000000,-0.488023,0.799996,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799992,0.000000,0.000000,0.799972,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799993,0.000000,0.000000,0.799982,0.799996,0.799996,0.799996,0.799993,0.799986,0.799987,0.799983,0.397831,6.133662,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.230948,3.263293,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200002,0.200000,0.211603,2.274579,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,0.200000,0.200000,0.625422,0.000000,0.000000,0.000000,0.000000,0.000000,0.355926,0.452627,0.442844,0.443994,0.442278,0.800000,0.000000,0.000000,0.000000,0.000000,0.800000,0.800000,0.800000,0.800000,0.800000,0.800000,0.799989,0.000000,0.000000,0.000000,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799993,0.000000,0.000000,-0.268178,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799994,0.000000,0.000000,0.799979,0.799999,0.799998,0.799998,0.799999,0.799999,0.799999,0.799999,0.799993,0.000000,0.000000,0.799983,0.799995,0.799995,0.799995,0.799990,0.799990,0.799990,0.799985,0.703319,6.425814,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,3.312411,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200005,0.200000,0.200000,2.274820,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200005,0.200004,0.200000,0.200000,1.452008,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,0.200000,0.200000,0.200000,0.800000,0.000000,0.000000,0.000000,0.000000,0.800000,0.800000,0.800000,0.800000,0.800000,0.800000,0.799986,0.000000,0.000000,0.000000,0.799995,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799990,0.000000,0.000000,-0.488051,0.799996,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799992,0.000000,0.000000,0.799972,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799993,0.000000,0.000000,0.799982,0.799996,0.799996,0.799996,0.799993,0.799986,0.799987,0.799983,0.397840,6.133662,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.230948,3.263293,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200002,0.200000,0.211603,2.274579,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,0.200000,0.200000,0.625421,0.000000,0.000000,0.000000,0.000000,0.000000,0.355887,0.452602,0.442821,0.443982,0.442273,0.800000,0.000000,0.000000,0.000000,0.000000,0.800000,0.800000,0.800000,0.800000,0.800000,0.800000,0.799989,0.000000,0.000000,0.000000,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799993,0.000000,0.000000,-0.268067,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799994,0.000000,0.000000,0.799979,0.799999,0.799998,0.799998,0.799999,0.799999,0.799999,0.799999,0.799993,0.000000,0.000000,0.799983,0.799995,0.799995,0.799995,0.799990,0.799990,0.799990,0.799985,0.703318,6.425814,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,3.312411,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200005,0.200000,0.200000,2.274820,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200005,0.200004,0.200000,0.200000,1.452008,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,0.200000,0.200000,0.200000,0.800000,0.000000,0.000000,0.000000,0.000000,0.800000,0.800000,0.800000,0.800000,0.800000,0.800000,0.799986,0.000000,0.000000,0.000000,0.799995,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799990,0.000000,0.000000,-0.487997,0.799996,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799992,0.000000,0.000000,0.799972,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799993,0.000000,0.000000,0.799982,0.799996,0.799996,0.799996,0.799993,0.799986,0.799987,0.799983,0.397709,6.133662,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.230948,3.263293,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200002,0.200000,0.211603,2.274579,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,0.200000,0.200000,0.625510,0.000000,0.000000,0.000000,0.000000,0.000000,0.356250,0.452849,0.443046,0.444094,0.442281,0.800000,0.000000,0.000000,0.000000,0.000000,0.800000,0.800000,0.800000,0.800000,0.800000,0.800000,0.799989,0.000000,0.000000,0.000000,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799993,0.000000,0.000000,-0.268119,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799994,0.000000,0.000000,0.799979,0.799999,0.799998,0.799998,0.799999,0.799999,0.799999,0.799999,0.799993,0.000000,0.000000,0.799983,0.799995,0.799995,0.799995,0.799990,0.799990,0.799990,0.799985,0.703329,6.425814,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,3.312411,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200005,0.200000,0.200000,2.274820,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200005,0.200004,0.200000,0.200000,1.452008,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,0.200000,0.200000,0.200000,0.800000,0.000000,0.000000,0.000000,0.000000,0.800000,0.800000,0.800000,0.800000,0.800000,0.800000,0.799986,0.000000,0.000000,0.000000,0.799995,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799990,0.000000,0.000000,-0.488023,0.799996,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799992,0.000000,0.000000,0.799972,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799993,0.000000,0.000000,0.799982,0.799996,0.799996,0.799996,0.799993,0.799986,0.799987,0.799983,0.399597,6.126080,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.230948,3.263293,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200002,0.200000,0.211603,2.274579,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,0.200000,0.200000,0.623203,0.000000,0.000000,0.000000,0.000000,0.000000,0.352986,0.450368,0.440532,0.442402,0.441994,0.800000,0.000000,0.000000,0.000000,0.000000,0.800000,0.800000,0.800000,0.800000,0.800000,0.800000,0.799989,0.000000,0.000000,0.000000,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799993,0.000000,0.000000,-0.268195,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799994,0.000000,0.000000,0.799979,0.799999,0.799998,0.799998,0.799999,0.799999,0.799999,0.799999,0.799993,0.000000,0.000000,0.799983,0.799995,0.799995,0.799995,0.799990,0.799990,0.799990,0.799985,0.703181,6.425814,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,3.312411,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200005,0.200000,0.200000,2.274820,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200005,0.200004,0.200000,0.200000,1.452008,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,0.200000,0.200000,0.200000,0.800000,0.000000,0.000000,0.000000,0.000000,0.800000,0.800000,0.800000,0.800000,0.800000,0.800000,0.799986,0.000000,0.000000,0.000000,0.799995,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799990,0.000000,0.000000,-0.488071,0.799996,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799992,0.000000,0.000000,0.799972,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799993,0.000000,0.000000,0.799982,0.799996,0.799996,0.799996,0.799993,0.799986,0.799987,0.799983,0.371499,6.080409,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.231757,3.263293,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200002,0.200000,0.211603,2.274579,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,0.200000,0.200000,0.675423,0.000000,0.000000,0.000000,0.000000,0.000000,0.380744,0.474925,0.466142,0.465138,0.449573,0.800000,0.000000,0.000000,0.000000,0.000000,0.800000,0.800000,0.800000,0.800000,0.800000,0.800000,0.799990,0.000000,0.000000,0.000000,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799994,0.000000,0.000000,-0.268204,0.799999,0.799998,0.799998,0.799998,0.799998,0.799998,0.799998,0.799995,0.000000,0.000000,0.799980,0.799999,0.799999,0.799999,0.799999,0.799999,0.799999,0.799999,0.799993,0.000000,0.000000,0.799983,0.799995,0.799995,0.799995,0.799990,0.799990,0.799991,0.799986,0.705377,6.425814,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,3.312411,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200005,0.200000,0.200000,2.274820,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200005,0.200004,0.200000,0.200000,1.452008,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,0.200000,0.200000,0.200000,0.800000,0.000000,0.000000,0.000000,0.000000,0.800000,0.800000,0.800000,0.800000,0.800000,0.800000,0.799986,0.000000,0.000000,0.000000,0.799994,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799990,0.000000,0.000000,-0.487826,0.799996,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799992,0.000000,0.000000,0.799972,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799997,0.799993,0.000000,0.000000,0.799983,0.799996,0.799996,0.799996,0.799993,0.799986,0.799987,0.799983,0.754175,6.080409,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.236630,3.310800,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200008,0.200000,0.200255,2.274579,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,0.200000,0.200000,1.397176,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.234435,0.214241,0.214655,0.276670,0.800000,0.000000,0.000000,0.000000,0.000000,0.800000,0.800000,0.800000,0.800000,0.800000,0.800000,0.799987,0.000000,0.000000,0.000000,0.799992,0.799995,0.799995,0.799995,0.799995,0.799995,0.799995,0.799990,0.000000,0.000000,-0.361560,0.799994,0.799995,0.799995,0.799995,0.799995,0.799995,0.799995,0.799992,0.000000,0.000000,0.799966,0.799995,0.799995,0.799995,0.799995,0.799995,0.799996,0.799995,0.799993,0.000000,0.000000,0.799979,0.799993,0.799993,0.799993,0.799989,0.799985,0.799986,0.799980,0.735084,6.425814,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,3.312411,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200008,0.200000,0.200000,2.274820,0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,0.200008,0.200005,0.200000,0.200000,1.736698,0.000000,0.000000,0.000000,0.000000,0.000000,0.200000,0.200000,0.200000,0.200000,0.200000,0.800000,0.000000,0.000000,0.000000,0.000000,0.764174,0.800000,0.800000,0.800000,0.800000,0.800000,0.799985,0.000000,0.000000,0.000000,0.800000,0.800000,0.799995,0.799995,0.799995,0.799995,0.799996,0.799989,0.000000,0.000000,-0.614179,0.799995,0.799996,0.799996,0.799996,0.799996,0.799996,0.799996,0.799992,0.000000,0.000000,0.799966,0.799996,0.799996,0.799996,0.799996,0.799996,0.799996,0.799996,0.799992,0.000000,0.000000,0.799979,0.799994,0.799994,0.799994,0.799993,0.799982,0.799983,0.799978}};

void getMu(float *z_sorted,float *mu)
{
	int i;
	mu[0] = 1 - z_sorted[0];

	for (i = 0; i < nDim; i++)
	{
			mu[i + 1] = z_sorted[i] - z_sorted[i + 1];
	}
	mu[nDim] = z_sorted[nDim-1];
}

void Sorting(float *number, int n)
{
	int i,j;
	float tmp;

	for (i = 0; i < n; ++i)
	{
		for (j = i + 1; j < n; ++j)
		{
			if (number[i] < number[j])
			{
				tmp = number[i];
				number[i] = number[j];
				number[j] = tmp;
			}
		}
	}
}

void Transform(float *x, float *z)
{
	int k;
	int i;
	for (k = 0; k < nDim; k++)
	{
    z[k] = mm[k] * x[k] + qq[k];
	}
}

void divideZ(float *Z, int *intZ, float *decZ)
{
	int i;

	for (i = 0; i < nDim; i++)
	{
		intZ[i] = (int)(Z[i]);
		decZ[i] = Z[i] - intZ[i];
	}
}

void getSimplexVertices(int *intZ, float *decZ, float *sortedDecZ, int *addr)
{
	int i,j;
	int toAdd;
	float diff;
	addr[0] = 0;
	for(i=nDim-1;i>0;i--)
		addr[0] = (addr[0]+intZ[i])*(Npartition[i-1]+1);
	addr[0] += intZ[0];

	for(i=1;i<nDim+1;i++)
	{
		addr[i] = 0;
		for(j=nDim-1;j>0;j--)
		{
			//1(decZ[j]-sortedDecZ[i]), where 1 is the step function
			diff = decZ[j]-sortedDecZ[i-1]; 
			if (diff >= 0)
				toAdd = 1;
			else 
				toAdd = 0;
		addr[i] = (addr[i]+intZ[j]+toAdd)*(Npartition[j-1]+1);
		}
	diff = decZ[0]-sortedDecZ[i-1]; 
		if (diff >= 0)
			toAdd = 1;
		else 
			toAdd = 0;
      	addr[i] += intZ[0]+toAdd;
	}
}

void calculatePWAS(float *x, float *u)
{
	int i;

	float Z[nDim];
	int Zint[nDim];
	float Zdec[nDim];
	float ZdecSorted[nDim];

	float mu[nDim+1];
	int vertAddr[nDim+1];

	Transform(x, Z);
	divideZ(Z, Zint, Zdec);
	for(i=0;i<nDim;i++)
	   ZdecSorted[i] = Zdec[i];
	Sorting(ZdecSorted,nDim);
	getMu(ZdecSorted,mu);
	getSimplexVertices(Zint, Zdec, ZdecSorted, vertAddr);

	for(i=0;i<nY;i++)
		*(u+i) = uFunction(vertAddr,mu,i,Z);
}

float uFunction(int *vertexAddr, float *mu, int uIndex, float *x) 
{
	int i;
	float res = 0;
	for(i=0;i<nDim+1;i++)
	{
      if(mu[i] != 0)
          res += mu[i]*weigthVector[uIndex][vertexAddr[i]];
	}
	return res;
}
