# Estado de integración Veepoo (revisión 2026-10-31)

SDK upstream: https://github.com/HBandSDK/iOS_Ble_SDK

Verificaciones:
- API `VPBleCentralManage.sharedBleManager()`, búsqueda, conexión y modelo de capacidades verificadas en las cabeceras públicas del SDK.
- El framework histórico `2.0.43.15/VeepooBleSDK.framework` contiene arquitectura ARM64 para iPhone (y ARMv7). No se ha demostrado que funcione con el firmware A2.
- El proyecto Bridge incluye `VeepooCapabilityProbe` con compilación condicional. **El SDK binario NO está aún vinculado al target**. No confundir la existencia del código con conexión real.
- En el SDK la autenticación por contraseña y el descubrimiento de características son parte del flujo de conexión; no leer datos hasta su validación.

Siguiente puerta de calidad:
1. Incorporar binarios y dependencias oficiales del SDK en compilación **iphoneos** (el framework histórico no incluye una arquitectura de simulador).
2. Corregir las firmas del callback según `VPPublicDefine.h`, enlazar al target y compilar realmente esa rama `canImport`.
3. Realizar la conexión a un A2 físico. Detectar capacidad real y comprobar recuperación de un día.
4. Solo después habilitar sincronización HealthKit, consentimiento y deduplicación.

La validación de compilación sin framework no acredita las funciones 1-4.
