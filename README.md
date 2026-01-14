# tmpNote

A basic self-hosted privnote alternative

---

## Installation

### Client
- Go install

  Requires `Go` to be installed and your GOBIN to be in your `$PATH`
  ```sh
  go install github.com/Supraboy981322/tmpNote/tN
  ```
  (The command is `tN`)


### Server
- Compile from sources

  Requires precisely version 0.15.2 of Zig ((official "getting started" page)[https://ziglang.org/learn/getting-started/])

  - Clone the repo
    ```sh
    git clone https://github.com/Supraboy981322/tmpNote.git
    ```
  - Move to the repository directory
    ```sh
    cd tmpNote
    ```
  - Compile
    ```sh
    zig build
    ```
    The final binary will be located in `./zig-out/bin/`

## Features

If a feature is not checked off, it is not yet implemented, but is planned. 

- [x] Make a note
- [x] View a note
- [x] auto delete notes
- [x] link to a note
- [x] db is non-persistent (wiped when restarted)
- [x] webui
  - [ ] dashboard
- [x] cli
  - [x] tool
  - [ ] tool wrapper with tui
- [x] api
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
    - [x] parsing headers for note ID 
    - [x] parsing headers for new note
    - [x] parsing query params for new note
    - [x] reading POST request body for note content
    - [x] replacing HTML placeholder comment with note
    - [x] replying with the note ID when creating a new note
    - [x] determine api vs webui requests
    - [x] dedicated api http handlers
    - [ ] Better web ui
  - [x] Catch-up to Go proto
