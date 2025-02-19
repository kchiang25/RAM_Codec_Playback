library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity i2c_codec is
    generic (
        ic_addr : std_logic_vector(6 downto 0) := "0011010"  -- Default address of the WM8731 audio codec
    );
    port (
        rst       : in  std_logic;               -- Active low reset
        clk       : in  std_logic;               -- Clock signal
        start     : in  std_logic;               -- Start transmission pulse
        reg_addr  : in  std_logic_vector(6 downto 0); -- Register address to be updated
        reg_data  : in  std_logic_vector(8 downto 0); -- Register value to be updated
        i2c_sda   : inout std_logic;              -- SDA line of the I2C bus
        i2c_scl   : out std_logic;                -- SCL line of the I2C bus
        ack       : out std_logic;                -- Acknowledge signal
        idle      : out std_logic                 -- Idle signal
    );
end i2c_codec;

architecture behavioral of i2c_codec is
    type Tstate IS (s_idle, s_start, s_addr, s_ack1, s_byte1, s_ack2, s_byte2, s_ack3, s_stop1, s_stop2);
    constant BIT_CNT : integer := 8;            -- Number of bits to transmit (8 bits for address/data)
    constant TICK_CNT : integer := 1;          -- Tick count for timing

    -- declare other signals
    signal state      : Tstate := s_idle;
    signal aux_scl    : std_logic := '1';
    signal en_scl     : std_logic := '0';
    signal sreg       : std_logic_vector(7 downto 0); -- 8 bits for the data (register + data)
    signal ack_bit1    : std_logic;
    signal ack_bit2    : std_logic;
    signal ack_bit3    : std_logic;

begin
    process(clk, rst) -- generates SCL (en_scl = enable signal)
    begin
        if rst='0' then
            aux_scl <= '1';
        elsif(clk'event and clk='1') then
            if(en_scl='1') then
                aux_scl <= not aux_scl;
            else
                aux_scl <= '1';
            end if;
        end if;
    end process;
    i2c_scl <= aux_scl;
	
    process(clk, rst)
        variable tick_count : integer := 0;      -- Variable for tick count
        variable bit_count  : integer := 0;      -- Variable for bit count
    begin
        if rst='0' then
            state <= s_idle;
            i2c_sda <= '1';
            en_scl <= '0';
            ack <= '0';
            idle <= '1';
        elsif(clk'event and clk='0') then -- falling edge
            case state is
                when s_idle =>
                    idle <= '1';
                    if(start='1') then
                        state <= s_start;
                    else
                        state <= s_idle;
                    end if;

                when s_start =>
                    idle <= '0';
                    sreg <= ic_addr & '0'; -- load register address and R/W(write)
                    i2c_sda <= '0'; -- Start condition
                    bit_count := 0; -- Initialize bit count
                    tick_count := 0; -- Initialize tick count
                    en_scl <= '1';
                    state <= s_addr;

                when s_addr =>
                    i2c_sda <= sreg(7); -- update SDA output with shift register bit
                    if(tick_count = TICK_CNT) then
                        sreg <= sreg(6 downto 0) & '0'; -- shift left
                        if bit_count = BIT_CNT then
                            bit_count := 0;
                            state <= s_ack1;
                        else
                            bit_count := bit_count + 1; -- increment
                            state <= s_addr;
                        end if;
                        tick_count := 0;
                    else
                        tick_count := tick_count + 1; -- increment
                    end if;

                when s_ack1 =>
                    i2c_sda <= 'Z'; -- hi-Z
                    ack_bit1 <= i2c_sda; -- read ADC bit from SDA line
                    if(tick_count = TICK_CNT) then
								sreg <= reg_addr(6 downto 0) & reg_data(8); -- load 7 bits of addr. + MSB of data
                        bit_count := 0; -- reset bit count
                        state <= s_byte1; -- proceed to send data byte
                        tick_count := 0; -- reset tick count
                    else
                        tick_count := tick_count + 1; -- increment
                    end if;

                when s_byte1 =>
                    i2c_sda <= sreg(7); -- update SDA output with data bit
                    if(tick_count = TICK_CNT) then
                        sreg <= sreg(6 downto 0) & '0'; -- shift left
                        if bit_count = BIT_CNT then
                            bit_count := 0; -- reset bit count
                            state <= s_ack2;
                        else
                            bit_count := bit_count + 1; -- increment
                            state <= s_byte1;
                        end if;
									tick_count := 0; -- reset tick count
                    else
                        tick_count := tick_count + 1; -- increment
                    end if;

                when s_ack2 =>
                    i2c_sda <= 'Z'; -- hi-Z
                    ack_bit2 <= i2c_sda; -- read ACK bit
                    if(tick_count = TICK_CNT) then
						  sreg <= reg_data(7 downto 0); -- load 8 data bits
                        bit_count := 0; -- reset bit count
                        state <= s_byte2; -- proceed to send data byte
                        tick_count := 0; -- reset tick count
                    else
                        tick_count := tick_count + 1; -- increment
                    end if;
						  
					when s_byte2 =>
                    i2c_sda <= sreg(7); -- update SDA output with data bit
                    if(tick_count = TICK_CNT) then
                        sreg <= sreg(6 downto 0) & '0'; -- shift left
                        if bit_count = BIT_CNT then
                            bit_count := 0; -- reset bit count
                            state <= s_ack3;
                        else
                            bit_count := bit_count + 1; -- increment
                            state <= s_byte2;
                        end if;
                        tick_count := 0; -- reset tick count
                    else
                        tick_count := tick_count + 1; -- increment
                    end if;
						  
						  when s_ack3 =>
                    i2c_sda <= 'Z'; -- hi-Z
                    ack_bit3 <= i2c_sda; -- read ACK bit
                    if(tick_count = TICK_CNT) then
                        state <= s_stop1; -- proceed to stop condition
                        tick_count := 0; -- reset tick count
                    else
                        tick_count := tick_count + 1; -- increment
                    end if;


                when s_stop1 =>
                    i2c_sda <= '0'; -- Generate Stop condition
                    en_scl <= '0';
                    ack <= ack_bit1 or ack_bit2 or ack_bit3; -- set ack
                    state <= s_stop2;

                when s_stop2 =>
                    i2c_sda <= '1'; -- End of transmission
                    state <= s_idle;

            end case;
        end if;
    end process;

end behavioral;
