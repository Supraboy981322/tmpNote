package main

/*
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
typedef struct {
	char *cont;
	int leng;
} res;
*/
import "C"
import (
	"fmt"
	//"math"
	"bytes"
	"unsafe"
//	"runtime/debug"
	"compress/gzip"
);
 
func main() {}

//export Gz
func Gz(data *C.char, length C.int) C.res {
	goBytes := C.GoBytes(unsafe.Pointer(data), length)

	var b bytes.Buffer
	gz := gzip.NewWriter(&b)
	if _, e := gz.Write(goBytes); e != nil {
		fmt.Printf("cgo err{%v}\n", e)
		return C.res { cont:nil, leng:0 }
	}
	if e := gz.Close(); e != nil { 
		fmt.Printf("cgo err{%v}\n", e)
		return C.res { cont:nil, leng:0 }
	}
	s_C := len(b.Bytes())

	cPtr := C.malloc(C.size_t(len(b.Bytes())))
	cBuf := (*[1 << 30]byte)(cPtr)
	copy(cBuf[:len(goBytes)], b.Bytes())

	return C.res { cont:(*C.char)(cPtr), leng:C.int(s_C) }
}
