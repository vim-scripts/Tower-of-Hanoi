" hanoi.vim -- Tower of Hanoi game for Vim
" Author: Hari Krishna (hari_vim at yahoo dot com)
" Last Change: 09-Feb-2004 @ 12:34
" Created: 29-Jan-2004
" Version: 1.1.0
" Licence: This program is free software; you can redistribute it and/or
"          modify it under the terms of the GNU General Public License.
"          See http://www.gnu.org/copyleft/gpl.txt 
" Download From:
"     http://www.vim.org/script.php?script_id=900
" Description:
"   This is just a quick-loader for the Tower of Hanoi game, see
"   games/hanoi/hanoi.vim for the actual code.
"
"   Use hjkl keys to move the disk. Use <Space> to pause the play. Use <C-C>
"   to stop the demo or play at any time.
"
"   Some good information about this puzzle can be found at:
"     http://www.cut-the-knot.org/recurrence/hanoi.shtml

command! -nargs=? Hanoi :call <SID>Hanoi(<args>)

function! s:Hanoi(...)
  if !exists('g:loaded_hanoi')
    " If it is not already loaded, first load it.
    runtime games/hanoi/hanoi.vim
  endif
  let g:hanoiNDisks = (a:0 > 0) ? a:1 : ''
  runtime games/hanoi/hanoi.vim
endfunction

