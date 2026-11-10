# Re-estimación de More in Common desde sus microdatos (mayo, julio, septiembre y octubre de 2026)
# con la misma lógica que los modelos M1-M4 aplicados al CIS, adaptada al cuestionario de MiC.
#   MIC  reproducción de su estimación: intencion_voto_final (una imputación XGBoost) x peso x prob_voto_estimada
#   M1   intención + simpatía (intencion_voto_simpatia) con el peso demográfico (solo octubre lo publica)
#   M2   lo mismo con `peso` (raking que ya incluye el recuerdo del 23J, imputado por MiC)
#   M3   votantes probables (probabilidad declarada 9-10) + cascada para indecisos: intención directa -> simpatía ->
#        recuerdo declarado (si ese partido se ofrece), con `peso`
#   M4   votantes probables; indecisos por regresión logística multinomial ajustada sobre los que declaran voto
#        (ideología, recuerdo, sexo, edad y valoración de líderes cuando la hay), con `peso`
# Todo en % sobre voto válido (candidaturas + blanco). Intervalos del 95 % por remuestreo de entrevistas.
# Uso: Rscript R/04_microdatos_mic.R   (lee datos/mic/microdatos-2026-MM.zip; B=200 y B4=40 por defecto)
# Los ZIP de MiC no se redistribuyen en este repositorio: descárgalos de https://moreincommon.es/pulso-electoral.html
suppressPackageStartupMessages({ library(data.table); library(haven); library(nnet) })
set.seed(20261110)
B <- as.integer(Sys.getenv("B", "200")); B4 <- as.integer(Sys.getenv("B4", "40"))
DIR <- "datos/mic"
CAMPO <- list("05" = c(NA, NA), "07" = c(NA, NA), "09" = c(NA, NA), "10" = c("2026-10-21", "2026-10-25"))

leer <- function(z) {
  tmp <- file.path(tempdir(), sub("\\.zip$", "", basename(z))); dir.create(tmp, showWarnings = FALSE)
  unzip(z, exdir = tmp)
  as.data.table(read_sav(list.files(tmp, pattern = "\\.sav$", full.names = TRUE)[1]))
}

# Códigos de MiC -> candidaturas del 29N
grupo <- function(cod) {
  cod <- as.integer(cod)
  fcase(cod == 1L, "PP", cod == 2L, "PSOE", cod == 3L, "VOX", cod %in% 4:7, "FA", cod == 20L, "POD", cod == 21L, "SALF",
        cod %in% c(8:12, 14L, 15L, 32L, 33L), "REG", cod == 22L, "OTROS", cod == 23L, "BLANCO",
        cod == 24L, "NULO", cod == 25L, "NO_VOTARIA", cod %in% c(98L, 99L), "NSNC", default = NA_character_)
}
VALIDO <- c("PP", "PSOE", "VOX", "FA", "POD", "SALF", "REG", "OTROS", "BLANCO")
reparto <- function(v, w) { ok <- v %in% VALIDO; s <- tapply(w[ok], factor(v[ok], VALIDO), sum); s[is.na(s)] <- 0; 100 * s / sum(s) }

preparar <- function(x) {
  d <- data.table(
    peso = x$peso, peso_demo = if ("peso_demografico" %in% names(x)) x$peso_demografico else NA_real_,
    prob = as.numeric(x$prob_voto_declarada), prob_est = x$prob_voto_estimada,
    int = grupo(x$intencion_voto_raw), int_sim = grupo(x$intencion_voto_simpatia),
    final = { f <- as.integer(x$intencion_voto_final); g <- grupo(f); g[f == 0L] <- "ABST"; g[f == 98L] <- "REG"; g[f == 99L] <- "OTROS"; g },
    # simpatía: el 23 es «Ninguno», no «Blanco»
    sim = fifelse(as.integer(x$simpatia_partido) %in% c(23L, 98L, 99L), NA_character_, grupo(x$simpatia_partido)),
    rec = grupo(x$voto_2023_raw), rec_final = as.integer(x$voto_2023_final),
    ideo = as.numeric(x$ideologia), sexo = as.factor(as.integer(x$genero)), edad = as.factor(as.integer(x$grupo_edad)))
  lid <- grep("^valoracion_", names(x), value = TRUE)
  for (l in lid) d[, (l) := as.numeric(x[[l]])]
  d
}

votante_probable <- function(d) ((!is.na(d$prob) & d$prob >= 9) | (is.na(d$prob) & d$int %in% VALIDO)) & !(d$int %in% "NO_VOTARIA")
cascada <- function(d) {
  ofrecidos <- unique(d$int[d$int %in% VALIDO])
  v <- fifelse(d$int %in% VALIDO, d$int, NA_character_)
  und <- d$int %in% "NSNC"
  usar <- und & is.na(v) & d$sim %in% VALIDO; v[usar] <- d$sim[usar]
  rec <- fifelse(d$rec %in% intersect(ofrecidos, setdiff(VALIDO, "BLANCO")), d$rec, NA_character_)
  usar <- und & is.na(v) & !is.na(rec); v[usar] <- rec[usar]
  v
}
modelo4 <- function(d) {
  vp <- votante_probable(d); dec <- vp & d$int %in% VALIDO; und <- vp & d$int %in% "NSNC"
  lid <- grep("^valoracion_", names(d), value = TRUE)
  X <- data.frame(ideo = fifelse(is.na(d$ideo), mean(d$ideo, na.rm = TRUE), d$ideo), ideo_na = as.numeric(is.na(d$ideo)),
                  sexo = d$sexo, edad = d$edad, rec = factor(fcase(d$rec_final %in% c(1, 2, 3, 4), as.character(d$rec_final),
                  d$rec_final == 0, "ABST", default = "OTRO")))
  for (l in lid) { v <- d[[l]]; X[[l]] <- fifelse(is.na(v), mean(v, na.rm = TRUE), v); X[[paste0(l, "_na")]] <- as.numeric(is.na(v)) }
  y <- d$int; fr <- table(y[dec]); cl <- names(fr)[fr >= 25]; yc <- fifelse(y %in% cl, y, "RESTO")
  aj <- multinom(factor(yc[dec]) ~ ., data = X[dec, , drop = FALSE], weights = d$peso[dec] / mean(d$peso[dec]),
                 trace = FALSE, maxit = 300, decay = 0.01)
  p <- predict(aj, newdata = X[und, , drop = FALSE], type = "probs")
  if (is.null(dim(p))) p <- matrix(p, nrow = sum(und), dimnames = list(NULL, aj$lev))
  tot <- tapply(d$peso[dec], factor(y[dec], VALIDO), sum); tot[is.na(tot)] <- 0
  imp <- colSums(p * d$peso[und])
  resto <- setdiff(VALIDO, cl)
  if ("RESTO" %in% names(imp) && sum(tot[resto]) > 0) tot[resto] <- tot[resto] + imp[["RESTO"]] * tot[resto] / sum(tot[resto])
  com <- intersect(names(imp), cl); tot[com] <- tot[com] + imp[com]
  100 * tot / sum(tot)
}
estimar <- function(d, m4 = TRUE) {
  vp <- votante_probable(d)
  out <- list(
    MIC = { ok <- d$final %in% VALIDO; s <- tapply((d$peso * d$prob_est)[ok], factor(d$final[ok], VALIDO), sum); s[is.na(s)] <- 0; 100 * s / sum(s) },
    M1 = if (all(is.na(d$peso_demo))) NULL else reparto(d$int_sim, d$peso_demo),
    M2 = reparto(d$int_sim, d$peso),
    M3 = reparto(fifelse(vp, cascada(d), NA_character_), d$peso))
  if (m4) out$M4 <- tryCatch(modelo4(d), error = function(e) NULL)
  out
}
largo <- function(l) rbindlist(lapply(names(l), \(m) if (is.null(l[[m]])) NULL else data.table(modelo = m, partido = names(l[[m]]), est = as.numeric(l[[m]]))))

zips <- sort(list.files(DIR, pattern = "^microdatos-2026-\\d{2}\\.zip$", full.names = TRUE))
stopifnot(length(zips) > 0)
res <- rbindlist(lapply(zips, \(z) {
  mes <- sub(".*-(\\d{2})\\.zip$", "\\1", z)
  d <- preparar(leer(z))
  pt <- largo(estimar(d))
  idx <- function() sample.int(nrow(d), nrow(d), replace = TRUE)
  bs <- rbindlist(lapply(seq_len(B), \(b) largo(estimar(d[idx()], m4 = FALSE))[, b := b]))
  bs4 <- rbindlist(lapply(seq_len(B4), \(b) { r <- modelo4(d[idx()]); data.table(modelo = "M4", partido = names(r), est = as.numeric(r), b = b) }))
  iv <- rbind(bs, bs4)[, .(lo = quantile(est, .025), hi = quantile(est, .975)), by = .(modelo, partido)]
  vp <- votante_probable(d)
  cat(sprintf("%s: n=%d, votantes probables %.1f %%, indecisos entre ellos %.1f %%\n", mes, nrow(d),
              100 * sum(d$peso[vp]) / sum(d$peso), 100 * sum(d$peso[vp & d$int == "NSNC"]) / sum(d$peso[vp])))
  merge(pt, iv, by = c("modelo", "partido"), all.x = TRUE)[, `:=`(mes = paste0("2026-", mes), n = nrow(d))]
}))
fwrite(res, "salidas/mic_reestimacion.csv")
# Ancla del escenario «si acierta More in Common recalculado» (R/03 la lee de datos/anclas_microdatos.csv):
# M3 de la oleada más reciente, con sus fechas de campo (no vienen en el fichero: se toman de la publicación de MiC).
CAMPO_MIC <- list("2026-05" = NULL, "2026-07" = NULL, "2026-09" = NULL, "2026-10" = c("2026-10-21", "2026-10-25"))
ult <- max(res$mes); fechas <- CAMPO_MIC[[ult]]
if (is.null(fechas)) {
  warning("Oleada ", ult, " de More in Common sin fechas de campo en CAMPO_MIC: no se actualiza el ancla MiC_M3.")
} else {
  m3 <- res[mes == ult & modelo == "M3", setNames(round(est, 2), partido)]
  an <- fread("datos/anclas_microdatos.csv", encoding = "UTF-8", colClasses = list(character = c("inicio", "fin")))
  an <- an[casa != "MiC_M3"]
  mes_txt <- c("enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre")[as.integer(substr(ult, 6, 7))]
  an <- rbind(an, data.table(casa = "MiC_M3", cliente = paste("MiC", mes_txt, "reestimado"), inicio = fechas[1], fin = fechas[2],
    n = res[mes == ult, n[1]], modo = "online", PP = m3[["PP"]], PSOE = m3[["PSOE"]], VOX = m3[["VOX"]], FA = m3[["FA"]],
    POD = m3[["POD"]], SALF = m3[["SALF"]], fuente = "microdatos MiC, R/04_microdatos_mic.R",
    nota = "M3: votantes probables (9-10) + cascada; peso con recuerdo 23J"), fill = TRUE)
  fwrite(an, "datos/anclas_microdatos.csv")
  cat("Ancla MiC_M3 actualizada con la oleada", ult, "\n")
}
print(dcast(res[partido %in% c("PP", "PSOE", "VOX", "FA", "POD", "SALF")], mes + modelo ~ partido, value.var = "est")[
  , .(mes, modelo, PP = round(PP, 1), PSOE = round(PSOE, 1), VOX = round(VOX, 1), FA = round(FA, 1), POD = round(POD, 1), SALF = round(SALF, 1))])
