// -----------------------------------------------------------------------------
// Module Name   : sha256_axi_wrapper
// Author        : Youngjin Kim
// Description   : AXI4-Lite/Stream interface wrapper for SHA-256 Core.
//                 Handles data padding, bus protocol, and secure access.
// Reference     : Micro_Architecture_Specification.md
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module sha256_axi_wrapper (
    input logic clk_i,
    input logic rst_n_i,

    input  logic [ 7:0] s_axi_awaddr,
    input  logic [ 2:0] s_axi_awprot,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,
    input  logic [31:0] s_axi_wdata,
    input  logic [ 3:0] s_axi_wstrb,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,
    output logic [ 1:0] s_axi_bresp,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,

    input  logic [ 7:0] s_axi_araddr,
    input  logic [ 2:0] s_axi_arprot,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,
    output logic [31:0] s_axi_rdata,
    output logic [ 1:0] s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,

    input  logic [31:0] s_axis_tdata,
    input  logic [ 3:0] s_axis_tkeep,
    input  logic        s_axis_tlast,
    input  logic        s_axis_tvalid,
    output logic        s_axis_tready,

    output logic irq_o
);

  localparam [2:0] S_IDLE = 3'd0;
  localparam [2:0] S_RCV = 3'd1;
  localparam [2:0] S_PAD_80 = 3'd2;
  localparam [2:0] S_PAD_LEN = 3'd3;
  localparam [2:0] S_START_CORE = 3'd4;
  localparam [2:0] S_WAIT_CORE = 3'd5;
  localparam [2:0] S_DONE = 3'd6;

  // 1. AXI4-Lite Channel
  logic         aw_latched;
  logic [  7:0] awaddr_reg;
  logic [  2:0] awprot_reg;
  logic         w_latched;
  logic [ 31:0] wdata_reg;
  logic [  3:0] wstrb_reg;
  logic         slv_reg_wen;
  logic [  1:0] bresp_reg;
  logic         ar_latched;
  logic [  7:0] araddr_reg;
  logic [  2:0] arprot_reg;
  logic         slv_reg_ren;
  logic [  1:0] rresp_reg;

  // 2. AXI4-Stream Channel
  logic [  2:0] valid_bytes;
  logic         axis_tkeep_invalid;
  logic         axis_tkeep_err;

  // 3. CSR Control & Status
  logic         ctrl_en;
  logic         ctrl_irq_en;
  logic         ctrl_soft_reset;
  logic         ctrl_start_pulse;
  logic         clear_done_pulse;
  logic         status_err_flag;
  logic         status_done;
  logic         transaction_active;
  logic         status_busy;
  logic [ 31:0] state_in_reg       [ 0:7];

  // 4. Core Interface
  logic         core_rst_n;
  logic         core_start;
  logic         core_ready;
  logic         core_busy;
  logic         core_done;
  logic         core_busy_w;
  logic [255:0] core_state_in;
  logic [511:0] core_block_reg;
  logic [255:0] core_state_out;

  // 5. Wrapper FSM & Padding Datapath
  logic [  2:0] state;
  logic [  2:0] nstate;
  logic [  2:0] ret_state;
  logic         block_pending;
  logic         first_block;
  logic [  6:0] byte_cnt;
  logic [  3:0] word_cnt;
  logic [ 63:0] msg_len;
  logic [  7:0] block_b            [0:63];
  logic [511:0] block_b_endian;
  logic [ 31:0] core_state_out_reg [ 0:7];

  /****************************************************************************/
  // AXI4-Lite Write Channel (AW, W, B)
  /****************************************************************************/
  assign slv_reg_wen = (aw_latched && w_latched && !s_axi_bvalid);
  assign s_axi_bresp = bresp_reg;

  always_ff @(posedge clk_i or negedge rst_n_i) begin : aw_latch_reg
    if (!rst_n_i) begin
      s_axi_awready <= 1'b0;
      aw_latched <= 1'b0;
      awaddr_reg <= 8'd0;
      awprot_reg <= 3'd0;
    end else begin
      if (s_axi_awvalid && !s_axi_awready && !aw_latched) begin
        s_axi_awready <= 1'b1;
        awaddr_reg <= s_axi_awaddr;
        awprot_reg <= s_axi_awprot;
      end else if (s_axi_awready) begin
        s_axi_awready <= 1'b0;
        aw_latched <= 1'b1;
      end else if (s_axi_bvalid && s_axi_bready) begin
        aw_latched <= 1'b0;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_n_i) begin : w_latch_reg
    if (!rst_n_i) begin
      s_axi_wready <= 1'b0;
      w_latched <= 1'b0;
      wdata_reg <= 32'd0;
      wstrb_reg <= 4'd0;
    end else begin
      if (s_axi_wvalid && !s_axi_wready && !w_latched) begin
        s_axi_wready <= 1'b1;
        wdata_reg <= s_axi_wdata;
        wstrb_reg <= s_axi_wstrb;
      end else if (s_axi_wready) begin
        s_axi_wready <= 1'b0;
        w_latched <= 1'b1;
      end else if (s_axi_bvalid && s_axi_bready) begin
        w_latched <= 1'b0;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_n_i) begin : bvalid_reg
    if (!rst_n_i) begin
      s_axi_bvalid <= 1'b0;
    end else begin
      if (aw_latched && w_latched && !s_axi_bvalid) begin
        s_axi_bvalid <= 1'b1;
      end else if (s_axi_bvalid && s_axi_bready) begin
        s_axi_bvalid <= 1'b0;
      end
    end
  end
  /****************************************************************************/
  // AXI4-Lite Read Channel (AR, R)
  /****************************************************************************/
  assign slv_reg_ren = (ar_latched && !s_axi_rvalid);
  assign s_axi_rresp = rresp_reg;

  always_ff @(posedge clk_i or negedge rst_n_i) begin : ar_latch_reg
    if (!rst_n_i) begin
      s_axi_arready <= 1'b0;
      ar_latched <= 1'b0;
      araddr_reg <= 8'd0;
      arprot_reg <= 3'd0;
    end else begin
      if (s_axi_arvalid && !s_axi_arready && !ar_latched) begin
        s_axi_arready <= 1'b1;
        araddr_reg <= s_axi_araddr;
        arprot_reg <= s_axi_arprot;
      end else if (s_axi_arready) begin
        s_axi_arready <= 1'b0;
        ar_latched <= 1'b1;
      end else if (s_axi_rvalid && s_axi_rready) begin
        ar_latched <= 1'b0;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_n_i) begin : rvalid_reg
    if (!rst_n_i) begin
      s_axi_rvalid <= 1'b0;
    end else begin
      if (ar_latched && !s_axi_rvalid) begin
        s_axi_rvalid <= 1'b1;
      end else if (s_axi_rvalid && s_axi_rready) begin
        s_axi_rvalid <= 1'b0;
      end
    end
  end


  /****************************************************************************/
  // AXI4-Stream Receive & TKEEP Check
  /****************************************************************************/
  assign s_axis_tready = (state == S_RCV) && ctrl_en && !ctrl_soft_reset;
  assign axis_tkeep_invalid = s_axis_tlast ?
      !((s_axis_tkeep == 4'b0001) || (s_axis_tkeep == 4'b0011) ||
        (s_axis_tkeep == 4'b0111) || (s_axis_tkeep == 4'b1111)) :
      (s_axis_tkeep != 4'b1111);
  assign axis_tkeep_err = (state == S_RCV) && s_axis_tvalid && s_axis_tready && axis_tkeep_invalid;
  assign valid_bytes = {2'b00, s_axis_tkeep[0]} + {2'b00, s_axis_tkeep[1]} +
                       {2'b00, s_axis_tkeep[2]} + {2'b00, s_axis_tkeep[3]};

  /****************************************************************************/
  // SHA-256 Core Interface & Endian Swap
  /****************************************************************************/
  sha256_core u_core (
      .clk_i      (clk_i),
      .rst_n_i    (core_rst_n),
      .start_i    (core_start),
      .state_in_i (core_state_in),
      .block_i    (core_block_reg),
      .ready_o    (core_ready),
      .busy_o     (core_busy),
      .done_o     (core_done),
      .state_out_o(core_state_out)
  );
  genvar j;  // MAS 4.4.4 Completion and Endianness Conversion
  generate
    for (j = 0; j < 64; j = j + 1) begin : gen_endian_conversion
      assign block_b_endian[511-j*8-:8] = block_b[j];
    end
  endgenerate

  assign core_start = (state == S_START_CORE);
  assign core_state_in = first_block ?
        {state_in_reg[0], state_in_reg[1], state_in_reg[2], state_in_reg[3],
         state_in_reg[4], state_in_reg[5], state_in_reg[6], state_in_reg[7]} :
        {core_state_out_reg[0], core_state_out_reg[1], core_state_out_reg[2], core_state_out_reg[3],
         core_state_out_reg[4], core_state_out_reg[5], core_state_out_reg[6], core_state_out_reg[7]};
  assign core_busy_w = (core_busy && !core_done) || core_start;

  /****************************************************************************/
  // CSR Write & Protection Logic
  /****************************************************************************/
  assign irq_o = (status_done | status_err_flag) & ctrl_irq_en;
  assign status_busy = transaction_active | core_busy;
  assign clear_done_pulse = slv_reg_wen && !awprot_reg[1] && (awaddr_reg == 8'h0C) &&
                            wstrb_reg[0] && wdata_reg[1];

  always_ff @(posedge clk_i or negedge rst_n_i) begin : csr_write_reg
    if (!rst_n_i) begin
      core_rst_n       <= 1'b0;
      ctrl_en          <= 1'b0;
      ctrl_irq_en      <= 1'b0;
      ctrl_soft_reset  <= 1'b0;
      ctrl_start_pulse <= 1'b0;
      status_err_flag  <= 1'b0;
      bresp_reg        <= 2'b00;

      state_in_reg[0]  <= 32'h6a09e667;
      state_in_reg[1]  <= 32'hbb67ae85;
      state_in_reg[2]  <= 32'h3c6ef372;
      state_in_reg[3]  <= 32'ha54ff53a;
      state_in_reg[4]  <= 32'h510e527f;
      state_in_reg[5]  <= 32'h9b05688c;
      state_in_reg[6]  <= 32'h1f83d9ab;
      state_in_reg[7]  <= 32'h5be0cd19;
    end else begin
      core_rst_n       <= (~ctrl_soft_reset) & (~axis_tkeep_err);
      ctrl_start_pulse <= 1'b0;

      if (ctrl_soft_reset) begin
        ctrl_soft_reset <= 1'b0;
        status_err_flag <= 1'b0;
        state_in_reg[0] <= 32'h6a09e667;
        state_in_reg[1] <= 32'hbb67ae85;
        state_in_reg[2] <= 32'h3c6ef372;
        state_in_reg[3] <= 32'ha54ff53a;
        state_in_reg[4] <= 32'h510e527f;
        state_in_reg[5] <= 32'h9b05688c;
        state_in_reg[6] <= 32'h1f83d9ab;
        state_in_reg[7] <= 32'h5be0cd19;
      end

      if (slv_reg_wen) begin
        bresp_reg <= 2'b00;

        // MAS 4.3.1 PROT Firewall & 4.3.3 Word-Alignment Check
        if ((awprot_reg[1] == 1'b1) || (awaddr_reg[1:0] != 2'b00)) begin
          bresp_reg <= 2'b10;  // SLVERR
        end else begin
          case (awaddr_reg[7:2])
            6'h01: begin
              if (status_busy) begin
                // MAS 4.3.2 Atomicity Violation & Hang Recovery
                if (wstrb_reg[0] && wdata_reg[3]) begin
                  ctrl_soft_reset <= 1'b1;
                end else begin
                  bresp_reg <= 2'b10;
                end
              end else if (wstrb_reg[0]) begin
                ctrl_en          <= wdata_reg[0];
                ctrl_irq_en      <= wdata_reg[1];
                ctrl_start_pulse <= wdata_reg[2];
                ctrl_soft_reset  <= wdata_reg[3];
              end
            end
            6'h03: begin
              if (wstrb_reg[0] && wdata_reg[2]) begin
                status_err_flag <= 1'b0;
              end
            end
            6'h20, 6'h21, 6'h22, 6'h23, 6'h24, 6'h25, 6'h26, 6'h27: begin
              if (status_busy) begin
                bresp_reg <= 2'b10;
              end else begin
                if (wstrb_reg[0]) state_in_reg[awaddr_reg[4:2]][7:0] <= wdata_reg[7:0];
                if (wstrb_reg[1]) state_in_reg[awaddr_reg[4:2]][15:8] <= wdata_reg[15:8];
                if (wstrb_reg[2]) state_in_reg[awaddr_reg[4:2]][23:16] <= wdata_reg[23:16];
                if (wstrb_reg[3]) state_in_reg[awaddr_reg[4:2]][31:24] <= wdata_reg[31:24];
              end
            end
            6'h00, 6'h02, 6'h04, 6'h05, 6'h08, 6'h09, 6'h0A, 6'h0B, 6'h0C, 6'h0D, 6'h0E, 6'h0F: begin
              bresp_reg <= 2'b10;
            end
            default: begin
              bresp_reg <= 2'b11;
            end
          endcase
        end
      end
      if (axis_tkeep_err) begin
        status_err_flag <= 1'b1;
      end
    end
  end

  /****************************************************************************/
  // CSR Read & Decode Logic
  /****************************************************************************/
  always_ff @(posedge clk_i or negedge rst_n_i) begin : csr_read_reg
    if (!rst_n_i) begin
      s_axi_rdata <= 32'd0;
      rresp_reg   <= 2'b00;
    end else begin
      if (slv_reg_ren) begin
        rresp_reg <= 2'b00;
        if ((arprot_reg[1] == 1'b1) || (araddr_reg[1:0] != 2'b00)) begin
          s_axi_rdata <= 32'd0;
          rresp_reg   <= 2'b10;
        end else begin
          case (araddr_reg[7:2])
            6'h00: s_axi_rdata <= 32'h41749591;
            6'h01: s_axi_rdata <= {30'd0, ctrl_irq_en, ctrl_en};
            6'h02: s_axi_rdata <= {29'd0, status_err_flag, status_done, status_busy};
            6'h04: s_axi_rdata <= msg_len[31:0];
            6'h05: s_axi_rdata <= msg_len[63:32];
            6'h08: s_axi_rdata <= core_state_out_reg[0];
            6'h09: s_axi_rdata <= core_state_out_reg[1];
            6'h0A: s_axi_rdata <= core_state_out_reg[2];
            6'h0B: s_axi_rdata <= core_state_out_reg[3];
            6'h0C: s_axi_rdata <= core_state_out_reg[4];
            6'h0D: s_axi_rdata <= core_state_out_reg[5];
            6'h0E: s_axi_rdata <= core_state_out_reg[6];
            6'h0F: s_axi_rdata <= core_state_out_reg[7];
            6'h20: s_axi_rdata <= state_in_reg[0];
            6'h21: s_axi_rdata <= state_in_reg[1];
            6'h22: s_axi_rdata <= state_in_reg[2];
            6'h23: s_axi_rdata <= state_in_reg[3];
            6'h24: s_axi_rdata <= state_in_reg[4];
            6'h25: s_axi_rdata <= state_in_reg[5];
            6'h26: s_axi_rdata <= state_in_reg[6];
            6'h27: s_axi_rdata <= state_in_reg[7];
            default: begin
              s_axi_rdata <= 32'd0;
              rresp_reg   <= 2'b11;
            end
          endcase
        end
      end
    end
  end

  /****************************************************************************/
  // Wrapper FSM State Register
  /****************************************************************************/
  always_ff @(posedge clk_i or negedge rst_n_i) begin : fsm_state_reg
    if (!rst_n_i) begin
      state <= S_IDLE;
    end else if (ctrl_soft_reset) begin
      state <= S_IDLE;
    end else begin
      state <= nstate;
    end
  end

  /****************************************************************************/
  // Wrapper FSM Next-State Logic
  /****************************************************************************/
  always_comb begin : fsm_next_state
    nstate = state;
    unique case (state)
      S_IDLE: begin
        if (ctrl_start_pulse && ctrl_en) nstate = S_RCV;
      end

      S_RCV: begin
        if (s_axis_tvalid && s_axis_tready) begin
          if (axis_tkeep_invalid) begin
            nstate = S_IDLE;
          end else if (byte_cnt + valid_bytes == 7'd64) begin
            nstate = core_busy_w ? S_WAIT_CORE : S_START_CORE;
          end else if (s_axis_tlast) begin
            nstate = S_PAD_80;
          end
        end
      end

      S_PAD_80: begin
        nstate = (byte_cnt + 7'd1 > 7'd56) ? (core_busy_w ? S_WAIT_CORE : S_START_CORE) : S_PAD_LEN;
      end

      S_PAD_LEN: begin
        nstate = core_busy_w ? S_WAIT_CORE : S_START_CORE;
      end

      S_START_CORE: begin
        nstate = (ret_state == S_DONE) ? S_WAIT_CORE : ret_state;
      end

      S_WAIT_CORE: begin
        nstate = (core_done) ? (block_pending ? S_START_CORE : ret_state) : S_WAIT_CORE;
      end

      S_DONE: begin
        nstate = S_IDLE;
      end

      default: begin
        nstate = S_IDLE;
      end
    endcase
  end


  /****************************************************************************/
  // Wrapper Padding & Buffer Datapath
  // ret_state, block_pending, transaction_active, status_done, first_block,
  // msg_len, byte_cnt, core_block_reg, block_b, core_state_out_reg
  /****************************************************************************/
  assign word_cnt = byte_cnt[5:2];
  always_ff @(posedge clk_i or negedge rst_n_i) begin : fsm_datapath_reg
    if (!rst_n_i) begin
      ret_state          <= S_IDLE;
      block_pending      <= 1'b0;
      transaction_active <= 1'b0;
      status_done        <= 1'b0;
      first_block        <= 1'b1;
      msg_len            <= 64'd0;
      byte_cnt           <= 7'd0;
      core_block_reg     <= 512'd0;
      for (int i = 0; i < 64; i = i + 1) block_b[i] <= 8'h00;
      for (int i = 0; i < 8; i = i + 1) core_state_out_reg[i] <= 32'd0;
    end else begin
      if (clear_done_pulse) begin
        status_done <= 1'b0;
      end

      if (ctrl_soft_reset) begin
        ret_state          <= S_IDLE;
        block_pending      <= 1'b0;
        first_block        <= 1'b1;
        transaction_active <= 1'b0;
        status_done        <= 1'b0;
        byte_cnt           <= 7'd0;
        msg_len            <= 64'd0;
        core_block_reg     <= 512'd0;
        for (int i = 0; i < 64; i = i + 1) block_b[i] <= 8'h00;
        for (int i = 0; i < 8; i = i + 1) core_state_out_reg[i] <= 32'd0;
      end else begin
        if (core_done && !axis_tkeep_err) begin
          first_block           <= 1'b0;
          core_state_out_reg[0] <= core_state_out[255:224];
          core_state_out_reg[1] <= core_state_out[223:192];
          core_state_out_reg[2] <= core_state_out[191:160];
          core_state_out_reg[3] <= core_state_out[159:128];
          core_state_out_reg[4] <= core_state_out[127:96];
          core_state_out_reg[5] <= core_state_out[95:64];
          core_state_out_reg[6] <= core_state_out[63:32];
          core_state_out_reg[7] <= core_state_out[31:0];
        end

        unique case (state)
          S_IDLE: begin
            if (ctrl_start_pulse && ctrl_en) begin
              block_pending      <= 1'b0;
              first_block        <= 1'b1;
              transaction_active <= 1'b1;
              status_done        <= 1'b0;
              msg_len            <= 64'd0;
              byte_cnt           <= 7'd0;
              core_block_reg     <= 512'd0;
              for (int i = 0; i < 64; i = i + 1) block_b[i] <= 8'h00;
            end
          end

          S_RCV: begin
            if (s_axis_tvalid && s_axis_tready) begin
              if (axis_tkeep_invalid) begin
                ret_state          <= S_IDLE;
                block_pending      <= 1'b0;
                first_block        <= 1'b1;
                transaction_active <= 1'b0;
                status_done        <= 1'b0;
                byte_cnt           <= 7'd0;
                msg_len            <= 64'd0;
                core_block_reg     <= 512'd0;
                for (int i = 0; i < 64; i = i + 1) block_b[i] <= 8'h00;
                for (int i = 0; i < 8; i = i + 1) core_state_out_reg[i] <= 32'd0;
              end else begin
                block_b[{word_cnt, 2'b00}] <= s_axis_tdata[7:0];
                if (s_axis_tkeep[1]) block_b[{word_cnt, 2'b01}] <= s_axis_tdata[15:8];
                if (s_axis_tkeep[2]) block_b[{word_cnt, 2'b10}] <= s_axis_tdata[23:16];
                if (s_axis_tkeep[3]) block_b[{word_cnt, 2'b11}] <= s_axis_tdata[31:24];

                byte_cnt <= byte_cnt + valid_bytes;
                msg_len  <= msg_len + {58'd0, valid_bytes, 3'b000};

                if (byte_cnt + valid_bytes == 7'd64) begin
                  ret_state     <= s_axis_tlast ? S_PAD_80 : S_RCV;
                  block_pending <= core_busy_w;
                end
              end
            end
          end

          S_PAD_80: begin
            block_b[byte_cnt] <= 8'h80;
            byte_cnt          <= byte_cnt + 7'd1;
            if (byte_cnt + 7'd1 > 7'd56) begin
              ret_state     <= S_PAD_LEN;
              block_pending <= core_busy_w;
            end
          end

          S_PAD_LEN: begin
            block_b[56]   <= msg_len[63:56];
            block_b[57]   <= msg_len[55:48];
            block_b[58]   <= msg_len[47:40];
            block_b[59]   <= msg_len[39:32];
            block_b[60]   <= msg_len[31:24];
            block_b[61]   <= msg_len[23:16];
            block_b[62]   <= msg_len[15:8];
            block_b[63]   <= msg_len[7:0];
            ret_state     <= S_DONE;
            block_pending <= core_busy_w;
          end

          S_START_CORE: begin
            core_block_reg <= block_b_endian;
            byte_cnt       <= 7'd0;
            for (int i = 0; i < 64; i = i + 1) block_b[i] <= 8'h00;
          end

          S_WAIT_CORE: begin
            if (core_done && block_pending) begin
              block_pending <= 1'b0;
            end
          end

          S_DONE: begin
            status_done        <= 1'b1;
            transaction_active <= 1'b0;
          end

          default: ;
        endcase
      end
    end
  end

endmodule
