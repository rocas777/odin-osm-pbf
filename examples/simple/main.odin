package simple

import "core:fmt"
import "core:mem"
import "core:time"
import "core:sync"

import pbf "../../odin_pbf"

main :: proc() {
    r := pbf.get_reader("./data/andorra-260308.osm.pbf")

    r.handle_node = read_node
    r.handle_way = read_way

    pbf.read(&r)
    pbf.reader_destroy(&r)
}

read_node :: proc(n: ^pbf.Node){
    fmt.println(pbf.get_lat(n), pbf.get_lon(n))
}

read_way :: proc(w: ^pbf.Way){
}