# ImagenMaestra V4: novedades y estructura del programa

`ImagenMaestra.cmd` prepara un equipo de referencia con Windows, captura su
imagen desde Hiren's BootCD PE y la despliega en otros equipos. Todo está en
un único archivo `.cmd` que lleva dentro varios scripts de PowerShell, entre
ellos una interfaz gráfica de cuatro pestañas.

> - Uso paso a paso: [`LEEME.txt`](LEEME.txt)
> - Protocolo de pruebas: [`README.md`](README.md)
> - Este documento: qué cambió en cada versión y cómo está organizado el código.

---

## Índice

1. [Estructura de la carpeta](#1-estructura-de-la-carpeta)
2. [Flujo de trabajo](#2-flujo-de-trabajo)
3. [Estructura de `ImagenMaestra.cmd`](#3-estructura-de-imagenmaestracmd)
4. [Acciones y parámetros](#4-acciones-y-parámetros)
5. [Códigos de salida](#5-códigos-de-salida)
6. [Historial de versiones y mejoras](#6-historial-de-versiones-y-mejoras)
7. [Notas para quien edite el script](#7-notas-para-quien-edite-el-script)

---

## 1. Estructura de la carpeta

La carpeta se copia a la **raíz de un disco externo NTFS**.

```
Img_V4\
├── ImagenMaestra.cmd        Programa principal (preparar, capturar, desplegar, montar)
├── CuentasCPE.cmd           Verificación de un equipo ya desplegado (en Windows)
├── ScriptsEducativos\
│   └── Verificar-Equipo.ps1 Lo lanza CuentasCPE.cmd; informe en ScriptsEducativos\Logs\
├── Imagenes\                Imágenes .wim capturadas (y .swm si se dividen)
├── Drivers\                 (opcional) drivers .inf que se inyectan al desplegar
├── Respuesta\               (opcional) unattend.xml propio para la configuración inicial
├── Logs\                    Registros de DISM y de cada fase (se crea solo)
├── Montaje\                 Carpetas de montaje de imágenes (se crea sola)
├── Scratch\                 Carpeta temporal de DISM (se crea y se borra sola)
├── LEEME.txt                Manual de uso
├── README.md                Protocolo de pruebas
├── README_V4.md             Este documento
├── daranueva.txt            Salida de una captura real (ejemplo del error 112, disco lleno)
├── _pruebas\
│   └── montar_como_system.cmd   Experimento: montar con DISM como SYSTEM (error 1299)
└── _scripts_anteriores\     Versiones anteriores, guardadas como referencia
```

---

## 2. Flujo de trabajo

| Paso | Dónde | Equipo | Pestaña / acción | Resultado |
|---|---|---|---|---|
| 1. Preparar y Sysprep | Windows | Referencia | Pestaña 1 / `preparar` | Equipo generalizado y apagado |
| 2. Capturar | Hiren's | Referencia | Pestaña 2 / `capturar` | `Imagenes\<nombre>.wim` con Windows + `PARTICION_n` |
| 3. Desplegar | Hiren's | Cada destino | Pestaña 3 / `desplegar` | Disco particionado, Windows aplicado, nombre = serial |
| 4. Verificar | Windows | Cada destino | `CuentasCPE.cmd` → [1] | Informe en `ScriptsEducativos\Logs\` |
| (opcional) Modificar | Windows o Hiren's | — | Pestaña 4 / `montar` | `.wim` cambiado sin repetir Sysprep |

Contenido del `.wim` que genera la V4:

| Índice | Nombre | Contenido |
|---|---|---|
| 1 | `<nombre>` | Partición de Windows |
| 2… | `PARTICION_1`, `PARTICION_2`… | Particiones de recuperación y de datos del equipo de referencia |

La descripción de cada índice `PARTICION_n` guarda lo necesario para recrear la
partición en el despliegue:

```
CPEPART,n-1,tipo-<GUID>,attr-0x...,mb-<tamaño>,usado-<MB>,fs-NTFS,etiqueta-<texto>,recovery-1
```

---

## 3. Estructura de `ImagenMaestra.cmd`

El archivo tiene dos partes:

- **Parte batch** (líneas 1–1563): procesa los argumentos, muestra el menú de texto y ejecuta cada acción.
- **Bloques de PowerShell** (líneas 1570–4065): cada uno empieza en una línea marcadora `#==XXX==#`. La subrutina `:extraer_ps` copia el bloque a `%TEMP%` y lo ejecuta desde ahí.

```
ImagenMaestra.cmd
│
├─ BATCH
│  ├─ Cabecera, variables y entorno (SELF, BASE, UNIDAD, ENPE)   detecta WinPE por la clave MiniNT
│  ├─ :leer_args / :ejecutar_args   parámetros -X  →  variables P_*; los demás van en OPCS
│  ├─ :gui / :gui_fallo             pide permisos (UAC) y abre la ventana; si falla, menú de texto
│  ├─ :menu / :menu_preparar        menú de texto [0]–[8]
│  ├─ :lanzar                       despachador: nombre o número de acción → etiqueta
│  ├─ :ayuda
│  ├─ :particiones                  "Revisar particiones" (PRT -Accion Revisar)
│  ├─ :preparar                     ejecuta PS1 (+CPE); gestiona el código 4 (reinicio)
│  ├─ :capturar                     dism /Capture-Image + PRT -Accion Capturar + .swm opcional
│  ├─ :anadir_particiones           añade PARTICION_n a un .wim existente
│  ├─ :desplegar                    firmware, plan, nombre, diskpart, Apply-Image, drivers,
│  │                                unattend, nombre, bcdboot, PRT -Accion Aplicar
│  ├─ :montar … :mnt_reparar        montar, guardar, desmontar, drivers, cachés de la GPU,
│  │                                listar y reparar montajes
│  └─ Utilidades: :avisar_si_no_pe, :pausa, :extraer_ps, :lista_caches, :borrar_carpeta
│
├─ #==PS1==#  Preparar y Sysprep (equipo de referencia)
├─ #==GUI==#  Interfaz gráfica WinForms (4 pestañas)
├─ #==CPE==#  Script de primer arranque (SetupComplete.cmd en cada equipo desplegado)
└─ #==PRT==#  Particiones, plan de disco y nombre del equipo
```

### 3.1 Parte batch: secciones principales

| Sección | Líneas | Qué hace |
|---|---|---|
| Cabecera y entorno | [1–49](ImagenMaestra.cmd#L1-L49) | Variables base; `ENPE=1` cuando corre en WinPE/Hiren's |
| Argumentos | [52–75](ImagenMaestra.cmd#L52-L75) | `-Auto`, `-Origen`, `-Imagen`, `-Disco`, `-NombreEquipo`… |
| Interfaz gráfica | [80–104](ImagenMaestra.cmd#L80-L104) | Extrae `GUI` y la abre con `powershell -STA` |
| Menú de texto | [109–166](ImagenMaestra.cmd#L109-L166) | Opciones 1–8; `:menu_preparar` pregunta las opciones S/N |
| Despachador | [172–195](ImagenMaestra.cmd#L172-L195) | Nombre o número de acción → etiqueta |
| Ayuda | [201–242](ImagenMaestra.cmd#L201-L242) | Texto de `ImagenMaestra.cmd ayuda` |
| Revisar particiones | [249–265](ImagenMaestra.cmd#L249-L265) | Muestra qué se hará con cada partición |
| Preparar | [271–322](ImagenMaestra.cmd#L271-L322) | Lanza PS1; con código 4 registra `RunOnce` y ofrece reiniciar |
| Capturar | [328–521](ImagenMaestra.cmd#L328-L521) | Comprueba Sysprep, excluye cachés de la GPU, captura y añade particiones |
| Añadir particiones | [530–680](ImagenMaestra.cmd#L530-L680) | Completa un `.wim` al que le faltan las `PARTICION_n` |
| Desplegar | [685–1042](ImagenMaestra.cmd#L685-L1042) | Despliegue completo en el disco elegido |
| Montar y modificar | [1051–1535](ImagenMaestra.cmd#L1051-L1535) | Montar, guardar, desmontar, inyectar drivers, borrar cachés, reparar |
| Utilidades | [1540–1563](ImagenMaestra.cmd#L1540-L1563) | `:avisar_si_no_pe`, `:pausa`, `:extraer_ps` |

### 3.2 Bloque `#==PS1==#`: Preparar y Sysprep ([línea 1570](ImagenMaestra.cmd#L1570))

Se ejecuta en el Windows del equipo de referencia, como administrador. Pasos, en orden:

1. Comprueba que el equipo **no esté en un dominio**.
2. Comprueba que **BitLocker** esté desactivado en `C:`.
3. Busca **reinicios pendientes** de Windows Update → código 4.
4. Desactiva el **almacenamiento reservado** (error 0x800F0975) → código 4 si estaba en uso.
5. **Idioma es-MX** como único idioma: lo descarga, lo fija → código 4; en la siguiente pasada quita los demás → código 4 si hace falta.
6. Quita las **apps de la Store** que bloquean Sysprep (`-QuitarAppsProblema`).
7. **Cuenta AdministradorCPE** (`-CuentasCPE`): renombra o crea la cuenta y borra las demás. Las que están en uso quedan en `CPE-EliminarCuentas.txt` para el primer arranque.
8. **Fondo común** obligatorio en `C:\Windows\Web\Wallpaper\CPE\` (salvo `-SinFondoComun`).
9. Limpia temporales, papelera y **cachés de la GPU**.
10. **Limpieza profunda** DISM `/ResetBase` (`-LimpiezaProfunda`).
11. Crea el **`unattend.xml`** (omitir la configuración inicial, idioma, teclado, zona horaria).
12. Borra la entrada `RunOnce` y `ImagenMaestra_reanudar.xml` para que **no queden dentro de la imagen**.
13. Ejecuta **Sysprep** `/generalize /oobe /shutdown`.

Funciones auxiliares: `Paso`, `Ok`, `Aviso`, `Fallo` (código 1), `Reiniciar` (código 4),
`IdiomasDelSistema`, `ReservasDe`, `IdiomaActualTexto`.

### 3.3 Bloque `#==GUI==#`: interfaz gráfica ([línea 2289](ImagenMaestra.cmd#L2289))

Usa WinForms. Para cada acción lanza el propio `.cmd` con `-Auto` y muestra su
salida en tiempo real.

| Grupo | Funciones |
|---|---|
| Controles | `Pt`, `Tam`, `Poner`, `Etiqueta`, `Boton`, `Casilla`, `Lista`, `Informar`, `Preguntar` |
| Ejecución de procesos | `Iniciar-Accion`, `Leer-Salida`, `Procesar-Linea`, `Actualizar-Barra`, `Terminar-Accion`, `Detener-Proceso`, `Modo-Ejecutando` |
| Pestaña 1, Preparar | Casillas de opciones, contraseña escrita dos veces (cifrada con DPAPI), continuación tras reinicio |
| Pestaña 2, Capturar | `Cargar-Particiones`, `Actualizar-Destino` |
| Pestaña 3, Desplegar | `Cargar-Imagenes`, `Cargar-Indices`, `Cargar-Discos`, `Actualizar-Requisitos`, `Confirmar-Borrado`, `Cargar-NombreEquipo`, `Detectar-Firmware`, `Disco-Del-Script` |
| Pestaña 4, Montar | `Cargar-MImagenes`, `Cargar-MIndices`, `Leer-Montajes`, `Cargar-Montajes`, `Montaje-Elegido`, `Ruta-Valida` |

`Terminar-Accion` interpreta los códigos de salida: 3 pregunta si aceptar el
idioma actual, y 4 guarda las opciones, registra `RunOnce` y ofrece reiniciar.

### 3.4 Bloque `#==CPE==#`: primer arranque ([línea 3557](ImagenMaestra.cmd#L3557))

Preparar lo deja en `Windows\Setup\Scripts\` y `SetupComplete.cmd` lo ejecuta
como SYSTEM en cada equipo desplegado. Borra, con su perfil, las cuentas que no
se pudieron borrar antes de Sysprep. Nunca toca AdministradorCPE ni las cuentas
integradas. Registro: `C:\Windows\Logs\CPE-Contenidos.log`.

### 3.5 Bloque `#==PRT==#`: particiones y plan de disco ([línea 3592](ImagenMaestra.cmd#L3592))

| `-Accion` | Lo usa | Qué hace |
|---|---|---|
| `Revisar` | Capturar, Añadir particiones, botón "Revisar particiones" | Inventario: qué es cada partición y si se captura, se recrea o tiene un problema |
| `Capturar` | Capturar, Añadir particiones | `dism /Append-Image` de cada partición extra como `PARTICION_n` |
| `Plan` | Desplegar | Disco mínimo, si cabe, reducción de las particiones de datos y script de diskpart (`plan.cmd`, `extras_dp.txt`) |
| `Aplicar` | Desplegar | Restaura las particiones extra con su tipo y atributos; registra WinRE (`reagentc`) |
| `Nombre` | Desplegar | Lee el serial de la BIOS y propone el nombre (`SERIAL=`, `NOMBRE=`, `MOTIVO=`) |
| `PonerNombre` | Desplegar | Escribe `ComputerName` en `Windows\Panther\unattend.xml` |
| `Funciones` | Interfaz gráfica | Solo carga las funciones |

Cálculo del espacio en el despliegue:

- **Windows** = tamaño de la imagen × 1,15 + 10 GB libres.
- **Particiones de recuperación** = tamaño original.
- **Particiones de datos** = tamaño original. Si no caben, se reducen a lo que ocupan + 20 % + 512 MB (mínimo 1 GB, y nunca más que el tamaño original).
- **Arranque** = EFI 300 MB + MSR 16 MB (UEFI), o System 500 MB (BIOS).
- Si el disco no alcanza ni con la reducción, el despliegue termina con código 2 **sin tocar el disco**.

---

## 4. Acciones y parámetros

| Acción | Nº | Entorno | Parámetros |
|---|---|---|---|
| `gui` | 5 | Ambos | — |
| `menu` | — | Ambos | — |
| `preparar` | 1 | Windows | `-QuitarAppsProblema` `-LimpiezaProfunda` `-SinFondoComun` `-CuentasCPE` `-SinClave` `-OmitirOOBE` `-AceptarIdiomaActual` |
| `particiones` | — | Hiren's | `-Origen D:` |
| `capturar` | 2 | Hiren's | `-Origen` `-Nombre` `-Descripcion` `-Dividir` `-SinExtras` |
| `anadirparticiones` | 6 | Hiren's | `-Origen C:` `-Imagen` |
| `desplegar` | 3 | Hiren's | `-Imagen` `-Indice` `-Disco` `-Firmware UEFI\|BIOS` `-NombreEquipo` |
| `montar` | 7 | Ambos | `-Imagen` `-Indice` `-Montaje` |
| `guardar` | — | Ambos | `-Montaje` |
| `desmontar` | — | Ambos | `-Montaje` `-Guardar` \| `-Descartar` |
| `inyectardrivers` | — | Ambos | `-Montaje` |
| `limpiarcaches` | — | Ambos | `-Montaje` |
| `montadas` | 8 | Ambos | — |
| `repararmontajes` | — | Ambos | — |
| `ayuda` | 4 | Ambos | — |

`-Auto` (lo usa la interfaz gráfica) no hace preguntas ni pausas.
**Con `desplegar -Auto` no se pide escribir BORRAR.**

---

## 5. Códigos de salida

| Código | Significado |
|---|---|
| 0 | Terminó bien |
| 1 | Error o cancelado |
| 2 | (Plan) El disco de destino es demasiado pequeño; no se tocó nada |
| 3 | (Preparar con `-Confirmado`) No se pudo instalar es-MX; la ventana pregunta si aceptar el idioma actual |
| 4 | (Preparar) **Hace falta reiniciar**. No es un error: Preparar continúa al iniciar sesión |
| 99 | (Preparar) Se relanzó con permisos de administrador en otra ventana |

---

## 6. Historial de versiones y mejoras

Las versiones anteriores están en [`_scripts_anteriores/`](_scripts_anteriores/).

| Versión | Archivo | Fecha | Tamaño |
|---|---|---|---|
| V1 | `1_Preparar_y_Sysprep.cmd/.ps1`, `2_Capturar.cmd`, `3_Desplegar.cmd` | 30-sep-2026 | ~500 líneas en 4 archivos |
| V2 | `ImagenMaestra_V2_sin_particion.cmd` | 10-oct-2026 | 1.584 líneas |
| V3 | `ImagenMaestra_con_ADMINISTRACION.cmd` | 15-oct-2026 | 2.953 líneas |
| V3.5 | `ImagenMaestra_antes_reinicio_20261104_1432.cmd` | 03-nov-2026 | 3.983 líneas |
| **V4** | **`ImagenMaestra.cmd`** | **nov-2026** | **4.065 líneas** |

> Los nombres V3 y V3.5 se usan solo en este documento para distinguir los dos archivos intermedios.

### V1: tres scripts separados

- `1_Preparar_y_Sysprep.ps1`: comprueba dominio, BitLocker, reinicios pendientes y almacenamiento reservado; quita apps de la Store; limpieza; `unattend.xml` con CopyProfile; Sysprep.
- `2_Capturar.cmd`: `dism /Capture-Image` de la partición de Windows.
- `3_Desplegar.cmd`: diskpart UEFI/BIOS, `Apply-Image`, drivers, `unattend.xml`, `bcdboot`.
- Sin interfaz gráfica. Se ejecuta cada script a mano.

### V2: script único con interfaz gráfica

- **Un solo `ImagenMaestra.cmd`** con PowerShell incrustado (bloques `#==PS1==#` y `#==GUI==#`).
- **Interfaz WinForms de 3 pestañas**: listas de particiones, imágenes, índices y discos (modelo y tamaño), salida en tiempo real, barra de progreso, botones "Cancelar" y "Carpeta Logs".
- Si la ventana no se puede abrir (WinPE sin .NET), se usa el **menú de texto**.
- **Línea de comandos** con acciones y parámetros, y el modo `-Auto`.
- Pide **permisos de administrador** solo en Windows.
- **No deja elegir el disco** que contiene las imágenes.
- Opcionalmente genera una **copia `.swm`** para USB FAT32.

### V3: cuentas, particiones extra y plan de disco

- **Cuenta única AdministradorCPE** (`-CuentasCPE`, `-SinClave`): renombra la cuenta de trabajo y borra las demás. La contraseña se escribe dos veces y se pasa cifrada con DPAPI.
- **Sin configuración inicial** (`-OmitirOOBE`): los equipos desplegados arrancan directo al inicio de sesión.
- **Script de primer arranque** (`#==CPE==#`, vía `SetupComplete.cmd`).
- **Particiones de recuperación y datos** (`#==PRT==#`): se capturan como índices `PARTICION_n` y se recrean al desplegar con su tipo, atributos y WinRE (`-SinExtras` para omitirlas).
- Botón **"Revisar particiones"** antes de capturar. Se detiene si hay una partición cifrada o ilegible.
- **Plan de disco**: calcula el disco mínimo y despliega en discos más pequeños reduciendo las particiones de datos.
- Partición oculta **ADMINISTRACION** con la carpeta `Contenidos\` (índice 2), con `-ParticionContenidos`, `-TamanoContenidos` y `-Contenidos GB`. *(Se quitó en V3.5.)*
- **Verificación** de equipos desplegados con `CuentasCPE.cmd` y `Verificar-Equipo.ps1`.

### V3.5: montar imágenes, nombre por serial, idioma y fondo

- **Pestaña 4 "Montar y modificar"**: montar cualquier índice, guardar sin desmontar, desmontar guardando o descartando, inyectar drivers, listar montajes y **reparar montajes huérfanos** ("Needs Remount").
- Protecciones al montar: carpeta vacía en NTFS, **no permite OneDrive**, y limpia sola un montaje fallido.
- **Error 1299 resuelto**: Preparar borra y Capturar excluye las **cachés de sombreadores de la GPU** (AMD, NVIDIA, Intel). Para imágenes antiguas está el botón "Borrar cachés de la GPU" (`limpiarcaches`).
- **`anadirparticiones`**: completa un `.wim` al que le faltan las `PARTICION_n` (por ejemplo, tras el *error 112: disco lleno* de [`daranueva.txt`](daranueva.txt)) sin volver a capturar Windows. Comprueba que no haya índices `PARTICION_` repetidos.
- **Nombre del equipo = serial de la BIOS** (`-NombreEquipo` para cambiarlo). Detecta seriales falsos ("To be filled by O.E.M.", "Default string"), aplica las reglas de Windows (15 caracteres, sin solo números) y lo escribe en `unattend.xml` antes del primer arranque.
- **Idioma es-MX como único idioma**: lo descarga, lo fija en pantalla, sistema, bienvenida y usuarios nuevos, y quita los demás. `-AceptarIdiomaActual` si no hay internet.
- **Fondo de escritorio común y bloqueado** para todas las cuentas, también las nuevas (`-SinFondoComun` para no hacerlo).
- **ADMINISTRACION eliminada**. Si una imagen antigua trae ese índice, ya no se aplica.
- Registros: `Scratch\` evita el *Error 267* de DISM, y el `dism.log` de Hiren's se copia a `Logs\dism_hirens.log` (en `X:` se perdería al reiniciar).

### V4 (actual): reinicios guiados y continuación automática

Los cambios respecto a V3.5 son estos:

1. **Reiniciar ya no se trata como un error.** Antes, Preparar terminaba con "[X] REINICIA el equipo y vuelve a ejecutar" en cuatro casos: reinicio pendiente de Windows Update, almacenamiento reservado, idioma recién instalado e idiomas desinstalados. Ahora sale con el **código 4** y un aviso amarillo `[REINICIO]`.
2. **Ofrece "¿Reiniciar ahora?"**, tanto en la ventana como en el menú de texto. Con Sí reinicia en 5 segundos.
3. **Continúa sola al iniciar sesión.**
   - **Ventana:** guarda las opciones en `%LOCALAPPDATA%\ImagenMaestra_reanudar.xml`, con la contraseña aún cifrada con DPAPI, y registra `RunOnce`. Al iniciar sesión con la misma cuenta, la ventana se abre en la pestaña 1 y pregunta si continuar. **No vuelve a pedir la contraseña.**
   - **Menú de texto:** registra en `RunOnce` la misma orden `preparar` con las mismas opciones.
4. **Freno contra bucles.** Si Preparar pide reiniciar **3 veces seguidas por el mismo motivo**, se detiene y desactiva la continuación automática.
5. **Cancelar funciona.** Si se responde No a "¿Continuar Preparar?", se borra la continuación y la ventana ya no se abre sola.
6. **La imagen sale limpia.** Antes de Sysprep se borran la entrada `RunOnce` y el archivo de continuación, para que no lleguen a los equipos desplegados.
7. **Se quitó CopyProfile** (`-SinCopyProfile` y su casilla). Solo funcionaba desde el Administrador integrado del modo auditoría y, desde una cuenta normal, podía dejar la configuración inicial en bucle. La personalización llega a los equipos por la propia cuenta AdministradorCPE y el fondo común.
8. **Más fiable con "aceptar idioma actual".** Al relanzar con `-AceptarIdiomaActual`, la ventana conserva los argumentos y la contraseña. Así, si después hace falta un reinicio, la continuación usa las opciones correctas.

### Resumen por función

| Función | V1 | V2 | V3 | V3.5 | V4 |
|---|:-:|:-:|:-:|:-:|:-:|
| Script único + interfaz gráfica | | ✔ | ✔ | ✔ | ✔ |
| Línea de comandos con `-Auto` | | ✔ | ✔ | ✔ | ✔ |
| AdministradorCPE + sin configuración inicial | | | ✔ | ✔ | ✔ |
| Particiones de recuperación y datos (`PARTICION_n`) | | | ✔ | ✔ | ✔ |
| Despliegue en discos más pequeños | | | ✔ | ✔ | ✔ |
| Partición ADMINISTRACION | | | ✔ | | |
| Montar y modificar `.wim` | | | | ✔ | ✔ |
| Sin error 1299 (cachés de la GPU) | | | | ✔ | ✔ |
| Añadir particiones a un `.wim` existente | | | | ✔ | ✔ |
| Nombre del equipo = serial | | | | ✔ | ✔ |
| Idioma es-MX único | | | | ✔ | ✔ |
| Fondo común bloqueado | | | | ✔ | ✔ |
| CopyProfile | ✔ | ✔ | ✔ | ✔ | |
| Reinicio guiado + continuación automática | | | | | ✔ |

---

## 7. Notas para quien edite el script

- Guárdalo con saltos de línea **CRLF**. Con LF, CMD interpreta mal las etiquetas.
- No borres las líneas `#==PS1==#`, `#==GUI==#`, `#==CPE==#` y `#==PRT==#`, ni escribas `#==` dentro de los bloques: `:extraer_ps` las usa para cortar cada bloque.
- La parte batch usa `EnableDelayedExpansion`. Dentro de bloques `( … )` usa `!var!`, y no pongas `!` en textos ni rutas. La interfaz rechaza rutas con `" & % ! ^ < > |` (`Ruta-Valida`).
- Una acción nueva necesita:
  - una etiqueta,
  - una línea en `:lanzar`,
  - una entrada en `:ayuda`,
  - si se usa desde la ventana, que acepte `-Auto`.
- Para los códigos de salida nuevos de Preparar, revisa `Terminar-Accion` en la interfaz y el tratamiento de `RC` en `:preparar`.
