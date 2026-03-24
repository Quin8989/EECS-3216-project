project_open de10_lite
load_package report
load_report
set rows [get_number_of_rows -name {Fitter||Resource Section||All Package Pins}]
for {set i 0} {$i < $rows} {incr i} {
    set pin [get_report_panel_data -name {Fitter||Resource Section||All Package Pins} -row $i -col_name {Pin Name/Usage}]
    set loc [get_report_panel_data -name {Fitter||Resource Section||All Package Pins} -row $i -col_name {Location}]
    if {[string match "PIN_W*" $loc]} {
        puts "$loc $pin"
    }
}
project_close
