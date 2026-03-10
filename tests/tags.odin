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

count : i64

success : bool

//osmium cat ./data/andorra-260308.osm.pbf -f opl | grep '^n' | wc -l
@(test)
read_correct_count_nodes :: proc(t: ^testing.T) {
    read_node :: proc(n: ^pbf.Node){
        sync.atomic_add(&count, 1)
    }

    r : pbf.Reader
    defer destroy(&r)
    init(&r)
    r.handle_node = read_node

    pbf.read(&r)

    testing.expect_value(t, count, 489692)
}

//osmium count -t way ./data/andorra-260308.osm.pbf
@(test)
read_correct_count_ways :: proc(t: ^testing.T) {
    read_way :: proc(w: ^pbf.Way){
        sync.atomic_add(&count, 1)
    }

    r : pbf.Reader
    defer destroy(&r)
    init(&r)
    r.handle_way = read_way

    pbf.read(&r)

    testing.expect_value(t, count, 25678)
}

//osmium cat ./data/andorra-260308.osm.pbf -f opl | grep '^n' | grep -E '(^|,|T)name=' | wc -l
@(test)
has_key_nodes :: proc(t: ^testing.T) {
    read_node :: proc(n: ^pbf.Node){
        if pbf.has_key(n, "name"){
            sync.atomic_add(&count, 1)
        }
    }

    r : pbf.Reader
    defer destroy(&r)
    init(&r)
    r.handle_node = read_node

    pbf.read(&r)

    testing.expect_value(t, count, 2118)
}

//osmium cat ./data/andorra-260308.osm.pbf -f opl | grep '^w' | grep -E '(^|,|T)highway=' | wc -l
@(test)
has_key_ways :: proc(t: ^testing.T) {
    read_way :: proc(w: ^pbf.Way){
        if pbf.has_key(w, "highway"){
            sync.atomic_add(&count, 1)
        }
    }

    r : pbf.Reader
    defer destroy(&r)
    init(&r)
    r.handle_way = read_way

    pbf.read(&r)

    testing.expect_value(t, count, 8254)
}

//osmium cat ./data/andorra-260308.osm.pbf -f opl | grep '^n' | grep -E '=crossing([ ,]|$)' | wc -l
@(test)
has_value_nodes :: proc(t: ^testing.T) {
    read_node :: proc(n: ^pbf.Node){
        if pbf.has_value(n, "crossing"){
            sync.atomic_add(&count, 1)
        }
    }

    r : pbf.Reader
    defer destroy(&r)
    init(&r)
    r.handle_node = read_node

    pbf.read(&r)

    testing.expect_value(t, count, 962)
}

//osmium cat ./data/andorra-260308.osm.pbf -f opl | grep '^w' | grep -E '=residential([ ,]|$)' | wc -l
@(test)
has_value_ways :: proc(t: ^testing.T) {
    read_way :: proc(w: ^pbf.Way){
        if pbf.has_value(w, "residential"){
            sync.atomic_add(&count, 1)
        }
    }

    r : pbf.Reader
    defer destroy(&r)
    init(&r)
    r.handle_way = read_way

    pbf.read(&r)

    testing.expect_value(t, count, 1161)
}


@(test)
get_value_ways :: proc(t: ^testing.T) {
    read_way :: proc(w: ^pbf.Way){
        if w.id == 1459434920{
            v :=  pbf.get_value(w, "highway")
            if(v == "residential"){
                success = true
            }
        }
    }

    r : pbf.Reader
    defer destroy(&r)
    init(&r)
    r.handle_way = read_way

    pbf.read(&r)

    testing.expect_value(t, success, true)
}

@(test)
get_value_nodes :: proc(t: ^testing.T) {
    read_node :: proc(n: ^pbf.Node){
        if n.id == 13593008002{
            v :=  pbf.get_value(n, "amenity")
            if(v == "restaurant"){
                success = true
            }
        }
    }

    r : pbf.Reader
    defer destroy(&r)
    init(&r)
    r.handle_node = read_node

    pbf.read(&r)

    testing.expect_value(t, success, true)
}

