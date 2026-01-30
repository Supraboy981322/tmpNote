package main

/*
#include <stdio.h>
#include <stdlib.h>
extern void Foo(char* data, int length);
*/
import ("C";"unsafe";"os");

func main() {}

//export Foo
func Foo(data *C.char, length C.int) {
	goBytes := C.GoBytes(unsafe.Pointer(data), length)
	os.Stdout.Write(goBytes)
}
