# odin-osm-pbf

A fast and lightweight **OpenStreetMap `.osm.pbf` reader written in Odin**.

This project provides a simple way to decode and process `.osm.pbf` files.\
It focuses on performance, low memory usage, and a clean API that integrates well with Odin programs.

---

## Features

- Streaming `.osm.pbf` parsing
- Callback-based API for processing data
- Multi-core processing support
- Minimal allocations

---

## Example

```odin
import pbf "odin-osm-pbf"

read_node :: proc(n: ^pbf.Node) {
    // process node
}

read_way :: proc(w: ^pbf.Way) {
    // process way
}

main :: proc() {
    r := pbf.get_reader("map.osm.pbf")

    r.handle_node = read_node
    r.handle_way  = read_way

    pbf.read(&r)
}
```

The reader streams through the file and calls your handlers as nodes and ways are decoded.

---

## Design

The reader works by:

1. Reading PBF blobs from the file
2. Decompressing them
3. Decoding protobuf structures
4. Emitting nodes and ways through callbacks

This allows processing very large datasets without loading the entire map into memory.

---

## Status

This is an early release and the API may evolve.

Planned improvements include:

- relation support

---

## License

This project is licensed under the MIT License — see the [LICENSE](https://github.com/rocas777/odin-osm-pbf/blob/main/LICENSE) file for details.

