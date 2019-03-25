library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity main is
    port( 
            clk         : in std_logic;
            int_btn     : in std_logic_vector(3 downto 0);
            leds        : out std_logic_vector(3 downto 0);
            uart_rx_pin : in std_logic;
            uart_tx_pin : out std_logic
         );
end main;

architecture Behavioral of main is 
    component kcpsm6 
        generic (                 
                    hwbuild                 : std_logic_vector(7 downto 0) := X"00";
                    interrupt_vector        : std_logic_vector(11 downto 0) := X"3FF";
                    scratch_pad_memory_size : integer := 64
                );
        port (                   
                    address        : out std_logic_vector(11 downto 0);
                    instruction    : in std_logic_vector(17 downto 0);
                    bram_enable    : out std_logic;
                    in_port        : in std_logic_vector(7 downto 0);
                    out_port       : out std_logic_vector(7 downto 0);
                    port_id        : out std_logic_vector(7 downto 0);
                    write_strobe   : out std_logic;
                    k_write_strobe : out std_logic;
                    read_strobe    : out std_logic;
                    interrupt      : in std_logic;
                    interrupt_ack  : out std_logic;
                    sleep          : in std_logic;
                    reset          : in std_logic;
                    clk            : in std_logic
                );
                              
    
    end component;
    
    component led_prog1                            
        generic(    C_FAMILY          : string  := "S6"; 
                    C_RAM_SIZE_KWORDS : integer := 1);
                  
        port (      address     : in std_logic_vector(11 downto 0);
                    instruction : out std_logic_vector(17 downto 0);
                    enable      : in std_logic;
                    clk         : in std_logic;
                      
                    address_b    : in std_logic_vector(15 downto 0);
                    data_in_b    : in std_logic_vector(31 downto 0);
                    parity_in_b  : in std_logic_vector(3 downto 0);
                    data_out_b   : out std_logic_vector(31 downto 0);
                    parity_out_b : out std_logic_vector(3 downto 0);
                    enable_b     : in std_logic;
                    we_b         : in std_logic_vector(3 downto 0));
    end component;
    
    component uart_tx6
        port (
                data_in             : in std_logic_vector(7 downto 0);
                en_16_x_baud        : in std_logic;
                serial_out          : out std_logic;
                buffer_write        : in std_logic;
                buffer_data_present : out std_logic;
                buffer_half_full    : out std_logic;
                buffer_full         : out std_logic;
                buffer_reset        : in std_logic;
                clk                 : in std_logic);
    end component;
    
    component uart_rx6
    port (
            serial_in           : in std_logic;
            en_16_x_baud        : in std_logic;
            data_out            : out std_logic_vector(7 downto 0);
            buffer_read         : in std_logic;
            buffer_data_present : out std_logic;
            buffer_half_full    : out std_logic;
            buffer_full         : out std_logic;
            buffer_reset        : in std_logic;
            clk                 : in std_logic);
    end component;
    
    component mem_interface
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
    end component;

    -- stuff for the processor
    signal address        : std_logic_vector(11 downto 0) := (others => '0');
    signal instruction    : std_logic_vector(17 downto 0) := (others => '0');
    signal bram_enable    : std_logic                     := '0';
    signal in_port        : std_logic_vector(7 downto 0)  := (others => '0');
    signal out_port       : std_logic_vector(7 downto 0)  := (others => '0');
    signal port_id        : std_logic_vector(7 downto 0)  := (others => '0');
    signal write_strobe   : std_logic                     := '0';
    signal k_write_strobe : std_logic                     := '0';
    signal read_strobe    : std_logic                     := '0';
    signal interrupt      : std_logic                     := '0';
    signal interrupt_ack  : std_logic                     := '0';
    signal kcpsm6_sleep   : std_logic                     := '0';
    signal kcpsm6_reset   : std_logic                     := '0';
    
    -- stuff for the UART
    signal baud_count        : integer range 0 to 53        := 0;
    signal uart_baud         : std_logic                    := '0';
    
    -- | uart_tx6                                             | uart_rx6
    -- [buffer_data_present] [buffer_half_full] [buffer_full] [buffer_data_present] [buffer_half_full] [buffer_full]
    signal uart_status       : std_logic_vector(5 downto 0) := (others => '0');
    signal uart_data_in      : std_logic_vector(7 downto 0) := (others => '0');
    signal uart_data_out     : std_logic_vector(7 downto 0) := (others => '0');
    signal uart_buffer_write : std_logic                    := '0';
    signal uart_buffer_read  : std_logic                    := '0';
    signal uart_reset        : std_logic                    := '0';
    
    -- stuff for the memory, bram first
    signal ext_bram_we              : std_logic_vector(3 downto 0)  := (others => '0');
    
    -- then the memory interface
    signal mem_intf_split_addr_in   : std_logic_vector(7 downto 0)  := (others => '0');
    signal mem_intf_split_data_in   : std_logic_vector(7 downto 0)  := (others => '0');
    signal mem_intf_parity_in       : std_logic                     := '0';
    
    signal mem_intf_addr_buf_en     : std_logic                     := '0';
    signal mem_intf_data_buf_en     : std_logic                     := '0';
    signal mem_intf_reset           : std_logic                     := '0';
    
    signal mem_intf_addr_idx        : std_logic_vector(0 downto 0)  := (others => '0');
    signal mem_intf_data_idx        : std_logic_vector(1 downto 0)  := (others => '0');
    
    signal mem_intf_bram_addr_out   : std_logic_vector(15 downto 0) := (others => '0');
    signal mem_intf_bram_data_out   : std_logic_vector(31 downto 0) := (others => '0');
    signal mem_intf_bram_parity_out : std_logic_vector(3 downto 0)  := (others => '0');
    
    signal mem_intf_bram_data_in    : std_logic_vector(31 downto 0) := (others => '0');
    signal mem_intf_bram_parity_in  : std_logic_vector(3 downto 0)  := (others => '0');
        
    -- for the state machines
    signal addr_writes   : integer range 0 to 2;
    signal data_writes   : integer range 0 to 2;
    signal data_reads    : integer range 0 to 3;
    signal interrupt_cnt : integer range 0 to 3;
    signal parity_buf    : std_logic_vector(1 downto 0);
    
    -- for leds
    signal leds_buf : std_logic_vector(3 downto 0);
    
begin
    kcpsm6_sleep <= '0';
    leds         <= leds_buf;
    
    processor: kcpsm6
        generic map (                 
                        hwbuild                 => X"00", 
                        interrupt_vector        => X"7BF",
                        scratch_pad_memory_size => 64
                    )
        port map (      address        => address,
                        instruction    => instruction,
                        bram_enable    => bram_enable,
                        port_id        => port_id,
                        write_strobe   => write_strobe,
                        k_write_strobe => k_write_strobe,
                        out_port       => out_port,
                        read_strobe    => read_strobe,
                        in_port        => in_port,
                        interrupt      => interrupt,
                        interrupt_ack  => interrupt_ack,
                        sleep          => kcpsm6_sleep,
                        reset          => kcpsm6_reset,
                        clk            => clk);
                     
    program_rom: led_prog1                   --Name to match your PSM file
        generic map (             
                        C_FAMILY             => "7S",   --Family 'S6', 'V6' or '7S'
                        C_RAM_SIZE_KWORDS    => 2)      --Program size '1', '2' or '4'
        port map (      
                        address     => address,      
                        instruction => instruction,
                        enable      => bram_enable,
                        clk         => clk,
                        
                        address_b    => mem_intf_bram_addr_out,
                        data_in_b    => mem_intf_bram_data_out,
                        parity_in_b  => mem_intf_bram_parity_out,
                        data_out_b   => mem_intf_bram_data_in,
                        parity_out_b => mem_intf_bram_parity_in,
                        enable_b     => '1',
                        we_b         => ext_bram_we);
                        
    uart_tx: uart_tx6
        port map (
                    data_in             => uart_data_in,
                    en_16_x_baud        => uart_baud,
                    serial_out          => uart_tx_pin,
                    buffer_write        => uart_buffer_write,
                    buffer_data_present => uart_status(5),
                    buffer_half_full    => uart_status(4),
                    buffer_full         => uart_status(3),
                    buffer_reset        => uart_reset,
                    clk                 => clk);
                    
    uart_rx: uart_rx6
        port map ( 
                    serial_in           => uart_rx_pin,
                    en_16_x_baud        => uart_baud,
                    data_out            => uart_data_out,
                    buffer_read         => uart_buffer_read,
                    buffer_data_present => uart_status(2),
                    buffer_half_full    => uart_status(1),
                    buffer_full         => uart_status(0),
                    buffer_reset        => uart_reset,
                    clk                 => clk);
                   
    bram_interface: mem_interface
        generic map (   C_BRAM_PORT_WIDTH => "18")
        port map (  clk            => clk,
                    reset          => mem_intf_reset,
                    
                    split_addr_in   => mem_intf_split_addr_in,
                    split_data_in   => mem_intf_split_data_in,
                    parity_in       => mem_intf_parity_in,
                    
                    addr_buf_en     => mem_intf_addr_buf_en,
                    data_buf_en     => mem_intf_data_buf_en,
                                        
                    bram_addr_out   => mem_intf_bram_addr_out,
                    bram_data_out   => mem_intf_bram_data_out,
                    bram_parity_out => mem_intf_bram_parity_out,
                    
                    bram_data_in    => mem_intf_bram_data_in,
                    bram_parity_in  => mem_intf_bram_parity_in
                );
                
    handle_interrupt: process(clk)
    begin
        if rising_edge(clk) then
            case interrupt_cnt is
                when 0 =>
                    kcpsm6_reset <= '0';
                    
                    if int_btn(0) = '1' or int_btn(1) = '1' or int_btn(2) = '1' or int_btn(3) = '1' then
                        interrupt     <= '1';
                        interrupt_cnt <= 1;
                    end if;
                    
                when 1 =>
                    if interrupt_ack = '1' then
                        interrupt     <= '0';
                        interrupt_cnt <= 2;
                    end if;
                    
                when 2 =>                    
                    if leds_buf = "1111" then
                        interrupt_cnt <= 3;
                    end if;
                    
                when 3 =>
                    if leds_buf = "0000" then
                        kcpsm6_reset  <= '1';
                        interrupt_cnt <= 0;
                    end if;
            end case;
        end if;
    end process handle_interrupt;
                
    baud_rate: process(clk)
    begin
        if rising_edge(clk) then
            if baud_count = 53 then
                baud_count <= 0;
                uart_baud <= '1';
            else
                baud_count <= baud_count + 1;
                uart_baud <= '0';
            end if;
        end if;
    end process baud_rate;
    
    handle_mem_states : process(clk)
    begin
        if rising_edge(clk) then
            if ext_bram_we = "1111" or 
                (addr_writes = 2 and data_reads = 3) then
                mem_intf_reset <= '1';
            else
                mem_intf_reset <= '0';
            end if;
        end if;
    end process handle_mem_states;

    -- Port mapping
    -- 0000 0001 - UART data out
    -- 0000 0010 - Memory interface split address out
    -- 0000 0011 - Memory interface split data out, parity 0
    -- 0000 1011 - Memory interface split data out, parity 1
    -- 0000 0100 - Leds out
    output_ports : process(clk)
    begin
        if rising_edge(clk) then
            uart_buffer_write    <= '0';
            ext_bram_we          <= "0000";
            mem_intf_addr_buf_en <= '0';
            mem_intf_data_buf_en <= '0';
            
            if write_strobe = '1' or k_write_strobe = '1' then
                case port_id(2 downto 0) is                                 
                    when "001" => 
                        uart_buffer_write <= '1';
                        uart_data_in      <= out_port;
                                                           
                    when "010" => 
                        addr_writes            <= addr_writes + 1;
                        mem_intf_addr_buf_en   <= '1';
                        mem_intf_split_addr_in <= out_port;
                                            
                    when "011" => 
                        data_writes            <= data_writes + 1;
                        mem_intf_data_buf_en   <= '1';
                        mem_intf_split_data_in <= out_port;
                        mem_intf_parity_in     <= port_id(3);
                        
                    when "100" =>
                        leds_buf <= out_port(3 downto 0);
                    
                    when others => null;
                end case;
            end if;    
            
            if addr_writes = 2 then
                if data_writes = 2 then
                    -- write and reset
                    ext_bram_we <= "1111";
                    addr_writes <= 0;
                    data_writes <= 0;
                elsif data_reads = 3 then
                    -- read and reset
                    addr_writes   <= 0;
                end if;
            end if;
        end if;
    end process output_ports;
    
    -- Port mapping
    -- 0000 0001 - UART data in
    -- 0000 0010 - UART status in
    -- 0000 0011 - Memory interface split data in
    input_ports : process(clk)
    begin
        if rising_edge(clk) then  
            uart_buffer_read <= '0';
                      
            case port_id(1 downto 0) is
                when "01" => 
                    uart_buffer_read <= read_strobe;
                    in_port          <= uart_data_out;
                             
                when "10" => 
                    in_port(7 downto 6) <= (others => '0');
                    in_port(5 downto 0) <= uart_status;
                            
                when "11" => 
                    if data_reads = 0 then
                        in_port       <= mem_intf_bram_data_out(7 downto 0);
                        parity_buf(0) <= mem_intf_bram_parity_out(0);
                        
                    elsif data_reads = 1 then
                        in_port       <= mem_intf_bram_data_out(15 downto 8);
                        parity_buf(1) <= mem_intf_bram_parity_out(1);
                        
                    elsif data_reads = 2 then
                        in_port <= "000000" & parity_buf;
                    
                    elsif data_reads = 3 then
                        data_reads <= 0;
                    end if;
                    
                    if read_strobe = '1' then
                        data_reads <= data_reads + 1;
                    end if;
                
                when others => 
                    in_port <= (others => '0');
            end case;
        end if;
    end process input_ports;
end Behavioral;
