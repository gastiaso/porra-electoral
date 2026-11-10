# Porra Electoral

Media de encuestas y simulación de escaños para las elecciones generales del 29 de noviembre de 2026. Un proyecto de Guillermo Astiaso.

## Qué hace

1. **Agrega las encuestas publicadas.** Corrige el sesgo propio de cada empresa («efecto casa»), con la condición de que la media de las empresas privadas no tenga sesgo. Así obtiene la tendencia diaria de cada partido.
2. **Simula la elección.** Recrea 4.000 veces el resultado en las 52 circunscripciones (D'Hondt, umbral del 3 %), partiendo del 23J. Incluye un error común de todas las encuestas el día de la votación.
3. **Enseña cuánto depende el resultado del supuesto.** Además de la media, calcula escenarios: que las encuestas fallen como en 2023, que acierte una empresa concreta, o que acierten las dos encuestas con microdatos abiertos (CIS y More in Common), recalculadas con el mismo modelo.

La portada muestra la media de las encuestas. Los escenarios están en la misma página, porque la cifra central sola transmite más seguridad de la que hay.

## La porra

`web/porra.html` es un juego sin dinero: 14 «partidos» (duelos de escaños entre dos candidaturas, en el Congreso o en una circunscripción) más un pleno al 15 (escaños de PP + Vox) y, opcionalmente, el reparto de los 350 escaños por partido (gana el menor desvío absoluto sumado; desempata el 1-X-2 y solo se calcula cuando `resultados.json` trae `completo: true`). La porra se guarda en el navegador y viaja en el propio enlace: no hay servidor ni registro. Las reglas están en `datos/porra.json`. La noche electoral se corrige con `web/datos/resultados.json`, que genera `R/08_resultados.R` a partir de `datos/resultados_29N.csv` (plantilla en `datos/resultados_29N_plantilla.csv`).

## Estructura

```
datos/      encuestas (una fila por ventana de campo, con su fuente), resultados del 23J por provincia,
            reestimaciones propias del CIS y de More in Common
R/          00 validación de encuestas · 01 base provincial · 02 agregador (JAGS) · 03 escaños y escenarios
            04 More in Common desde microdatos · 05 CIS preelectoral · 06 gráficos · 07 exporta web/datos/modelo.json
            07b exporta casas.json, supuestos.json y encuestas.json · 08 resultados para la porra · 09 comprobación con 2019 y 2023
            10 evaluación tras el 29N · pruebas.R comprobaciones antes de publicar
salidas/    resultados intermedios (los sorteos completos no se versionan)
web/        sitio estático (portada, porra, supuestos, encuestas, encuestadoras, metodología, preguntas, evaluación):
            lee los JSON de web/datos/ y no calcula nada
docs/       metodología, preguntas frecuentes, guía de actualización diaria (actualizar.md) y de evaluación (evaluacion.md)
herramientas/ imágenes de vista previa en redes y dirección pública
```

## Ejecutar

```
Rscript actualizar.R                # el día a día: valida, recalcula, prueba y resume los cambios (≈7 min)
Rscript ejecutar.R                  # todo el modelo desde cero, sin copias ni resumen
VEDA=1 Rscript R/07_exportar_json.R # interruptor de reserva: JSON sin cifras (no se usa por defecto)
```

La guía paso a paso para añadir una encuesta y publicar está en `docs/actualizar.md`; la de la noche electoral y la evaluación, en `docs/evaluacion.md`. `actualizar.R` no recalcula después del 23 de noviembre salvo con `FORZAR=1`.

Requisitos: R ≥ 4.3, [JAGS 4](https://mcmc-jags.sourceforge.io/) y los paquetes `data.table`, `rjags`, `mvtnorm`, `jsonlite`, `ggplot2`, `haven` y `nnet`.

## Última actualización: 23 de noviembre

La ley electoral (LOREG, art. 69.7) prohíbe publicar, difundir o reproducir sondeos durante los cinco días anteriores a la votación, del martes 24 al sábado 28 de noviembre. La última actualización de la web es la del lunes 23; desde entonces no se añade ni se cambia nada hasta el cierre de los colegios el 29N. Queda un interruptor de reserva (`VEDA=1`) que publica la web sin cifras, por si hiciera falta retirarlas.

## Fuentes y licencias

- Código: [MIT](LICENSE).
- Tipografías: Archivo Black y Courier Prime, autoalojadas con licencia SIL Open Font License (`web/fuentes/`).
- Datos propios (agregados, simulaciones y reestimaciones): [CC BY 4.0](LICENCIA-DATOS.md).
- Las cifras de cada encuesta son de sus autores y medios, y se citan fila a fila en `datos/encuestas.csv`.
- Resultados del 23J: BOE-A-2023-18907.
- Los microdatos del CIS y de More in Common no se redistribuyen; se descargan de sus webs.

