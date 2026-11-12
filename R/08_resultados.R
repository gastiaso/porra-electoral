# Resultados del 29N para comprobar las quinielas.
# Entrada: datos/resultados_29N.csv con una fila por circunscripción y candidatura que obtenga escaño:
#   provincia, partido, escanos      (partido con los códigos de la web: PP, PSOE, VOX, FA, POD, SALF, ERC, JUNTS,
#                                     BILDU, PNV, BNG, CC, UPN, AA, OTROS)
#   y, opcionalmente, una fila por circunscripción con partido = "_ESTADO" y escanos = 1 si el escrutinio está cerrado.
# Salida: web/datos/resultados.json (la quiniela lo detecta solo y corrige los boletos).
# Uso: Rscript R/08_resultados.R [provisional|definitivo]
suppressPackageStartupMessages({ library(data.table); library(jsonlite) })
estado <- commandArgs(trailingOnly = TRUE)[1]; if (is.na(estado)) estado <- "provisional"
r <- fread("datos/resultados_29N.csv", encoding = "UTF-8")
b <- fread("datos/base_23J.csv", encoding = "UTF-8")[, .(provincia = district, escanos_prov = escanos)]
r <- r[!is.na(partido) & nzchar(partido) & !is.na(escanos) & partido != "_ESTADO"]   # filas vacías de la plantilla, fuera
stopifnot(all(r$provincia %in% b$provincia))
chk <- merge(r[, .(asignados = sum(escanos)), by = provincia], b, by.x = "provincia", by.y = "provincia", all.y = TRUE)
incompletas <- chk[is.na(asignados) | asignados != escanos_prov]
if (nrow(incompletas)) message("Circunscripciones sin todos sus escaños: ", paste(incompletas$provincia, collapse = ", "))
nac <- r[, .(escanos = sum(escanos)), by = partido]
out <- list(estado = estado, actualizado = format(Sys.time(), "%Y-%m-%d %H:%M"),
            completo = nrow(incompletas) == 0,
            congreso = as.list(setNames(nac$escanos, nac$partido)),
            provincias = lapply(split(r, r$provincia), \(x) as.list(setNames(x$escanos, x$partido))))
write_json(out, "web/datos/resultados.json", auto_unbox = TRUE, pretty = FALSE)
cat("web/datos/resultados.json:", sum(nac$escanos), "escaños asignados;", if (out$completo) "completo" else "INCOMPLETO", "\n")
