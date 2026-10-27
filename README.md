# Iris

App personal de iOS con un agente llamado Iris, lista de tareas, recordatorios y un widget para la pantalla de bloqueo.

**Versión 0.1:** pantallas completas, tareas que se guardan, recordatorios con notificaciones y widget de bloqueo. El "cerebro" de Iris (IA con Gemini) llega en la versión 0.2.

---

## Cómo funciona la instalación

1. Tú subes el código a GitHub desde VS Code.
2. GitHub compila la app sola en una Mac en la nube y te deja un archivo `Iris.ipa`.
3. Instalas ese `.ipa` en tu iPhone desde Windows con **Sideloadly**.

---

## 1. Subir el código a GitHub (una sola vez)

1. Descomprime la carpeta `Iris` y ábrela en **VS Code** (Archivo › Abrir carpeta).
2. Ve a la pestaña **Control de código fuente** (el ícono de ramas, a la izquierda).
3. Toca **Publish to GitHub** y elige **public repository**.
   - Público = las Mac de GitHub son gratis e ilimitadas. El código no tiene ninguna clave ni dato personal.
4. Asegúrate de que la rama se llame `main` (es lo normal).

Desde ahí, cada vez que cambies algo: escribe un mensaje en Control de código fuente › **Commit** › **Sync / Push**.

## 2. Descargar el .ipa

1. En la página de tu repositorio en GitHub, abre la pestaña **Actions**.
2. Verás "Compilar Iris" corriendo (tarda unos 5 a 10 minutos). Cuando tenga el chulito verde, ábrelo.
3. Abajo, en **Artifacts**, descarga **Iris-ipa**. Es un `.zip`: descomprímelo y adentro está `Iris.ipa`.

Si sale una X roja, abre el paso que falló y mándale el error a Claude.

## 3. Preparar Windows (una sola vez)

Sideloadly necesita las versiones de **iTunes** y **iCloud** descargadas desde la página de Apple (**no** las de la Microsoft Store).

1. Instala iTunes desde apple.com (versión para Windows de 64 bits).
2. Instala iCloud para Windows desde apple.com.
3. Instala **Sideloadly** desde sideloadly.io.

## 4. Instalar en el iPhone

1. Conecta el iPhone al computador con el cable y toca **Confiar** en el iPhone.
2. Abre Sideloadly, arrastra `Iris.ipa` a la ventana.
3. Escribe tu **Apple ID** y toca **Start**. Te pedirá la contraseña (y el código de verificación si tienes doble factor).
4. En el iPhone:
   - **Configuración › Privacidad y seguridad › Modo de desarrollador** → actívalo y reinicia el iPhone (solo la primera vez).
   - **Configuración › General › VPN y gestión de dispositivos** → toca tu Apple ID → **Confiar**.
5. Abre Iris.

## 5. Agregar el widget

Mantén presionada la pantalla de bloqueo › **Personalizar** › **Pantalla de bloqueo** › toca la zona de widgets debajo de la hora › busca **Iris** › elige el widget rectangular.

---

## Cosas a tener en cuenta

- **La app caduca cada 7 días** con un Apple ID gratuito. Para renovarla, vuelve a instalarla con Sideloadly (tus tareas no se borran). Sideloadly también tiene una opción de renovación automática por Wi-Fi si dejas el computador encendido.
- **Si el widget sale vacío** aunque tengas tareas, avísale a Claude: puede ser que la firma gratuita no le dé permiso al widget de leer las tareas, y hay otra forma de resolverlo.
- Con Apple ID gratuito puedes tener máximo 3 apps instaladas así al mismo tiempo.

---

## Estructura del código

```
project.yml                 Configuración del proyecto (XcodeGen lo convierte en proyecto de Xcode)
.github/workflows/          Instrucciones para que GitHub compile la app
Iris/                       La app
  IrisApp.swift             Punto de entrada
  Stores/                   Dónde se guardan las tareas y los recordatorios
  Views/                    Pantallas: Iris, Tareas, Recordatorios, Ajustes
  Assets.xcassets/          Ícono de la app
IrisWidget/                 El widget de la pantalla de bloqueo
Shared/                     Código que usan tanto la app como el widget
```
