# Exporta los datos que consume la web (un único JSON; la web no calcula nada).
suppressPackageStartupMessages({ library(data.table); library(jsonlite) })
set.seed(13112026)
CORTE <- Sys.getenv("CORTE", "2026-11-08")
VEDA <- Sys.getenv("VEDA", "0") == "1"                   # interruptor manual: 24-28 nov
NOM <- c(PP = "PP", PSOE = "PSOE", VOX = "Vox", FA = "Frente Amplio", POD = "Podemos", SALF = "SALF", ERC = "ERC",
         JUNTS = "Junts", BILDU = "EH Bildu", PNV = "PNV", BNG = "BNG", CC = "CC", UPN = "UPN")
ORDEN_HEMI <- c("BILDU", "ERC", "POD", "FA", "BNG", "PSOE", "PNV", "CC", "JUNTS", "UPN", "PP", "VOX", "SALF")

r <- fread("salidas/agregador_resumen.csv"); s <- fread("salidas/agregador_serie.csv")
e <- fread("datos/encuestas.csv", encoding = "UTF-8")
E <- readRDS("salidas/escanos_central_draws.rds")
t <- fread("salidas/escanos_escenarios.csv"); u <- fread("salidas/ultimo_escano.csv")

media <- lapply(split(r, r$momento), \(x) setNames(lapply(seq_len(nrow(x)), \(i) list(
  mediana = round(x$mediana[i], 1), p05 = round(max(0, x$p05[i]), 1), p95 = round(x$p95[i], 1))), x$partido))
escanos <- setNames(lapply(colnames(E)[!colnames(E) %in% c("OTROS", "BLANCO")], \(p) list(
  nombre = NOM[[p]], mediana = median(E[, p]), p05 = unname(quantile(E[, p], .05)), p95 = unname(quantile(E[, p], .95)),
  p_al_menos_uno = round(mean(E[, p] >= 1), 3))), colnames(E)[!colnames(E) %in% c("OTROS", "BLANCO")])
der <- E[, "PP"] + E[, "VOX"]
# un reparto representativo (el sorteo más cercano a las medianas) para dibujar el hemiciclo
med <- apply(E, 2, median); rep_i <- which.min(rowSums(abs(sweep(E, 2, med))))
hemi <- E[rep_i, ORDEN_HEMI]; hemi <- hemi[hemi > 0]
ORDEN_TABLA <- c("PP", "PSOE", "VOX", "FA", "ERC", "BILDU", "PNV", "JUNTS", "BNG", "CC", "UPN", "POD", "SALF")
id_tiradas <- sample.int(nrow(E), 200)
tiradas <- cbind(n = id_tiradas, E[id_tiradas, ORDEN_TABLA])
en_juego <- u[order(-p)][, .(p1 = partido[1], q1 = p[1], p2 = partido[2], q2 = p[2], escanos = escanos[1]), by = provincia][order(q1)][1:12]

# Porra: probabilidad de 1, X y 2 en cada fila y de cada opción del pleno, según la media (escenario central)
porra <- jsonlite::fromJSON("datos/porra.json", simplifyVector = TRUE)
A <- readRDS("salidas/escanos_provincia_central.rds")
esc_amb <- function(amb, p) if (amb == "Congreso") E[, p] else A[, amb, p]
porra_media <- list(
  filas = lapply(seq_len(nrow(porra$filas)), \(i) { f <- porra$filas[i, ]
    x <- esc_amb(f$ambito, f$local); y <- esc_amb(f$ambito, f$visitante)
    list(id = f$id, p1 = round(mean(x > y), 3), pX = round(mean(x == y), 3), p2 = round(mean(x < y), 3)) }),
  pleno = setNames(lapply(seq_len(nrow(porra$pleno$opciones)), \(i) { o <- porra$pleno$opciones[i, ]
    round(mean(der >= o$min & der <= o$max), 3) }), porra$pleno$opciones$id))
# Juego de escaños: la media de cada partido, redondeada para que sume exactamente 350 (restos mayores)
reparto_350 <- function(m, total = 350) { b <- floor(m); r <- total - sum(b)
  if (r > 0) { o <- order(m - b, decreasing = TRUE)[seq_len(r)]; b[o] <- b[o] + 1 }; b }
porra_media$escanos <- as.list(c(reparto_350(colMeans(E[, ORDEN_TABLA])), OTROS = 0))
stopifnot(sum(unlist(porra_media$escanos)) == 350)

out <- list(
  meta = list(corte = CORTE, generado = format(Sys.time(), "%Y-%m-%d %H:%M"), veda = VEDA,
              encuestas = nrow(e[casa != "CIS_M3"]), casas = uniqueN(e[casa != "CIS_M3"]$casa),
              simulaciones = nrow(E), eleccion = "2026-11-29"),
  nombres = as.list(NOM),
  media = media,
  serie = s[, .(fecha = as.character(fecha), partido, med = round(med, 2), lo = round(lo, 2), hi = round(hi, 2))],
  encuestas = e[casa != "CIS_M3", .(casa, cliente, inicio, fin, n, PP, PSOE, VOX, FA, POD, SALF, fuente)],
  escanos = escanos,
  bloque_pp_vox = list(mediana = median(der), p05 = unname(quantile(der, .05)), p95 = unname(quantile(der, .95)),
                       p_mayoria = round(mean(der >= 176), 3)),
  hemiciclo = as.list(hemi),
  tiradas = as.data.table(tiradas),
  escenarios = t[, .(escenario, swing, PP, PSOE, VOX, p_mayoria = round(`P(PP+VOX>=176)`, 3),
                     p_psoe_primero = round(`P(PSOE>PP esc.)`, 3), p05 = `PP+VOX p05`, p95 = `PP+VOX p95`)],
  en_juego = en_juego[, .(provincia, escanos, p1, q1 = round(q1, 2), p2, q2 = round(q2, 2))],
  porra_media = porra_media
)
# Durante la prohibición (art. 69.7 LOREG, 24-28 nov) el JSON público no lleva ninguna cifra: solo el aviso.
if (VEDA) out <- list(meta = list(corte = CORTE, generado = format(Sys.time(), "%Y-%m-%d %H:%M"), veda = TRUE, eleccion = "2026-11-29"))
dir.create("web/datos", recursive = TRUE, showWarnings = FALSE)
file.copy("datos/porra.json", "web/datos/porra.json", overwrite = TRUE)   # reglas de la porra: sin cifras, también en veda
write_json(out, "web/datos/modelo.json", auto_unbox = TRUE, digits = NA, pretty = FALSE)
# Las encuestas también son sondeos: en veda se retira el CSV público.
if (VEDA) unlink("web/datos/encuestas.csv") else
  fwrite(e[casa != "CIS_M3", .(empresa = casa, medio = cliente, inicio, fin, muestra = n, modo, PP, PSOE, VOX, FA, POD, SALF, fuente, nota)],
         "web/datos/encuestas.csv")
cat("web/datos/modelo.json:", round(file.size("web/datos/modelo.json") / 1024), "KB\n")
