# Imagenes_Maestras_CPE

Herramienta para **preparar, capturar y desplegar imágenes maestras de Windows** en equipos de forma masiva, usando un disco externo y un USB de arranque con **Hiren's BootCD PE**.

Todo el proceso se maneja desde un solo script (`ImagenMaestra.cmd`) con interfaz gráfica de tres pestañas (o menú de texto si no hay .NET). Un segundo script (`CuentasCPE.cmd`) verifica cada equipo una vez desplegado.

---

## Características

- **Interfaz gráfica** (PowerShell + WinForms) con progreso en tiempo real, botón de cancelar y acceso a los logs. Si no se puede abrir, se usa un menú de texto.
- **Preparación con Sysprep**: quita las apps de la Store que bloquean Sysprep, hace limpieza de componentes y CopyProfile.
- **Idioma único es-MX** (español latinoamericano): lo instala si falta y desinstala los demás idiomas.
- **Cuenta única `AdministradorCPE`**: opcionalmente elimina las demás cuentas y deja los equipos desplegados sin configuración inicial (OOBE).
- **No se pierde ninguna partición**: las de recuperación (WinRE, recovery del fabricante) y las de datos se guardan en el mismo `.wim` como índices `PARTICION_n`, con su tipo, atributos y etiqueta.
- **Despliegue automático UEFI/BIOS**: particiona, aplica la imagen, inyecta drivers, copia `unattend.xml`, crea el arranque y restaura las particiones extra y WinRE.
- **Discos más pequeños**: calcula el espacio mínimo y reduce las particiones de datos si hace falta, sin perder archivos.
- **Verificación posterior** con informe guardado por equipo.

## Requisitos

- Equipo de referencia con Windows instalado y personalizado.
- USB de arranque con **Hiren's BootCD PE**.
- Disco externo **NTFS** con espacio suficiente para las imágenes.
- Una licencia de Windows para cada equipo de destino.

## Estructura

Copia la carpeta completa a la **raíz** del disco externo:

```
Imagenes_Maestras_CPE\
├── ImagenMaestra.cmd        # Script único: preparar, capturar y desplegar
├── CuentasCPE.cmd           # Verificación de cada equipo ya desplegado
├── LEEME.txt                # Manual de uso detallado
├── ScriptsEducativos\
│   └── Verificar-Equipo.ps1 # Lo usa CuentasCPE.cmd (no hace falta abrirlo)
├── Imagenes\                # Aquí se guardan los .wim capturados
├── Drivers\                 # (Opcional) drivers .inf a inyectar al desplegar
├── Respuesta\               # (Opcional) unattend.xml propio
├── Logs\                    # Registros de DISM (se crea sola)
└── _scripts_anteriores\     # Versiones anteriores, solo como referencia
```

Las carpetas `Imagenes\`, `Drivers\` y `Respuesta\` no están en el repositorio; se crean en el disco externo según se necesiten.

## Uso rápido

Doble clic en `ImagenMaestra.cmd`. Se abre una ventana con tres pestañas:

| Paso | Pestaña | Dónde se ejecuta |
|------|---------|------------------|
| 1 | Preparar y Sysprep | Windows, equipo de referencia |
| 2 | Capturar imagen | Hiren's, equipo de referencia |
| 3 | Desplegar imagen | Hiren's, equipo de destino |

### 1. Preparar (Windows, equipo de referencia)

1. Personaliza el equipo, idealmente en **modo auditoría** (`Ctrl+Shift+F3` en la pantalla de región durante la instalación).
2. Desconecta internet para que la Store no actualice apps y rompa Sysprep. La excepción es cuando el equipo no tiene el idioma es-MX: esa vez sí hace falta internet para descargarlo y luego pedirá reiniciar.
3. Ejecuta la pestaña **Preparar** y elige las opciones.
4. El equipo se apaga. **No lo enciendas en Windows.**

### 2. Capturar (Hiren's, equipo de referencia)

1. Arranca desde el USB de Hiren's con el disco externo conectado.
2. Ejecuta `ImagenMaestra.cmd` desde el disco externo y elige **Capturar**.
3. Se crea `Imagenes\<nombre>.wim` (índice 1 = Windows, más un índice `PARTICION_n` por cada partición de recovery o datos). Con **Revisar particiones** se ve qué se hará con cada partición antes de capturar.

### 3. Desplegar (Hiren's, equipo de destino)

1. Arranca el equipo de destino con Hiren's y conecta el disco externo.
2. Elige **Desplegar**, la imagen y el disco de destino. Antes de pedir confirmación se comprueba que la imagen cabe.
3. Escribe `BORRAR` para confirmar. Al terminar, reinicia: Windows arranca directo al inicio de sesión con `AdministradorCPE` (o hace la configuración inicial, si la imagen se preparó sin omitirla).

### 4. Verificar (Windows, equipo ya desplegado)

Ejecuta `CuentasCPE.cmd` desde el disco externo y elige **[1] Verificación completa**. No cambia nada; revisa el despliegue, las particiones, WinRE y las cuentas, y guarda un informe en `ScriptsEducativos\Logs\Verificacion-<equipo>-<fecha>.txt`.

## Línea de comandos

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

## Precauciones

- **Revisa siempre el número de disco** antes de escribir `BORRAR`. El despliegue borra el disco de destino completo.
- Sysprep se puede ejecutar unas **8 veces** sobre la misma instalación. Guarda una copia del equipo de referencia **antes** de Sysprep para poder actualizar la imagen más adelante.
- Si Sysprep falla, revisa `C:\Windows\System32\Sysprep\Panther\setuperr.log`.
- Las imágenes capturadas con versiones anteriores pueden traer un índice `ADMINISTRACION` que ya no se aplica. Vuelve a capturarlas con esta versión.
- Si editas `ImagenMaestra.cmd`, guárdalo con **saltos de línea CRLF** y no borres las líneas marcadoras `#==PS1==#`, `#==GUI==#`, `#==CPE==#` y `#==PRT==#` (ni escribas `#==` dentro del código que va después de ellas).

## Más información

El manual completo, con todas las opciones explicadas paso a paso, está en [LEEME.txt](LEEME.txt).
