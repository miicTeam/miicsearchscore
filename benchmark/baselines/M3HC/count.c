#include "mex.h"
#include "matrix.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    mwSize  nelem;
    double* inputdata, *outputdata;
    int i;
    
//     if (nrhs != 2) {
//         mexErrMsgTxt("Needs two input arguments.");
//     }
//     if(nlhs > 1){
//         mexErrMsgTxt("Too many output arguments.");
//     }
    
//     nbins = (mwSize) *(mxGetPr(prhs[1]));
    
    plhs[0] = mxCreateDoubleMatrix((mwSize) *(mxGetPr(prhs[1])), 1, mxREAL); // Column Vector
        
    nelem = mxGetNumberOfElements(prhs[0]);
    inputdata = mxGetPr(prhs[0]);
    outputdata = mxGetPr(plhs[0]);
    
    for(i = 0; i < nelem; i++) {
        outputdata[(int) (inputdata[i]-1)]++;
    }
    
}
