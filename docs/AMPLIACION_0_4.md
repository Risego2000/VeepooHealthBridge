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

Se incorpora la API oficial readManualTestData(withTimestamp:dataType:result:), pidiendo únicamente la máscara supportManualTestType anunciada. El resultado manual queda disponible en el archivo privado y en su visor. Se guarda además en un archivo protegido de Application Support, excluido de backup, separado por dirección de dispositivo; no se declaran conversiones a Salud de sus campos sin unidades confirmadas. La cobertura comprende solo los modelos reconocidos por el esquema de cabeceras fijado; clases desconocidas se identifican explícitamente. No hay prueba física de esta API en A2.

## Evidencia de la revisión final

Código validado: `668e74872823627e45a6566fc8a18ceaa56b1a32`.

- SDK oficial y aplicación en Release para iPhone: workflow completo correcto, empaquetado de candidata sin firma incluido: https://github.com/Risego2000/VeepooHealthBridge/actions/runs/41172634812
- 14 pruebas del núcleo, compilación de simulador y compilación iPhone sin SDK: pasos correctos en https://github.com/Risego2000/VeepooHealthBridge/actions/runs/41172634828. La fase opcional de capturas es independiente de esos resultados.
- API de lecturas manuales, esquema de modelos, persistencia y visor: compilados; sin prueba física con A2.
- Escritura real en Salud, recuperación completa del A2, firma del titular y distribución TestFlight: no realizadas.

No se afirma «todas las mediciones del A2 a Salud» ni «únicamente pendiente de Apple». La cobertura real del firmware y la equivalencia de los campos necesitan comprobación física; ECG y otros campos sin tipo escribible mantienen sus límites aunque la firma esté disponible.
