ENTITY clock_div IS 		
  GENERIC(N : natural := 10); 
  PORT (rst, clk_in : in bit;
        clk_out : out bit); 
END clock_div;

ARCHITECTURE behavioral OF clock_div IS 
 SIGNAL clk_div_sig : BIT;
BEGIN 	
  PROCESS(clk_in, rst)
    VARIABLE count : INTEGER RANGE 0 to N;
  BEGIN
    IF(rst = '0') THEN
      count   := 0;
      clk_div_sig <= '0';
    ELSIF(clk_in'EVENT AND clk_in='1') THEN
           IF(count=N-1) THEN
              count := 0;
              clk_div_sig <= NOT clk_div_sig;
           ELSE
              count := count + 1;
           END IF;
    END IF;
  END PROCESS;
  clk_out <= clk_div_sig;
END behavioral; 

-- expected frequency = 50MHz / 2N = 19201.2289