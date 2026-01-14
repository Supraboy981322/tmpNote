package main

import (
	"os"
	"fmt"
	"strconv"
	"golang.org/x/term"
)

func eror(msg string, e error) {
	msg = fmt.Sprintf("\033[1;38;2;255;255;255m"+
				"\033[48;2;210;0;0m %s \033[0m\n", msg)
	if e != nil {
		msg = fmt.Sprintf("%s   "+
				"\033[48;2;255;255;255m"+
				" \033[1;38;2;210;0;0m%v \033[0m\n",
				msg, e)
	}
	Fsmart_print(os.Stderr, msg)
}

func erorF(msg string, e error) {
	eror(msg, e) ; os.Exit(1)
}

func len_no_esc(l string) int {
	return len(strip_esc(l))
}

func strip_esc(s string) string {
	var res string ; var esc bool
	for _, c := range s {
		if c != '\033' {
			if esc {
				_, e := strconv.Atoi(string(c))
				if c != ';' && c != '[' && e != nil { esc = false }
			} else { res += string(c) }
		} else { esc = true }
	}
	return res
}

func Fsmart_print(f *os.File, msg string, a ...any) {
	l := fmt.Sprintf(msg, a...)
	fd := int(f.Fd())
	if !term.IsTerminal(fd) { l = strip_esc(l) }
	fmt.Fprint(f, l)
}

func smart_print(msg string, a ...any) {
	Fsmart_print(os.Stdout, msg, a...)
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
		"      usage: "+cols["purple"]+"tN "+cols["yel"]+"--value "+cols["purple"]+"\"some message\"                         ",
		"  "+cols["blue"]+"--view"+cols["white"]+", "+cols["blue"]+"--get"+cols["white"]+", "+cols["blue"]+"-g"+cols["white"]+", "+cols["blue"]+"-V"+cols["white"]+"                                        ",
		"    view an existing note                                      ",
		"      usage: "+cols["purple"]+"tN "+cols["yel"]+"--view "+cols["purple"]+"--key \"your key\"                        ",
		"  "+cols["blue"]+"--set"+cols["white"]+", "+cols["blue"]+"--new"+cols["white"]+", "+cols["blue"]+"--mk"+cols["white"]+", "+cols["blue"]+"--make"+cols["white"]+", "+cols["blue"]+"-s"+cols["white"]+", "+cols["blue"]+"-n"+cols["white"]+"                           ",
		"    create a new note                                          ",
		"      usage: "+cols["purple"]+"tN "+cols["yel"]+"--new"+cols["purple"]+" \"your message\"                           ",
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
	lines = append(lines, "")
	for i, l := range lines {
		_ = i
		li_len := len_no_esc(l)
		diff := (termWidth-li_len)/2
		for _ = range diff { l = colOff+" "+bg["def"]+l } 
		l = bg["def"]+l+colOff
		smart_print(l+"\n")
	}
}
