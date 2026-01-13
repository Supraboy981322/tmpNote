package main

import (
	"os"
	"fmt"
	"slices"
)

func eror(msg string, e error) {
	if e != nil {
		msg = fmt.Sprintf("\033[1;38;2;255;255;255m"+
				"\033[48;2;210;0;0m"+
				" %s \033[0m\n   "+
				"\033[48;2;255;255;255m"+
				" \033[1;38;2;210;0;0m%v \033[0m\n",
				msg, e)
	}
	fmt.Fprint(os.Stderr, msg)
}

func erorF(msg string, e error) {
	eror(msg, e)
	os.Exit(1)
}

func (args *Args) dupe(a, cut, old string, aN int) {
	e := fmt.Errorf("called %s (arg #%d), "+
			"but %s (arg %d) was already set",
			cut+a, aN, old, args.Used.Map[old])
	erorF("invalid arg", e)
}

func (args *Args) parse() {
	args.advance()
	aN := args.Cur.Pos
	if aN >= args.Args.N { return }
	if slices.Contains(args.Used.Tak, aN) {
		args.parse() ; return
	}

	args.Cur.Arg = args.Args.V[aN]
	cut := string(args.Cur.Arg[0])
	args.Cur.Arg = args.Cur.Arg[1:]
	arg := args.Cur.Arg
	if len(args.Cur.Arg) < 1 {
		e := fmt.Errorf("--> %s", cut+arg)
		erorF("invalid arg", e)
	}
	if arg[0] == '-' {
		switch arg[1:] {
		 case "key":
			if note.Key != "" {
				args.dupe(arg, cut, "--key", aN)
			} else {
				note.Key = args.next()
				if note.Key == "" {
					e := fmt.Errorf("called --key arg, but no value given")
					erorF("invalid arg", e)
				}
			}
		 case "value", "val":
			if note.Val != nil {
				args.dupe(arg, cut, "--val", aN)
			} else {
				note.Val = []byte(args.next())
				if note.Val == nil {
					e := fmt.Errorf("called --value arg, but no value given")
					erorF("invalid arg", e)
				}
			}
		 case "server":
			if server != "" {
				args.dupe(arg, cut, "--server", aN)
			} else {
				server = args.next()
				if server == "" {
					e := fmt.Errorf("called --server arg, but no value given")
					erorF("invalid arg", e)
				}
			}
		 default:
			e := fmt.Errorf("--> %s", cut+arg)
			erorF("invalid arg", e)
		}
	} else {
		for _, a := range arg {
			switch a {
			 case 'k':
				if note.Key != "" {
					args.dupe(arg, cut, "--key", aN)
				} else {
					note.Key = args.next()
					if note.Key == "" {
						e := fmt.Errorf("called -k arg, but no value given")
						erorF("invalid arg", e)
					}
				}
			 case 'v':
				if note.Val != nil {
					args.dupe(arg, cut, "--val", aN)
				} else {
					note.Val = []byte(args.next())
					if note.Val == nil {
						e := fmt.Errorf("called -v arg, but no value given")
						erorF("invalid arg", e)
					}
				}
			 case 'S':
				if server != "" {
					args.dupe(arg, cut, "--server", aN)
				} else { 
					server = args.next()
					if server == "" {
						e := fmt.Errorf("called -S arg, but no value given")
						erorF("invalid arg", e)
					}
				}
			 default:
				e := fmt.Errorf("--> %s", cut+arg)
				erorF("invalid arg", e)
			}
		}
	}
	args.Used.Map[cut+arg] = aN
	if args.Args.N > args.Cur.Pos {
		args.parse()
	}
}

func (args *Args) next() string {
	aN := args.Cur.Pos
	args.Used.Tak = append(args.Used.Tak, aN+1)
	if args.Args.N <= aN+1 { return "" }
	return args.Args.V[aN+1]
}

func (args *Args) advance() {
	if args.Cur.Pos != -1 {
		aN := args.Cur.Pos
		args.Used.Tak = append(args.Used.Tak, aN)
	}
	args.Cur.Pos++
}
