# ==============================================================================
# Script Name: package_ip.tcl
# Description: 최상위 rtl 디렉토리 소스를 읽어 IP Repo를 자동 생성합니다.
# ==============================================================================

# 1. 경로 설정
proc get_env_or_default {name default_value} {
	if {[info exists ::env($name)] && $::env($name) ne ""} {
		return $::env($name)
	}

	return $default_value
}

set script_dir [file dirname [file normalize [info script]]]
set part [get_env_or_default PART "xc7z020clg400-1"]
set prj_dir [file normalize [file join $script_dir .. ip_packager_prj]]
set ip_repo_dir [file normalize [file join $script_dir .. ip_repo]]
set rtl_dir [file normalize [file join $script_dir .. .. design]]

# 2. 기존 결과물 초기화
file delete -force $prj_dir
file delete -force $ip_repo_dir
file mkdir $ip_repo_dir

# 3. 임시 프로젝트 생성
create_project -force ip_packager $prj_dir -part $part

# 4. RTL 소스 추가
add_files [glob -nocomplain $rtl_dir/*.sv]
add_files [glob -nocomplain $rtl_dir/sha256_core/*.sv]
set_property top sha256_axi_wrapper [current_fileset]
update_compile_order -fileset sources_1

# 5. IP 패키징 시작
ipx::package_project -root_dir $ip_repo_dir -vendor localdomain -library user -taxonomy /UserIP -import_files -set_current false
ipx::edit_ip_in_project -upgrade true -name tmp_edit_project -directory $ip_repo_dir $ip_repo_dir/component.xml

set core [ipx::current_core]

# 기본 정보 설정
set_property name sha256_axi_wrapper $core
set_property version 1.0 $core
set_property display_name "sha256_axi_wrapper_v1_0" $core

# 6. 클럭(clk_i) 인터페이스 매핑 (s_axi, s_axis, rst_n_i 동기화)[cite: 3]
ipx::infer_bus_interface clk_i xilinx.com:signal:clock_rtl:1.0 $core
ipx::add_bus_parameter ASSOCIATED_BUSIF [ipx::get_bus_interfaces clk_i -of_objects $core]
set_property value s_axi:s_axis [ipx::get_bus_parameters ASSOCIATED_BUSIF -of_objects [ipx::get_bus_interfaces clk_i -of_objects $core]]

ipx::add_bus_parameter ASSOCIATED_RESET [ipx::get_bus_interfaces clk_i -of_objects $core]
set_property value rst_n_i [ipx::get_bus_parameters ASSOCIATED_RESET -of_objects [ipx::get_bus_interfaces clk_i -of_objects $core]]

# 7. 리셋(rst_n_i) 인터페이스 매핑[cite: 3]
ipx::infer_bus_interface rst_n_i xilinx.com:signal:reset_rtl:1.0 $core

# 8. 인터럽트(irq_o) 레벨 하이(LEVEL_HIGH) 매핑[cite: 3]
ipx::infer_bus_interface irq_o xilinx.com:signal:interrupt_rtl:1.0 $core
ipx::add_bus_parameter SENSITIVITY [ipx::get_bus_interfaces irq_o -of_objects $core]
set_property value LEVEL_HIGH [ipx::get_bus_parameters SENSITIVITY -of_objects [ipx::get_bus_interfaces irq_o -of_objects $core]]

# 9. s_axi Outstanding 트랜잭션 1로 제한 (경고 방지)[cite: 3]
ipx::add_bus_parameter NUM_READ_OUTSTANDING [ipx::get_bus_interfaces s_axi -of_objects $core]
ipx::add_bus_parameter NUM_WRITE_OUTSTANDING [ipx::get_bus_interfaces s_axi -of_objects $core]
set_property value 1 [ipx::get_bus_parameters NUM_READ_OUTSTANDING -of_objects [ipx::get_bus_interfaces s_axi -of_objects $core]]
set_property value 1 [ipx::get_bus_parameters NUM_WRITE_OUTSTANDING -of_objects [ipx::get_bus_interfaces s_axi -of_objects $core]]

# 10. 코어 업데이트 및 종료
ipx::update_source_project_archive -component $core
ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::check_integrity $core
ipx::save_core $core

# 임시 프로젝트 제거
ipx::move_temp_component_back -component $core
close_project -delete
close_project

puts "========================================================="
puts " IP Packaging Completed: $ip_repo_dir"
puts "========================================================="