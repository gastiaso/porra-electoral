# Comprobaciones de salida que deben pasar antes de publicar. actualizar.R las ejecuta al final y, si alguna falla,
# devuelve la web a la versión anterior.
# Uso (desde la raíz del proyecto):  Rscript R/pruebas.R      (con CORTE=AAAA-MM-DD comprueba además la fecha de corte)
suppressPackageStartupMessages({ library(data.table); library(jsonlite) })

PARTIDOS <- c("PP", "PSOE", "VOX", "FA", "POD", "SALF")
RANGO <- list(PP = c(20, 45), PSOE = c(15, 40), VOX = c(8, 30), FA = c(1, 15), POD = c(0, 8), SALF = c(0, 8))
OFICIAL_23J <- c(PP = 137, PSOE = 121, VOX = 33, SUMAR = 31, ERC = 7, JUNTS = 7, BILDU = 6, PNV = 5, BNG = 1, CC = 1, UPN = 1)
RHAT_MAX <- 1.05

`%||%` <- function(a, b) if (is.null(a)) b else a
fallos <- character()
prueba <- function(nombre, f) {                 # f: función sin argumentos que devuelve res(...)
  r <- tryCatch(f(), error = function(e) list(ok = FALSE, detalle = paste("no se ha podido comprobar:", conditionMessage(e))))
  cat(sprintf("  %-5s %s%s\n", if (r$ok) "ok" else "FALLO", nombre, if (nzchar(r$detalle)) paste0(": ", r$detalle) else ""))
  if (!r$ok) fallos <<- c(fallos, nombre)
}
res <- function(problemas, si_ok = "") {       # problemas: vector de textos; vacío = bien
  problemas <- problemas[nzchar(problemas)]
  list(ok = !length(problemas), detalle = if (length(problemas)) paste(head(problemas, 6), collapse = "; ") else si_ok)
}
leer_rds <- function(f) { if (!file.exists(f)) stop("falta ", f); readRDS(f) }

# ------------------------------------------------------------------ lo que lee la web (web/js/comun.js)
js <- if (file.exists("web/js/comun.js")) paste(readLines("web/js/comun.js", encoding = "UTF-8", warn = FALSE), collapse = "\n") else ""
de_js <- function(patron, defecto) {
  m <- regmatches(js, regexec(patron, js))[[1]]
  if (length(m) < 2) return(defecto)
  x <- regmatches(m[2], gregexpr("'[^']+'", m[2]))[[1]]
  if (length(x)) gsub("'", "", x) else defecto
}
ORDEN <- de_js("export const ORDEN = \\[([^]]*)\\]",
               c("PP", "PSOE", "VOX", "FA", "ERC", "BILDU", "PNV", "JUNTS", "AC", "BNG", "CC", "UPN", "POD", "SALF"))
bloque <- regmatches(js, regexec("export const ESCENARIOS = \\[(.*?)\\];", js))[[1]][2]
ids <- if (is.na(bloque)) character() else regmatches(bloque, gregexpr("id: '[^']+'", bloque))[[1]]
ESCENARIOS <- if (length(ids)) sub("id: '([^']+)'", "\\1", ids) else c("A_media_privadas", "B_correccion_23J", "F_ancla_microdatos", "E_ancla_SW")
CLAVE_WEB <- de_js("D\\.media\\?*\\.\\[('[^']+')\\]", NA_character_)   # clave fija, si la web la escribe así
MESES <- c("ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic")
etiqueta <- function(f) { f <- as.Date(f); paste0(as.integer(format(f, "%d")), "-", MESES[as.integer(format(f, "%m"))]) }

cat("Pruebas de publicación\n")
m <- if (file.exists("web/datos/modelo.json")) fromJSON("web/datos/modelo.json", simplifyVector = TRUE) else NULL
porra <- fromJSON("datos/porra.json", simplifyVector = TRUE)
enc <- fread("datos/encuestas.csv", encoding = "UTF-8", colClasses = list(character = c("inicio", "fin")))
pub <- enc[casa != "CIS_M3"]                    # R/07 deja fuera la reestimación propia del CIS
# la media a la fecha de corte: la clave que no es «29-nov» (la web toma la primera que encuentra)
CLAVES <- setdiff(names(m$media), "29-nov")
CLAVE <- if (!is.na(CLAVE_WEB)) CLAVE_WEB else CLAVES[1]

# ------------------------------------------------------------------ agregador
prueba(sprintf("Convergencia del agregador (R-hat < %.2f)", RHAT_MAX), \() {
  ag <- leer_rds("salidas/agregador_draws.rds")
  res(if (!is.finite(ag$rhat) || ag$rhat >= RHAT_MAX) sprintf("R-hat máximo %.3f", ag$rhat), sprintf("R-hat máximo %.3f", ag$rhat))
})

# ------------------------------------------------------------------ escaños
prueba("Cada simulación reparte 350 escaños", \() {
  E <- leer_rds("salidas/escanos_central_draws.rds"); s <- rowSums(E)
  res(if (any(s != 350)) sprintf("%d de %d simulaciones no suman 350 (p. ej. %d)", sum(s != 350), nrow(E), s[s != 350][1]),
      sprintf("%d simulaciones", nrow(E)))
})
prueba("Cada circunscripción reparte sus escaños", \() {
  A <- leer_rds("salidas/escanos_provincia_central.rds")
  b <- fread("datos/base_23J.csv", encoding = "UTF-8")
  esperado <- setNames(b$escanos, b$district)[dimnames(A)[[2]]]
  S <- apply(A, c(1, 2), sum)
  mal <- which(colSums(sweep(S, 2, esperado) != 0) > 0)
  res(c(if (anyNA(esperado)) "provincias que no están en base_23J.csv",
        if (length(mal)) paste("no cuadran:", paste(names(mal), collapse = ", "))), sprintf("%d circunscripciones", length(esperado)))
})
prueba("D'Hondt reproduce el resultado oficial del 23J", \() {
  def <- Filter(\(x) is.call(x) && identical(x[[1]], as.name("<-")) && identical(x[[2]], as.name("dhondt")),
                as.list(parse("R/03_escanos.R", keep.source = FALSE)))
  if (!length(def)) stop("no encuentro la función dhondt en R/03_escanos.R")
  en <- new.env(); eval(def[[1]], en)
  b <- fread("datos/base_23J.csv", encoding = "UTF-8")
  P23 <- c(names(OFICIAL_23J), "OTROS", "BLANCO")
  S <- as.matrix(b[, paste0("s_", P23), with = FALSE]); colnames(S) <- P23
  r <- Reduce(`+`, lapply(seq_len(nrow(b)), \(i) en$dhondt(S[i, ], b$escanos_2023[i])))
  dif <- names(OFICIAL_23J)[r[names(OFICIAL_23J)] != OFICIAL_23J]
  res(c(if (length(dif)) paste(sprintf("%s %d (oficial %d)", dif, r[dif], OFICIAL_23J[dif]), collapse = ", "),
        if (sum(r) != 350) sprintf("suma %d", sum(r))), "PP 137, PSOE 121, Vox 33, Sumar 31 y el resto")
})

# ------------------------------------------------------------------ voto
prueba("Medias de voto razonables", \() {
  if (is.null(m)) stop("falta web/datos/modelo.json")
  pr <- character()
  for (mo in c(CLAVE, "29-nov")) {
    x <- m$media[[mo]]; if (is.null(x)) { pr <- c(pr, sprintf("falta la media «%s»", mo)); next }
    for (p in PARTIDOS) {
      v <- x[[p]]
      if (is.null(v$mediana)) { pr <- c(pr, sprintf("%s sin %s", mo, p)); next }
      if (v$mediana < RANGO[[p]][1] || v$mediana > RANGO[[p]][2]) pr <- c(pr, sprintf("%s %s = %.1f fuera de %g-%g", mo, p, v$mediana, RANGO[[p]][1], RANGO[[p]][2]))
      if (!(v$p05 <= v$mediana && v$mediana <= v$p95)) pr <- c(pr, sprintf("%s %s: intervalo incoherente", mo, p))
    }
    s <- sum(sapply(PARTIDOS, \(p) x[[p]]$mediana %||% 0))
    if (s < 80 || s > 100) pr <- c(pr, sprintf("%s: los seis suman %.1f", mo, s))
  }
  res(pr, sprintf("media a %s: PP %.1f, PSOE %.1f, Vox %.1f", m$meta$corte, m$media[[CLAVE]]$PP$mediana,
                  m$media[[CLAVE]]$PSOE$mediana, m$media[[CLAVE]]$VOX$mediana))
})
prueba("La media no se aleja de la media simple de las privadas (21 días)", \() {
  corte <- as.Date(m$meta$corte)
  r <- pub[casa != "SW" & as.Date(fin) > corte - 21 & as.Date(fin) <= corte]
  if (nrow(r) < 4) return(res(character(), sprintf("solo %d encuestas en esos días: no se compara", nrow(r))))
  simple <- colMeans(r[, ..PARTIDOS], na.rm = TRUE)
  tol <- c(PP = 2.5, PSOE = 2.5, VOX = 2.5, FA = 2, POD = 1.5, SALF = 1.5)
  d <- sapply(PARTIDOS, \(p) m$media[[CLAVE]][[p]]$mediana - simple[[p]])
  res(sprintf("%s %+.1f puntos", PARTIDOS, d)[abs(d) > tol],
      sprintf("%d encuestas; mayor diferencia %s %+.1f", nrow(r), PARTIDOS[which.max(abs(d))], d[which.max(abs(d))]))
})

# ------------------------------------------------------------------ modelo.json
prueba("modelo.json corresponde a datos/encuestas.csv y al corte", \() {
  if (is.null(m)) stop("falta web/datos/modelo.json")
  k1 <- paste(pub$casa, pub$inicio, pub$fin); k2 <- paste(m$encuestas$casa, m$encuestas$inicio, m$encuestas$fin)
  corte_env <- Sys.getenv("CORTE", "")
  ag <- if (file.exists("salidas/agregador_draws.rds")) readRDS("salidas/agregador_draws.rds") else list()
  res(c(if (m$meta$encuestas != nrow(pub)) sprintf("dice %d encuestas y el CSV tiene %d", m$meta$encuestas, nrow(pub)),
        if (!setequal(k1, k2)) sprintf("encuestas distintas (%s): vuelve a ejecutar el modelo",
                                       paste(head(c(setdiff(k1, k2), setdiff(k2, k1)), 3), collapse = "; ")),
        if (max(as.Date(enc$fin)) > as.Date(m$meta$corte)) sprintf("hay encuestas con campo posterior al corte (%s)", m$meta$corte),
        if (nzchar(corte_env) && corte_env != m$meta$corte) sprintf("corte %s y CORTE=%s", m$meta$corte, corte_env),
        if (!is.null(ag$corte) && as.character(ag$corte) != m$meta$corte) sprintf("el agregador se calculó con corte %s", ag$corte),
        if (length(CLAVE) && grepl("^\\d{1,2}-[a-z]{3}$", CLAVE) && CLAVE != etiqueta(m$meta$corte))
          sprintf("la media del agregador es del %s y el corte del JSON, %s: ejecuta R/02 y R/07 con el mismo CORTE", CLAVE, m$meta$corte)),
      sprintf("%d encuestas, corte %s", m$meta$encuestas, m$meta$corte))
})
prueba("modelo.json trae lo que usa la portada", \() {
  pr <- character()
  falta <- function(x, que) if (is.null(x) || (is.atomic(x) && anyNA(x))) pr <<- c(pr, que)
  for (f in c("corte", "encuestas", "casas", "simulaciones", "eleccion")) falta(m$meta[[f]], paste0("meta.", f))
  if (is.na(CLAVE_WEB) && length(CLAVES) != 1) pr <- c(pr, sprintf("media debe traer una sola fecha además de «29-nov» (trae: %s)", paste(CLAVES, collapse = ", ")))
  for (k in ORDEN) { falta(m$nombres[[k]], paste0("nombres.", k))
    for (f in c("mediana", "p05", "p95")) falta(m$escanos[[k]][[f]], sprintf("escanos.%s.%s", k, f)) }
  for (k in PARTIDOS) falta(m$media[[CLAVE]][[k]]$mediana, sprintf("media['%s'].%s", CLAVE, k))
  for (f in c("mediana", "p05", "p95", "p_mayoria")) falta(m$bloque_pp_vox[[f]], paste0("bloque_pp_vox.", f))
  s <- as.data.table(m$serie)
  if (!all(c("fecha", "partido", "med", "lo", "hi") %in% names(s))) pr <- c(pr, "serie sin fecha/partido/med/lo/hi") else {
    if (!setequal(unique(s$partido), PARTIDOS)) pr <- c(pr, "serie sin los seis partidos")
    if (max(s$fecha) != "2026-11-29") pr <- c(pr, "la serie no llega al 29-nov")
    if (!m$meta$corte %in% s$fecha) pr <- c(pr, "la fecha de corte no está en la serie")
  }
  ce <- c("casa", "cliente", "inicio", "fin", "n", PARTIDOS)
  if (!all(ce %in% names(m$encuestas))) pr <- c(pr, paste("encuestas sin", paste(setdiff(ce, names(m$encuestas)), collapse = ", ")))
  if (!all(c("n", ORDEN) %in% names(m$tiradas)) || !NROW(m$tiradas)) {
    pr <- c(pr, "tiradas incompletas")
  } else if (any(rowSums(as.matrix(m$tiradas[, ORDEN])) != 350)) pr <- c(pr, "hay tiradas que no suman 350")
  es <- as.data.table(m$escenarios)
  for (id in ESCENARIOS) {
    x <- es[escenario == id & swing == "mixto"]
    if (nrow(x) != 1) { pr <- c(pr, paste("falta el escenario", id)); next }
    if (anyNA(x[, .(PP, PSOE, VOX, p_mayoria, p_psoe_primero)])) {
      pr <- c(pr, paste("escenario incompleto:", id))
    } else if (any(x[, c(p_mayoria, p_psoe_primero)] < 0 | x[, c(p_mayoria, p_psoe_primero)] > 1)) pr <- c(pr, paste("probabilidad fuera de 0-1:", id))
  }
  if (NROW(m$en_juego) < 8 || !all(c("provincia", "escanos", "p1", "q1", "p2", "q2") %in% names(m$en_juego))) pr <- c(pr, "en_juego: menos de 8 filas o campos")
  if (!file.exists("web/datos/encuestas.csv") || nrow(fread("web/datos/encuestas.csv")) != m$meta$encuestas) pr <- c(pr, "web/datos/encuestas.csv no cuadra")
  res(pr, sprintf("%d partidos, %d escenarios", length(ORDEN), length(ESCENARIOS)))
})
prueba("modelo.json trae lo que usa la porra (porra_media)", \() {
  pm <- m$porra_media; pr <- character()
  if (is.null(pm)) stop("falta porra_media")
  f <- as.data.table(pm$filas)
  if (nrow(f) != nrow(porra$filas) || !all(f$id == porra$filas$id)) {
    pr <- c(pr, "las filas no coinciden con datos/porra.json")
  } else if (any(abs(f$p1 + f$pX + f$p2 - 1) > 0.002)) pr <- c(pr, "1-X-2 que no suman 1")
  if (!setequal(names(pm$pleno), porra$pleno$opciones$id)) {
    pr <- c(pr, "el pleno no trae las opciones de datos/porra.json")
  } else if (abs(sum(unlist(pm$pleno)) - 1) > 0.002) pr <- c(pr, "el pleno no suma 1")
  esc <- unlist(pm$escanos)
  if (!all(porra$escanos$partidos %in% names(esc))) pr <- c(pr, paste("escanos sin", paste(setdiff(porra$escanos$partidos, names(esc)), collapse = ", ")))
  if (sum(esc) != 350) pr <- c(pr, sprintf("porra_media$escanos suma %d", sum(esc)))
  if (any(esc < 0 | esc != round(esc))) pr <- c(pr, "escaños negativos o con decimales")
  res(pr, sprintf("%d filas, pleno y reparto de 350", nrow(f)))
})
for (fj in c("web/datos/casas.json", "web/datos/supuestos.json")) if (file.exists(fj))
  prueba(sprintf("%s con el mismo corte", basename(fj)), \() {
    x <- fromJSON(fj, simplifyVector = FALSE)
    res(if (!identical(x$meta$corte, m$meta$corte)) sprintf("corte %s y modelo.json %s", x$meta$corte, m$meta$corte))
  })

if (length(fallos)) {
  stop(sprintf("%d prueba%s fallida%s: no publiques esta versión.", length(fallos), if (length(fallos) > 1) "s" else "",
               if (length(fallos) > 1) "s" else ""), call. = FALSE)
} else cat("  Todas las pruebas pasan.\n")
