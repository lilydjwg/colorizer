" Name Of File:	colorizer.vim
" Description:	Colorize all text in the form #rrggbb or #rgb
" Maintainer:	lilydjwg <lilydjwg@gmail.com>
" Licence:	No Warranties. Do whatever you want with this. But please tell me!
" Last Change:	2011-05-08
" Version:	1.2.2
" Usage:	This file should reside in the plugin directory.
" Derived From: css_color.vim
" 		http://www.vim.org/scripts/script.php?script_id=2150
" Thanks To:	Niklas Hofer (Author of css_color.vim), Ingo Karkat, Rykka 
" Usage:
"
" This plugin defines four commands:
"
" 	ColorHighlight	- start/update highlighting
" 	ColorClear      - clear all highlights
" 	ColorToggle     - toggle highlights
"       ColorBuffer     - toggle highlight current buffer
" NEW!  ColorBlock      - toggle color block 
"                         See http://oi55.tinypic.com/2qktgrd.jpg
"
" buffers of css and html filetype are highlighted by default.
"
" Mappings:
" By default, the following are mapped:
" 	<leader>tc is mapped to ColorToggle
" 	<leader>tb is mapped to ColorBuffer
" 	<leader>tk is mapped to ColorBlock
" If you want to use another key map, do like this:
" 	nmap ,tc <Plug>Colorizer
" 	nmap ,tb <Plug>ColorBuffer
" 	nmap ,tk <Plug>ColorBlock
"
" Configuraion:
" do not setup any mappings:
"	let g:colorizer_nomap = 1
" highlight the following filetype of buffer by default:
"	let g:colorizer_filetype = 'css,html'
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
  if exists("w:colorizer_block") && w:colorizer_block==1
    return "#".pure
  endif
  let r = eval('0x'.pure[0].pure[1])
  let g = eval('0x'.pure[2].pure[3])
  let b = eval('0x'.pure[4].pure[5])
  if r*30 + g*59 + b*11 > 12000
    return '#222222'
  else
    " softer 
    return '#cccccc'
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
  endfor
  return x
endfunction

function s:SetMatcher(color) "{{{2
  let color = strpart(a:color, 1)
  if len(color) == 3
    let color = substitute(color, '.', '&&', 'g')
  endif
  let group = 'Color' . color
  " Use dict , so only matchadd() while dict(key) not exists.
  if !exists("w:colorizer_MatchDic")|let w:colorizer_MatchDic={}|endif
  if !has_key(w:colorizer_MatchDic,group)
      let fg = s:FGforBG(color)
      if &t_Co == 256
          exe 'hi '.group.' ctermfg='.s:Rgb2xterm(fg).' ctermbg='.s:Rgb2xterm('#'.color)
      endif
      exe 'hi '.group.' guifg='.fg.' guibg=#'.color
      let w:colorizer_MatchDic[group] = matchadd(group, a:color.'\>')
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
function s:ClearMatches() "{{{2
    if !exists('w:colorizer_MatchDic')
        return
    endif
    for [key,var] in items(w:colorizer_MatchDic)
        call matchdelete(var)
        exec "hi clear ".key." NONE"
    endfor 
    unlet w:colorizer_MatchDic
endfunction
function s:ColorHighlight(update) "{{{2
  if exists('w:colorizer_MatchDic')
    if !a:update
      return
    endif
    call s:ColorClear()
  endif
  for i in range(1, line("$"))
    call s:PreviewColorInLine(i)
  endfor
  augroup Colorizer
    au!
    autocmd CursorHold,CursorHoldI,InsertLeave * silent call s:PreviewColorInLine('.')
    autocmd BufEnter * silent call s:PreviewColorInLine('.')
    autocmd WinEnter * silent call s:ColorHighlight(0)
  augroup END
endfunction
function s:ColorClear() "{{{2
    if exists("#Colorizer")|exec "aug! Colorizer"|endif
    let savepos = tabpagenr()
    tabdo windo call s:ClearMatches()
    exe 'tabn '.savepos
endfunction
function s:ColorToggle() "{{{2
  if exists('#Colorizer#BufEnter')
    call s:ColorClear()
    echomsg 'Disabled color code highlighting.'
  else
    call s:ColorHighlight(1)
    echomsg 'Enabled color code highlighting.'
  endif
endfunction
let s:colortable=[] "{{{2
for c in range(0, 254)
  let color = s:Xterm2rgb(c)
  call add(s:colortable, color)
endfor
"Toggles colorizing of current buffer
function s:ColorBuffer()"{{{2
   call s:ClearBuffer()
  if !exists("w:colorize_buffer") || w:colorize_buffer==0
    let w:colorize_buffer=1
    call s:RedrawBuffer()
    aug colorizer_buffer 
      au!
      autocmd CursorHold,CursorHoldI,InsertLeave <buffer>
                  \ silent call s:PreviewColorInLine('.')
      autocmd BufEnter <buffer> silent call s:PreviewColorInLine('.')
    aug END
   echohl Title |echo "Done." |echohl Normal
  elseif w:colorize_buffer==1 
   unlet w:colorize_buffer
   echohl Title |echo "Done." |echohl Normal
  endif
endfunction
"Redraw and clear in buffer
function s:RedrawBuffer()
   for i in range(1, line("$"))
      call s:PreviewColorInLine(i)
   endfor
   redraw
 endfunction
function s:ClearBuffer()
  if exists("#colorizer_buffer")|exec "au! colorizer_buffer"|endif
  call s:ClearMatches()
endfunction
" NEW: COLOR BLOCK toggle: Same color with FG and BG
function! s:ToggleColorBlock()
   if !exists("w:colorizer_block") || w:colorizer_block==0
     let w:colorizer_block=1
     echohl Modemsg | echo "set color block" | echohl Normal
   elseif w:colorizer_block==1
     unlet w:colorizer_block
     echohl Todo | echo "set NO color block" | echohl Normal
   endif
   call s:ClearBuffer()
   call s:RedrawBuffer()
endfunction

if !exists("g:colorizer_filetype")
  let g:colorizer_filetype = 'css,html'
endif

augroup Colorizer_filetype
  au!
  for type in split(g:colorizer_filetype,',')
    exe 'autocmd Filetype '.type.' ColorizerBuffer'
  endfor
augroup END

"Define commands {{{2
command -bar ColorBlock call s:ToggleColorBlock() 
command -bar ColorHighlight call s:ColorHighlight(1)
command -bar ColorClear call s:ColorClear()
command -bar ColorToggle call s:ColorToggle()
command -bar ColorBuffer call s:ColorBuffer()
nnoremap <unique> <silent> <Plug>ColorBuffer :ColorBuffer<CR>
nnoremap <unique> <silent> <Plug>Colorizer :ColorToggle<CR>
nnoremap <unique> <silent> <Plug>ColorBlock :ColorBlock<CR>
if !exists("g:colorizer_nomap") || g:colorizer_nomap == 0
  if !hasmapto("<Plug>Colorizer")
    nmap <unique> <Leader>tc <Plug>Colorizer
  endif
  if !hasmapto("<Plug>ColorBuffer")
    nmap <unique> <leader>tb <Plug>ColorBuffer
  endif
  if !hasmapto("<Plug>ColorBlock")
    nmap <unique> <Leader>tk <Plug>ColorBlock 
  endif
endif
" Cleanup and modelines {{{1
let &cpo = s:save_cpo
" vim:ft=vim:fdm=marker:fen:fmr={{{,}}}:sw=2:
