" hanoi.vim -- Tower of Hanoi game for Vim
" Author: Hari Krishna (hari_vim at yahoo dot com)
" Last Change: 05-Feb-2004 @ 10:12
" Created: 29-Jan-2004
" Version: 1.0.0
" Licence: This program is free software; you can redistribute it and/or
"          modify it under the terms of the GNU General Public License.
"          See http://www.gnu.org/copyleft/gpl.txt 
" Download From:
"     http://www.vim.org/script.php?script_id=
" Description:
"   This is just a quick-loader for the Tower of Hanoi game, see
"   games/hanoi/hanoi.vim for the actual code.
"
"   Use hjkl keys to move the disk. Use <Space> to pause the play. Use <C-C>
"   to stop the demo or play at any time.
"
"   Some good information about this puzzle can be found at:
"     http://www.cut-the-knot.org/recurrence/hanoi.shtml

command! -nargs=? Hanoi :runtime games/hanoi/hanoi.vim | THanoi <args>

