module vlang

import gx
import os
import pacs

pub fn load(path string) &pacs.File {
	mut rtrn := &pacs.File {
		lang:      "V"
		path:      path
		read_only: !os.is_writable(path)
	}
	if os.is_executable(path){
		rtrn.alt = "This file is executable, will not display contents."
		return rtrn
	}
	if !os.is_readable(path){
		rtrn.alt = "Could not open file. Not readable."
		return rtrn
	}
	mut file_obj := os.open(path) or {
		println("The program should never crash here (Line 32). Please submit a GitHub issue!")
		exit(404)
	}
	rtrn.lines = file_obj.read_bytes(int(os.file_size(path))).bytestr().replace("\r", "").split("\n")
	return rtrn
}

pub fn parse(scale f32, mut file &pacs.File){
	file.rlines = file.lines
	file.kws.clear()
	mut last := 0
	mut in_comment := false
	mut nested_comments := 0 // For that one maniac... you're welcome
	mut in_string := false
	mut entry_char := ""
	// mut in_structure := false
	// mut open_p_or_b_or_cb := 0
	for line in 0 .. file.lines.len {
		if file.rlines[line].len * 13 > file.xmax {file.xmax = file.rlines[line].len * 13}
		for {
			if last >= file.rlines[line].len {
				break
			}
			if file.rlines[line].substr(last, last + 1) != "\t"{
				last++
			} else {
				file.rlines[line] = file.rlines[line].replace_once("\t", " ".repeat(4 - last % 4))
			}
		}
		last = 0
		for index in 0 .. file.rlines[line].len {
			if in_comment {
				if index > 0 {
					if file.rlines[line].substr(index - 1, index + 1) == "*/"{
						nested_comments--
					}
					if file.rlines[line].substr(index - 1, index + 1) == "/*"{
						nested_comments++
					}
				}
				if nested_comments == 0 {
					file.kws << pacs.Highlight{
						text:  file.rlines[line].substr(last, index + 1)
						color: gx.rgb(0, 50, 50)
						line:  line
						col:   last
						x:     int(last * 13 * scale)
						y:     int(line * 30 * scale)
					}
					in_comment = false
					last = index + 1
				} else if index == file.rlines[line].len - 1 {
					file.kws << pacs.Highlight{
						text:  file.rlines[line].substr(last, index + 1)
						color: gx.rgb(0, 50, 50)
						line:  line
						col:   last
						x:     int(last * 13 * scale)
						y:     int(line * 30 * scale)
					}
				}
			}
			else if in_string {
				if index > 0 {
					if (file.rlines[line].substr(index, index + 1) == entry_char) && (file.rlines[line].substr(index - 1, index) != "\\"){
						file.kws << pacs.Highlight{
							text:  file.rlines[line].substr(last, index + 1)
							color: gx.rgb(255, 175, 75)
							line:  line
							col:   last
							x:     int(last * 13 * scale)
							y:     int(line * 30 * scale)
						}
						in_string = false
						last = index + 1
					}
				}
				else if file.rlines[line].substr(index, index + 1) == entry_char {
					file.kws << pacs.Highlight{
						text:  file.rlines[line].substr(last, index + 1)
						color: gx.rgb(255, 175, 75)
						line:  line
						col:   last
						x:     int(last * 13 * scale)
						y:     int(line * 30 * scale)
					}
					in_string = false
					last = index + 1
				}
				if index == file.rlines[line].len - 1 {
					file.kws << pacs.Highlight{
						text:  file.rlines[line].substr(last, index + 1)
						color: gx.rgb(255, 175, 75)
						line:  line
						col:   last
						x:     int(last * 13 * scale)
						y:     int(line * 30 * scale)
					}
				}
			}
			else if file.rlines[line].substr(index, index + 1) in [" ", "\t", ",", ":", "(", ")", "[", "]", "{", "}"]{
				last = index + 1
			} else
			if !in_comment && (file.rlines[line].substr(last, index + 1) in kw_list) && (file.rlines[line].substr(index + 1, index + 1 + int(index + 1 < file.rlines[line].len)) in ["", " ", "\t", ",", ":", "(", ")", "[", "]", "{", "}"]) {
				file.kws << pacs.Highlight{
					text:  file.rlines[line].substr(last, index + 1)
					color: kw_map[file.rlines[line].substr(last, index + 1)]
					line:  line
					col:   last
					x:     int(last * 13 * scale)
					y:     int(line * 30 * scale)
				}
				last = index + 1
			} 
			else
			if file.rlines[line].substr(last, index + 1) == "//" {
				file.kws << pacs.Highlight{
					text:  file.rlines[line].substr(last, file.rlines[line].len)
					color: gx.rgb(0, 50, 50)
					line:  line
					col:   last
					x:     int(last * 13 * scale)
					y:     int(line * 30 * scale)
				}
				last = 0
				break
			}
			else if file.rlines[line].substr(last, index + 1) == "/*" {
				if index == file.rlines[line].len - 1 {
					file.kws << pacs.Highlight{
						text:  file.rlines[line].substr(last, index + 1)
						color: gx.rgb(0, 50, 50)
						line:  line
						col:   last
						x:     int(last * 13 * scale)
						y:     int(line * 30 * scale)
					}
				}
				in_comment = true
				nested_comments++
			}
			else if file.rlines[line].substr(index, index + 1) in ["\"", "\'"] {
				entry_char = file.rlines[line].substr(index, index + 1)
				if index == file.rlines[line].len - 1 {
					file.kws << pacs.Highlight{
						text:  file.rlines[line].substr(last, index + 1)
						color: gx.rgb(255, 175, 75)
						line:  line
						col:   last
						x:     int(last * 13 * scale)
						y:     int(line * 30 * scale)
					}
				}
				in_string = true
			}
		}
		last = 0
	}
}

pub fn save(mut file &pacs.File){
	if !file.read_only {
		mut file_obj := os.open_file(file.path, "w", 1) or {
			println("Unable to open file to write.")
			return
		}
		file_obj.write_string(file.lines.join_lines()) or {
			println("Unable to write to file.")
			return
		}
		file_obj.close()
	}
}