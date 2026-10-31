
proc get_env_or_default {name default_value} {
    if {[info exists ::env($name)] && $::env($name) ne ""} {
    return $::env($name)
    }

  return $default_value
}

set script_dir [file dirname [file normalize [info script]]]
set proj_name [expr {[info exists ::env(PROJECT_NAME)] && $::env(PROJECT_NAME) ne "" ? $::env(PROJECT_NAME) : "ip_generator"}]
set part [expr {[info exists ::env(PART)] && $::env(PART) ne "" ? $::env(PART) : "xc7z020clg400-1"}]
set proj_dir [get_env_or_default PROJECT_DIR [file normalize [file join $script_dir .. build $proj_name]]]
set rtl_dir [get_env_or_default RTL_DIR [file normalize [file join $script_dir .. .. design]]]
set synth_dir [get_env_or_default SYNTH_DIR [file normalize [file join $script_dir .. synth]]]

create_project $proj_name $proj_dir -part $part -force

# 보드 파트 설정
# set_property board_part digilentinc.com:zybo-z7-20:part0:1.2 [current_project]

set rtl_files [list \
  [file join $rtl_dir "sha256_axi_wrapper.sv"] \
  [file join $rtl_dir "sha256_core" "sha256_add32.sv"] \
  [file join $rtl_dir "sha256_core" "sha256_ch.sv"] \
  [file join $rtl_dir "sha256_core" "sha256_controller.sv"] \
  [file join $rtl_dir "sha256_core" "sha256_core.sv"] \
  [file join $rtl_dir "sha256_core" "sha256_datapath.sv"] \
  [file join $rtl_dir "sha256_core" "sha256_ep0.sv"] \
  [file join $rtl_dir "sha256_core" "sha256_ep1.sv"] \
  [file join $rtl_dir "sha256_core" "sha256_k_rom.sv"] \
  [file join $rtl_dir "sha256_core" "sha256_maj.sv"] \
  [file join $rtl_dir "sha256_core" "sha256_message_schedule.sv"] \
  [file join $rtl_dir "sha256_core" "sha256_rotr.sv"] \
  [file join $rtl_dir "sha256_core" "sha256_round_logic.sv"] \
  [file join $rtl_dir "sha256_core" "sha256_sig0.sv"] \
  [file join $rtl_dir "sha256_core" "sha256_sig1.sv"] \
]
add_files -fileset sources_1 $rtl_files
#add_files -fileset constrs_1 [file join $synth_dir "constraint.xdc"]
set_property top sha256_axi_wrapper [get_filesets sources_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "=== Project Creation Completed Successfully ==="