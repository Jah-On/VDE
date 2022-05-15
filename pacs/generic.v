module pacs

import gx
import os

pub fn load(path string) &File {
	mut rtrn := &File {
		path:       path
		read_only:  !os.is_writable(path)
	}
	if os.is_executable(path){
		rtrn.alt = "This file is executable, will not display contents."
		return rtrn
	}
	if !os.is_readable(path){
		rtrn.alt = "Could not open file. Not readable."
		return rtrn
	}
	// mut file_obj := os.open(path) or {
	// 	println("The program should never crash here (Line 32). Please submit a GitHub issue!")
	// 	exit(404)
	// }
	rtrn.alt = "Can only show V files for now."
	// rtrn.lines = file_obj.read_bytes(int(os.file_size(path))).bytestr().split("\n")
	// rtrn.rlines = rtrn.lines
	return rtrn
}

pub fn (mut file File) parse(scale f32, xshift int, yshift int){
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////

[heap]
pub struct File {
pub mut:
	path        string
	lang        string
	alt         string
	read_only   bool
	lines       []string
	rlines      []string
	shift       []int = [0,0]
	edit        []int = [0,0]
	highlight   []int = [-1, -1]
	kws         []Highlight
	vars        []Variable
	xmax        int
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////

[heap]
pub struct Highlight {
pub mut:
	text    string
	color   gx.Color
	line    int
	col     int
	x       int
	y       int
}

[heap]
struct Variable {
pub mut:
	name    string
	typ     string
	mutx    bool
	sub     []Variable
}