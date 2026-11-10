# Agregador de encuestas con efectos casa (JAGS).
#   y[i,k] = mu[t_i,k] + h[casa_i,k] + error muestral + error no muestral (tau_k)
#   mu[.,k]: paseo aleatorio diario, del 25-sep al 29-nov (el tramo sin encuestas proyecta la incertidumbre hasta el 29N)
#   Identificación: la media de los efectos casa de las privadas es cero (SW y CIS_M3 quedan fuera de la restricción,
#   con efecto casa libre pero encogido hacia cero por la misma distribución jerárquica, t de Student con 3 g.l.).
# Salida: salidas/agregador_draws.rds, salidas/agregador_resumen.csv, salidas/efectos_casa.csv
suppressPackageStartupMessages({ library(data.table); library(rjags) })
source("R/funciones_agregador.R")
set.seed(29112026)

PARTIDOS <- c("PP", "PSOE", "VOX", "FA", "POD", "SALF")
DIA0 <- as.Date("2026-09-25"); ELECCION <- as.Date("2026-11-29"); HOY <- as.Date(Sys.getenv("CORTE", "2026-11-08"))
FUERA_DE_LA_RESTRICCION <- c("SW", "CIS_M3")
excluir <- strsplit(Sys.getenv("EXCLUIR", ""), ",")[[1]]   # p. ej. EXCLUIR=SW para la variante sin SW

e <- fread("datos/encuestas.csv", encoding = "UTF-8")
e <- e[!(casa %in% excluir)]
a <- ajustar_agregador(e, PARTIDOS, DIA0, ELECCION, libres = FUERA_DE_LA_RESTRICCION, semilla = 29)
cat(sprintf("R-hat máximo: %.3f (sobre %d parámetros)\n", a$rhat, a$npar))
TT <- a$TT; T_HOY <- as.integer(HOY - DIA0) + 1L; orden <- a$orden; e <- a$e; g <- matrix(a$rhat)
M <- a$M
col_mu <- function(t, k) sprintf("mu[%d,%d]", t, k)
dibujar <- function(t) sapply(seq_along(PARTIDOS), \(k) M[, col_mu(t, k)]) |> `colnames<-`(PARTIDOS)
draws_hoy <- dibujar(T_HOY); draws_29n <- dibujar(TT)
serie <- rbindlist(lapply(seq_len(TT), \(t) data.table(fecha = DIA0 + t - 1, partido = PARTIDOS,
  med = apply(dibujar(t), 2, median), lo = apply(dibujar(t), 2, quantile, .05), hi = apply(dibujar(t), 2, quantile, .95))))
hc <- rbindlist(lapply(seq_along(orden), \(j) data.table(casa = orden[j], partido = PARTIDOS,
  efecto = sapply(seq_along(PARTIDOS), \(k) median(M[, sprintf("h[%d,%d]", j, k)])),
  lo = sapply(seq_along(PARTIDOS), \(k) quantile(M[, sprintf("h[%d,%d]", j, k)], .05)),
  hi = sapply(seq_along(PARTIDOS), \(k) quantile(M[, sprintf("h[%d,%d]", j, k)], .95)),
  n_encuestas = sum(e$casa == orden[j]))))
# Para anclar en una casa concreta: mu_casa = mu + h[casa] (lo que esa casa "vería" el 29N)
h_draws <- lapply(setNames(seq_along(orden), orden), \(j) sapply(seq_along(PARTIDOS), \(k) M[, sprintf("h[%d,%d]", j, k)]) |> `colnames<-`(PARTIDOS))
par_ruido <- data.table(partido = PARTIDOS,
  sigma_dia = sapply(seq_along(PARTIDOS), \(k) median(M[, sprintf("sigma[%d]", k)])),
  tau = sapply(seq_along(PARTIDOS), \(k) median(M[, sprintf("tau[%d]", k)])),
  sd_casas = sapply(seq_along(PARTIDOS), \(k) median(M[, sprintf("sdh[%d]", k)])))

sufijo <- if (length(excluir) && nzchar(excluir[1])) paste0("_sin_", paste(excluir, collapse = "_")) else ""
saveRDS(list(hoy = draws_hoy, d29n = draws_29n, h = h_draws, partidos = PARTIDOS, rhat = max(g[, 1], na.rm = TRUE)),
        sprintf("salidas/agregador_draws%s.rds", sufijo))
fwrite(serie, sprintf("salidas/agregador_serie%s.csv", sufijo))
fwrite(hc, sprintf("salidas/efectos_casa%s.csv", sufijo))
fwrite(par_ruido, sprintf("salidas/agregador_parametros%s.csv", sufijo))
res <- function(d, etiqueta) data.table(momento = etiqueta, partido = PARTIDOS, mediana = apply(d, 2, median),
  p05 = apply(d, 2, quantile, .05), p95 = apply(d, 2, quantile, .95))
MESES <- c("ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic")
etiqueta_corte <- paste0(as.integer(format(HOY, "%d")), "-", MESES[as.integer(format(HOY, "%m"))])   # p. ej. «8-nov»
r <- rbind(res(draws_hoy, etiqueta_corte), res(draws_29n, "29-nov"))
fwrite(r, sprintf("salidas/agregador_resumen%s.csv", sufijo))
print(r, digits = 3)
cat("\nP(PP > PSOE) 29N:", round(mean(draws_29n[, "PP"] > draws_29n[, "PSOE"]), 3), "\n")
print(hc[order(partido, efecto)][partido %in% c("PP", "PSOE")], digits = 2)
