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
	"compress/zlib"
	"compress/gzip"
	"github.com/google/brotli/go/cbrotli"
);

type comp[T io.Writer] func(io.Writer) T
type de_comp[T io.Reader] func(io.Reader) (T, error)
 
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

func generic_de_comp[T io.Reader](
	data *C.char,
	length C.int,
	de_comp de_comp[T],
) C.res {
	go_bytes := c_chars_to_go_bytes(data, length)
	b := bytes.NewBuffer(go_bytes)
	re, e := de_comp(b)
	if e != nil {
		fmt.Printf("failed to create de compressor: %v", e)
		return C.res{cont:nil,leng:0}
	}
	uncomp, e := io.ReadAll(re)
	if e != nil && e != io.EOF {
		fmt.Printf("cgo failed to decompress: %v", e)
		return C.res{cont:nil,leng:0}
	}
	c_chars, c_int := copy_bytes_to_c_char(uncomp)
	return C.res{cont:c_chars,leng:c_int}
}

//compress gzip
//export Gz
func Gz(data *C.char, length C.int) C.res {
	return generic_comp(data, length, func(w io.Writer) io.WriteCloser {
		return gzip.NewWriter(w)
	})
}

//compress zlib
//export Zlib
func Zlib(data *C.char, length C.int) C.res {
	return generic_comp(data, length, func(w io.Writer) io.WriteCloser {
		return zlib.NewWriter(w)
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
	return generic_de_comp(data, length, func(w io.Reader) (io.Reader, error) {
		return cbrotli.NewReader(w), nil
	})
}

//decompress gzip
//export De_Gz
func De_Gz(data *C.char, length C.int) C.res {
	return generic_de_comp(data, length, func(w io.Reader) (io.Reader, error) {
		return gzip.NewReader(w)
	})
}

//decompress zlib
//export De_Zlib
func De_Zlib(data *C.char, length C.int) C.res {
	return generic_de_comp(data, length, func(w io.Reader) (io.Reader, error) {
		return zlib.NewReader(w)
	})
}
