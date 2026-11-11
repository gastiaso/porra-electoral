# Metodología

*Versión del 10 de noviembre de 2026. El método puede cambiar hasta el lanzamiento; los cambios posteriores quedarán registrados aquí con su fecha.*

*10-nov: error común ampliado y escenario «si fallan como en 2023» recalculado, ambos a partir de la comprobación con 2019 y 2023 (sección 6).*

## 1. Qué es y qué no es

Es una **media de encuestas publicadas**, corregida por el sesgo de cada empresa y convertida en escaños mediante simulación. No es una encuesta propia: no hay trabajo de campo. Tampoco es una predicción con garantías. Si las encuestas fallan juntas, como en 2023, la media falla con ellas. Por eso la portada enseña también qué pasaría con otros supuestos.

## 2. Encuestas

- Entran las estimaciones de voto publicadas desde finales de septiembre de 2026, con su empresa, cliente, fechas de campo, muestra y fuente (`datos/encuestas.csv`).
- Una empresa que publica un seguimiento diario acumulado entra **una sola vez**, con su última entrega, para no contar varias veces las mismas entrevistas.
- **SW Demoscopia** entra con una muestra efectiva de 1.000 entrevistas, menor que la declarada, por dos razones: acumula entrevistas día a día y hay dudas publicadas sobre su modo de entrevista (llamadas automáticas).
- Cifras, fechas de campo y muestras se toman de la [base de sondeos de Demócrata](https://www.democrata.es/elecciones-generales-espana/herramientas/encuestas), que enlaza cada estudio con su publicación original. Las pocas que no figuran allí salen de otras recopilaciones, citadas fila a fila; las discrepancias se anotan en la columna `nota`.
- **CIS:** no se usa su estimación publicada. Se usa una **reestimación propia sobre sus microdatos** (votantes probables más reparto de indecisos, modelo M3).

## 3. Agregador

- Cada partido (PP, PSOE, Vox, Frente Amplio, Podemos y SALF) tiene una tendencia diaria que puede cambiar de un día para otro (paseo aleatorio).
- Cada encuesta se descompone en cuatro partes: tendencia del día, sesgo de su empresa, error de muestreo y un error adicional que se estima con los datos.
- Los sesgos de empresa se suponen de **media cero entre las empresas privadas**, y en esa media cada empresa pesa lo mismo, publique mucho o poco. Es el supuesto que más pesa en el resultado.
- **SW Demoscopia y el CIS recalculado quedan fuera de esa referencia:** su sesgo se estima libremente, sin obligarlo a compensarse con el de las demás. Los paneles de Electomanía entran como una empresa privada más.
- Los sesgos pueden ser grandes en una empresa concreta sin arrastrar al resto (distribución de colas anchas).
- Se estima por MCMC (JAGS) y se proyecta hasta el 29 de noviembre: la incertidumbre crece con los días que faltan.

## 4. De votos a escaños

1. Se parte de los resultados del 23J en cada circunscripción y de los escaños del 29N (Madrid 38 y Cádiz 8; el resto, como en 2023).
2. El cambio estatal de cada partido se traslada a cada provincia como mezcla de dos reglas: proporcional y aditiva. Se añade una variación aleatoria por comunidad y por provincia.
3. El espacio de Sumar en 2023 se reparte entre Frente Amplio y Podemos, salvo en la Comunitat Valenciana y Canarias, donde concurren juntos.
4. Partidos de ámbito autonómico: su peso estatal se toma de las encuestas que los publican, con un 20 % de incertidumbre. Aliança Catalana no concurre a estas generales y no entra en el modelo.
5. Se suma un **error común de todas las encuestas** el día de la votación, de tamaño desconocido: desviación típica de 2 puntos en PP y PSOE, 1,5 en Vox, 1 en Frente Amplio y 0,7 en Podemos y SALF, calibrada con 2019 y 2023 (sección 6). PP y PSOE tienden a fallar en sentido contrario, y PP y Vox comparten votantes.
6. Ley D'Hondt con umbral del 3 % en cada circunscripción, 4.000 veces.

## 5. Escenarios

| Escenario | Supuesto |
|---|---|
| Media de las encuestas | El sesgo medio de las empresas privadas es cero |
| Si fallan como en 2023 | Se aplica el error que esta misma media tuvo el 23J (sección 6): el PP sobrestimado en 0,9 puntos, el PSOE infraestimado en 3,3, Vox sobrestimado en 0,8 y Sumar en 1,0 (para Frente Amplio y Podemos) |
| Si aciertan las de microdatos abiertos | Se toma la media del CIS y de More in Common, recalculados con el mismo modelo |
| Si acierta una empresa | Se toma su desviación respecto a la tendencia en sus fechas de campo |

## 6. Comprobación con 2019 y 2023

El mismo agregador, alimentado solo con las encuestas publicadas hasta el último día permitido antes del 10N de 2019 y del 23J de 2023 (sin el CIS ni agregadores de terceros) y proyectado al día de la votación (`R/09_backtest.R`). Voto en porcentaje sobre voto válido:

| Elección | Partido | Resultado | Media | Diferencia |
|---|---|---:|---:|---:|
| 10N 2019 | PSOE | 28,0 | 27,2 | +0,8 |
| | PP | 20,8 | 21,1 | −0,3 |
| | Vox | 15,1 | 13,8 | +1,3 |
| | Unidas Podemos | 12,9 | 12,3 | +0,6 |
| | Ciudadanos | 6,8 | 9,2 | −2,4 |
| 23J 2023 | PP | 33,1 | 34,0 | −0,9 |
| | PSOE | 31,7 | 28,4 | +3,3 |
| | Vox | 12,4 | 13,2 | −0,8 |
| | Sumar | 12,3 | 13,3 | −1,0 |

- La diferencia media fue de 1,1 puntos por partido en 2019 y de 1,5 en 2023. Corregir el sesgo de cada empresa apenas cambia el promedio simple de sus últimas encuestas: el error que pesa es el que comparten todas.
- Los intervalos del agregador por sí solo recogen 5 de los 9 resultados. Con el error común que se usaba hasta el 10 de noviembre (1,5 puntos en PP y PSOE, 1,2 en Vox, 0,5-0,8 en el resto), 7 de 9: quedaban fuera el PSOE en 2023 y Ciudadanos en 2019, por unas dos desviaciones. Con el actual (sección 4), 8 de 9; Ciudadanos sigue fuera.
- Nueve casos son pocos para calibrar con precisión. El error común puede seguir siendo corto para un partido que se hunde o despega en la última semana.

## 7. Límites conocidos

- Las reglas de traslado a provincias no recogen realineamientos territoriales nuevos.
- Los partidos autonómicos son muy inciertos, y el voto que deja libre Aliança Catalana en Cataluña solo está recogido en la medida en que ya lo reflejan las encuestas.
- La concurrencia de Podemos en las listas de ERC en Cataluña no está modelizada.
- El error común está calibrado con pocas elecciones (sección 6).

## 8. Última actualización

La ley electoral (LOREG, art. 69.7) prohíbe publicar, difundir o reproducir sondeos del 24 al 28 de noviembre. La última actualización es la del lunes 23 de noviembre; desde entonces no se añade ni se cambia ninguna cifra hasta el cierre de los colegios el 29N.
