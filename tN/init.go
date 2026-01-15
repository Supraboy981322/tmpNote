package main

import (
	"os"
	"fmt"
	"errors"
	"slices"
	"strings"
	"net/url"
	"path/filepath"
	"golang.org/x/term"
)

func chkTerm() {
	errFd := int(os.Stderr.Fd())
	outFd := int(os.Stdout.Fd())
	if term.IsTerminal(outFd) { term_chk.stdout = true }
	if term.IsTerminal(errFd) { term_chk.stderr = true }
}

func (args *Args) dupe(a, cut, old string, aN int) {
	decl := args.Used.Map[old]
	if decl == 0 { return }
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
		 case "key": if act != "" && note.Key != "" { return }
			if note.Key != "" { args.dupe(arg, cut, "--key", aN) }
			note.Key = args.next()
			if note.Key == "" {
				e := fmt.Errorf("called --key arg, but no value given")
				erorF("invalid arg", e)
			}
		 case "value", "val": if act != "" && note.Val != nil { return }
			if note.Val != nil { args.dupe(arg, cut, "--val", aN) }
			note.Val = []byte(args.next())
			if note.Val == nil {
				e := fmt.Errorf("called --value arg, but no value given")
				erorF("invalid arg", e)
			}
		 case "server":
			if server != "" { args.dupe(arg, cut, "--server", aN) }
			server = args.next()
			if server == "" {
				e := fmt.Errorf("called --server arg, but no value given")
				erorF("invalid arg", e)
			}
		 case "view", "get": 
			act = "set" ; if note.Key == "" {
				note.Key = args.next()
			}
		 case "set", "new", "mk", "make": 
			act = "set" ; if note.Val == nil {
				note.Val = []byte(args.next())
			}
		 case "help": help() ; os.Exit(0)
		 default:
			e := fmt.Errorf("--> %s", cut+arg)
			erorF("invalid arg", e)
		}
	} else {
		for _, a := range arg {
			switch a {
			 case 'k': if act != "" && note.Key != "" { continue }
				if note.Key != "" { args.dupe(arg, cut, "--key", aN) }
				note.Key = args.next()
				if note.Key == "" {
					e := fmt.Errorf("called -k arg, but no value given")
					erorF("invalid arg", e)
				}
			 case 'v': if act != "" && note.Val != nil { continue }
				if note.Val != nil { args.dupe(arg, cut, "--val", aN) }
				note.Val = []byte(args.next())
				if note.Val == nil {
					e := fmt.Errorf("called -v arg, but no value given")
					erorF("invalid arg", e)
				}
			 case 'S':
				if server != "" { args.dupe(arg, cut, "--server", aN) }
				server = args.next()
				if server == "" {
					e := fmt.Errorf("called -S arg, but no value given")
					erorF("invalid arg", e)
				}
			 case 'g', 'V':
				act = "view" ; if note.Key == "" {
					note.Key = args.next()
				}
			 case 's', 'n': 
				act = "set" ; if note.Val == nil {
					note.Val = []byte(args.next())
				}
			 case 'h': help() ; os.Exit(0)
			 default:
				e := fmt.Errorf("--> %s", cut+arg)
				erorF("invalid arg", e)
			}
		}
	}
	args.Used.Map[cut+arg] = aN+1
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

func parseConf() error {
	home, e := os.UserHomeDir()
	if e != nil { erorF("failed to get home dir for config", e) }

	conf_path := home
	for _, p := range []string {
		".config", "Supraboy981322", "tmpNote", "config",
	} { conf_path = filepath.Join(conf_path, p) }

	conf_B, e := os.ReadFile(conf_path)
	if e != nil {
		if strings.Contains(e.Error(), home) {
			e = fmt.Errorf(strings.ReplaceAll(e.Error(), home, "~"))
		}; return e
	}; conf_str := string(conf_B)

	c_eror := func (msg string, l string, lN int) {
		eror("failed to parse config", fmt.Errorf(msg))
		fmt.Printf("  %d |   %s\n", lN, l)
	}

	for li_N, l := range strings.Split(conf_str, "\n") {
		l = strings.TrimSpace(l)
		if l == "" { continue }
		if len(l) > 2 { if l[:2] == "//" { continue } }
		pair := strings.Split(l, ":")
		for i, _ := range pair { pair[i] = strings.TrimSpace(pair[i]) }
		if len(pair) > 2 {
			if len(pair) <= 1 {
				c_eror("invalid key-value pair", l, li_N)
			} else { c_eror("missing value", l, li_N) }
		}

		k, v := pair[0], pair[1]
		if k == "" { c_eror("key is empty", l, li_N) }
		if v == "" { c_eror("value is empty", l, li_N) }

		switch k {
		 case "server": server = v
		 default: c_eror("invalid option key", l, li_N) 
		}
	}
 
	return nil
}

func ensure_args() {
	switch act {
	 case "view": if note.Key == "" {
			e := fmt.Errorf("need note key")
		  erorF("missing arg", e)
		}
	 case "set": if note.Val == nil {
			e := fmt.Errorf("need note value")
		  erorF("missing arg", e)
	  }
	 case "":
		e := errors.New("need action")
		erorF("missing arg", e)
	 default:
		e := errors.New("(action: '"+act+"') --> init()")
		erorF("you forgot to add another case for new action", e)
	}
	u, e := url.Parse(server)
	if e != nil { erorF("failed to server parse url", e) }
	if !u.IsAbs() { server = "https://"+server }
}
