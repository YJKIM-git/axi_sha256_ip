//------------------------------------------------------------
//   Copyright 2010-2018 Mentor Graphics Corporation
//   All Rights Reserved Worldwide
//
//   Licensed under the Apache License, Version 2.0 (the
//   "License"); you may not use this file except in
//   compliance with the License.  You may obtain a copy of
//   the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in
//   writing, software distributed under the License is
//   distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
//   CONDITIONS OF ANY KIND, either express or implied.  See
//   the License for the specific language governing
//   permissions and limitations under the License.
//------------------------------------------------------------
//   Copyright 2026 Youngjin Kim
//
//   Modifications:
//   - Adopted the UVM architectural framework from the original APB VIP.
//   - Implements the SHA-256 block-level environment and analysis connections.
//------------------------------------------------------------------------------

// Initial block-level environment integration scaffold.
class sha256_env extends uvm_env;
  `uvm_component_utils(sha256_env)

  sha256_env_config                      m_cfg;

  axi4lite_agent                         m_axi4lite_agent;
  axis_agent                             m_axis_agent;
  core_agent                             m_core_agent;

  sha256_scoreboard                      m_scoreboard;
  sha256_csr_coverage                    m_csr_coverage;
  sha256_overall_coverage                m_overall_coverage;

  reg2axi4lite_adapter                   m_reg2axi4lite;
  uvm_reg_predictor #(axi4lite_seq_item) m_axi4lite2reg_predictor;

  extern function new(string name = "sha256_env", uvm_component parent = null);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);

endclass : sha256_env

function sha256_env::new(string name = "sha256_env", uvm_component parent = null);
  super.new(name, parent);
endfunction

function void sha256_env::build_phase(uvm_phase phase);
  super.build_phase(phase);

  m_cfg = sha256_env_config::get_config(this);
  if (m_cfg == null) begin
    `uvm_fatal("CFG_ERR", "sha256_env_config is null after get_config()")
  end

  if (m_cfg.csr_rb == null) begin
    `uvm_fatal("CFG_ERR",
               "sha256_env_config.csr_rb is null; create and attach the RAL block before env build")
  end

  if (m_cfg.axi4lite_agent_cfg != null) begin
    uvm_config_db#(axi4lite_agent_config)::set(this, "m_axi4lite_agent*", "axi4lite_agent_config",
                                               m_cfg.axi4lite_agent_cfg);
    m_axi4lite_agent = axi4lite_agent::type_id::create("m_axi4lite_agent", this);
  end

  if (m_cfg.axis_agent_cfg != null) begin
    uvm_config_db#(axis_agent_config)::set(this, "m_axis_agent*", "axis_agent_config",
                                           m_cfg.axis_agent_cfg);
    m_axis_agent = axis_agent::type_id::create("m_axis_agent", this);
  end

  if (m_cfg.core_agent_cfg != null) begin
    uvm_config_db#(core_agent_config)::set(this, "m_core_agent*", "core_agent_config",
                                           m_cfg.core_agent_cfg);
    m_core_agent = core_agent::type_id::create("m_core_agent", this);
  end

  m_axi4lite2reg_predictor =
      uvm_reg_predictor#(axi4lite_seq_item)::type_id::create("m_axi4lite2reg_predictor", this);
  m_reg2axi4lite = reg2axi4lite_adapter::type_id::create("m_reg2axi4lite");
  m_reg2axi4lite.m_cfg = m_cfg.axi4lite_agent_cfg;

  if (m_cfg.has_scoreboard) begin
    m_scoreboard = sha256_scoreboard::type_id::create("m_scoreboard", this);
  end

  if (m_cfg.has_functional_coverage) begin
    m_csr_coverage = sha256_csr_coverage::type_id::create("m_csr_coverage", this);
    m_overall_coverage =
        sha256_overall_coverage::type_id::create("m_overall_coverage", this);
  end

endfunction : build_phase

// VSpec 2.3: End-to-End TLM Connection & Transaction Flow
function void sha256_env::connect_phase(uvm_phase phase);
  super.connect_phase(phase);

  // VSpec 4.2.1: Explicit Prediction
  if (m_cfg.csr_rb != null) begin : ral_connect
    if (m_cfg.csr_rb.get_parent() == null) begin
      if (m_cfg.axi4lite_agent_cfg != null && m_cfg.axi4lite_agent_cfg.active == UVM_ACTIVE) begin
        m_cfg.csr_rb.default_map.set_sequencer(m_axi4lite_agent.m_sequencer, m_reg2axi4lite);
      end

      m_axi4lite2reg_predictor.map = m_cfg.csr_rb.default_map;
      m_axi4lite2reg_predictor.adapter = m_reg2axi4lite;
      m_cfg.csr_rb.default_map.set_auto_predict(0);
      if (m_axi4lite_agent != null) begin
        m_axi4lite_agent.ap.connect(m_axi4lite2reg_predictor.bus_in);
      end
    end
  end

  if (m_scoreboard != null) begin : sb_connect
    if (m_axi4lite_agent != null) begin
      m_axi4lite_agent.ap.connect(m_scoreboard.axil_fifo.analysis_export);
    end
    if (m_axis_agent != null) begin
      m_axis_agent.ap.connect(m_scoreboard.axis_fifo.analysis_export);
    end
    if (m_core_agent != null && m_core_agent.monitor != null) begin
      m_core_agent.monitor.ap.connect(m_scoreboard.core_fifo.analysis_export);
    end
    m_scoreboard.csr_rb = m_cfg.csr_rb;
  end

  if (m_cfg.has_functional_coverage && m_cfg.csr_rb != null) begin : coverage_connect
    if (m_csr_coverage != null && m_axi4lite_agent != null) begin : csr_coverage_connect
      m_axi4lite_agent.ap.connect(m_csr_coverage.analysis_export);
      m_csr_coverage.csr_rb = m_cfg.csr_rb;
    end

    if (m_overall_coverage != null) begin : overall_coverage_connect
      if (m_axi4lite_agent != null) begin
        m_axi4lite_agent.ap.connect(m_overall_coverage.axil_fifo.analysis_export);
      end
      if (m_axis_agent != null) begin
        m_axis_agent.ap.connect(m_overall_coverage.axis_fifo.analysis_export);
      end
      if (m_core_agent != null && m_core_agent.monitor != null) begin
        m_core_agent.monitor.ap.connect(m_overall_coverage.core_fifo.analysis_export);
      end
      m_overall_coverage.csr_rb = m_cfg.csr_rb;
    end
  end
endfunction : connect_phase
