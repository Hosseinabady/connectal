// bsv libraries
import SpecialFIFOs::*;
import Vector::*;
import StmtFSM::*;
import FIFO::*;

// portz libraries
import Directory::*;
import CtrlMux::*;
import Portal::*;
import Leds::*;
import AxiMasterSlave::*;

// generated by tool
import SayWrapper::*;
import SayProxy::*;

// defined by user
import Say::*;

module mkPortalTop(StdPortalTop#(addrWidth));

   // instantiate user portals
   SayProxy sayProxy <- mkSayProxy(7);
   Say say <- mkSay(sayProxy.ifc);
   SayWrapper sayWrapper <- mkSayWrapper(1008,say);
   Vector#(2,StdPortal) portals;
   portals[0] = sayWrapper.portalIfc;
   portals[1] = sayProxy.portalIfc; 
   
   // instantiate system directory
   Directory dir <- mkDirectory(portals);
   Vector#(1,StdPortal) directories;
   directories[0] = dir.portalIfc;
   
   // when constructing ctrl and interrupt muxes, directories must be the first argument
   let ctrl_mux <- mkAxiSlaveMux(directories,portals);
   let interrupt_mux <- mkInterruptMux(portals);
   
   interface interrupt = interrupt_mux;
   interface ctrl = ctrl_mux;
   interface m_axi = null_axi_master;
   interface leds = default_leds;

endmodule
