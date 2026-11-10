# Valida datos/encuestas.csv antes de calcular nada. Los ERRORES paran; los AVISOS se muestran y se sigue.
# Uso (desde la raíz del proyecto):  Rscript R/00_validar_encuestas.R
#   CORTE=AAAA-MM-DD   fecha de corte (por defecto, el fin de campo más reciente del fichero)
#   ENCUESTAS=ruta     otro fichero (por defecto, datos/encuestas.csv)
# actualizar.R y ejecutar.R lo ejecutan siempre como primer paso.
suppressPackageStartupMessages({ library(data.table) })
`%||%` <- function(a, b) if (is.null(a)) b else a

validar_encuestas <- function(fichero = "datos/encuestas.csv", corte = "",
                              hoy = as.Date(format(Sys.time(), "%Y-%m-%d", tz = "Europe/Madrid")),
                              publicadas = "web/datos/encuestas.csv", nombres_web = "R/07b_exportar_extra.R") {
  COLS <- c("casa", "cliente", "inicio", "fin", "n", "modo", "PP", "PSOE", "VOX", "FA", "POD", "SALF", "fuente", "nota")
  PCT <- c("PP", "PSOE", "VOX", "FA", "POD", "SALF")
  DIA0 <- as.Date("2026-09-25")                       # primer día del agregador (R/02)
  MODOS <- c("tel", "online", "mixto", "IVR", "presencial")
  err <- character(); av <- character()
  E <- function(...) err <<- c(err, sprintf(...))
  A <- function(...) av <<- c(av, sprintf(...))
  fin_mal <- function() list(errores = err, avisos = av, datos = NULL, corte = corte, fichero = fichero)
  dm <- function(d) format(as.Date(d), "%d-%m")       # 2026-11-08 -> 08-11

  # ---------------------------------------------------------------- formato del fichero
  if (!file.exists(fichero)) { E("No existe %s.", fichero); return(fin_mal()) }
  lin <- readLines(fichero, encoding = "UTF-8", warn = FALSE)
  if (!length(lin)) { E("%s está vacío.", fichero); return(fin_mal()) }
  lin[1] <- sub("^﻿", "", lin[1])
  if (!all(validUTF8(lin))) {
    E("%s no está en UTF-8 (líneas %s). Guárdalo como «CSV UTF-8 (delimitado por comas)».", fichero,
      paste(head(which(!validUTF8(lin)), 5), collapse = ", "))
    return(fin_mal())
  }
  if (grepl(";", lin[1]) && !grepl(",", lin[1])) {
    E("El separador es «;» y debe ser «,». Pasa a menudo al guardar desde Excel en español: guarda como «CSV UTF-8» o edita el fichero con un editor de texto.")
    return(fin_mal())
  }
  ncamp <- count.fields(textConnection(lin), sep = ",", quote = "\"", blank.lines.skip = FALSE, comment.char = "")
  if (anyNA(ncamp)) { E("Hay comillas sin cerrar o un salto de línea dentro de una celda (cerca de la línea %d).", which(is.na(ncamp))[1]); return(fin_mal()) }
  vacias <- which(ncamp == 0 | !nzchar(trimws(lin)))
  if (length(vacias)) A("Líneas en blanco (%s): se ignoran, pero conviene borrarlas.", paste(vacias, collapse = ", "))
  malas <- setdiff(which(ncamp != ncamp[1]), vacias)
  if (length(malas)) {
    E("Estas líneas no tienen %d columnas como la cabecera: %s. Suele ser una coma dentro de la fuente o la nota sin comillas: escribe esa celda entre comillas dobles.",
      ncamp[1], paste(sprintf("%d (%d columnas)", malas, ncamp[malas]), collapse = ", "))
    return(fin_mal())
  }
  usar <- setdiff(seq_along(lin), vacias)
  if (length(usar) < 2) { E("%s no tiene ninguna encuesta.", fichero); return(fin_mal()) }
  e <- fread(text = lin[usar], colClasses = "character", na.strings = "", encoding = "UTF-8")
  linea <- usar[-1]                                    # número de línea en el fichero de cada fila de datos
  falta <- setdiff(COLS, names(e))
  if (length(falta)) { E("Faltan columnas: %s. La cabecera debe ser: %s", paste(falta, collapse = ", "), paste(COLS, collapse = ",")); return(fin_mal()) }
  sobra <- setdiff(names(e), c(COLS, "url"))
  if (length(sobra)) A("Columnas que el modelo no usa (se ignoran): %s.", paste(sobra, collapse = ", "))
  q <- function(i) sprintf("Línea %d (%s, %s a %s)", linea[i], e$casa[i], e$inicio[i], e$fin[i])

  # ---------------------------------------------------------------- celdas obligatorias y tipos
  for (cc in c("casa", "fuente")) for (i in which(is.na(e[[cc]]) | !nzchar(trimws(e[[cc]]))))
    E("%s: falta «%s»%s.", q(i), cc, if (cc == "fuente") " (cada fila cita de dónde salen las cifras)" else "")
  for (i in which(is.na(e$cliente))) A("%s: falta el cliente (medio). Si es publicación propia, escribe «propia».", q(i))
  for (i in which(!is.na(e$modo) & !e$modo %in% MODOS))
    A("%s: modo «%s» poco habitual (se usan: %s).", q(i), e$modo[i], paste(MODOS, collapse = ", "))

  f_ok <- function(x) !is.na(x) & grepl("^\\d{4}-\\d{2}-\\d{2}$", x) & !is.na(as.Date(x, format = "%Y-%m-%d"))
  for (cc in c("inicio", "fin")) for (i in which(!f_ok(e[[cc]])))
    E("Línea %d (%s): fecha de %s «%s» no válida. Formato AAAA-MM-DD, p. ej. 2026-11-08.", linea[i], e$casa[i], cc, e[[cc]][i])
  fechas_ok <- f_ok(e$inicio) & f_ok(e$fin)
  ini <- as.Date(ifelse(fechas_ok, e$inicio, NA)); fin <- as.Date(ifelse(fechas_ok, e$fin, NA))

  for (i in which(is.na(e$n) | !grepl("^[0-9]+$", e$n)))
    E("%s: muestra «%s» no válida. Escribe un número entero sin puntos de miles (1000, no 1.000).", q(i), e$n[i])
  n <- suppressWarnings(as.numeric(ifelse(grepl("^[0-9]+$", e$n), e$n, NA)))
  for (i in which(!is.na(n) & n <= 0)) E("%s: la muestra debe ser mayor que 0.", q(i))
  for (i in which(!is.na(n) & n > 0 & n < 300)) A("%s: muestra de solo %d entrevistas.", q(i), as.integer(n[i]))

  X <- sapply(PCT, \(p) {
    x <- trimws(e[[p]])
    for (i in which(!is.na(x) & !grepl("^[0-9]+(\\.[0-9]+)?$", x)))
      E("%s: %s = «%s» no es un número. Usa punto decimal (31.5, no 31,5) y deja la celda vacía si la casa no lo publica.", q(i), p, x[i])
    suppressWarnings(as.numeric(ifelse(grepl("^[0-9]+(\\.[0-9]+)?$", x), x, NA)))
  })
  if (is.null(dim(X))) X <- matrix(X, nrow = 1, dimnames = list(NULL, PCT))
  for (p in c("PP", "PSOE", "VOX")) for (i in which(is.na(e[[p]]))) E("%s: falta %s (todas las encuestas lo publican).", q(i), p)
  for (p in PCT) for (i in which(!is.na(X[, p]) & (X[, p] < 0 | X[, p] > 60)))
    E("%s: %s = %s fuera del rango 0-60.", q(i), p, X[i, p])
  suma <- rowSums(X, na.rm = TRUE)
  for (i in which(suma > 100)) E("%s: PP+PSOE+VOX+FA+POD+SALF suman %.1f (más de 100).", q(i), suma[i])
  for (i in which(suma < 70 & !is.na(X[, "PP"]))) A("%s: los seis partidos suman solo %.1f. ¿Falta una cifra o hay una errata?", q(i), suma[i])

  # ---------------------------------------------------------------- fechas
  if (!nzchar(corte)) corte <- if (any(fechas_ok)) as.character(max(fin, na.rm = TRUE)) else ""
  if (nzchar(corte) && !f_ok(corte)) { E("CORTE «%s» no es una fecha AAAA-MM-DD.", corte); corte <- "" }
  for (i in which(fechas_ok & ini > fin)) E("%s: el inicio de campo es posterior al fin.", q(i))
  for (i in which(fechas_ok & fin > hoy)) E("%s: el fin de campo es posterior a hoy (%s).", q(i), hoy)
  if (nzchar(corte)) for (i in which(fechas_ok & fin > as.Date(corte)))
    E("%s: el campo acaba después del corte (%s). Sube CORTE o quita la fila.", q(i), corte)
  medio <- ini + (fin - ini) / 2                       # mismo punto medio que el agregador
  for (i in which(fechas_ok & as.integer(round(medio - DIA0)) + 1L < 1L))
    E("%s: el punto medio del campo es anterior al %s, primer día del agregador.", q(i), format(DIA0, "%d-%m-%Y"))
  for (i in which(fechas_ok & fin - ini > 31)) A("%s: ventana de campo de %d días.", q(i), as.integer(fin[i] - ini[i]))

  # ---------------------------------------------------------------- duplicados y nombres de casa
  dup <- which(duplicated(e))
  for (i in dup) E("%s: fila repetida exactamente (ya está en la línea %d).", q(i), linea[which(do.call(paste, e) == do.call(paste, e[i]))[1]])
  clave <- paste(e$casa, e$inicio, e$fin)
  for (i in setdiff(which(duplicated(clave)), dup))
    E("%s: la misma entrega (casa y fechas) aparece dos veces, con cifras distintas (línea %d).", q(i), linea[match(clave[i], clave)])
  norm <- function(x) gsub("[^a-z0-9]", "", tolower(iconv(x, "UTF-8", "ASCII//TRANSLIT")))
  variantes <- split(unique(e$casa[!is.na(e$casa)]), norm(unique(e$casa[!is.na(e$casa)])))
  for (v in variantes[lengths(variantes) > 1])
    E("La misma casa está escrita de varias formas: %s. Usa siempre el mismo nombre o el modelo las tratará como empresas distintas.",
      paste0("«", v, "»", collapse = ", "))

  # casas que no estaban en la última publicación
  if (file.exists(publicadas)) {
    conocidas <- unique(c(fread(publicadas, encoding = "UTF-8", select = 1L)[[1]], "CIS_M3"))
    for (cs in setdiff(unique(e$casa[!is.na(e$casa)]), conocidas)) {
      parecida <- conocidas[norm(conocidas) == norm(cs)]
      if (length(parecida)) A("Casa «%s»: parece «%s», que ya está publicada. Usa exactamente el mismo nombre.", cs, parecida[1])
      else A("Casa nueva: «%s». Comprueba el nombre: entra en la media de las privadas (sesgo medio cero) y cambia un poco el resto.", cs)
    }
  }
  # la web usa el nombre largo de cada casa (si falta, R/07b muestra el código)
  if (file.exists(nombres_web)) {
    def <- Filter(\(x) is.call(x) && identical(x[[1]], as.name("<-")) && identical(x[[2]], as.name("NOMBRE_CASA")),
                  as.list(parse(nombres_web, keep.source = FALSE)))
    if (length(def) && is.call(def[[1]][[3]]) && identical(def[[1]][[3]][[1]], as.name("c"))) {
      sin_nombre <- setdiff(unique(e$casa[!is.na(e$casa)]), names(eval(def[[1]][[3]], baseenv())))
      if (length(sin_nombre))
        A("Sin nombre para la web: %s (la web mostrará el código). Añádelo a NOMBRE_CASA en %s (p. ej. %s = \"Nombre de la empresa\").",
          paste(sin_nombre, collapse = ", "), nombres_web, sin_nombre[1])
    }
  }

  # ---------------------------------------------------------------- solapes y saltos dentro de cada casa
  ok <- fechas_ok & !is.na(e$casa)
  for (cs in unique(e$casa[ok])) {
    id <- which(ok & e$casa == cs); id <- id[order(ini[id], fin[id])]
    if (length(id) < 2) next
    for (a in seq_along(id)[-length(id)]) for (b in (a + 1):length(id)) {
      i <- id[a]; j <- id[b]
      dias <- as.integer(min(fin[i], fin[j]) - max(ini[i], ini[j])) + 1L
      if (dias <= 0 || clave[i] == clave[j] || grepl("solape revisado", paste(e$nota[i], e$nota[j]), ignore.case = TRUE)) next
      A("Solape en %s: líneas %d (%s a %s) y %d (%s a %s) comparten %d día%s de campo. Norma: una entrega por ventana no solapada; de un tracking acumulado, solo la última. Si está revisado, escribe «solape revisado» en la nota.",
        cs, linea[i], dm(ini[i]), dm(fin[i]), linea[j], dm(ini[j]), dm(fin[j]), dias, if (dias > 1) "s" else "")
    }
    id <- id[order(fin[id], ini[id])]
    for (a in seq_along(id)[-1]) {
      i <- id[a - 1]; j <- id[a]
      for (p in PCT) if (!is.na(X[i, p]) && !is.na(X[j, p]) && abs(X[j, p] - X[i, p]) > 4)
        A("Salto de %+.1f puntos en %s de %s: %s (línea %d, campo hasta %s) frente a %s en su entrega anterior (hasta %s). Comprueba la cifra.",
          X[j, p] - X[i, p], p, cs, X[j, p], linea[j], dm(fin[j]), X[i, p], dm(fin[i]))
    }
  }
  list(errores = err, avisos = av, datos = e, corte = corte, fichero = fichero)
}

informar_validacion <- function(v) {
  cat(sprintf("Validación de %s\n", v$fichero %||% "las encuestas"))
  e <- v$datos
  if (!is.null(e) && nrow(e)) {
    f <- suppressWarnings(as.Date(e$fin, format = "%Y-%m-%d"))
    cat(sprintf("  %d encuestas de %d casas; último fin de campo: %s; corte: %s\n", nrow(e), uniqueN(e$casa),
                if (all(is.na(f))) "?" else format(max(f, na.rm = TRUE)), if (nzchar(v$corte)) v$corte else "?"))
  }
  for (x in v$avisos) cat(strwrap(x, 110, initial = "  AVISO  ", prefix = "         "), sep = "\n")
  for (x in v$errores) cat(strwrap(x, 110, initial = "  ERROR  ", prefix = "         "), sep = "\n")
  if (length(v$errores))
    stop(sprintf("%d error%s en las encuestas: corrige el fichero y vuelve a ejecutar.", length(v$errores),
                 if (length(v$errores) > 1) "es" else ""), call. = FALSE)
  cat(sprintf("  Sin errores%s.\n", if (length(v$avisos)) sprintf(" (%d aviso%s: revísalo%s, pero se sigue)",
      length(v$avisos), if (length(v$avisos) > 1) "s" else "", if (length(v$avisos) > 1) "s" else "") else ""))
  invisible(v)
}

informar_validacion(validar_encuestas(Sys.getenv("ENCUESTAS", "datos/encuestas.csv"), corte = Sys.getenv("CORTE", "")))
