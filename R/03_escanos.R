# Simulación de escaños: 52 circunscripciones, D'Hondt con umbral del 3 % del voto válido.
# Voto estatal: draws del agregador al 29N + error sistemático de la industria (desconocido) + supuestos de escenario.
# Traslado a provincias desde el 23J con tres reglas de swing (proporcional, aditivo, mixto) y ruido autonómico y provincial.
# Uso: Rscript R/03_escanos.R            (NSIM=4000 por defecto; variable de entorno)
suppressPackageStartupMessages({ library(data.table) })
set.seed(20261129)
NSIM <- as.integer(Sys.getenv("NSIM", "4000"))
ESCANOS_ALT <- Sys.getenv("ESCANOS_ALT", "0") == "1"   # variante con los 8 cambios de una sola fuente

b <- fread("datos/base_23J.csv", encoding = "UTF-8")
if (ESCANOS_ALT) {
  b[, escanos := escanos_2023]
  b[district %in% c("Madrid", "Alicante/Alacant", "Valencia/València", "Málaga"), escanos := escanos + 1L]
  b[district %in% c("Asturias", "Cádiz", "Badajoz", "Coruña (A)"), escanos := escanos - 1L]
}
stopifnot(sum(b$escanos) == 350)
w <- b$validos / sum(b$validos)                       # peso de cada provincia en el voto válido (23J)
nac23 <- function(p) sum(b[[paste0("s_", p)]] * w)

# ------------------------------------------------------------------ D'Hondt
dhondt <- function(v, n, umbral = 3) {                # v: % por candidatura (incluye BLANCO y OTROS, que no optan: OTROS es un agregado)
  ok <- v >= umbral & !(names(v) %in% c("BLANCO", "OTROS"))
  if (!any(ok)) return(setNames(integer(length(v)), names(v)))
  vv <- v[ok]
  cocientes <- outer(vv, seq_len(n), "/")
  orden <- order(cocientes, decreasing = TRUE)[seq_len(n)]
  gan <- table(factor(names(vv)[(orden - 1) %% length(vv) + 1], levels = names(v)))
  setNames(as.integer(gan), names(v))
}
# Contraste: con los porcentajes del 23J y los escaños de 2023, debe reproducir el resultado oficial
PARTIDOS23 <- c("PP","PSOE","VOX","SUMAR","ERC","JUNTS","BILDU","PNV","BNG","CC","UPN","OTROS","BLANCO")
S23 <- as.matrix(b[, paste0("s_", PARTIDOS23), with = FALSE]); colnames(S23) <- PARTIDOS23
e23 <- Reduce(`+`, lapply(seq_len(nrow(b)), \(i) dhondt(S23[i, ], b$escanos_2023[i])))
cat("Contraste 23J (debe dar PP 137, PSOE 121, VOX 33, SUMAR 31, ERC 7, JUNTS 7, BILDU 6, PNV 5, BNG 1, CC 1, UPN 1):\n"); print(e23)
stopifnot(e23[["PP"]] == 137, e23[["PSOE"]] == 121, e23[["VOX"]] == 33, e23[["SUMAR"]] == 31)

# ------------------------------------------------------------------ voto estatal por escenario
ag <- readRDS("salidas/agregador_draws.rds")
D <- ag$d29n[sample.int(nrow(ag$d29n), NSIM, replace = TRUE), ]
idx_h <- sample.int(nrow(ag$h[[1]]), NSIM, replace = TRUE)

enc <- rbind(fread("datos/encuestas.csv", encoding = "UTF-8", colClasses = list(character = c("inicio", "fin"))),
             fread("datos/anclas_microdatos.csv", encoding = "UTF-8", colClasses = list(character = c("inicio", "fin")))[casa != "CIS_M3"])
enc[, medio := as.Date(inicio) + round((as.Date(fin) - as.Date(inicio)) / 2)]
serie <- fread("salidas/agregador_serie.csv"); serie[, fecha := as.Date(fecha)]
# Escenario B: «si esta media falla como falló en 2023». Error del mismo agregador en el 23J (09_backtest.R),
# proyectado al día de la votación con las encuestas publicadas hasta el 17-jul-2023 (media - resultado).
if (!file.exists("salidas/backtest.csv")) stop("Falta salidas/backtest.csv: ejecuta antes R/09_backtest.R")
bt <- fread("salidas/backtest.csv")[eleccion == "23J 2023"]
err23 <- setNames(-bt$error, bt$partido)[c("PP", "PSOE", "VOX", "SUMAR")]
cat("\nError del agregador en el 23J (media - resultado):\n"); print(round(err23, 2))

# Regionalistas y nuevos: objetivo estatal (% válido) a partir de las encuestas de oct-nov que los publican; sd relativa 20 %
REG <- c(ERC = 2.4, JUNTS = 1.3, BILDU = 1.35, PNV = 0.95, BNG = 0.95, CC = 0.45, UPN = 0.2)
# Aliança Catalana no se presenta a las generales (decisión de su dirección, oct-2026): no entra en la simulación.
# Su voto queda donde lo ponen las encuestas, que en su mayoría ya no la publicaban.

# Calibrado con el backtest (09_backtest.R): en 2019 y 2023 el error común llegó a 3,3 puntos (PSOE 23J) y 2,4
# (Cs 10N). Con estos valores el resultado cae dentro del intervalo del 90 % en 8 de 9 casos; con los anteriores
# (PP y PSOE 1,5; Vox 1,2; FA 0,8; Podemos y SALF 0,5), en 7 de 9. Variante con los anteriores: SIST=anterior.
SIST_ANTERIOR <- Sys.getenv("SIST", "") == "anterior"
SD_SIST <- if (SIST_ANTERIOR) c(PP = 1.5, PSOE = 1.5, VOX = 1.2, FA = 0.8, POD = 0.5, SALF = 0.5) else
  c(PP = 2.0, PSOE = 2.0, VOX = 1.5, FA = 1.0, POD = 0.7, SALF = 0.7)
COR_SIST <- diag(6); dimnames(COR_SIST) <- list(names(SD_SIST), names(SD_SIST))
COR_SIST["PP", "PSOE"] <- COR_SIST["PSOE", "PP"] <- -0.5
COR_SIST["PP", "VOX"] <- COR_SIST["VOX", "PP"] <- -0.3
COR_SIST["PSOE", "FA"] <- COR_SIST["FA", "PSOE"] <- -0.3
SIGMA_SIST <- diag(SD_SIST) %*% COR_SIST %*% diag(SD_SIST); dimnames(SIGMA_SIST) <- dimnames(COR_SIST)
stopifnot(all(eigen(SIGMA_SIST)$values > 0))

escenario <- function(nombre) {
  V <- D
  if (nombre == "B_correccion_23J") {
    V[, "PP"] <- V[, "PP"] - err23[["PP"]]; V[, "PSOE"] <- V[, "PSOE"] - err23[["PSOE"]]; V[, "VOX"] <- V[, "VOX"] - err23[["VOX"]]
    f <- 1 - err23[["SUMAR"]] / 12.31; V[, "FA"] <- V[, "FA"] * f; V[, "POD"] <- V[, "POD"] * f
  }
  # Anclas: "si esta casa tuviera razón". Se usa su desviación bruta respecto a la tendencia en su fecha de campo
  # (no el efecto casa encogido del modelo, que con una sola encuesta apenas se separa del ruido), más su error muestral.
  # F: media de las dos fuentes con microdatos abiertos reestimadas con el mismo modelo (CIS-M3 y MiC-M3).
  ancla <- list(C_ancla_CIS_M3 = "CIS_M3", D_ancla_MiC = "MoreInCommon", D2_ancla_MiC_M3 = "MiC_M3", E_ancla_SW = "SW",
                F_ancla_microdatos = c("CIS_M3", "MiC_M3"))
  if (nombre %in% names(ancla)) {
    desv <- lapply(ancla[[nombre]], \(cs) {
      ec <- enc[casa == cs][.N]
      mt <- serie[fecha == ec$medio, setNames(med, partido)][colnames(V)]
      y <- unlist(ec[, colnames(V), with = FALSE]); y[is.na(y)] <- mt[is.na(y)]
      vs <- (y / 100) * (1 - y / 100) * 1e4 * 1.5 / ec$n
      matrix(y - mt, NSIM, ncol(V), byrow = TRUE) + sapply(vs, \(x) rnorm(NSIM, 0, sqrt(x)))
    })
    V <- V + Reduce(`+`, desv) / length(desv)
  }
  # error sistemático desconocido el día de la elección (común a todas las casas), correlacionado:
  # PP y PSOE fallan en sentido contrario (23J: PP +0,9 / PSOE -3,3 en la media), y PP y Vox comparten votantes.
  V <- V + mvtnorm::rmvnorm(NSIM, sigma = SIGMA_SIST)
  pmax(V, 0.1)
}

# ------------------------------------------------------------------ traslado a provincias
swing <- function(s23, nuevo, viejo, regla) {
  prop <- s23 * nuevo / viejo
  adit <- pmax(s23 + (nuevo - viejo), 0.05 * s23)
  switch(regla, proporcional = prop, aditivo = adit, mixto = (prop + adit) / 2)
}
ccaa_id <- as.integer(factor(b$ccaa)); NCCAA <- max(ccaa_id)
es_cva_can <- b$ccaa %in% c("CVA", "CAN")
es_cat <- b$ccaa == "CAT"

provincias <- function(v, regla, sd_ccaa = 0.06, sd_prov = 0.06) {
  ruido <- function() exp(rnorm(NCCAA, 0, sd_ccaa))[ccaa_id] * exp(rnorm(nrow(b), 0, sd_prov))
  S <- cbind(
    PP   = swing(b$s_PP,   v[["PP"]],   nac23("PP"),   regla) * ruido(),
    PSOE = swing(b$s_PSOE, v[["PSOE"]], nac23("PSOE"), regla) * ruido(),
    VOX  = swing(b$s_VOX,  v[["VOX"]],  nac23("VOX"),  regla) * ruido(),
    IZQ  = swing(b$s_SUMAR, v[["FA"]] + v[["POD"]], nac23("SUMAR"), regla) * ruido(),
    SALF = v[["SALF"]] * exp(rnorm(nrow(b), 0, 0.15)))
  # Podemos solo por separado fuera de la C. Valenciana y Canarias
  q <- v[["POD"]] / sum((S[, "IZQ"] * w)[!es_cva_can])
  POD <- ifelse(es_cva_can, 0, pmin(q, 1) * S[, "IZQ"])
  S <- cbind(S[, c("PP", "PSOE", "VOX")], FA = S[, "IZQ"] - POD, POD = POD, SALF = S[, "SALF"])
  reg <- sapply(names(REG), \(p) b[[paste0("s_", p)]] * (REG[[p]] * exp(rnorm(1, 0, 0.2))) / nac23(p) * exp(rnorm(nrow(b), 0, 0.05)))
  S <- cbind(S, reg)
  resto <- pmax(100 - sum(colSums(S * w)), 1)          # otros + blanco, repartido como en 2023
  ob <- (b$s_OTROS + b$s_BLANCO); OB <- ob * resto / sum(ob * w)
  S <- cbind(S, OTROS = OB * b$s_OTROS / ob, BLANCO = OB * b$s_BLANCO / ob)
  S <- 100 * S / rowSums(S)
  # rastrillo: que el agregado estatal de los partidos estatales coincida con el draw
  for (it in 1:3) {
    for (p in c("PP", "PSOE", "VOX", "SALF")) S[, p] <- S[, p] * v[[p]] / sum(S[, p] * w)
    S <- 100 * S / rowSums(S)
  }
  S
}

ultimo_escano <- function(v, n, umbral = 3) {         # partido que se lleva el último escaño de la circunscripción
  ok <- v >= umbral & !(names(v) %in% c("BLANCO", "OTROS")); vv <- v[ok]
  co <- outer(vv, seq_len(n), "/"); o <- order(co, decreasing = TRUE)
  names(vv)[(o[n] - 1) %% length(vv) + 1]
}
simular <- function(nombre, regla, con_ultimo = FALSE) {
  V <- escenario(nombre)
  cols <- colnames(provincias(V[1, ], regla))
  ult <- if (con_ultimo) matrix(NA_character_, NSIM, nrow(b)) else NULL
  prov <- if (con_ultimo) array(0L, c(NSIM, nrow(b), length(cols)), dimnames = list(NULL, b$district, cols)) else NULL
  res <- t(vapply(seq_len(NSIM), \(s) {
    S <- provincias(V[s, ], regla)
    if (con_ultimo) ult[s, ] <<- vapply(seq_len(nrow(b)), \(i) ultimo_escano(S[i, ], b$escanos[i]), "")
    ep <- lapply(seq_len(nrow(b)), \(i) dhondt(S[i, ], b$escanos[i]))
    if (con_ultimo) for (i in seq_len(nrow(b))) prov[s, i, ] <<- ep[[i]]
    Reduce(`+`, ep)
  }, numeric(length(cols))))
  colnames(res) <- cols
  list(esc = res, voto = V, ultimo = ult, prov = prov)
}

resumen <- function(sim, nombre, regla) {
  E <- sim$esc
  bloque_der <- E[, "PP"] + E[, "VOX"] + E[, "UPN"]
  investidura23 <- E[, "PSOE"] + E[, "FA"] + E[, "POD"] + E[, "ERC"] + E[, "JUNTS"] + E[, "BILDU"] + E[, "PNV"] + E[, "BNG"] + E[, "CC"]
  data.table(escenario = nombre, swing = regla,
    PP = median(E[, "PP"]), PSOE = median(E[, "PSOE"]), VOX = median(E[, "VOX"]), FA = median(E[, "FA"]),
    POD = median(E[, "POD"]), SALF = median(E[, "SALF"]),
    `P(PP+VOX+UPN>=176)` = mean(bloque_der >= 176), `P(PP+VOX>=176)` = mean(E[, "PP"] + E[, "VOX"] >= 176),
    `P(bloque 2023>=176)` = mean(investidura23 >= 176), `P(PSOE>PP esc.)` = mean(E[, "PSOE"] > E[, "PP"]),
    `PP+VOX p05` = quantile(E[, "PP"] + E[, "VOX"], .05), `PP+VOX p95` = quantile(E[, "PP"] + E[, "VOX"], .95))
}

ESCENARIOS <- c("A_media_privadas", "B_correccion_23J", "C_ancla_CIS_M3", "D_ancla_MiC", "D2_ancla_MiC_M3", "F_ancla_microdatos", "E_ancla_SW")
REGLAS <- c("mixto", "proporcional", "aditivo")
tabla <- list(); central <- NULL
for (sc in ESCENARIOS) for (rg in REGLAS) {
  if (sc != "A_media_privadas" && rg != "mixto") next  # sensibilidad de la regla solo en el central
  sim <- simular(sc, rg, con_ultimo = sc == "A_media_privadas" && rg == "mixto")
  tabla[[paste(sc, rg)]] <- resumen(sim, sc, rg)
  if (sc == "A_media_privadas" && rg == "mixto") central <- sim
  cat(sprintf("%s / %s hecho\n", sc, rg))
}
tabla <- rbindlist(tabla)
suf <- paste0(if (ESCANOS_ALT) "_escanos_alt" else "", if (SIST_ANTERIOR) "_sist_anterior" else "")
fwrite(tabla, sprintf("salidas/escanos_escenarios%s.csv", suf))
E <- central$esc
dist <- rbindlist(lapply(colnames(E), \(p) data.table(partido = p, media = mean(E[, p]), mediana = median(E[, p]),
  p05 = quantile(E[, p], .05), p95 = quantile(E[, p], .95), `P(>=1)` = mean(E[, p] >= 1))))
fwrite(dist, sprintf("salidas/escanos_central%s.csv", suf))
saveRDS(E, sprintf("salidas/escanos_central_draws%s.rds", suf))
saveRDS(central$prov, sprintf("salidas/escanos_provincia_central%s.rds", suf))   # [simulación, provincia, partido]
U <- central$ultimo
ult <- rbindlist(lapply(seq_len(nrow(b)), \(i) { t <- table(U[, i]) / NSIM
  data.table(provincia = b$district[i], ccaa = b$ccaa[i], escanos = b$escanos[i], partido = names(t), p = as.numeric(t)) }))
fwrite(ult, sprintf("salidas/ultimo_escano%s.csv", suf))
fwrite(as.data.table(central$voto), sprintf("salidas/voto_central_draws%s.csv", suf))
print(dist[order(-media)], digits = 3)
print(tabla, digits = 3)
