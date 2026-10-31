# Instalación en iPhone: límites y firma legítima

Estado verificado: [compilación 41166329544](https://github.com/Risego2000/VeepooHealthBridge/actions/runs/41166329544) pasó compilación, verificación de las tres cadenas de privacidad y empaquetado de IPA **SIN FIRMA**. Esto NO constituye una instalación de iOS ni prueba BLE/HealthKit.

## Datos obligatorios para producir un IPA instalable
1. Identidad de firma emitida para el titular autorizado: certificado Apple y clave privada, suministrados por el titular exclusivamente al gestor seguro de credenciales de CI. **Nunca subir .p12, contraseñas o perfiles al repositorio público.**
2. Perfil de aprovisionamiento autorizado para el bundle ID de la aplicación y, para distribución ad hoc o desarrollo, UDID de destino registrado, y capacidad HealthKit habilitada por Apple para ese identificador.
3. Comprobar que la aplicación y sus frameworks embebidos quedan correctamente firmados, y que el IPA exportado conserva los derechos requeridos.
4. Instalación desde el propio iPhone por un canal autorizado (TestFlight, MDM legítimo, ad hoc cuando corresponda o flujo de desarrollo autorizado), seguida de pruebas de Bluetooth con el A2 y de autorización HealthKit.

## No sustituye una firma
- Cambiar `.zip` a `.ipa`, modificar `Info.plist` o escribir un `_CodeSignature` artificial no proporciona una firma aceptada por iOS.
- Un certificado empresarial de otra organización no autoriza distribuir esta app ni garantiza su seguridad.
- SideInstaller/SideStore son externos al proyecto y no se ha validado que un aprovisionamiento gratuito de Apple permita los derechos HealthKit necesarios.
- La instalación de un perfil DNS no instala la app ni aprovisiona HealthKit; el DNS externo puede observar dominios visitados.

## Qué está automatizado
GitHub Actions `.github/workflows/veepoo-device-sdk.yml` integra el SDK, compila, valida las cadenas NSBluetoothAlwaysUsageDescription/NSHealthShareUsageDescription/NSHealthUpdateUsageDescription y publica `VeepooHealthBridge-UNSIGNED.ipa` como artefacto. Codemagic publica el mismo tipo de paquete.

## Pruebas pendientes con el dispositivo
- Conexión BLE real con A2 (firmware 02.52.01.00-5982).
- Lecturas completas y equivalencia semántica de métricas del SDK con Apple Health.
- Prueba positiva de permisos HealthKit con firma habilitada; no escribir HRV no validada como SDNN ni ECG no compatible.
