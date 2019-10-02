#! /bin/sh
# \
exec tclsh "$0" ${1+"$@"}

# 2019 (c) Alexander Danilov <alexander.a.danilov@gmail.com>

# Usage: $0 dbname table1 table2
# Description: show difference in two tables from PostgreSQL database
# Description: < - if table1 missing column from table2
# Description: > - if table2 missing column from table1
# Description: # - if column has different type or default value

package require Tcl 8.6
package require tdbc::postgres

if {[llength $argv] != 3} {
    puts stderr "Usage: $argv0 dbname table1 table2"
    exit 1
}

lassign $argv dbname table1 table2

tdbc::postgres::connection create db -db $dbname

set query {
    SELECT column_name as name, column_default as default, data_type as type 
    FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE table_name = :table
}

set q [db prepare $query]

set table $table1
set diff [dict create]
$q foreach row {
    set default [expr {[dict exists $row default] ? " DEFAULT [dict get $row default]" : ""}]
    dict set diff [dict get $row name] [list "[dict get $row type]$default"]
}

set table $table2
$q foreach row {
    set name [dict get $row name]
    set type [dict get $row type]
    set default [expr {[dict exists $row default] ? " DEFAULT [dict get $row default]" : ""}]
    set v "[dict get $row type]$default"

    if {[dict exists $diff $name]} {
        dict lappend diff $name $v
    } else {
        dict set diff $name [list [list] $v]
    }
}

set w1 [tcl::mathfunc::max {*}[lmap k [dict keys $diff] {string length $k}]]
set w2 [tcl::mathfunc::max {*}[lmap v [dict values $diff] {string length [lindex $v 0]}]]
set w3 [tcl::mathfunc::max {*}[lmap v [dict values $diff] {string length [lindex $v 1]}]]
set fmt "%s %-${w1}s | %-${w2}s | %-${w3}s"
puts [format $fmt " " " " $table1 $table2]
puts [string repeat - [expr {1 + 1 + $w1 + 3 + $w2 + 3 + $w3}]]
dict for {k v} $diff {
    lassign $v t1 t2
    if {$t1 eq $t2} {
        puts [format $fmt " " $k {*}$v]
    } elseif {$t1 eq ""} {
        puts [format $fmt "<" $k {*}$v]
    } elseif {$t2 eq ""} {
        puts [format $fmt ">" $k {*}$v]
    } else {
        puts [format $fmt "#" $k {*}$v]
    }
}


db close

