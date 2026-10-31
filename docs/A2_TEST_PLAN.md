# Pruebas reales del A2 — pendientes

**Regla:** No declarar una función soportada sin una respuesta comprobada del reloj real.

1. Comprobar la identidad BLE: nombre anunciado A2, UUID local, intensidad de señal y servicios. El identificador BLE puede cambiar entre sesiones; no usarlo como identidad permanente.
2. Asegurar que G Band ha desconectado Bluetooth antes de conectar otra app.
3. Obtener el objeto de capacidades del dispositivo del SDK. Registrar firmware, flags ECG, HRV y composición corporal, sin información de salud personal.
4. Leer un día de registros y comparar marcas temporales con G Band. Mantener valores brutos, unidades, zona horaria y código del origen.
5. Comprobar permisos HealthKit, detectar registros ya existentes, exigir confirmación del usuario y escribir únicamente métricas admitidas.
6. ECG: conservar trazado en archivo propio, sin afirmar que HealthKit permite escribir un ECG.
7. Validar cada categoría con lecturas reales y desactivar las que no cumplan los criterios de exactitud o origen.

**Bloqueo:** Esta prueba requiere que se ejecute una app nativa firmada en un iPhone físico junto al A2. No se puede realizar desde CI ni desde esta conversación.
