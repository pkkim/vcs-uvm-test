// Interface definition (outside of package)
interface adder_if;
  logic clk;
  logic [7:0] a;
  logic [7:0] b;
  logic [8:0] sum;
endinterface

// DUT: Simple 8-bit Adder
module adder(
  input clk,
  input [7:0] a,
  input [7:0] b,
  output logic [8:0] sum
);
  always_ff @(posedge clk) begin
    sum <= a + b;
  end
endmodule

// UVM Testbench
package adder_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Sequence Item
  class adder_item extends uvm_sequence_item;
    rand bit [7:0] a;
    rand bit [7:0] b;
    bit [8:0] sum;

    `uvm_object_utils_begin(adder_item)
      `uvm_field_int(a, UVM_ALL_ON)
      `uvm_field_int(b, UVM_ALL_ON)
      `uvm_field_int(sum, UVM_ALL_ON)
    `uvm_object_utils_end

    constraint c_inputs {
      a inside {[0:100]};
      b inside {[0:100]};
    }

    function new(string name = "adder_item");
      super.new(name);
    endfunction
  endclass

  // Sequence
  class adder_sequence extends uvm_sequence #(adder_item);
    `uvm_object_utils(adder_sequence)

    function new(string name = "adder_sequence");
      super.new(name);
    endfunction

    task body();
      repeat(10) begin
        req = adder_item::type_id::create("req");
        start_item(req);
        if(!req.randomize()) begin
          `uvm_error("SEQ", "Randomization failed")
        end
        finish_item(req);
      end
    endtask
  endclass

  // Driver
  class adder_driver extends uvm_driver #(adder_item);
    `uvm_component_utils(adder_driver)

    virtual adder_if vif;

    function new(string name = "adder_driver", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(virtual adder_if)::get(this, "", "vif", vif))
        `uvm_fatal("DRV", "Could not get vif")
    endfunction

    virtual task run_phase(uvm_phase phase);
      forever begin
        seq_item_port.get_next_item(req);
        // Drive inputs to DUT
        @(posedge vif.clk);
        vif.a <= req.a;
        vif.b <= req.b;
        seq_item_port.item_done();
      end
    endtask
  endclass

  // Monitor
  class adder_monitor extends uvm_monitor;
    `uvm_component_utils(adder_monitor)

    virtual adder_if vif;
    uvm_analysis_port #(adder_item) item_collected_port;

    function new(string name = "adder_monitor", uvm_component parent = null);
      super.new(name, parent);
      item_collected_port = new("item_collected_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(virtual adder_if)::get(this, "", "vif", vif))
        `uvm_fatal("MON", "Could not get vif")
    endfunction

    virtual task run_phase(uvm_phase phase);
      adder_item item;
      forever begin
        @(posedge vif.clk);
        item = adder_item::type_id::create("item");
        item.a = vif.a;
        item.b = vif.b;
        @(posedge vif.clk); // Wait for next clock cycle to sample the output
        item.sum = vif.sum;
        item_collected_port.write(item);
      end
    endtask
  endclass

  // Scoreboard
  class adder_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(adder_scoreboard)

    uvm_analysis_imp #(adder_item, adder_scoreboard) item_collected_export;

    function new(string name = "adder_scoreboard", uvm_component parent = null);
      super.new(name, parent);
      item_collected_export = new("item_collected_export", this);
    endfunction

    virtual function void write(adder_item item);
      if(item.sum == item.a + item.b)
        `uvm_info("SCB", $sformatf("PASS: a=%0d, b=%0d, sum=%0d", item.a, item.b, item.sum), UVM_LOW)
      else
        `uvm_error("SCB", $sformatf("FAIL: a=%0d, b=%0d, sum=%0d", item.a, item.b, item.sum))
    endfunction
  endclass

  // Agent
  class adder_agent extends uvm_agent;
    `uvm_component_utils(adder_agent)

    adder_driver driver;
    adder_monitor monitor;
    uvm_sequencer #(adder_item) sequencer;

    function new(string name = "adder_agent", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      driver = adder_driver::type_id::create("driver", this);
      monitor = adder_monitor::type_id::create("monitor", this);
      sequencer = uvm_sequencer#(adder_item)::type_id::create("sequencer", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
  endclass

  // Environment
  class adder_env extends uvm_env;
    `uvm_component_utils(adder_env)

    adder_agent agent;
    adder_scoreboard scoreboard;

    function new(string name = "adder_env", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agent = adder_agent::type_id::create("agent", this);
      scoreboard = adder_scoreboard::type_id::create("scoreboard", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      agent.monitor.item_collected_port.connect(scoreboard.item_collected_export);
    endfunction
  endclass

  // Test
  class adder_test extends uvm_test;
    `uvm_component_utils(adder_test)

    adder_env env;

    function new(string name = "adder_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = adder_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
      adder_sequence seq;
      phase.raise_objection(this);
      seq = adder_sequence::type_id::create("seq");
      seq.start(env.agent.sequencer);
      phase.drop_objection(this);
    endtask
  endclass
endpackage

// Top module
module top;
  import uvm_pkg::*;
  import adder_pkg::*;

  // Instantiate interface
  adder_if vif();

  // Clock generation
  initial begin
    vif.clk = 0;
    forever #5 vif.clk = ~vif.clk;
  end

  // Instantiate DUT
  adder dut (
    .clk(vif.clk),
    .a(vif.a),
    .b(vif.b),
    .sum(vif.sum)
  );

  initial begin
    // Set interface in config db
    uvm_config_db#(virtual adder_if)::set(null, "*", "vif", vif);
    // Start UVM phases
    run_test("adder_test");
  end
endmodule
