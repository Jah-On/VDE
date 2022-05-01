import clipboard
import gg
import gx
import math
import os
import time
// import v.ast
// import v.parser
import v.pref
import v.token
import v.scanner

const (
    key_map = {32:" ", 39:"\"\"", 44:"<", 45:"_", 46:">", 47:"?", 49:"!", 50:"@", 51:"#", 52:"$", 53:"%", 54:"^", 55:"&", 56:"*", 57:"(", 48:")", 59:":", 61:"+", 91:"{", 92:"|", 93:"}", 96:"~"}
)

[heap]
struct App {
mut:
    ctx             &gg.Context = 0
    cb              &clipboard.Clipboard = clipboard.new()
    wk_dir          string
    files_in_dir    []File
    open_files      []File
    current_file    &File = 0
    shift_down      bool
}

[heap]
struct File {
mut:
    path        string
    index       int
    contents    []Line = []
    alt         string
    ystart      int
    xshift      int
    edit        []int = [0,0]
    read_only   bool
    ref_files   []File
}

[heap]
struct Line {
mut:
    base    string
    tabs    [][]int
    tkns    []KeyWord
}

[heap]
struct KeyWord {
    str     string
    pos     []int
    color   gx.Color
}

fn (file File) save(){
    mut temp := ""
    mut output := ""
    for line in 0 .. file.contents.len{
        temp = file.contents[line].base
        for tab := file.contents[line].tabs.len - 1; tab >= 0; tab-- {
            temp = temp.substr(0, file.contents[line].tabs[tab][0]) + "\t" + temp.substr(file.contents[line].tabs[tab][1], temp.len)
        }
        output += temp
        if line < file.contents.len - 1{
            output += "\n"
        }
        temp = ""
    }
    mut file_obj := os.open_file(file.path, "w", 1) or {
        println("Unable to open file to write.")
        return
    }
    file_obj.write_string(output) or {
        println("Unable to write to file.")
        return
    }
    file_obj.close()
}

fn token_matcher(mut line &Line, token &token.Token, line_nr int){
    match token.kind {
        .comment {
            line.tkns << KeyWord{
                str:    "//" + " ".repeat(int(token.pos > 1)) + token.lit.substr(int(token.lit.len != 0), token.lit.len)
                pos:    [line.base.index("//") or {0}, line_nr]
                color:  gx.rgb(0, 50, 50)
            }
            println(token.col)
        }
        .key_as {
            line.tkns << KeyWord{
                str:    token.lit
                pos:    [token.col - 1, line_nr]
                color:      gx.rgb(255, 0, 255)
            }
        }
        .key_fn {
            line.tkns << KeyWord{
                str:    token.lit
                pos:    [token.col - 1, line_nr]
                color:      gx.rgb(255, 255, 128)
            }
        }
        .key_import {
            line.tkns << KeyWord{
                str:    token.lit
                pos:    [token.col - 1, line_nr]
                color:      gx.rgb(255, 0, 255)
            }
        }
        .key_struct {
            line.tkns << KeyWord{
                str:    token.lit
                pos:    [token.col - 1, line_nr]
                color:  gx.rgb(100, 100, 100)
            }
        }
        .name {
            if token.lit == "bool" {
                line.tkns << KeyWord{
                    str:    token.lit
                    pos:    [token.col - 1, line_nr]
                    color:      gx.rgb(0, 0, 255)
                }
                return
            }
            if token.lit in ["i8", "i16","int", "i64"] {
                line.tkns << KeyWord{
                    str:    token.lit
                    pos:    [token.col - 1, line_nr]
                    color:      gx.rgb(50, 100, 255)
                }
                return
            }
            if token.lit in ["u8", "u16","u32", "u64"] {
                line.tkns << KeyWord{
                    str:    token.lit
                    pos:    [token.col - 1, line_nr]
                    color:      gx.rgb(0, 150, 255)
                }
                return
            }
            if token.lit in ["f32", "f64"] {
                line.tkns << KeyWord{
                    str:    token.lit
                    pos:    [token.col - 1, line_nr]
                    color:      gx.rgb(0, 200, 255)
                }
                return
            }
            if token.lit == "string" {
                line.tkns << KeyWord{
                    str:    token.lit
                    pos:    [token.col - 1, line_nr]
                    color:      gx.rgb(0, 200, 100)
                }
                return
            }
            if token.lit == "rune" {
                line.tkns << KeyWord{
                    str:    token.lit
                    pos:    [token.col - 1, line_nr]
                    color:      gx.rgb(0, 150, 50)
                }
                return
            }
            if token.lit == "voidptr" {
                line.tkns << KeyWord{
                    str:    token.lit
                    pos:    [token.col - 1, line_nr]
                    color:      gx.rgb(100, 0, 0)
                }
                return
            }
        }
        .number {
            line.tkns << KeyWord{
                str:    token.lit
                pos:    [token.col - 1, line_nr]
                color:  gx.rgb(175, 255, 225)
            }
        }
        .string {
            line.tkns << KeyWord{
                str:    "\"" + token.lit + "\""
                pos:    [token.col - 1, line_nr]
                color:  gx.rgb(255, 175, 75)
            }
        }
        else {}
    }
}

fn (mut app App) scan_files(){
    mut indexer := 0
    mut file_path := ""
    mut files_skipped := 0
    for file in 0 .. os.ls(app.wk_dir) or {[]}.len{
        file_path = os.ls(app.wk_dir) or {
            files_skipped++
            continue
        }[file]
        if os.is_dir(file_path){
            files_skipped++
            continue
        }
        app.files_in_dir << File{
            path: app.wk_dir + "/" + file_path
            index: file - files_skipped
        }
        if os.is_executable(file_path){
            app.files_in_dir[app.files_in_dir.len-1].alt = "This file is executable, will not display contents."
        } else {
            mut file_obj := os.open(file_path) or {
                files_skipped++
                continue
            }
            mut file_data := file_obj.read_bytes(int(os.file_size(file_path))).bytestr().split("\n")
            file_obj.close()
            for line in 0 .. file_data.len {
                app.files_in_dir[app.files_in_dir.len - 1].contents << Line{
                    base: file_data[line]
                }
                for {
                    if indexer >= app.files_in_dir[app.files_in_dir.len - 1].contents[line].base.len{
                        break
                    }
                    if app.files_in_dir[app.files_in_dir.len - 1].contents[line].base.substr(indexer, indexer+1) != "\t"{
                        indexer++
                    } else {
                        app.files_in_dir[app.files_in_dir.len - 1].contents[line].base = app.files_in_dir[app.files_in_dir.len - 1].contents[line].base.replace_once("\t", " ".repeat(4 - indexer % 4))
                        app.files_in_dir[app.files_in_dir.len - 1].contents[line].tabs << [indexer, indexer + 4 - indexer % 4]
                        indexer += 4 - indexer % 4
                    }
                }
                for token in scanner.new_scanner(app.files_in_dir[app.files_in_dir.len - 1].contents[line].base, scanner.CommentsMode.parse_comments, pref.new_preferences()).all_tokens{
                    token_matcher(mut app.files_in_dir[app.files_in_dir.len - 1].contents[line], token, line)
                }
                indexer = 0
            }
        }
    }
}

fn (mut line Line) scan_line(line_nr int) int {
    mut return_val := 0
    mut indexer := 0
    line.tabs = []
    for {
        if indexer >= line.base.len{
            break
        }
        if line.base.substr(indexer, indexer+1) != "\t"{
            indexer++
        } else {
            line.base = line.base.replace_once("\t", " ".repeat(4 - indexer % 4))
            line.tabs.insert(line.tabs.len, [indexer, indexer + 4 - indexer % 4])
            return_val = 4 - indexer % 4
            indexer += 4 - indexer % 4
        }
    }
    line.tkns = []
    cfg := pref.Preferences{
        check_only: true
    }
    for token in scanner.new_scanner(line.base, scanner.CommentsMode.parse_comments, cfg).all_tokens{
        println(token.col)
        token_matcher(mut line, token, line_nr)
    }
    return return_val
}

fn main(){
    mut app := &App{
        wk_dir: os.resource_abs_path("")
    }
    app.ctx = gg.new_context(
        width: 1920
        height: 1050
        window_title: "VDE (V Developement Environemnt)"
        bg_color: gx.rgb(25,25,25)
        frame_fn: render
        user_data: app
        font_path: os.resource_abs_path("../RobotoMono-Regular.ttf")
        keyup_fn: kb_up
        keydown_fn: kb_down
        scroll_fn: scroll
        click_fn: click
        swap_interval: 2
        // ui_mode: true
    )
    app.scan_files()
    app.current_file = &app.files_in_dir[0]
    app.ctx.run()
}

fn click(x f32, y f32, button gg.MouseButton, mut app &App){
    if button == gg.MouseButton.left {
        app.current_file.edit[1] = int(y / 30) + app.current_file.ystart
        if x / 13 + app.current_file.xshift > app.current_file.contents[app.current_file.edit[1]].base.len {
            app.current_file.edit[0] = app.current_file.contents[app.current_file.edit[1]].base.len
        } else {
            app.current_file.edit[0] = int(x / 13) + app.current_file.xshift
        }
    }
}

fn kb_down(key gg.KeyCode, mod gg.Modifier, mut app &App){
    mut stop := 0
    if (!app.shift_down) && ((key == gg.KeyCode.left_shift) || (key == gg.KeyCode.right_shift)) {
        app.shift_down = true
    }
    if key == gg.KeyCode.page_down{
        yscroll := 10
        if app.current_file.ystart + yscroll < 0{
            app.current_file.ystart = 0
            return
        }
        if app.current_file.ystart + yscroll >= app.current_file.contents.len - int(gg.window_size().height/30) {
            if app.current_file.contents.len - int(gg.window_size().height/30) < 0 {
                app.current_file.ystart = 0
                return
            }
            app.current_file.ystart = app.current_file.contents.len - int(gg.window_size().height/30)
            return
        }
        app.current_file.ystart += int(yscroll)
        if app.current_file.contents.len < int(gg.window_size().height/30) {
            stop = app.current_file.contents.len
        } else {
            stop = int(gg.window_size().height/30)
        }
		for line in app.current_file.ystart .. stop {
            app.current_file.contents[line].scan_line(line)
        }
    }
    if key == gg.KeyCode.page_up{
        yscroll := -10
        if app.current_file.ystart + yscroll < 0{
            app.current_file.ystart = 0
            return
        }
        if app.current_file.ystart + yscroll >= app.current_file.contents.len - int(gg.window_size().height/30) {
            if app.current_file.contents.len - int(gg.window_size().height/30) < 0 {
                app.current_file.ystart = 0
                return
            }
            app.current_file.ystart = app.current_file.contents.len - int(gg.window_size().height/30)
            return
        }
        app.current_file.ystart += int(yscroll)
        if app.current_file.contents.len < int(gg.window_size().height/30) {
            stop = app.current_file.contents.len
        } else {
            stop = int(gg.window_size().height/30)
        }
		for line in app.current_file.ystart .. stop {
            app.current_file.contents[line].scan_line(line)
        }
    }
    if key == gg.KeyCode.right {
        for tab in 0 .. app.current_file.contents[app.current_file.edit[1]].tabs.len {
            if app.current_file.edit[0] == app.current_file.contents[app.current_file.edit[1]].tabs[tab][0] {
                app.current_file.edit[0] = app.current_file.contents[app.current_file.edit[1]].tabs[tab][1]
                return
            }
        }
        if app.current_file.edit[0] >= app.current_file.contents[app.current_file.edit[1]].base.len {
            if app.current_file.edit[1] + 1 <= app.current_file.contents.len - 1 {
                app.current_file.edit = [0, app.current_file.edit[1] + 1]
            }
        } else {
            app.current_file.edit[0]++
        }
    }
    if key == gg.KeyCode.left {
        for tab in 0 .. app.current_file.contents[app.current_file.edit[1]].tabs.len {
            if app.current_file.edit[0] == app.current_file.contents[app.current_file.edit[1]].tabs[tab][1] {
                app.current_file.edit[0] = app.current_file.contents[app.current_file.edit[1]].tabs[tab][0]
                return
            }
        }
        if app.current_file.edit[0] == 0 {
            if app.current_file.edit[1] - 1 >= 0 {
                app.current_file.edit = [app.current_file.contents[app.current_file.edit[1] - 1].base.len, app.current_file.edit[1] - 1]
            }
        } else {
            app.current_file.edit[0]--
        }
    }
    if key == gg.KeyCode.up {
        if app.current_file.edit[1] > 0{
            app.current_file.edit[1]--
        } else {
            app.current_file.edit[0] = 0
        }
        if app.current_file.edit[0] > app.current_file.contents[app.current_file.edit[1]].base.len {
            app.current_file.edit[0] = app.current_file.contents[app.current_file.edit[1]].base.len
        }
        for tab in 0 .. app.current_file.contents[app.current_file.edit[1]].tabs.len {
            if (app.current_file.edit[0] > app.current_file.contents[app.current_file.edit[1]].tabs[tab][0]) && (app.current_file.edit[0] < app.current_file.contents[app.current_file.edit[1]].tabs[tab][1]) {
                app.current_file.edit[0] = app.current_file.contents[app.current_file.edit[1]].tabs[tab][int(app.current_file.edit[0] > 2)]
                break
            }
        }
    }
    if key == gg.KeyCode.down {
        if app.current_file.edit[1] < app.current_file.contents.len - 1 {
            app.current_file.edit[1]++
        } else {
            app.current_file.edit[0] = app.current_file.contents[app.current_file.edit[1]].base.len
        }
        if app.current_file.edit[0] > app.current_file.contents[app.current_file.edit[1]].base.len {
            app.current_file.edit[0] = app.current_file.contents[app.current_file.edit[1]].base.len
        }
        for tab in 0 .. app.current_file.contents[app.current_file.edit[1]].tabs.len {
            if (app.current_file.edit[0] > app.current_file.contents[app.current_file.edit[1]].tabs[tab][0]) && (app.current_file.edit[0] < app.current_file.contents[app.current_file.edit[1]].tabs[tab][1]) {
                app.current_file.edit[0] = app.current_file.contents[app.current_file.edit[1]].tabs[tab][int(app.current_file.edit[0] > 2)]
                break
            }
        }
    }
    if (int(key) >= 32) && (int(key) <= 96) && (mod != gg.Modifier.ctrl) && (mod != gg.Modifier.alt) && (mod != gg.Modifier.super) {
        if mod == gg.Modifier.shift {
            if (int(key) >= 65) && (int(key) <= 90) {
                app.current_file.contents[app.current_file.edit[1]].base = app.current_file.contents[app.current_file.edit[1]].base.substr(0, app.current_file.edit[0]) + u8(key).ascii_str() + app.current_file.contents[app.current_file.edit[1]].base.substr(app.current_file.edit[0], app.current_file.contents[app.current_file.edit[1]].base.len)
            } else {
                app.current_file.contents[app.current_file.edit[1]].base = app.current_file.contents[app.current_file.edit[1]].base.substr(0, app.current_file.edit[0]) + key_map[u8(key)] + app.current_file.contents[app.current_file.edit[1]].base.substr(app.current_file.edit[0], app.current_file.contents[app.current_file.edit[1]].base.len)
            }
        } else {
            app.current_file.contents[app.current_file.edit[1]].base = app.current_file.contents[app.current_file.edit[1]].base.substr(0, app.current_file.edit[0]) + u8(key).ascii_str().to_lower() + app.current_file.contents[app.current_file.edit[1]].base.substr(app.current_file.edit[0], app.current_file.contents[app.current_file.edit[1]].base.len)
        }
        app.current_file.contents[app.current_file.edit[1]].scan_line(app.current_file.edit[1])
        app.current_file.edit[0]++
    }
    if key == gg.KeyCode.backspace {
        if app.current_file.edit != [0,0] {
            if app.current_file.edit[0] != 0 {
                for tab in 0 .. app.current_file.contents[app.current_file.edit[1]].tabs.len {
                    if app.current_file.edit[0] == app.current_file.contents[app.current_file.edit[1]].tabs[tab][1]{
                        app.current_file.contents[app.current_file.edit[1]].base = app.current_file.contents[app.current_file.edit[1]].base.substr(0, app.current_file.contents[app.current_file.edit[1]].tabs[tab][0]) + app.current_file.contents[app.current_file.edit[1]].base.substr(app.current_file.contents[app.current_file.edit[1]].tabs[tab][1], app.current_file.contents[app.current_file.edit[1]].base.len)
                        app.current_file.edit[0] += app.current_file.contents[app.current_file.edit[1]].tabs[tab][0] - app.current_file.contents[app.current_file.edit[1]].tabs[tab][1]
                        app.current_file.contents[app.current_file.edit[1]].tabs.delete(tab)
						app.current_file.contents[app.current_file.edit[1]].scan_line(app.current_file.edit[1])
                        return
                    }
                }
                app.current_file.contents[app.current_file.edit[1]].base = app.current_file.contents[app.current_file.edit[1]].base.substr(0, app.current_file.edit[0] - 1) + app.current_file.contents[app.current_file.edit[1]].base.substr(app.current_file.edit[0], app.current_file.contents[app.current_file.edit[1]].base.len)
                app.current_file.edit[0]--
				app.current_file.contents[app.current_file.edit[1]].scan_line(app.current_file.edit[1])
            } else {
                if app.current_file.contents[app.current_file.edit[1]].base != "" {
                    app.current_file.contents[app.current_file.edit[1] - 1].base += app.current_file.contents[app.current_file.edit[1]].base
                    app.current_file.contents[app.current_file.edit[1] - 1].tabs << app.current_file.contents[app.current_file.edit[1]].tabs
                }
                app.current_file.contents.delete(app.current_file.edit[1])
                app.current_file.edit[1]--
                app.current_file.edit[0] = app.current_file.contents[app.current_file.edit[1]].base.len
				if app.current_file.contents.len < int(gg.window_size().height/30) {
                    stop = app.current_file.contents.len
                } else {
                    stop = int(gg.window_size().height/30)
                }
				for line in app.current_file.ystart .. stop {
					app.current_file.contents[line].scan_line(line)
				}
            }
        }
    }
    if key == gg.KeyCode.tab {
        app.current_file.contents[app.current_file.edit[1]].base = app.current_file.contents[app.current_file.edit[1]].base.substr(0, app.current_file.edit[0]) + "\t" + app.current_file.contents[app.current_file.edit[1]].base.substr(app.current_file.edit[0], app.current_file.contents[app.current_file.edit[1]].base.len)
        app.current_file.edit[0] += app.current_file.contents[app.current_file.edit[1]].scan_line(app.current_file.edit[1])
    }
    if key == gg.KeyCode.enter {
        if app.current_file.edit[0] == 0 {
            app.current_file.contents.insert(app.current_file.edit[1], Line{})
        } else if app.current_file.edit[0] == app.current_file.contents[app.current_file.edit[1]].base.len {
            app.current_file.contents.insert(app.current_file.edit[1] + 1, Line{})
            app.current_file.edit[0] = 0
            app.current_file.edit[1]++
        }
        if app.current_file.contents.len < int(gg.window_size().height/30) {
            stop = app.current_file.contents.len
        } else {
            stop = int(gg.window_size().height/30)
        }
        for line in app.current_file.ystart .. stop {
            app.current_file.contents[line].scan_line(line)
        }
    }
}

fn kb_up(key gg.KeyCode, mod gg.Modifier, mut app &App){
    if (key == gg.KeyCode.q) && (mod == gg.Modifier.ctrl){
        app.ctx.quit()
    }
    if (key == gg.KeyCode.s) && (mod == gg.Modifier.ctrl){
        app.current_file.save()
    }
	if (key == gg.KeyCode.r) && (mod == gg.Modifier.ctrl){
		app.current_file.save()
		os.execute("v VDE.v -gc boehm")
		mut p := os.new_process("./VDE")
		p.run()
        exit(0)
    }
	if (key == gg.KeyCode.v) && (mod == gg.Modifier.ctrl){
    }
    if (key == gg.KeyCode.left_bracket) && (mod == gg.Modifier.ctrl){
        app.current_file = &app.files_in_dir[app.current_file.index + (-1 * int(app.current_file.index != 0))]
    }
    if (key == gg.KeyCode.right_bracket) && (mod == gg.Modifier.ctrl){
        app.current_file = &app.files_in_dir[app.current_file.index + (1 * int(app.current_file.index != (app.files_in_dir.len - 1)))]
    }
    if (app.shift_down) && ((key == gg.KeyCode.left_shift) || (key == gg.KeyCode.right_shift)) {
        app.shift_down = false
    }
}

fn scroll(data &gg.Event, mut app &App){
    if data.scroll_x != 0{
        if app.current_file.xshift - data.scroll_x * 23 >= 0 {
            app.current_file.xshift -= int(data.scroll_x) * 23
        }
    }
    if app.shift_down {
        if app.current_file.xshift - (data.scroll_y / math.abs(data.scroll_y)) * 23 >= 0 {
            app.current_file.xshift -= int(data.scroll_y / math.abs(data.scroll_y)) * 23
        }
        return
    }
    yscroll := data.scroll_y * -2
    if app.current_file.ystart + yscroll < 0{
        app.current_file.ystart = 0
        return
    }
    if app.current_file.ystart + yscroll >= app.current_file.contents.len - int(gg.window_size().height/30) {
        if app.current_file.contents.len - int(gg.window_size().height/30) < 0 {
            app.current_file.ystart = 0
            return
        }
        app.current_file.ystart = app.current_file.contents.len - int(gg.window_size().height/30)
        return
    }
    app.current_file.ystart += int(yscroll)
}

fn render(mut app &App){
    app.ctx.begin()
    if app.current_file.alt != ""{
        app.ctx.draw_text(0, 0, app.current_file.alt, gx.TextCfg{
            size:   28
            color:  gx.white
        })
    } else {
        mut stop := 0
        if app.current_file.contents.len > math.ceil(gg.window_size().height/30){
            stop = int(math.ceil(gg.window_size().height/30)) + app.current_file.ystart
            stop += int(stop != app.current_file.contents.len)
        } else {
            stop = app.current_file.contents.len + app.current_file.ystart
        }
        for line in app.current_file.ystart .. stop {
            app.ctx.draw_text(0 - app.current_file.xshift, (line - app.current_file.ystart) * 30, app.current_file.contents[line].base, gx.TextCfg{
                size:   28
                color:  gx.white
            })
            for token in app.current_file.contents[line].tkns {
                app.ctx.draw_text(token.pos[0] * 13 - app.current_file.xshift, (token.pos[1] - app.current_file.ystart) * 30, token.str, gx.TextCfg{
                    size: 28
                    color: token.color
                })
            }
        }
        if !app.current_file.read_only{
            if app.ctx.frame % 60 > 29 {
                app.ctx.draw_line(app.current_file.edit[0] * 13 + 1 - app.current_file.xshift, (app.current_file.edit[1] - app.current_file.ystart) * 30, app.current_file.edit[0] * 13 + 1  - app.current_file.xshift, (app.current_file.edit[1] - app.current_file.ystart) * 30 + 28, gx.white)
            }
        }
    }
    app.ctx.end()
}
