package odin_pbf

import "core:compress/zlib"
import "core:bytes"

zlib_decompress :: proc(data: []u8, expected_size: i32) -> bytes.Buffer {
    buf := make([]u8, expected_size)
    defer delete(buf)

    buffer : bytes.Buffer
    bytes.buffer_init(&buffer, buf)


    err := zlib.inflate_from_byte_array(data, &buffer, expected_output_size = int(expected_size))
    if err != nil {
        panic("zlib init failed")
    }

    return buffer
}