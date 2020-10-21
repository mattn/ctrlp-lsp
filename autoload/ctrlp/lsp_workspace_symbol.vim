if exists('g:ctrlp_lsp_workspace_symbol_loaded')
  finish
endif
let g:ctrlp_lsp_workspace_symbol_loaded = 1

call add(g:ctrlp_ext_vars, {
  \ 'init': 'ctrlp#lsp_workspace_symbol#init(s:crbufnr)',
  \ 'search': 'ctrlp#lsp_workspace_symbol#search()',
  \ 'accept': 'ctrlp#lsp_workspace_symbol#accept',
  \ 'exit': 'ctrlp#lsp_workspace_symbol#exit()',
  \ 'lname': 'LspWorkspaceSymbol',
  \ 'sname': 'LspWrkSym',
  \ 'type': 'file',
  \ 'sort': 0,
  \ })

let s:id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)
function! ctrlp#lsp_workspace_symbol#id() abort
  return s:id
endfunction

let s:last_input = '_'
let s:reqid = 0
let s:items = []
let s:list = []

function! ctrlp#lsp_workspace_symbol#init(bufnr) abort
  if !exists('s:bufnr') | let s:bufnr = a:bufnr | endif
  call ctrlp#lsp_workspace_symbol#search()
  return s:items
endfunction

function! s:clear_timer() abort
  if exists('s:search_timer')
    call timer_stop(s:search_timer)
    unlet s:search_timer
  endif
endfunction

function! ctrlp#lsp_workspace_symbol#search() abort
  call s:clear_timer()
  let s:search_timer = timer_start(250, function('s:search'), {'repeat': 0})
endfunction

function! s:search(...) abort
  let l:input = ctrlp#input()
  if l:input ==# s:last_input
    return
  endif
  let s:last_input = l:input

  let s:reqid += 1
  let l:servers = filter(lsp#get_whitelisted_servers(s:bufnr), 'lsp#capabilities#has_workspace_symbol_provider(v:val)')
  let l:ctx = { 'reqid': s:reqid }
  for l:server in l:servers
    call lsp#send_request(l:server, {
      \ 'bufnr': s:bufnr,
      \ 'method': 'workspace/symbol',
      \ 'params': {
      \   'query': l:input,
      \ },
      \ 'on_notification': function('s:handle_results', [l:server, l:ctx]),
      \ })
  endfor
endfunction

function! s:handle_results(server, ctx, data) abort
  if !exists('s:bufnr')
    return
  endif
  if a:ctx['reqid'] != s:reqid
    return
  endif
  if lsp#client#is_error(a:data['response'])
    call lsp#utils#error('Failed to retrieve wokspace symbols.')
    return
  endif
  if len(s:items) > 0
    call remove(s:items, 0, len(s:items) - 1)
  endif
  let s:list = lsp#ui#vim#utils#symbols_to_loc_list(a:server, a:data)
  for l:item in s:list
    call add(s:items, l:item['text'])
  endfor
  call sort(s:items)
  call ctrlp#setlines()
  call ctrlp#update(0)
endfunction

function! ctrlp#lsp_workspace_symbol#exit() abort
  let s:last_input = '_'
  let s:list = []
  if len(s:items) > 0
    call remove(s:items, 0, len(s:items) - 1)
  endif
  unlet! s:bufnr
  call s:clear_timer()
endfunction

function! ctrlp#lsp_workspace_symbol#accept(mode, str) abort
  let l:founds = filter(s:list, {k, v -> v['text'] == a:str})
  call ctrlp#exit()
  redraw
  if len(l:founds) == 0
    return
  endif
  let l:found = l:founds[0]
  exe 'keepalt' 'edit' fnameescape(l:found['filename'])
  call cursor(l:found['lnum'], l:found['col'])
  if foldlevel(l:found['lnum']) > 0
    normal! zv
  endif
  normal! zz
endfunction
