package main

import (
	"os"
	"fmt"
	"slices"
	"strings"
	"path/filepath"
	"golang.org/x/term"
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
		 case "key":
			if note.Key != "" { args.dupe(arg, cut, "--key", aN) }
			note.Key = args.next()
			if note.Key == "" {
				e := fmt.Errorf("called --key arg, but no value given")
				erorF("invalid arg", e)
			}
		 case "value", "val":
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
		 case "help": help() ; os.Exit(0)
		 default:
			e := fmt.Errorf("--> %s", cut+arg)
			erorF("invalid arg", e)
		}
	} else {
		for _, a := range arg {
			switch a {
			 case 'k':
				if note.Key != "" { args.dupe(arg, cut, "--key", aN) }
				note.Key = args.next()
				if note.Key == "" {
					e := fmt.Errorf("called -k arg, but no value given")
					erorF("invalid arg", e)
				}
			 case 'v':
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

//looks like spagetti, I know
//  I wrote a script to generate valid Go string slice code,
//    since it's the same output every time I could save on compute
//      by just having the window prerendered and just print it
func help() {
	cols := map[string]string{
		"purple": "\033[38;2;145;125;255m",
		"blue": "\033[38;2;0;150;255m",
		"itals": "\033[3m",
		"red": "\033[38;2;200;35;30m",
		"yel": "\033[38;2;255;255;100m",
		"white": "\033[38;2;255;255;255m",
	} ; colOff := "\033[0m"
	bg := map[string]string{
		"def": "\033[48;2;16;23;41m",
		"white": "\033[48;2;255;255;255m",
//		"def": "\033[48;2;255;255;255m",
	}

	//said spagett
	lines := []string{
		"                                                               ",
		"                       "+cols["red"]+cols["itals"]+"//tmpNote"+cols["white"]+" -- "+cols["yel"]+"help"+cols["white"]+"                       ",
		"  "+cols["blue"]+"--help"+cols["white"]+", "+cols["blue"]+"-h"+cols["white"]+"                                                   ",
		"    returns this and exits                                     ",
		"  "+cols["blue"]+"--key"+cols["white"]+", "+cols["blue"]+"-k"+cols["white"]+"                                                    ",
		"    set the key for the note                                   ",
		"      usage: "+cols["purple"]+"tN "+cols["yel"]+"--key"+cols["purple"]+" \"your key\"                               ",
		"  "+cols["blue"]+"--value"+cols["white"]+", "+cols["blue"]+"--val"+cols["white"]+", "+cols["blue"]+"-v"+cols["white"]+"                                           ",
    "    set the value for the note                                 ",
		"\033[1D      usage: "+cols["purple"]+"tN "+cols["yel"]+"--value "+cols["purple"]+"\"some message\"                         ",
		"  "+cols["blue"]+"--view"+cols["white"]+", "+cols["blue"]+"--get"+cols["white"]+", "+cols["blue"]+"-g"+cols["white"]+", "+cols["blue"]+"-V"+cols["white"]+"                                        ",
		"    view an existing note                                      ",
		"      usage: "+cols["purple"]+"tN "+cols["yel"]+"--view "+cols["purple"]+"--key \"your key\"                        ",
		"\033[1D  "+cols["blue"]+"--set"+cols["white"]+", "+cols["blue"]+"--new"+cols["white"]+", "+cols["blue"]+"--mk"+cols["white"]+", "+cols["blue"]+"--make"+cols["white"]+", "+cols["blue"]+"-s"+cols["white"]+", "+cols["blue"]+"-n"+cols["white"]+"                           ",
		"    create a new note                                          ",
		"      usage: "+cols["purple"]+"tN "+cols["yel"]+"--new"+cols["purple"]+" --key \"your key\" --value \"your message\"  ",
		"                                                               ",
	}

	var termWidth int ; {
		fd := int(os.Stdout.Fd())
		if !term.IsTerminal(fd) {
			fmt.Fprintln(os.Stderr, "non-terminals are unsupported at the moment")
			os.Exit(1)
		}
		var e error
		termWidth, _, e = term.GetSize(fd)
		if e != nil { eror("failed to get term size", e) }
	}
	len_no_esc := func(l string) int {
		var res int ; var esc bool
		for _, c := range l {
			switch c {
			 case '\033': esc = true
			 case 'm', 'D': esc = false
			 default: if !esc { res++ }
			}
		}
		return res
	}; _ = len_no_esc
	fmt.Println("")
	for i, l := range lines {
		_ = i
		li_len := len_no_esc(l)
		diff := (termWidth-li_len)/2
		for _ = range diff { l = colOff+" "+bg["def"]+l } 
		l = bg["def"]+l+colOff
		fmt.Println(l)
	}
}
