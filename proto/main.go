package main

import (
	"io"
	"strings"
	_ "embed"
	"strconv"
	"net/http"
	"github.com/charmbracelet/log"
)

type (
	Server struct {
		Port int
		Name string
	}
	Config struct {
		Server Server
		Encrypt bool
	}
	Note struct {
		Content []byte
	}
)

//go:embed web/new_note.html
var newNotePage []byte

//go:embed web/view_note.html
var viewNotePage []byte

var (
	config = Config{
		Server: Server{
			Port: 9485,
			Name: "tmpNote",
		},
		Encrypt: false,
	}

	//mem only, doesn't need to persist 
	DB map[string]Note
)

func init() {
	DB = make(map[string]Note)
	/* TODO: config */
}

func main() {
	http.HandleFunc("/new", newNote)
	http.HandleFunc("/view", viewNote)
	http.HandleFunc("/dash", dashboard)
	http.HandleFunc("/", newNote)

	portStr := ":"+strconv.Itoa(config.Server.Port)
	log.Infof("listening on port %s", portStr[1:])
	if err := http.ListenAndServe(portStr, nil); err != nil {
		log.Fatal(err)
	}
}

func newNote(w http.ResponseWriter, r *http.Request) {
	var n string
	for _, h := range []string{"note", "n",} {
		if r.Header.Get(h) != "" { n = r.Header.Get(h) ; break }
	};if n == "" { nB, _ := io.ReadAll(r.Body) ; n = string(nB) }

	if n == "" {
		w.Header().Set("Content-Type", "text/html")
		w.Write(newNotePage)
		return
	}

	note := Note{
		Content: []byte(n),
	}
	
	id := genId(16)
	DB[id] = note

	w.Write([]byte(id))
}

func viewNote(w http.ResponseWriter, r *http.Request) {
	var id string
	for _, h := range []string{"id", "i",} {
		if r.Header.Get(h) != "" { id = r.Header.Get(h) ; break }
	};if id == "" {
		idB, _ := io.ReadAll(r.Body)
		id = string(idB)
	};if id == "" { id = r.URL.Query().Get("id") }
		
	n := DB[id].Content
	if n == nil  { n = []byte("invalid id") }

	if r.Method == "POST" {
		w.Header().Set("Content-Type", "text/plain")
		w.Write(n)
	} else if r.Method == "GET" {
		p := string(viewNotePage)
		splitStr := "<!-- split here -->"
		splitStart := strings.Index(p, splitStr)
		splitEnd := splitStart+len(splitStr)
		p = p[:splitStart]+string(n)+p[splitEnd:]

		w.Header().Set("Content-Type", "text/html")
		w.Write([]byte(p))
	} else { return }
	
	delete(DB, id) 
}

func dashboard(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte("todo: dashboard"))
}

