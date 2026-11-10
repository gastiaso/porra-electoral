# Gráficos del informe: tendencia por partido (agregador) y escaños de PP+Vox por escenario.
suppressPackageStartupMessages({ library(data.table); library(ggplot2) })
TINTA <- "#1f1f1f"; TINTA2 <- "#6b6b6b"; REJILLA <- "#e6e6e3"
COL <- c(PP = "#1D5FA8", PSOE = "#D7263D", VOX = "#5A9E2F", FA = "#C2407D", POD = "#6B3FA0", SALF = "#A0522D")
NOMBRE <- c(PP = "PP", PSOE = "PSOE", VOX = "Vox", FA = "Frente Amplio", POD = "Podemos", SALF = "SALF")
tema <- theme_minimal(base_size = 11) + theme(
  text = element_text(colour = TINTA), axis.text = element_text(colour = TINTA2), panel.grid.minor = element_blank(),
  panel.grid.major.x = element_blank(), panel.grid.major.y = element_line(colour = REJILLA, linewidth = 0.3),
  strip.text = element_text(face = "bold", hjust = 0, colour = TINTA), plot.title = element_text(face = "bold"),
  plot.caption = element_text(colour = TINTA2, hjust = 0), legend.position = "none")

s <- fread("salidas/agregador_serie.csv"); s[, fecha := as.Date(fecha)]
e <- fread("datos/encuestas.csv", encoding = "UTF-8")
e[, medio := as.Date(inicio) + round((as.Date(fin) - as.Date(inicio)) / 2)]
el <- melt(e, id.vars = c("casa", "medio"), measure.vars = names(COL), variable.name = "partido", value.name = "v")[!is.na(v)]
el[, tipo := fifelse(casa %in% c("SW", "CIS_M3", "MoreInCommon"), casa, "otras")]
for (d in list(s, el)) d[, partido := factor(NOMBRE[as.character(partido)], levels = NOMBRE)]
s[, fase := fifelse(fecha <= as.Date(Sys.getenv("CORTE", "2026-11-08")), "datos", "proyección")]

g1 <- ggplot() +
  geom_ribbon(data = s, aes(fecha, ymin = lo, ymax = hi, fill = partido), alpha = 0.18) +
  geom_line(data = s[fase == "datos"], aes(fecha, med, colour = partido), linewidth = 0.7) +
  geom_line(data = s[fase == "proyección"], aes(fecha, med, colour = partido), linewidth = 0.7, linetype = "22") +
  geom_point(data = el[tipo == "otras"], aes(medio, v), colour = TINTA2, size = 1.1, alpha = 0.55) +
  geom_point(data = el[tipo != "otras"], aes(medio, v, shape = tipo), colour = TINTA, size = 2, stroke = 0.7) +
  scale_shape_manual(values = c(SW = 4, CIS_M3 = 2, MoreInCommon = 0)) +
  geom_vline(xintercept = as.Date(c("2026-10-28", "2026-11-29")), colour = TINTA2, linewidth = 0.3, linetype = "dotted") +
  scale_colour_manual(values = setNames(COL, NOMBRE)) + scale_fill_manual(values = setNames(COL, NOMBRE)) +
  facet_wrap(~partido, scales = "free_y", ncol = 3) +
  scale_x_date(date_labels = "%d-%b", breaks = as.Date(c("2026-10-01", "2026-10-28", "2026-11-29"))) +
  labs(title = "Agregador de encuestas: mediana y banda del 90 %", x = NULL, y = "% voto válido",
       caption = paste("Puntos grises: encuestas privadas. ✕ SW Demoscopia · △ CIS octubre reestimado (M3) · □ More in Common.",
                       "Línea discontinua: proyección al 29N. Punteadas: accidente de Urda (28-oct) y 29N.", sep = "\n")) +
  tema + theme(legend.position = "none")
ggsave("salidas/fig1_agregador.png", g1, width = 9, height = 5.6, dpi = 200, bg = "white")

t <- fread("salidas/escanos_escenarios.csv")
ETQ <- c("A_media_privadas mixto" = "Media de las privadas (central)", "A_media_privadas proporcional" = "Central · swing proporcional",
         "A_media_privadas aditivo" = "Central · swing aditivo", "B_correccion_23J mixto" = "Corrigiendo el error de la industria en el 23J",
         "C_ancla_CIS_M3 mixto" = "Si acierta el CIS de octubre reestimado (M3)", "D_ancla_MiC mixto" = "Si acierta More in Common (publicado)",
         "D2_ancla_MiC_M3 mixto" = "Si acierta More in Common reestimado (M3)", "F_ancla_microdatos mixto" = "Media CIS-M3 y MiC-M3 (microdatos abiertos)",
         "E_ancla_SW mixto" = "Si acierta SW Demoscopia")
t[, etiqueta := factor(ETQ[paste(escenario, swing)], levels = rev(ETQ))]
t[, med := PP + VOX]
g2 <- ggplot(t, aes(y = etiqueta)) +
  geom_vline(xintercept = 176, colour = TINTA2, linewidth = 0.4, linetype = "dashed") +
  geom_segment(aes(x = `PP+VOX p05`, xend = `PP+VOX p95`, yend = etiqueta), colour = COL[["PP"]], linewidth = 2, lineend = "round", alpha = 0.35) +
  geom_point(aes(x = med), colour = COL[["PP"]], size = 3) +
  geom_text(aes(x = `PP+VOX p95` + 2, label = fifelse(`P(PP+VOX>=176)` > 0.995, "> 99 %", sprintf("%.0f %%", 100 * `P(PP+VOX>=176)`))), hjust = 0, size = 3.3, colour = TINTA) +
  annotate("text", x = 176.5, y = 0.45, label = "mayoría absoluta (176)", size = 3, colour = TINTA2, hjust = 0, vjust = 0) +
  scale_x_continuous(limits = c(150, 222)) + coord_cartesian(clip = "off") +
  labs(title = "Escaños de PP + Vox según el supuesto", subtitle = "Punto: mediana de las simulaciones · barra: 90 % · cifra: probabilidad de llegar a 176",
       x = "escaños", y = NULL) + tema + theme(panel.grid.major.y = element_blank(), panel.grid.major.x = element_line(colour = REJILLA, linewidth = 0.3))
ggsave("salidas/fig2_escenarios.png", g2, width = 9, height = 5, dpi = 200, bg = "white")
cat("ok\n")
