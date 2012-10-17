
command! -nargs=+ All :call NewAllCmd("<args>", "grep")
command! -nargs=+ EAll :call NewAllCmd("<args>", "egrep")

function! GetSeqNum()
python <<PYTHON
import vim
toks = vim.current.line.split()
seq = [x for x in toks if x.startswith("seq=")]
if seq:
    vim.command("return '%s '"%seq[0])
else:
    vim.command("return 'seq=unknown'")
PYTHON
endfunction

function! GetCmdAdr()
python <<PYTHON
import vim
toks = vim.current.line.split()
adr = [x[4:15] for x in toks if x.startswith("Adr=")]
if adr:
    vim.command("return '%s'"%adr[0])
else:
    vim.command("return 'Adr=unknown'")
PYTHON
endfunction

function! GetEverything(search)
python <<PYTHON
import vim
import re
import sys
def uniqify(seq):
  seen = {}
  ret = []
  for s in seq:
    if s not in seen:
      ret.append(s)
    seen[s] = 1 
  return ret
search = vim.eval("a:search")
trace = vim.current.buffer[:]
# Find all lines containing search string
seq = [t for t in trace if t.find(search) > 0]
# Find all addresses used by seqNum
allAdrs = [a[4:15] for a in " ".join(seq).split() if a.startswith("Adr=")]
allAdrs = uniqify(map(lambda x: x.strip(), allAdrs))
# Find all the sequences operating on all addresses in adr
reAdrs = re.compile("|".join(allAdrs), re.IGNORECASE)
adrMatches = [t for t in trace if reAdrs.search(t) != None]
# Stick a space on the end of each sequence number
reSeqNum = re.compile(r"seq=[0-9]+", re.IGNORECASE)
allSeqs = map(lambda x: x+" ", reSeqNum.findall(" ".join(adrMatches)))
radness="ERROR|" + "|".join(uniqify(allSeqs))
if radness:
  vim.command("return '%s'"%radness)
else:
  vim.command("return 'Something.Awful.Just.Happened.In.GetEverything'")
PYTHON
endfunction

function! GetField(num)
    " return *num*-th whitespace-delimited field on the current line
    let toks = split(getline('.'), ':')
    if len(toks) >= a:num
        return toks[a:num-1]
    endif
    return ''
endfunction

function! NewAllCmd(search, grep_cmd)
python <<PYTHON
import vim
search = vim.eval("a:search")
grep_cmd = vim.eval("a:grep_cmd")
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
vim.command("silent r ! %s %r %s"%(grep_cmd, search, tempname))
# hack to check if any lines found by cursor position
row, col = vim.current.window.cursor
if (row, col) == (1, 0):
    vim.command("bd")
    print "Pattern %r not found!" % search
else:
    vim.command("let g:last_all_buf=%s"%vim.current.buffer.number)
    # set filetype
    vim.command("setf "+ftype)
    # change name of buffer to search pattern
    search = vim.eval("escape(%r,%r)"%(search,"|"))
    vim.command("file "+"".join(search.split()))
    # hack to make buffer show up in minibufexplorer
    vim.command("new")
    vim.command("bd")
    # hack to delete first line (blank), go to bottom, and bottom align
    vim.command("normal ggddGzb")
    vim.command('map <buffer> <C-q> :let @z=GetField(1)\|b %s\|exec "normal ".getreg("z")."Gzz"<CR>'%bnum)
PYTHON
endfunction

