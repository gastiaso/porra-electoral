#!/usr/bin/env bash
# Pone en absoluto og:url y og:image (WhatsApp y otras redes no leen rutas relativas en la vista previa).
# Uso, desde la raíz del proyecto, cuando se sepa la dirección pública:
#   bash herramientas/url_publica.sh https://usuario.github.io/porra-electoral
# Se puede repetir con otra dirección: sustituye la anterior.
set -euo pipefail
base="${1:?Falta la dirección pública, p. ej. https://usuario.github.io/porra-electoral}"; base="${base%/}"
for f in web/index.html web/porra.html web/metodologia.html web/preguntas.html docs/plantilla.html; do
  case "$(basename "$f")" in index.html) pag="" ;; porra.html) pag="porra.html" ;; preguntas.html) pag="preguntas.html" ;; *) pag="metodologia.html" ;; esac
  sed -i -E "s#(property=\"og:image\" content=\")[^\"]*(img/og-[a-z]+\.png)#\1$base/\2#; s#(property=\"og:url\" content=\")[^\"]*\"#\1$base/$pag\"#" "$f"
done
grep -h 'og:url\|og:image"' web/index.html web/porra.html
