
" pressing ctrl-j with a visual selection will push it through translation
" tool and replace selection with the output

function ItchTranslate()
	return Chomp(system("insert_string --from " . shellescape(expand("%")) . " " . shellescape(getreg(""))))
endfunction

vmap <c-j> x"=ItchTranslate()<cr>p

