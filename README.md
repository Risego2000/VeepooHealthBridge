# Veepoo Health Bridge — A2 / G Band

Aplicación iOS experimental para evaluar la lectura de un reloj A2 mediante el SDK de Veepoo y la sincronización selectiva de datos compatibles con Apple Health.

## Estado verificado
- ✅ Proyecto SwiftUI v0.2 incluido en `VeepooHealthBridge_v0_2_source.zip`.
- ✅ [Compilación iOS Simulator](https://github.com/Risego2000/VeepooHealthBridge/actions/runs/41158918327) correcta.
- ✅ Exploración Bluetooth LE, conexión CoreBluetooth y descubrimiento de servicios GATT implementados. Diagnóstico no probado con A2 físico.
- ✅ Compilación de fuente actualizada para simulador y destino iPhone físico sin firma: https://github.com/Risego2000/VeepooHealthBridge/actions/runs/41159378324
- ✅ Código Swift publicado en la raíz del repositorio (sin necesidad de descomprimir el ZIP).
- ❌ No se ha integrado el framework real de Veepoo ni comprobado el protocolo del A2.
- ❌ No hay lectura real del historial del reloj, ni IPA firmado, ni distribución TestFlight. Una compilación sin firma no se instala desde Safari.
- ❌ No se ha probado una transferencia real a Apple Health.

## Ejecutar pruebas sin Mac
En **Actions** ejecutar `iOS build validation (Veepoo Bridge)` para comprobar la compilación del ZIP y `Veepoo SDK inventory` para consultar el contenido y formato del SDK upstream. **Ambas son pruebas de CI, no generan una aplicación instalable**.

## Siguiente implementación técnica
1. Auditar arquitectura y licencia del framework de Veepoo y firmas reales en la demo.
2. Implementar un adaptador real que sustituya `PlaceholderVeepooAdapter`; comprobar escaneo, conexión y características del firmware A2.
3. Descargar historial real con paginación, fechas, procedencia, unidades y control de errores.
4. Validar los datos y evitar duplicados de G Band antes de escribir en HealthKit.
5. Firmar y distribuir mediante un método compatible con las capacidades usadas.

## Privacidad y seguridad
Los datos de salud se mantienen localmente. No subir archivos de salud, certificados de firma, claves API ni contraseñas a este repositorio público. Los valores estimados de tensión arterial, glucosa, ácido úrico o lípidos del reloj no son mediciones clínicas validadas. Los ECG de terceros no pueden escribirse como ECG de Apple Health.

SDK de referencia: https://github.com/HBandSDK/iOS_Ble_SDK
