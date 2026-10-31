# Veepoo Health Bridge · informe de candidata 0.3.0

**Fecha:** 31 de octubre de 2026.  
**Repositorio:** https://github.com/Risego2000/VeepooHealthBridge  
**Dispositivo objetivo:** A2, firmware comunicado 02.52.01.00-5982.  
**Expediente Apple comunicado:** referencia reservada en la entrega privada. No se ha consultado su contenido o estado.

## 1. Resultado y criterio de aceptación

Se entrega una candidata nativa para pruebas, con código actualizado en GitHub, pruebas del núcleo y compilación del SDK de dispositivo. **No se declara la aplicación validada para uso final con el reloj.** No hay una instalación firmada, un ensayo físico con A2 ni una transferencia real a Salud acreditados en esta intervención.

La infraestructura de desarrollo puede ejecutarse remotamente: el usuario no necesita disponer de un ordenador personal. Esto no elimina las exigencias de firma, perfil y distribución de Apple.

## 2. Alcance de la revisión

Se revisaron las fuentes Swift, modelo y persistencia, HealthKit, el escáner CoreBluetooth, el puente Veepoo, configuración XcodeGen, plist, derechos, workflows de GitHub y Codemagic, documentación e integración de dependencias. Se contrastaron firmas y formatos con las cabeceras del SDK oficial fijado y con su demo.

El SDK es un binario de terceros. Revisar sus cabeceras y enlazarlo no equivale a auditar exhaustivamente su implementación interna, comportamiento de red, seguridad del firmware o exactitud sanitaria.

## 3. Cambios aplicados

### Integración real del fabricante

- Actualización de SDK 2.0.43.15 a **2.2.110.15**. La versión anterior no exponía las mismas categorías modernas.
- Revisión upstream fijada: `c1ec1363c659deaa483778315b86e680f8f81af0` de HBandSDK/iOS_Ble_SDK.
- Preparación común en `scripts/prepare-vendor.sh`; versiones explícitas de dependencias de CocoaPods.
- Enlace de frameworks de dispositivo y diferenciación entre bibliotecas estáticas y frameworks que deben embeberse.
- Corrección de etiquetas de callbacks Swift y de expresiones que el compilador no podía resolver.
- Eliminación del adaptador ficticio que solamente devolvía «no integrado».

### Conexión y gestión de lecturas

- Búsqueda y conexión oficial Veepoo, contraseña de cuatro cifras y espera de autenticación antes de leer.
- Reconexión de sesión configurable y persistente; desconexión manual.
- Protección frente a respuestas de autenticación tardías después de una desconexión manual.
- Lecturas adicionales por capacidad anunciada de oxígeno, HRV, temperatura y sesiones de actividad.
- Tratamiento particular de temperatura tipo 5, que la cabecera del fabricante integra en la lectura general.
- Exclusión de comandos simultáneos, progreso y desconexión al vencer el tiempo de espera de transferencia.
- Diagnóstico CoreBluetooth independiente con referencias de periféricos conservadas, limpieza de servicios, límites de búsqueda/conexión y descarte de callbacks de otro periférico.

### Datos, historial y presentación

- Interfaz SwiftUI con Resumen, Reloj, Historial, Salud y Ajustes, estados vacíos y sin datos de demostración.
- Historial local, importación/exportación JSON, revisión individual y gráficos de muestras reales almacenadas.
- Zona de registro seleccionable y formatos de fecha estrictos.
- Archivo sanitario privado de los datos presentes en la base SDK: originales, presión bruta, sueño ordinario/preciso, oxígeno, HRV, temperatura, actividad, ECG, composición corporal y estimaciones bioquímicas.
- Conservación de campos documentados de modelos ECG, composición corporal y sueño preciso, sin solicitar un diagnóstico al SDK ni atribuirles exactitud clínica.

### HealthKit y deduplicación

- Validación compartida entre importación, almacenamiento y salida: fechas, valores finitos, unidades/rangos de estructura, intervalos y límites de campos.
- Una importación o callback SDK no puede autodeclarar una muestra validada. La revisión se realiza dentro de la app.
- Migración que retira la confianza de registros procedentes de una política anterior de validación.
- Identidad SHA-256 estable por fuente, métrica e intervalo, independiente del ID mutable de un archivo importado.
- Deduplicación local, metadatos de sincronización HealthKit, comprobación de permisos de escritura y exclusión de sincronizaciones concurrentes.
- Exclusión de ECG y estimaciones de glucosa, lípidos y ácido úrico de las escrituras en Salud. HRV genérica no se convierte a SDNN.

### Privacidad, errores e infraestructura

- Protección completa de los archivos de Bridge al bloquear el iPhone y exclusión del historial de sus copias de seguridad.
- Importaciones con límite de tamaño/cantidad; errores de persistencia y exportación visibles.
- Borrado del historial de Bridge y de sus exportaciones temporales conocidas. No se afirma borrar la base del SDK, Salud ni copias compartidas fuera de la app.
- Logs del SDK desactivados desde el puente; ninguna telemetría propia añadida al código.
- Manifiesto de privacidad para el uso de preferencias de la app; icono y metadatos de versión de candidata.
- El antiguo workflow que sobrescribía fuentes actuales desde el ZIP v0.2 queda convertido en inspección de archivo de solo lectura.
- Preparación de firma remota autorizada y validación del derecho HealthKit en app/perfil. Sin secretos dentro del repositorio.

## 4. Matriz de datos

«Conversión» significa código y reglas de transformación; no que el A2 las haya entregado.

| Categoría | Recuperación/conversión implementada | Destino previsto | Condición pendiente |
|---|---|---|---|
| Pulsaciones | Campo documentado `heartValue` | Historial y Salud, previa revisión | Respuesta real, fechas y equivalencia con G Band |
| Pasos | Sumas no solapadas de media hora | Historial y Salud, previa revisión | Confirmar intervalos y repetición de descargas |
| Oxígeno | Porcentaje del SDK a fracción 0–1 | Historial y Salud, previa revisión | Confirmar formato y precisión del reloj |
| Temperatura | Valor documentado en °C | Historial; Salud solo tras confirmar sensor y revisar | No confundir temperatura cutánea con corporal |
| Sueño ordinario | Segmentos de cinco minutos; conserva despertares | Sueño sin especificar | Contrastar fechas/duración del A2 |
| Sueño preciso | Curva hexadecimal y duración de punto; excluye vigilia/insomnio | Sueño sin especificar | Verificar formato, sin equivalencia de etapas clínicas |
| Grasa y masa magra | Porcentaje a fracción y kg; origen estimado explícito | Historial y Salud, previa revisión | Presencia y significado real de los campos |
| Peso/altura/sexo del modelo corporal | Conservados como entradas de perfil en archivo bruto | No se inventa una medición del reloj | El SDK señala que son datos aportados por la app |
| HRV del fabricante y RR | Lectura y conservación original | Archivo privado | No consta que el valor HRV sea SDNN |
| ECG, QT y demás resultados del modelo | Conservación bruta de trazado y metadatos disponibles | Archivo privado; no ECG de Apple Health | Captura física, escala, muestreo y compatibilidad |
| Presión del historial | Preservación sin intercambiar nombres ambiguos | Archivo privado | Aclarar sistólica/diastólica con datos reales |
| Glucosa, lípidos, ácido úrico estimados | Preservación de los datos disponibles del fabricante | Archivo privado; no Salud | No se consideran mediciones clínicas validadas |
| Sesiones deportivas | Lectura adicional y archivo SDK | Archivo privado | Comprobar las categorías que devuelva el A2 |

## 5. Pruebas automatizadas

Los datos sintéticos existen únicamente como fixtures de XCTest. La aplicación no carga esas muestras ni presenta valores inventados.

Pruebas del núcleo:

1. Rechazo de valores no finitos y fuera de rango.
2. Rechazo de fechas futuras e intervalos invertidos.
3. Importaciones sin confianza en su marca de validación y conservación de registros existentes.
4. Exigencia del método SDNN para HRV destinada a Salud.
5. Rechazo de hora inválida, booleanos y valores nulos de pulsaciones.
6. Conversión única de porcentaje de oxígeno a fracción.
7. Sueño ordinario: exclusión de despertares y rechazo de duración incoherente.
8. Temperatura: rechazo de horas fraccionarias.
9. Pasos: intervalos completos no solapados y rechazo de fracciones.
10. Composición: no convertir el peso de perfil en una medición.
11. Sueño preciso: exclusión de insomnio/vigilia y rechazo de hexadecimal inválido.
12. Deduplicación del mismo intervalo aunque cambie el ID externo, conservando fuentes distintas.

Estas pruebas no ejercitan Bluetooth físico, el código interno del binario Veepoo, una autorización real de HealthKit ni un perfil de firma Apple.

## 6. Evidencias de ejecución

| Evidencia | Revisión | Resultado comprobado |
|---|---|---|
| [Pruebas y compilación de fuente](https://github.com/Risego2000/VeepooHealthBridge/actions/runs/41171214979) | `801bd8f421423ad888f340f221bc5bdea4a5c78c` | Paso de 12 tests del núcleo correcto; compilación de simulador y compilación iPhone sin SDK correctas |
| [Integración oficial de dispositivo](https://github.com/Risego2000/VeepooHealthBridge/actions/runs/41171134561) | `adc1af27f56f801c287dd3c74672702ae15aff69` | Workflow completo correcto: SDK 2.2.110.15, compilación iPhone, comprobación de textos de privacidad y empaquetado IPA |
| Inspección del artefacto descargado | Binario de la revisión `adc1af27` | ZIP/IPA íntegro; bundle `org.veepoobridge.ios`; versión `0.3.0`, build `3`; iOS mínimo 17.0; sin perfil de aprovisionamiento |

La revisión `801bd8f4` solo modifica el workflow de capturas respecto a `adc1af27`; la fuente de la app y los tests son iguales. La fase de capturas es opcional y tiene su propio resultado: un paso de compilación correcto no se usa para afirmar que el simulador gráfico haya arrancado.

**IPA sin firma:** `VeepooHealthBridge-UNSIGNED.ipa`, 2.434.401 bytes.  
**SHA-256 de la IPA:** `ea3f2f8317a404f5487957410c6869fa1c2289381c616ca4df8e3f58f2bb5e3e`.  
**SHA-256 del ZIP de artefacto GitHub:** `150b46b74128dd0ed28a4f25a94fbf1cfedbe85bf79f30f7dbe644c082b540f6`. No son el mismo archivo.

La descarga de la IPA se inspeccionó localmente y se incluyó en la entrega privada. Su ausencia de aprovisionamiento es coherente con la compilación sin firma: no se puede instalar directamente desde Safari.

Los logs registran fallos intermedios y sus correcciones. No se utilizan ejecuciones antiguas como prueba de cambios posteriores.

## 7. Estado de aceptación

| Hito | Estado |
|---|---|
| Código implementado | Sí, con alcance y límites descritos en este informe |
| Núcleo probado automáticamente | Resultado específico en las evidencias de CI |
| Compilación para simulador | Resultado específico en las evidencias de CI; sin SDK de dispositivo |
| Compilación para iPhone con SDK real | Resultado específico en las evidencias de CI |
| Interfaz ejecutado en simulador | Solo se acredita con capturas obtenidas del ejecutor; no con un diseño generado |
| Comunicación física con A2 | No probada |
| Descarga íntegra del A2 y cotejo con G Band | No probados |
| Escritura real y repetición en Salud | No probadas |
| Firma/perfil HealthKit del titular | No disponibles en esta ejecución |
| Instalación con TestFlight | Preparación documentada; no realizada |
| Aceptación final de la aplicación | Pendiente de firma, validación de distribución y pruebas físicas |

## 8. Riesgos y límites que siguen abiertos

1. **Compatibilidad específica A2:** nombre comercial y firmware no demuestran soporte de una categoría. Depende de capacidades anunciadas y datos entregados por el dispositivo.
2. **Zona horaria e intervalos ambiguos:** los campos locales sin offset no permiten resolver por sí solos una hora repetida de otoño. Los viajes también requieren cotejo. No se deben verificar registros ambiguos sin referencia.
3. **Segundo plano:** no se acredita monitoreo permanente, recuperación tras cierre forzado ni reconexión después de reiniciar la app. La reconexión descrita es de sesión.
4. **Duplicados de otras apps:** la identidad de Bridge no garantiza identificar copias guardadas por G Band con otra procedencia/identificadores. Denegar lectura de Salud limita lo que la app puede observar.
5. **Binario SDK:** su tráfico y sus archivos internos deben inspeccionarse en iPhone. Los controles de protección/borrado de Bridge no certifican todos los archivos de terceros.
6. **Distribución Apple:** la validación de App Store Connect puede exigir ajustes de metadatos, privacidad, herramientas o frameworks. Preparar una configuración de firma no acredita la aceptación del paquete por Apple.
7. **Exactitud sanitaria:** un dato dentro de rango o cotejado con G Band no queda validado clínicamente.

No todos estos puntos dependen de la respuesta al expediente Apple. Los puntos de compatibilidad, tráfico, exactitud semántica y comportamiento físico dependen de ensayar la candidata junto al reloj.

## 9. Próximo paso concreto

Activar los recursos del titular necesarios para el workflow firmado, ejecutar la distribución autorizada y seguir `INSTALACION_IPHONE_0_3.md`. Tras instalar la candidata, registrar resultados por categoría y corregir cualquier diferencia observada antes de declarar finalizada la compatibilidad A2.
