`include "svunit_defines.svh"
import svunit_pkg::*;

// SVUnit module must end with '_unit_test'
module my_cov_unit_test;

  string name = "my_cov_ut";
  svunit_testcase svunit_ut;

  // This is the UUT that we're
  // running the Unit Tests on
  my_cov dut;

  // Create the interface
  logic clock;
  logic select;
  logic [3:0] data;
  my_interface my_interface(.*);

  // Build - runs once
  function void build();
    svunit_ut = new(name);
    dut = my_cov::type_id::create("dut", null);
    dut._if = my_interface;
  endfunction

  // Setup before each test
  task setup();
    svunit_ut.setup();
    // Stop coverage collection
    dut.my_cg.my_cp.stop();
    // Clear the interface signals
    clock = 0;
    select = 0;
    data = 0;
    #1;
  endtask

  // Teardown after each test
  task teardown();
    svunit_ut.teardown();
  endtask

  // All tests are defined between the
  // SVUNIT_TESTS_BEGIN/END macros
  //
  // Each individual test must be
  // defined between `SVTEST(_NAME_) and `SVTEST_END
  `SVUNIT_TESTS_BEGIN

  // Test that coverage is NOT hit when select is low.
  `SVTEST(no_coverage)
    // Run coverage class
    fork: run
      dut.run_phase(null);
    join_none

    // Start coverage collection
    dut.my_cg.my_cp.start();
    // Initial coverage should be 0
    `FAIL_IF(dut.my_cg.my_cp.get_coverage());

    // Toggle interface pins
    data = 3;
    toggle_clock();
    data = 4;
    toggle_clock();

    // Coverage should still be 0
    `FAIL_IF(dut.my_cg.my_cp.get_coverage());

    // Stop coverage class
    disable run;
  `SVTEST_END

  // Test that full coverage is hit when select is high.
  `SVTEST(full_coverage)
    // Run coverage class
    fork: run
      dut.run_phase(null);
    join_none

    // Start coverage collection
    dut.my_cg.my_cp.start();
    // Initial coverage should be 0
    `FAIL_IF(dut.my_cg.my_cp.get_coverage());

    // Toggle interface pins and check that all coverage is hit
    select = 1;
    for (int i = 0; i < 16; i += 1) begin
      data = i;
      toggle_clock();
      if (i == 7) begin
        // Half the coverage should be hit
        `FAIL_UNLESS(dut.my_cg.my_cp.get_coverage() == 50);
      end
    end

    // Coverage should be 100
    `FAIL_UNLESS(dut.my_cg.my_cp.get_coverage() == 100);

    // Stop coverage class
    disable run;
  `SVTEST_END


  `SVUNIT_TESTS_END

  task toggle_clock();
    repeat (2) #5 clock = ~clock;
  endtask

  initial begin
    // Dump waves
    $dumpvars(0, my_cov_unit_test);
  end

endmodule
