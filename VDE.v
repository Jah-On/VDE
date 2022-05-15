import clipboard as lol
import gg
import gx
import math
import os
import time
// import v.parser
import pacs
import pacs.vlang

const (
    key_map = {32:" ", 39:"\"\"", 44:"<", 45:"_", 46:">", 47:"?", 49:"!", 50:"@", 51:"#", 52:"$", 53:"%", 54:"^", 55:"&", 56:"*", 57:"(", 48:")", 59:":", 61:"+", 91:"{", 92:"|", 93:"}", 96:"~"}
)


[heap]
struct App {
// pub mut:
//     cb              &clipboard.Clipboard
mut:
    ctx             &gg.Context = 0
    wk_dir          string
    files_in_dir    []pacs.File
    open_files      []pacs.File
    current_file    &pacs.File = 0
    current_index   int
    shift_down      bool
}

fn (mut app App) scan_files(){
    mut path := ""
    mut files_skipped := 0
    for file in 0 .. os.ls(app.wk_dir) or {[]}.len{
        path = os.ls(app.wk_dir) or {
            files_skipped++
            continue
        }[file]
        if os.is_dir(path){
            files_skipped++
            continue
        }
        if path.substr(path.len - 2, path.len) == ".v" {
            app.files_in_dir << vlang.load(path)
            vlang.parse(1.0, mut &app.files_in_dir[app.files_in_dir.len - 1])
        } else {
            app.files_in_dir << pacs.load(path)
        }
    }
}

fn main(){
    mut app := &App{
        // cb: clipboard.new()
        wk_dir: os.resource_abs_path("")
    }
    app.ctx = gg.new_context(
        width: 1920
        height: 1050
        window_title: "VDE (V Developement Environemnt)"
        bg_color: gx.rgb(25,25,25)
        frame_fn: render
        user_data: app
        font_path: os.resource_abs_path("assets/RobotoMono-Regular.ttf")
        keyup_fn: kb_up
        keydown_fn: kb_down
        scroll_fn: scroll
        click_fn: click
        swap_interval: 2
        // ui_mode: true
    )
    app.scan_files()
    app.current_file = &app.files_in_dir[1]
    app.current_index = 1
    app.ctx.run()
}

fn click(x f32, y f32, button gg.MouseButton, mut app &App){
    if button == gg.MouseButton.left {
        app.current_file.edit[1] = int((y + app.current_file.shift[1]) / 30)
        if x / 13 + app.current_file.shift[1] / 13 > app.current_file.lines[app.current_file.edit[1]].len {
            app.current_file.edit[0] = app.current_file.lines[app.current_file.edit[1]].len
        } else {
            app.current_file.edit[0] = int((x + app.current_file.shift[0]) / 13)
        }
    }
}

fn kb_down(key gg.KeyCode, mod gg.Modifier, mut app &App){
    mut temp := 0
    match mod {
        .shift {}
        .ctrl {}
        else {
            match key {
                .backspace {
                    if app.current_file.edit != [0,0] {
                        if app.current_file.edit[0] != 0 {
                            app.current_file.lines[app.current_file.edit[1]] = app.current_file.lines[app.current_file.edit[1]].substr(0, app.current_file.edit[0] - 1) + app.current_file.lines[app.current_file.edit[1]].substr(app.current_file.edit[0], app.current_file.lines[app.current_file.edit[1]].len)
                            app.current_file.edit[0]--
                        } else {
                            app.current_file.edit[0] = app.current_file.lines[app.current_file.edit[1]- 1].len
                            if app.current_file.lines[app.current_file.edit[1]] != "" {
                                app.current_file.lines[app.current_file.edit[1] - 1] = app.current_file.lines[app.current_file.edit[1] - 1] + app.current_file.lines[app.current_file.edit[1]]
                            }
                            app.current_file.lines.delete(app.current_file.edit[1])
                            app.current_file.edit[1]--
                        }
                        vlang.parse(1.0, mut app.current_file)
                    }
                }
                .enter {
                    if app.current_file.edit[0] == 0 {
                        app.current_file.lines.insert(app.current_file.edit[1], "")
                    } else {
                        app.current_file.lines.insert(app.current_file.edit[1] + 1, app.current_file.lines[app.current_file.edit[1]].substr(app.current_file.edit[0], app.current_file.lines[app.current_file.edit[1]].len))
                        app.current_file.lines[app.current_file.edit[1]] = app.current_file.lines[app.current_file.edit[1]].substr(0, app.current_file.edit[0])
                    }
                    app.current_file.edit[0] = 0
                    app.current_file.edit[1]++
                    vlang.parse(1.0, mut app.current_file)
                }
                .left {
                    if temp != 1 {
                        if app.current_file.edit[0] == 0 {
                            if app.current_file.edit[1] - 1 >= 0 {
                                app.current_file.edit = [app.current_file.rlines[app.current_file.edit[1] - 1].len, app.current_file.edit[1] - 1]
                            }
                        } else {
                            app.current_file.edit[0]--
                        }
                    }
                }
                .left_shift {if !app.shift_down {app.shift_down = true}}
                .page_down {
                    if app.current_file.edit[1] + 50 < app.current_file.rlines.len {
                        app.current_file.edit[1] += 50
                    } else {
                        app.current_file.edit[1] = app.current_file.rlines.len - 1
                    }
                    if app.current_file.edit[0] > app.current_file.rlines[app.current_file.edit[1]].len {
                        app.current_file.edit[0] = app.current_file.rlines[app.current_file.edit[1]].len
                    }
                }
                .page_up {
                    if app.current_file.edit[1] - 50 >= 0 {
                        app.current_file.edit[1] -= 50
                    } else {
                        app.current_file.edit[1] = 0
                    }
                    if app.current_file.edit[0] > app.current_file.rlines[app.current_file.edit[1]].len {
                        app.current_file.edit[0] = app.current_file.rlines[app.current_file.edit[1]].len
                    }
                }
                .right {
                    if app.current_file.edit[0] >= app.current_file.rlines[app.current_file.edit[1]].len {
                        if app.current_file.edit[1] + 1 <= app.current_file.rlines.len - 1 {
                            app.current_file.edit = [0, app.current_file.edit[1] + 1]
                        }
                    } else {
                        app.current_file.edit[0]++
                    }
                }
                .right_shift {if !app.shift_down {app.shift_down = true}}
                // .tab {
                //     app.current_file.contents[app.current_file.edit[1]].base = app.current_file.contents[app.current_file.edit[1]].base.substr(0, app.current_file.edit[0]) + "\t" + app.current_file.contents[app.current_file.edit[1]].base.substr(app.current_file.edit[0], app.current_file.contents[app.current_file.edit[1]].base.len)
                //     app.current_file.edit[0] += app.current_file.contents[app.current_file.edit[1]].scan_line(app.current_file.edit[1])
                // }
                .up {
                    if app.current_file.edit[1] > 0{
                        app.current_file.edit[1]--
                    } else {
                        app.current_file.edit[0] = 0
                    }
                    if app.current_file.edit[0] > app.current_file.rlines[app.current_file.edit[1]].len {
                        app.current_file.edit[0] = app.current_file.rlines[app.current_file.edit[1]].len
                    }
                }
                else {
                    if (int(key) >= 32) && (int(key) <= 96) {
                        app.current_file.lines[app.current_file.edit[1]] = app.current_file.lines[app.current_file.edit[1]].substr(0, app.current_file.edit[0]) + u8(key).ascii_str().to_lower().repeat(1 + int(key == gg.KeyCode.apostrophe)) + app.current_file.lines[app.current_file.edit[1]].substr(app.current_file.edit[0], app.current_file.lines[app.current_file.edit[1]].len)
                        vlang.parse(1.0, mut app.current_file)
                        app.current_file.edit[0]++
                    }
                }
            }
            if app.current_file.edit[0] - int(app.current_file.edit[0] > 0) - int(app.current_file.edit[0] > 1) - int(app.current_file.edit[0] > 2) < app.current_file.shift[0]/13 {
                app.current_file.shift[0] -= app.current_file.shift[0] - (app.current_file.edit[0] - int(app.current_file.edit[0] > 0) - int(app.current_file.edit[0] > 1) - int(app.current_file.edit[0] > 2)) * 13
            } else if app.current_file.edit[0] * 13 > app.current_file.shift[0] + gg.window_size().width - 39 {
                app.current_file.shift[0] -= app.current_file.shift[0] + int(gg.window_size().width) - 39 - app.current_file.edit[0] * 13
            }
            if app.current_file.edit[1] * 30 < app.current_file.shift[1] {
                app.current_file.shift[1] -= app.current_file.shift[1] - app.current_file.edit[1] * 30
            } else if app.current_file.edit[1] * 30 > app.current_file.shift[1] + gg.window_size().height - 60 {
                app.current_file.shift[1] -= app.current_file.shift[1] + gg.window_size().height - app.current_file.edit[1] * 30 - 60
            }
            if key == gg.KeyCode.down {
                if app.current_file.edit[1] < app.current_file.rlines.len - 1 {
                    app.current_file.edit[1]++
                } else {
                    app.current_file.edit[0] = app.current_file.rlines[app.current_file.edit[1]].len
                }
                if app.current_file.edit[0] > app.current_file.rlines[app.current_file.edit[1]].len {
                    app.current_file.edit[0] = app.current_file.rlines[app.current_file.edit[1]].len
                }
            }
        }
    }
}

fn kb_up(key gg.KeyCode, mod gg.Modifier, mut app &App){
    if (key == gg.KeyCode.q) && (mod == gg.Modifier.ctrl){
        app.ctx.quit()
    }
    if (key == gg.KeyCode.s) && (mod == gg.Modifier.ctrl){
        vlang.save(mut app.current_file)
    }
    if (key == gg.KeyCode.v) && (mod == gg.Modifier.ctrl){
    }
    if (key == gg.KeyCode.left_bracket) && (mod == gg.Modifier.ctrl){
        app.current_index -= int(app.current_index != 0)
    }
    if (key == gg.KeyCode.right_bracket) && (mod == gg.Modifier.ctrl){
        app.current_index += int(app.current_index != (app.files_in_dir.len - 1))
    }
    app.current_file = &app.files_in_dir[app.current_index]
    if (app.shift_down) && ((key == gg.KeyCode.left_shift) || (key == gg.KeyCode.right_shift)) {
        app.shift_down = false
    }
}

fn scroll(data &gg.Event, mut app &App){
    if data.scroll_x != 0{
        if (app.current_file.shift[0] - data.scroll_x * 26 >= 0) && (app.current_file.shift[0] - data.scroll_x * 26 < app.current_file.xmax * 13 - gg.window_size().width/2 + 26) {
            app.current_file.shift[0] -= int(data.scroll_x) * 26
            return
        }
    }
    if app.shift_down {
        if (app.current_file.shift[0] - (data.scroll_y / math.abs(data.scroll_y)) * 26 >= 0) && (app.current_file.shift[0] - (data.scroll_y / math.abs(data.scroll_y)) * 26 < app.current_file.xmax - gg.window_size().width/2 + 26) {
            app.current_file.shift[0] -= int(data.scroll_y / math.abs(data.scroll_y)) * 26
        }
        return
    }
    yscroll := int(data.scroll_y) * -60
    if app.current_file.shift[1] + yscroll < 0{
        app.current_file.shift[1] = 0
        return
    }
    if app.current_file.shift[1] + yscroll >= app.current_file.rlines.len * 30 - gg.window_size().height {
        if app.current_file.rlines.len * 30 - gg.window_size().height < 0 {
            app.current_file.shift[1] = 0
            return
        }
        app.current_file.shift[1] = app.current_file.rlines.len * 30 - gg.window_size().height
        return
    }
    app.current_file.shift[1] += yscroll
}

fn render(mut app &App){
    mut s_a_s := [0, 0] // start and stop
    app.ctx.begin()
    if app.current_file.alt != ""{
        app.ctx.draw_text(0, 0, app.current_file.alt, gx.TextCfg{
            size:   28
            color:  gx.white
        })
    }
    else {
        s_a_s[1] = int((app.current_file.shift[1] + gg.window_size().height) / 30)
        if s_a_s[1] >= app.current_file.lines.len {
            s_a_s[1] = app.current_file.lines.len
        }
        for line in int(app.current_file.shift[1]/30) .. s_a_s[1] {
            app.ctx.draw_text(0 - app.current_file.shift[0], line * 30 - app.current_file.shift[1], app.current_file.rlines[line], gx.TextCfg{
                size:   28
                color:  gx.white
            })
        }
        s_a_s[1] = 0
        for kw in 0 .. app.current_file.kws.len {
            if (app.current_file.kws[kw].y) < app.current_file.shift[1] {s_a_s[0] = kw}
            else if app.current_file.kws[kw].y >= app.current_file.shift[1] + gg.window_size().height {
                s_a_s[1] = kw
                break
            }
        }
        if (s_a_s[1] == 0) && (app.current_file.kws.len > 0){
            s_a_s[1] = app.current_file.kws.len
        }
        for kw in s_a_s[0] .. s_a_s[1] {
            app.ctx.draw_text(app.current_file.kws[kw].x - app.current_file.shift[0], app.current_file.kws[kw].y - app.current_file.shift[1], app.current_file.kws[kw].text, gx.TextCfg{
                size:   28
                color:  app.current_file.kws[kw].color
            })
        }
        if !app.current_file.read_only{
            if app.ctx.frame % 60 > 29 {
                app.ctx.draw_line(app.current_file.edit[0] * 13 + 1 - app.current_file.shift[0], app.current_file.edit[1] * 30 - app.current_file.shift[1], app.current_file.edit[0] * 13 + 1  - app.current_file.shift[0], app.current_file.edit[1] * 30 + 28 - app.current_file.shift[1], gx.white)
            }
        }
    }
    app.ctx.end()
}
