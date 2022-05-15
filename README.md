# VDE
An IDE built in V for V.

This is alpha software as of now. As such, this code may contain bugs that lead to data loss. 

Install and run steps:
  ```bash
  git clone https://github.com/Jah-On/VDE
  cd VDE
  v VDE.v -gc boehm
  ./VDE
  ```

Current shortcuts:
 - Ctrl S, save file
 - Ctrl Q, exit without saving
 - Ctrl [ or ], switch between files in directory

To do:
- Alpha:
  - [x] Allow editing (one character at a time)
  - [x] Highlighting for primatives
  - [x] Highlighting for keywords
  - [x] Highlighting for single line comments
  - [x] Highlighting for strings
  - [x] Highlighting for multi line comments
  - [ ] Highlighting for numbers
  - [x] More efficient rendering
  - [ ] Horizontal scroll capping
  - [x] Text cursor following
  - [ ] Text highlighting
  - [ ] Copy/Paste
  - [ ] Add bottom bar for save state and row+col info
  - [ ] Argument launching
  - [ ] Add word by word "hopping"
  - [ ] Add a way to make new file
  - [ ] Scaling
  - [ ] Drag and drop support

- Beta
  - [ ] Add to this list

- Release
  - [ ] Add to this list
