# Exporta los datos de las páginas «Las encuestadoras» (web/datos/casas.json) y «Elige tus supuestos»
# (web/datos/supuestos.json). Solo lee salidas ya calculadas por 02, 03 y 09: no estima nada.
# Uso (desde la raíz del proyecto):  Rscript R/07b_exportar_extra.R
suppressPackageStartupMessages({ library(data.table); library(jsonlite) })
CORTE <- Sys.getenv("CORTE", "2026-11-08")
GENERADO <- format(Sys.time(), "%Y-%m-%d %H:%M")
LIBRES <- c("SW", "CIS_M3")                       # fuera de la restricción «media de las privadas = 0» (R/02)
P4 <- c("PP", "PSOE", "VOX", "FA")

e <- fread("datos/encuestas.csv", encoding = "UTF-8", colClasses = list(character = c("inicio", "fin")))
h <- fread("salidas/efectos_casa.csv")

# ------------------------------------------------------------------ nombres para la web
NOMBRE_CASA <- c(AteneoDato = "Ateneo del Dato", SigmaDos = "Sigma Dos", Winston = "Winston", Data10 = "Data10",
  EMAnalytics = "EM-Analytics", SocioMetrica = "SocioMétrica", NCReport = "NC Report", DYM = "DYM", IMOP = "IMOP",
  `40dB` = "40dB", GAD3 = "GAD3", Hamalgama = "Hamalgama Métrica", InvyMark = "InvyMark", TargetPoint = "Target Point",
  MoreInCommon = "More in Common", Sondaxe = "Sondaxe", CelesteTel = "Celeste-Tel", SW = "SW Demoscopia",
  CIS_M3 = "CIS (reestimación propia)")
CLIENTE <- c(`El Pais-SER` = "El País-SER", `El Espanol` = "El Español", Articulo14 = "Artículo14", Vozpopuli = "Vozpópuli",
  `La Razon` = "La Razón", Electomania = "Electomanía", `ABC (Vocento)` = "ABC", propia = "publicación propia",
  `La Septima` = "La Séptima", `CIS 3582 reestimado` = "CIS, estudio 3582 (microdatos)")
MODO <- c(tel = "telefónica", online = "por internet", mixto = "mixta (combina varios modos)", IVR = "llamadas automáticas (IVR)")
# Enlaces conocidos (los mismos que cita la metodología). Si encuestas.csv trae una columna `url`, manda esa.
URL_FUENTE <- list(c("Dem[oó]crata", "https://www.democrata.es/elecciones-generales-espana/herramientas/encuestas"),
                   c("MiC", "https://moreincommon.es/pulso-electoral.html"),
                   c("reestimación propia", "metodologia.html"))
fuente_txt <- function(x) { x <- gsub("Democrata", "Demócrata", x); gsub("Electografica", "Electográfica", x) }
fuente_url <- function(f, u = NA_character_) {
  if (!is.na(u) && nzchar(u)) return(u)
  for (m in URL_FUENTE) if (grepl(m[1], f)) return(m[2])
  NA_character_
}
renombra <- function(x, mapa) ifelse(x %in% names(mapa), mapa[x], x)
num <- function(x) if (is.na(x)) NULL else round(x, 2)

faltan <- setdiff(unique(e$casa), names(NOMBRE_CASA))
if (length(faltan)) { warning("Casas sin nombre legible en NOMBRE_CASA (se usa el código): ", paste(faltan, collapse = ", "))
  NOMBRE_CASA <- c(NOMBRE_CASA, setNames(faltan, faltan)) }
stopifnot(setequal(unique(e$casa), unique(h$casa)))
if (!"url" %in% names(e)) e[, url := NA_character_]
setorder(e, casa, fin, inicio)

# ------------------------------------------------------------------ casas.json
casas <- lapply(unique(e$casa), \(cs) {
  x <- e[casa == cs]; u <- x[.N]; hc <- h[casa == cs]
  modos <- unique(x$modo[!is.na(x$modo) & nzchar(x$modo)])
  list(
    id = cs, nombre = NOMBRE_CASA[[cs]], libre = cs %in% LIBRES,
    clientes = as.list(unique(renombra(x$cliente, CLIENTE))),
    modo = if (length(modos)) paste(renombra(modos, MODO), collapse = "; ") else NULL,
    entregas = lapply(seq_len(nrow(x)), \(i) list(x$inicio[i], x$fin[i], x$n[i])),     # [inicio, fin, muestra]
    ultima = c(list(inicio = u$inicio, fin = u$fin, n = u$n),
               setNames(lapply(P4, \(p) num(u[[p]])), P4),
               list(fuente = fuente_txt(u$fuente), url = fuente_url(u$fuente, u$url))),
    efecto = setNames(lapply(P4, \(p) { r <- hc[partido == p]; round(c(r$efecto, r$lo, r$hi), 2) }), P4)  # [mediana, p05, p95]
  )
})
casas <- casas[order(sapply(casas, `[[`, "libre"), tolower(sapply(casas, `[[`, "nombre")))]
casas_json <- list(meta = list(corte = CORTE, generado = GENERADO, privadas = sum(!sapply(casas, `[[`, "libre"))),
                   casas = casas)

# ------------------------------------------------------------------ supuestos.json
t <- fread("salidas/escanos_escenarios.csv")
NSIM <- if (file.exists("salidas/escanos_central_draws.rds")) nrow(readRDS("salidas/escanos_central_draws.rds")) else
  as.integer(Sys.getenv("NSIM", "4000"))
esc <- lapply(split(t, t$escenario), \(x) setNames(lapply(seq_len(nrow(x)), \(i) list(
  PP = x$PP[i], PSOE = x$PSOE[i], VOX = x$VOX[i], FA = x$FA[i],
  mayoria = round(x$`P(PP+VOX>=176)`[i], 3), psoe_primero = round(x$`P(PSOE>PP esc.)`[i], 3),
  p05 = x$`PP+VOX p05`[i], p95 = x$`PP+VOX p95`[i])), x$swing))

# Error de la media en el 23J (media − resultado), el que aplica el escenario B (R/03 lo toma de R/09)
bt <- fread("salidas/backtest.csv")[eleccion == "23J 2023"]
err23 <- setNames(as.list(round(-bt$error, 1)), bt$partido)

# Desviación de cada encuesta ancla respecto a la tendencia en sus fechas de campo (la que trasladan C, D, D2, E y F;
# misma regla que R/03: última fila de cada casa, punto medio del campo redondeado)
enc <- rbind(e[, !"url"], fread("datos/anclas_microdatos.csv", encoding = "UTF-8",
             colClasses = list(character = c("inicio", "fin")))[casa != "CIS_M3"], fill = TRUE)
enc[, medio := as.Date(inicio) + round((as.Date(fin) - as.Date(inicio)) / 2)]
serie <- fread("salidas/agregador_serie.csv"); serie[, fecha := as.Date(fecha)]
desv <- function(cs) { ec <- enc[casa == cs][.N]; mt <- serie[fecha == ec$medio, setNames(med, partido)]
  sapply(P4, \(p) ec[[p]] - mt[[p]]) }
ANCLAS <- list(C_ancla_CIS_M3 = "CIS_M3", D_ancla_MiC = "MoreInCommon", D2_ancla_MiC_M3 = "MiC_M3", E_ancla_SW = "SW",
               F_ancla_microdatos = c("CIS_M3", "MiC_M3"))
anclas <- lapply(ANCLAS, \(cs) {
  d <- Reduce(`+`, lapply(cs, desv)) / length(cs)
  c(as.list(round(d, 1)), list(campo = lapply(cs, \(z) { ec <- enc[casa == z][.N]; c(ec$inicio, ec$fin) })))
})

supuestos_json <- list(meta = list(corte = CORTE, generado = GENERADO, simulaciones = NSIM, mayoria = 176),
                       error_23J = err23, anclas = anclas, escenarios = esc)

dir.create("web/datos", recursive = TRUE, showWarnings = FALSE)
write_json(casas_json, "web/datos/casas.json", auto_unbox = TRUE, digits = NA, na = "null", null = "null")
write_json(supuestos_json, "web/datos/supuestos.json", auto_unbox = TRUE, digits = NA, na = "null", null = "null")
for (f in c("web/datos/casas.json", "web/datos/supuestos.json")) cat(f, ":", round(file.size(f) / 1024, 1), "KB\n")
