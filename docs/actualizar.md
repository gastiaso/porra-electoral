# Actualizar la media cada día

Rutina hasta el **23 de noviembre**: añadir las encuestas nuevas, ejecutar un comando, revisar el resumen y publicar.

## 1. Añadir una encuesta

Abre `datos/encuestas.csv` con un editor de texto (o con Excel, guardando como «CSV UTF-8 (delimitado por comas)») y añade una fila al final por cada encuesta nueva.

| Columna | Qué poner |
|---|---|
| `casa` | Empresa, con el **mismo nombre** que ya usa el fichero: `40dB`, `AteneoDato`, `CelesteTel`, `Data10`, `DYM`, `EMAnalytics`, `GAD3`, `Hamalgama`, `IMOP`, `InvyMark`, `MoreInCommon`, `NCReport`, `SigmaDos`, `SocioMetrica`, `Sondaxe`, `SW`, `TargetPoint`, `Winston` |
| `cliente` | Medio que la publica (`propia` si la publica la empresa) |
| `inicio`, `fin` | Fechas del **trabajo de campo**, no de publicación, en formato `2026-11-12` |
| `n` | Muestra, sin puntos de miles (`1000`) |
| `modo` | `tel`, `online`, `mixto`, `IVR`, `presencial` o vacío |
| `PP`, `PSOE`, `VOX`, `FA`, `POD`, `SALF` | Estimación de voto publicada, con **punto decimal** (`31.5`). Vacía si no la publica. `FA` es Frente Amplio, `POD` Podemos y `SALF` Se Acabó La Fiesta |
| `fuente` | De dónde salen las cifras: `Demócrata (base de sondeos)` u otra recopilación o medio |
| `nota` | Lo que no sea evidente: supuestos, discrepancias entre fuentes, fecha de publicación |

- **De dónde tomar las cifras:** la [base de sondeos de Demócrata](https://www.democrata.es/elecciones-generales-espana/herramientas/encuestas), que da fechas de campo, muestra y enlace al original. Si la encuesta no está allí, se toma de otra recopilación o del medio y se cita en `fuente`.
- **En `nota`:** `n no publicada: se usa la habitual (1.000)`, `inicio de campo supuesto`, `PP 32,6 en algunas recopilaciones`, `publicada 3-nov`. Si la celda lleva comas, va entre comillas dobles.
- **Trackings acumulados** (Sigma Dos, SW, SocioMétrica…): una sola fila por ventana de campo no solapada. Si la entrega nueva incluye días de la anterior, **sustituye** esa fila (fechas, muestra y cifras) en vez de añadir otra, y anótalo: `tracking acumulado (incluye la entrega del 29-30 oct)`. SW entra con `n` = 1000.
- **CIS:** no se mete su estimación publicada. La fila `CIS_M3` es la reestimación propia (`R/05_cis_3584.R`).
- **Empresa nueva:** añade también su nombre para la web en `NOMBRE_CASA` de `R/07b_exportar_extra.R`; si no, la validación para.

## 2. Ejecutar

Desde la carpeta del proyecto:

```
Rscript actualizar.R
```

El corte es por defecto la fecha de fin de campo más reciente del fichero, y es la que sale en la portada («Media de encuestas a…»). Para fijarlo: `CORTE=2026-11-12 Rscript actualizar.R` (en Windows: `Rscript actualizar.R 2026-11-12`). Tarda unos 7 minutos y hace, por orden:

1. Valida `datos/encuestas.csv`. Los **errores** paran (fechas, números, columnas, duplicados, campo posterior al corte). Los **avisos** no paran, pero hay que leerlos: casa nueva, solape de ventanas de una misma casa, saltos de más de 4 puntos frente a su entrega anterior.
2. Guarda una copia de `web/datos/` en `salidas/copias/<fecha-hora>/`.
3. Recalcula: agregador (R/02), More in Common si hay un ZIP nuevo en `datos/mic/` (R/04), escaños (R/03), gráficos (R/06) y datos de la web (R/07 y R/07b).
4. Pasa las pruebas de publicación (`R/pruebas.R`).
5. Muestra el resumen de cambios y lo guarda en `salidas/ultima_actualizacion.txt`.

## 3. Revisar el resumen

- **Encuestas nuevas y retiradas:** deben ser exactamente las que has tocado.
- **Voto, escaños y probabilidades**, antes y ahora. Lo normal de un día para otro son décimas de voto y pocos escaños. `<<` marca un cambio grande (1 punto de voto, 5 escaños o 10 puntos de probabilidad): comprueba las cifras de la encuesta que lo provoca contra su fuente. Si están bien, el cambio es real.

Si todo cuadra, publica `datos/encuestas.csv` y `web/datos/` (commit y push).

## 4. Si algo falla

Si falla cualquier paso o prueba, `web/datos/` vuelve sola a la versión anterior y no hay nada que deshacer. El modelo que ha fallado queda en `salidas/modelo_fallido.json`.

| Mensaje | Qué hacer |
|---|---|
| `ERROR` en la validación | Corrige la línea que indica y vuelve a ejecutar |
| Convergencia del agregador (R-hat) | Revisa la última encuesta añadida (errata, solape). Volver a ejecutar da lo mismo, porque las semillas son fijas. Si los datos están bien, sube las iteraciones en `R/02_agregador.R`: `ajustar_agregador(..., burn = 40000, iter = 80000)` (tarda el doble) |
| Medias de voto razonables / lejos de la media simple | Casi siempre una errata en una encuesta (13.2 por 31.2) o una casa nueva con cifras extremas |
| 350 escaños, circunscripciones o 23J | Un cambio en `R/03_escanos.R` o en `datos/base_23J.csv` ha roto el reparto. No publiques; deshaz ese cambio |
| `modelo.json` no corresponde a `encuestas.csv` | El CSV ha cambiado después de calcular o el corte no cuadra: vuelve a ejecutar |
| Campos de la portada o de la porra | Se ha cambiado `R/07_exportar_json.R` o `web/js/` y no casan: alinéalos antes de publicar |

Para volver a mano a cualquier versión anterior: copia el contenido de `salidas/copias/<fecha-hora>/` en `web/datos/`. Las pruebas se pueden pasar solas con `Rscript R/pruebas.R`, y la validación con `Rscript R/00_validar_encuestas.R`.

## 5. Congelación del 23 de noviembre

La última actualización es la del **23 de noviembre, antes de las 23:59**, con corte 23-nov como mucho. Desde entonces `actualizar.R` se niega a ejecutarse y la web sigue en línea sin cambios hasta el 29N. Solo con `FORZAR=1` se salta la congelación, para un arreglo justificado.

## 6. Noche del 29N: resultados de la porra

1. Copia `datos/resultados_29N_plantilla.csv` como `datos/resultados_29N.csv`.
2. Rellena una fila por circunscripción y candidatura con escaño: `provincia,partido,escanos` (si una provincia reparte escaños entre varios partidos, repite la fila con cada uno). La provincia, tal como viene en la plantilla. Códigos de partido: `PP`, `PSOE`, `VOX`, `FA`, `POD`, `SALF`, `ERC`, `JUNTS`, `BILDU`, `PNV`, `BNG`, `CC`, `UPN` y `OTROS`. Las cifras, de la web oficial de resultados del Ministerio del Interior. **Borra las filas que sigan vacías** (provincias aún sin resultado): si se quedan, la porra da esas provincias por escrutadas con 0 escaños.
3. `Rscript R/08_resultados.R provisional` genera `web/datos/resultados.json`. Publícalo: la porra corrige sola los boletos. Repite a medida que avance el escrutinio; mientras falten circunscripciones lo dice al final.
4. Con los 350 escaños asignados se calcula también el juego de escaños. Al cerrar el escrutinio: `Rscript R/08_resultados.R definitivo`.

`actualizar.R` no interviene esa noche: la media sigue congelada.

## 7. Otro ordenador y archivo final

- Requisitos: R 4.3 o posterior, [JAGS 4](https://mcmc-jags.sourceforge.io/) (antes que el paquete `rjags`) y los paquetes de `DESCRIPTION`; en R: `install.packages(c("data.table", "jsonlite", "rjags", "mvtnorm", "ggplot2", "haven", "nnet"))`. `actualizar.R` lo comprueba al empezar.
- Archivo tras el 29N: `CITATION.cff` y `.zenodo.json` describen la versión congelada (1.0.0). Al publicarla, añade `date-released` en `CITATION.cff` y crea la versión en GitHub con la integración de Zenodo activada para obtener el DOI.
