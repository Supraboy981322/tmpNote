package main

import (
	"os"
	"fmt"
	"errors"
)

type (
	Note struct {
		Val []byte
		Key string
	}
	Args struct {
		Args struct {
			V []string
			N int
		}
		Cur struct {
			Pos int
			Arg string
		}
		Used struct {
			Map map[string]int
			Tak []int
		}
	}
)

var (
	note Note
	server string
	args = Args{
		Args: struct {
			V []string
			N int
		}{
			V: os.Args[1:],
			N: len(os.Args[1:]),
		},
		Cur: struct {
			Pos int
			Arg string
		}{ Pos: -1 },
		Used: struct {
			Map map[string]int
			Tak []int
		}{
			Map: map[string]int{},
			Tak: []int{},
		},
	}
)

func init() {
	if args.Args.N < 1 {
		e := errors.New("not enough args "+
				"(printing \033[48;2;100;25;175m"+
				"\033[38;2;255;255;255m --help "+
				"\033[48;2;255;255;255m"+
				"\033[1;38;2;210;0;0m)")
		eror("invalid arg", e)
		help() ; os.Exit(1)
	}
	{
		args.parse()
		var has_err bool
		for k, v := range map[string][]byte{
			"note value": note.Val,
			"note key": []byte(note.Key),
		} {
			if len(v) == 0 {
				e := fmt.Errorf("missing %s", k)
				eror("invalid command", e)
				has_err = true
			}
		}
		if has_err { os.Exit(1) }
	}
}

func main() {
	fmt.Printf("server{%s}\nkey{%s}\nval{%s}\n", server, note.Key, note.Val)
}
