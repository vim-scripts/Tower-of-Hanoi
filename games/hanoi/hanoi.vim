" hanoi.vim -- Tower of Hanoi game for Vim
" Author: Hari Krishna (hari_vim at yahoo dot com)
" Last Change: 05-Feb-2004 @ 10:12
" Created: 29-Jan-2004
" Requires: Vim-6.2, multvals.vim(3.4), genutils.vim(1.10)
" Version: 1.0.0
" Licence: This program is free software; you can redistribute it and/or
"          modify it under the terms of the GNU General Public License.
"          See http://www.gnu.org/copyleft/gpl.txt 
" Download From:
"     http://www.vim.org/script.php?script_id=
" Description:
" TODO:

if exists('loaded_hanoi')
  finish
endif

if v:version < 602
  echomsg 'You need Vim 6.2 to run this version of hanoi.vim.'
  finish
endif

" Dependency checks.
if !exists('loaded_multvals')
  runtime plugin/multvals.vim
endif
if !exists('loaded_multvals') || loaded_multvals < 304
  echomsg 'hanoi: You do not have the latest version of multvals.vim'
  finish
endif
if !exists('loaded_genutils')
  runtime plugin/genutils.vim
endif
if !exists('loaded_genutils') || loaded_genutils < 110
  echomsg 'hanoi: You do not have the latest version of genutils.vim'
  finish
endif
let loaded_hanoi = 1

if !exists('s:myBufNum')
  let s:myBufNum = -1
endif

let s:GAP = 2 " Gap between the pole and disk at the top.
let s:INCREMENT = 2 " Increment in width.
let s:POLE_CLEARANCE = 2
let s:MINWIDTH = 3 " Width of the disk with ID = 1.

let s:playPaused = 0

command! -nargs=? THanoi :call <SID>Hanoi(<args>)

function! s:SetupBuf()
  let s:MAXX = winwidth(0)
  let s:MAXY = winheight(0)
  let maxWidthByWidth = (s:MAXX - 4)/3 " Leave 1 space and devide into 3 parts.
  let maxWidthByHeight = s:MAXY - s:GAP - s:POLE_CLEARANCE + 1
  let s:MAXWIDTH = (maxWidthByWidth < maxWidthByHeight) ? maxWidthByWidth :
        \ maxWidthByHeight
  let s:MAX_DISKS = (s:MAXWIDTH - s:MINWIDTH)/s:INCREMENT

  call s:clear()
  call SetupScratchBuffer()
  setlocal noreadonly " Or it shows [RO] after the buffer name, not nice.
  setlocal nonumber
  setlocal foldcolumn=0 nofoldenable
  setlocal tabstop=1

  " Setup syntax such a way that any non-tabs appear as selected.
  syn clear
  syn match HanoiSelected "[^\t]"
  hi HanoiSelected guifg=grey90 guibg=black gui=reverse
endfunction

function! s:Hanoi(...)
  if s:myBufNum == -1
    " Temporarily modify isfname to avoid treating the name as a pattern.
    let _isf = &isfname
    let _cpo = &cpo
    try
      set isfname-=\
      set isfname-=[
      set cpo-=A
      if exists('+shellslash')
	exec "sp \\\\[Hanoi]"
      else
	exec "sp \\[Hanoi]"
      endif
    finally
      let &isfname = _isf
      let &cpo = _cpo
    endtry
    let s:myBufNum = bufnr('%')
  else
    let buffer_win = bufwinnr(s:myBufNum)
    if buffer_win == -1
      exec 'sb '. s:myBufNum
    else
      exec buffer_win . 'wincmd w'
    endif
  endif
  wincmd _

  let restCurs = ''
  try
    setlocal modifiable


    let restCurs = substitute(GetVimCmdOutput('hi Cursor'),
          \ '\_s*Cursor\s*xxx\s*', 'hi Cursor ', '')
    let hideCurs = substitute(GetVimCmdOutput('hi Normal'),
          \ '\_s*Normal\s*xxx\s*', 'hi Cursor ', '')

    if s:playPaused
      exec hideCurs
      call s:play()
      return
    endif

    call s:SetupBuf()

    if a:0 == 0
      let number = s:welcome()
    else
      let number = a:1
    endif
    if ! s:Initialize(number)
      quit
      return
    endif

    "exec "normal \<C-G>a" " Create an undo point.
    "call s:putstr(s:MAXY/2, s:MAXX/2-20,
    "      \ 'You want to play or see the Demo(p, d)?[p] ')
    "redraw
    echon 'You want to play or see the Demo(p, d)?[p] '
    let char = getchar()
    "silent! undo
    if char == '^\d\+$' || type(char) == 0
      let char = nr2char(char)
    endif " It is the ascii code.

    exec hideCurs
    if char == "d"
      call s:demo()
    else
      call s:play()
    endif
  finally
    exec restCurs | " Restore the cursor highlighting.
    setlocal nomodifiable
  endtry
endfunction

function! s:welcome()
  call s:clear()
  call s:putstr(s:MAXY/2 - 4, s:MAXX/2 - 15, 'T O W E R S   O F   H A N O I')
  call s:putstr(s:MAXY/2, 1, 'Move all the disks from the I pole to III pole')
  call s:putstr(s:MAXY/2 + 2, 1, 'Bigger disk on a Smaller one is not allowd')
  call s:putstr(s:MAXY/2 + 4, 1, "Use 'h' & 'l' keys to Select the pole" .
        \ " and move a disk ")
  call s:putstr(s:MAXY/2 + 6, 1, "Use 'j' & 'k' keys to lift and drop a disk")
  call s:putstr(s:MAXY/2 + 8, 1, 'q or <ctrl>C to Quit')
  call s:putstr(s:MAXY/2 + 10, 1, 'How many disks you want to select?(<' .
        \ (s:MAX_DISKS+1) . ")? ")
  redraw
  return input('Enter number of disks: ') + 0
endfunction

function! s:Initialize(number)
  call s:clear()
  if a:number > s:MAX_DISKS
    echo "Sorry, too many disks."
    return 0
  elseif a:number < 1
    echo "Kidding?"
    return 0
  else
    let s:number = a:number
  endif

  " 1 for base and a few left out at the top.
  let s:poleheight = s:number + 1 + s:POLE_CLEARANCE
  let s:polepos = (s:MAXY - s:poleheight) / 2 + s:poleheight " Bottom position.

  let i = 0
  while i < 3
    " Create 3 poles.
    call s:PoleCreate(i, s:polepos, s:MAXX/6*(2*i+1), s:poleheight, s:GAP,
	  \ s:number)
    call s:PoleDraw(i, s:MINWIDTH, s:INCREMENT)
    let i = i + 1
  endwhile

  let i = s:number
  while i > 0
    " Create disks.
    call s:DiskCreate(i, s:MINWIDTH, s:INCREMENT)
    call s:DiskSetIsOn(i, 1)
    call s:PolePushDisk(0, i)
    call s:DiskDraw(i, ' ', 1)
    let i = i - 1
  endwhile
  let s:curdisk = i + 1
  call s:DiskDraw(s:curdisk, '-', 1)
  let s:curpole = 0

  return 1
endfunction

function! s:play()
  let s:playPaused = 0
  redraw
  while !(s:PoleNOD(2) == s:number && s:DiskIsOn(s:curdisk))
    let char = getchar()
    if char == '^\d\+$' || type(char) == 0
      let char = nr2char(char)
    endif " It is the ascii code.

    try " [-2f]

    if char == 'q'
      quit
      return
    elseif char == ' '
      let s:playPaused = 1
      echo 'Game paused'
      return
    elseif char == 'k' " UP
      if s:DiskIsOn(s:curdisk) " If only on.
        call s:DiskErase(s:curdisk)
        call s:DiskSetIsOn(s:curdisk, 0)
        call s:DiskDraw(s:curdisk, '-', 1) | redraw
      endif
    elseif char == 'j' " DOWN
      if ! s:DiskIsOn(s:curdisk) " If not already on only.
        if s:PoleTopId(s:curpole) > s:curdisk " Allow only smaller disk.
          call s:DiskErase(s:curdisk)
          call s:DiskSetIsOn(s:curdisk, 1)
          call s:DiskDraw(s:curdisk, '-', 1) | redraw
        endif
      endif
    elseif char == 'l' " RIGHT
      let pcurpole = s:curpole
      let s:curpole = (s:curpole == 2) ? 0 : s:curpole + 1
      if ! s:DiskIsOn(s:curdisk) " If the disk is not on the pole.
        call s:DiskErase(s:curdisk)
        call s:PolePushDisk(s:curpole, s:curdisk)
        call s:PolePopDisk(pcurpole)
        call s:DiskDraw(s:curdisk, '-', 1) | redraw
      else
        if s:PoleNOD(s:curpole) == 0 " If no disk on next pole,
          let s:curpole = (s:curpole == 2) ? 0 : s:curpole + 1
          if s:PoleNOD(s:curpole) == 0
            let s:curpole = pcurpole " Invalid pole, restore.
            throw 'BreakIfLoop'
          endif
        endif
        call s:DiskDraw(s:curdisk, ' ', 1)
        let s:curdisk = s:PoleGetDisk(s:curpole, s:PoleNOD(s:curpole))
        call s:DiskDraw(s:curdisk, '-', 1) | redraw
      endif
    elseif char == 'h' " LEFT
      let pcurpole = s:curpole
      let s:curpole = (s:curpole == 0) ? 2 : s:curpole - 1
      if ! s:DiskIsOn(s:curdisk) " If the disk is not on the pole.
        call s:DiskErase(s:curdisk)
        call s:PolePushDisk(s:curpole, s:curdisk)
        call s:PolePopDisk(pcurpole)
        call s:DiskDraw(s:curdisk, '-', 1) | redraw
      else
        if s:PoleNOD(s:curpole) == 0 " If no disk on next pole,
          let s:curpole = (s:curpole == 0) ? 2 : s:curpole - 1
          if s:PoleNOD(s:curpole) == 0
            let s:curpole = pcurpole " Invalid pole, restore.
            throw 'BreakIfLoop'
          endif
        endif
        call s:DiskDraw(s:curdisk, ' ', 1)
        let s:curdisk = s:PoleGetDisk(s:curpole, s:PoleNOD(s:curpole))
        call s:DiskDraw(s:curdisk, '-', 1) | redraw
      endif
    endif

    catch /BreakIfLoop/ " [+2s]
    endtry
  endwhile
  call s:putstr(s:MAXY/2 - 2, s:MAXX/2 - 10, 'E X C E L L E N T !!')
endfunction

function! s:demo()
  let pole = 0
  let i = 0
  while i < s:number
    call s:move(0, pole, 2) " Ultimate target.
    if (pole)
      let pole = 0
    else
      let pole = 1
    endif
    let i = i + 1
  endwhile
endfunction

" Move the disk at the given position from source pole to destination pole.
function! s:move(position, sp, dp)
  let op = 3 - a:sp - a:dp " Find the other pole.
  let position = a:position

  while position < (s:PoleNOD(a:sp) - 1) " While this is not the top most disk,
    " first move the disk that is above this disk to the other pole,
    call s:move(position + 1, a:sp, op)

    let tmpNDisks = s:PoleNOD(a:dp)
    let i = 0
    " if the destination pole is not empty,
    if tmpNDisks
      " find the disk which is larger than the present,
      while i < tmpNDisks
	if s:PoleGetDiskID(a:dp, tmpNDisks - i) >
	      \ s:PoleGetDiskID(a:sp, position + 1)
	  break
	endif
	let i = i + 1
      endwhile
    endif
    " and move all the disks that are above this disk to the other pole, such
    " that the disk can be placed on the destination pole,
    if i
      call s:move(tmpNDisks - i, a:dp, op) " Results in a recursive call.
    endif
  endwhile
  " and finally move the disk that was asked for.
  call s:delay()
  let s:curdisk = s:PolePopDisk(a:sp)
  call s:DiskErase(s:curdisk)
  call s:DiskSetIsOn(s:curdisk, 0)
  call s:DiskDraw(s:curdisk, '-', 1) | redraw
  call s:delay()
  call s:DiskErase(s:curdisk)
  call s:PolePushDisk(a:dp, s:curdisk)
  call s:DiskDraw(s:curdisk, '-', 1) | redraw
  call s:delay()
  call s:DiskErase(s:curdisk)
  call s:DiskSetIsOn(s:curdisk, 1)
  call s:DiskDraw(s:curdisk, ' ', 1) | redraw
endfunction

function! s:putrow(y, x1, x2, ch)
  let y = (a:y > 0) ? a:y : 1
  let x1 = (a:x1 > 0) ? a:x1 : 1
  let x2 = (a:x2 > 0) ? a:x2 : 1
  let ch = a:ch[0]
  let _search = @/
  let _report = &report
  try
    set report=99999
    let @/ = '\%>'.(x1-1).'c.\%<'.(x2+1).'c'
    silent! exec y.'s//'.ch.'/g'
  finally
    let &report = _report
    let _search = @/
  endtry
endfunction

function! s:putcol(y1, y2, x, ch)
  let y1 = (a:y1 > 0) ? a:y1 : 1
  let y2 = (a:y2 > 0) ? a:y2 : 1
  let x = (a:x > 0) ? a:x : 1
  let ch = a:ch[0]
  let _search = @/
  let _report = &report
  try
    set report=99999
    let @/ = '\%'.x.'c.'
    silent! exec y1.','.y2.'s//'.ch
  finally
    let &report = _report
    let _search = @/
  endtry
endfunction

function! s:putstr(y, x, str)
  let y = (a:y > 0) ? a:y : 1
  let x = (a:x > 0) ? a:x : 1
  let _search = @/
  let _report = &report
  try
    if a:y > line('$')
      $put=a:str
    else
      set report=99999
      let @/ = '\%'.x.'c.\{'.strlen(a:str).'}'
      silent! exec y.'s//'.escape(a:str, '\&~')
    endif
  finally
    let &report = _report
    let _search = @/
  endtry
endfunction

function! s:clear()
  call OptClearBuffer()
  " Fill the buffer with tabs.
  let tabFill = substitute(GetSpacer(s:MAXX), ' ', "\t", 'g')
  while strlen(tabFill) < s:MAXX
    let tabFill = tabFill.strpart(tabFill, 0, s:MAXX - strlen(tabFill))
  endwhile
  call setline(1, tabFill)
  let i = 2
  while i <= s:MAXY
    $put=tabFill
    let i = i + 1
  endwhile 
endfunction

function! s:delay()
  sleep 500m
endfunction

" Pole {{{

function! s:PoleCreate(pole, posy, posx, height, gap, maxno)
  let s:pole{a:pole} = a:pole " Id
  let s:pole{a:pole}{'y'} = a:posy
  let s:pole{a:pole}{'x'} = a:posx
  let s:pole{a:pole}{'height'} = a:height
  let s:pole{a:pole}{'gap'} = a:gap
  let s:pole{a:pole}{'disks'} = ''
  let s:pole{a:pole}{'nod'} = 0
  let s:pole{a:pole}{'maxno'} = a:maxno " Capacity.
endfunction

function! s:PoleY(pole)
  return s:pole{a:pole}{'y'}
endfunction

function! s:PoleX(pole)
  return s:pole{a:pole}{'x'}
endfunction

function! s:PoleHeight(pole)
  return s:pole{a:pole}{'height'}
endfunction

function! s:PoleGap(pole)
  return s:pole{a:pole}{'gap'}
endfunction

"function! s:PoleNOD(pole)
"  return s:pole{a:pole}{'nod'}
"endfunction

" FIXME: I don't need 'nod' property at all.
function! s:PoleNOD(pole)
  return MvNumberOfElements(s:PoleDisks(a:pole), ',')
endfunction

"function! s:PoleSetNOD(pole, nod)
"  let s:pole{a:pole}{'nod'} = a:nod
"endfunction

function! s:PoleDisks(pole)
  return s:pole{a:pole}{'disks'}
endfunction

function! s:PoleSetDisks(pole, disks)
  let s:pole{a:pole}{'disks'} = a:disks
endfunction

function! s:PoleMaxNo(pole)
  return s:pole{a:pole}{'maxno'}
endfunction

function! s:PoleTopId(pole)
  return (s:PoleNOD(a:pole) < 2) ? s:PoleMaxNo(a:pole) + 1 :
        \ MvElementAt(s:PoleDisks(a:pole), ',', s:PoleNOD(a:pole) - 2)
endfunction

function! s:PolePushDisk(pole, disk)
  " CHECK: if the current top disk is bigger than this disk.
  call s:PoleSetDisks(a:pole, MvAddElement(s:PoleDisks(a:pole), ',', a:disk))
  "call s:PoleSetNOD(a:pole, s:PoleNOD(a:pole) + 1)
  call s:DiskMoveTo(a:disk, a:pole, s:PoleNOD(a:pole))
endfunction

function! s:PolePopDisk(pole)
  " CHECK: if there are any other disks which are not on the poles.
  let disk = MvLastElement(s:PoleDisks(a:pole), ',')
  call s:PoleSetDisks(a:pole, MvRemoveElement(s:PoleDisks(a:pole), ',', disk))
  "call s:PoleSetNOD(a:pole, s:PoleNOD(a:pole) - 1)
  "call s:DiskSetIsOn(a:disk, 0)
  return disk
endfunction

function! s:PoleGetDisk(pole, pos)
  return MvElementAt(s:PoleDisks(a:pole), ',', a:pos - 1)
endfunction

" Get the disk id of the disk at the given position.
function! s:PoleGetDiskID(pole, pos)
  return (s:PoleNOD(a:pole) >= a:pos) ? s:PoleGetDisk(a:pole, a:pos) :
	\ 0 " 0 for no disks.
endfunction

function! s:PoleDraw(pole, min, inc)
  let y = s:PoleY(a:pole)
  let x = s:PoleX(a:pole)
  let height = s:PoleHeight(a:pole)
  let maxno = s:PoleMaxNo(a:pole)

  call s:putcol(y-height, y, x, ' ')

  call s:DiskCreate(maxno+1, a:min, a:inc) " Dummy disk as a base.
  call s:DiskSetIsOn(maxno+1, 1)
  call s:DiskMoveTo(maxno+1, a:pole, 0) " Move to the base position.
  call s:DiskDraw(maxno+1, ' ', 0)
endfunction

" Pole }}}


" Disk {{{

function! s:DiskCreate(disk, min, inc)
  let s:disk{a:disk} = a:disk " Id
  let s:disk{a:disk}{'width'} = a:min + a:inc * (a:disk - 1)
  let s:disk{a:disk}{'pole'} = ''
  let s:disk{a:disk}{'pos'} = ''
  let s:disk{a:disk}{'ison'} = ''
endfunction

function! s:DiskWidth(disk)
  return s:disk{a:disk}{'width'}
endfunction

function! s:DiskPole(disk)
  return s:disk{a:disk}{'pole'}
endfunction

function! s:DiskPos(disk)
  return s:disk{a:disk}{'pos'}
endfunction

function! s:DiskIsOn(disk)
  return s:disk{a:disk}{'ison'}
endfunction

function! s:DiskSetIsOn(disk, bool)
  let s:disk{a:disk}{'ison'} = a:bool
endfunction

function! s:DiskMoveTo(disk, pole, pos)
  let s:disk{a:disk}{'pole'} = a:pole
  let s:disk{a:disk}{'pos'} = a:pos
endfunction

function! s:DiskErase(disk)
  call s:DiskDrawImpl(a:disk, "\t", (s:DiskIsOn(a:disk) ? 2 : 0))
endfunction

function! s:DiskDraw(disk, ch, opt)
  call s:DiskDrawImpl(a:disk, a:ch, a:opt)
endfunction

function! s:DiskDrawImpl(disk, ch, opt)
  let pole = s:DiskPole(a:disk)
  let width = s:DiskWidth(a:disk)
  let position = s:DiskPos(a:disk)
  let y = s:DiskIsOn(a:disk) ? s:PoleY(pole) - position :
        \ s:PoleY(pole) - s:PoleHeight(pole) - s:PoleGap(pole)

  let stx = s:PoleX(pole) - width/2
  call s:putrow(y, stx, stx+width, a:ch)
  if a:opt == 1
    " Show the disk id in the middle.
    call s:putstr(y, s:PoleX(pole), a:disk)
  elseif a:opt == 2
    " Erasing, make sure pole is restored correctly.
    call s:putstr(y, s:PoleX(pole), " ")
  endif
endfunction
 
" Disk }}}

" vim6:fdm=marker et sw=2
