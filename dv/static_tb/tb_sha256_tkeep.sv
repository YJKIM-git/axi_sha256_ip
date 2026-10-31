`timescale 1ns / 1ps

module tb_sha256_tkeep;

  logic        clk_i;
  logic        rst_n_i;

  logic [ 7:0] s_axi_awaddr;
  logic [ 2:0] s_axi_awprot;
  logic        s_axi_awvalid;
  logic        s_axi_awready;
  logic [31:0] s_axi_wdata;
  logic [ 3:0] s_axi_wstrb;
  logic        s_axi_wvalid;
  logic        s_axi_wready;
  logic [ 1:0] s_axi_bresp;
  logic        s_axi_bvalid;
  logic        s_axi_bready;

  logic [ 7:0] s_axi_araddr;
  logic [ 2:0] s_axi_arprot;
  logic        s_axi_arvalid;
  logic        s_axi_arready;
  logic [31:0] s_axi_rdata;
  logic [ 1:0] s_axi_rresp;
  logic        s_axi_rvalid;
  logic        s_axi_rready;

  logic [31:0] s_axis_tdata;
  logic [ 3:0] s_axis_tkeep;
  logic        s_axis_tlast;
  logic        s_axis_tvalid;
  logic        s_axis_tready;
  logic        irq_o;

  localparam logic [7:0] ADDR_CTRL = 8'h04;
  localparam logic [7:0] ADDR_STATUS = 8'h08;
  localparam logic [7:0] ADDR_INTCLEAR = 8'h0C;
  localparam logic [7:0] ADDR_MSG_LEN_LO = 8'h10;
  localparam logic [7:0] ADDR_MSG_LEN_HI = 8'h14;
  localparam logic [7:0] ADDR_DIGEST_0 = 8'h20;

  localparam logic [255:0] GOLDEN_ABC_DIGEST = {
    32'hba7816bf,
    32'h8f01cfea,
    32'h414140de,
    32'h5dae2223,
    32'hb00361a3,
    32'h96177a9c,
    32'hb410ff61,
    32'hf20015ad
  };

  int err_cnt = 0;
  int pass_cnt = 0;

  sha256_axi_wrapper DUT (
      .clk_i        (clk_i),
      .rst_n_i      (rst_n_i),
      .s_axi_awaddr (s_axi_awaddr),
      .s_axi_awprot (s_axi_awprot),
      .s_axi_awvalid(s_axi_awvalid),
      .s_axi_awready(s_axi_awready),
      .s_axi_wdata  (s_axi_wdata),
      .s_axi_wstrb  (s_axi_wstrb),
      .s_axi_wvalid (s_axi_wvalid),
      .s_axi_wready (s_axi_wready),
      .s_axi_bresp  (s_axi_bresp),
      .s_axi_bvalid (s_axi_bvalid),
      .s_axi_bready (s_axi_bready),
      .s_axi_araddr (s_axi_araddr),
      .s_axi_arprot (s_axi_arprot),
      .s_axi_arvalid(s_axi_arvalid),
      .s_axi_arready(s_axi_arready),
      .s_axi_rdata  (s_axi_rdata),
      .s_axi_rresp  (s_axi_rresp),
      .s_axi_rvalid (s_axi_rvalid),
      .s_axi_rready (s_axi_rready),
      .s_axis_tdata (s_axis_tdata),
      .s_axis_tkeep (s_axis_tkeep),
      .s_axis_tlast (s_axis_tlast),
      .s_axis_tvalid(s_axis_tvalid),
      .s_axis_tready(s_axis_tready),
      .irq_o        (irq_o)
  );

  initial begin
    clk_i = 1'b0;
    forever #5 clk_i = ~clk_i;
  end

  function automatic bit is_valid_tkeep(input logic tlast, input logic [3:0] tkeep);
    if (!tlast) return (tkeep == 4'b1111);
    else return (tkeep inside {4'b0001, 4'b0011, 4'b0111, 4'b1111});
  endfunction

  // White-box SVA for protocol violation detection, state recovery, and buffer zeroization
  property p_tkeep_invalid_decode;
    @(posedge clk_i) disable iff (!rst_n_i)
    (DUT.state == 3'd1 && s_axis_tvalid && s_axis_tready) |->
    (DUT.axis_tkeep_invalid == !is_valid_tkeep(
        s_axis_tlast, s_axis_tkeep
    ));
  endproperty

  property p_tkeep_err_abort_fsm;
    @(posedge clk_i) disable iff (!rst_n_i)
    DUT.axis_tkeep_err |=>
    (DUT.state == 3'd0) && (DUT.status_err_flag == 1'b1) &&
    (DUT.transaction_active == 1'b0) && (DUT.status_busy == 1'b0) &&
    (DUT.status_done == 1'b0) && (s_axis_tready == 1'b0);
  endproperty

  property p_tkeep_err_zeroize_datapath;
    @(posedge clk_i) disable iff (!rst_n_i)
    DUT.axis_tkeep_err |=>
    (DUT.byte_cnt == 7'd0) && (DUT.msg_len == 64'd0) &&
    (DUT.first_block == 1'b1) && (DUT.core_block == 512'd0);
  endproperty

  property p_tkeep_err_no_core_trigger;
    @(posedge clk_i) disable iff (!rst_n_i)
    DUT.axis_tkeep_err |=> (!DUT.core_start && !DUT.core_busy);
  endproperty

  property p_w1c_clr_err;
    @(posedge clk_i) disable iff (!rst_n_i)
    (DUT.slv_reg_wren && !DUT.awprot_reg[1] && (DUT.awaddr_reg[7:2] == 6'h03) &&
     DUT.wstrb_reg[0] && DUT.wdata_reg[2] && !DUT.axis_tkeep_err) |=>
    (DUT.status_err_flag == 1'b0);
  endproperty

  a_tkeep_invalid_decode :
  assert property (p_tkeep_invalid_decode)
  else begin
    err_cnt++;
    $error("[SVA_FAIL] p_tkeep_invalid_decode");
  end
  a_tkeep_err_abort_fsm :
  assert property (p_tkeep_err_abort_fsm)
  else begin
    err_cnt++;
    $error("[SVA_FAIL] p_tkeep_err_abort_fsm");
  end
  a_tkeep_err_zeroize :
  assert property (p_tkeep_err_zeroize_datapath)
  else begin
    err_cnt++;
    $error("[SVA_FAIL] p_tkeep_err_zeroize_datapath");
  end
  a_tkeep_err_no_core :
  assert property (p_tkeep_err_no_core_trigger)
  else begin
    err_cnt++;
    $error("[SVA_FAIL] p_tkeep_err_no_core_trigger");
  end
  a_w1c_clr_err :
  assert property (p_w1c_clr_err)
  else begin
    err_cnt++;
    $error("[SVA_FAIL] p_w1c_clr_err");
  end

  c_null_beat_mid :
  cover property (@(posedge clk_i) DUT.axis_tkeep_err && !s_axis_tlast && (s_axis_tkeep == 4'b0000));
  c_null_beat_last :
  cover property (@(posedge clk_i) DUT.axis_tkeep_err && s_axis_tlast && (s_axis_tkeep == 4'b0000));
  c_partial_beat_mid :
  cover property (@(posedge clk_i) DUT.axis_tkeep_err && !s_axis_tlast && (s_axis_tkeep != 4'b0000));
  c_sparse_beat_last :
  cover property (@(posedge clk_i) DUT.axis_tkeep_err && s_axis_tlast && (s_axis_tkeep != 4'b0000));

  task automatic reset_dut();
    rst_n_i       = 1'b0;
    s_axi_awaddr  = 8'd0;
    s_axi_awprot  = 3'd0;
    s_axi_awvalid = 1'b0;
    s_axi_wdata   = 32'd0;
    s_axi_wstrb   = 4'd0;
    s_axi_wvalid  = 1'b0;
    s_axi_bready  = 1'b0;
    s_axi_araddr  = 8'd0;
    s_axi_arprot  = 3'd0;
    s_axi_arvalid = 1'b0;
    s_axi_rready  = 1'b0;
    s_axis_tdata  = 32'd0;
    s_axis_tkeep  = 4'd0;
    s_axis_tlast  = 1'b0;
    s_axis_tvalid = 1'b0;
    repeat (20) @(posedge clk_i);
    #1ns rst_n_i = 1'b1;
    repeat (5) @(posedge clk_i);
  endtask

  task automatic axil_write(input logic [7:0] addr, input logic [31:0] data,
                            output logic [1:0] resp);
    @(posedge clk_i);
    s_axi_awaddr  <= addr;
    s_axi_awprot  <= 3'b000;
    s_axi_awvalid <= 1'b1;
    s_axi_wdata   <= data;
    s_axi_wstrb   <= 4'hF;
    s_axi_wvalid  <= 1'b1;
    s_axi_bready  <= 1'b1;
    do @(posedge clk_i); while (!(s_axi_awready && s_axi_wready));
    s_axi_awvalid <= 1'b0;
    s_axi_wvalid  <= 1'b0;
    do @(posedge clk_i); while (!s_axi_bvalid);
    resp = s_axi_bresp;
    s_axi_bready <= 1'b0;
  endtask

  task automatic axil_read(input logic [7:0] addr, output logic [31:0] data,
                           output logic [1:0] resp);
    @(posedge clk_i);
    s_axi_araddr  <= addr;
    s_axi_arprot  <= 3'b000;
    s_axi_arvalid <= 1'b1;
    s_axi_rready  <= 1'b1;
    do @(posedge clk_i); while (!s_axi_arready);
    s_axi_arvalid <= 1'b0;
    do @(posedge clk_i); while (!s_axi_rvalid);
    data = s_axi_rdata;
    resp = s_axi_rresp;
    s_axi_rready <= 1'b0;
  endtask

  task automatic axis_send_beat(input logic [31:0] data, input logic [3:0] keep, input logic last);
    @(posedge clk_i);
    s_axis_tdata  <= data;
    s_axis_tkeep  <= keep;
    s_axis_tlast  <= last;
    s_axis_tvalid <= 1'b1;
    do @(posedge clk_i); while (!s_axis_tready);
    s_axis_tvalid <= 1'b0;
    s_axis_tkeep  <= 4'b0000;
    s_axis_tlast  <= 1'b0;
  endtask

  task automatic start_transaction();
    logic [1:0] resp;
    axil_write(ADDR_CTRL, 32'h0000_0003, resp);
    axil_write(ADDR_CTRL, 32'h0000_0007, resp);
    while (!s_axis_tready) @(posedge clk_i);
  endtask

  // Pre-load 1 valid beat before error injection to verify buffer & counter wipe
  task automatic run_invalid_tkeep_case(input string tag, input bit preload_valid_beat,
                                        input logic tlast_val, input logic [3:0] tkeep_val);
    logic [31:0] rdata, len_lo, len_hi;
    logic [1:0] resp;

    start_transaction();

    if (preload_valid_beat) begin
      axis_send_beat(32'hDEAD_BEEF, 4'b1111, 1'b0);
      @(posedge clk_i);
      if (DUT.byte_cnt != 7'd4 || DUT.msg_len != 64'd32 || DUT.core_block[511:480] == 32'd0) begin
        err_cnt++;
        $error("[%s] Preload failed: byte_cnt=%0d, msg_len=%0d", tag, DUT.byte_cnt, DUT.msg_len);
      end
    end

    axis_send_beat(32'hC0DE_0000, tkeep_val, tlast_val);

    axil_read(ADDR_STATUS, rdata, resp);
    axil_read(ADDR_MSG_LEN_LO, len_lo, resp);
    axil_read(ADDR_MSG_LEN_HI, len_hi, resp);

    if (rdata !== 32'h0000_0004 || len_lo !== 32'd0 || len_hi !== 32'd0 || DUT.core_block !== 512'd0) begin
      err_cnt++;
      $error("[%s] FAIL (tlast=%0b, tkeep=4'b%04b) -> STATUS=0x%08h, LEN=%0d, BLOCK_ZERO=%0b", tag,
             tlast_val, tkeep_val, rdata, {len_hi, len_lo}, (DUT.core_block == 512'd0));
    end else begin
      pass_cnt++;
      $display(
          "[PASS] %-22s | tlast=%0b | tkeep=4'b%04b | STATUS=0x%08h (ERR_PRT=1, BUSY=0) | BUF_WIPED=1",
          tag, tlast_val, tkeep_val, rdata);
    end

    axil_write(ADDR_INTCLEAR, 32'h0000_0004, resp);
    axil_read(ADDR_STATUS, rdata, resp);
    if (rdata !== 32'h0000_0000) begin
      err_cnt++;
      $error("[%s] CLR_ERR failed: STATUS=0x%08h", tag, rdata);
    end
  endtask

  task automatic verify_post_error_recovery_abc();
    logic [255:0] actual_digest;
    logic [ 31:0] rdata;
    logic [  1:0] resp;

    start_transaction();
    axis_send_beat(32'h0063_6261, 4'b0111, 1'b1);

    while (!irq_o) @(posedge clk_i);

    for (int idx = 0; idx < 8; idx++) begin
      axil_read(ADDR_DIGEST_0 + idx * 4, rdata, resp);
      actual_digest[255-idx*32-:32] = rdata;
    end

    axil_read(ADDR_MSG_LEN_LO, rdata, resp);
    if (actual_digest !== GOLDEN_ABC_DIGEST || rdata !== 32'd24) begin
      err_cnt++;
      $error("[RECOVERY_ABC] Digest mismatch! Expected=%064h, Actual=%064h, Len=%0d",
             GOLDEN_ABC_DIGEST, actual_digest, rdata);
    end else begin
      pass_cnt++;
      $display(
          "[PASS] POST_ERR_RECOVERY_ABC  | tlast=1 | tkeep=4'b0111 | DIGEST=%08h...%08h (MATCH)",
          actual_digest[255:224], actual_digest[31:0]);
    end

    axil_write(ADDR_INTCLEAR, 32'h0000_0002, resp);
  endtask

  initial begin
    $display(
        "=========================================================================================");
    $display(" SHA-256 AXI4-Stream TKEEP Protocol Violation & Null Beat Directed Testbench");
    $display(
        "=========================================================================================");

    reset_dut();

    $display(
        "\n--- [Phase 1] Dedicated Null Beat (TKEEP = 4'b0000) Verification ([WV-AXIS-09] Closure) ---");
    run_invalid_tkeep_case("NULL_MID_PKT_PRELOAD", 1'b1, 1'b0, 4'b0000);
    run_invalid_tkeep_case("NULL_LAST_PKT_PRELOAD", 1'b1, 1'b1, 4'b0000);
    run_invalid_tkeep_case("NULL_SINGLE_BEAT_0B", 1'b0, 1'b1, 4'b0000);

    $display("\n--- [Phase 2] Exhaustive 27-Pattern Invalid (TLAST, TKEEP) Truth-Table Sweep ---");
    for (int tlast_i = 0; tlast_i <= 1; tlast_i++) begin
      for (int tkeep_i = 0; tkeep_i < 16; tkeep_i++) begin
        if (!is_valid_tkeep(tlast_i[0], tkeep_i[3:0])) begin
          run_invalid_tkeep_case($sformatf("SWEEP_L%0d_K%02d", tlast_i, tkeep_i), 1'b1, tlast_i[0],
                                 tkeep_i[3:0]);
        end
      end
    end

    $display("\n--- [Phase 3] Post-Error Recovery & Golden Hash Verification ---");
    verify_post_error_recovery_abc();

    #50ns;
    $display(
        "=========================================================================================");
    $display(" TEST SUMMARY: PASS = %0d / 31, ERROR = %0d", pass_cnt, err_cnt);
    if (err_cnt == 0 && pass_cnt == 31) $display(" === SHA256 DIRECTED TKEEP TEST PASSED ===");
    else $display(" === SHA256 DIRECTED TKEEP TEST FAILED ===");
    $display(
        "=========================================================================================");
    $finish;
  end

  // Optional waveform dump block for documentation figure extraction
  initial begin
    $dumpfile("tb_sha256_tkeep_figure.vcd");
    $dumpvars(0, tb_sha256_tkeep.clk_i, tb_sha256_tkeep.rst_n_i, tb_sha256_tkeep.s_axis_tvalid,
              tb_sha256_tkeep.s_axis_tready, tb_sha256_tkeep.s_axis_tdata,
              tb_sha256_tkeep.s_axis_tkeep, tb_sha256_tkeep.s_axis_tlast, tb_sha256_tkeep.DUT.state,
              tb_sha256_tkeep.DUT.axis_tkeep_invalid, tb_sha256_tkeep.DUT.axis_tkeep_err,
              tb_sha256_tkeep.DUT.status_busy, tb_sha256_tkeep.DUT.status_err_flag,
              tb_sha256_tkeep.DUT.byte_cnt, tb_sha256_tkeep.DUT.msg_len,
              tb_sha256_tkeep.DUT.block_b[0], tb_sha256_tkeep.DUT.clear_done_pulse);
  end

endmodule
