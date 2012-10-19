" all_filter.vim - A plug-in to filter lines of a buffer into a new search
" buffer
"
" Optional flags:
"     g:use_default_all_filter_mappings = 1 or 0
"

if !has('python')
    " exit if python is not available.
    finish
endif

if exists("b:did_all_filter_plugin")
    finish " only load once
else
    let b:did_all_filter_plugin = 1
endif

command! -nargs=+ All :call NewAllCmd("<args>", "grep")
command! -nargs=+ EAll :call NewAllCmd("<args>", "egrep")

" Make searches case-insensitive by default (without a way to disable it)
let g:all_filter_default_grep_opts="-i"

"-------------------------------------------------------------------------------
" Default Mappings
"-------------------------------------------------------------------------------
if !exists('g:use_default_all_filter_mappings') || (g:use_default_all_filter_mappings == 1)
    " Interactive filter
    nnoremap <silent> <Leader>f :call NewAllCmd(input("Search for: "), "egrep")<CR>
    " Last search term filter
    nnoremap <silent> <Leader>F :call NewAllCmd(@/, "grep")<CR>
    " Sequence filter: extract sequence from current line and show related
    " events
    nnoremap <silent> <Leader>s :call NewAllCmd(GetKey("seq=")."\\b", "egrep")<CR>
    " Parent sequence filter: extract parent sequence from current line, then
    " show all parent and child events
    nnoremap <silent> <Leader>p :call NewAllCmd(GetKey("Pseq=")[1:]."\\b", "egrep")<CR>
    " Pipe pass filter: show pipe passes for the same chip/slice/pipe
    nnoremap <silent> <Leader>fp :call NewAllCmd(GetFields(2,4," "), "egrep")<CR>
    " Super filter: extracts address from current line and shows all sequences
    " operating on the same address, plus any errors
    nnoremap <silent> <Leader>S :call NewAllCmd(GetEverything(GetKey("seq=")), "egrep")<CR>
    " Address filter: extracts address from current line and shows all events
    " with the same address
    nnoremap <silent> <Leader>a :call NewAllCmd(GetKey("Adr=")[4:15], "grep")<CR>
endif

function! GetKey(key)
python <<PYTHON
import vim
key = vim.eval("a:key")
toks = vim.current.line.split()
seq = [x for x in toks if x.startswith(key)]
if seq:
    vim.command(r"return '%s'"%seq[0])
else:
    vim.command(r"throw '%s not found on current line'" % key)
PYTHON
endfunction

function! GetFields(start, stop, delim)
    " Return fields [start:stop] of the current line, split on *delim*
    let toks = split(getline('.'), a:delim)
    let start = a:start
    let stop = a:stop
    if len(toks) >= stop
        return join(toks[start : stop], a:delim)
    endif
    throw "Number of tokens on line less than the range requested"
endfunction

function! GetEverything(search)
python <<PYTHON
import vim
import re
import sys
search = vim.eval("a:search")
trace = vim.current.buffer[:]
# Find all lines containing search string
seq = [t for t in trace if t.find(search) > 0]
# Find all addresses used by seqNum
allAdrs = [a[4:15] for a in " ".join(seq).split() if a.startswith("Adr=")]
allAdrs = sorted(set(map(lambda x: x.strip(), allAdrs)))
# Find all the sequences operating on all addresses in adr
reAdrs = re.compile("|".join(allAdrs), re.IGNORECASE)
adrMatches = [t for t in trace if reAdrs.search(t) != None]
# Stick a space on the end of each sequence number
reSeqNum = re.compile(r"seq=[0-9]+", re.IGNORECASE)
allSeqs = map(lambda x: x.replace("seq=","")+r"\b", reSeqNum.findall(r"\b".join(adrMatches)))
#radness="ERROR|" + "|".join(sorted(set(allSeqs)))
radness="ERROR|seq=(" + "|".join(sorted(set(allSeqs))) + ")"
if radness:
  vim.command("return '%s'"%radness)
else:
  vim.command("return 'Something.Awful.Just.Happened.In.GetEverything'")
PYTHON
endfunction

function! NewAllCmd(search, grep_cmd)
python <<PYTHON
import vim, re, os
original_row, original_col = vim.current.window.cursor
search = vim.eval("a:search")
grep_cmd = vim.eval("a:grep_cmd")
all_options = vim.eval("g:all_filter_default_grep_opts")
# check that a buffer with the intended name doesn't already exist
title = search.replace("|", "\|").replace(r'\b', '')
title = title.replace("\"", "\\\"").replace(" ", "\ ")
exists = any(title == b.name.rpartition("/")[2] if b.name else False for b in vim.buffers)
if exists:
    vim.command("echo %r" % ("buffer with name %r already exists!" % title))
else:
    fname = vim.eval("bufname('')")
    ftype = vim.eval("&filetype")
    bnum = vim.current.buffer.number
    # save current buffer to tempfile
    tempname = vim.eval("tempname()")
    vim.command("silent w "+tempname)
    # create map to jump to the buffer of the last all view
    vim.command('map <buffer> <C-q> :exec "buffer" g:last_all_buf\|exec "normal j"<cr>')
    # new unnamed buffer
    vim.command("enew")
    # make it a scratch buffer
    vim.command("set buftype=nofile bufhidden=hide noswapfile")
    # read grep/grin output into empty buffer
    vim.command("silent r ! %s -n %s %s %s" %
                (grep_cmd, all_options, re.escape(search), tempname))
    # hack to check if any lines found by cursor position
    row, col = vim.current.window.cursor
    if (row, col) == (1, 0):
        vim.command("bd")
        vim.command("echo %r" % ("Pattern %r not found!" % search))
    else:
        vim.command("let g:last_all_buf=%s"%vim.current.buffer.number)
        # set filetype
        vim.command("setf "+ftype)
        # change name of buffer to search pattern
        vim.command("file "+title)
        # hack to make buffer show up in minibufexplorer
        vim.command("new")
        vim.command("bd")
        # hack to delete first line (blank)
        vim.command("normal ggdd")
        # jump to line in search buffer associated with line the search was
        # triggered from
        vim.command("exec search('^%d:')" % original_row)
        # center the current line
        vim.command("normal zz")
        # create map to jump to original buffer
        vim.command('map <buffer> <C-q> :let @z=GetFields(0,0,":")\|b %s\|exec "normal ".getreg("z")."Gzz"<CR>'%bnum)
if os.path.isfile(tempname):
    os.remove(tempname)
PYTHON
endfunction

