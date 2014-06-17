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

// bsv libraries
import Vector::*;
import GetPut::*;
import Connectable :: *;
import Clocks :: *;
import FIFO::*;
import DefaultValue::*;

// portz libraries
import Portal::*;
import Directory::*;
import CtrlMux::*;
import Portal::*;
import Leds::*;
import PortalMemory::*;
import MemTypes::*;
import MemServer::*;

// generated by tool
import FMComms1RequestWrapper::*;
import FMComms1IndicationProxy::*;
import DmaConfigWrapper::*;
import DmaIndicationProxy::*;

// defined by user
import XilinxCells::*;
import XbsvXilinxCells::*;

import FMComms1ADC::*;
import FMComms1DAC::*;

typedef enum { FMComms1Request, FMComms1Indication, DmaIndication, DmaConfig} IfcNames deriving (Eq,Bits);

interface FMComms1Pins;
   interface FMComms1ADCPins adcpins;
   interface FMComms1DACPins dacpins;
   (* prefix="" *)
endinterface

interface FMComms1;
   interface Vector#(2,StdPortal) portals;
   interface FMComms1Pins pins;
endinterface

module mkFMComms1#(Clock fmc_imageon_clk1)(FMComms1);

   // These need to be connected to the clocks for the ADC and DAC
   Wire#(Bit#(1)) adc_dco_p <- mkDWire(0);
   Wire#(Bit#(1)) adc_dco_n <- mkDWire(0);
   Wire#(Bit#(1)) dac_dco_p <- mkDWire(0);
   Wire#(Bit#(1)) dac_dco_n <- mkDWire(0);


   // instantiate user portals
   // fmcomms1
   FMComms1IndicationProxy fmcomms1IndicationProxy <- mkFMComms1IndicationProxy(FMComms1Indication);
   FMComms1 fmcomms1 <- mkFMComms1();
   FMComms1RequestWrapper fmcomms1RequestWrapper <- mkFMComms1RequestWrapper(FMComms1Request);

   FMComms1ADC adc <- mkFMComms1ADC(adc_clk_p, adc_clk_n);
   FMComms1DAC dac <- mkFMComms1DAC(dac_clk_p, dac_clk_n);
   
   
   Vector#(2,StdPortal) portal_array;
   portal_array[0] = fmcomms1RequestWrapper.portalIfc; 
   portal_array[1] = fmcomms1IndicationProxy.portalIfc;


   interface Vector portals = portal_array;
   
   /* the names in this interface get mapped to real pins on the chip */
   interface FMComms1Pins pins;
      interface FMComms1ADCPins adcpins = fmcomms1adc.pins;
      interface FMComms1DACPins dacpins = fmcomms1dac.pins;
      method Action io_adc_dco_p(Bit#(1) v);
      method Action io_adc_dco_n(Bit#(1) v);
      method Action io_dac_dco_p(Bit#(1) v);
      method Action io_dac_dco_n(Bit#(1) v);
   endinterface
endmodule

module mkPortalTop(PortalTop#(addrWidth,64,FMComms1Pins,0))
      provisos(Add#(addrWidth, a__, 52),
	    Add#(b__, addrWidth, 64),
	    Add#(c__, 12, addrWidth),
	    Add#(addrWidth, d__, 44),
	    Add#(e__, c__, 40),
	    Add#(f__, addrWidth, 40));

   Clock adc_clk_p;
   Clock adc_clk_n;
   Clock dac_clk_p;
   Clock dac_clk_n;

   FMComms1ADC adc <- mkFMComms1ADC(adc_clk_p, adc_clk_n);
   FMComms1DAC dac <- mkFMComms1DAC(dac_clk_p, dac_clk_n);
   
   FMComms1IndicationProxy fmcomms1IndicationProxy <- mkFMComms1IndicationProxy(FMComms1Indication);
   FMComms1 fmcomms1 <- mkFMComms1(fmcomms1IndicationProxy, dac.dac, adc.adc);
   FMComms1RequestWrapper fmcomms1RequestWrapper <- mkFMComms1RequestWrapper(FMComms1Request);

   Vector#(1,  ObjectReadClient#(64))   readClients = cons(fmcomms1.dmaReadClient, nil);
   Vector#(1, ObjectWriteClient#(64))  writeClients = cons(fmcomms1.dmaWriteClient, nil);
   DmaIndicationProxy dmaIndicationProxy <- mkDmaIndicationProxy(DmaIndication);
   MemServer#(addrWidth, 64, 1)   dma <- mkMemServer(dmaIndicationProxy.ifc, readClients, writeClients);
   DmaConfigWrapper dmaRequestWrapper <- mkDmaConfigWrapper(DmaConfig,dma.request);

   Vector#(4,StdPortal) portals;
   portals[0] = fmcomms1RequestWrapper.portalIfc;
   portals[1] = fmcomms1IndicationProxy.portalIfc; 
   portals[2] = dmaRequestWrapper.portalIfc;
   portals[3] = dmaIndicationProxy.portalIfc; 

   
   
   // instantiate system directory
   StdDirectory dir <- mkStdDirectory(ic.portals);
   let ctrl_mux <- mkSlaveMux(dir,ic.portals);
   


   
   interface interrupt = getInterruptVector(ic.portals);
   interface slave = ctrl_mux;
   interface masters = nil;
   //interface leds = captureRequestInternal.leds;
   interface FMComms1Pins pins;
      interface FMCOmms1ADCPins adcpins = adc.pins;
      interface FMCOmms1ADCPins dacpins = dac.pins;
      method Action io_adc_dco_p(Bit#(1) v);
	 adc_dco_p <= v;
      endmethod
      method Action io_adc_dco_n(Bit#(1) v);
	 adc_dco_n <= v;
      endmethod
      method Action io_dac_dco_p(Bit#(1) v);
	 dac_dco_p <= v;
      endmethod
      method Action io_dac_dco_n(Bit#(1) v);
	 dac_dco_n <= v;
      endmethod
   endinterface
endmodule : mkPortalTop
