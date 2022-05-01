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
 - Ctrl R, (not working properly yet and is only meant for VDE.v) save, compile, run the new VDE file, and close the old instance.
 - Ctrl [ or ], switch between files in directory

To do:
- Alpha:
  - [x] Allow editing (one character at a time)
  - [x] Highlighting for primatives
  - [ ] Highlighting for keywords (partial)
  - [ ] More efficient rendering
  - [ ] Horizontal scroll capping
  - [ ] Text cursor following
  - [ ] Text highlighting
  - [ ] Copy/Paste
  - [ ] Add bottom bar for save state and row+col info
  - [ ] Argument launching
  - [ ] Add more to this list
  - [ ] Add word by word "hopping"
  - [ ] Add a way to make new file
  - [ ] Scaling
  - [ ] Drag and drop support

- Beta
  - [ ] Add to this list

- Release
  - [ ] Add to this list
