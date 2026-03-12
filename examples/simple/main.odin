package simple

import "core:fmt"
import "core:mem"
import "core:time"
import "core:sync"

import pbf "../../odin_pbf"


main :: proc() {
    ctx := 4790
    r := pbf.get_reader("./data/andorra-260308.osm.pbf")

    r.handle_node = read_node
    r.handle_way = read_way
    r.ctx = &ctx

    pbf.read(&r)
    pbf.reader_destroy(&r)
}

read_node :: proc(n: ^pbf.Node, raw_ctx: rawptr){
    ctx := cast(^int)raw_ctx
    fmt.println(pbf.get_lat(n), pbf.get_lon(n))
    assert(ctx^ == 4790)
}

read_way :: proc(w: ^pbf.Way, raw_ctx: rawptr){
    ctx := cast(^int)raw_ctx
    assert(ctx^ == 4790)
}