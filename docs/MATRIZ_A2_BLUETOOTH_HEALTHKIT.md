# Estudio de implementación A2 → Bluetooth → Salud

Fecha de revisión: 31 de octubre de 2026. Firmware comunicado: `02.52.01.00-5982`.

## Alcance y resultado

El flujo para este proyecto es **reloj A2 → Bluetooth LE → SDK oficial Veepoo → adaptadores de Bridge → HealthKit → app Salud**. Bluetooth transporta los registros; HealthKit determina qué representación puede guardarse en Salud. El emparejamiento por sí solo no exporta el historial propietario.

Se revisaron las cabeceras y el ejemplo oficial del SDK 2.2.110.15, revisión `c1ec1363c659deaa483778315b86e680f8f81af0`, y el código Bridge en `3926ef6c35877855b0e42cbf37814ef10ee02c0b`. Los tres archivos de extracción/decodificación/escritura locales coinciden con esa revisión remota. Se consultó documentación oficial de Apple, incluida su representación DocC cuando la página HTML no expone el contenido.

**El SDK es multimodelo. La presencia de una propiedad no demuestra que este A2 la mida o transmita.** Deben registrarse las capacidades anunciadas tras autenticar el reloj y contrastarse con un registro real por familia. No se ha probado físicamente ningún dato en esta revisión. Este documento especifica implementación y pendientes; no añade nuevas funciones operativas a la app.

Estados usados: **D** = adaptador SDK→muestra local existente; **H** = escritor HealthKit existente; **A** = archivo original/visor, sin normalización automática; **P** = propuesta pendiente. D/H no significan transferencia real comprobada. Todas las muestras extraídas quedan sin verificar; la marca de verificación del usuario tampoco constituye validación clínica.

## 1. Obtención por Bluetooth

1. Usar un único propietario de la conexión: `VPBleCentralManage`. Autenticar, esperar disponibilidad del periférico y leer sus capacidades. No ejecutar simultáneamente el escáner de diagnóstico como segundo cliente del reloj.
2. Inspeccionar `fiveProtocolType`, `saveDays`, `sleepType`, `oxygenType`, `hrvType`, `ecgType`, `resRateType`, `temperatureType`, `bloodPressureType`, `bloodGlucoseType`, `bloodAnalysisType`, `bodyCompositionType`, `supportManualTestType` y las capacidades de deporte, estrés, GSR y MET. Cada enum tiene reglas propias: por ejemplo, `metType` 0 y 1 significan no disponible; no basta comprobar «distinto de cero» para todos.
3. Ejecutar la lectura general y las lecturas adicionales compatibles en serie, con identificador de operación, cancelación y tiempo máximo. La temperatura de tipo 5 usa la lectura general según el SDK. Consultar después `VPDataBaseOperation` por fecha y dirección del dispositivo.
4. Recuperar los manuales con `readManualTestData(withTimestamp:dataType:)` y la máscara anunciada. El código actual conserva su contenido. Un futuro cursor incremental solo avanza tras persistir toda la respuesta; usar solapamiento y deduplicación para soportar cortes y registros con la misma marca temporal.
5. Separar lectura histórica de medición activa: no iniciar sensores o inflado de un manguito para «sincronizar». No inventar servicios GATT, comandos ni escalas mediante ingeniería por semejanza.
6. Preservar texto de fecha y zona de registro. Los datos históricos `HH:mm` necesitan día y zona; los timestamps manuales necesitan confirmar época, segundos y tratamiento de zona contra el firmware. No sustituir una fecha ausente por la hora de descarga.
7. La app declara `bluetooth-central` y tiene reconexión de sesión. No se ha demostrado restauración tras terminación del proceso, cierre forzado o reinicio. Hace falta verificar qué restauración expone el SDK, además del comportamiento real de iOS.

## 2. Medidas fisiológicas

| Dato del reloj/SDK | Destino y representación | Conversión y condición | Estado actual / trabajo restante |
|---|---|---|---|
| Frecuencia cardíaca histórica `heartValue` | `heartRate`, latidos/min | Una muestra por instante documentado; conservar origen y contexto real | D+H. Falta prueba A2→Salud |
| FC manual `heartArray`, FC de microchequeo y FC de ECG | `heartRate` cuando haya unidad y ventana conocidas | Los arrays no documentan aquí la cadencia de cada elemento. No repartirlos inventando segundos; una media ECG describe su ventana, no múltiples instantes | A; adaptadores por canal pendientes |
| Tensión manual `h_bp`/`l_bp` | Dos cantidades mmHg dentro de `HKCorrelation(.bloodPressure)` | Misma lectura, fecha, dispositivo y método. Comprobar `testModel`, `protocol`, `state`, `credibility`; estados 2/9 advierten mala postura/movimiento | H de cantidades individuales; correlación y decodificador manual P |
| Tensión legacy `systolic`/`diastolic` | Mismo destino, después de resolver protocolo | El ejemplo oficial asigna 106 a `diastolic` y 71 a `systolic`. No intercambiar automáticamente por magnitud: requiere contrato del fabricante y registro contrastado | A; interpretación bloqueada por ambigüedad |
| SpO₂ histórica `OxygenValue` | `oxygenSaturation`, fracción | Porcentaje/100: 98 → 0,98. No guardar 98 con unidad fracción; invalidar ausentes/sentinelas | D+H. Manual `bloodOxygenArray` aún A |
| Frecuencia respiratoria | `respiratoryRate`, respiraciones/min | `resRateType` anuncia soporte. La cabecera de oxígeno advierte que los campos posteriores al valor no están presentes; ECG marca `aveResRate` temporalmente no válido. No usar esos campos por su nombre | H preparado; fuente efectiva, unidad y adaptador P |
| Temperatura corporal histórica `value` | `bodyTemperature`, °C | El SDK distingue temperatura corporal estimada de `originalValue`, temperatura superficial. Debe conservarse método y ubicación del sensor | D+H para `value`; ubicación/método físicos pendientes |
| Temperatura manual `bodyTemp`/`origTemp` | Corporal solo si su significado está documentado | Son uint16; la cabecera manual no especifica divisor. No aplicar /10 o /100 sin evidencia. Los modelos compuestos usan otros tipos | A; contrato de escala P |
| Temperatura cutánea/original | Conservar por separado en Bridge | No confundirla con temperatura central ni basal. `appleSleepingWristTemperature` es de solo lectura | A; no escritura a la tarjeta de temperatura nocturna Apple |
| Glucosa `bloodGlucoses`, `bloodSugarValue`, `bloodSugar` | Técnicamente existe `bloodGlucose` | Confirmar mg/dL o mmol/L, escala específica y método. Mantener nivel de riesgo separado del valor. Una estimación óptica no queda validada por un permiso ni por estar en rango | A; no se envía actualmente como glucemia medida |
| Índice de perfusión periférica | `peripheralPerfusionIndex`, fracción porcentual | Solo si aparece una medida PI identificada, con escala documentada. SpO₂, PWV y «carga cardíaca» no son PI | Tipo Apple existente; sin fuente A2 demostrada ni implementación |

Las comprobaciones de rango son filtros de formato, no demostraciones de exactitud. Un valor fuera del límite del adaptador debe conservarse en el archivo original con motivo de exclusión, no desaparecer como si nunca hubiera existido. Un número cero puede ser ausencia, fallo o valor válido según el campo; debe decidirse por contrato, no con una regla global.

## 3. ECG, intervalos y análisis cardíaco

| Dato | Implementación legítima | Límite y estado |
|---|---|---|
| Onda ECG `originalSignals`/`filterSignals` | Archivo completo y visor Bridge; calibrar con `getGainValue` y `convertToMvWithValue:ecgType:testType:gain:` cuando el tipo lo admita | Apple declara ECG de solo lectura. No se pueden crear `HKElectrocardiogram` de este reloj. A y visor existentes; calibración mV y prueba física P |
| Frecuencia de muestreo, derivación y duración ECG | Preservar `frequency`, `uploadFrequency`, `lead`, tipo y ventana; resolver significado por canal | No inventar 250/512 Hz. Visor actual usa frecuencia explícita admisible o índice de muestra; no declara mV |
| HRV genérico `hrvValue`, `aveHrv`, `hrvArray` | Mostrar como índice/HRV del fabricante con nombre exacto | No identifica automáticamente SDNN o RMSSD. A, sin convertir a SDNN |
| SDNN explícito `diseaseSdnn` | `heartRateVariabilitySDNN`, ms; ventana ECG, procedencia y versión de algoritmo | Informe `VPECGTestResutHandle.resultReportWithModel:` ofrece campo explícito. Confirmar acceso/licencia, resultado real y definición; no está conectado al escritor. H existe para muestras SDNN verificadas |
| RR históricos `hearts` | Adaptador de unidades por tabla; SDK documenta multiplicar cada elemento por 10 | No extender factor a `rrs` de ECG u otros arrays. Faltan tiempos, huecos, artefactos y clasificación NN verificados |
| SDNN derivado de NN | Desviación estándar de intervalos normales con método, duración y control de calidad | Núcleo numérico existente y probado; no clasifica latidos ni produce muestras automáticamente. Elegir y documentar convención del estimador; n−1 actual no demuestra equivalencia al fabricante |
| RMSSD `diseaseRmssd` o derivado NN | Conservar RMSSD separado; adaptar al identificador Apple únicamente con SDK/OS compatibles y semántica confirmada | DocC consultado publica `heartRateVariabilityRMSSD` con introducción 27.0; no explica todavía unidades ni tarjeta de recuperación. No está habilitado en la candidata |
| Serie de tiempos de latido | `HKHeartbeatSeriesBuilder`, offsets en segundos y `precededByGap` | Vía pública real; requiere comienzo exacto, continuidad/huecos y autorización. No contiene voltajes ni crea un ECG. P |
| QT, QRS, ST y amplitudes | Guardar con sus unidades en Bridge y en un informe exportable | No hay un tipo cantidad general equivalente en el catálogo consultado para cada parámetro. QRS/ST del informe usan escalas enteras ×100; no aplicar a canales distintos. A según registro recibido |
| PWV | Conservar velocidad de onda de pulso en Bridge, con escala y método | El informe declara m/s almacenado ×10. No es PI, presión, velocidad al caminar ni rigidez arterial de Apple. A |
| Lorenz/Poincaré e índices de diagnóstico | Vista/análisis propio claramente identificado, si se dispone de permisos del proveedor | No convertir índices de riesgo del fabricante en diagnósticos de Salud. Algunas funciones analíticas requieren acuerdo comercial según cabeceras |
| Recuperación cardíaca al minuto | `heartRateRecoveryOneMinute`, diferencia positiva entre pico de esfuerzo y FC un minuto después de acabar | Necesita entrenamiento identificado y ambas FC con tiempo real. No se deduce del HRV ni de su puntuación; P |
| FC en reposo / media caminando | `restingHeartRate` / `walkingHeartRateAverage` | Requieren contexto y método específicos. Ni mínimo diario ni promedio de toda FC son sustitutos; P |
| Fibrilación, avisos FC alta/baja/ritmo irregular | Avisos propios solo con algoritmo y evidencia adecuados | `atrialFibrillationBurden` y categorías Apple de avisos de ritmo consultadas son de solo lectura; no se rellenan desde un resultado Veepoo |

Un documento CDA, si en el futuro se genera correctamente, sería una representación documental distinta: no convierte un PDF en ECG ni desbloquea su tarjeta. No está implementado ni se recomienda fabricar un documento clínico para eludir restricciones.

## 4. Actividad, sueño y composición corporal

| Dato | Destino propuesto | Regla de implementación y estado |
|---|---|---|
| Pasos por media hora `stepValue` | `stepCount`, unidades enteras | D+H; intervalo de 30 minutos, sin sumar además el total diario |
| Distancia de marcha/carrera | `distanceWalkingRunning`, metros | H preparado. Tabla diaria `Dis` documentada km→m; `totalDis` deportivo documentado m. Elegir canal y evitar solapamiento; decodificador P |
| Calorías | `activeEnergyBurned`, kcal, solo energía activa | H preparado. Tabla diaria `Cal` dice kcal; deportiva `totalCal` dice cal. Confirmar con fabricante y A2 antes de convertir; distinguir gasto total, activo y basal. No tratar todos los campos como kcal |
| Deporte | `HKWorkout` con modalidad, inicio/fin, pausas y muestras asociadas | API histórica de running contiene modalidades y detalles por minuto. Mapear enum explícito; no fabricar GPS/ruta. Evitar sumar otra vez pasos/distancia/calorías ya exportados. A, constructor de entrenamiento P |
| Ritmo/velocidad deportiva | Velocidad compatible o resumen del entrenamiento | Confirmar unidad de `pace`, distancia efectiva, pausas y modo. No usar ritmo de carrera como velocidad de escaleras. A/P |
| MET manual `VPManualMetModel.value` | Candidato `physicalEffort` (MET) o metadato de MET medio de entrenamiento, si equivale | Apple tiene un tipo MET: no debe descartarse como inexistente. La cabecera manual solo dice entero; faltan escala, duración, equivalencia y prueba de autorización/escritura. A/P |
| Sueño ordinario | `sleepAnalysis.asleepUnspecified` por segmentos | D+H; `SLE_LINE` de cinco minutos, no exportar despierto como dormido |
| Sueño preciso | `sleepAnalysis` por segmentos | D+H para `sleepType == 1`. El SDK también anuncia tipo 3; el extractor actual no lo procesa. Confirmar representación del tipo 3 y añadir su rama con pruebas |
| Profundo, ligero, REM, despierto | Categorías Apple `asleepDeep`, `asleepCore`, `asleepREM`, `awake`, si hay equivalencia documentada | HealthKit admite fases de terceros: no exige algoritmo Apple. La app actual opta por sueño inespecífico. Ampliación posible preservando clasificación Veepoo; no asumir «insomnio» = despierto sin contrato |
| Calidad/puntuación de sueño, apnea/hipoxia | Indicadores originales en Bridge | No convertir puntuación en horas ni posibles eventos en un diagnóstico de apnea. Las cabeceras consultadas no garantizan los campos auxiliares de oxígeno |
| IMC `bmi` | `bodyMassIndex`, count | D+H; identificar derivado del perfil/algoritmo, no medición independiente |
| Grasa corporal `bodyFatPercentage` | `bodyFatPercentage`, fracción | D+H; porcentaje/100, conservar carácter estimado |
| Masa magra `leanBodyMass` | `leanBodyMass`, kg | D+H. Masa muscular y masa magra no son equivalentes |
| Peso/altura/sexo/edad del modelo de composición | Perfil, no nuevas mediciones | SDK declara peso/altura/sexo como entradas de perfil. H genérico de peso existe, pero no extrae de ahí un peso medido. Nunca reescribir peso/altura históricos al sincronizar una composición |
| Masa grasa, muscular, ósea; grasa subcutánea; tasas de músculo/esqueleto | Bridge con kg o % según propiedad | No existe un equivalente directo general por campo en el catálogo de cantidades consultado. No mapear hueso a densidad ni músculo a masa magra |
| Agua corporal `%`/kg y proteína corporal `%`/kg | Bridge, separados por dimensión | No son agua bebida ni proteínas ingeridas: no usar `dietaryWater` o `dietaryProtein` |
| Metabolismo basal `basalMetabolicRate` | Posible cálculo de `basalEnergyBurned` por intervalo, con método explícito | Una tasa no es energía acumulada. Confirmar kcal/día y vigencia antes de integrar; no escribir el mismo total en cada lectura. A/P |

## 5. Bioquímica, estrés y microchequeo

| Campo | Decisión |
|---|---|
| Colesterol total, HDL, LDL, triglicéridos | Conservar separado cada analito, unidades y método. Las cabeceras indican decimales, no bastan para concluir mg/dL o mmol/L. No hay tipos cantidad de lípidos sanguíneos en el catálogo consultado. `dietaryCholesterol` significa colesterol ingerido, no colesterol sanguíneo |
| Ácido úrico | Archivo/visor propio; no tiene tipo cantidad equivalente en el catálogo consultado. El valor y el nivel de riesgo se conservan por separado |
| Resultados de laboratorio FHIR | `HKClinicalRecord` es solo lectura. Crear JSON FHIR no habilita insertar análisis del reloj en la sección clínica |
| Estrés 0–100, fatiga 0–99 | Índices propios. No equivalen a ejercicio, gasto calórico, ansiedad o síntomas autodeclarados |
| Emoción −10…10 | Índice del fabricante. No convertir automáticamente a `HKStateOfMind`; un registro del estado de ánimo requiere que la persona exprese su experiencia con su semántica correspondiente |
| Riesgo de depresión 0–2 | No convertir a PHQ-9 ni a un diagnóstico. Tampoco derivar GAD-7 del estrés; ambas evaluaciones requieren sus respuestas y método |
| GSR/EDA | `electrodermalActivity` acepta conductancia real. `VPManualGSRModel` expone humedad cutánea, emoción, riesgo de depresión, activación simpática y cortisol; no expone conductancia en µS. El nombre GSR no basta para exportar EDA |
| Humedad cutánea 1–99 | Índice propio, no hidratación ingerida ni conductancia eléctrica |
| Activación simpática 1–99 | Índice propio, no SDNN/RMSSD ni presión |
| Cortisol `cortisolValue` | El SDK declara µg/L y rango, pero eso no demuestra medición de laboratorio. Archivo propio con método estimado; sin tipo cantidad equivalente consultado |
| Microchequeo/Health Glance | Contenedor de varias familias, no una medida única. Respetar `protocol`, `functionSupport`/`getFuncSupport`, distinguir valores de perfil y reutilizar adaptadores validados por campo. El SDK advierte que la composición en cierto modelo manual no está soportada actualmente por sus proyectos |
| «Riesgo cardíaco», miocarditis, enfermedad coronaria, arteriosclerosis, presión/fatiga de informe ECG | Resultados del algoritmo del proveedor, con versión y limitaciones. No crear diagnósticos ni registros clínicos, ni presentarlos como evaluación médica validada |

Ruido ambiental/auriculares, velocidad al subir/bajar escaleras, asimetría de marcha, tiempo de doble apoyo, VO₂ máx., minutos de pie y notificaciones Apple no se deducen de pasos o FC. No se ha encontrado una fuente A2 verificada para esos datos. Que Salud muestre una tarjeta no significa que el reloj tenga el sensor, el algoritmo o la posibilidad de escritura necesarios.

## 6. Diseño del adaptador y sincronización

Cada adaptador debe conservar: dispositivo seudonimizado; firmware y versión SDK; canal (histórico/manual/ECG/deporte); identificador original; inicio/fin; zona y texto temporal original; valor original y convertido; unidad; método; calidad/estado; versión de conversión; motivo de exclusión. Los campos desconocidos se archivan como desconocidos, no se les atribuye significado.

La identidad debe permitir reconocer un mismo evento recibido por dos vías sin fusionar por error dos mediciones distintas en el mismo segundo. La candidata deduplica fuente/tipo/intervalo y usa `HKMetadataKeySyncIdentifier` y versión 1. Es una base, pero todavía faltan política de prioridad entre canales, actualización de lecturas corregidas/versiones y decisión para eventos simultáneos. No se garantiza eliminar duplicados escritos por G Band u otra aplicación: tienen otra procedencia; hace falta configurar una sola app escritora por familia o conciliación explícita.

En presión se guardará la correlación, sin guardar además por separado sus cantidades contenidas. En actividades se elegirá una base temporal no solapada. En sueño no se sumarán total nocturno y sus fases. En porcentajes se distingue 0–100 de fracción 0–1.

Solicitar permisos solo para tipos realmente habilitados. La finalización satisfactoria del diálogo no implica autorización de cada tipo. Comprobar escritura, registrar resultado por muestra/familia, mantener reintentos sin duplicar y mostrar «recibido», «excluido» y «guardado en Salud» por separado. No prometer que la escritura de FC/SDNN rellene otras tarjetas que Apple calcula con sus propios criterios.

Privacidad: archivos propios protegidos y excluidos de copia, sin valores en registros públicos, secretos o direcciones del reloj en GitHub. La protección de los archivos de Bridge no demuestra que cada base de datos interna o dependencia del SDK tenga la misma política; hay que revisar almacenamiento real en el contenedor iOS y comportamiento de red. El borrado local y la revocación de permiso no borran automáticamente muestras ya guardadas en Salud: una función futura debe eliminar únicamente muestras de Bridge y comunicar su alcance.

## 7. Entregables pendientes y pruebas de aceptación

1. **Contrato de datos por canal:** unidades/divisores/cadencia/timestamps, sentinelas, estados, máscara de funciones; consultar al fabricante lo que no documenta. No requiere respuesta de Apple, pero algunas respuestas y licencias dependen de Veepoo.
2. **Desarrollo pendiente:** normalización manual; presión correlacionada; distancia y energía por canal; entrenamientos; sueño tipo 3 y fases; metadatos de sensor y calidad; actualizaciones y conciliación entre canales. Los escritores genéricos existentes no sustituyen esos adaptadores.
3. **Investigaciones condicionadas:** SDNN explícito del informe/licencia, NN/heartbeat series, RMSSD con SDK compatible, MET y basal. Cada una se habilita por evidencia; no por rellenar una pantalla.
4. **Pruebas automáticas necesarias al implementar:** fixtures del contrato, unidades por canal, DST/medianoche, arrays incompletos, fallos/cortes, estados de mala calidad, sesión duplicada, BP conjunta, muestras corregidas y permisos parciales. Los fixtures numéricos se etiquetan como pruebas; nunca como datos recibidos.
5. **Prueba física desde iPhone:** registrar capacidades, descargar sin exportar; cotejar valores/unidades/fechas con reloj y app del fabricante; habilitar una familia; comprobar en Salud fuente/valor/intervalo; repetir descarga; cortar Bluetooth y reintentar; verificar duplicados, errores y exclusiones. La precisión sanitaria requiere referencia y protocolo apropiados, más allá de comprobar transporte.
6. **Distribución:** compilación macOS remota y firma legítima/TestFlight desde cuenta del titular. No hace falta ordenador personal. La firma permite instalar; no cambia las API de solo lectura ni documenta unidades del reloj.

Evidencia previa de la candidata: código app `5dfae215df704ef39c88e69602ab5d4e93772318`; [Release con SDK oficial y paquete sin firma](https://github.com/Risego2000/VeepooHealthBridge/actions/runs/41174117548); [18 pruebas del núcleo, builds y capturas](https://github.com/Risego2000/VeepooHealthBridge/actions/runs/41174117581). Esas ejecuciones no prueban los adaptadores propuestos aquí, comunicación A2 ni escritura física en Salud. Este cambio es documental, sin cambios de binario ni nuevas pruebas ejecutadas.

## Fuentes primarias

- [SDK oficial y cabeceras fijadas](https://github.com/HBandSDK/iOS_Ble_SDK/tree/c1ec1363c659deaa483778315b86e680f8f81af0/iOS_sdk_source/Framework/2.2.XX.15/VeepooBleSDK.framework/Headers): `VPDataBaseOperation.h`, `VPPeripheralModel.h`, `VPPeripheralBaseManage.h`, `VPManual*.h`, `VPHealthGlanceTestModel.h`, `VPBodyCompositionValueModel.h`, `VPECGTestDataModel.h`, `VPECGTestResutHandle.h`, `VPDailyBloodAnalysisModel.h`.
- Apple: [guardar muestras](https://developer.apple.com/documentation/healthkit/saving-data-to-healthkit), [catálogo de cantidades](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier), [correlación de presión](https://developer.apple.com/documentation/healthkit/hkcorrelationtypeidentifier/bloodpressure).
- Apple: [ECG solo lectura](https://developer.apple.com/documentation/healthkit/hkelectrocardiogramtype), [SDNN](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilitysdnn), [RMSSD](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilityrmssd), [metadatos DocC RMSSD](https://developer.apple.com/tutorials/data/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilityrmssd.json).
- Apple: [series de latidos](https://developer.apple.com/documentation/healthkit/hkheartbeatseriesbuilder), [WWDC19 sobre su escritura](https://developer.apple.com/videos/play/wwdc2019/218/), [recuperación al minuto](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartraterecoveryoneminute), [FC en reposo](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/restingheartrate).
- Apple: [temperatura corporal](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/bodytemperature), [temperatura nocturna solo lectura](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/applesleepingwristtemperature), [glucosa](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/bloodglucose), [PI](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/peripheralperfusionindex), [EDA](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/electrodermalactivity).
- Apple: [MET/esfuerzo físico](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/physicaleffort), [categorías de sueño](https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis), [registros clínicos de solo lectura](https://developer.apple.com/documentation/healthkit/accessing-health-records), [estado de ánimo y cuestionarios](https://developer.apple.com/videos/play/wwdc2024/10109/).
- Apple: [carga de FA solo lectura](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/atrialfibrillationburden), [identidad de sincronización](https://developer.apple.com/documentation/healthkit/hkmetadatakeysyncidentifier), [versión de sincronización](https://developer.apple.com/documentation/healthkit/hkmetadatakeysyncversion).

Conclusión de ingeniería: es viable ampliar la transferencia de las mediciones compatibles y conservar los análisis restantes dentro de Bridge. No es demostrable hoy que este A2 genere todas las categorías del SDK, que todas tengan equivalente escribible en Salud o que únicamente falte la firma de Apple.
