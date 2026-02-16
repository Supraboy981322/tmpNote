package main

/*
extern void fn_callback(void* fn);
extern void void_ptr_fn_callback(void* fn, void* data);
*/
import "C"
import (
	"unsafe"
);

func main() {}

//export async_void
func async_void(fn unsafe.Pointer) {
	go C.fn_callback(fn)
}

//export async_data
func async_data(fn unsafe.Pointer, data unsafe.Pointer) {
	go C.void_ptr_fn_callback(fn, data)
}
