library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity stream_codec is
    generic (
        N : integer := 16  -- Default address of the WM8731 audio codec
    );
    port (
        rst       : in  std_logic;               -- Active low reset
        clk       : in  std_logic;               -- Clock signal
        adcdat    : in  std_logic;               
        left_in   : in  std_logic_vector(N-1 downto 0); -- 
        right_in  : in  std_logic_vector(N-1 downto 0); --
        bclk      : out std_logic;
        adclrc    : out std_logic; 
        daclrc    : out std_logic; 
        dacdat    : out std_logic; 	
        mclk      : out std_logic;  
        left_out  : out  std_logic_vector(N-1 downto 0); -- 
        right_out : out  std_logic_vector(N-1 downto 0) --             
    );
end stream_codec;

architecture behavioral of stream_codec is
    signal left_right : std_logic; -- 0=left channel, 1=right channel
    signal left_right_1 : std_logic; -- 0=left channel, 1=right channel
    signal mclk_sig : std_logic;
    signal bclk_sig : std_logic;
    constant FS : integer := 44100; -- Sampling rate (old 44100)
    constant LRC_DIV : integer := (12000000 / (2 * FS));
    constant BCLK_DIV : integer := (LRC_DIV / (2 * N));
begin
    -- 12 MHz clock generation - clock input freq = 24 MHz
    process(rst, clk)
    begin
        if (rst = '0') then
            mclk_sig <= '0';
        elsif (clk'event and clk = '1') then
            mclk_sig <= not mclk_sig;
        end if;
    end process;
    
    mclk <= mclk_sig;

    -- Left/right (adclrc and daclrc) clock generation
    process(rst, mclk_sig)
        variable counter : integer range 0 to 8191;
    begin
        if (rst = '0') then
            left_right <= '0';
            counter := 0;
        elsif (mclk_sig'event and mclk_sig = '1') then -- Divides mclk_sig
            if (counter = LRC_DIV - 1) then
                left_right <= not left_right;
                counter := 0;
            else
                counter := counter + 1;
            end if;
        end if;
    end process;
    
    adclrc <= left_right;
    daclrc <= left_right;

    -- BCLK clock generation
    process(rst, mclk_sig)
        variable counter : integer range 0 to 255;
    begin
        if (rst = '0') then
            bclk_sig <= '0';
            counter := 0;
        elsif (mclk_sig'event and mclk_sig = '1') then -- Divides mclk_sig
            if (counter = BCLK_DIV - 1) then
                bclk_sig <= not bclk_sig;
                counter := 0;
            else
                counter := counter + 1;
            end if;
        end if;
    end process;
    
    bclk <= bclk_sig;

    -- Shift register to convert data from serial to parallel (ADC and DAC)
    process(rst, bclk_sig)
        variable adc_sreg : std_logic_vector(N-1 downto 0);
        variable dac_sreg : std_logic_vector(N-1 downto 0);
    begin
        if (rst = '0') then
            dacdat <= '0';
        elsif (bclk_sig'event and bclk_sig = '1') then
            if (left_right /= left_right_1) then -- Detect change in left_right
                if (left_right = '0') then
                    right_out <= adc_sreg; -- Retrieve right channel from shift reg
                    dac_sreg := right_in; -- Load right channel into shift reg
                else
                    left_out <= adc_sreg; -- Retrieve left channel from shift reg
                    dac_sreg := left_in; -- Load left channel into shift reg
                end if;
            else
                adc_sreg := adc_sreg(N-2 downto 0) & adcdat;
                dac_sreg := dac_sreg(N-2 downto 0) & '0';
            end if;
            
            left_right_1 <= left_right;
            dacdat <= dac_sreg(N-1);
        end if;
    end process;
end behavioral;
