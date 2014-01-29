// bsv libraries
import SpecialFIFOs::*;
import Vector::*;
import StmtFSM::*;
import FIFO::*;

// portz libraries
import AxiMasterSlave::*;
import Directory::*;
import CtrlMux::*;
import Portal::*;
import PortalMemory::*;
import Dma::*;
import AxiDma::*;

// generated by tool
import MemreadRequestWrapper::*;
import DmaRequestWrapper::*;
import MemreadIndicationProxy::*;
import DmaIndicationProxy::*;

// defined by user
import Memread::*;

module mkPortalTop(StdPortalDmaTop#(addrWidth)) provisos (
    Add#(addrWidth, a__, 52),
    Add#(b__, addrWidth, 64),
    Add#(c__, 12, addrWidth),
    Add#(addrWidth, d__, 44));

   DmaIndicationProxy dmaIndicationProxy <- mkDmaIndicationProxy(9);

   MemreadIndicationProxy memreadIndicationProxy <- mkMemreadIndicationProxy(7);
   Memread memread <- mkMemread(memreadIndicationProxy.ifc);
   MemreadRequestWrapper memreadRequestWrapper <- mkMemreadRequestWrapper(1008,memread.request);

   Vector#(1, DmaReadClient#(64)) clients = cons(memread.dmaClient, nil);
   Integer             numRequests = 2;
   AxiDmaServer#(addrWidth,64) dma <- mkAxiDmaServer(dmaIndicationProxy.ifc, numRequests, clients, nil);

   DmaRequestWrapper dmaRequestWrapper <- mkDmaRequestWrapper(1005,dma.request);

   Vector#(4,StdPortal) portals;
   portals[0] = memreadRequestWrapper.portalIfc;
   portals[1] = memreadIndicationProxy.portalIfc; 
   portals[2] = dmaRequestWrapper.portalIfc;
   portals[3] = dmaIndicationProxy.portalIfc; 
   
   Directory dir <- mkDirectory(portals);
   Vector#(1,StdPortal) directories;
   directories[0] = dir.portalIfc;
   
   // when constructing ctrl and interrupt muxes, directories must be the first argument
   let ctrl_mux <- mkAxiSlaveMux(directories,portals);
   let interrupt_mux <- mkInterruptMux(portals);
   
   interface interrupt = interrupt_mux;
   interface ctrl = ctrl_mux;
   interface m_axi = replicate(dma.m_axi);
   interface leds = ?;
endmodule : mkPortalTop
