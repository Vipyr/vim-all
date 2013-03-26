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
endif
let b:did_all_filter_plugin = 1


command! -nargs=+ All    :call NewAllBuffer("<args>", "grep")
command! -nargs=+ AllAdd :call NewAllBuffer("<args>", "grep", 'a')
command! -nargs=+ EAll    :call NewAllBuffer("<args>", "egrep")
command! -nargs=+ EAllAdd :call NewAllBuffer("<args>", "egrep", 'a')


" Make searches case-insensitive by default (without a way to disable it)
let g:all_filter_default_grep_opts="-i"


"-------------------------------------------------------------------------------
" Default Mappings
"-------------------------------------------------------------------------------
if !exists('g:use_default_all_filter_mappings') || (g:use_default_all_filter_mappings == 1)
    " Interactive filter
    nnoremap <silent> <Leader>af  :call NewAllCmd(input("Search for: "), "egrep")<CR>
    nnoremap <silent> <Leader>aaf :call NewAllCmd(input("Search for: "), "egrep", 'a')<CR>
    " Last search term filter
    nnoremap <silent> <Leader>al  :exec "All" @/<CR>
    nnoremap <silent> <Leader>aal :exec "AllAdd" @/<CR>
    " Sequence filter: extract sequence from current line and show related
    " events
    nnoremap <silent> <Leader>as  :exec "EAll" GetKey("seq=")."\\\\b"<CR>
    nnoremap <silent> <Leader>aas :exec "EAllAdd" GetKey("seq=")."\\\\b"<CR>
    " Super filter: extracts address from current line and shows all sequences
    " operating on the same address, plus any errors
    nnoremap <silent> <Leader>aS  :call GetEverything(GetKey("seq="))<CR>
    nnoremap <silent> <Leader>aaS :call GetEverything(GetKey("seq="), 'a')<CR>
    " Parent sequence filter: extract parent sequence from current line, then
    " show all parent and child events
    nnoremap <silent> <Leader>ap  :exec "EAll" GetKey("Pseq=")[1:]."\\\\b"<CR>
    nnoremap <silent> <Leader>aap :exec "EAllAdd" GetKey("Pseq=")[1:]."\\\\b"<CR>
    " Pipe pass filter: show pipe passes for the same chip/slice/pipe
    nnoremap <silent> <Leader>aP  :exec "EAll" GetFields(2,4," ")<CR>
    nnoremap <silent> <Leader>aaP :exec "EAllAdd" GetFields(2,4," ")<CR>
    " Address filter: extracts address from current line and shows all events
    " with the same address
    nnoremap <silent> <Leader>aa  :exec "All" GetKey("Adr=")[4:14]<CR>
    nnoremap <silent> <Leader>aaa :exec "AllAdd" GetKey("Adr=")[4:14]<CR>
    " CC Address filter
    nnoremap <silent> <Leader>ac  :exec "All" GetKey("Adr=")[-6:-1]<CR>
    nnoremap <silent> <Leader>aac :exec "AllAdd" GetKey("Adr=")[-6:-1]<CR>
    " Error filter
    nnoremap <silent> <Leader>ae  :exec "All error"<CR>
    nnoremap <silent> <Leader>aae :exec "AllAdd error"<CR>

    " Hide (d)data lines
    nnoremap <silent> <Leader>hd :call HideLines("Data=")<CR>
    " Hide (p)resp lines
    nnoremap <silent> <Leader>hp :call HideLines("PRsp=")<CR>
    " Hide (c)resp lines
    nnoremap <silent> <Leader>hc :call HideLines("CRsp=")<CR>
    " Hide (f)dk lines
    nnoremap <silent> <Leader>hf :call HideLines("\(FRsp\|DRsp\|KRsp\|RRsp\)=")<CR>

    " ------------------------------------------------
    " Convenient non-standard maps
    " ------------------------------------------------
    " Hide all except Pipe Passes
    nnoremap <silent> <Leader>pp :call ShowLines(" C[34] Md=")<CR>
endif


let s:plugin_path = escape(expand('<sfile>:p:h'), '\')
exe 'pyfile ' . s:plugin_path . '/all_filter.py'


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


function! GetEverything(search, ...)
python <<PYTHON
e = vim.eval
flags = ''
if int(e("a:0")) > 0:
    flags = e("a:1")
add_to_last = 'a' in flags
search = e("a:search")
everything = get_everything_re(search)
title = "Everything:%s" % search
new_search_buffer(everything, "egrep", add_to_last=add_to_last, title=title)
PYTHON
endfunction


function! NewAllBuffer(search, grep_cmd, ...)
python <<PYTHON
e = vim.eval
flags = ''
if int(e("a:0")) > 0:
    flags = e("a:1")
add_to_last = 'a' in flags
new_search_buffer(e("a:search"), e("a:grep_cmd"), add_to_last=add_to_last)
PYTHON
endfunction


function! HideLines(pattern)
    exec "g/".a:pattern."/d"
endfunction


function! ShowLines(pattern)
    exec "g!/".a:pattern."/d"
endfunction
