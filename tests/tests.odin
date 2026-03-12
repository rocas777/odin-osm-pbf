package tests

import "core:testing"
import pbf "../odin_pbf"
import fmt "core:fmt"
import time "core:time"
import sync "core:sync"

init :: proc(r : ^pbf.Reader){
    r^ = pbf.get_reader("./data/andorra-260308.osm.pbf", 24)

    count = 0
    success = false
}

destroy :: proc(r: ^pbf.Reader){
    pbf.reader_destroy(r)
}