# tmpNote

A basic self-hosted privnote alternative

---

## Features

If a feature is not checked off, it is not yet implemented, but is planned. 

- [x] Make a note
- [x] View a note
- [x] auto delete notes
- [x] link to a note
- [x] db is non-persistent (wiped when restarted)
- [x] webui
  - [ ] dashboard
- [ ] cli
  - [ ] tool
  - [ ] tool wrapper with tui
- [ ] api
  - [ ] Spec
  - [ ] Go module
- [ ] mascot(?)

## Progress

- [x] Go prototype
  - [x] HTTP server
    - [x] parsing HTTP headers
    - [x] parsing query params
  - [x] database
  - [x] making notes
  - [x] viewing notes
  - [x] deleting notes when viewed
- [x] web prototype
- [x] Zig rewrite
  - [x] HTTP server
    - [x] parsing query params for note ID
    - [ ] parsing headers for note ID 
    - [x] parsing headers for new note
    - [ ] parsing query params for new note
    - [x] reading POST request body for note content
    - [x] replacing HTML placeholder comment with note
    - [x] replying with the note ID when creating a new note
    - [x] determine api vs webui requests
    - [x] dedicated api http handlers
  - [x] Catch-up to Go proto
