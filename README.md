# 🎮 FPGA Dual Shooter - Control por Acelerómetro

<div align="center">

![VHDL](https://img.shields.io/badge/VHDL-Hardware-blue)
![Processing](https://img.shields.io/badge/Processing-Game-green)
![DE10-Lite](https://img.shields.io/badge/FPGA-DE10--Lite-orange)
![License](https://img.shields.io/badge/License-MIT-yellow)

**Proyecto de Diseño Digital con Dispositivos Programables**

*Control de videojuego mediante acelerómetro y comunicación UART*

</div>

---

## 📋 Descripción

Este proyecto implementa un sistema de control para un videojuego tipo "shooter" utilizando una FPGA DE10-Lite. El sistema integra:

- 🔄 **Acelerómetro ADXL345** integrado en la placa para detectar inclinación
- 📡 **Comunicación UART** a 115200 bps hacia la PC
- 🎮 **Juego en Processing** con gráficos estilo cyberpunk
- ⚡ **Respuesta ultra rápida** (~62 comandos/segundo)

---

## 🏗️ Arquitectura del Sistema

```
┌─────────────┐    UART TX     ┌─────────────┐      USB      ┌─────────────┐
│    FPGA     │───────────────►│   Arduino   │──────────────►│     PC      │
│  DE10-Lite  │   115200 bps   │  USB-Serial │               │  Processing │
│  ADXL345    │                │ (Modo Bypass)│               │ DualShooter │
└─────────────┘                └─────────────┘               └─────────────┘
```

---

## 🎯 Controles

| Entrada | Comando | Acción en el juego |
|---------|---------|-------------------|
| Inclinar FPGA hacia ti | `U` | Mover nave arriba |
| Inclinar FPGA lejos | `D` | Mover nave abajo |
| Switch SW[0] | `L` | Disparar izquierda |
| Switch SW[1] | `R` | Disparar derecha |

---

## 📁 Estructura del Proyecto

```
FPGA-DualShooter-Accelerometer/
├── 📂 VHDL/
│   ├── top_dual_shooter_simple.vhd   # Módulo principal
│   ├── spi_master.vhd                # Controlador SPI
│   ├── accel_driver.vhd              # Driver ADXL345
│   ├── clock_div.vhd                 # Divisor de frecuencia
│   └── decoder7seg.vhd               # Decodificador 7-seg (debug)
│
├── 📂 DualShooter/
│   └── DualShooter.pde               # Juego en Processing
│
├── 📂 Documentacion/
│   └── documentacion_proyecto.tex    # Documentación LaTeX
│
├── 📂 Quartus/
│   └── *.qpf, *.qsf                  # Archivos de proyecto Quartus
│
└── README.md
```

---

## ⚙️ Hardware Requerido

| Componente | Descripción |
|------------|-------------|
| **DE10-Lite** | FPGA Intel MAX 10 con acelerómetro ADXL345 integrado |
| **Arduino Uno** | Usado como adaptador USB-Serial (modo bypass) |
| **Cable USB** | Para conectar Arduino a la PC |
| **Jumper** | Para conectar RESET-GND en Arduino |

---

## 🔌 Conexiones

1. **Jumper en Arduino**: Conectar pin `RESET` a `GND`
2. **FPGA a Arduino**: `PIN_AB6 (uart_tx)` → `D1 (TX)`
3. **Arduino a PC**: Cable USB

---

## 🚀 Instalación y Uso

### 1. Programar la FPGA
```bash
# Abrir proyecto en Quartus Prime
# Compilar y programar el archivo .sof en la DE10-Lite
```

### 2. Configurar Arduino (Modo Bypass)
```bash
# Conectar jumper entre RESET y GND
# Conectar USB a la PC
```

### 3. Ejecutar el Juego
```bash
# Abrir Processing
# Abrir DualShooter/DualShooter.pde
# Verificar puerto COM en el código (línea ~26)
# Click en Run
```

---

## 📊 Parámetros de Configuración

### VHDL (top_dual_shooter_simple.vhd)
| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| `SEND_INTERVAL` | 800,000 ciclos (16ms) | ~62 comandos/seg |
| `DEBOUNCE_LIMIT` | 250,000 ciclos (5ms) | Anti-rebote |
| `TILT_THRESHOLD` | 15 | Sensibilidad del acelerómetro |

### Processing (DualShooter.pde)
| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| `SERIAL_PORT` | "COM3" | Puerto del Arduino |
| `playerSpeed` | 14 | Velocidad del jugador |
| `shootCooldown` | 60ms | Tiempo entre disparos |

---

## 🎨 Características del Juego

- ✨ Pantalla completa
- 🌟 Fondo de estrellas animadas
- 💥 Explosiones con partículas
- 📳 Screen shake al recibir daño
- 🔥 Sistema de combos
- 📈 Niveles progresivos

---

## 📸 Capturas

> *Agregar capturas del juego y del hardware aquí*

---

## 📚 Documentación

La documentación completa del proyecto se encuentra en formato LaTeX en la carpeta `Documentacion/`.

---

## 👥 Autores

- **[Tu Nombre]** - *Desarrollo completo* - [@AldonDC](https://github.com/AldonDC)

---

## 📄 Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para más detalles.

---

## 🙏 Agradecimientos

- [bjohnsonfl/SPI_Accelerometer](https://github.com/bjohnsonfl/SPI_Accelerometer) - Módulos SPI y driver ADXL345
- Terasic - DE10-Lite User Manual
- Analog Devices - ADXL345 Datasheet

---

<div align="center">

**⭐ Si te gustó el proyecto, dale una estrella! ⭐**

</div>
