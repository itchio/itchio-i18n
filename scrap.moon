
import P, R, S, V, C from require "lpeg"

cont = R("\128\191")
multibyte_character =  R("\194\223") * cont +
  R("\224\239") * cont * cont +
  R("\240\244") * cont * cont * cont

-- whitespace characters that are not regular spaces
invalid_whitespace = S("\13\11\12\9") +
  P("\239\187\191") +
  P("\194") * S("\133\160") +
  P("\225") * (P("\154\128") + P("\160\142")) +
  P("\226") * (P("\128") * S("\131\135\139\128\132\136\140\175\129\133\168\141\130\134\169\138\137") + P("\129") * S("\159\160")) +
  P("\227\128\128")

valid_character = (R("\032\126") + multibyte_character) - invalid_whitespace

has_invalid_character = P {
  (P(-1) / -> false) + valid_character * V(1) + C(P(1))
}

print has_invalid_character\match "hello world!"
