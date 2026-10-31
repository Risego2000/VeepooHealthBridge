> **Revisión de diseño 0.5:** referencia visual corregida a G Band (tres pestañas y acento naranja). Estudio técnico: [ECG, VFC y Apple Health](docs/ESTUDIO_GBAND_SALUD_0_5.md). 18 pruebas del núcleo y compilación Release con SDK oficial verificadas. Tres capturas reales del simulador revisadas. No se afirma igualdad de capacidades ni compatibilidad A2 a partir del diseño.

> **Revisión vigente 0.4.0:** consulta [AMPLIACION_0_4.md](docs/AMPLIACION_0_4.md). Incluye lectura manual por capacidades anunciadas, visor de datos originales, IMC, sincronización opcional de muestras verificadas, cola de envío y declaración BLE en segundo plano. 14 pruebas del núcleo y compilación Release con SDK oficial verificadas. Sin validación física del A2 ni distribución firmada. El informe 0.3 siguiente conserva la evidencia de la versión anterior.

# Veepoo Health Bridge · candidata 0.3

App **nativa de iPhone**, SwiftUI, para evaluar la recuperación del historial de un A2 y la transferencia selectiva a Apple Health. Firmware objetivo comunicado por el usuario: **02.52.01.00-5982**. No se afirma compatibilidad física antes de probarlo.

## Código actual

La fuente autoritativa está en `Sources/`, no en el ZIP histórico v0.2. El antiguo workflow de extracción ya no puede sobrescribir las fuentes.

- Interfaz con cinco pestañas: Resumen, Reloj, Historial, Salud y Ajustes.
- SDK oficial **2.2.110.15**, fijado al commit upstream `c1ec1363c659deaa483778315b86e680f8f81af0`; preparación reproducible en `scripts/prepare-vendor.sh`.
- Búsqueda, contraseña de cuatro cifras, autenticación, desconexión, reconexión de sesión y bloqueo de comandos concurrentes.
- Lectura general y lecturas adicionales de oxígeno, HRV, temperatura y actividad, según las capacidades anunciadas.
- Decodificación estricta de pulsaciones, pasos por media hora, oxígeno, temperatura, sueño ordinario/preciso y grasa/masa magra estimadas. Las muestras permanecen sin verificar hasta el cotejo del usuario.
- Archivo privado de las categorías disponibles en la base del SDK, incluidos ECG, composición corporal, HRV y estimaciones bioquímicas. Conservar los datos brutos no valida su significado clínico.
- HealthKit con consentimiento, validación, comprobación de permiso de escritura, identificadores estables y prevención de sincronizaciones simultáneas.
- Protección de archivos de Bridge, exclusión del historial de sus copias de seguridad, importaciones limitadas, borrado local y exportaciones voluntarias.

## Verificación

`swift test --parallel` ejecuta las pruebas del núcleo sin requerir iPhone ni el SDK binario. Los datos sintéticos se usan únicamente en tests y no se incluyen como registros de la app.

[Actions](https://github.com/Risego2000/VeepooHealthBridge/actions) separa:

1. Pruebas del núcleo, compilación para simulador y para iPhone sin SDK, y capturas del interfaz ejecutado en simulador.
2. Compilación **iphoneos con el SDK oficial enlazado** y empaquetado de IPA **sin firma**.

Una compilación de simulador no demuestra integración del SDK, Bluetooth real ni escritura en Salud. Una IPA sin firma no es un instalador.

## Firma e instalación sin ordenador personal

El workflow manual `ios-testflight-candidate` de `codemagic.yaml` prepara firma autorizada en un Mac remoto y subida a App Store Connect. Requiere que el titular configure su cuenta Apple Developer, registro de la app, perfil HealthKit y la integración segura llamada `Veepoo Apple Developer`. No contiene credenciales y no se ha ejecutado con una identidad del titular.

El usuario puede recibir la app en **TestFlight en su iPhone**. No se necesitan certificados empresariales ajenos ni una PWA. La generación y firma siguen requiriendo infraestructura macOS remota y autorización de Apple; no se realizan íntegramente dentro del iPhone.

## Límites explícitos

- No hay pruebas físicas con A2, ni transferencia real a HealthKit, ni distribución TestFlight acreditada todavía.
- La reconexión implementada es de sesión. No se promete monitoreo permanente en segundo plano ni supervivencia al cierre forzado de iOS.
- La deduplicación identifica registros de Bridge. No garantiza detectar copias de G Band u otra fuente con otros identificadores.
- HRV del fabricante no se presupone SDNN. ECG y estimaciones de glucosa, ácido úrico o lípidos no se escriben en Salud.
- La presión del historial conserva campos brutos por ambigüedad de nombres en la cabecera oficial.
- La temperatura debe contrastarse: un valor cutáneo no se debe presentar como temperatura corporal.
- El SDK no suministra peso medido en su modelo de composición: peso, altura y sexo son datos de perfil, no mediciones recuperadas.
- Horas repetidas por cambio de horario y viajes requieren cotejo antes de verificar muestras.
- La protección y borrado descritos corresponden a los archivos de Bridge; la base privada del SDK y el tráfico de ese binario necesitan inspección en dispositivo. No subir historiales sanitarios al repositorio público.

Consulta `docs/INFORME_CANDIDATA_0_3.md` y `docs/INSTALACION_IPHONE_0_3.md` para el expediente técnico y las puertas de aceptación.
