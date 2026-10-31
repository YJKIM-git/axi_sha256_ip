proc get_env_or_default {name default_value} {
	if {[info exists ::env($name)] && $::env($name) ne ""} {
		return $::env($name)
	}

	return $default_value
}

set script_dir [file dirname [file normalize [info script]]]
set project_name [get_env_or_default FPGA_PROJECT_NAME "fpga_sha256"]
set part [get_env_or_default PART "xc7z020clg400-1"]
set project_dir [file normalize [get_env_or_default FPGA_PROJECT_DIR [file join $script_dir .. build $project_name]]]
set bd_dir [file normalize [get_env_or_default BD_DIR [file join $script_dir .. bd]]]
set ip_repo_dir [file normalize [get_env_or_default IP_REPO_DIR [file join $script_dir .. ip_repo]]]
set source_bd [file join $bd_dir "zybo.bd"]
set project_bd_dir [file join [file dirname $project_dir] "${project_name}_bd"]
set project_bd [file join $project_bd_dir "zybo.bd"]

if {![file exists $source_bd]} {
	error "Block design not found: $source_bd"
}

if {![file exists [file join $ip_repo_dir "component.xml"]]} {
	error "IP repository not found: $ip_repo_dir"
}

create_project $project_name $project_dir -part $part -force
set_property ip_repo_paths [list $ip_repo_dir] [current_project]
update_ip_catalog

file mkdir $project_bd_dir
file copy -force $source_bd $project_bd
add_files -norecurse -fileset sources_1 $project_bd

set bd_file [get_files $project_bd]
generate_target all $bd_file
set wrapper_path [make_wrapper -fileset sources_1 -files $bd_file -top]
add_files -norecurse -fileset sources_1 $wrapper_path

set_property top zybo_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts "=== FPGA project $project_name created successfully ==="
