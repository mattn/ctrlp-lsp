if exists('g:ctrlp_lsp_document_symbol_loaded')
  finish
endif
let g:ctrlp_lsp_document_symbol_loaded = 1

call add(g:ctrlp_ext_vars, {
  \ 'init': 'ctrlp#lsp_document_symbol#init(s:crbufnr)',
  \ 'search': 'ctrlp#lsp_document_symbol#search()',
  \ 'accept': 'ctrlp#lsp_document_symbol#accept',
  \ 'exit': 'ctrlp#lsp_document_symbol#exit()',
  \ 'lname': 'LspDocumentSymbol',
  \ 'sname': 'LspDocSym',
  \ 'type': 'file',
  \ 'sort': 0,
  \ })

let s:id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)
function! ctrlp#lsp_document_symbol#id() abort
  return s:id
endfunction

let s:last_input = '_'
let s:reqid = 0
let s:items = []
let s:list = []

function! ctrlp#lsp_document_symbol#init(bufnr) abort
  if !exists('s:bufnr') | let s:bufnr = a:bufnr | endif
  call ctrlp#lsp_document_symbol#search()
  return s:items
endfunction

function! ctrlp#lsp_document_symbol#search() abort
  let l:input = ctrlp#input()
  if l:input ==# s:last_input
    return
  endif
  let s:last_input = l:input

  let s:reqid += 1
  let l:servers = filter(lsp#get_whitelisted_servers(s:bufnr), 'lsp#capabilities#has_document_symbol_provider(v:val)')
  let l:ctx = { 'reqid': s:reqid }
  for l:server in l:servers
    call lsp#send_request(l:server, {
      \ 'bufnr': s:bufnr,
      \ 'method': 'textDocument/documentSymbol',
      \ 'params': {
      \   'textDocument': lsp#get_text_document_identifier(s:bufnr),
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

function! ctrlp#lsp_document_symbol#exit() abort
  let s:last_input = '_'
  let s:list = []
  if len(s:items) > 0
    call remove(s:items, 0, len(s:items) - 1)
  endif
  unlet! s:bufnr
endfunction

function! ctrlp#lsp_document_symbol#accept(mode, str) abort
  let l:founds = filter(s:list, {k, v -> v['text'] == a:str})
  call ctrlp#lsp_document_symbol#exit()
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
