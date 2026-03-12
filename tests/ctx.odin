package tests

import "core:testing"
import pbf "../odin_pbf"
import fmt "core:fmt"
import time "core:time"
import sync "core:sync"

@(test)
read_node_correct_ctx :: proc(t: ^testing.T) {
    read_node :: proc(n: ^pbf.Node, raw_ctx: rawptr){
        ctx := cast(^int)raw_ctx
        assert(ctx^ == 4798)
    }

    value_to_check := 4798

    r : pbf.Reader
    defer destroy(&r)
    init(&r)
    r.ctx = &value_to_check
    r.handle_node = read_node

    pbf.read(&r)
}