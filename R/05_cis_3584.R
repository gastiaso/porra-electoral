# CIS preelectoral 3584 (≈45.000 entrevistas, campo 7-oct a 7-nov). ESTADO: pendiente de publicación.
# Ruta prevista (reestimación propia del CIS con los modelos M1-M4; su código se incorporará a este repositorio):
#   1) Copiar MD3584.zip a datos/raw/ del repo y añadir el estudio al inventario/crosswalk (es un preelectoral: revisar
#      que INTENCIONG / VOTOSIMG / RECUERDO / escala de probabilidad de voto tienen los mismos códigos que el barómetro).
#   2) targets::tar_make() y Rscript estimacion/modelos.R  ->  estimacion/resultados_modelos.csv con el estudio 3584.
#   3) Este script toma M3 (y M2/M4 como sensibilidad) del 3584 y lo añade a datos/encuestas.csv como casa «CIS_M3»
#      con su ventana de campo real; la entrada del 3582 (octubre) se mantiene como observación anterior de la misma casa.
# Con 45.000 entrevistas su varianza muestral es mínima: lo que pesa es el efecto casa (libre, fuera de la restricción),
# por eso conviene usar también las ponderaciones provinciales (PESOPROV) para contrastar el swing provincial del 03.
suppressPackageStartupMessages({ library(data.table) })
f <- Sys.getenv("RESULTADOS_MODELOS", "datos/cis_modelos_M1_M4.csv")
r <- fread(f)[estudio == 3584]
if (!nrow(r)) stop("El 3584 aún no está en ", f, ": ver pasos 1-2 de la cabecera.")
r[partido %in% c("SUMAR", "FRENTE_AMPLIO"), partido := "FA"]; r[partido == "PODEMOS", partido := "POD"]
m3 <- r[modelo == "M3", .(est = sum(est)), by = partido]
fila <- data.table(casa = "CIS_M3", cliente = "CIS 3584 reestimado", inicio = "2026-10-07", fin = "2026-11-07", n = 45000,
  modo = "mixto", PP = m3[partido == "PP", est], PSOE = m3[partido == "PSOE", est], VOX = m3[partido == "VOX", est],
  FA = m3[partido == "FA", est], POD = m3[partido == "POD", est], SALF = m3[partido == "SALF", est],
  fuente = "reestimación propia del CIS (M1-M4)", nota = "M3 sobre el preelectoral; n real, campo de un mes")
e <- fread("datos/encuestas.csv", encoding = "UTF-8")
fwrite(rbind(e[!(casa == "CIS_M3" & inicio == "2026-10-07")], fila), "datos/encuestas.csv")
print(fila)
