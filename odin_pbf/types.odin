package odin_pbf

BlobHeader :: struct {
    type: string,
    indexdata: []u8,
    datasize: i32,
}

Blob :: struct {
    raw_size: i32,
}

Block :: union{
    HeaderBlock,
    PrimitiveBlock,
}

HeaderBlock :: struct {
    bbox: HeaderBBox,

    required_features: []string,
    optional_features: []string,

    writingprogram: string,
    source: string,

    replication_timestamp: i64,
    replication_sequence:  i64,
    replication_url: string,
}
HeaderBBox :: struct {
    left:   i64,
    right:  i64,
    top:    i64,
    bottom: i64,
}

PrimitiveBlock :: struct {
    string_table: []string,
    granularity: i32,
    lat_offset: i64,
    lon_offset: i64,
    date_granularity: i32,
    primitive_groups: []PrimitiveGroup
}

PrimitiveGroup :: union{
    []Node,
    []Way,
    DenseNodes,
}

NodeType :: enum{
    DenseNode,
    Node
}

Node :: struct{
    id: i64,
    _keys : []u32,
    _vals : []u32,
    //    info: Info
    _lat: i64,
    _lon: i64,

    _keys_vals : []u32,

    _pb: ^PrimitiveBlock,

    _type: NodeType
}

Way :: struct{
    id: u64,
    _keys : []u32,
    _vals : []u32,
    //    info: Info
    _refs: []i64,
    _lat: []i64,
    _lon: []i64,

    _pb: ^PrimitiveBlock,
}

DenseNodes :: struct{
    _id:  []i64,
    //    denseInfo: DenseInfo
    _lat: []i64,
    _lon: []i64,
    _keys_vals: []u32,

    _pb: ^PrimitiveBlock,
}


has_key_node :: proc(n: ^Node, s: string) -> bool{
    if n._keys_vals != nil{
        for i := 0; i < len(n._keys_vals); i += 2{
            k := n._keys_vals[i]
            if n._pb.string_table[k] == s{
                return true
            }
        }
    }
    for k in n._keys{
        if n._pb.string_table[k] == s{
            return true
        }
    }
    return false
}

has_key_way :: proc(w: ^Way, s: string) -> bool{
    for k in w._keys{
        if w._pb.string_table[k] == s{
            return true
        }
    }
    return false
}

has_key :: proc{has_key_node, has_key_way}

get_refs :: proc(w: ^Way) -> []i64{
    refs := make([]i64, len(w._refs))

    last_id : i64 = 0
    for r, i in w._refs{
        n_id := last_id + r
        refs[i] = n_id
        last_id = n_id
    }

    return refs
}

get_lat :: proc(n: ^Node) -> f64{
    return f64(n._pb.lat_offset + n._lat * i64(n._pb.granularity)) * 1e-9
}

get_lon :: proc(n: ^Node) -> f64{
    return f64(n._pb.lon_offset + n._lon * i64(n._pb.granularity)) * 1e-9
}

has_value_node :: proc(n: ^Node, s: string) -> bool{
    for i := 1; i < len(n._keys_vals); i += 2{
        k := n._keys_vals[i]
        if n._pb.string_table[k] == s{
            return true
        }
    }
    for k in n._vals{
        if n._pb.string_table[k] == s{
            return true
        }
    }
    return false
}

has_value_way :: proc(w: ^Way, s: string) -> bool{
    for k in w._vals{
        if w._pb.string_table[k] == s{
            return true
        }
    }
    return false
}

has_value :: proc{has_value_node, has_value_way}


get_value_node :: proc(n: ^Node, s: string) -> string{
    if n._keys_vals != nil{
        for i := 0; i < len(n._keys_vals); i += 2{
            k := n._keys_vals[i]
            if n._pb.string_table[k] == s{
                v := n._keys_vals[i+1]
                return n._pb.string_table[v]
            }
        }
    }
    for k,i in n._keys{
        value := n._vals[i]
        if n._pb.string_table[k] == s{
            return n._pb.string_table[value]
        }
    }
    return ""
}

get_value_way :: proc(w: ^Way, s: string) -> string{
    for k,i in w._keys{
        value := w._vals[i]
        if w._pb.string_table[k] == s{
            return w._pb.string_table[value]
        }
    }
    return ""
}

get_value :: proc{get_value_node, get_value_way}