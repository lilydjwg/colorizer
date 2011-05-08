" Name Of File:	colorizer.vim
" Description:	Colorize all text in the form #rrggbb or #rgb
" Maintainer:	lilydjwg <lilydjwg@gmail.com>
" Licence:	No Warranties. Do whatever you want with this. But please tell me!
" Usage:	This file should reside in the plugin directory.
" Derived From: css_color.vim
" 		http://www.vim.org/scripts/script.php?script_id=2150
" Thanks To:	Niklas Hofer (Author of css_color.vim), Ingo Karkat, rykka
" Usage:
"
" This plugin defines three commands:
"
" 	ColorHighlight	- start/update highlighting
" 	ColorClear      - clear all highlights
" 	ColorToggle     - toggle highlights
"
" By default, <leader>tc is mapped to ColorToggle. If you want to use another
" key map, do like this:
" 	nmap ,tc <Plug>Colorizer
"
" If you want completely not to map it, set the following in your vimrc:
"	let g:colorizer_nomap = 1
"
" To use solid color highlight, set this in your vimrc (later change won't
" probably take effect unless you use ':ColorHighlight!' to force update):
"	let g:colorizer_fgcontrast = -1
" set it to 0 or 1 to use a softened foregroud color.
"
" Note: if you modify a color string in normal mode, if the cursor is still on
" that line, it'll take 'updatetime' seconds to update. You can use
" :ColorHighlight (or your key mapping) again to force update.
"
" Performace Notice: In terminal, it may take several seconds to highlight 240
" different colors. GUI version is much quicker.

" Reload guard and 'compatible' handling {{{1
if exists("loaded_colorizer") || v:version < 700 || !(has("gui_running") || &t_Co == 256)
  finish
endif
let loaded_colorizer = 1

let s:save_cpo = &cpo
set cpo&vim

" main part {{{1
function s:FGforBG(bg) "{{{2
  " takes a 6hex color code and returns a matching color that is visible
  let pure = substitute(a:bg,'^#','','')
  let r = eval('0x'.pure[0].pure[1])
  let g = eval('0x'.pure[2].pure[3])
  let b = eval('0x'.pure[4].pure[5])
  let fgc = g:colorizer_fgcontrast
  if r*30 + g*59 + b*11 > 12000
    return s:predefined_fgcolors['dark'][fgc]
  else
    return s:predefined_fgcolors['light'][fgc]
  end
endfunction
function s:Rgb2xterm(color) "{{{2
  " selects the nearest xterm color for a rgb value like #FF0000
  let best_match=0
  let smallest_distance = 10000000000
  let r = eval('0x'.a:color[1].a:color[2])
  let g = eval('0x'.a:color[3].a:color[4])
  let b = eval('0x'.a:color[5].a:color[6])
  for c in range(0,254)
    let d = s:pow(s:colortable[c][0]-r,2) + s:pow(s:colortable[c][1]-g,2) + s:pow(s:colortable[c][2]-b,2)
    if d<smallest_distance
      let smallest_distance = d
      let best_match = c
    endif
  endfor
  return best_match
endfunction
"" the 6 value iterations in the xterm color cube {{{2
let s:valuerange = [0x00, 0x5F, 0x87, 0xAF, 0xD7, 0xFF]

"" 16 basic colors {{{2
let s:basic16 = [[0x00, 0x00, 0x00], [0xCD, 0x00, 0x00], [0x00, 0xCD, 0x00], [0xCD, 0xCD, 0x00], [0x00, 0x00, 0xEE], [0xCD, 0x00, 0xCD], [0x00, 0xCD, 0xCD], [0xE5, 0xE5, 0xE5], [ 0x7F, 0x7F, 0x7F ], [ 0xFF, 0x00, 0x00 ], [ 0x00, 0xFF, 0x00 ], [ 0xFF, 0xFF, 0x00 ], [ 0x5C, 0x5C, 0xFF ], [ 0xFF, 0x00, 0xFF ], [ 0x00, 0xFF, 0xFF ], [0xFF, 0xFF, 0xFF]]

function s:Xterm2rgb(color) "{{{2
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
    let color=a:color-16
    let r = s:valuerange[(color/36)%6]
    let g = s:valuerange[(color/6)%6]
    let b = s:valuerange[color%6]
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
function s:pow(x, n) "{{{2
  let x = a:x
  for i in range(a:n-1)
    let x = x*a:x
    return x
  endfor
endfunction
function s:SetMatcher(color) "{{{2
  let color = strpart(a:color, 1)
  let group = 'Color' . color
  if len(color) == 3
    let color = substitute(color, '.', '&&', 'g')
  endif
  if !hlexists(group) || s:force_group_update
    let fg = g:colorizer_fgcontrast < 0 ? '#'.color : s:FGforBG(color)
    if &t_Co == 256
      exe 'hi '.group.' ctermfg='.s:Rgb2xterm(fg).' ctermbg='.s:Rgb2xterm('#'.color)
    endif
    " Always set gui* as user may switch to GUI version and it's cheap
    exe 'hi '.group.' guifg='.fg.' guibg=#'.color
  endif
  if !exists("w:colormatches[group]")
    let w:colormatches[group] = matchadd(group, a:color.'\>')
  endif
endfunction
function s:PreviewColorInLine(where) "{{{2
  let place = 0
  let colorpat = '#[0-9A-Fa-f]\{3\}\>\|#[0-9A-Fa-f]\{6\}\>'
  while 1
    let foundcolor = matchstr(getline(a:where), colorpat, place)
    let place = match(getline(a:where), colorpat, place) + 1
    if foundcolor == ''
      break
    endif
    call s:SetMatcher(foundcolor)
  endwhile
endfunction
function s:ColorHighlight(update, ...) "{{{2
  if exists('w:colormatches')
    if !a:update
      return
    endif
    call s:ColorClear()
  endif
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
    autocmd CursorHold,CursorHoldI,InsertLeave * silent call s:PreviewColorInLine('.')
    autocmd BufRead * silent call s:ColorHighlight(1)
    autocmd WinEnter * silent call s:ColorHighlight(0)
    autocmd ColorScheme * let s:force_group_update=1 | silent call s:ColorHighlight(1)
  augroup END
endfunction
function s:ColorClear() "{{{2
  augroup Colorizer
    au!
  augroup END
  let savepos = tabpagenr()
  tabdo windo call s:ClearMatches()
  exe 'tabn '.savepos
endfunction
function s:ClearMatches() "{{{2
  if !exists('w:colormatches')
    return
  endif
  for i in values(w:colormatches)
    call matchdelete(i)
  endfor
  unlet w:colormatches
endfunction
function s:ColorToggle() "{{{2
  if exists('#Colorizer#BufEnter')
    call s:ColorClear()
    echomsg 'Disabled color code highlighting.'
  else
    call s:ColorHighlight(0)
    echomsg 'Enabled color code highlighting.'
  endif
endfunction
let s:colortable=[] "{{{2
for c in range(0, 254)
  let color = s:Xterm2rgb(c)
  call add(s:colortable, color)
endfor
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
"Define commands {{{2
command -bar -bang ColorHighlight call s:ColorHighlight(1, "<bang>")
command -bar ColorClear call s:ColorClear()
command -bar ColorToggle call s:ColorToggle()
nnoremap <unique> <silent> <Plug>Colorizer :ColorToggle<CR>
if !hasmapto("<Plug>Colorizer") && (!exists("g:colorizer_nomap") || g:colorizer_nomap == 0)
  nmap <unique> <Leader>tc <Plug>Colorizer
endif
" Cleanup and modelines {{{1
let &cpo = s:save_cpo
" vim:ft=vim:fdm=marker:fen:fmr={{{,}}}:
