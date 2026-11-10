# Ejecuta el modelo completo y regenera los datos de la web. Para el día a día, mejor actualizar.R
# (valida, guarda copia, compara con la versión anterior y respeta la congelación del 23-nov).
# Uso (desde la raíz del proyecto):  Rscript ejecutar.R
#   Variables opcionales: NSIM (simulaciones por escenario, 4000) y CORTE (fecha de corte, AAAA-MM-DD;
#   por defecto, el fin de campo más reciente de datos/encuestas.csv).
# Requisitos: R >= 4.3, JAGS 4 instalado en el sistema y los paquetes de DESCRIPTION.
invisible(suppressWarnings(Sys.setlocale("LC_ALL", "C.UTF-8")))
if (!nzchar(Sys.getenv("NSIM"))) Sys.setenv(NSIM = "4000")
if (!nzchar(Sys.getenv("CORTE"))) Sys.setenv(CORTE = as.character(max(as.Date(
  data.table::fread("datos/encuestas.csv", select = "fin", colClasses = "character")$fin), na.rm = TRUE)))
cat("Corte:", Sys.getenv("CORTE"), "· simulaciones:", Sys.getenv("NSIM"), "\n")
paso <- function(f) { cat("\n==>", f, "\n"); t0 <- Sys.time(); source(f, local = new.env(), encoding = "UTF-8")
  cat(sprintf("    %.1f s\n", as.numeric(difftime(Sys.time(), t0, units = "secs")))) }
paso("R/00_validar_encuestas.R")
paso("R/01_base_23J.R")
paso("R/02_agregador.R")
if (length(list.files("datos/mic", pattern = "\\.zip$"))) paso("R/04_microdatos_mic.R") else
  cat("\n(sin ZIP de More in Common en datos/mic: se usa salidas/mic_reestimacion.csv tal cual)\n")
if (!file.exists("salidas/backtest.csv")) paso("R/09_backtest.R")   # el escenario B usa el error del agregador en el 23J
paso("R/03_escanos.R")
paso("R/06_graficos.R")
paso("R/07_exportar_json.R")
if (file.exists("R/07b_exportar_extra.R")) paso("R/07b_exportar_extra.R")
paso("R/pruebas.R")
