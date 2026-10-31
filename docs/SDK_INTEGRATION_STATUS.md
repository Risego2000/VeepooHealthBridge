# Integración SDK · revisión 0.3

La fuente vigente está en `Sources/`. Se sustituyó la versión histórica 2.0.43.15 por **2.2.110.15**, presente en `Framework/2.2.XX.15` del repositorio oficial HBandSDK/iOS_Ble_SDK, revisión `c1ec1363c659deaa483778315b86e680f8f81af0`.

El script `scripts/prepare-vendor.sh` descarga esa revisión y genera la integración de dispositivo. Los frameworks de dispositivo no se enlazan al simulador. El hecho de que el simulador compile no acredita esas llamadas.

`VeepooCapabilityProbe` implementa búsqueda, conexión con contraseña, estados de autenticación, reconexión de sesión, lecturas por capacidad, tiempos de espera, inspección y exportación del archivo privado. No queda un adaptador de producción que genere datos simulados.

`VendorHistoryDecoder` contiene conversiones independientes del binario para campos documentados. Su núcleo se prueba con XCTest mediante Swift Package Manager. Una prueba con fixtures acredita reglas de conversión, no que el reloj suministre esos campos.

La tabla completa de resultados y enlaces de CI está en `INFORME_CANDIDATA_0_3.md`. La puerta final de compatibilidad sigue siendo la prueba física de A2 firmware 02.52.01.00-5982.
