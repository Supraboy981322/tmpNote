package main

/*
#include <stdio.h>
#include <stdlib.h>
typedef struct {
	char *cont;
	int leng;
} res;
*/
import "C"
import (
	"io"
	"fmt"
	"bytes"
	"unsafe"
	"compress/gzip"
);
 
func main() {}

//convert *C.char to []byte
func c_chars_to_go_bytes(data *C.char, length C.int) []byte {
	return C.GoBytes(unsafe.Pointer(data), length)
}

func copy_bytes_to_c_char(b []byte) (*C.char, C.int) {
	//size of compressed data
	s_C := len(b)

	//a C pointer to the data
	cPtr := C.malloc(C.size_t(s_C))
	cBuf := (*[1 << 30]byte)(cPtr) //create a C Buffer

	//copy data to C buffer
	copy(cBuf[:s_C], b)

	return (*C.char)(cPtr), C.int(s_C)
}

//gzip
//export Gz
func Gz(data *C.char, length C.int) C.res {
	goBytes := c_chars_to_go_bytes(data, length)

	//compress data
	var b bytes.Buffer
	gz := gzip.NewWriter(&b)
	if _, e := gz.Write(goBytes); e != nil {
		fmt.Printf("cgo err{%v}\n", e)
		return C.res { cont:nil, leng:0 }
	}

	//close compressor (is that the right term?)
	if e := gz.Close(); e != nil { 
		fmt.Printf("cgo err{%v}\n", e)
		return C.res { cont:nil, leng:0 }
	}

	c_chars, c_size :=  copy_bytes_to_c_char(b.Bytes())

	//return the struct
	return C.res { cont:c_chars, leng:c_size }
}

//export De_Gz
func De_Gz(data *C.char, length C.int) C.res {
	//convert *C.char to []byte
	goBytes := C.GoBytes(unsafe.Pointer(data), length)

	//compress data
	b := bytes.NewBuffer(goBytes)
	gz, e := gzip.NewReader(b)
	if e != nil {
		fmt.Printf("cgo err{%v}\n", e)
		return C.res { cont:nil, leng:0 }
	}
	defer gz.Close()

	uncomp, e := io.ReadAll(gz)
	if e != nil && e != io.EOF {
		fmt.Printf("cgo err{%v}\n", e)
		return C.res { cont:nil, leng:0 }
	}

	//size of compressed data
	s_C := len(uncomp)

	//a C pointer to the data
	cPtr := C.malloc(C.size_t(s_C))
	cBuf := (*[1 << 30]byte)(cPtr) //create a C Buffer

	//copy data to C buffer
	copy(cBuf[:s_C], uncomp)

	//return the struct
	return C.res { cont:(*C.char)(cPtr), leng:C.int(s_C) }
}
