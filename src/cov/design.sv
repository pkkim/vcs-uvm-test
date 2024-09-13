interface my_interface(
  input clock,
  input select,
  input [3:0] data);
  
  clocking cb @(posedge clock);
    input select, data;
  endclocking
endinterface

import uvm_pkg::*;
`include "uvm_macros.svh"

// Simple coverage class that covers all values of data
// when select is high.
class my_cov extends uvm_component;

  virtual my_interface _if;
  
  `uvm_component_utils(my_cov);
  
  covergroup my_cg;
    my_cp: coverpoint _if.cb.data iff(_if.cb.select);
  endgroup
  
  function new(string name, uvm_component parent = null);
    super.new(name, parent);
    my_cg = new();
  endfunction
  
  // Sample the coverage on each clock.
  task run_phase(uvm_phase phase);
    forever begin
      @(_if.cb);
      my_cg.sample();
    end
  endtask

endclass
