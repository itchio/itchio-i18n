FROM leafo/lapis-archlinux-itchio:latest
MAINTAINER leaf corcoran <leafot@gmail.com>

WORKDIR /itchio-i18n
ADD . .
ENTRYPOINT ./ci.sh
