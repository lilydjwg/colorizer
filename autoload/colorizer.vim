" colorizer.vim	Colorize all text in the form #rrggbb or #rgb; autoload functions
" Maintainer:	lilydjwg <lilydjwg@gmail.com>
" Version:	1.4.2
" License:	Vim License  (see vim's :help license)
"
" See plugin/colorizer.vim for more info.

let s:keepcpo = &cpo
set cpo&vim

function! s:FGforBG(bg) "{{{1
  " takes a 6hex color code and returns a matching color that is visible
  let pure = substitute(a:bg,'^#','','')
  let r = str2nr(pure[0:1], 16)
  let g = str2nr(pure[2:3], 16)
  let b = str2nr(pure[4:5], 16)
  let fgc = g:colorizer_fgcontrast
  if r*30 + g*59 + b*11 > 12000
    return s:predefined_fgcolors['dark'][fgc]
  else
    return s:predefined_fgcolors['light'][fgc]
  end
endfunction

function! s:Rgb2xterm(color) "{{{1
  " selects the nearest xterm color for a rgb value like #FF0000
  let best_match=0
  let smallest_distance = 10000000000
  let r = str2nr(a:color[1:2], 16)
  let g = str2nr(a:color[3:4], 16)
  let b = str2nr(a:color[5:6], 16)
  let colortable = s:GetXterm2rgbTable()
  for c in range(0,254)
    let d = pow(colortable[c][0]-r,2) + pow(colortable[c][1]-g,2) + pow(colortable[c][2]-b,2)
    if d<smallest_distance
      let smallest_distance = d
      let best_match = c
    endif
  endfor
  return best_match
endfunction

"" the 6 value iterations in the xterm color cube {{{1
let s:valuerange = [0x00, 0x5F, 0x87, 0xAF, 0xD7, 0xFF]

"" 16 basic colors {{{1
let s:basic16 = [
      \ [0x00, 0x00, 0x00], [0xCD, 0x00, 0x00],
      \ [0x00, 0xCD, 0x00], [0xCD, 0xCD, 0x00],
      \ [0x00, 0x00, 0xEE], [0xCD, 0x00, 0xCD],
      \ [0x00, 0xCD, 0xCD], [0xE5, 0xE5, 0xE5],
      \ [0x7F, 0x7F, 0x7F], [0xFF, 0x00, 0x00],
      \ [0x00, 0xFF, 0x00], [0xFF, 0xFF, 0x00],
      \ [0x5C, 0x5C, 0xFF], [0xFF, 0x00, 0xFF],
      \ [0x00, 0xFF, 0xFF], [0xFF, 0xFF, 0xFF]]

function! s:Xterm2rgb(color) "{{{1
  " 16 basic colors
  let r = 0
  let g = 0
  let b = 0
  if a:color<16
    let r = s:basic16[a:color][0]
    let g = s:basic16[a:color][1]
    let b = s:basic16[a:color][2]
  endif

  " color cube color
  if a:color>=16 && a:color<=232
    let l:color=a:color-16
    let r = s:valuerange[(l:color/36)%6]
    let g = s:valuerange[(l:color/6)%6]
    let b = s:valuerange[l:color%6]
  endif

  " gray tone
  if a:color>=233 && a:color<=253
    let r=8+(a:color-232)*0x0a
    let g=r
    let b=r
  endif
  let rgb=[r,g,b]
  return rgb
endfunction

function! s:SetMatcher(color, pat) "{{{1
  " "color" is the converted color and "pat" is what to highlight
  let group = 'Color' . strpart(a:color, 1)
  if !hlexists(group) || s:force_group_update
    let fg = g:colorizer_fgcontrast < 0 ? a:color : s:FGforBG(a:color)
    if &t_Co == 256 && !(has('termguicolors') && &termguicolors)
      exe 'hi '.group.' ctermfg='.s:Rgb2xterm(fg).' ctermbg='.s:Rgb2xterm(a:color)
    endif
    " Always set gui* as user may switch to GUI version and it's cheap
    exe 'hi '.group.' guifg='.fg.' guibg='.a:color
  endif
  if !exists("w:colormatches[a:pat]")
    let w:colormatches[a:pat] = matchadd(group, a:pat)
  endif
endfunction

" Color Converters {{{1
function! s:RgbBgColor() "{{{2
  let bg = synIDattr(synIDtrans(hlID("Normal")), "bg")
  let r = str2nr(bg[1:2], 16)
  let g = str2nr(bg[3:4], 16)
  let b = str2nr(bg[5:6], 16)
  return [r,g,b]
endfunction

function! s:Hexa2Rgba(hex,alpha) "{{{2
  let r = str2nr(a:hex[1:2], 16)
  let g = str2nr(a:hex[3:4], 16)
  let b = str2nr(a:hex[5:6], 16)
  let alpha = printf("%.2f", str2float(str2nr(a:alpha,16)) / 255.0)
  return [r,g,b,alpha]
endfunction

function! s:Rgba2Rgb(r,g,b,alpha,percent,rgb_bg) "{{{2
  " converts matched r,g,b values and percentages to [0:255]
  " if possible, overlays r,g,b with alpha on given rgb_bg color
  if a:percent
    let r = a:r * 255 / 100
    let g = a:g * 255 / 100
    let b = a:b * 255 / 100
  else
    let r = a:r
    let g = a:g
    let b = a:b
  endif
  if r > 255 || g > 255 || b > 255
    return []
  endif
  if empty(a:rgb_bg)
    return [r,g,b]
  endif
  let alpha = str2float(a:alpha)
  if alpha < 0
    let alpha = 0.0
  elseif alpha > 1
    let alpha = 1.0
  endif
  if alpha == 1.0
    return [r,g,b]
  endif
  let r = float2nr(ceil(r * alpha) + ceil(a:rgb_bg[0] * (1 - alpha)))
  let g = float2nr(ceil(g * alpha) + ceil(a:rgb_bg[1] * (1 - alpha)))
  let b = float2nr(ceil(b * alpha) + ceil(a:rgb_bg[2] * (1 - alpha)))
  if r > 255
    let r = 255
  endif
  if g > 255
    let g = 255
  endif
  if b > 255
    let b = 255
  endif
  return [r,g,b]
endfunction

"ColorFinders {{{1
function! s:HexCode(str, lineno) "{{{2
  " finds RGB: #00f #0000ff and RGBA: #00f8 #0000ff88 (or ARGB: #800f #880000ff)
  if has("gui_running")
    let rgb_bg = s:RgbBgColor()
  else
    " translucent colors would display incorrectly, so ignore the alpha value
    let rgb_bg = []
  endif
  let ret = []
  let place = 0
  let colorpat = '#[0-9A-Fa-f]\{3\}\>\|#[0-9A-Fa-f]\{6\}\>\|#[0-9A-Fa-f]\{8\}\>\|#[0-9A-Fa-f]\{4\}\>'
  while 1
    let foundcolor = matchstr(a:str, colorpat, place)
    if foundcolor == ''
      break
    endif
    let place = matchend(a:str, colorpat, place)
    let pat = foundcolor . '\>'
    let colorlen = len(foundcolor)
    if get(g:, 'colorizer_hex_alpha_first') == 1
      if colorlen == 4 || colorlen == 5
        let ha = tolower(foundcolor[1])
        let hr = tolower(foundcolor[2])
        let hg = tolower(foundcolor[3])
        let hb = tolower(foundcolor[4])
        let foundcolor = substitute(foundcolor, '[[:xdigit:]]', '&&', 'g')
      else
        let ha = tolower(foundcolor[1:2])
        let hr = tolower(foundcolor[3:4])
        let hg = tolower(foundcolor[5:6])
        let hb = tolower(foundcolor[7:8])
      endif
      if len(foundcolor) == 9
        let alpha      = foundcolor[1:2]
        let foundcolor = '#'.foundcolor[3:8]
      else
        let alpha = 'ff'
      endif
      if empty(rgb_bg)
        if colorlen == 5
          let pat = printf('\c#\x\zs%s%s%s\ze\>', hr,hg,hb)
        elseif colorlen == 9
          let pat = printf('\c#\x\x\zs%s%s%s\ze\>', hr,hg,hb)
        endif
      endif
    else
      if colorlen == 4 || colorlen == 5
        let hr = tolower(foundcolor[1])
        let hg = tolower(foundcolor[2])
        let hb = tolower(foundcolor[3])
        let ha = tolower(foundcolor[4])
        let foundcolor = substitute(foundcolor, '[[:xdigit:]]', '&&', 'g')
      else
        let hr = tolower(foundcolor[1:2])
        let hg = tolower(foundcolor[3:4])
        let hb = tolower(foundcolor[5:6])
        let ha = tolower(foundcolor[7:8])
      endif
      if len(foundcolor) == 9
        let alpha      = foundcolor[7:8]
        let foundcolor = foundcolor[0:6]
      else
        let alpha = 'ff'
      endif
      if empty(rgb_bg)
        if colorlen == 5
          let pat = printf('\c#%s%s%s\ze\x\>', hr,hg,hb)
        elseif colorlen == 9
          let pat = printf('\c#%s%s%s\ze\x\x\>', hr,hg,hb)
        endif
      endif
    endif
    if empty(rgb_bg) || tolower(alpha) == 'ff'
      call add(ret, [foundcolor, pat])
    else
      let rgba    = s:Hexa2Rgba(foundcolor, alpha)
      let rgb     = s:Rgba2Rgb(rgba[0], rgba[1], rgba[2], rgba[3], 0, rgb_bg)
      let l:color = printf('#%02x%02x%02x', rgb[0], rgb[1], rgb[2])
      call add(ret, [l:color, pat])
    endif
  endwhile
  return ret
endfunction

function! s:RgbColor(str, lineno) "{{{2
  let ret = []
  let place = 0
  let colorpat = '\<rgb(\v\s*(\d+(\%)?)\s*,\s*(\d+%(\2))\s*,\s*(\d+%(\2))\s*\)'
  while 1
    let foundcolor = matchlist(a:str, colorpat, place)
    if empty(foundcolor)
      break
    endif
    let place = matchend(a:str, colorpat, place)
    if foundcolor[2] == '%'
      let r = foundcolor[1] * 255 / 100
      let g = foundcolor[3] * 255 / 100
      let b = foundcolor[4] * 255 / 100
    else
      let r = foundcolor[1]
      let g = foundcolor[3]
      let b = foundcolor[4]
    endif
    if r > 255 || g > 255 || b > 255
      break
    endif
    let pat = printf('\<rgb(\v\s*%s\s*,\s*%s\s*,\s*%s\s*\)', foundcolor[1], foundcolor[3], foundcolor[4])
    if foundcolor[2] == '%'
      let pat = substitute(pat, '%', '\\%', 'g')
    endif
    let l:color = printf('#%02x%02x%02x', r, g, b)
    call add(ret, [l:color, pat])
  endwhile
  return ret
endfunction

function! s:RgbaColor(str, lineno) "{{{2
  if has("gui_running") || (has("termguicolors") && &termguicolors)
    let rgb_bg = s:RgbBgColor()
  else
    " translucent colors would display incorrectly, so ignore the alpha value
    let rgb_bg = []
  endif
  let ret = []
  let place = 0
  let percent = 0
  let colorpat = '\<rgba(\v\s*(\d+(\%)?)\s*,\s*(\d+%(\2))\s*,\s*(\d+%(\2))\s*,\s*(-?[.[:digit:]]+)\s*\)'
  while 1
    let foundcolor = matchlist(a:str, colorpat, place)
    if empty(foundcolor)
      break
    endif
    if foundcolor[2] == '%'
      let percent = 1
    endif
    let rgb = s:Rgba2Rgb(foundcolor[1], foundcolor[3], foundcolor[4], foundcolor[5], percent, rgb_bg)
    if empty(rgb)
      break
    endif
    let place = matchend(a:str, colorpat, place)
    if empty(rgb_bg)
      let pat = printf('\<rgba(\v\s*%s\s*,\s*%s\s*,\s*%s\s*,\ze\s*(-?[.[:digit:]]+)\s*\)', foundcolor[1], foundcolor[3], foundcolor[4])
    else
      let pat = printf('\<rgba(\v\s*%s\s*,\s*%s\s*,\s*%s\s*,\s*%s0*\s*\)', foundcolor[1], foundcolor[3], foundcolor[4], foundcolor[5])
    endif
    if percent
      let pat = substitute(pat, '%', '\\%', 'g')
    endif
    let l:color = printf('#%02x%02x%02x', rgb[0], rgb[1], rgb[2])
    call add(ret, [l:color, pat])
  endwhile
  return ret
endfunction

function! s:PreviewColorInLine(where) "{{{1
  let line = getline(a:where)
  for Func in s:ColorFinder
    let ret = Func(line, a:where)
    " returned a list of a list: color as #rrggbb, text pattern to highlight
    for r in ret
      call s:SetMatcher(r[0], r[1])
    endfor
  endfor
endfunction

function! s:CursorMoved() "{{{1
  if !exists('w:colormatches')
    return
  endif
  if exists('b:colorizer_last_update')
    if b:colorizer_last_update == b:changedtick
      " Nothing changed
      return
    endif
  endif
  call s:PreviewColorInLine('.')
  let b:colorizer_last_update = b:changedtick
endfunction

function! s:TextChanged() "{{{1
  if !exists('w:colormatches')
    return
  endif
  echomsg "TextChanged"
  call s:PreviewColorInLine('.')
endfunction

function! colorizer#ColorHighlight(update, ...) "{{{1
  if exists('w:colormatches')
    if !a:update
      return
    endif
    call s:ClearMatches()
  endif
  if (g:colorizer_maxlines > 0) && (g:colorizer_maxlines <= line('$'))
    return
  end
  let w:colormatches = {}
  if g:colorizer_fgcontrast != s:saved_fgcontrast || (exists("a:1") && a:1 == '!')
    let s:force_group_update = 1
  endif
  for i in range(1, line("$"))
    call s:PreviewColorInLine(i)
  endfor
  let s:force_group_update = 0
  let s:saved_fgcontrast = g:colorizer_fgcontrast
  augroup Colorizer
    au!
    if exists('##TextChanged')
      autocmd TextChanged * silent call s:TextChanged()
      if v:version > 704 || v:version == 704 && has('patch143')
        autocmd TextChangedI * silent call s:TextChanged()
      else
        " TextChangedI does not work as expected
        autocmd CursorMovedI * silent call s:CursorMoved()
      endif
    else
      autocmd CursorMoved,CursorMovedI * silent call s:CursorMoved()
    endif
    " rgba handles differently, so need updating
    autocmd GUIEnter * silent call colorizer#ColorHighlight(1)
    autocmd BufEnter * silent call colorizer#ColorHighlight(1)
    autocmd WinEnter * silent call colorizer#ColorHighlight(1)
    autocmd ColorScheme * let s:force_group_update=1 | silent call colorizer#ColorHighlight(1)
  augroup END
endfunction

function! colorizer#ColorClear() "{{{1
  augroup Colorizer
    au!
  augroup END
  augroup! Colorizer
  let save_tab = tabpagenr()
  let save_win = winnr()
  tabdo windo call s:ClearMatches()
  exe 'tabn '.save_tab
  exe save_win . 'wincmd w'
endfunction

function! s:ClearMatches() "{{{1
  if !exists('w:colormatches')
    return
  endif
  for i in values(w:colormatches)
    try
      call matchdelete(i)
    catch /.*/
      " matches have been cleared in other ways, e.g. user has called clearmatches()
    endtry
  endfor
  unlet w:colormatches
endfunction

function! colorizer#ColorToggle() "{{{1
  if exists('#Colorizer')
    call colorizer#ColorClear()
    echomsg 'Disabled color code highlighting.'
  else
    call colorizer#ColorHighlight(0)
    echomsg 'Enabled color code highlighting.'
  endif
endfunction

function! colorizer#AlphaPositionToggle() "{{{1
  if exists('#Colorizer')
    if get(g:, 'colorizer_hex_alpha_first') == 1
      let g:colorizer_hex_alpha_first = 0
    else
      let g:colorizer_hex_alpha_first = 1
    endif
    call colorizer#ColorHighlight(1)
  endif
endfunction

function! s:GetXterm2rgbTable() "{{{1
  if !exists('s:table_xterm2rgb')
    let s:table_xterm2rgb = []
    for c in range(0, 254)
      let s:color = s:Xterm2rgb(c)
      call add(s:table_xterm2rgb, s:color)
    endfor
  endif
  return s:table_xterm2rgb
endfun

" Setups {{{1
let s:ColorFinder = [function('s:HexCode'), function('s:RgbColor'), function('s:RgbaColor')]
let s:force_group_update = 0
let s:predefined_fgcolors = {}
let s:predefined_fgcolors['dark']  = ['#444444', '#222222', '#000000']
let s:predefined_fgcolors['light'] = ['#bbbbbb', '#dddddd', '#ffffff']
if !exists("g:colorizer_fgcontrast")
  " Default to black / white
  let g:colorizer_fgcontrast = len(s:predefined_fgcolors['dark']) - 1
elseif g:colorizer_fgcontrast >= len(s:predefined_fgcolors['dark'])
  echohl WarningMsg
  echo "g:colorizer_fgcontrast value invalid, using default"
  echohl None
  let g:colorizer_fgcontrast = len(s:predefined_fgcolors['dark']) - 1
endif
let s:saved_fgcontrast = g:colorizer_fgcontrast

" Restoration and modelines {{{1
let &cpo = s:keepcpo
unlet s:keepcpo
" vim:ft=vim:fdm=marker:fmr={{{,}}}:ts=8:sw=2:sts=2:et
