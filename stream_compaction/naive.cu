#include <cuda.h>
#include <cuda_runtime.h>
#include "common.h"
#include "naive.h"
namespace StreamCompaction {
    namespace Naive {

        #define checkCUDAErrorWithLine(msg) checkCUDAError(msg, __LINE__)  // We can use defines provided in this project

        int* dev_buf1;
        int* dev_buf2;
        #define blockSize 128

        using StreamCompaction::Common::PerformanceTimer;
        PerformanceTimer& timer()
        {
            static PerformanceTimer timer;
            return timer;
        }
        // TODO: __global__

        __global__ void performScan(int d, int* buf1, int* buf2, int N)
        {
            int index = (blockIdx.x * blockDim.x) + threadIdx.x;
            if (index > N)
            {
                return;
            }
            int pow2_d = pow(2, d);
            int pow2_dminus1 = pow2_d / 2;
            if (index >= pow2_dminus1)
            {
                buf2[index] = buf1[index - pow2_dminus1] + buf1[index];
            }
            else
            {
                buf2[index] = buf1[index];
            }
            
        }

        void FreeMemory() {
            cudaFree(dev_buf1);
            cudaFree(dev_buf2);
        }

        void AllocateMemory(int n)
        {
            cudaMalloc((void**)&dev_buf1, n * sizeof(int));
            checkCUDAErrorWithLine("cudaMalloc dev_vel2 failed!");
            cudaMalloc((void**)&dev_buf2, n * sizeof(int));
            checkCUDAErrorWithLine("cudaMalloc dev_vel2 failed!");
            cudaDeviceSynchronize();
        }

        /**
         * Performs prefix-sum (aka scan) on idata, storing the result into odata.
         */
        void scan(int n, int *odata, const int *idata) {
            timer().startGpuTimer();
            // TODO

            int power2 = 1;
            int nearesttwo = 2;

            for (int i = 0; i < n; i++)
            {
                nearesttwo = nearesttwo << 1;
                if (nearesttwo >= n)
                {
                    break;
                }
            }
            int difference = nearesttwo - n;

            int finalMemSize = n + difference;

            int *arr_z = new int[finalMemSize];

        /*    for (int i = 0; i < finalMemSize; i++)
            {
                if (i < difference)
                {
                    arr_z[difference] = 0; 
                    continue;
                }
                arr_z[i] = idata[i - difference];
            }*/

            int bp = idata[0];
            int fp = idata[n-1];
            for (int i = 0; i < difference; i++)
            {
                arr_z[i] = 0;
            }
            for (int i = 0; i < n; i++)
            {
                arr_z[i + difference] = idata[i];
            }

         /*   for (int i = 0; i < finalMemSize; i++)
            {
                printf("%3d ", arr_z[i]);
            }*/

            int d = ilog2ceil(finalMemSize);
            AllocateMemory(finalMemSize);
            cudaMemcpy(dev_buf1, arr_z, sizeof(int) * finalMemSize, cudaMemcpyHostToDevice);

            dim3 fullBlocksPerGrid((finalMemSize + blockSize - 1) / blockSize);

            for (int i = 1; i <= d; i++)
            {
                performScan << < fullBlocksPerGrid, blockSize >> > (i, dev_buf1, dev_buf2, finalMemSize);
                cudaDeviceSynchronize();
                std::swap(dev_buf1, dev_buf2);
            }
           
            if (d % 2 != 0)
            {
                cudaMemcpy(arr_z, dev_buf2, sizeof(int) * finalMemSize, cudaMemcpyDeviceToHost);
            }
            else
            {
                cudaMemcpy(arr_z, dev_buf1, sizeof(int) * finalMemSize, cudaMemcpyDeviceToHost);
            }

         /*   for (int i = 0; i < finalMemSize; i++)
            {
                printf("%3d ", arr_z[i]);
            }*/

            for (int i = 0; i < n; i++)
            {
                odata[i] = arr_z[i + difference];
            }

            //rightshift
            for (int i = n -1; i >= 1 ; i--)
            {
                odata[i] = odata[i - 1];
            }
            odata[0] = 0;

           /* printf("]\n");
            for (int i = 0; i < n; i++)
            {
                printf("%3d ", odata[i]);
            }*/


            timer().endGpuTimer();
        }
    }
}
