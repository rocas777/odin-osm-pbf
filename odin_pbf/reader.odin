package odin_pbf

import "core:os"
import "core:io"
import "core:bufio"
import "core:thread"
import "core:mem"

Reader :: struct{
    file: ^os.File,
    reader : bufio.Reader,
    procs: int,

    handle_node: proc(n: ^Node),
    handle_way: proc(w: ^Way),
}


workerData :: struct {
    buf: []u8,
    blob_header: BlobHeader,
    blob_header_buf: []u8,
    reader: ^Reader
}

get_reader :: proc(path: string, procs := 0) -> Reader {
    np := procs
    if np == 0{
        np = os.get_processor_core_count() - 1
        if np < 1 {
            np = 1
        }
    }

    f, err := os.open(path)
    if err != os.ERROR_NONE {
        panic(os.error_string(err))
    }

    stream := os.to_stream(f)
    reader := io.to_reader(stream)
    buffio_reader: bufio.Reader
    bufio.reader_init(&buffio_reader, reader, 1 << 20, context.allocator)

    return Reader{
        file = f,
        procs = np,
        reader = buffio_reader
    }
}

read :: proc(r: ^Reader){
    read_file_block(r)
}

reader_destroy :: proc(r: ^Reader){
    bufio.reader_destroy(&r.reader)
}


read_file_block :: proc(r: ^Reader){
    threadPool :thread.Pool
    thread.pool_init(&threadPool, context.allocator, int(r.procs))
    thread.pool_start(&threadPool)
    defer thread.pool_destroy(&threadPool)

    sum : u64
    for i := 0; ;i+=1{
        block_size, err_size := read_u32_be(r)
        if(err_size == io.Error.EOF){
            break
        }
        blob_header, err_blob_header := read_buf(r, block_size)
        if(err_blob_header == io.Error.EOF){
            break
        }

        parsed_blob_header := parse_blob_header(blob_header)

        blob, err_blob := read_buf(r, u32(parsed_blob_header.datasize))
        if(err_blob == io.Error.EOF){
            break
        }

        wd := new(workerData)
        wd.buf = blob
        wd.blob_header = parsed_blob_header
        wd.blob_header_buf = blob_header
        wd.reader = r

        thread.pool_add_task(&threadPool, context.allocator, worker, wd, i)
    }
    thread.pool_finish(&threadPool)
}

worker :: proc (t: thread.Task){
    job := cast(^workerData)t.data

    parsed_blob := parse_blob(job.buf, job.blob_header, job.reader)

    delete(job.buf)
    delete(job.blob_header_buf)
    mem.free(job)
}

close :: proc(r: ^Reader){
    os.close(r.file)
}
