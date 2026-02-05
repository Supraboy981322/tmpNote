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
	"github.com/google/brotli/go/cbrotli"
);

type comp[T io.Writer] func(io.Writer) T
type de_comp[T io.Reader] func(io.Reader) T
 
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

func generic_comp[T io.WriteCloser](
	data *C.char,
	length C.int,
	comp comp[T],
) C.res {
	var buf bytes.Buffer
	wr := comp(&buf)

	go_bytes := c_chars_to_go_bytes(data, length)

	if _, e := wr.Write(go_bytes); e != nil {
		fmt.Printf("cgo generic compressor failed to write: %v", e)
		return C.res { cont:nil, leng:0 }
	}

	if e := wr.Close(); e != nil {
		fmt.Printf("failed to close genereic compressor: %v", e)
		return C.res { cont:nil, leng:0 }
	}

	c_chars, c_int := copy_bytes_to_c_char(buf.Bytes())
	return C.res { cont:c_chars, leng:c_int }
}

//compress gzip
//export Gz
func Gz(data *C.char, length C.int) C.res {
	return generic_comp(data, length, func(w io.Writer) io.WriteCloser {
		return gzip.NewWriter(w)
	})
}

//compress brotli
//export Br
func Br(data *C.char, length C.int) C.res {
	return generic_comp(data, length, func(w io.Writer) io.WriteCloser {
		wr_opts := cbrotli.WriterOptions{ Quality: 1 }
		return cbrotli.NewWriter(w, wr_opts)
	})
}

//decompress brotli
//export De_Br
func De_Br(data *C.char, length C.int) C.res {
	//goBytes := c_chars_to_go_bytes(data, length)
	//b := bytes.NewBuffer(goBytes)
	//br := cbrotli.NewReader(b)
	//defer br.Close(); 
	//uncomp, e := io.ReadAll(br)
	//if e != nil && e != io.EOF {
	//	fmt.Printf("cgo brotli err{%v}", e)
	//	return C.res { cont:nil, leng:0 }
	//}	
	//c_chars, c_size := copy_bytes_to_c_char(uncomp)
	//return C.res { cont:c_chars, leng:c_size }
	return generic_de_comp(data, length, func(w io.Reader) io.Reader {
		return cbrotli.NewReader(w)
	})
}

func generic_de_comp[T io.Reader](
	data *C.char,
	length C.int,
	de_comp de_comp[T],
) C.res {
	go_bytes := c_chars_to_go_bytes(data, length)
	b := bytes.NewBuffer(go_bytes)
	re := de_comp(b)
	uncomp, e := io.ReadAll(re)
	if e != nil && e != io.EOF {
		fmt.Printf("cgo failed to decompress: %v", e)
		return C.res{cont:nil,leng:0}
	}
	c_chars, c_int := copy_bytes_to_c_char(uncomp)
	return C.res{cont:c_chars,leng:c_int}
}

//decompress gzip
//export De_Gz
func De_Gz(data *C.char, length C.int) C.res {
	//convert *C.char to []byte
	goBytes := c_chars_to_go_bytes(data, length)

	//compress data
	b := bytes.NewBuffer(goBytes)
	gz, e := gzip.NewReader(b)
	if e != nil {
		fmt.Printf("cgo err{%v}\n", e)
		return C.res { cont:nil, leng:0 }
	}
	defer gz.Close()

	//get []byte from result
	uncomp, e := io.ReadAll(gz)
	if e != nil && e != io.EOF {
		fmt.Printf("cgo err{%v}\n", e)
		return C.res { cont:nil, leng:0 }
	}

	//copy []byte to a C allocator *char buffer
	c_chars, c_size := copy_bytes_to_c_char(uncomp)

	//return the struct
	return C.res { cont:c_chars, leng:c_size }
}
