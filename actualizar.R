# Actualización diaria (hasta el 23 de noviembre): valida las encuestas, recalcula, pasa las pruebas y resume
# qué ha cambiado frente a la versión anterior de la web. Guía: docs/actualizar.md
# Uso, desde la raíz del proyecto:
#   Rscript actualizar.R                     corte = el fin de campo más reciente de datos/encuestas.csv
#   CORTE=2026-11-12 Rscript actualizar.R    corte explícito (en Windows: Rscript actualizar.R 2026-11-12)
#   FORZAR=1 Rscript actualizar.R            salta la congelación (corte posterior al 23-nov o ejecución después)
#   NSIM=1000 Rscript actualizar.R           menos simulaciones, solo para ensayos (por defecto 4000)
# Tarda unos 7 minutos. Si falla cualquier paso o prueba, web/datos vuelve a la versión anterior.
invisible(suppressWarnings(Sys.setlocale("LC_ALL", "C.UTF-8")))
suppressPackageStartupMessages({ library(data.table); library(jsonlite) })
if (!file.exists("R/02_agregador.R")) stop("Ejecuta actualizar.R desde la carpeta del proyecto (la que contiene R/ y datos/).", call. = FALSE)

ULTIMO_CORTE <- as.Date("2026-11-23")
CONGELACION <- as.POSIXct("2026-11-23 23:59:59", tz = "Europe/Madrid")
PARTIDOS <- c("PP", "PSOE", "VOX", "FA", "POD", "SALF")
ORDEN <- c("PP", "PSOE", "VOX", "FA", "ERC", "BILDU", "PNV", "JUNTS", "AC", "BNG", "CC", "UPN", "POD", "SALF")
ESCENARIO <- c(A_media_privadas = "Si aciertan de media", B_correccion_23J = "Si fallan como en 2023",
               C_ancla_CIS_M3 = "Si acierta el CIS (M3)", D_ancla_MiC = "Si acierta More in Common",
               D2_ancla_MiC_M3 = "Si acierta MiC (M3)", F_ancla_microdatos = "Si aciertan las de microdatos",
               E_ancla_SW = "Si acierta SW")
t_inicio <- Sys.time()
hoy <- as.Date(format(t_inicio, "%Y-%m-%d", tz = "Europe/Madrid"))
es_fecha <- function(x) grepl("^\\d{4}-\\d{2}-\\d{2}$", x) & !is.na(as.Date(x, format = "%Y-%m-%d"))

# ------------------------------------------------------------------ requisitos
local({
  if (!file.exists("DESCRIPTION")) return(invisible())
  dep <- trimws(strsplit(gsub("\n", " ", read.dcf("DESCRIPTION", fields = "Imports")[1, 1]), ",")[[1]])
  pq <- sub("\\s*\\(.*", "", dep); minimo <- ifelse(grepl(">=", dep), sub(".*>=\\s*([^)]+)\\).*", "\\1", dep), NA)
  falta <- pq[!nzchar(vapply(pq, \(p) system.file(package = p), ""))]
  if (length(falta)) stop(sprintf("Faltan paquetes de R: %s. Instálalos con install.packages(c(%s)).", paste(falta, collapse = ", "),
                                  paste0("\"", falta, "\"", collapse = ", ")), call. = FALSE)
  viejos <- pq[mapply(\(p, v) !is.na(v) && packageVersion(p) < v, pq, minimo)]
  if (length(viejos)) cat("AVISO: versiones más antiguas que las de DESCRIPTION:", paste(viejos, collapse = ", "), "(debería funcionar; si falla, actualízalas)\n")
  v <- tryCatch(suppressMessages(rjags::jags.version()), error = function(e) NULL)
  if (is.null(v) || v < "4.0.0") stop("rjags no encuentra JAGS 4. Instálalo desde https://mcmc-jags.sourceforge.io/ y vuelve a probar.", call. = FALSE)
})

# ------------------------------------------------------------------ fecha de corte y congelación
args <- commandArgs(trailingOnly = TRUE)
corte <- if (any(grepl("^\\d{4}-", args))) args[grepl("^\\d{4}-", args)][1] else Sys.getenv("CORTE", "")
forzar <- Sys.getenv("FORZAR", "0") == "1" || "forzar" %in% tolower(args)
origen <- "indicado"
if (!nzchar(corte)) {
  fin <- tryCatch(fread("datos/encuestas.csv", select = "fin", colClasses = "character", encoding = "UTF-8")$fin, error = function(e) character())
  fin <- fin[!is.na(fin) & es_fecha(fin)]
  if (!length(fin)) stop("No se puede leer el fin de campo de datos/encuestas.csv: pasa el corte a mano (CORTE=AAAA-MM-DD).", call. = FALSE)
  corte <- as.character(max(as.Date(fin))); origen <- "el fin de campo más reciente"
}
if (!es_fecha(corte)) stop(sprintf("CORTE «%s» no es una fecha AAAA-MM-DD.", corte), call. = FALSE)
if (!forzar && as.Date(corte) > ULTIMO_CORTE)
  stop(sprintf("Congelación: el último corte publicable es el 23-nov y has pedido %s. La web se queda como está hasta el 29N. Para saltártelo a sabiendas: FORZAR=1.", corte), call. = FALSE)
if (!forzar && t_inicio > CONGELACION)
  stop("Congelación: la web no se actualiza desde el 23-nov a las 23:59 y sigue en línea sin cambios hasta el 29N. Para saltártelo a sabiendas: FORZAR=1.", call. = FALSE)
if (as.Date(corte) > hoy) stop(sprintf("CORTE %s es posterior a hoy (%s).", corte, hoy), call. = FALSE)
Sys.setenv(CORTE = corte)                              # lo leen R/02, R/07 y R/07b
if (!nzchar(Sys.getenv("NSIM"))) Sys.setenv(NSIM = "4000")

cat(sprintf("Actualización del %s · corte %s (%s)%s · %s simulaciones\n", hoy, corte, origen,
            if (forzar) " · FORZADA" else "", Sys.getenv("NSIM")))

# ------------------------------------------------------------------ pasos
restaurar <- function() invisible()                    # hasta que haya copia no hay nada que restaurar
paso <- function(f, nota = "") {
  cat(sprintf("\n==> %s%s\n", f, if (nzchar(nota)) paste0(" (", nota, ")") else ""))
  t0 <- Sys.time()
  tryCatch(source(f, local = new.env(), encoding = "UTF-8"), error = function(e) {
    restaurar()
    stop(sprintf("ha fallado %s: %s", f, conditionMessage(e)), call. = FALSE)
  })
  cat(sprintf("    %.0f s\n", as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}
paso("R/00_validar_encuestas.R")

# ------------------------------------------------------------------ copia de la web actual (tras validar)
copia <- file.path("salidas", "copias", format(t_inicio, "%Y%m%d-%H%M%S"))
dir.create(copia, recursive = TRUE, showWarnings = FALSE)
web_antes <- list.files("web/datos", full.names = TRUE)
invisible(file.copy(web_antes, copia, overwrite = TRUE))
anterior <- if (file.exists(file.path(copia, "modelo.json"))) fromJSON(file.path(copia, "modelo.json")) else NULL
restaurar <- function() {
  vuelta <- web_antes[!file.exists(web_antes) | tools::md5sum(web_antes) != tools::md5sum(file.path(copia, basename(web_antes)))]
  if (!length(web_antes)) return(cat("\nNo había versión anterior de web/datos que restaurar: no publiques web/datos.\n"))
  if (!length(vuelta)) return(invisible())
  if ("web/datos/modelo.json" %in% vuelta && file.exists("web/datos/modelo.json"))
    invisible(file.copy("web/datos/modelo.json", "salidas/modelo_fallido.json", overwrite = TRUE))
  invisible(file.copy(file.path(copia, basename(vuelta)), "web/datos", overwrite = TRUE))
  cat("\nweb/datos ha vuelto a la versión anterior", if ("web/datos/modelo.json" %in% vuelta)
    "(la que ha fallado está en salidas/modelo_fallido.json)", "\n")
}
cat(sprintf("\nCopia de web/datos en %s\n", copia))

if (!file.exists("datos/base_23J.csv")) paso("R/01_base_23J.R")
paso("R/02_agregador.R", "unos 4 minutos")
zips <- list.files("datos/mic", pattern = "\\.zip$", full.names = TRUE)
if (length(zips) && (!file.exists("salidas/mic_reestimacion.csv") || any(file.mtime(zips) > file.mtime("salidas/mic_reestimacion.csv")))) {
  paso("R/04_microdatos_mic.R", "ZIP nuevo de More in Common")
} else cat("\n(sin ZIP nuevo de More in Common en datos/mic: no se recalcula R/04)\n")
if (!file.exists("salidas/backtest.csv")) paso("R/09_backtest.R", "falta salidas/backtest.csv")
paso("R/03_escanos.R", "unos 3 minutos")
paso("R/06_graficos.R")
paso("R/07_exportar_json.R")
if (file.exists("R/07b_exportar_extra.R")) paso("R/07b_exportar_extra.R")
paso("R/pruebas.R")

# ------------------------------------------------------------------ resumen de cambios
resumen <- function(a, n) {
  out <- character(); L <- function(...) out <<- c(out, sprintf(...))
  marca <- function(d, umbral) if (!is.na(d) && abs(d) >= umbral) "  <<" else ""
  izq <- function(x, w = 40) paste0(x, strrep(" ", max(0, w - nchar(x))))   # sprintf cuenta bytes, no letras
  cab <- function(t) L("\n%s %6s  %6s  %7s", izq(t, 42), "antes", "ahora", "cambio")
  clave <- function(x) setdiff(names(x$media), "29-nov")[1]
  L("RESUMEN · corte %s · %d encuestas de %d casas · %s simulaciones", n$meta$corte, n$meta$encuestas, n$meta$casas, n$meta$simulaciones)
  if (is.null(a) || is.null(a$media)) { L("No hay versión anterior con cifras: nada que comparar."); return(out) }
  L("Frente a la versión anterior (corte %s, generada el %s; %d encuestas de %d casas)", a$meta$corte, a$meta$generado, a$meta$encuestas, a$meta$casas)
  ka <- paste(a$encuestas$casa, a$encuestas$inicio, a$encuestas$fin); kn <- paste(n$encuestas$casa, n$encuestas$inicio, n$encuestas$fin)
  linea_enc <- function(x, s) sprintf("  %s %s (%s), campo %s a %s, n = %s: PP %s · PSOE %s · Vox %s · FA %s", s, x$casa, x$cliente,
                                      x$inicio, x$fin, x$n, x$PP, x$PSOE, x$VOX, x$FA)
  nuevas <- n$encuestas[!kn %in% ka, , drop = FALSE]; quitadas <- a$encuestas[!ka %in% kn, , drop = FALSE]
  if (nrow(nuevas)) { L("\nEncuestas nuevas:"); for (i in seq_len(nrow(nuevas))) out <- c(out, linea_enc(nuevas[i, ], "+")) }
  if (nrow(quitadas)) { L("Encuestas retiradas:"); for (i in seq_len(nrow(quitadas))) out <- c(out, linea_enc(quitadas[i, ], "-")) }
  if (!nrow(nuevas) && !nrow(quitadas)) L("\nLas mismas encuestas que la versión anterior.")

  cab("Voto (%, media a la fecha de corte)")
  for (p in PARTIDOS) { x <- round(a$media[[clave(a)]][[p]]$mediana, 1); y <- round(n$media[[clave(n)]][[p]]$mediana, 1)
    L("  %s %6.1f  %6.1f  %+7.1f%s", izq(n$nombres[[p]]), x, y, y - x, marca(y - x, 1)) }
  cab("Escaños (mediana, escenario central)")
  for (k in ORDEN) { x <- round(a$escanos[[k]]$mediana); y <- round(n$escanos[[k]]$mediana)
    L("  %s %6.0f  %6.0f  %+7.0f%s", izq(n$nombres[[k]]), x, y, y - x, marca(y - x, 5)) }
  ba <- lapply(a$bloque_pp_vox, round); bn <- lapply(n$bloque_pp_vox, round)
  L("  %s %6.0f  %6.0f  %+7.0f%s", izq("PP + Vox"), ba$mediana, bn$mediana, bn$mediana - ba$mediana, marca(bn$mediana - ba$mediana, 5))
  L("  %s %3.0f-%3.0f %3.0f-%3.0f", izq("PP + Vox, 9 de cada 10", 39), ba$p05, ba$p95, bn$p05, bn$p95)

  cab("Probabilidades (%)")
  ea <- as.data.table(a$escenarios)[swing == "mixto"]; en <- as.data.table(n$escenarios)[swing == "mixto"]
  ca <- ea[escenario == "A_media_privadas"]; cn <- en[escenario == "A_media_privadas"]
  pr <- function(et, x, y) { x <- round(100 * x, 1); y <- round(100 * y, 1)
    L("  %s %6.1f  %6.1f  %+7.1f%s", izq(et), x, y, y - x, marca(y - x, 10)) }
  pr("Mayoría PP + Vox (central)", ca$p_mayoria, cn$p_mayoria)
  pr("PSOE por delante del PP (central)", ca$p_psoe_primero, cn$p_psoe_primero)
  for (id in setdiff(en$escenario, "A_media_privadas")) {
    x <- ea[escenario == id]$p_mayoria; if (!length(x)) x <- NA
    pr(paste("Mayoría:", if (id %in% names(ESCENARIO)) ESCENARIO[[id]] else id), x, en[escenario == id]$p_mayoria)
  }
  if (any(grepl("<<$", out))) L("\n<< cambio grande: comprueba la encuesta que lo provoca antes de publicar.")
  out
}
txt <- resumen(anterior, fromJSON("web/datos/modelo.json"))
cat("\n", paste(txt, collapse = "\n"), "\n", sep = "")
writeLines(txt, "salidas/ultima_actualizacion.txt")
cat(sprintf("\nListo en %.0f minutos. Resumen guardado en salidas/ultima_actualizacion.txt.\nSi todo cuadra, publica: datos/encuestas.csv y web/datos/ (commit y push).\n",
            as.numeric(difftime(Sys.time(), t_inicio, units = "mins"))))
