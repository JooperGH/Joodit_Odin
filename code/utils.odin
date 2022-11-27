package main

import "core:strings"
import "core:fmt"

format_string :: proc(format: string, args: ..any) -> string {
    str: strings.Builder
	strings.builder_init(&str, context.temp_allocator)
	fmt.sbprintf(buf=&str, fmt=format, args=args)
	return strings.to_string(str)
}