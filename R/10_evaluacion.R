# Evaluación con los resultados del 29N: qué dijo el modelo y qué pasó.
#
# Compara el resultado con lo último que se publicó antes de la veda:
#   (a) voto estatal: media de encuestas el 29N (mediana e intervalo del 90 % del agregador, con y sin el error común
#       de todas las encuestas) y promedio simple de la última encuesta de cada empresa;
#   (b) escaños: escenario central (mediana e intervalo) y cada escenario; probabilidad que se daba a la mayoría de PP y Vox;
#   (c) circunscripciones: reparto real frente a los repartos simulados y, si hay voto provincial, el último escaño;
#   (d) empresas: error de la última encuesta de cada una en PP, PSOE, Vox y Frente Amplio, por orden alfabético.
#
# USO LA NOCHE DEL 29N (desde la raíz del proyecto)
#   1. Escaños por circunscripción (los mismos que corrigen la porra):
#        cp datos/resultados_29N_plantilla.csv datos/resultados_29N.csv     y rellenar: provincia, partido, escanos
#   2. Voto estatal, en % sobre voto válido (candidaturas + blanco), con dos decimales:
#        cp datos/resultados_29N_votos_plantilla.csv datos/resultados_29N_votos.csv   y rellenar la columna pct
#      - _ESCRUTADO: % escrutado (si es menor que 100, la evaluación sale como provisional).
#      - OTROS: el resto de candidaturas; BLANCO: voto en blanco. Con BLANCO, la suma debe dar 100.
#      - Las listas conjuntas de Frente Amplio y Podemos (C. Valenciana y Canarias) cuentan como FA, igual que en el modelo.
#      - Opcional, para saber quién se llevó el último escaño: filas con ambito = nombre de la circunscripción tal como
#        figura en datos/base_23J.csv (p. ej. «Coruña (A)») y el % de cada candidatura en ella, al menos de todas las que
#        pasan del 3 %. Se comprueba que el reparto D'Hondt de esos porcentajes da los escaños del paso 1.
#   3. LC_ALL=C.UTF-8 Rscript R/08_resultados.R provisional      # porra
#      LC_ALL=C.UTF-8 Rscript R/10_evaluacion.R provisional      # esta evaluación
#      Con el escrutinio general (definitivo): los dos con «definitivo». Si falta escrutinio o hay circunscripciones
#      sin todos sus escaños, la evaluación sigue marcada como provisional aunque se pida «definitivo».
#   Basta con uno de los dos ficheros: sin voto se evalúan los escaños, y sin escaños, el voto.
#
# Salidas: salidas/evaluacion_{voto,escanos,escenarios,provincias,casas}.csv y web/datos/evaluacion.json
#   (web/evaluacion.html lo lee; mientras no existe, la página anuncia que la evaluación se publicará con los resultados).
#
# IMPORTANTE: usa salidas/ tal como están (agregador_draws.rds, escanos_*.csv/rds, ultimo_escano.csv). Deben ser las de
# la última versión publicada antes de la veda: no se debe volver a ejecutar ejecutar.R después del 23 de noviembre.
#
# Variables opcionales (para pruebas): VOTOS, ESCANOS (ficheros de entrada), DESTINO (carpeta de los CSV), JSON (salida).
suppressPackageStartupMessages({ library(data.table); library(jsonlite) })
invisible(Sys.setlocale("LC_ALL", "C.UTF-8"))

estado_pedido <- commandArgs(trailingOnly = TRUE)[1]; if (is.na(estado_pedido)) estado_pedido <- "provisional"
if (!estado_pedido %in% c("provisional", "definitivo")) stop("Uso: Rscript R/10_evaluacion.R [provisional|definitivo]")
F_VOTOS <- Sys.getenv("VOTOS", "datos/resultados_29N_votos.csv")
F_ESCANOS <- Sys.getenv("ESCANOS", "datos/resultados_29N.csv")
DESTINO <- Sys.getenv("DESTINO", "salidas")
F_JSON <- Sys.getenv("JSON", "web/datos/evaluacion.json")

# ------------------------------------------------------------------ supuestos del modelo
EST <- c("PP", "PSOE", "VOX", "FA", "POD", "SALF")                       # partidos del agregador
CUATRO <- c("PP", "PSOE", "VOX", "FA")
SD_SIST <- c(PP = 2.0, PSOE = 2.0, VOX = 1.5, FA = 1.0, POD = 0.7, SALF = 0.7)   # error común: el de R/03_escanos.R
Z90 <- qnorm(0.95)
l03 <- readLines("R/03_escanos.R", encoding = "UTF-8")
if (!any(grepl("c(PP = 2.0, PSOE = 2.0, VOX = 1.5, FA = 1.0, POD = 0.7, SALF = 0.7)", l03, fixed = TRUE)))
  warning("El error común de R/03_escanos.R no coincide con SD_SIST de este script: actualízalo antes de publicar.")
# Partidos que no entran en el agregador: objetivo fijo de R/03 (desviación relativa del 20 %)
eval(parse(text = grep("^REG <- c\\(", l03, value = TRUE)[1]))
SUP <- REG; SD_REL <- setNames(rep(0.2, length(REG)), names(REG))
ESCENARIOS <- c(A_media_privadas = "Si las encuestas aciertan de media",
                B_correccion_23J = "Si fallan como en 2023",
                F_ancla_microdatos = "Si aciertan el CIS y More in Common, recalculados con sus microdatos",
                E_ancla_SW = "Si acierta SW Demoscopia",
                C_ancla_CIS_M3 = "Si acierta el CIS, recalculado con sus microdatos",
                D_ancla_MiC = "Si acierta More in Common (estimación publicada)",
                D2_ancla_MiC_M3 = "Si acierta More in Common, recalculada con sus microdatos")
EN_PORTADA <- c("A_media_privadas", "B_correccion_23J", "F_ancla_microdatos", "E_ancla_SW")   # los de web/js/comun.js

# ------------------------------------------------------------------ salidas del modelo
necesarios <- c("salidas/agregador_draws.rds", "salidas/escanos_central_draws.rds", "salidas/escanos_provincia_central.rds",
                "salidas/escanos_escenarios.csv", "salidas/ultimo_escano.csv")
if (length(f <- necesarios[!file.exists(necesarios)])) stop("Faltan salidas del modelo: ", paste(f, collapse = ", "))
b <- fread("datos/base_23J.csv", encoding = "UTF-8")
ag <- readRDS("salidas/agregador_draws.rds"); D <- ag$d29n
E <- readRDS("salidas/escanos_central_draws.rds")
A <- readRDS("salidas/escanos_provincia_central.rds")                    # [sorteo, circunscripción, partido]
stopifnot(identical(dimnames(A)[[2]], b$district), identical(dimnames(A)[[3]], colnames(E)))
PARTIDOS <- colnames(E)                                                  # 14 candidaturas + OTROS y BLANCO (sin escaños)
TODOS <- setdiff(PARTIDOS, "BLANCO")
ORDEN <- c("PP", "PSOE", "VOX", "FA", "ERC", "BILDU", "PNV", "JUNTS", "BNG", "CC", "UPN", "POD", "SALF")
esc_sc <- fread("salidas/escanos_escenarios.csv")[swing == "mixto"]
ult_esc <- fread("salidas/ultimo_escano.csv", encoding = "UTF-8")
der <- E[, "PP"] + E[, "VOX"]
meta_modelo <- tryCatch(fromJSON("web/datos/modelo.json")$meta, error = function(e) NULL)
modelo_pub <- tryCatch(fromJSON("web/datos/modelo.json"), error = function(e) NULL)
if (!is.null(modelo_pub$bloque_pp_vox) && abs(modelo_pub$bloque_pp_vox$p_mayoria - round(mean(der >= 176), 3)) > 0.0015)
  warning("salidas/ no coincide con web/datos/modelo.json (probabilidad de mayoría de PP y Vox distinta). ",
          "Comprueba que son las salidas de la versión publicada.")

# ------------------------------------------------------------------ utilidades
dhondt <- function(v, n, umbral = 3) {                                   # como en R/03: OTROS es un agregado y no opta
  ok <- v >= umbral & !(names(v) %in% c("BLANCO", "OTROS")); vv <- v[ok]
  co <- outer(vv, seq_len(n), "/"); o <- order(co, decreasing = TRUE)[seq_len(n)]
  gan <- table(factor(names(vv)[(o - 1) %% length(vv) + 1], levels = names(v)))
  list(escanos = setNames(as.integer(gan), names(v)), ultimo = names(vv)[(o[n] - 1) %% length(vv) + 1])
}
num <- function(x) suppressWarnings(as.numeric(sub(",", ".", trimws(x), fixed = TRUE)))
a_modelo <- function(p) ifelse(p %in% TODOS, p, "OTROS")                # códigos desconocidos cuentan como OTROS
avisos <- character()

# ------------------------------------------------------------------ resultados
leer_votos <- function(f) {
  if (!file.exists(f)) { message("No hay ", f, ": no se evalúa el voto."); return(NULL) }
  v <- fread(f, encoding = "UTF-8", colClasses = "character")
  if (!all(c("ambito", "partido", "pct") %in% names(v))) stop(f, " debe tener las columnas ambito, partido y pct")
  v[, `:=`(ambito = trimws(ambito), partido = toupper(trimws(partido)), pct = num(pct))]
  v <- v[partido != "" & !is.na(pct)]
  if (!nrow(v)) { message(f, " está vacío: no se evalúa el voto."); return(NULL) }
  v[tolower(ambito) %in% c("estado", "total", "españa", "espana"), ambito := "Estado"]
  if (length(m <- setdiff(v$ambito, c("Estado", b$district))))
    stop("Ámbitos desconocidos en ", f, ": ", paste(m, collapse = ", "), ". Usa «Estado» o el nombre de datos/base_23J.csv.")
  if (anyDuplicated(v[, .(ambito, partido)])) stop("Hay candidaturas repetidas en el mismo ámbito en ", f)
  ve <- v[ambito == "Estado"]; escr <- ve[partido == "_ESCRUTADO", pct]; ve <- ve[partido != "_ESCRUTADO"]
  if (length(m <- setdiff(ve$partido, PARTIDOS))) stop("Códigos desconocidos en el voto estatal: ", paste(m, collapse = ", "),
    ". Válidos: ", paste(PARTIDOS, collapse = ", "))
  if (length(m <- setdiff(EST, ve$partido))) stop("Falta el voto estatal de: ", paste(m, collapse = ", "))
  tot <- sum(ve$pct)
  if ("BLANCO" %in% ve$partido && abs(tot - 100) > 1) warning(sprintf("El voto estatal suma %.2f (debería ser 100).", tot))
  if (!"BLANCO" %in% ve$partido && tot > 100.5) warning(sprintf("El voto estatal suma %.2f, más de 100.", tot))
  list(estado = setNames(ve$pct, ve$partido), escrutado = if (length(escr)) escr[1] else NA_real_,
       prov = v[ambito != "Estado" & partido != "_ESCRUTADO"])
}
leer_escanos <- function(f) {
  if (!file.exists(f)) { message("No hay ", f, ": no se evalúan los escaños."); return(NULL) }
  r <- fread(f, encoding = "UTF-8", colClasses = "character")
  r[, `:=`(provincia = trimws(provincia), partido = toupper(trimws(partido)), escanos = suppressWarnings(as.integer(escanos)))]
  r <- r[partido != "" & !is.na(escanos)]
  cerradas <- r[partido == "_ESTADO" & escanos == 1L, unique(provincia)]
  r <- r[partido != "_ESTADO"]
  if (!nrow(r)) { message(f, " está vacío: no se evalúan los escaños."); return(NULL) }
  if (length(m <- setdiff(r$provincia, b$district))) stop("Circunscripciones desconocidas en ", f, ": ", paste(m, collapse = ", "))
  if (length(m <- setdiff(r$partido, TODOS))) message("Se cuentan como OTROS: ", paste(m, collapse = ", "))
  r[, partido := a_modelo(partido)]
  r <- r[, .(escanos = sum(escanos)), by = .(provincia, partido)]
  M <- matrix(0L, nrow(b), length(PARTIDOS), dimnames = list(b$district, PARTIDOS))
  M[cbind(r$provincia, r$partido)] <- r$escanos
  if (any(rowSums(M) > b$escanos)) stop("Más escaños de los que reparte en: ", paste(b$district[rowSums(M) > b$escanos], collapse = ", "))
  completa <- rowSums(M) == b$escanos
  if (!all(completa)) message("Circunscripciones sin todos sus escaños: ", paste(b$district[!completa], collapse = ", "))
  list(M = M, completa = setNames(completa, b$district), cerradas = cerradas)
}
V <- leer_votos(F_VOTOS); R <- leer_escanos(F_ESCANOS)
if (is.null(V) && is.null(R)) stop("No hay resultados que evaluar: rellena ", F_VOTOS, " o ", F_ESCANOS)

# ------------------------------------------------------------------ (a) voto
enc <- fread("datos/encuestas.csv", encoding = "UTF-8", colClasses = list(character = c("inicio", "fin")))
ultimas <- enc[casa != "CIS_M3"][order(casa, fin)][, .SD[.N], by = casa]      # última encuesta publicada de cada empresa
voto <- voto_otros <- NULL
if (!is.null(V)) {
  vt <- V$estado
  voto <- rbindlist(lapply(EST, \(p) {
    d <- D[, p]; m <- median(d); s_tot <- sqrt(sd(d)^2 + SD_SIST[[p]]^2); y <- vt[[p]]; q <- quantile(d, c(.05, .95), names = FALSE)
    sim <- mean(ultimas[[p]], na.rm = TRUE)
    data.table(partido = p, resultado = y, media = m, p05 = q[1], p95 = q[2],
               p05_comun = max(0, m - Z90 * s_tot), p95_comun = m + Z90 * s_tot, error = y - m, z_comun = (y - m) / s_tot,
               dentro = y >= q[1] & y <= q[2], dentro_comun = abs(y - m) <= Z90 * s_tot,
               promedio_simple = sim, casas = sum(!is.na(ultimas[[p]])), error_simple = y - sim)
  }))
  po <- intersect(names(SUP), names(vt))
  if (length(po)) voto_otros <- rbindlist(lapply(po, \(p) {
    s <- SUP[[p]]; lo <- s * exp(-Z90 * SD_REL[[p]]); hi <- s * exp(Z90 * SD_REL[[p]])
    data.table(partido = p, resultado = vt[[p]], supuesto = s, p05 = lo, p95 = hi, error = vt[[p]] - s,
               dentro = vt[[p]] >= lo & vt[[p]] <= hi)
  }))
}

# ------------------------------------------------------------------ (b) escaños
escanos <- bloque <- escenarios <- NULL
if (!is.null(R)) {
  real <- colSums(R$M)
  extra <- if (real[["OTROS"]] > 0) "OTROS" else character()
  escanos <- rbindlist(lapply(c(ORDEN, extra), \(p) {
    x <- E[, p]; y <- real[[p]]; q <- quantile(x, c(.05, .95), names = FALSE)
    data.table(partido = p, resultado = y, mediana = median(x), p05 = q[1], p95 = q[2], error = y - median(x),
               dentro = y >= q[1] & y <= q[2], p_exacto = mean(x == y), p_menos = mean(x < y), p_mas = mean(x > y))
  }))
  s <- real[["PP"]] + real[["VOX"]]; pm <- mean(der >= 176)
  bloque <- list(resultado = s, mayoria = s >= 176, mediana = median(der), p05 = unname(quantile(der, .05)),
                 p95 = unname(quantile(der, .95)), p_mayoria = round(pm, 3), p_resultado = round(if (s >= 176) pm else 1 - pm, 3),
                 p_menos = round(mean(der < s), 3), p_mas = round(mean(der > s), 3))
  escenarios <- esc_sc[, .(escenario, PP, PSOE, VOX, FA, p_mayoria = `P(PP+VOX>=176)`, p05 = `PP+VOX p05`, p95 = `PP+VOX p95`)]
  escenarios[, nombre := unname(ESCENARIOS[escenario])][is.na(nombre), nombre := escenario]
  escenarios[, en_portada := escenario %in% EN_PORTADA]
  escenarios[, desvio := abs(PP - real[["PP"]]) + abs(PSOE - real[["PSOE"]]) + abs(VOX - real[["VOX"]]) + abs(FA - real[["FA"]])]
  escenarios[, `:=`(mas_cercano = desvio == min(desvio), p_resultado = if (s >= 176) p_mayoria else 1 - p_mayoria,
                    dentro_pp_vox = s >= p05 & s <= p95)]
  setorder(escenarios, desvio)
}

# ------------------------------------------------------------------ (c) circunscripciones
provincias <- NULL; ultimo_resumen <- NULL
if (!is.null(R)) {
  vp <- if (!is.null(V)) V$prov else data.table(ambito = character(), partido = character(), pct = numeric())
  provincias <- rbindlist(lapply(seq_len(nrow(b)), \(i) {
    pr <- b$district[i]; n <- b$escanos[i]; y <- R$M[i, ]; S <- A[, i, ]
    clave <- do.call(paste, c(as.data.frame(S), sep = "-")); tab <- sort(table(clave), decreasing = TRUE)
    modal <- as.integer(strsplit(names(tab)[1], "-", fixed = TRUE)[[1]]); names(modal) <- PARTIDOS
    fav <- ult_esc[provincia == pr][which.max(p)]
    rr <- sort(y[y > 0], decreasing = TRUE); rmod <- sort(modal[modal > 0], decreasing = TRUE)
    fila <- data.table(provincia = pr, escanos = n, completa = R$completa[[pr]], cerrada = pr %in% R$cerradas,
      real = paste(names(rr), rr, collapse = " · "), mas_repetido = paste(names(rmod), rmod, collapse = " · "),
      reparto_real = list(as.list(rr)), reparto_mas_repetido = list(as.list(rmod)),
      p_mas_repetido = as.numeric(tab[1]) / nrow(S),
      acierto_reparto = NA, cambiados = NA_integer_, p_reparto = NA_real_, dos_primeros = NA_character_, p_dos_primeros = NA_real_,
      error_max = NA_integer_, ultimo_favorito = fav$partido, p_favorito = fav$p,
      ultimo_real = NA_character_, p_ultimo_real = NA_real_, acierto_ultimo = NA)
    if (!fila$completa) return(fila)
    top <- names(sort(y[y > 0], decreasing = TRUE))[seq_len(min(2, sum(y > 0)))]
    fila[, `:=`(acierto_reparto = all(modal == y), cambiados = as.integer(sum(abs(modal - y)) / 2),
                p_reparto = mean(clave == paste(y, collapse = "-")),
                dos_primeros = paste(sprintf("%s %d", top, y[top]), collapse = " · "),
                p_dos_primeros = mean(rowSums(S[, top, drop = FALSE] == matrix(y[top], nrow(S), length(top), byrow = TRUE)) == length(top)),
                error_max = as.integer(max(abs(modal - y))))]
    pv <- vp[ambito == pr]
    if (nrow(pv)) {                                                       # último escaño con el voto provincial
      v <- setNames(pv$pct, pv$partido); d <- dhondt(v, n)
      e_mod <- tapply(d$escanos, a_modelo(names(d$escanos)), sum)
      e_mod <- setNames(as.integer(e_mod[TODOS]), TODOS); e_mod[is.na(e_mod)] <- 0L
      if (!all(e_mod == y[TODOS])) {
        message("En ", pr, " el D'Hondt del voto provincial no da los escaños del fichero de escaños: no se evalúa su último escaño.")
      } else {
        u <- a_modelo(d$ultimo); pu <- ult_esc[provincia == pr & partido == u, p]
        fila[, `:=`(ultimo_real = u, p_ultimo_real = if (length(pu)) pu else 0, acierto_ultimo = u == fav$partido)]
      }
    }
    fila
  }))
  provincias[, cambiados_orden := fifelse(is.na(cambiados), -1L, cambiados)]
  setorder(provincias, -cambiados_orden, p_reparto, provincia); provincias[, cambiados_orden := NULL]
  con_ult <- provincias[!is.na(acierto_ultimo)]
  ultimo_resumen <- list(con_datos = nrow(con_ult), aciertos = sum(con_ult$acierto_ultimo),
                         esperados = round(sum(con_ult$p_favorito), 1))
}

# ------------------------------------------------------------------ (d) empresas
casas <- NULL
if (!is.null(V)) {
  anclas <- fread("datos/anclas_microdatos.csv", encoding = "UTF-8", colClasses = list(character = c("inicio", "fin")))
  fila_casa <- function(x, tipo) {
    out <- x[, .(casa, medio = cliente, fin, PP, PSOE, VOX, FA)]
    for (p in CUATRO) out[, (paste0("error_", p)) := vt[[p]] - get(p)]
    out[, error_medio := rowMeans(abs(as.matrix(.SD)), na.rm = TRUE), .SDcols = paste0("error_", CUATRO)]
    out[, tipo := tipo][]
  }
  casas <- rbind(fila_casa(ultimas, "encuesta"), fila_casa(anclas, "reestimación propia"))
  casas <- casas[order(tipo != "encuesta", tolower(casa))]
}

# ------------------------------------------------------------------ estado de la evaluación
completo <- !is.null(R) && all(R$completa)
escrutado <- if (!is.null(V)) V$escrutado else NA_real_
estado <- estado_pedido
if (estado == "definitivo" && ((!is.na(escrutado) && escrutado < 100) || (!is.null(R) && !completo))) {
  warning("Se pidió «definitivo», pero falta escrutinio o hay circunscripciones incompletas: queda como provisional.")
  estado <- "provisional"
}
if (!is.null(R) && !completo) avisos <- c(avisos, sprintf("Faltan escaños por asignar en %d circunscripciones; los totales de escaños son parciales.", sum(!R$completa)))
if (is.null(V)) avisos <- c(avisos, "Aún no está el voto estatal: falta la comparación del voto y de las empresas.")
if (is.null(R)) avisos <- c(avisos, "Aún no están los escaños: falta la comparación de escaños y circunscripciones.")

# ------------------------------------------------------------------ salidas
dir.create(DESTINO, recursive = TRUE, showWarnings = FALSE)
if (!is.null(voto)) fwrite(rbind(copy(voto)[, tipo := "agregador"],
                                 if (!is.null(voto_otros)) copy(voto_otros)[, tipo := "supuesto fijo"], fill = TRUE),
                           file.path(DESTINO, "evaluacion_voto.csv"))
if (!is.null(escanos)) {
  fwrite(escanos, file.path(DESTINO, "evaluacion_escanos.csv"))
  fwrite(escenarios, file.path(DESTINO, "evaluacion_escenarios.csv"))
  fwrite(provincias[, !c("reparto_real", "reparto_mas_repetido")], file.path(DESTINO, "evaluacion_provincias.csv"))
}
if (!is.null(casas)) fwrite(casas, file.path(DESTINO, "evaluacion_casas.csv"))

redondear <- function(x, d = 2) { x <- copy(x); for (j in names(x)) if (is.double(x[[j]])) set(x, j = j, value = round(x[[j]], d)); x }
json <- list(
  meta = list(estado = estado, escrutado = escrutado, completo = completo, avisos = as.list(avisos),
              circunscripciones_cerradas = if (!is.null(R)) length(R$cerradas) else NULL,
              generado = format(Sys.time(), "%Y-%m-%d %H:%M"), corte = meta_modelo$corte,
              simulaciones = nrow(E), sorteos_agregador = nrow(D), error_comun = as.list(SD_SIST)),
  voto = if (!is.null(voto)) list(
    partidos = redondear(voto),
    otros = if (!is.null(voto_otros)) redondear(voto_otros) else NULL,
    resumen = list(n = nrow(voto), dentro = sum(voto$dentro), dentro_comun = sum(voto$dentro_comun),
                   error_medio = round(mean(abs(voto$error)), 2), error_medio_simple = round(mean(abs(voto$error_simple)), 2),
                   error_medio_cuatro = round(mean(abs(voto[partido %in% CUATRO]$error)), 2),
                   error_medio_simple_cuatro = round(mean(abs(voto[partido %in% CUATRO]$error_simple)), 2))),
  escanos = if (!is.null(escanos)) list(
    partidos = redondear(escanos, 3), pp_vox = bloque,
    resumen = list(n = nrow(escanos[partido %in% ORDEN]), dentro = sum(escanos[partido %in% ORDEN]$dentro)),
    escenarios = redondear(escenarios, 3)),
  provincias = if (!is.null(provincias)) list(
    resumen = list(evaluadas = sum(provincias$completa), aciertos_reparto = sum(provincias$acierto_reparto, na.rm = TRUE),
                   esperados_reparto = round(sum(provincias[completa == TRUE]$p_mas_repetido), 1),
                   cambiados = sum(provincias$cambiados, na.rm = TRUE), ultimo = ultimo_resumen),
    lista = redondear(provincias[, !c("real", "mas_repetido", "dos_primeros")], 3)),
  casas = if (!is.null(casas)) redondear(casas)
)
dir.create(dirname(F_JSON), recursive = TRUE, showWarnings = FALSE)
write_json(json, F_JSON, auto_unbox = TRUE, digits = NA, na = "null", null = "null", pretty = FALSE)

# ------------------------------------------------------------------ resumen en consola
cat(sprintf("\nEvaluación %s%s\n", toupper(estado), if (!is.na(escrutado)) sprintf(" (escrutado: %.2f %%)", escrutado) else ""))
if (!is.null(voto)) {
  cat("\nVoto (resultado - media; dentro del 90 % sin / con error común):\n")
  print(voto[, .(partido, resultado, media = round(media, 2), error = round(error, 2), dentro, dentro_comun,
                 promedio_simple = round(promedio_simple, 2), error_simple = round(error_simple, 2))])
}
if (!is.null(escanos)) {
  cat("\nEscaños (escenario central):\n"); print(escanos[, .(partido, resultado, mediana, p05, p95, dentro, p_exacto = round(p_exacto, 3))])
  cat(sprintf("\nPP + Vox: %d escaños. Probabilidad que se daba a ese resultado (%s mayoría): %.3f\n",
              bloque$resultado, if (bloque$mayoria) "con" else "sin", bloque$p_resultado))
  cat("\nEscenarios (desvío = suma de errores absolutos en PP, PSOE, Vox y FA):\n")
  print(escenarios[, .(escenario, PP, PSOE, VOX, FA, desvio, mas_cercano, p_resultado = round(p_resultado, 3))])
  cat(sprintf("\nCircunscripciones: el reparto más repetido coincide en %d de %d (esperables: %.1f).",
              sum(provincias$acierto_reparto, na.rm = TRUE), sum(provincias$completa), sum(provincias[completa == TRUE]$p_mas_repetido)))
  if (ultimo_resumen$con_datos) cat(sprintf(" Último escaño: %d de %d.", ultimo_resumen$aciertos, ultimo_resumen$con_datos))
  cat("\n"); print(head(provincias[cambiados > 0, .(provincia, real, mas_repetido, cambiados, p_dos_primeros = round(p_dos_primeros, 3))], 10))
}
cat("\n", F_JSON, ": ", round(file.size(F_JSON) / 1024), " KB\n", sep = "")
if (length(avisos)) cat("Avisos:", avisos, sep = "\n  ")
