
# PlanAhead Launch Script for Post-Synthesis pin planning, created by Project Navigator

create_project -name CAD971VGA -dir "C:/Users/Mohammad/Desktop/CAD_VGA_Xilinx/planAhead_run_2" -part xc6slx9tqg144-2
set_property design_mode GateLvl [get_property srcset [current_run -impl]]
set_property edif_top_file "C:/Users/Mohammad/Desktop/CAD_VGA_Xilinx/CAD971Test.ngc" [ get_property srcset [ current_run ] ]
add_files -norecurse { {C:/Users/Mohammad/Desktop/CAD_VGA_Xilinx} }
set_param project.pinAheadLayout  yes
set_property target_constrs_file "vga.ucf" [current_fileset -constrset]
add_files [list {vga.ucf}] -fileset [get_property constrset [current_run]]
link_design
