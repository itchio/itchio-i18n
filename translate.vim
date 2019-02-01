
" pressing ctrl-j with a visual selection will push it through translation
" tool and replace selection with the output

function ItchTranslate()
	return substitute(system("./insert_string --from " . shellescape(expand("%")) . " " . shellescape(getreg(""))), '\n$', '', '')
endfunction

vnoremap <c-j> x"=ItchTranslate()<cr>P


function ItchTranslateLookup()
	return substitute(system("./select_key"), '\n$', '', '')
endfunction

nnoremap <c-j> "=ItchTranslateLookup()<cr>P
