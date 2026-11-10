# Base provincial: resultados del 23J por circunscripción y escaños del 29N.
# Entrada: datos/raw_23J_adhni.csv (todas las candidaturas por provincia; BOE-A-2023-18907)
#          datos/raw_23J_jfmurciego.csv (partidos con escaño; se usa como contraste)
# Salida:  datos/base_23J.csv  (una fila por provincia, % sobre voto válido = candidaturas + blanco)
suppressPackageStartupMessages({ library(data.table) })

a <- fread("datos/raw_23J_adhni.csv", encoding = "UTF-8")
grupo <- function(p) fcase(
  p %in% c("PP"), "PP",
  p %in% c("PSOE", "PSC"), "PSOE",
  p %in% c("VOX"), "VOX",
  p %in% c("SUMAR"), "SUMAR",
  p %in% c("ERC"), "ERC",
  p %in% c("JUNTS"), "JUNTS",
  p %in% c("EH Bildu"), "BILDU",
  p %in% c("EAJ-PNV"), "PNV",
  p %in% c("BNG"), "BNG",
  p %in% c("CCa"), "CC",
  p %in% c("UPN"), "UPN",
  default = "OTROS")
a[, partido := grupo(candidate_party)]
v <- dcast(a[, .(votos = sum(votes)), by = .(district, partido)], district ~ partido, value.var = "votos", fill = 0)
tot <- unique(a[, .(district, formal = formal_votes, nulo_blanco = informal_votes, escanos_2023 = district_seats)])
b <- merge(tot, v, by = "district")

# Blanco ≈ 44 % de las papeletas no adscritas (en blanco 0,81 % y nulo ~1 % del total en el 23J). Aproximación:
# el fichero de origen junta blanco y nulo; solo afecta al umbral del 3 % y al denominador del voto válido.
b[, BLANCO := round(0.44 * nulo_blanco)]
b[, validos := formal + BLANCO]

ccaa <- c(
  "Almería"="AND","Cádiz"="AND","Córdoba"="AND","Granada"="AND","Huelva"="AND","Jaén"="AND","Málaga"="AND","Sevilla"="AND",
  "Huesca"="ARA","Teruel"="ARA","Zaragoza"="ARA","Asturias"="AST","Balears (Illes)"="BAL",
  "Palmas (Las)"="CAN","Santa Cruz de Tenerife"="CAN","Cantabria"="CANT",
  "Ávila"="CYL","Burgos"="CYL","León"="CYL","Palencia"="CYL","Salamanca"="CYL","Segovia"="CYL","Soria"="CYL","Valladolid"="CYL","Zamora"="CYL",
  "Albacete"="CLM","Ciudad Real"="CLM","Cuenca"="CLM","Guadalajara"="CLM","Toledo"="CLM",
  "Barcelona"="CAT","Girona"="CAT","Lleida"="CAT","Tarragona"="CAT",
  "Alicante/Alacant"="CVA","Castellón/Castelló"="CVA","Valencia/València"="CVA",
  "Badajoz"="EXT","Cáceres"="EXT","Coruña (A)"="GAL","Lugo"="GAL","Ourense"="GAL","Pontevedra"="GAL",
  "Madrid"="MAD","Murcia"="MUR","Navarra"="NAV","Araba/Álava"="PVA","Bizkaia"="PVA","Gipuzkoa"="PVA",
  "Rioja (La)"="RIO","Ceuta"="CEU","Melilla"="MEL")
stopifnot(all(b$district %in% names(ccaa)))
b[, ccaa := ccaa[district]]

# Escaños del 29N (RD 806/2026): Madrid 37 -> 38 y Cádiz 9 -> 8; resto como en 2023.
# Hay una fuente (ESdiario) que cita además Alicante, Valencia y Málaga +1 y Asturias, Badajoz y A Coruña -1;
# otras tres (Artículo14, ESdiario Andalucía, Diario de Avisos) solo Madrid y Cádiz. Ver ESCANOS_ALT en 03_escanos.R.
b[, escanos := escanos_2023]
b[district == "Madrid", escanos := 38L]
b[district == "Cádiz", escanos := 8L]
stopifnot(sum(b$escanos) == 350, sum(b$escanos_2023) == 350)

partidos <- c("PP","PSOE","VOX","SUMAR","ERC","JUNTS","BILDU","PNV","BNG","CC","UPN","OTROS","BLANCO")
for (p in partidos) b[, (paste0("s_", p)) := 100 * get(p) / validos]

# Contraste con el segundo fichero (partidos con escaño)
j <- fread("datos/raw_23J_jfmurciego.csv", encoding = "UTF-8")
tot_j <- j[, .(votos = sum(votos)), by = partido]
tot_a <- data.table(partido = c("PP","PSOE","VOX","SUMAR","ERC","JUNTS"),
                    votos_a = sapply(c("PP","PSOE","VOX","SUMAR","ERC","JUNTS"), \(p) sum(b[[p]])))
chk <- merge(tot_a, tot_j[partido %in% tot_a$partido], by = "partido")
stopifnot(all(chk$votos_a == chk$votos))

nac <- b[, lapply(.SD, sum), .SDcols = c(partidos, "validos")]
cat("Voto válido estatal 23J (%):\n"); print(round(100 * unlist(nac[, ..partidos]) / nac$validos, 2))
fwrite(b[, c("district","ccaa","escanos","escanos_2023","validos", partidos, paste0("s_", partidos)), with = FALSE],
       "datos/base_23J.csv")
