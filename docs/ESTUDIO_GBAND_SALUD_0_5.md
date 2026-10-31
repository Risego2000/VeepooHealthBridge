# Diseño G Band e integración de datos cardíacos — 0.5

Fecha: 31 de octubre de 2026. Objetivo: A2 firmware comunicado 02.52.01.00-5982, iPhone y Apple Health.

## Referencia visual correcta

La referencia es **G Band**, App Store ID 6447599368, desarrollador Shenzhen Veepoo Technology. Se revisaron sus capturas oficiales mediante la ficha y el servicio de metadatos de Apple. Las imágenes proporcionadas por el usuario muestran la app Salud y sus permisos para G Band: no son el panel principal de G Band.

Se implementa una distribución inspirada en G Band con identidad Veepoo Bridge: fondo claro, acento naranja, anillo de pasos, resumen calorías/pasos/distancia, tarjeta de actividad azul, cuadrícula de salud y tres pestañas Salud/Dispositivo/Perfil. Historial, Apple Health, ECG/VFC y diagnóstico siguen accesibles. No se copian logotipos ni imágenes personales. Los valores vacíos permanecen vacíos; el objetivo configurable de pasos no se presenta como dato medido.

Referencia: https://apps.apple.com/app/id6447599368

## ECG: qué puede entrar en Salud

Apple documenta HKElectrocardiogramType como solo lectura: no se pueden crear muestras ECG en HealthKit desde esta app. Ni un certificado, ni un perfil con HealthKit, ni activar todos los permisos de G Band cambian esa API.

La vía implementada es conservar los originales del SDK y ofrecer un visor local de las muestras de filterSignals: hasta 2000 puntos por vista previa (se retienen hasta 40 vistas previas en memoria y se muestran 12 en esa pantalla; el archivo conserva el conjunto original), sin calibración clínica. Si uploadFrequency contiene una frecuencia explícita válida, el eje usa segundos; de lo contrario muestra índice de muestra. No se presupone 250/512 Hz ni se inventa escala en mV. El archivo privado conserva los datos completos. No se presenta una onda vacía o inventada como ECG recibido.

La cabecera del SDK ofrece convertToMvWithValue:ecgType:testType:gain: y getGainValue para una eventual escala calibrada. Antes de habilitarla hay que contrastar tipo de ECG, ganancia, frecuencia y resultado contra una grabación A2. La cabecera advierte de tipos sin adaptación que devuelven conversión cero. No se implementa un detector de arritmias ni se diagnostica a partir del trazado.

HealthKit dispone también de documentos CDA mediante HKCDADocumentSample. Se considera una vía documental a investigar, no un método demostrado para crear ECG: requiere XML CDA válido y no equivale a adjuntar un PDF arbitrario ni a rellenar la tarjeta Electrocardiogramas. No se ha desarrollado ni probado esta vía. No se fabrica un documento clínico, profesional sanitario o procedencia para eludir la limitación.

## VFC: hallazgos y opciones

### SDNN explícito del fabricante

La cabecera oficial VPECGTestResutHandle.h expone VPECGTestResultReportModle.diseaseSdnn (SDNN en ms) y diseaseRmssd (RMSSD). Existe resultReportWithModel: para obtener el informe. Esto proporciona una vía técnica concreta para investigar, distinta de renombrar aveHrv o hrvValue.

No se invoca automáticamente el módulo de análisis diagnóstico: la cabecera del modelo ECG indica restricciones para clientes de pago en las funciones de diagnóstico. Hay que confirmar acceso/licencia y que el A2 entregue el informe. La presencia de la propiedad en una cabecera no demuestra un resultado no vacío, unidades efectivas, fecha o validez del dispositivo. Esta integración de informe no está habilitada como lectura operativa ni como transferencia demostrada.

### Cálculo desde intervalos normales

El núcleo NNIntervalAnalysis implementa por separado SDNN muestral (n−1) y RMSSD. Exige unidades en milisegundos, confirmación expresa de latidos normales, continuidad, límites de tamaño, valores finitos y un mínimo de duración de 60 segundos. No clasifica automáticamente latidos, no filtra ectopias y no convierte cualquier RR en NN. No genera muestras HealthKit por sí mismo.

Las pruebas verifican diferencia SDNN/RMSSD, serie constante, datos inválidos, duración insuficiente y rechazo de series sin normalidad/continuidad confirmadas. Son pruebas numéricas con fixtures, no validación clínica ni prueba de extracción del A2.

Los intervalos `hearts` de la tabla HRV documentada por el SDK indican factor ×10. Eso no autoriza a aplicar el mismo factor a `rrs` de ECG o a arrays manuales sin documentar. Cada canal necesita un adaptador de unidades y marcas temporales contrastado con el firmware. No se asume que el SDK identifique intervalos normales.

### RMSSD y la nueva VFC de recuperación

La documentación oficial ya incluye heartRateVariabilityRMSSD, disponible desde iOS 27 según sus metadatos DocC. Corrige una generalización anterior: SDNN no es el único identificador de VFC publicado por Apple a esta fecha.

La página pública RMSSD consultada presenta la declaración y disponibilidad, sin discusión de unidades, agregación o correspondencia con la tarjeta «VFC de recuperación». No se supone que RMSSD sea SDNN ni se garantiza que escribir ese tipo rellene una tarjeta concreta. La candidata actual no declara esa escritura como operativa: usa el SDK de compilación disponible para CI y mantiene la escritura SDNN existente. Faltan compilación con SDK compatible, comprobación de autorización/escritura y prueba en el iPhone con datos reales.

Las apps de salud de terceros con autorización de lectura pueden consumir los tipos que Bridge haya escrito correctamente en HealthKit. No existe una transferencia universal de archivos ECG a cualquier app: hace falta un importador compatible y consentimiento del usuario.

Los heartbeat series son otra representación legítima de tiempos de latido: HKHeartbeatSeriesBuilder permite guardarlos. No contienen voltajes ECG y no equivalen a un electrocardiograma. Una integración necesitaría instantes, interrupciones y deduplicación contrastados; no se ha habilitado una carga de RR de unidades desconocidas.

## Resto de categorías: decisión por significado, no por icono

| Familia | Vía | Condiciones y estado |
|---|---|---|
| Pasos, FC, sueño, oxígeno, temperatura | Mapeos ya implementados | Verificar tipos, unidades, tiempo, sensor y duplicados con A2 |
| Distancia, energía activa y respiración | Tipos HealthKit preparados | No implica extracción A2 demostrada; falta semántica explícita por canal |
| Presión arterial | Tipos HealthKit disponibles | Los campos legacy son ambiguos; manual h_bp/l_bp permite investigación más precisa. Contrastar antes de convertir |
| Grasa/masa magra/IMC | Mapeo disponible | Identificar estimación y valores derivados del perfil; no inventar peso medido |
| Glucosa | Apple tiene tipo bloodGlucose | Un permiso activado no valida una estimación óptica del reloj; no se publica como glucemia medida |
| Ácido úrico, lípidos, QT, PWV, GSR, estrés, fatiga y MET | Archivo/visor local según datos recibidos | No se convierten a otra métrica solo por parecido de nombre o número |
| Ansiedad, depresión y estado de ánimo | Requieren sus datos/semántica propios | No se derivan de estrés/HRV como si fueran cuestionarios o diagnósticos |
| Ruido, auriculares, marcha/escaleras, carga de fibrilación y recuperación | No demostradas por A2 | No se rellenan tarjetas de Salud sin una fuente y un método adecuados |

## Evidencias y límites

Esta revisión debe validarse en sus propias ejecuciones de CI, independientemente de la 0.4. La vista ECG necesita datos reales del SDK para mostrar una onda: una captura vacía del simulador no prueba comunicación ni un trazado. No hay datos de salud personales en este documento público. Las capturas del usuario no se han subido al repositorio.

No se puede prometer «todos los datos en Salud» ni «solo falta una respuesta de Apple»: hay tipos de solo lectura, semánticas sin confirmar, restricciones del fabricante y pruebas físicas pendientes.

## Fuentes primarias

- Apple, ECG de solo lectura: https://developer.apple.com/documentation/healthkit/hkelectrocardiogramtype
- Apple, SDNN: https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilitysdnn
- Apple, RMSSD: https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilityrmssd
- Apple, series de latidos: https://developer.apple.com/documentation/healthkit/hkheartbeatseriesbuilder
- Apple, ejemplos de series: https://developer.apple.com/documentation/healthkit/reading-and-writing-healthkit-series-data
- Apple, documentos CDA: https://developer.apple.com/documentation/healthkit/hkcdadocumentsample
- Apple, glucosa: https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/bloodglucose
- SDK oficial, revisión fijada c1ec1363c659deaa483778315b86e680f8f81af0: https://github.com/HBandSDK/iOS_Ble_SDK

## Verificación de esta revisión

- Código de aplicación: `5dfae215df704ef39c88e69602ab5d4e93772318`.
- Release para iPhone con SDK oficial y empaquetado sin firma: https://github.com/Risego2000/VeepooHealthBridge/actions/runs/41174117548 — workflow correcto.
- 18 pruebas del núcleo, compilaciones y capturas: https://github.com/Risego2000/VeepooHealthBridge/actions/runs/41174117581 — tres capturas descargadas y revisadas (Salud, Dispositivo, Perfil).
- Las modificaciones posteriores del script de capturas y este informe no alteran el código de la app validado.
- No hay datos reales del A2, prueba de señal ECG, autorización efectiva de HealthKit ni firma del titular comprobados en esta ejecución. Las imágenes son estados vacíos reales del simulador.
