// Copyright (c) 2013 Quanta Research Cambridge, Inc.

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
import FIFOF::*;
import Vector::*;
import MemTypes::*;
import Pipe::*;
import Portal::*;
import BlueNoC::*;

typedef enum {
   BpHeader,
   BpMessage
   } BnocPortalState deriving (Bits,Eq);


module mkPortalMsgRequest#(Vector#(numRequests, PipeIn#(Bit#(32))) portal)(MsgSink#(4));
   Reg#(Bit#(8)) messageWordsReg <- mkReg(0);
   Reg#(Bit#(8)) methodIdReg <- mkReg(0);
   Reg#(BnocPortalState) bpState <- mkReg(BpHeader);
   FifoMsgSink#(4) fifoMsgSink <- mkFifoMsgSink();
   Bool verbose = False;

   rule receiveMessageHeader if (bpState == BpHeader && !fifoMsgSink.empty());
      let hdr = fifoMsgSink.first();
      fifoMsgSink.deq();
      let methodId = hdr[31:24];
      Bit#(8) messageWords = hdr[23:16];
      methodIdReg <= methodId;
      if (verbose)
	 $display("receiveMessageHeader hdr=%x methodId=%x messageWords=%d", hdr, methodId, messageWords);
      messageWordsReg <= messageWords;
      if (messageWords != 0)
	 bpState <= BpMessage;
   endrule
   rule receiveMessage if (bpState == BpMessage && !fifoMsgSink.empty());
      let data = fifoMsgSink.first();
      fifoMsgSink.deq();
      if (verbose)
	 $display("receiveMessage id=%d data=%x messageWords=%d", methodIdReg, data, messageWordsReg);
      portal[methodIdReg].enq(data);
      messageWordsReg <= messageWordsReg - 1;
      if (messageWordsReg == 1)
	 bpState <= BpHeader;
   endrule
   return fifoMsgSink.sink;
endmodule

module mkPortalMsgIndication#(Vector#(numIndications, PipeOut#(Bit#(32))) portal, PortalSize messageSize)(MsgSource#(4));
   Reg#(Bit#(16)) messageWordsReg <- mkReg(0);
   Reg#(Bit#(8)) methodIdReg <- mkReg(0);
   Reg#(BnocPortalState) bpState <- mkReg(BpHeader);
   Vector#(numIndications, Bool) readyBits = map(pipeOutNotEmpty, portal);
   Bool      interruptStatus = False;
   Bit#(8)  readyChannel = -1;
   FifoMsgSource#(4) fifoMsgSource <- mkFifoMsgSource();
   function Bool pipeOutNotEmpty(PipeOut#(a) po); return po.notEmpty(); endfunction
   let verbose = False;

   for (Integer i = valueOf(numIndications) - 1; i >= 0; i = i - 1) begin
      if (readyBits[i]) begin
         interruptStatus = True;
         readyChannel = fromInteger(i);
      end
   end
   rule sendHeader if (bpState == BpHeader && interruptStatus);
      Bit#(16) messageBits = messageSize.size(extend(readyChannel));
      Bit#(16) roundup = messageBits[4:0] == 0 ? 0 : 1;
      Bit#(16) numWords = (messageBits >> 5) + roundup;
      /*      
      *   +------+--+--------+--------+--------+
      *   |  OP  |DP| LENGTH |  SRC   |   DST  |
      *   +------+--+--------+--------+--------+
      *    31  26    23    16 15     8 7      0
      */
      // op, dp, and src left empty for now
      Bit#(32) hdr = extend(readyChannel) << 24 | (extend(numWords) << 16);
      if (verbose) $display("sendHeader hdr=%h messageBits=%d numWords=%d", hdr, messageBits, numWords);
      messageWordsReg <= numWords;
      methodIdReg <= readyChannel;
      fifoMsgSource.enq(hdr);
      bpState <= BpMessage;
   endrule
   rule sendMessage if (bpState == BpMessage);
      messageWordsReg <= messageWordsReg - 1;
      let v = portal[methodIdReg].first;
      portal[methodIdReg].deq();
      fifoMsgSource.enq(v);
      if (verbose) $display("sendMessage id=%d data=%h messageWords=%d", methodIdReg, v, messageWordsReg);
      if (messageWordsReg == 1) begin
	 bpState <= BpHeader;
      end
   endrule
   return fifoMsgSource.source;
endmodule

interface BluenocTop#(numeric type numRequests, numeric type numIndications);
   interface Vector#(numRequests, MsgSink#(4)) requests;
   interface Vector#(numIndications, MsgSource#(4)) indications;
endinterface
