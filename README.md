# 🎮 Control de Videojuego con FPGA
## Dual Shooter - Integración de Acelerómetro y Switches

<div align="center">

![FPGA](https://img.shields.io/badge/FPGA-Intel_MAX_10-0071C5?style=for-the-badge&logo=intel)
![VHDL](https://img.shields.io/badge/VHDL-Hardware_Design-FF6B6B?style=for-the-badge)
![Processing](https://img.shields.io/badge/Processing-Game_Engine-006699?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Completed-success?style=for-the-badge)

---

**Diseño de Lógica Programable**  
*Tecnológico de Monterrey*

**Autor:** Alfonso Solis Diaz  
**Matrícula:** A00838034  
**Profesor:** Roberto Mora

---

</div>

## 📋 Resumen

Este proyecto implementa un sistema de control para un videojuego tipo "shooter" utilizando una **FPGA DE10-Lite**. El sistema integra el **acelerómetro interno ADXL345** de la placa para detectar inclinación (movimiento arriba/abajo) y **switches físicos** para disparar. La comunicación con el juego ejecutándose en una PC se realiza mediante **UART** a través del Arduino integrado en modo bypass.

El proyecto demuestra la integración de:
- Sensores (acelerómetro ADXL345)
- Comunicación serial (SPI y UART)
- Lógica digital en VHDL
- Integración hardware-software

---

## 🎯 Objetivos del Proyecto

- Diseñar e implementar un controlador de videojuego utilizando una FPGA
- Demostrar conocimientos en:
  - ✅ Diseño digital con VHDL
  - ✅ Comunicación SPI con sensores
  - ✅ Comunicación UART
  - ✅ Máquinas de estado
  - ✅ Integración hardware-software

---

## 🏗️ Arquitectura del Sistema

El sistema consta de tres componentes principales:

```
┌─────────────────┐      SPI       ┌─────────────────────────────────────┐
│   Acelerómetro  │───────────────►│                                     │
│     ADXL345     │                │            FPGA DE10-Lite           │
└─────────────────┘                │                                     │
                                   │  ┌─────────────────────────────┐    │
┌─────────────────┐                │  │  • spi_master.vhd           │    │
│    Switches     │───────────────►│  │  • accel_driver.vhd         │    │
│   SW[0], SW[1]  │                │  │  • UART TX (115200 bps)     │    │
└─────────────────┘                │  │  • Detección de inclinación │    │
                                   │  └─────────────────────────────┘    │
                                   └──────────────┬──────────────────────┘
                                                  │ UART TX
                                                  ▼
                                   ┌─────────────────────────────────────┐
                                   │         Arduino (Bypass Mode)       │
                                   │         USB-Serial Adapter          │
                                   └──────────────┬──────────────────────┘
                                                  │ USB
                                                  ▼
                                   ┌─────────────────────────────────────┐
                                   │              PC                     │
                                   │     Processing (DualShooter)        │
                                   └─────────────────────────────────────┘
```

---

## ⚙️ Hardware Utilizado

### Placa DE10-Lite

| Característica | Especificación |
|----------------|----------------|
| FPGA | Intel MAX 10 10M50DAF484C7G |
| Elementos Lógicos | 50,000 |
| Clock | 50 MHz (oscilador interno) |
| Acelerómetro | ADXL345 (3 ejes, SPI) |
| Switches | 10 (SW0-SW9) |
| LEDs | 10 (LEDR0-LEDR9) |
| Arduino Header | Compatible con Arduino Uno R3 |

### Acelerómetro ADXL345

| Señal | Pin FPGA | Función |
|-------|----------|---------|
| GSENSOR_CS_N | PIN_AB16 | Chip Select (activo bajo) |
| GSENSOR_SCLK | PIN_AB15 | Clock SPI |
| GSENSOR_SDI | PIN_V11 | Data In (MOSI) |
| GSENSOR_SDO | PIN_V12 | Data Out (MISO) |
| GSENSOR_INT1 | PIN_Y14 | Interrupción 1 |

---

## 🔌 Conexiones del Sistema

### Modo Bypass del Arduino

Para utilizar el Arduino como adaptador USB-Serial:

1. **Conectar RESET a GND**: Jumper entre pin RESET y GND
2. **FPGA TX a Arduino D1**: PIN_AB6 → D1 (TX)
3. **USB a PC**: Cable USB del Arduino a la computadora

| Origen | Conexión | Destino |
|--------|----------|---------|
| FPGA: PIN_AB6 (uart_tx) | Cable | Arduino: D1 (TX) |
| Arduino: RESET | Jumper | Arduino: GND |
| Arduino: USB | Cable USB | PC: Puerto COM |

### Asignación de Pines FPGA

| Señal VHDL | Pin | I/O Standard | Descripción |
|------------|-----|--------------|-------------|
| clk | PIN_P11 | 3.3-V LVTTL | Clock 50 MHz |
| reset_n | PIN_B8 | 3.3V Schmitt | KEY[0] (Reset) |
| key1 | PIN_A7 | 3.3V Schmitt | KEY[1] (START/PAUSE) |
| sw[0] | PIN_C10 | 3.3-V LVTTL | Switch 0 (Disparo Izq) |
| sw[1] | PIN_C11 | 3.3-V LVTTL | Switch 1 (Disparo Der) |
| uart_tx | PIN_AB6 | 3.3-V LVTTL | UART TX |
| ledr[0-5] | PIN_A8... | 3.3-V LVTTL | LEDs indicadores |

---

## 💻 Diseño en VHDL

### Módulos del Sistema

| Módulo | Descripción |
|--------|-------------|
| `top_dual_shooter_simple` | Módulo principal que integra todos los componentes |
| `spi_master` | Controlador SPI para comunicación con el ADXL345 |
| `accel_driver` | Driver específico para configurar y leer el ADXL345 |
| `clock_div` | Divisor de frecuencia para generar el clock SPI |

### Detección de Inclinación

```vhdl
-- Extraer eje Y de los datos del acelerómetro
accel_y <= signed(accel_data(31 downto 16));

-- Detección de inclinación con umbral
move_up   <= '1' when accel_y > TILT_THRESHOLD else '0';
move_down <= '1' when accel_y < -TILT_THRESHOLD else '0';
```

### Comandos UART

```vhdl
constant CMD_UP    : std_logic_vector(7 downto 0) := x"55";  -- 'U'
constant CMD_DOWN  : std_logic_vector(7 downto 0) := x"44";  -- 'D'
constant CMD_LEFT  : std_logic_vector(7 downto 0) := x"4C";  -- 'L'
constant CMD_RIGHT : std_logic_vector(7 downto 0) := x"52";  -- 'R'
constant CMD_START : std_logic_vector(7 downto 0) := x"53";  -- 'S' (START/PAUSE)
```

### Parámetros Optimizados

| Parámetro VHDL | Valor | Descripción |
|----------------|-------|-------------|
| SEND_INTERVAL | 800,000 ciclos (16 ms) | ~62 comandos/segundo |
| DEBOUNCE_LIMIT | 250,000 ciclos (5 ms) | Anti-rebote ultra rápido |
| TILT_THRESHOLD | 15 | Alta sensibilidad |

---

## 📡 Comunicación SPI

### Protocolo

El ADXL345 utiliza **SPI Modo 3**:
- **CPOL = 1**: Clock en alto cuando está inactivo
- **CPHA = 1**: Datos muestreados en flanco de subida

### Registros Utilizados

| Registro | Dirección | Función |
|----------|-----------|---------|
| DATA_FORMAT | 0x31 | Configuración de formato |
| BW_RATE | 0x2C | Velocidad de muestreo |
| POWER_CTL | 0x2D | Control de energía |
| DATAX0-DATAZ1 | 0x32-0x37 | Datos de aceleración |

---

## 🎮 Software del Juego (Processing)

### Características

**Pantalla de Inicio:**
- Menú principal con nave animada flotando
- Fondo de estrellas con parpadeo suave
- Mensaje "Press KEY[1] to START" parpadeante
- Indicador de estado FPGA (conectada/desconectada)
- Presionar KEY[1] inicia el juego

**Mecánicas de juego:**
- Mover la nave verticalmente usando el acelerómetro
- Disparar a enemigos que vienen de ambos lados
- Sistema de combo: disparos consecutivos multiplican el puntaje
- Niveles progresivos con dificultad incrementada
- Pausar con KEY[1] durante el juego

**Características visuales (estilo cyberpunk):**
- Pantalla completa con fondo de estrellas animadas
- Efectos de glow y partículas en explosiones
- Screen shake al recibir daño
- HUD profesional con gradientes

### Parámetros del Juego

| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| playerSpeed | 14 | Velocidad de movimiento |
| bulletSpeed | 20 | Velocidad de las balas |
| shootCooldown | 60 ms | Tiempo entre disparos |
| FPGA Timeout | 40 ms | Tiempo para resetear flags |
| Lerp Factor | 0.6 | Suavizado de movimiento |

### Optimización de Lectura Serial

```java
// Lee TODOS los bytes disponibles (no solo uno)
while (fpgaSerial.available() > 0) {
    char cmd = char(fpgaSerial.read());
    // Procesar comando...
}
```

---

## 🎯 Controles

### Controles FPGA

| Entrada | Comando UART | Acción |
|---------|--------------|--------|
| Inclinar hacia ti | `U` | Mover nave arriba |
| Inclinar lejos | `D` | Mover nave abajo |
| Switch SW[0] | `L` | Disparar izquierda |
| Switch SW[1] | `R` | Disparar derecha |
| **KEY[1]** | `S` | **START / PAUSE / Reanudar** |
| KEY[0] | - | Reset del sistema |

### Controles Teclado (alternativo)

| Tecla | Acción |
|-------|--------|
| W / S | Mover arriba / abajo |
| A | Disparar izquierda |
| D | Disparar derecha |
| ENTER | Iniciar / Pausar |
| P | Pausar |
| R | Reiniciar |

### Indicadores LED

| LED | Indicación |
|-----|------------|
| LEDR[0] | Switch 0 activo (disparo izquierdo) |
| LEDR[1] | Switch 1 activo (disparo derecho) |
| LEDR[2] | Inclinación hacia arriba detectada |
| LEDR[3] | Inclinación hacia abajo detectada |
| LEDR[4] | Transmisión UART activa |
| LEDR[5] | KEY[1] presionado (START/PAUSE) |

---

## 📁 Estructura del Proyecto

```
FPGA-DualShooter-Accelerometer/
│
├── 📂 VHDL/
│   ├── top_dual_shooter_simple.vhd   # Módulo principal
│   ├── spi_master.vhd                # Controlador SPI
│   ├── accel_driver.vhd              # Driver ADXL345
│   ├── clock_div.vhd                 # Divisor de frecuencia
│   └── decoder7seg.vhd               # Decodificador 7-seg
│
├── 📂 Processing/
│   └── DualShooter.pde               # Juego en Processing
│
├── .gitignore
└── README.md
```

---

## 🚀 Guía de Instalación

### Requisitos

- [Quartus Prime Lite](https://www.intel.com/content/www/us/en/software/programmable/quartus-prime/download.html) (para FPGA)
- [Processing 4](https://processing.org/download) (para el juego)
- [PuTTY](https://www.putty.org/) (opcional, para debugging serial)

### Paso 1: Programar la FPGA

1. Abrir Quartus Prime
2. Abrir el proyecto (`.qpf`)
3. Compilar el proyecto
4. Programar el archivo `.sof` en la DE10-Lite

### Paso 2: Configurar Arduino (Modo Bypass)

1. Conectar un jumper entre **RESET** y **GND**
2. Conectar cable USB del Arduino a la PC
3. Verificar el puerto COM asignado (Device Manager)

### Paso 3: Ejecutar el Juego

1. Abrir Processing
2. Abrir `DualShooter/DualShooter.pde`
3. Modificar `SERIAL_PORT` con tu puerto COM:
   ```java
   String SERIAL_PORT = "COM3";  // Cambiar según tu sistema
   ```
4. Click en **Run** (▶)

---

## � Solución de Problemas

| Problema | Solución |
|----------|----------|
| No aparecen caracteres en PuTTY | Verificar jumper RESET-GND en Arduino |
| Caracteres ilegibles | Verificar baud rate (debe ser 115200) |
| Puerto COM no disponible | Cerrar otras aplicaciones que usen el puerto |
| Acelerómetro no responde | Verificar conexiones SPI y que el código esté programado |
| Juego no responde | Verificar puerto COM en el código de Processing |

---

## 📊 Resultados

- ✅ Comunicación exitosa con el acelerómetro ADXL345 mediante SPI
- ✅ Detección de inclinación funcional con umbral optimizado
- ✅ Switches con tiempo de debounce de 5 ms
- ✅ Comunicación UART estable a 115200 bps
- ✅ Respuesta del juego ~62 comandos/segundo
- ✅ Juego fluido con efectos visuales profesionales

---

## � Referencias

1. Intel Corporation. "DE10-Lite User Manual". Terasic Technologies.
2. Analog Devices. "ADXL345 Digital Accelerometer Datasheet".
3. [bjohnsonfl/SPI_Accelerometer](https://github.com/bjohnsonfl/SPI_Accelerometer) - Módulos SPI y driver ADXL345
4. Processing Foundation. "Processing Reference". https://processing.org/reference/

---

## 📄 Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para más detalles.

---

<div align="center">

**Tecnológico de Monterrey**  
*Diseño de Lógica Programable*  
*Enero 2026*

---

⭐ **¡Dale una estrella si te gustó el proyecto!** ⭐

</div>
