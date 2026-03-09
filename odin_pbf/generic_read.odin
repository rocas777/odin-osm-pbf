package odin_pbf

import "core:io"
import "core:bufio"

read_varint_fast :: #force_inline proc(buf: []u8, i: ^int) -> u64 {
    b := buf[i^]
    // 1-byte fast path
    if b < 0b10000000 {
        i^ += 1
        return u64(b)
    }

    // fallback
    result: u64 = 0
    shift: u32 = 0

    for {
        b = buf[i^]
        i^ += 1
        result |= (u64(b & 0b01111111) << shift)
        if (b & 0b10000000) == 0 {
            break
        }
        shift += 7
    }

    return result
}

read_string :: #force_inline proc(buf: []u8, i: ^int) -> (s: string){
    l := read_varint_fast(buf, i)
    s = string(buf[i^ : i^+int(l)])
    i^ += int(l)
    return
}

read_bytes :: #force_inline proc(buf: []u8, i: ^int) -> (b: []u8){
    l := read_varint_fast(buf, i)
    b = buf[i^ : i^+int(l)]
    i^ += int(l)
    return
}

read_i32 :: #force_inline proc(buf: []u8, i: ^int) -> i32{
    return i32(read_varint_fast(buf, i))
}

read_i64 :: #force_inline proc(buf: []u8, i: ^int) -> i64{
    return i64(read_varint_fast(buf, i))
}

decode_zigzag64 :: proc(v: u64) -> i64 {
    return i64(v >> 1) ~ -i64(v & 1)
}

read_packed_u32 :: proc(buf: []u8, i: ^int) -> []u32 {
    size := read_varint_fast(buf, i)

    end := i^ + int(size)

    values := make([dynamic]u32, 0)

    for i^ < end {
        v := u32(read_varint_fast(buf, i))
        append(&values, v)
    }

    return values[:]
}

read_packed_i64_zg :: proc(buf: []u8, i: ^int) -> []i64 {
    size := read_varint_fast(buf, i)

    end := i^ + int(size)

    values := make([dynamic]i64, 0)

    for i^ < end {
        v := decode_zigzag64(read_varint_fast(buf, i))
        append(&values, v)
    }

    return values[:]
}

read_buf ::  proc(r: ^Reader, size: u32) -> (buf: []u8, err: io.Error){
    buf = make([]u8, size)
    read_exact(r, buf) or_return
    return buf, nil
}

read_u32_be :: proc(r: ^Reader) -> (value: u32, err: io.Error) {
    buf: [4]u8

    read_exact(r, buf[:]) or_return

    return (u32(buf[0]) << 24) |
    (u32(buf[1]) << 16) |
    (u32(buf[2]) << 8)  |
    (u32(buf[3])), nil
}

read_exact :: proc(r: ^Reader, buf: []u8) -> (err: io.Error){
    read := 0

    for read < len(buf) {
        n, err := bufio.reader_read(&r.reader, buf[read:])

        if err != nil {
            return err
        }

        if n == 0 {
            return err
        }

        read += n
    }

    return nil
}