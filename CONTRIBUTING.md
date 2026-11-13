# Cómo contribuir

Gracias por querer ayudar. Esto es un proyecto chico, así que las reglas son
pocas.

## Antes de mandar un cambio

- **Una idea por pull request.** Un arreglo o una función por vez: así se puede
  revisar, probar y, si hace falta, revertir sin llevarse puesto nada más.
- **Que pase la verificación.** Antes de subir:

  ```bash
  flutter analyze --no-fatal-infos
  flutter test
  ```

  El mismo chequeo corre solo en cada push. Si tocaste lógica que se puede
  probar sin interfaz (listas, letras, rutas, ordenamientos), agregá su prueba
  en `test/`.
- **Probalo en un teléfono.** Todo lo que toque audio, notificación, widgets,
  permisos o Bluetooth no lo cubre ninguna prueba automática. Contá en el pull
  request en qué modelo y versión de Android lo probaste.
- **Si agregás algo visible**, sumá su entrada en `lib/core/changelog.dart` y en
  `CHANGELOG.md`.

La guía técnica (cómo compilar, firmar y publicar) está en
[`docs/desarrollo.md`](docs/desarrollo.md).

## Mensajes de commit

En español, explicando **por qué** se hace el cambio, no solo qué se tocó. El
qué ya se ve en el diff.

```
Pausar al llegar a cero el volumen del teléfono

Bajar el volumen del todo dejaba la música sonando en silencio y después
los botones de volumen cambiaban el de las llamadas.
```

## Nada personal en el repositorio

El repositorio es público. No subas:

- claves, tokens, keystores ni archivos `.jks`;
- rutas de tu computadora (`C:\Users\...`), nombres de usuario ni direcciones de
  correo reales;
- capturas, listas de reproducción o archivos de audio tuyos a modo de ejemplo;
- datos de pago más allá de un alias de solo recibir.

Si algo así se te escapó y ya está subido, avisá por privado (ver abajo) antes
de abrir un issue: un issue público lo deja aún más a la vista.

## Reportar un fallo

Abrí un [issue](https://github.com/B3njaminGC/Remastered-Music/issues) contando:

- qué esperabas y qué pasó;
- los pasos para que vuelva a pasar;
- modelo de teléfono, versión de Android y número de build (está en
  *Ajustes → Qué hay de nuevo*).

Si la app se cierra, ayuda muchísimo el registro del sistema. Antes de pegarlo,
revisalo: suele incluir rutas y nombres de archivos tuyos, y a veces la lista de
apps instaladas. Borrá lo que no quieras hacer público y pegá solo las líneas
del error.

## Reportar un problema de seguridad

**No abras un issue.** Escribí en privado por
[GitHub Security Advisories](https://github.com/B3njaminGC/Remastered-Music/security/advisories/new),
que es un canal cerrado entre vos y quien mantiene el proyecto.

Contá qué encontraste y cómo reproducirlo, sin incluir datos personales tuyos ni
de terceros, y sin publicar nada hasta que haya una versión con el arreglo.

## Sobre el uso de IA

Este proyecto se desarrolla con **Claude (Anthropic) como asistente de
programación**, y los commits lo dicen en sus líneas de atribución. Si usás una
herramienta de IA para tu aporte, no hay problema: mencionalo en el pull request
y revisá y probá el resultado antes de mandarlo. El código que se sube es
responsabilidad de quien lo sube, lo haya escrito una persona o no.
