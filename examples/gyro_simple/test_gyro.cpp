
// Copyright (c) 2014 Quanta Research Cambridge, Inc.

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.


#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <string.h>
#include <pthread.h>
#include <netdb.h>
#include <netinet/in.h>
#include <signal.h>

#include "StdDmaIndication.h"
#include "MemServerRequest.h"
#include "MMURequest.h"
#include "dmaManager.h"
#include "sock_utils.h"

#include "GeneratedTypes.h"
#include "gyro.h"
#include "gyro_simple.h"


int main(int argc, const char **argv)
{
  GyroCtrlIndication *ind = new GyroCtrlIndication(IfcNames_ControllerIndication);
  GyroCtrlRequestProxy *device = new GyroCtrlRequestProxy(IfcNames_ControllerRequest);
  MemServerRequestProxy *hostMemServerRequest = new MemServerRequestProxy(IfcNames_HostMemServerRequest);
  MMURequestProxy *dmap = new MMURequestProxy(IfcNames_HostMMURequest);
  DmaManager *dma = new DmaManager(dmap);
  MemServerIndication *hostMemServerIndication = new MemServerIndication(hostMemServerRequest, IfcNames_HostMemServerIndication);
  MMUIndication *hostMMUIndication = new MMUIndication(dma, IfcNames_HostMMUIndication);

  sem_init(&status_sem,1,0);
  sem_init(&read_sem,1,0);
  sem_init(&write_sem,1,0);

  portalExec_start();
  start_server();

  int dstAlloc = portalAlloc(alloc_sz);
  char *dstBuffer = (char *)portalMmap(dstAlloc, alloc_sz);
  unsigned int ref_dstAlloc = dma->reference(dstAlloc);

  long req_freq = 100000000; // 100 mHz
  long freq = 0;
  setClockFrequency(0, req_freq, &freq);
  fprintf(stderr, "Requested FCLK[0]=%ld actually %ld\n", req_freq, freq);

  // setup
  setup_registers(device);  

#ifndef BSIM
  if(verbose){
    for(int i = 0; i < 32; i++){
      short int tmp;
      read_reg(device, OUT_X_H);
      tmp = read_reg_val << 8;
      read_reg(device, OUT_X_L);
      tmp |= read_reg_val;
      fprintf(stderr, "XXX %8d, ", (short int)tmp);

      read_reg(device, OUT_Y_H);
      tmp = read_reg_val << 8;
      read_reg(device, OUT_Y_L);
      tmp |= read_reg_val;
      fprintf(stderr, "%8d, ", (short int)tmp);

      read_reg(device, OUT_Z_H);
      tmp = read_reg_val << 8;
      read_reg(device, OUT_Z_L);
      tmp |= read_reg_val;
      fprintf(stderr, "%8d\n", (short int)tmp);
    }
  }
#endif
  
  // sample has one two-byte component for each axis (x,y,z).  This is to ensure 
  // that the X component always lands in offset 0 when the HW wraps around
  int sample_size = 6;
  int bus_data_width = 8;
  int wrap_limit = alloc_sz-(alloc_sz%(sample_size*bus_data_width)); 
  fprintf(stderr, "wrap_limit:%08x\n", wrap_limit);
  sample_gyro(wrap_limit, device, ref_dstAlloc, dstAlloc, dstBuffer);
 
}
