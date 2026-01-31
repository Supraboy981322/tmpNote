# tmpNote

A basic self-hosted privnote alternative

---

## Installation

### Client
- Go install

  Requires `Go` to be installed and your GOBIN to be in your `$PATH`
  ```sh
  go install github.com/Supraboy981322/tmpNote/tN@latest
  ```
  (The command is `tN`)


### Server
- Compile from sources

  Requires `nix` and `git`

  - Clone the repo
    ```sh
    git clone https://github.com/Supraboy981322/tmpNote.git
    ```
  - Move to the repository directory
    ```sh
    cd tmpNote
    ```
  - enter Nix development shell
    ```sh
    nix develop
    ```
  - Compile
    ```sh
    build_tmpNote
    ```
  - Exit Nix development shell
    ```sh
    exit
    ```
    The final binary will be located in `./zig-out/bin/`

## Features

If a feature is not checked off, it is not yet implemented, but is planned. 

- [x] Make a note
- [x] View a note
- [x] auto delete notes
- [x] link to a note
- [ ] set an expiration date/time for a note
- [ ] files
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

[see the `TODO.md`](/TODO.md)
