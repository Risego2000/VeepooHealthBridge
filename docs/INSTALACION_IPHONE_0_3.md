# Instalación legítima utilizando solamente el iPhone

Fecha: 31 de octubre de 2026. Candidata: 0.3.0.

## Vía preparada: CI macOS remoto → App Store Connect → TestFlight

No necesitas tener un ordenador personal. La compilación y la firma sí necesitan un entorno macOS: se ejecutarán en el servicio remoto. La aplicación que se instala es nativa, con Bluetooth y HealthKit; no se sustituye por una web.

Apple exige que el titular tenga acceso a los recursos de distribución necesarios. El expediente **referencia reservada en la entrega privada** es una referencia proporcionada por el usuario: no se ha accedido a su contenido ni comprobado que Apple lo haya resuelto. No se puede deducir su estado del número.

## Lo que ya deja preparado el repositorio

En `codemagic.yaml`, el workflow manual `ios-testflight-candidate`:

1. Descarga el SDK oficial fijado a un commit, prepara frameworks y dependencias y genera el proyecto.
2. Ejecuta las pruebas del núcleo.
3. Aplica los perfiles autorizados del titular mediante `xcode-project use-profiles`.
4. Genera un archivo firmado y una IPA para App Store Connect.
5. Comprueba firma, derecho HealthKit en la app y derecho HealthKit en el perfil.
6. Configura la subida a App Store Connect con la integración segura. No publica automáticamente en la App Store ni envía una solicitud de revisión de beta.

**Estado:** configuración preparada y revisable; no ejecutada con credenciales del titular. Un YAML correcto no demuestra que Apple vaya a aceptar el binario ni que el perfil esté disponible.

## Intervención que corresponde al titular

Todo puede gestionarse desde el iPhone, utilizando Safari, Archivos, Apple Developer y TestFlight según corresponda:

1. Comprobar que la pertenencia al Apple Developer Program está activa y que están aceptados los acuerdos. Si Apple mantiene bloqueada la cuenta por el expediente, esta parte depende de su resolución.
2. En Apple Developer, registrar un identificador explícito y habilitar HealthKit. El proyecto usa `org.veepoobridge.ios`; si no se puede registrar ese identificador, debe sustituirse coherentemente en proyecto, perfil y configuración de CI.
3. Crear el registro de la aplicación en App Store Connect, asociado al mismo identificador.
4. Crear una clave API dedicada con los permisos necesarios para la integración de CI. Descargar el `.p8` a Archivos y cargarlo **solo en el gestor seguro del servicio de compilación**, junto con Issuer ID y Key ID. No subirlo a GitHub ni pegarlo en una conversación.
5. Conectar el repositorio a Codemagic y crear la integración con el nombre **Veepoo Apple Developer**, usado por el YAML. Desde sus opciones de identidades de firma, generar o aportar un certificado Apple Distribution del propio titular y preparar el perfil App Store con HealthKit.
6. Elegir el workflow `ios-testflight-candidate` y ejecutarlo sobre el commit validado. Para una segunda subida debe aumentarse `CURRENT_PROJECT_VERSION` en `project.yml` a un valor no utilizado.
7. Revisar el resultado de procesamiento en App Store Connect. Completar la información de prueba, privacidad y cifrado que solicite Apple; resolver cualquier incidencia del SDK o dependencias que su validación identifique.
8. Asignar la build a un grupo interno habilitado, o tramitar beta externa si corresponde. Instalar **TestFlight** en el iPhone y aceptar la invitación o acceso configurado.
9. Ejecutar el plan de pruebas físicas. No marcar la compatibilidad A2 como aprobada por haber instalado la app.

Estos pasos necesitan acceso autenticado del titular; no se dispone de ese acceso en esta ejecución. No se ha creado un certificado, subido una build firmada, invitado a testers ni contactado con Apple.

## Prueba física mínima de aceptación

- Confirmar firmware visible e interno, nombre del dispositivo y capacidades reales anunciadas.
- Conectar después de liberar G Band. Probar contraseña incorrecta, correcta, salida de alcance, Bluetooth apagado y desconexión manual.
- Recuperar un día completo y repetir la descarga: el número de muestras de Bridge no debe crecer por duplicación.
- Comparar fechas y unidades frente a G Band. Probar la zona Europe/Madrid y un historial que cruce cambio de hora: los registros ambiguos no deben verificarse sin contraste.
- Contrastar al menos diez muestras de frecuencia, diez intervalos de pasos y las categorías realmente presentes. Comprobar porcentajes y tipo de sensor de temperatura.
- Revisar las etapas de sueño: se envía sueño sin especificar, sin atribuir equivalencia clínica a las etapas del fabricante.
- Verificar manualmente unas muestras y autorizar HealthKit. Inspeccionar valor, tipo, unidad, fecha y origen en Salud. Repetir envío y comprobar que Bridge no añade copias.
- Denegar permisos de lectura/escritura, reautorizarlos, bloquear el iPhone durante operaciones y comprobar los mensajes y persistencia.
- Inspeccionar el archivo privado del SDK y el tráfico del binario. No subir esos datos sanitarios al repositorio público.

## Fuentes oficiales consultadas

- Apple: https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases
- Apple: https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/
- Apple: https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
- Codemagic: https://docs.codemagic.io/yaml-quick-start/building-a-native-ios-app/

No se considera solución entregar otra IPA sin firma, utilizar certificados empresariales ajenos, instalar un perfil DNS ni cambiar la extensión de un archivo.
