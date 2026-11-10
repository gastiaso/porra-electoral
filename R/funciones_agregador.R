# Modelo del agregador (JAGS), compartido por 02_agregador.R (29N) y 09_backtest.R (10N 2019 y 23J 2023).
#   y[i,k] = mu[t_i,k] + h[casa_i,k] + error muestral + error no muestral (tau_k)
#   mu[.,k]: paseo aleatorio diario desde dia0 hasta el día de la elección
#   Identificación: la media de los efectos casa de las casas «de referencia» que publican cada partido es cero;
#   las «libres» quedan fuera
#   de la restricción, con efecto casa encogido hacia cero por la misma t de Student (3 g.l.).
suppressPackageStartupMessages({ library(data.table); library(rjags) })

MODELO_AGREGADOR <- "
model {
  for (k in 1:K) {
    mu[1, k] ~ dnorm(m0[k], 1 / 25)
    sigma[k] ~ dunif(0, 0.5)
    for (t in 2:TT) { mu[t, k] ~ dnorm(mu[t - 1, k], 1 / pow(sigma[k], 2)) }
    tau[k] ~ dunif(0, 2)
    sdh[k] ~ dunif(0, 5)
    for (j in 1:J) { hraw[j, k] ~ dt(0, 1 / pow(sdh[k], 2), 3) }   # colas anchas: una casa atípica no arrastra al resto
    hbar[k] <- inprod(hraw[1:NR, k], w[1:NR, k]) / sum(w[1:NR, k])   # solo las casas que publican el partido
    for (j in 1:NR) { h[j, k] <- hraw[j, k] - hbar[k] }
    for (j in (NR + 1):J) { h[j, k] <- hraw[j, k] }
    for (i in 1:N) { y[i, k] ~ dnorm(mu[t[i], k] + h[casa[i], k], 1 / (vs[i, k] + pow(tau[k], 2))) }
  }
}"

# e: data.table con casa, inicio, fin, n y una columna por partido (NA si la casa no lo publica)
ajustar_agregador <- function(e, partidos, dia0, eleccion, libres = character(), deff = 1.5,
                              adapt = 2000, burn = 20000, iter = 40000, thin = 20, semilla = 1) {
  e <- copy(e)
  e[, medio := as.Date(inicio) + (as.Date(fin) - as.Date(inicio)) / 2]
  e[, t := as.integer(round(medio - dia0)) + 1L]
  TT <- as.integer(eleccion - dia0) + 1L
  casas <- unique(e$casa)
  ref <- setdiff(casas, libres); lib <- intersect(casas, libres); orden <- c(ref, lib)
  e[, j := match(casa, orden)]
  Y <- as.matrix(e[, ..partidos])
  media_k <- colMeans(Y, na.rm = TRUE)
  P <- matrix(rep(media_k, each = nrow(Y)), nrow(Y)) / 100
  VS <- P * (1 - P) * 1e4 * deff / e$n                   # varianza muestral en puntos^2
  # w[j,k] = 1 si la casa j publica el partido k en alguna entrega (si no, su efecto no tiene datos)
  W <- sapply(seq_along(partidos), \(k) sapply(seq_along(orden), \(j) as.numeric(any(!is.na(Y[e$j == j, k])))))
  W <- matrix(W, nrow = length(orden))
  datos <- list(y = Y, vs = VS, t = e$t, casa = e$j, N = nrow(e), K = length(partidos), TT = TT,
                J = length(orden), NR = length(ref), m0 = media_k, w = W)
  inits <- lapply(1:4, \(c) list(.RNG.name = "base::Mersenne-Twister", .RNG.seed = semilla * 100 + c))
  jm <- jags.model(textConnection(MODELO_AGREGADOR), data = datos, inits = inits, n.chains = 4, n.adapt = adapt, quiet = TRUE)
  update(jm, burn, progress.bar = "none")
  s <- coda.samples(jm, c("mu", "h", "sigma", "tau", "sdh"), n.iter = iter, thin = thin, progress.bar = "none")
  g <- gelman.diag(s, multivariate = FALSE)$psrf
  sin_datos <- as.vector(outer(seq_along(orden), seq_along(partidos), \(j, k) sprintf("h[%d,%d]", j, k)))[as.vector(W) == 0]
  g <- g[!rownames(g) %in% sin_datos, , drop = FALSE]          # el R-hat no mide efectos sin datos (puro a priori)
  M <- as.matrix(s)
  dibujar <- function(t) sapply(seq_along(partidos), \(k) M[, sprintf("mu[%d,%d]", t, k)]) |> `colnames<-`(partidos)
  list(M = M, e = e, orden = orden, ref = ref, libres = lib, partidos = partidos, dia0 = dia0, TT = TT,
       dibujar = dibujar, rhat = max(g[, 1], na.rm = TRUE), npar = nrow(g))
}
