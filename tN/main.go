package main

import (
	"io"
	"os"
	"fmt"
	"time"
	"bytes"
	"errors"
	"net/url"
	"net/http"
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
	act string
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

	if e := parseConf(); e != nil {
		erorF("failed to parse config", e)
	}

	{
		args.parse()
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
}

func main() {
	mkReq()
}

func mkReq() {
	var req *http.Request
	switch act {
	 case "set":
		val_buf := bytes.NewBuffer(note.Val)
		var e error
		req, e = http.NewRequest("POST", server+"/api_new", val_buf)
		if e != nil { erorF("failed to create new request", e) }	
	 case "view":
		var e error
		empty_body := bytes.NewBuffer(nil)
		req, e = http.NewRequest("GET", server+"/api_view", empty_body)
		if e != nil { erorF("failed to create new request", e) }	
		req.Header.Set("id", note.Key)
	 default:
		e := errors.New("--> mkReq()")
		erorF("you forgot to add another case for new action", e)
	}
	client := &http.Client{
		Timeout: time.Second * 5,
	}
	resp, e := client.Do(req)
	if e != nil { erorF("failed to make request", e) }
	defer resp.Body.Close()

	bod, e := io.ReadAll(resp.Body)
	if e != nil { erorF("failed to read response body", e) }
	switch act {
	 case "set": print_id(bod)
	 case "view":
		os.Stdout.Write(bod)
		fmt.Println("")
	 default:
		erorF("your forgot to create a case for new action (printing resp body)", nil) 
	}
}
