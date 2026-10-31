# ENTREGA Y VALIDACIÓN EN IPHONE — VEepoo Health Bridge

## Estado verificable
- Las compilaciones sin firma de GitHub Actions han finalizado correctamente.
- La compilación de iPhone enlazando `VeepooBleSDK.framework`, `GRDFUSDK.framework`, AFNetworking, FMDB e iOSDFULibrary ha finalizado correctamente.
- Esto NO constituye una IPA firmada, ni prueba de comunicación con el reloj A2.
- El flujo `ios-veepoo-sdk` de `codemagic.yaml` es exclusivamente una compilación sin firma; no debe anunciarse como instalador.

## Prueba con reloj físico (imprescindible)
1. Generar e instalar una build firmada mediante un método autorizado de Apple.
2. Con G Band en estado compatible con el acceso BLE, buscar el reloj desde «Buscar con SDK Veepoo».
3. Seleccionar el reloj y comprobar que la conexión real y el firmware se muestran con valores coherentes.
4. Solicitar «Leer historial con SDK (diagnóstico)» y comprobar errores/estado.
5. Inspeccionar los recuentos diarios de la base de datos.
6. Extraer pulsaciones. Comparar al menos 10 lecturas con G Band, revisando fecha, zona horaria, unidades y duplicados.
7. Las muestras del SDK permanecen `validated=false`; su mera importación NO las autoriza para HealthKit.

## Límites técnicos pendientes
- Conexión y recuperación del A2, sin pruebas de hardware.
- El SDK incluye valores HRV que NO deben convertirse automáticamente a HealthKit SDNN.
- Apple Health no permite a cualquier tercero crear registros ECG equivalentes a los de Apple Watch.
- No publicar estimaciones de glucosa, lípidos o ácido úrico como medidas clínicas.
- No hay conversión completa de sueño, actividad, temperatura, oxígeno o ECG a `Measurement`.
- La firma digital y la distribución iOS requieren credenciales/permisos de Apple gestionados por el titular.

## Privacidad
Repositorio público: no cargar datos personales de salud, perfiles de firma, certificados, secretos, capturas de diagnóstico del dispositivo ni historiales exportados.

## Verificación de resultados
- Revisar las conclusiones reales en `Actions`, no solo los artefactos.
- Mantener el flujo de compilación sin firma separado del futuro flujo de distribución.
