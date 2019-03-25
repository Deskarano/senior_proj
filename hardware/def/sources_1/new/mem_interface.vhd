library ieee;
use ieee.std_logic_1164.all;

entity mem_interface is
    generic (   C_BRAM_PORT_WIDTH : string := "1" );
    port (
            -- data inputs
            clk            : in std_logic;
            reset          : in std_logic;
            
            split_addr_in  : in std_logic_vector(7 downto 0);
            split_data_in  : in std_logic_vector(7 downto 0);
            parity_in      : in std_logic;
            
            -- signals
            addr_buf_en    : in std_logic;
            data_buf_en    : in std_logic;
            
            -- to bram
            bram_addr_out   : out std_logic_vector(15 downto 0);
            bram_data_out   : out std_logic_vector(31 downto 0);
            bram_parity_out : out std_logic_vector(3 downto 0);
            
            bram_data_in    : in std_logic_vector(31 downto 0);
            bram_parity_in  : in std_logic_vector(3 downto 0)
            );
end mem_interface;

architecture Behavioral of mem_interface is

    signal addr_buf   : std_logic_vector(15 downto 0) := (others => '0');
    signal data_buf   : std_logic_vector(31 downto 0) := (others => '0');
    signal parity_buf : std_logic_vector(3 downto 0)  := (others => '0');
    
    signal addr_full  : std_logic                     := '0';
    signal addr_idx   : std_logic_vector(0 downto 0)  := (others => '0');
    signal data_idx   : std_logic_vector(1 downto 0)  := (others => '0');
                
begin    
    width_1_bram_output :  if C_BRAM_PORT_WIDTH = "1" generate
        bram_addr_out   <= '1' & addr_buf(14 downto 0);
        bram_data_out   <= "0000000000000000000000000000000" & data_buf(0);
        bram_parity_out <= (others => '0');
    end generate width_1_bram_output;
    
    width_2_bram_output : if C_BRAM_PORT_WIDTH = "2" generate
        bram_addr_out <= '1' & addr_buf(13 downto 0) & '1';
        bram_data_out <= "000000000000000000000000000000" & data_buf(1 downto 0);
        bram_parity_out <= (others => '0');
    end generate width_2_bram_output;
    
    width_4_bram_output : if C_BRAM_PORT_WIDTH = "4" generate
        bram_addr_out <= '1' & addr_buf(12 downto 0) & "11";
        bram_data_out <= "0000000000000000000000000000" & data_buf(3 downto 0);
        bram_parity_out <= (others => '0');
    end generate width_4_bram_output;
        
    width_9_bram_output : if C_BRAM_PORT_WIDTH = "9" generate
        bram_addr_out <= '1' & addr_buf(11 downto 0) & "111";
        bram_data_out <= "000000000000000000000000" & data_buf(7 downto 0);
        bram_parity_out <= "000" & parity_buf(0);
    end generate width_9_bram_output;

    width_18_bram_output : if C_BRAM_PORT_WIDTH = "18" generate
        bram_addr_out <= '1' & addr_buf(10 downto 0) & "1111";
        bram_data_out <= "0000000000000000" & data_buf(15 downto 0);
        bram_parity_out <= "00" & parity_buf(1 downto 0);
    end generate width_18_bram_output;
    
    width_36_bram_output : if C_BRAM_PORT_WIDTH = "36" generate
        bram_addr_out <= '1' & addr_buf(9 downto 0) & "11111";
        bram_data_out <= data_buf(31 downto 0);
        bram_parity_out <= parity_buf(3 downto 0);
    end generate width_36_bram_output;
    
    handle_addr_buf : process(clk, reset)
    begin
        if reset = '1' then
            addr_full <= '0';
            addr_idx  <= "0";
            addr_buf  <= (others => '0');
        end if;
     
        if rising_edge(clk) then
            if addr_full = '1' and data_idx = "00" then
                addr_full <= '0';
                addr_idx  <= "0";
                addr_buf  <= (others => '0');
            elsif addr_buf_en = '1' then
                case addr_idx is
                    when "0" => 
                        addr_idx             <= "1";
                        addr_buf(7 downto 0) <= split_addr_in;
                 
                    when "1" => 
                        addr_full             <= '1';
                        addr_buf(15 downto 8) <= split_addr_in;   
                 
                    when others => null;     
                end case;
            end if;
        end if;
    end process handle_addr_buf;
    
    handle_data_buf : process(clk, reset)
    begin
        if reset = '1' then
            data_idx   <= "00";
            data_buf   <= (others => '0');
            parity_buf <= (others => '0');
        end if;
     
        if rising_edge(clk) then
            if addr_full = '1' and data_idx = "00" then
                data_buf   <= bram_data_in;
                parity_buf <= bram_parity_in; 
            elsif data_buf_en = '1' then
                case data_idx is
                    when "00" => 
                        data_idx               <= "01";
                        data_buf(7 downto 0)   <= split_data_in;
                        parity_buf(0)          <= parity_in;
                              
                    when "01" => 
                        data_idx               <= "10";
                        data_buf(15 downto 8)  <= split_data_in;
                        parity_buf(1)          <= parity_in;
                              
                    when "10" => 
                        data_idx               <= "11";
                        data_buf(23 downto 16) <= split_data_in;
                        parity_buf(2)          <= parity_in;
                              
                    when "11" => 
                        data_buf(31 downto 24) <= split_data_in;
                        parity_buf(3)          <= parity_in;
                              
                    when others => null;
                end case;
            end if;           
        end if;
    end process handle_data_buf;
    
end Behavioral;