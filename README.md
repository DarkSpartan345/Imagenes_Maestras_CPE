<p align="center">
  <img src="Manual/logos/unal_logosimbolo_verde.png" width="150" alt="Universidad Nacional de Colombia">
</p>

# Imagenes_Maestras_CPE

Herramienta para **preparar, capturar y desplegar imágenes maestras de Windows** en equipos de forma masiva, usando un disco externo y un USB de arranque con **Hiren's BootCD PE**.

Todo el proceso se maneja desde un solo script (`ImagenMaestra.cmd`) con una interfaz de tres pestañas (o menú de texto si no hay .NET). Un segundo script (`CuentasCPE.cmd`) verifica cada equipo una vez desplegado.

> [!TIP]
> Este manual también está en PDF: [Manual/Manual_Imagen_Maestra.pdf](Manual/Manual_Imagen_Maestra.pdf) (fuente LaTeX en [Manual/Manual_Imagen_Maestra.tex](Manual/Manual_Imagen_Maestra.tex)).

## Contenido

1. [Introducción](#1-introducción)
2. [Obtención de la herramienta](#2-obtención-de-la-herramienta)
3. [Fase 1: preparación del equipo de referencia](#3-fase-1-preparación-del-equipo-de-referencia)
4. [Fase 2: captura de la imagen](#4-fase-2-captura-de-la-imagen)
5. [Fase 3: despliegue de la imagen](#5-fase-3-despliegue-de-la-imagen)
6. [Verificación del equipo desplegado](#6-verificación-del-equipo-desplegado)
7. [Resumen rápido](#7-resumen-rápido)
8. [Referencia técnica](#referencia-técnica)

---

## 1. Introducción

Este manual explica, paso a paso y con fotografías del proceso real, cómo se creó una **imagen maestra de Windows** en un equipo de referencia ASUS ExpertBook y cómo se desplegó después en un equipo de destino. Todo el proceso se hace con un único script, `ImagenMaestra.cmd`, que abre una interfaz con tres pestañas, una por fase.

| Fase | Pestaña | Dónde se ejecuta | Resultado |
|------|---------|------------------|-----------|
| 1. Preparación | Preparar y Sysprep | Windows del equipo de referencia | Equipo limpio, en español (es-MX), con una sola cuenta, apagado por Sysprep |
| 2. Captura | Capturar imagen | Hiren's BootCD PE, equipo de referencia | Archivo `Imagenes\Asus_Imagen_maestra.wim` en el disco externo |
| 3. Despliegue | Desplegar imagen | Hiren's BootCD PE, equipo de destino | Equipo con Windows, programas y particiones de la imagen |

### 1.1 Materiales utilizados

| Elemento | Detalle |
|----------|---------|
| Equipo de referencia | ASUS ExpertBook, AMD Ryzen 5 7535HS, 16 GB de RAM, SSD NVMe Samsung de 1 TB, firmware UEFI |
| USB de arranque | Memoria ADATA de 32 GB con Hiren's BootCD PE (Windows 11 PE x64), etiqueta `HBCD_PE_x64` |
| Disco externo | Toshiba de 1 TB (931 GB útiles), NTFS, USB 3.0 |
| Herramienta | Carpeta `IMG3_V3` (copia del repositorio) en la raíz del disco externo |
| Licencias | Una licencia de Windows por cada equipo de destino |

<p align="center">
  <img src="Imagenes%20manual/1000214233.jpeg" width="600" alt="Montaje de trabajo"><br>
  <em>Figura 1.1. Montaje de trabajo: equipo de referencia con la memoria USB de Hiren's (izquierda) y el disco externo Toshiba (derecha) conectados.</em>
</p>

> [!IMPORTANT]
> El despliegue **borra por completo** el disco de destino. Antes de confirmar, revise siempre el número, modelo y tamaño del disco seleccionado.

---

## 2. Obtención de la herramienta

### 2.1 Descargar el repositorio

1. Abra el repositorio `Imagenes_Maestras_CPE` en GitHub:
   **<https://github.com/DarkSpartan345/Imagenes_Maestras_CPE>**
   y pulse el botón verde **Code** (figura 2.1).
2. En el menú que aparece, copie la dirección HTTPS para clonarlo con Git, o elija **Download ZIP** para descargarlo como archivo comprimido (figura 2.2).

<p align="center">
  <img src="Imagenes%20manual/image%281%29.png" width="700" alt="Repositorio en GitHub"><br>
  <em>Figura 2.1. Página del repositorio en GitHub. El botón Code está marcado en rojo.</em>
</p>

<p align="center">
  <img src="Imagenes%20manual/image%282%29.png" width="700" alt="Menú Code"><br>
  <em>Figura 2.2. Menú Code: copiar la URL HTTPS o descargar el ZIP.</em>
</p>

### 2.2 Copiar la carpeta al disco externo

Copie la carpeta completa a la **raíz** del disco externo. En este caso se llamó `IMG3_V3` (figura 2.3).

<p align="center">
  <img src="Imagenes%20manual/image%283%29.png" width="550" alt="Carpeta en el disco externo"><br>
  <em>Figura 2.3. Contenido de la carpeta en el disco externo. <code>ImagenMaestra.cmd</code> es el script que se usa en las tres fases.</em>
</p>

| Carpeta o archivo | Para qué sirve |
|-------------------|----------------|
| `ImagenMaestra.cmd` | Preparar, capturar y desplegar |
| `CuentasCPE.cmd` | Verificar cada equipo ya desplegado |
| `Imagenes\` | Aquí se guardan los archivos `.wim` capturados |
| `Drivers\` | (Opcional) drivers `.inf` que se inyectan al desplegar |
| `Respuesta\` | (Opcional) un `unattend.xml` propio |
| `Logs\` | Registros de DISM y de cada proceso |

---

## 3. Fase 1: preparación del equipo de referencia

Esta fase se ejecuta en el **Windows del equipo de referencia**, después de instalar y personalizar todos los programas y contenidos que llevará la imagen.

### 3.1 Antes de empezar

- Deje el equipo personalizado: programas, contenidos educativos, fondo de pantalla y accesos directos.
- **Desconecte internet**, para que la Microsoft Store no actualice aplicaciones y bloquee Sysprep. La única excepción es cuando falta el idioma es-MX: esa vez sí se necesita internet para descargarlo.
- Conecte el disco externo.

### 3.2 Elegir las opciones

1. En el disco externo, haga doble clic en `ImagenMaestra.cmd` y concédale los permisos de administrador que solicita al abrirse.
2. Vaya a la pestaña **1. Preparar y Sysprep**.
3. Marque las opciones señaladas en rojo en la figura 3.1:
   - *Quitar automáticamente las apps de la Store que bloquean Sysprep.*
   - *Dejar SOLO la cuenta AdministradorCPE*, con la casilla *Sin contraseña*.
   - *Equipos desplegados sin configuración inicial (directo al inicio de sesión).*
4. Pulse **Preparar y ejecutar Sysprep**.

<p align="center">
  <img src="Imagenes%20manual/image%2812%29.png" width="600" alt="Pestaña Preparar y Sysprep"><br>
  <em>Figura 3.1. Pestaña Preparar y Sysprep con las opciones usadas (marcadas en rojo).</em>
</p>

5. Lea el resumen de confirmación. Indica que la cuenta AdministradorCPE quedará sin contraseña, qué cuentas se eliminarán con sus perfiles (aquí *Estudiante* y *Estudiantes*) y que el equipo se apagará al terminar. Pulse **Sí** (figura 3.2).

<p align="center">
  <img src="Imagenes%20manual/image%2813%29.png" width="450" alt="Confirmación"><br>
  <em>Figura 3.2. Confirmación antes de ejecutar la preparación.</em>
</p>

### 3.3 Comprobaciones automáticas

El script revisa el equipo antes de tocar nada. En la consola inferior se ve cada comprobación con `[OK]`, `[!]` (aviso) o `[X]` (error):

1. Que el equipo no esté unido a un dominio.
2. Que la unidad `C:` no esté cifrada con BitLocker.
3. Que no haya reinicios pendientes.
4. Que el almacenamiento reservado esté desactivado.
5. Que el idioma de la imagen sea español latinoamericano (es-MX).

<p align="center">
  <img src="Imagenes%20manual/image%2814%29.png" width="700" alt="Comprobaciones"><br>
  <em>Figura 3.3. Inicio de las comprobaciones: dominio y BitLocker.</em>
</p>

### 3.4 Ajuste del idioma (es-MX)

La imagen siempre queda con **es-MX como único idioma**. Si el equipo no lo tiene, la primera ejecución lo descarga, lo fija como idioma de pantalla y termina con el mensaje `Preparar terminó con errores (código 1)`. No es una falla: pide reiniciar para aplicar el idioma (figura 3.4).

<p align="center">
  <img src="Imagenes%20manual/image%2815%29.png" width="700" alt="Primera ejecución del idioma"><br>
  <em>Figura 3.4. Primera ejecución: es-MX instalado y fijado. Se pide reiniciar, iniciar sesión con la misma cuenta, desconectar internet y volver a ejecutar.</em>
</p>

En este equipo también faltaba el español de España (es-ES), que Windows usa como idioma de reserva de es-MX. El script lo descargó e instaló y volvió a pedir reinicio (figura 3.5).

<p align="center">
  <img src="Imagenes%20manual/image%2816%29.png" width="700" alt="Descarga de es-ES"><br>
  <em>(a) Descarga de es-ES como reserva de es-MX.</em><br><br>
  <img src="Imagenes%20manual/image%2817%29.png" width="700" alt="es-ES instalado"><br>
  <em>(b) es-ES instalado; se pide reiniciar de nuevo.</em><br>
  <em>Figura 3.5. Instalación del idioma de reserva.</em>
</p>

> [!NOTE]
> **Qué hacer cuando pide reiniciar**
> 1. Reinicie el equipo.
> 2. Inicie sesión con la **misma cuenta**.
> 3. Desconecte internet.
> 4. Abra otra vez `ImagenMaestra.cmd` y repita la pestaña **Preparar y Sysprep** con las mismas opciones.
>
> Repita hasta que la comprobación de idioma salga en verde.

En la siguiente ejecución la comprobación de idioma sale correcta: `La imagen queda en es-MX como único idioma`. Después el script busca y quita las aplicaciones de la Store que bloquean Sysprep (figura 3.6).

<p align="center">
  <img src="Imagenes%20manual/image%2818%29.png" width="800" alt="Idioma correcto"><br>
  <em>Figura 3.6. Idioma correcto. El proceso continúa con las apps de la Store.</em>
</p>

### 3.5 Limpieza y Sysprep

Con todo en orden, el script:

1. Hace la limpieza básica de archivos temporales.
2. Crea el archivo `C:\Windows\System32\Sysprep\unattend.xml`, que omite la configuración inicial con idioma es-MX, teclado latinoamericano y zona horaria de México.
3. Ejecuta:

   ```bat
   sysprep.exe /generalize /oobe /shutdown /quiet /unattend:C:\Windows\System32\Sysprep\unattend.xml
   ```

<p align="center">
  <img src="Imagenes%20manual/image%2819%29.png" width="350" alt="Sysprep en ejecución"><br>
  <em>Figura 3.7. Sysprep en ejecución (fase de limpieza de complementos).</em>
</p>

> [!CAUTION]
> **Al terminar Sysprep** el equipo se **apaga solo**. **No lo encienda en Windows**: si arranca Windows, Sysprep se consume y hay que preparar de nuevo. El siguiente arranque debe ser desde la memoria USB de Hiren's.

---

## 4. Fase 2: captura de la imagen

Esta fase se ejecuta en el **mismo equipo de referencia**, arrancando desde la memoria USB de Hiren's BootCD PE.

### 4.1 Arrancar desde la memoria USB

1. Con el equipo apagado, conecte la memoria USB de Hiren's y el disco externo (figura 1.1).
2. Encienda el equipo y entre a la utilidad de BIOS de ASUS (<kbd>F2</kbd> al encender). En *Prioridad de arranque* debe aparecer la memoria USB como *UEFI: Generic Flash Disk 8.07* (figura 4.1).
3. Pulse <kbd>F8</kbd> (*Menú Arranque*) y elija **UEFI: Generic Flash Disk 8.07, Partition 1** (figura 4.2).

<p align="center">
  <img src="Imagenes%20manual/1000214234.jpeg" width="49%" alt="BIOS vista general">
  <img src="Imagenes%20manual/1000214235.jpeg" width="49%" alt="BIOS detalle"><br>
  <em>Figura 4.1. Utilidad de BIOS de ASUS (modo EZ): (a) vista general; (b) detalle del SSD Samsung de 1 TB y del orden de arranque.</em>
</p>

<p align="center">
  <img src="Imagenes%20manual/1000214236.jpeg" width="600" alt="Menú de arranque"><br>
  <em>Figura 4.2. Menú de arranque (F8): se elige la memoria USB.</em>
</p>

4. Espere a que carguen los archivos y aparezca el escritorio de Hiren's BootCD PE (figura 4.3).

<p align="center">
  <img src="Imagenes%20manual/1000214237.jpeg" width="49%" alt="Carga de Hiren's">
  <img src="Imagenes%20manual/1000214238.jpeg" width="49%" alt="Escritorio de Hiren's"><br>
  <em>Figura 4.3. Arranque de Hiren's BootCD PE: (a) carga (<code>Loading files</code>); (b) escritorio de Hiren's BootCD PE Windows 11.</em>
</p>

### 4.2 Abrir la herramienta desde el disco externo

1. Abra *This PC*. Identifique el disco externo por su tamaño: aquí es **Local Disk (G:)**, de 931 GB y conectado por USB 3.0 (figura 4.4).
2. Entre a la carpeta `IMG3_V3` y ejecute `ImagenMaestra.cmd` (figura 4.5).

<p align="center">
  <img src="Imagenes%20manual/1000214239.jpeg" width="600" alt="Unidades en Hiren's"><br>
  <em>Figura 4.4. Unidades vistas desde Hiren's. El disco externo es <code>G:</code>.</em>
</p>

> [!NOTE]
> **Las letras de unidad cambian.** En Windows el disco externo era `F:`; en Hiren's pasó a ser `G:`. La herramienta detecta su propia carpeta, así que no hay que ajustar nada.

<p align="center">
  <img src="Imagenes%20manual/1000214243.jpeg" width="49%" alt="Carpeta IMG3_V3">
  <img src="Imagenes%20manual/1000214244.jpeg" width="49%" alt="ImagenMaestra.cmd"><br>
  <em>Figura 4.5. Ubicación de la herramienta en el disco externo: (a) carpeta <code>IMG3_V3</code> en la raíz de <code>G:</code>; (b) script <code>ImagenMaestra.cmd</code>.</em>
</p>

### 4.3 Configurar la captura

1. En la ventana, vaya a la pestaña **2. Capturar imagen**.
2. En la tabla debe aparecer la partición de Windows, `C:` (351,7 GB), con la columna **Sysprep = Sí**. Esto confirma que la fase 1 terminó bien (figura 4.6).
3. Deje marcada la casilla *Añadir las particiones de recovery y datos del disco (PARTICION_n)*.

<p align="center">
  <img src="Imagenes%20manual/1000214245.jpeg" width="700" alt="Pestaña Capturar imagen"><br>
  <em>Figura 4.6. Pestaña Capturar imagen con los valores iniciales.</em>
</p>

4. Pulse **Revisar particiones** para ver qué se hará con cada partición antes de capturar (figura 4.7).

<p align="center">
  <img src="Imagenes%20manual/1000214246.jpeg" width="700" alt="Revisar particiones"><br>
  <em>Figura 4.7. Resultado de Revisar particiones.</em>
</p>

| N.º | Partición | Tamaño | Qué se hace |
|:---:|-----------|-------:|-------------|
| 1 | EFI de arranque | 0,3 GB | No se captura; el despliegue crea una nueva |
| 2 | Reservada MSR | 0,0 GB | No se captura; el despliegue crea una nueva |
| 3 | Windows (`C:`) | 351,0 GB | Índice principal de la imagen |
| 4 | Recuperación (WinRE) | 1,5 GB | Se captura |
| 5 | Datos "Datos" | 300,1 GB | Se captura (30,7 GB usados) |
| 6 | Datos "Recovery" | 300,1 GB | Se captura (102,1 GB usados) |
| 7 | Recuperación "MYASUS" (FAT32) | 0,3 GB | Se captura (0,1 GB usados) |

*Particiones del disco del equipo de referencia. Se capturan 4 particiones extra en el mismo archivo `.wim`.*

5. En **Nombre** escriba un nombre que identifique el modelo; en este caso escribimos `Asus_Imagen_maestra`. En **Descripción**, *Imagen maestra*. La línea *Se guardará en* muestra la ruta final: `G:\IMG3_V3\Imagenes\Asus_Imagen_maestra.wim` (figura 4.8).

<p align="center">
  <img src="Imagenes%20manual/1000214247.jpeg" width="700" alt="Nombre de la imagen"><br>
  <em>Figura 4.8. Nombre y descripción de la imagen.</em>
</p>

### 4.4 Ejecutar la captura

1. Pulse **Capturar imagen**.
2. Revise origen (`C:\`) y destino, y pulse **Yes** para iniciar (figura 4.9).

<p align="center">
  <img src="Imagenes%20manual/1000214248.jpeg" width="700" alt="Confirmación de la captura"><br>
  <em>Figura 4.9. Confirmación de la captura.</em>
</p>

3. Espere. La captura tarda entre **20 y 60 minutos**. La barra inferior muestra el porcentaje y el registro se guarda en `G:\IMG3_V3\Logs\captura_Asus_Imagen_maestra.log` (figura 4.10).

<p align="center">
  <img src="Imagenes%20manual/1000214249.jpeg" width="49%" alt="Inicio de la captura">
  <img src="Imagenes%20manual/1000214254.jpeg" width="49%" alt="Captura al 18 %"><br>
  <em>Figura 4.10. Captura en curso: (a) origen, destino y archivo de registro; (b) guardando la imagen (18 %).</em>
</p>

4. Al terminar aparece *Imagen capturada correctamente en G:\IMG3_V3\Imagenes* y en la consola `CAPTURA TERMINADA`. Pulse **OK** (figura 4.11).

<p align="center">
  <img src="Imagenes%20manual/IMG-20261020-WA0005.jpeg" width="700" alt="Captura terminada"><br>
  <em>Figura 4.11. Captura terminada correctamente. En la consola se ven los índices <code>PARTICION_3</code> y <code>PARTICION_4</code> añadidos al <code>.wim</code>.</em>
</p>

> [!TIP]
> **Resultado esperado:** el archivo `Asus_Imagen_maestra.wim` (124,2 GB) queda en la carpeta `Imagenes` del disco externo. El índice 1 es Windows y los índices siguientes (`PARTICION_1` a `PARTICION_4`) son las particiones de recuperación y datos.

---

## 5. Fase 3: despliegue de la imagen

Esta fase se repite en **cada equipo de destino**, también desde Hiren's BootCD PE.

### 5.1 Arrancar el equipo de destino

1. Conecte la memoria USB de Hiren's y el disco externo al equipo de destino.
2. Arranque desde la memoria USB igual que en la captura (<kbd>F8</kbd>, *UEFI: Generic Flash Disk*). Vea las figuras 4.2 y 4.3.
3. Abra `ImagenMaestra.cmd` desde la carpeta `IMG3_V3` del disco externo.

### 5.2 Elegir imagen y disco de destino

1. Vaya a la pestaña **3. Desplegar imagen**.
2. En **Imagen** elija `Asus_Imagen_maestra.wim (124,2 GB)` y en **Índice** `1 - Asus_Imagen_maestra`.
3. Compruebe a la derecha:
   - **Firmware**: UEFI (detectado).
   - **Respuesta\unattend.xml**: no (se usa el que creó la fase 1).
4. En **Disco de DESTINO** elija el disco interno. La columna *Nota* indica si la imagen cabe:

| Disco | Modelo | Tamaño | Interfaz | Nota |
|:-----:|--------|-------:|----------|------|
| 0 | Samsung MZVMA1T0HCLD-00BTW | 953,9 GB | SCSI | **Cabe** ← destino |
| 1 | Toshiba External USB | 931,5 GB | USB | Contiene las imágenes |
| 2 | Generic Flash Disk USB | 29,0 GB | USB | Pequeño: faltan 248,9 GB |

*Discos detectados. La imagen necesita un disco mínimo de 717,7 GB.*

5. Pulse **Desplegar imagen**.
6. Aparece *Confirmar borrado del disco*, con el modelo y el tamaño del disco que se va a borrar. Si es el correcto, escriba `BORRAR` y pulse **Borrar y desplegar** (figura 5.1).

<p align="center">
  <img src="Imagenes%20manual/IMG-20261020-WA0009.jpeg" width="700" alt="Confirmar borrado del disco"><br>
  <em>Figura 5.1. Confirmación del borrado del disco 0 (Samsung, 953,9 GB). Se recrearán 4 particiones de recuperación y datos.</em>
</p>

> [!IMPORTANT]
> Verifique que el disco elegido **no** sea el disco externo ni la memoria USB. La acción no se puede deshacer.

### 5.3 Proceso automático

Después de confirmar, el script hace todo sin intervención:

1. Particiona el disco según el firmware (UEFI: EFI + MSR + Windows).
2. Aplica la imagen de Windows (índice 1).
3. Inyecta los drivers de la carpeta `Drivers` (si hay).
4. Copia `Respuesta\unattend.xml` (si existe).
5. Crea el arranque con `bcdboot`.
6. Recrea después de Windows las particiones de recuperación y datos (índices `PARTICION_n`), con su tipo y atributos, y registra el entorno de recuperación (WinRE).

Al terminar aparece *Despliegue terminado. Retira el USB y el disco externo antes de que arranque Windows. ¿Reiniciar ahora?*

<p align="center">
  <img src="Imagenes%20manual/1000214388.jpeg" width="700" alt="Despliegue terminado"><br>
  <em>Figura 5.2. Despliegue terminado. Se restauraron las particiones de los índices 3, 4 y 5.</em>
</p>

7. Pulse **Yes** para reiniciar y **retire la memoria USB y el disco externo**.

### 5.4 Primer arranque del equipo desplegado

En el primer arranque Windows termina de configurar el hardware. Aparece el logotipo de arranque personalizado y el mensaje *Preparando dispositivos* (figura 5.3).

<p align="center">
  <img src="Imagenes%20manual/Image_20261020_1306382292668009792503941.jpeg" width="49%" alt="Logotipo de arranque">
  <img src="Imagenes%20manual/Image_20261020_1306535857060814094690796.jpeg" width="49%" alt="Preparando dispositivos"><br>
  <em>Figura 5.3. Primer arranque tras el despliegue: (a) logotipo de arranque; (b) Preparando dispositivos 20 %.</em>
</p>

<p align="center">
  <img src="Imagenes%20manual/1000214389.jpeg" width="550" alt="Carga de Windows 11"><br>
  <em>Figura 5.4. Carga de Windows 11.</em>
</p>

En este despliegue Windows mostró la pantalla de configuración inicial para crear el usuario:

1. En *¿Quién usará este dispositivo?* escriba el nombre del usuario (en este caso, `Estudiante`) y pulse **Siguiente** (figura 5.5).
2. En *Crear una contraseña muy fácil de recordar* deje el campo vacío para que la cuenta quede sin contraseña y pulse **Siguiente** (figura 5.6).

<p align="center">
  <img src="Imagenes%20manual/1000214390.jpeg" width="49%" alt="Nombre del usuario">
  <img src="Imagenes%20manual/1000214391.jpeg" width="49%" alt="Pulsar Siguiente"><br>
  <em>Figura 5.5. Creación de la cuenta local: (a) nombre del usuario; (b) pulsar Siguiente.</em>
</p>

<p align="center">
  <img src="Imagenes%20manual/1000214392.jpeg" width="550" alt="Pantalla de contraseña"><br>
  <em>Figura 5.6. Pantalla de contraseña.</em>
</p>

3. Espere mientras Windows prepara la sesión: *Hola*, *Lo estamos preparando todo*, *Esto podría tardar algunos minutos* y *Ya casi está*. No apague el equipo.
4. Aparece el escritorio con la personalización de la imagen: fondo *Computadores para Educar*, accesos directos a los programas educativos (Arduino IDE, Audacity, Google Chrome, entre otros) y la ventana *Contenidos Educativos CPE* (figura 5.7).

<p align="center">
  <img src="Imagenes%20manual/1000214397.jpeg" width="700" alt="Escritorio del equipo desplegado"><br>
  <em>Figura 5.7. Escritorio del equipo desplegado, con la sesión Estudiante.</em>
</p>

---

## 6. Verificación del equipo desplegado

Después del despliegue se comprobó que las particiones y el entorno de recuperación quedaron igual que en el equipo de referencia.

### 6.1 Particiones

Abra *Administración de discos* (clic derecho en Inicio → *Administración de discos*). El disco 0 debe mostrar las mismas particiones que el equipo de referencia (figura 6.1).

<p align="center">
  <img src="Imagenes%20manual/1000214427.jpeg" width="700" alt="Administración de discos"><br>
  <em>Figura 6.1. Administración de discos en el equipo desplegado. El disco 1 es el disco externo, conectado para la revisión.</em>
</p>

| Partición | Tamaño | Sistema | Estado |
|-----------|-------:|---------|--------|
| EFI (sistema) | 300 MB | FAT32 | Creada por el despliegue |
| Windows (`C:`) | 351,64 GB | NTFS | Arranque, archivo de paginación |
| Recuperación (WinRE) | 1,46 GB | NTFS | Restaurada |
| Datos (`D:`) | 300,08 GB | NTFS | Restaurada |
| Recovery (`E:`) | 300,08 GB | NTFS | Restaurada |
| MYASUS (`F:`) | 272 MB | FAT32 | Restaurada |

### 6.2 Entorno de recuperación (WinRE)

1. En la búsqueda de Windows escriba `recuperación` y abra *Opciones de recuperación* (figura 6.2).
2. En *Sistema → Recuperación*, junto a *Arranque avanzado*, pulse **Reiniciar ahora** y confirme (figura 6.3).

<p align="center">
  <img src="Imagenes%20manual/1000214428.jpeg" width="700" alt="Búsqueda de recuperación"><br>
  <em>Figura 6.2. Búsqueda de las opciones de recuperación.</em>
</p>

<p align="center">
  <img src="Imagenes%20manual/1000214429.jpeg" width="49%" alt="Sistema - Recuperación">
  <img src="Imagenes%20manual/1000214430.jpeg" width="49%" alt="Confirmar reinicio"><br>
  <em>Figura 6.3. Arranque avanzado desde Configuración: (a) Sistema → Recuperación; (b) confirmar el reinicio.</em>
</p>

3. El equipo reinicia en WinRE. En *Choose an option* elija **Troubleshoot** (figura 6.4).
4. En *Troubleshoot* deben aparecer *Reset this PC*, *MyASUS in WinRE* y *Advanced options*. Entre a **Advanced options** (figura 6.5).

<p align="center">
  <img src="Imagenes%20manual/1000214433.jpeg" width="550" alt="Choose an option"><br>
  <em>Figura 6.4. Pantalla Choose an option del entorno de recuperación: se selecciona Troubleshoot.</em>
</p>

<p align="center">
  <img src="Imagenes%20manual/1000214434.jpeg" width="49%" alt="Troubleshoot">
  <img src="Imagenes%20manual/1000214435.jpeg" width="49%" alt="Advanced options"><br>
  <em>Figura 6.5. Opciones de solución de problemas: (a) Troubleshoot, con la herramienta MyASUS; (b) Advanced options.</em>
</p>

5. Vuelva atrás y elija **Continue** para salir a Windows 11.

> [!TIP]
> **Resultado esperado:** WinRE arranca y muestra las herramientas del fabricante (MyASUS in WinRE). Eso confirma que la partición de recuperación se restauró y quedó registrada.

---

## 7. Resumen rápido

| Paso | Acción | Figura |
|:----:|--------|:------:|
| 1 | Copiar la carpeta de la herramienta a la raíz del disco externo | 2.3 |
| 2 | En Windows, sin internet: **Preparar y Sysprep** con las opciones marcadas | 3.1 |
| 3 | Si pide reiniciar por el idioma: reiniciar y repetir el paso 2 | 3.4 |
| 4 | Esperar a que Sysprep apague el equipo; **no** arrancar Windows | 3.7 |
| 5 | Arrancar Hiren's desde la USB (<kbd>F8</kbd>) con el disco externo conectado | 4.2 |
| 6 | **Capturar imagen**: revisar particiones, poner nombre y capturar | 4.8 |
| 7 | En cada equipo de destino: arrancar Hiren's y abrir la herramienta | 4.3 |
| 8 | **Desplegar imagen**: elegir imagen y disco, escribir `BORRAR` | 5.1 |
| 9 | Retirar USB y disco externo, reiniciar y completar el primer inicio | 5.7 |
| 10 | Verificar las particiones y el entorno de recuperación (WinRE) | 6.1 |

---

## Referencia técnica

### Características

- **Interfaz gráfica** (PowerShell + WinForms) con progreso en tiempo real, botón de cancelar y acceso a los logs. Si no se puede abrir, se usa un menú de texto.
- **Preparación con Sysprep**: quita las apps de la Store que bloquean Sysprep, hace limpieza de componentes y CopyProfile.
- **Idioma único es-MX** (español latinoamericano): lo instala si falta y desinstala los demás idiomas.
- **Cuenta única `AdministradorCPE`**: opcionalmente elimina las demás cuentas y deja los equipos desplegados sin configuración inicial (OOBE).
- **No se pierde ninguna partición**: las de recuperación (WinRE, recovery del fabricante) y las de datos se guardan en el mismo `.wim` como índices `PARTICION_n`, con su tipo, atributos y etiqueta.
- **Despliegue automático UEFI/BIOS**: particiona, aplica la imagen, inyecta drivers, copia `unattend.xml`, crea el arranque y restaura las particiones extra y WinRE.
- **Discos más pequeños**: calcula el espacio mínimo y reduce las particiones de datos si hace falta, sin perder archivos.
- **Verificación posterior** con informe guardado por equipo.

### Línea de comandos

```bat
ImagenMaestra.cmd gui                 :: interfaz gráfica
ImagenMaestra.cmd menu                :: menú de texto
ImagenMaestra.cmd preparar   [-QuitarAppsProblema] [-LimpiezaProfunda] [-SinCopyProfile]
                             [-CuentasCPE] [-SinClave] [-OmitirOOBE] [-AceptarIdiomaActual]
ImagenMaestra.cmd capturar   [-Origen D:] [-Nombre x] [-Descripcion "y"] [-Dividir] [-SinExtras]
ImagenMaestra.cmd particiones -Origen D:
ImagenMaestra.cmd desplegar  [-Imagen ruta.wim] [-Indice 1] [-Disco 1] [-Firmware UEFI|BIOS]
ImagenMaestra.cmd anadirparticiones [-Origen C:] [-Imagen ruta.wim]
ImagenMaestra.cmd ayuda
```

- También valen los números: `ImagenMaestra.cmd 2`.
- Los datos que no se pasen como parámetro se preguntan en la consola.
- `-Auto` no hace preguntas (lo usa la interfaz gráfica). **Ojo:** `desplegar -Auto` no pide escribir `BORRAR`.

### Precauciones

- **Revisa siempre el número de disco** antes de escribir `BORRAR`. El despliegue borra el disco de destino completo.
- Sysprep se puede ejecutar unas **8 veces** sobre la misma instalación. Guarda una copia del equipo de referencia **antes** de Sysprep para poder actualizar la imagen más adelante.
- Si Sysprep falla, revisa `C:\Windows\System32\Sysprep\Panther\setuperr.log`.
- Las imágenes capturadas con versiones anteriores pueden traer un índice `ADMINISTRACION` que ya no se aplica. Vuelve a capturarlas con esta versión.
- Si editas `ImagenMaestra.cmd`, guárdalo con **saltos de línea CRLF** y no borres las líneas marcadoras `#==PS1==#`, `#==GUI==#`, `#==CPE==#` y `#==PRT==#` (ni escribas `#==` dentro del código que va después de ellas).

### Más información

El manual de uso con todas las opciones de la herramienta está en [LEEME.txt](LEEME.txt).
