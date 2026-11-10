# Evaluación con los resultados del 29N

`R/10_evaluacion.R` compara el resultado con lo último que se publicó antes de la veda y genera `web/datos/evaluacion.json`, que lee `web/evaluacion.html` («¿En qué acertamos y en qué no?»). Mientras ese JSON no existe, la página solo anuncia que la evaluación se publicará cuando haya resultados.

## La noche electoral

Desde la raíz del proyecto:

```
cp datos/resultados_29N_plantilla.csv       datos/resultados_29N.csv         # escaños por circunscripción
cp datos/resultados_29N_votos_plantilla.csv datos/resultados_29N_votos.csv   # voto estatal
# rellenar los dos ficheros
LC_ALL=C.UTF-8 Rscript R/08_resultados.R provisional    # corrige la porra
LC_ALL=C.UTF-8 Rscript R/10_evaluacion.R provisional    # evaluación
```

Con el escrutinio general se repiten los dos últimos comandos con `definitivo`. Si el escrutinio no llega al 100 % o falta algún escaño por asignar, la evaluación queda como provisional aunque se pida `definitivo`. Basta con uno de los dos ficheros: sin voto se evalúan los escaños; sin escaños, el voto.

Antes de ejecutarlo, `salidas/` debe contener las salidas de la última versión publicada antes de la veda (no se vuelve a ejecutar `ejecutar.R` después del 23 de noviembre). Si no coinciden con `web/datos/modelo.json`, el script avisa.

## Ficheros de entrada

**`datos/resultados_29N.csv`** (el mismo de la porra): `provincia,partido,escanos`, una fila por circunscripción y candidatura con escaño. Los nombres de circunscripción son los de `datos/base_23J.csv`; los códigos, `PP, PSOE, VOX, FA, POD, SALF, ERC, JUNTS, BILDU, PNV, BNG, CC, UPN, AC, OTROS` (cualquier otro código cuenta como `OTROS`).

**`datos/resultados_29N_votos.csv`**: `ambito,partido,pct`, en porcentaje sobre voto válido (candidaturas más blanco) y con dos decimales.

- Filas `Estado`: una por candidatura, más `BLANCO` (voto en blanco; con él, la suma debe dar 100) y `_ESCRUTADO` (% escrutado). `OTROS` es el resto de candidaturas.
- Las listas conjuntas de Frente Amplio y Podemos (C. Valenciana y Canarias) cuentan como `FA`, igual que en el modelo.
- Opcional: filas con `ambito` igual al nombre de una circunscripción y el porcentaje de cada candidatura en ella (al menos todas las que pasan del 3 %). Sirven para saber quién se llevó el último escaño. El script comprueba que el reparto D'Hondt de esos porcentajes da los escaños del otro fichero; si no, no evalúa el último escaño de esa circunscripción.

## Qué se compara

- **Voto** (seis partidos de la media): resultado frente a la mediana del agregador proyectada al 29N y su intervalo del 90 %, con y sin el error común que usa la simulación (desviación típica de 2 puntos en PP y PSOE, 1,5 en Vox, 1 en Frente Amplio y 0,7 en Podemos y SALF; intervalo normal de ±1,645 desviaciones, como en `R/09_backtest.R`). También frente al promedio simple de la última encuesta de cada empresa (sin la reestimación del CIS). Los partidos que no entran en el agregador se comparan con el voto fijo que les asigna `R/03_escanos.R`.
- **Escaños**: resultado frente a la mediana y el intervalo del 90 % del escenario central; mediana de cada escenario y su desvío (suma de diferencias sin signo en PP, PSOE, Vox y Frente Amplio); probabilidad que daba cada escenario al desenlace real de la mayoría de PP y Vox.
- **Circunscripciones**: si el reparto más repetido en las simulaciones coincide con el real, cuántos escaños fueron a otro partido (la mitad de la suma de diferencias sin signo), probabilidad del reparto exacto de los dos primeros partidos y, con voto provincial, si el último escaño fue para el favorito de `salidas/ultimo_escano.csv`. Se dan también los aciertos esperables según las propias probabilidades del modelo.
- **Empresas**: diferencia entre el resultado y la última estimación publicada por cada una en PP, PSOE, Vox y Frente Amplio, por orden alfabético; aparte, las dos reestimaciones propias con microdatos.

Todas las diferencias son resultado menos estimación: positivas si el partido sacó más.

## Salidas

`salidas/evaluacion_voto.csv`, `evaluacion_escanos.csv`, `evaluacion_escenarios.csv`, `evaluacion_provincias.csv`, `evaluacion_casas.csv` y `web/datos/evaluacion.json`. Para probar con otros ficheros sin tocar `datos/` ni `web/datos/`: variables `VOTOS`, `ESCANOS`, `DESTINO` (carpeta de los CSV) y `JSON`.
