package main

import (
	"fmt"
	"strings"
)

func print_id(bod []byte) {
	server_no_proto := strings.Split(server, "://")[1]
	id := string(bod)
	l1 := fmt.Sprintf("%s  %s[%sid%s]:%s %s %s",
			"\033[48;2;16;23;41m", "\033[1;38;2;125;134;177m",
			"\033[1;38;2;192;153;255m", "\033[1;38;2;125;134;177m",
			"\033[22;38;2;255;255;255m", id, "\033[0m")
	l2 := fmt.Sprintf("%s %s[%surl%s]:%s %s/view?id=%s%s %s",
			"\033[48;2;16;23;41m", "\033[1;38;2;125;134;177m",
			"\033[1;38;2;255;199;119m", "\033[1;38;2;125;134;177m",
			"\033[22;38;2;255;255;255m", server_no_proto, "\033[1m",
			id, "\033[0m")
	var longest int ; for _, l := range []string{ l1, l2, } {
		if len_no_esc(l) > longest { longest = len_no_esc(l) }
	}
	for i, l := range []string{ l1, l2 } {
		if len_no_esc(l) < longest {
			diff := longest-len_no_esc(l)
			for _ = range diff { l += "\033[48;2;16;23;41m \033[0m" }
		}
		switch i { case 0: l1 = l ; case 1: l2 = l }
	}
	smart_print("%s\n%s\n", l1, l2)
}
