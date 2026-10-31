# Ampliación 0.4.0 — alcance real

Se añade un visor nativo de solo lectura de las categorías y campos del archivo real del SDK, con expansión y paginación de arrays. No se rellenan campos ausentes.

Cambios implementados: incorporación automática al historial al finalizar lecturas SDK, envío automático opcional de muestras verificadas, reintento al volver al primer plano, cola para cambios durante un envío, diagnóstico de permisos/errores y soporte BMI. Se añaden mapeos HealthKit para energía activa en kcal, distancia caminando/corriendo en metros y frecuencia respiratoria por minuto cuando la fuente los aporte explícitamente. Estos tres mapeos no implican una extracción nueva demostrada del A2: no se infieren unidades ni se fabrican registros. El IMC recuperado del modelo corporal se etiqueta como derivado de perfil. Se declara bluetooth-central; esto no configura restauración interna del SDK, no acredita segundo plano físico y no garantiza ejecución permanente.

La compilación oficial de dispositivo pasa a Release. Las pruebas añaden controles para las nuevas categorías y el origen del IMC. Los resultados de esta revisión se documentan tras ejecutar Actions; los de 0.3 no prueban la 0.4.

## Qué impide garantizar «todo a Salud y solo falta Apple»

- ECG: Apple documenta que HKElectrocardiogramType es de solo lectura; ninguna firma permite escribir trazados del A2 como muestras ECG de Salud.
- HRV genérica no equivale a SDNN; no se inventa ese método.
- Un campo estimado de glucosa/lípidos/ácido úrico no se exporta como medición clínica por cambiarle el nombre.
- La presión ambigua, las unidades no documentadas, los datos realmente entregados por el firmware y el comportamiento de reconexión necesitan muestras y prueba física.
- La declaración bluetooth-central no basta para prometer ejecución después de cierre forzado; el SDK no expone una configuración pública de restauración en su gestor central en la revisión usada.

Los requisitos de cuenta, firma, perfil HealthKit y distribución son independientes de esos límites. No se ha accedido al expediente Apple. La ausencia de una prueba con hardware no se etiqueta como problema pendiente de Apple.

Fuentes: https://developer.apple.com/documentation/healthkit/hkelectrocardiogramtype y https://developer.apple.com/documentation/technotes/tn3115-bluetooth-state-restoration-app-relaunch-rules
