library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity mem_interface_tb is
--  Port ( );
end mem_interface_tb;

architecture Behavioral of mem_interface_tb is
    component mem_interface is
        generic (   C_BRAM_PORT_WIDTH : string := "18" );
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
    end component;
    
    component sim_clk_wrapper
        port (
                sim_clk_out : out std_logic;
                sim_rst_out : out std_logic
            );
    end component;
    
    signal sim_clk_sig : std_logic;
    signal sim_rst_sig : std_logic;
    
    signal sim_reset           : std_logic                     := '0';
        
    signal sim_split_addr_in   : std_logic_vector(7 downto 0)  := (others => '0');
    signal sim_split_data_in   : std_logic_vector(7 downto 0)  := (others => '0');
    signal sim_parity_in       : std_logic                     := '0';
    
    signal sim_addr_buf_en     : std_logic                     := '0';
    signal sim_data_buf_en     : std_logic                     := '0';
    
    signal sim_bram_addr_out   : std_logic_vector(15 downto 0) := (others => '0');
    signal sim_bram_data_out   : std_logic_vector(31 downto 0) := (others => '0');
    signal sim_bram_parity_out : std_logic_vector(3 downto 0)  := (others => '0');
    
    signal sim_bram_data_in    : std_logic_vector(31 downto 0) := (others => '0');
    signal sim_bram_parity_in  : std_logic_vector(3 downto 0)  := (others => '0');
    
    signal sim_bram_write : std_logic_vector(3 downto 0)  := (others => '0');
    signal dummy_vec1     : std_logic_vector(31 downto 0) := (others => '0');
    signal dummy_vec2     : std_logic_vector(3 downto 0)  := (others => '0');  
    
    signal result : std_logic_vector(17 downto 0);
    
begin
    sim_clk_gen : sim_clk_wrapper
        port map (
                    sim_clk_out => sim_clk_sig,
                    sim_rst_out => sim_rst_sig
                 );
                 
    UUT : mem_interface
        generic map (   C_BRAM_PORT_WIDTH => "18")
        port map (  clk            => sim_clk_sig,
                    reset          => sim_reset,
                    
                    split_addr_in   => sim_split_addr_in,
                    split_data_in   => sim_split_data_in,
                    parity_in       => sim_parity_in,
                    
                    addr_buf_en     => sim_addr_buf_en,
                    data_buf_en     => sim_data_buf_en,
                                        
                    bram_addr_out   => sim_bram_addr_out,
                    bram_data_out   => sim_bram_data_out,
                    bram_parity_out => sim_bram_parity_out,
                    
                    bram_data_in    => sim_bram_data_in,
                    bram_parity_in  => sim_bram_parity_in
                );
                
    main_bram: RAMB36E1
        generic map (   READ_WIDTH_A      => 18,
                        WRITE_WIDTH_A     => 18,
                        DOA_REG           => 0,
                        INIT_A            => X"000000000",
                        RSTREG_PRIORITY_A => "REGCE",
                        SRVAL_A           => X"000000000",
                        WRITE_MODE_A      => "WRITE_FIRST",
                    
                        READ_WIDTH_B      => 18,
                        WRITE_WIDTH_B     => 18,
                        DOB_REG           => 0,
                        INIT_B            => X"000000000",
                        RSTREG_PRIORITY_B => "REGCE",
                        SRVAL_B           => X"000000000",
                        WRITE_MODE_B      => "WRITE_FIRST",
                    
                        INIT_FILE                 => "NONE",
                        SIM_COLLISION_CHECK       => "ALL",
                        RAM_MODE                  => "TDP",
                        RDADDR_COLLISION_HWCONFIG => "DELAYED_WRITE",
                        EN_ECC_READ               => FALSE,
                        EN_ECC_WRITE              => FALSE,
                        RAM_EXTENSION_A           => "NONE",
                        RAM_EXTENSION_B           => "NONE",
                        SIM_DEVICE                => "7SERIES"
                    )
                    
        port map (
                        ADDRARDADDR   => sim_bram_addr_out,
                        ENARDEN       => '1',
                        CLKARDCLK     => sim_clk_sig,
                        DOADO         => sim_bram_data_in,
                        DOPADOP       => sim_bram_parity_in,
                        DIADI         => sim_bram_data_out,
                        DIPADIP       => sim_bram_parity_out,
                        WEA           => sim_bram_write,
                        REGCEAREGCE   => '0',
                        RSTRAMARSTRAM => '0',
                        RSTREGARSTREG => '0',
                        
                        ADDRBWRADDR => sim_bram_addr_out,
                        ENBWREN     => '0',
                        CLKBWRCLK   => sim_clk_sig,
                        DOBDO       => dummy_vec1,
                        DOPBDOP     => dummy_vec2,
                        DIBDI       => (others => '0'),
                        DIPBDIP     => (others => '0'),
                        WEBWE       => "00000000",
                        REGCEB      => '0',
                        RSTRAMB     => '0',
                        RSTREGB     => '0',
                        
                        CASCADEINA    => '0',
                        CASCADEINB    => '0',
                        INJECTDBITERR => '0',
                        INJECTSBITERR => '0'
                       );                 
    
    simulate: process
    begin
        sim_reset <= '1';
        
        wait until rising_edge(sim_clk_sig);
        -- first write to the buffers

        sim_reset <= '0';
        sim_addr_buf_en <= '1';
        sim_data_buf_en <= '1';
        
        sim_split_addr_in <= "00001000";
        sim_split_data_in <= "10101010";
        sim_parity_in <= '0';
        
        wait until rising_edge(sim_clk_sig);

        sim_split_addr_in <= "00010000";
        sim_split_data_in <= "01010101";
        sim_parity_in <= '1';
        
        wait until rising_edge(sim_clk_sig);
        -- write to the memory, should happen automatically
        
        sim_bram_write  <= "1111";
        sim_addr_buf_en <= '0';
        sim_data_buf_en <= '0';
                
        wait until rising_edge(sim_clk_sig);    

        -- clear buffers
        sim_reset      <= '1';
        sim_bram_write <= "0000";
        
        wait until rising_edge(sim_clk_sig);
        -- then try reading from that memory address
        sim_reset       <= '0';
        sim_addr_buf_en <= '1';
        
        sim_split_addr_in <= "00001000";   
        
        wait until rising_edge(sim_clk_sig);
        
        sim_split_addr_in <= "00010000";
        
        wait until rising_edge(sim_clk_sig);
        
        sim_addr_buf_en <= '0';
        
        wait until rising_edge(sim_clk_sig); 
        wait until rising_edge(sim_clk_sig);   
        
        result(17)          <= sim_bram_parity_out(1);
        result(16)          <= sim_bram_parity_out(0);
        result(15 downto 8) <= sim_bram_data_out(15 downto 8);
        result(7 downto 0)  <= sim_bram_data_out(7 downto 0);
        
        wait until rising_edge(sim_clk_sig);
        wait until rising_edge(sim_clk_sig);
        wait until rising_edge(sim_clk_sig);
    end process simulate;
end Behavioral;
