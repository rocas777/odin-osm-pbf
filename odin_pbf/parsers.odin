package odin_pbf

import "core:bytes"

skip_field :: #force_inline proc(buf: []u8, i: ^int, wire: u64){
    switch wire{
        case 0:{
            _ = read_varint_fast(buf, i)
        }
        case 2:{
            l := read_varint_fast(buf, i)
            i^ += int(l)
        }
        case:{
            panic("unsupported wire type")
        }
    }
}

parse_block :: proc(buf: []u8, blob_header: BlobHeader, i: ^int, r: ^Reader) -> Block{
    switch blob_header.type[3]{
        case 'H':{
            return parse_header_block(buf, i)
        }
        case 'D':{
            return parse_primitive_block(buf, i, r)
        }
        case:{
            panic("invalid blob type")
        }
    }
}

block_destroy :: proc(b: ^Block){
    switch v in b^ {
    case HeaderBlock:{
        h := b.(HeaderBlock)
        delete(h.required_features)
        delete(h.optional_features)
    }
    case PrimitiveBlock:{
        p := b.(PrimitiveBlock)
        delete(p.string_table)
        for i in 0..<len(p.primitive_groups) {
            primitive_group_destroy(&p.primitive_groups[i])
        }
        delete(p.primitive_groups)
    }
    case:
        panic("unknown type")
    }
}

primitive_group_destroy :: proc(p: ^PrimitiveGroup){
    switch v in p^{
        case []Node:{
            for n in v{
                delete(n._vals)
                delete(n._keys)
            }
            delete(v)
        }
        case []Way:{
            for n in v{
                delete(n._vals)
                delete(n._lon)
                delete(n._lat)
                delete(n._keys)
                delete(n._refs)
            }
            delete(v)
        }
        case DenseNodes:{
            delete(v._id)
            delete(v._lat)
            delete(v._lon)
        }
        case:
    }
}

parse_blob :: proc(buf: []u8, blob_header: BlobHeader, r: ^Reader) -> (Blob) {
    blob: Blob

    i:= 0
    for i < len(buf) {
        key := read_varint_fast(buf, &i)

        field := key >> 3
        wire  := key & 0b00000111

        switch field{
            case 2:{ //raw_size
                blob.raw_size = read_i32(buf, &i)
            }
            case 1:{ //raw
                size := read_varint_fast(buf, &i)
                j := 0
                block := parse_block(buf[i : i + int(size)], blob_header, &j, r)
                block_destroy(&block)
                i += int(size)
            }
            case 3:{ //zlib
                size := read_varint_fast(buf, &i)

                decompressed := zlib_decompress(buf[i : i + int(size)], blob.raw_size)
                defer bytes.buffer_destroy(&decompressed)
                j := 0
                block :=  parse_block(bytes.buffer_to_bytes(&decompressed), blob_header, &j, r)
                block_destroy(&block)
                i += int(size)
            }
            case:{
                skip_field(buf, &i, wire)
            }
        }
    }

    return blob
}

parse_blob_header :: proc(buf: []u8) -> BlobHeader {
    i := 0
    header: BlobHeader

    for i < len(buf) {
        key := read_varint_fast(buf, &i)

        field := key >> 3
        wire  := key & 0b00000111

        switch field{
            case 1:{
                header.type = read_string(buf, &i)
            }
            case 2:{
                header.indexdata = read_bytes(buf, &i)
            }
            case 3:{
                header.datasize = read_i32(buf, &i)
            }
            case:{
                skip_field(buf, &i, wire)
            }
        }
    }

    return header
}

parse_header_box :: proc(buf: []u8) -> HeaderBBox{
    i := 0
    box: HeaderBBox
    for i < len(buf) {
        key := read_varint_fast(buf, &i)

        field := key >> 3
        wire  := key & 0b00000111

        switch field{
            case 1:{
                box.left = decode_zigzag64(read_varint_fast(buf, &i))
            }
            case 2:{
                box.right = decode_zigzag64(read_varint_fast(buf, &i))
            }
            case 3:{
                box.top = decode_zigzag64(read_varint_fast(buf, &i))
            }
            case 4:{
                box.bottom = decode_zigzag64(read_varint_fast(buf, &i))
            }
            case: {
                skip_field(buf, &i, wire)
            }
        }
    }

    return box
}

parse_header_block :: proc(buf: []u8, i: ^int) -> HeaderBlock {
    block: HeaderBlock

    required_features := make([dynamic]string, 0)
    optional_features := make([dynamic]string, 0)

    for i^ < len(buf) {
        key := read_varint_fast(buf, i)

        field := key >> 3
        wire  := key & 0b00000111

        switch field{
            case 1:{ //bbox
                size := read_varint_fast(buf, i)

                block.bbox = parse_header_box(buf[i^ : i^ + int(size)])

                i^ += int(size)
            }
            case 4:{ //required_features
                feature := read_string(buf, i)
                append(&required_features, feature)
            }
            case 5:{ //optional_features
                feature := read_string(buf, i)
                append(&optional_features, feature)
            }
            case 16:{ //writingprogram
                block.writingprogram = read_string(buf, i)
            }
            case 17:{ //source
                block.source = read_string(buf, i)
            }
            case 32:{ //osmosis_replication_timestamp
                block.replication_timestamp = read_i64(buf, i)
            }
            case 33:{ //osmosis_replication_sequence_number
                block.replication_sequence = read_i64(buf, i)
            }
            case 34:{ //osmosis_replication_base_url
                block.replication_url = read_string(buf, i)
            }

            case: {
                skip_field(buf, i, wire)
            }
        }
    }
    block.required_features = required_features[:]
    block.optional_features = optional_features[:]

    return block
}

parse_primitive_block :: proc(buf: []u8, i: ^int, r: ^Reader) -> PrimitiveBlock {
    block: PrimitiveBlock

    block.granularity = 100
    block.lat_offset = 0
    block.lon_offset = 0
    block.date_granularity = 1000

    primitive_groups := make([dynamic]PrimitiveGroup, 0)

    for i^ < len(buf) {
        key := read_varint_fast(buf, i)

        field := key >> 3
        wire  := key & 0b00000111

        switch field{
            case 1:{ //stringtable
                size := read_varint_fast(buf, i)
                block.string_table = parse_string_table(buf[i^ : i^ + int(size)])
                i^ += int(size)
            }
            case 2:{ //primitivegroup
                size := read_varint_fast(buf, i)
                pg := parse_primitive_group(buf[i^ : i^ + int(size)])
                if(pg != nil){
                    append(&primitive_groups, pg)
                }
                i^ += int(size)
            }
            case 17:{ //granularity
                block.granularity = read_i32(buf, i)
            }
            case 19:{ //lat_offset
                block.lat_offset = read_i64(buf, i)
            }
            case 20:{ //lon_offset
                block.lon_offset = read_i64(buf, i)
            }
            case 18:{ //date_granularity
                block.date_granularity = read_i32(buf, i)
            }
            case: {
                skip_field(buf, i, wire)
            }
        }
    }

    block.primitive_groups = primitive_groups[:]

    for v in block.primitive_groups{
        switch pg in v{
            case []Node:{
                if r.handle_node == nil{
                    continue
                }
                for &n in pg{
                    n._pb = &block
                    r.handle_node(&n)
                }
            }
            case []Way:{
                if r.handle_way == nil{
                    continue
                }
                for &w in pg{
                    w._pb = &block
                    r.handle_way(&w)
                }
            }
            case DenseNodes:{
                if r.handle_node == nil{
                    continue
                }
                last_id : i64 = 0
                last_lat : i64 = 0
                last_lon : i64 = 0

                for dn, k in pg._id{
                    n := Node {
                        id = last_id + dn,
                        _lat = last_lat + pg._lat[k],
                        _lon = last_lon + pg._lon[k],
                        _pb = &block
                    }
                    last_id = n.id
                    last_lat = n._lat
                    last_lon = n._lon
                    r.handle_node(&n)
                }
            }
        }
    }

    return block
}

parse_string_table :: proc(buf: []u8) -> []string {
    i := 0

    strings := make([dynamic]string, 0)

    for i < len(buf) {
        key := read_varint_fast(buf, &i)

        field := key >> 3
        wire  := key & 7

        switch field {
        case 1: { // repeated bytes
            str := read_string(buf, &i)
            append(&strings, str)
        }
        case:
            skip_field(buf, &i, wire)
        }
    }

    return strings[:]
}

parse_primitive_group :: proc(buf: []u8) -> PrimitiveGroup{
    group: PrimitiveGroup

    i := 0

    nodes := make([dynamic]Node, 0)
    ways := make([dynamic]Way, 0)
    denseNodes : DenseNodes

    selected := 0

    for i < len(buf) {
        key := read_varint_fast(buf, &i)

        field := key >> 3
        wire  := key & 7

        selected = int(field)

        switch field {
        case 1: { // Node
            size := read_varint_fast(buf, &i)
            node := parse_node(buf[i : i + int(size)])
            append(&nodes, node)
            i += int(size)
        }
        case 2: { // DenseNodes
            size := read_varint_fast(buf, &i)
            denseNodes = parse_dense_node(buf[i : i + int(size)])
            i += int(size)
        }
        case 3: { // Way
            size := read_varint_fast(buf, &i)
            way := parse_way(buf[i : i + int(size)])
            append(&ways, way)
            i += int(size)
        }
        case 4: { // Relation
            size := read_varint_fast(buf, &i)
            i += int(size)
        }
        case 5: { // ChangeSet
            size := read_varint_fast(buf, &i)
            i += int(size)
        }
        case:
            skip_field(buf, &i, wire)
        }
    }

    group = nil

    switch selected{
        case 1:{
            delete(ways)

            group = nodes[:]
        }
        case 2:{
            delete(nodes)
            delete(ways)

            group = denseNodes
        }
        case 3:{
            delete(nodes)

            group = ways[:]
        }
        case 4:{
            delete(nodes)
            delete(ways)
        }
        case 5:{
            delete(nodes)
            delete(ways)
        }
    }

    return group
}

parse_node :: proc(buf: []u8) -> Node{
    node: Node

    i := 0

    for i < len(buf) {
        key := read_varint_fast(buf, &i)

        field := key >> 3
        wire  := key & 7

        switch field {
            case 1:{
                node.id = decode_zigzag64(read_varint_fast(buf, &i))
            }
            case 2:{
                node._keys = read_packed_u32(buf, &i)
            }
            case 3:{
                node._vals = read_packed_u32(buf, &i)
            }
            case 8:{
                node._lat = decode_zigzag64(read_varint_fast(buf, &i))
            }
            case 9:{
                node._lon = decode_zigzag64(read_varint_fast(buf, &i))
            }
            case:
                skip_field(buf, &i, wire)
        }
    }

    return node
}

parse_way :: proc(buf: []u8) -> Way{
    way: Way

    i := 0

    for i < len(buf) {
        key := read_varint_fast(buf, &i)

        field := key >> 3
        wire  := key & 7

        switch field {
            case 1:{
                way.id = decode_zigzag64(read_varint_fast(buf, &i))
            }
            case 2:{
                way._keys = read_packed_u32(buf, &i)
            }
            case 3:{
                way._vals = read_packed_u32(buf, &i)
            }
            case 8:{
                way._refs = read_packed_i64_zg(buf, &i)
            }
            case 9:{
                way._lat = read_packed_i64_zg(buf, &i)
            }
            case 10:{
                way._lon = read_packed_i64_zg(buf, &i)
            }
            case:
                skip_field(buf, &i, wire)
        }
    }

    return way
}

parse_dense_node :: proc(buf: []u8) -> DenseNodes{
    node: DenseNodes

    i := 0

    for i < len(buf) {
        key := read_varint_fast(buf, &i)

        field := key >> 3
        wire  := key & 7

        switch field {
            case 1:{
                node._id = read_packed_i64_zg(buf, &i)
            }
            case 8:{
                node._lat = read_packed_i64_zg(buf, &i)
            }
            case 9:{
                node._lon = read_packed_i64_zg(buf, &i)
            }
            case:
                skip_field(buf, &i, wire)
        }
    }

    return node
}




