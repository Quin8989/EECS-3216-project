project_open de10_lite
load_package report
load_report
set panel_names [get_report_panel_names]
foreach p $panel_names {
    if {[string match "*Pin*" $p]} { puts $p }
}
project_close
