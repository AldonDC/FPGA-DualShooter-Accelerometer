--------------------------------------------------------------------------------
-- File: top_dual_shooter_simple.vhd
-- Project: Dual Shooter FPGA - Switches + Acelerómetro (usando repo SPI)
-- Target: Intel MAX 10 10M50DAF484C7G (DE10-Lite)
--------------------------------------------------------------------------------
-- 
-- COMPORTAMIENTO:
--   SW[0] = Envía 'L' mientras está activo (disparo izquierdo)
--   SW[1] = Envía 'R' mientras está activo (disparo derecho)
--   Posición horizontal = No envía nada
--   Inclinar hacia ti = Envía 'U' (mover arriba)
--   Inclinar lejos = Envía 'D' (mover abajo)
--
-- LEDs:
--   LEDR[0] = SW[0] activo
--   LEDR[1] = SW[1] activo
--   LEDR[2] = Inclinación ARRIBA
--   LEDR[3] = Inclinación ABAJO
--   LEDR[4] = TX activo
--
-- Usa los componentes del repositorio bjohnsonfl/SPI_Accelerometer
--
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_dual_shooter_simple is
    port (
        clk          : in  std_logic;                      -- PIN_P11
        reset_n      : in  std_logic;                      -- PIN_B8
        sw           : in  std_logic_vector(1 downto 0);   -- PIN_C10, PIN_C11
        uart_tx      : out std_logic;                      -- PIN_AB6
        ledr         : out std_logic_vector(4 downto 0);   -- LEDs
        -- Acelerómetro ADXL345
        GSENSOR_CS_N : out std_logic;                      -- PIN_AB16
        GSENSOR_SCLK : out std_logic;                      -- PIN_AB15
        GSENSOR_SDI  : out std_logic;                      -- PIN_V11
        GSENSOR_SDO  : in  std_logic                       -- PIN_V12
    );
end entity top_dual_shooter_simple;

architecture rtl of top_dual_shooter_simple is

    -- UART timing (115200 baud @ 50MHz)
    constant CLKS_PER_BIT : integer := 434;
    
    -- Timer para envío (16 ms = 800K ciclos) - ULTRA RÁPIDO ~62 comandos/seg
    constant SEND_INTERVAL : integer := 800000;
    signal send_timer : integer range 0 to SEND_INTERVAL := 0;
    
    -- Debounce switches (5ms) - ULTRA RÁPIDO
    constant DEBOUNCE_LIMIT : integer := 250000;
    signal db_cnt_0 : integer range 0 to DEBOUNCE_LIMIT := 0;
    signal db_cnt_1 : integer range 0 to DEBOUNCE_LIMIT := 0;
    signal sw_stable_0 : std_logic := '0';
    signal sw_stable_1 : std_logic := '0';
    
    -- UART state machine
    type uart_state_t is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    signal uart_state : uart_state_t := IDLE;
    signal uart_data : std_logic_vector(7 downto 0) := (others => '0');
    signal uart_bit_idx : integer range 0 to 7 := 0;
    signal uart_clk_cnt : integer range 0 to CLKS_PER_BIT := 0;
    signal uart_busy : std_logic := '0';
    signal uart_start : std_logic := '0';
    
    -- Comandos ASCII
    constant CMD_UP    : std_logic_vector(7 downto 0) := x"55";  -- 'U'
    constant CMD_DOWN  : std_logic_vector(7 downto 0) := x"44";  -- 'D'
    constant CMD_LEFT  : std_logic_vector(7 downto 0) := x"4C";  -- 'L'
    constant CMD_RIGHT : std_logic_vector(7 downto 0) := x"52";  -- 'R'
    
    -- LED TX visible
    signal led_tx : std_logic := '0';
    constant LED_TIME : integer := 2500000;
    signal led_cnt : integer range 0 to LED_TIME := 0;
    
    -- Comando a enviar
    signal pending_cmd : std_logic_vector(7 downto 0) := (others => '0');
    signal has_cmd : std_logic := '0';
    
    -- Contador de comandos para enviar múltiples
    signal cmd_phase : integer range 0 to 2 := 0;
    
    -- Reset interno
    signal rst_internal : std_logic;
    
    -- Señales del SPI Master (del repositorio)
    signal go           : std_logic;
    signal pol          : std_logic;
    signal pha          : std_logic;
    signal bytes        : std_logic_vector(3 downto 0);
    signal rxData       : std_logic_vector(7 downto 0);
    signal rxDataReady  : std_logic := '0';
    signal txData       : std_logic_vector(7 downto 0);
    signal accel_data   : std_logic_vector(47 downto 0);
    
    signal sclk_out     : std_logic;
    signal sclk_buffer  : std_logic;
    signal mosi_buffer  : std_logic;
    signal cs_buffer    : std_logic;
    signal int1_buffer  : std_logic := '0';
    signal stateID      : std_logic_vector(2 downto 0);
    signal mode_sig     : std_logic;
    signal c_sig        : std_logic;
    
    -- Acelerómetro - valores procesados
    signal accel_y : signed(15 downto 0) := (others => '0');
    signal move_up : std_logic := '0';
    signal move_down : std_logic := '0';
    constant TILT_THRESHOLD : integer := 15;  -- ULTRA sensible
    
begin

    -- Reset: KEY[0] es active low, los drivers necesitan active high
    rst_internal <= not reset_n;
    
    -- LEDs
    ledr(0) <= sw_stable_0;
    ledr(1) <= sw_stable_1;
    ledr(2) <= move_up;
    ledr(3) <= move_down;
    ledr(4) <= led_tx;
    
    -- Extraer eje Y de los datos del acelerómetro
    -- Formato: XL(7:0), XH(15:8), YL(23:16), YH(31:24), ZL(39:32), ZH(47:40)
    accel_y <= signed(accel_data(31 downto 16));
    
    -- Detección de inclinación
    move_up   <= '1' when accel_y > TILT_THRESHOLD else '0';
    move_down <= '1' when accel_y < -TILT_THRESHOLD else '0';
    
    ----------------------------------------------------------------------------
    -- SPI Master (del repositorio bjohnsonfl/SPI_Accelerometer)
    ----------------------------------------------------------------------------
    U_SPI_MASTER : entity work.spi_master(FSM_1P)
        port map(
            clk         => clk,
            rst         => rst_internal,
            mosi        => mosi_buffer,
            miso        => GSENSOR_SDO,
            sclk_out    => sclk_out,
            cs_out      => cs_buffer,
            int1        => '0',
            int2        => '0',
            go          => go,
            pol         => pol,
            pha         => pha,
            bytes       => bytes,
            rxData      => rxData,
            txData      => txData,
            rxDataReady => rxDataReady
        );
    
    -- Conexiones SPI
    GSENSOR_SDI  <= mosi_buffer;
    GSENSOR_CS_N <= cs_buffer;
    GSENSOR_SCLK <= sclk_buffer;
    
    ----------------------------------------------------------------------------
    -- Accel Driver (del repositorio bjohnsonfl/SPI_Accelerometer)
    ----------------------------------------------------------------------------
    U_ACCEL_DRIVER : entity work.accel_driver(FSM_1P)
        port map(
            rst         => rst_internal,
            clk         => clk,
            int1        => int1_buffer,
            rxDataReady => rxDataReady,
            go          => go,
            pol         => pol,
            pha         => pha,
            bytes       => bytes,
            txData      => txData,
            rxData      => rxData,
            accel_data  => accel_data,
            stateID     => stateID,
            m           => mode_sig,
            c           => c_sig,
            intBypass   => '1'  -- Bypass del interrupt
        );

    -- Buffer del clock SPI
    process(clk, rst_internal)
    begin
        if rst_internal = '1' then
            sclk_buffer <= '1';
            int1_buffer <= '0';
        elsif rising_edge(clk) then
            sclk_buffer <= sclk_out;
        end if;
    end process;
    
    ----------------------------------------------------------------------------
    -- Debouncer para SW[0]
    ----------------------------------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            db_cnt_0 <= 0;
            sw_stable_0 <= '0';
        elsif rising_edge(clk) then
            if sw(0) = sw_stable_0 then
                db_cnt_0 <= 0;
            else
                if db_cnt_0 < DEBOUNCE_LIMIT then
                    db_cnt_0 <= db_cnt_0 + 1;
                else
                    sw_stable_0 <= sw(0);
                    db_cnt_0 <= 0;
                end if;
            end if;
        end if;
    end process;
    
    ----------------------------------------------------------------------------
    -- Debouncer para SW[1]
    ----------------------------------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            db_cnt_1 <= 0;
            sw_stable_1 <= '0';
        elsif rising_edge(clk) then
            if sw(1) = sw_stable_1 then
                db_cnt_1 <= 0;
            else
                if db_cnt_1 < DEBOUNCE_LIMIT then
                    db_cnt_1 <= db_cnt_1 + 1;
                else
                    sw_stable_1 <= sw(1);
                    db_cnt_1 <= 0;
                end if;
            end if;
        end if;
    end process;
    
    ----------------------------------------------------------------------------
    -- Timer y selección de comandos
    ----------------------------------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            send_timer <= 0;
            has_cmd <= '0';
            pending_cmd <= (others => '0');
            cmd_phase <= 0;
        elsif rising_edge(clk) then
            has_cmd <= '0';
            
            if send_timer < SEND_INTERVAL then
                send_timer <= send_timer + 1;
            else
                send_timer <= 0;
                
                if uart_busy = '0' then
                    case cmd_phase is
                        when 0 =>
                            -- Fase 0: Movimiento por acelerómetro
                            if move_up = '1' then
                                pending_cmd <= CMD_UP;
                                has_cmd <= '1';
                            elsif move_down = '1' then
                                pending_cmd <= CMD_DOWN;
                                has_cmd <= '1';
                            end if;
                            cmd_phase <= 1;
                            
                        when 1 =>
                            -- Fase 1: Disparo izquierdo
                            if sw_stable_0 = '1' then
                                pending_cmd <= CMD_LEFT;
                                has_cmd <= '1';
                            end if;
                            cmd_phase <= 2;
                            
                        when 2 =>
                            -- Fase 2: Disparo derecho
                            if sw_stable_1 = '1' then
                                pending_cmd <= CMD_RIGHT;
                                has_cmd <= '1';
                            end if;
                            cmd_phase <= 0;
                            
                        when others =>
                            cmd_phase <= 0;
                    end case;
                end if;
            end if;
        end if;
    end process;
    
    ----------------------------------------------------------------------------
    -- LED TX visible
    ----------------------------------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            led_cnt <= 0;
            led_tx <= '0';
        elsif rising_edge(clk) then
            if uart_start = '1' then
                led_tx <= '1';
                led_cnt <= 0;
            elsif led_cnt < LED_TIME then
                led_cnt <= led_cnt + 1;
            else
                led_tx <= '0';
            end if;
        end if;
    end process;
    
    ----------------------------------------------------------------------------
    -- UART TX State Machine
    ----------------------------------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            uart_state <= IDLE;
            uart_tx <= '1';
            uart_data <= (others => '0');
            uart_bit_idx <= 0;
            uart_clk_cnt <= 0;
            uart_busy <= '0';
            uart_start <= '0';
            
        elsif rising_edge(clk) then
            uart_start <= '0';
            
            case uart_state is
                when IDLE =>
                    uart_tx <= '1';
                    uart_busy <= '0';
                    
                    if has_cmd = '1' then
                        uart_data <= pending_cmd;
                        uart_state <= START_BIT;
                        uart_busy <= '1';
                        uart_start <= '1';
                    end if;
                
                when START_BIT =>
                    uart_tx <= '0';
                    if uart_clk_cnt < CLKS_PER_BIT - 1 then
                        uart_clk_cnt <= uart_clk_cnt + 1;
                    else
                        uart_clk_cnt <= 0;
                        uart_bit_idx <= 0;
                        uart_state <= DATA_BITS;
                    end if;
                
                when DATA_BITS =>
                    uart_tx <= uart_data(uart_bit_idx);
                    if uart_clk_cnt < CLKS_PER_BIT - 1 then
                        uart_clk_cnt <= uart_clk_cnt + 1;
                    else
                        uart_clk_cnt <= 0;
                        if uart_bit_idx < 7 then
                            uart_bit_idx <= uart_bit_idx + 1;
                        else
                            uart_state <= STOP_BIT;
                        end if;
                    end if;
                
                when STOP_BIT =>
                    uart_tx <= '1';
                    if uart_clk_cnt < CLKS_PER_BIT - 1 then
                        uart_clk_cnt <= uart_clk_cnt + 1;
                    else
                        uart_clk_cnt <= 0;
                        uart_state <= IDLE;
                    end if;
            end case;
        end if;
    end process;

end architecture rtl;
