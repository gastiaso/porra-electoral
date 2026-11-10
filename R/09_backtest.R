# Backtest: el mismo agregador, con las encuestas publicadas antes de la veda del 10N 2019 y del 23J 2023,
# frente al resultado. Mide el error de la media y si los intervalos (con y sin error sistemático) lo cubren.
# Entradas: datos/backtest/encuestas_{10N,23J}_wikipedia.csv (tablas de Wikipedia, voto estimado)
# Salida:   salidas/backtest.csv, salidas/backtest_casas.csv
suppressPackageStartupMessages({ library(data.table) })
source("R/funciones_agregador.R")

MESES <- c(Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6, Jul = 7, Aug = 8, Sep = 9, Oct = 10, Nov = 11, Dec = 12)
# «29 Jun–17 Jul», «16–17 Jul», «17 Jul»
fechas <- function(x, anio) {
  x <- gsub("–", "-", x); p <- strsplit(x, "-")[[1]]; fin <- strsplit(trimws(p[length(p)]), " ")[[1]]
  f_fin <- as.Date(sprintf("%d-%02d-%02d", anio, MESES[[fin[2]]], as.integer(fin[1])))
  if (length(p) == 1) return(c(f_fin, f_fin))
  ini <- strsplit(trimws(p[1]), " ")[[1]]
  mes_ini <- if (length(ini) == 2) MESES[[ini[2]]] else MESES[[fin[2]]]
  c(as.Date(sprintf("%d-%02d-%02d", anio, mes_ini, as.integer(ini[1]))), f_fin)
}
# Fuera: agregadores (KeyData), reestimaciones de terceros, el CIS publicado (en el 29N solo entra reestimado) y filas dudosas
FUERA <- c("KeyData", "CIS", "CIS (SocioMétrica)", "GI Internacional")

preparar <- function(f, partidos, anio, corte) {
  e <- fread(f, encoding = "UTF-8", na.strings = c("?", "–", ""))
  e <- e[!(firm %in% FUERA)]
  d <- t(sapply(e$fieldwork, fechas, anio = anio)); e[, `:=`(inicio = as.Date(d[, 1]), fin = as.Date(d[, 2]))]
  e[, casa := firm][, n := fifelse(is.na(sample), 1000L, as.integer(sample))]
  e[, faltan := rowSums(is.na(as.matrix(.SD))), .SDcols = partidos]
  e <- e[fin <= corte & faltan < length(partidos), c("casa", "inicio", "fin", "n", partidos), with = FALSE]
  # Una entrega por ventana no solapada y casa (los trackings diarios solapan): de la más reciente hacia atrás
  setorder(e, casa, -fin)
  e[, keep := { k <- logical(.N); lim <- as.Date("2100-01-01"); for (i in seq_len(.N)) if (fin[i] < lim) { k[i] <- TRUE; lim <- inicio[i] }; k }, by = casa]
  e[keep == TRUE][, keep := NULL][]
}

# Error común que usa 03_escanos.R el día de la elección (sd, puntos): el actual y el anterior al 10-nov
SIST <- c(PP = 2.0, PSOE = 2.0, VOX = 1.5, SUMAR = 1.0, UP = 1.0, CS = 1.0)
SIST_ANT <- c(PP = 1.5, PSOE = 1.5, VOX = 1.2, SUMAR = 0.8, UP = 0.8, CS = 0.8)
CASOS <- list(
  list(id = "10N 2019", f = "datos/backtest/encuestas_10N_wikipedia.csv", partidos = c("PSOE", "PP", "VOX", "UP", "CS"),
       anio = 2019, dia0 = as.Date("2019-10-07"), corte = as.Date("2019-11-04"), eleccion = as.Date("2019-11-10"),
       real = c(PSOE = 28.00, PP = 20.82, VOX = 15.08, UP = 12.86, CS = 6.79)),
  list(id = "23J 2023", f = "datos/backtest/encuestas_23J_wikipedia.csv", partidos = c("PP", "PSOE", "VOX", "SUMAR"),
       anio = 2023, dia0 = as.Date("2023-05-29"), corte = as.Date("2023-07-17"), eleccion = as.Date("2023-07-23"),
       real = c(PP = 33.05, PSOE = 31.70, VOX = 12.39, SUMAR = 12.31)))

res <- list(); casas <- list()
for (cs in CASOS) {
  e <- preparar(cs$f, cs$partidos, cs$anio, cs$corte)
  cat(sprintf("%s: %d entregas de %d casas\n", cs$id, nrow(e), uniqueN(e$casa)))
  a <- ajustar_agregador(e, cs$partidos, cs$dia0, cs$eleccion, semilla = cs$anio)
  d <- a$dibujar(a$TT)
  ult <- e[, .SD[which.max(fin)], by = casa]                 # la última entrega de cada casa, promedio simple
  for (p in cs$partidos) {
    sd_agr <- sd(d[, p]); m <- median(d[, p]); s_tot <- sqrt(sd_agr^2 + SIST[[p]]^2)
    res[[length(res) + 1]] <- data.table(eleccion = cs$id, partido = p, real = cs$real[[p]],
      media_simple = round(mean(ult[[p]], na.rm = TRUE), 2), agregador = round(m, 2),
      p05 = round(quantile(d[, p], .05), 2), p95 = round(quantile(d[, p], .95), 2),
      error = round(cs$real[[p]] - m, 2), z_total = round((cs$real[[p]] - m) / s_tot, 2),
      cubre_90_agregador = cs$real[[p]] >= quantile(d[, p], .05) & cs$real[[p]] <= quantile(d[, p], .95),
      cubre_90_con_sistematico = abs(cs$real[[p]] - m) <= 1.645 * s_tot,
      cubre_90_sist_anterior = abs(cs$real[[p]] - m) <= 1.645 * sqrt(sd_agr^2 + SIST_ANT[[p]]^2), rhat = round(a$rhat, 3))
  }
  # Error de cada casa = resultado - lo que esa casa "veía" el día de la elección (tendencia + su efecto)
  for (j in seq_along(a$orden)) for (k in seq_along(cs$partidos)) {
    casas[[length(casas) + 1]] <- data.table(eleccion = cs$id, casa = a$orden[j], partido = cs$partidos[k],
      error = round(cs$real[[k]] - median(d[, k] + a$M[, sprintf("h[%d,%d]", j, k)]), 2), entregas = sum(e$casa == a$orden[j]))
  }
}
res <- rbindlist(res); casas <- rbindlist(casas)
fwrite(res, "salidas/backtest.csv"); fwrite(casas, "salidas/backtest_casas.csv")
print(res)
cat("\nError absoluto medio de cada casa (puntos, todos los partidos):\n")
print(casas[, .(eam = round(mean(abs(error)), 2), entregas = entregas[1]), by = .(eleccion, casa)][order(eleccion, eam)])
