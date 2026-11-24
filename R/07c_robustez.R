# Comprobación de robustez: la media de las encuestas de los cinco días hasta el corte, frente a la del modelo.
# Ventana: punto medio de campo entre corte - 4 y corte, ambos incluidos (misma regla de punto medio que R/03 y R/07b),
# y la última encuesta de cada empresa. Entran todas las casas de datos/encuestas.csv, CIS y SW incluidos; CIS_M3 no,
# porque es una reestimación propia. Dos versiones: media simple y restando a cada encuesta el efecto casa del modelo
# (salidas/efectos_casa.csv, y = tendencia + efecto casa + error).
# Escribe salidas/robustez_5dias.csv y reescribe la nota entre <!-- robustez --> y <!-- /robustez --> en
# docs/metodologia.md y web/metodologia.html. Lo llama actualizar.R después de R/07b. Si algo falla, avisa y no para:
# es una nota de la metodología, no un dato de la web.
suppressPackageStartupMessages({ library(data.table) })

tryCatch({
  P <- c(PP = "PP", PSOE = "PSOE", VOX = "Vox", FA = "Frente Amplio")
  MESES <- c("enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre",
             "noviembre", "diciembre")
  e <- fread("datos/encuestas.csv", encoding = "UTF-8", colClasses = list(character = c("inicio", "fin")))
  corte <- as.Date(Sys.getenv("CORTE", as.character(max(as.Date(e$fin)))))
  desde <- corte - 4

  # Nombres legibles: los de NOMBRE_CASA en R/07b, sin ejecutar el resto de ese script
  NOMBRE_CASA <- character()
  for (x in parse("R/07b_exportar_extra.R", encoding = "UTF-8"))
    if (is.call(x) && identical(x[[1]], as.name("<-")) && identical(x[[2]], as.name("NOMBRE_CASA"))) NOMBRE_CASA <- eval(x[[3]])
  nombre <- function(cs) ifelse(cs %in% names(NOMBRE_CASA), NOMBRE_CASA[cs], cs)

  e[, medio := as.Date(inicio) + round((as.Date(fin) - as.Date(inicio)) / 2)]
  w <- e[casa != "CIS_M3" & medio >= desde & medio <= corte][order(casa, medio, fin)][, .SD[.N], by = casa]
  h <- dcast(fread("salidas/efectos_casa.csv")[partido %in% names(P)], casa ~ partido, value.var = "efecto")
  serie <- fread("salidas/agregador_serie.csv")[as.Date(fecha) == corte]
  modelo <- round(setNames(serie$med, serie$partido)[names(P)], 1)

  simple <- round(sapply(names(P), \(p) mean(w[[p]], na.rm = TRUE)), 1)
  wc <- merge(w[, c("casa", names(P)), with = FALSE], h, by = "casa", suffixes = c("", ".h"), all.x = TRUE)
  corregida <- round(sapply(names(P), \(p) mean(wc[[p]] - wc[[paste0(p, ".h")]], na.rm = TRUE)), 1)

  fwrite(data.table(corte = as.character(corte), desde = as.character(desde), version = rep(c("simple", "corregida", "modelo"), each = length(P)),
                    partido = rep(names(P), 3), valor = c(simple, corregida, modelo), encuestas = nrow(w),
                    casas = paste(w$casa, collapse = " ")), "salidas/robustez_5dias.csv")

  # ---------------------------------------------------------------- texto
  num <- function(x) formatC(x, format = "f", digits = 1, decimal.mark = ",")
  fecha <- function(d, mes = TRUE) paste0(as.integer(format(d, "%d")), if (mes) paste(" de", MESES[as.integer(format(d, "%m"))]))
  lista <- function(x) if (length(x) < 2) x else paste(paste(head(x, -1), collapse = ", "), "y", tail(x, 1))
  cifras <- function(v) lista(paste(P, num(v)))
  ventana <- if (format(desde, "%m") == format(corte, "%m")) sprintf("del %s al %s", fecha(desde, FALSE), fecha(corte)) else
    sprintf("del %s al %s", fecha(desde), fecha(corte))
  cab <- sprintf("Comprobación con las encuestas más recientes (corte del %s).", fecha(corte))
  if (nrow(w) == 0) {
    cuerpo <- sprintf("Ninguna encuesta tiene el punto medio de su campo en los cinco días hasta el corte (%s).", ventana)
  } else {
    d <- rbind(simple = simple - modelo, corregida = corregida - modelo)
    k <- which(abs(d) == max(abs(d)), arr.ind = TRUE)[1, ]
    cuerpo <- paste0(
      sprintf("Con solo las encuestas cuyo punto medio de campo cae en los cinco días hasta el corte, %s (%s: %s; la última de cada empresa; el CIS y SW Demoscopia entran como las demás si caen en esos días), ",
              ventana, if (nrow(w) == 1) "una" else nrow(w), lista(nombre(w$casa))),
      sprintf("la media simple da %s. Restando a cada encuesta el sesgo estimado de su empresa, %s. ", cifras(simple), cifras(corregida)),
      sprintf("La media del modelo ese día es %s. ", cifras(modelo)),
      if (max(abs(d)) < 0.05) "No hay diferencias. " else
        sprintf("La mayor diferencia es de %s puntos (%s, %s). ", num(max(abs(d))), P[colnames(d)[k[2]]],
                c(simple = "media simple", corregida = "media corregida")[rownames(d)[k[1]]]),
      "Con tan pocas encuestas, el resultado depende de qué empresas publicaron esos días.")
  }
  nota <- list(md = sprintf("**%s** %s", cab, cuerpo), html = sprintf("<strong>%s</strong> %s", cab, cuerpo))

  reescribir <- function(f, texto) {
    x <- paste(readLines(f, encoding = "UTF-8", warn = FALSE), collapse = "\n")
    if (!grepl("<!-- robustez -->", x, fixed = TRUE)) return(warning("sin marcas <!-- robustez --> en ", f, call. = FALSE))
    y <- sub("<!-- robustez -->.*?<!-- /robustez -->", paste0("<!-- robustez -->", gsub("\\", "\\\\", texto, fixed = TRUE), "<!-- /robustez -->"),
             x, perl = TRUE)
    writeBin(charToRaw(enc2utf8(paste0(y, "\n"))), f)
  }
  reescribir("docs/metodologia.md", nota$md)
  reescribir("web/metodologia.html", nota$html)

  cat(sprintf("Últimos 5 días (%s a %s, punto medio de campo): %d encuestas (%s)\n", desde, corte, nrow(w), paste(w$casa, collapse = ", ")))
  cat(sprintf("  simple     %s\n  corregida  %s\n  modelo     %s\n", cifras(simple), cifras(corregida), cifras(modelo)))
}, error = function(err) {
  cat("\nAVISO: la nota de robustez de la metodología NO se ha actualizado:", conditionMessage(err), "\n")
})
