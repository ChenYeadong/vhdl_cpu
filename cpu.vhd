----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    13:44:51 08/09/2012 
-- Design Name: 
-- Module Name:    cpu - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity cpu is
  Generic(AddrWidth: integer := 32;
          DataWidth: integer := 32;
          StackSize: integer := 16;
          StackWidth: integer := 4;
          CodeSize: integer := 2048;
          CodeMemoryWidth: integer := 11;
          DataSize: integer := 512;
          DataMemoryWidth: integer := 9);
    Port ( clk : in  STD_LOGIC;
           rx: in std_logic;
           tx: out std_logic;
           addr : out  STD_LOGIC_VECTOR (AddrWidth-1 downto 0);
           dout : out  STD_LOGIC_VECTOR (DataWidth-1 downto 0);
           iowr : out  STD_LOGIC;
           din : in  STD_LOGIC_VECTOR (DataWidth-1 downto 0);
           reset : in  STD_LOGIC);
end cpu;

architecture Behavioral of cpu is

constant CodeWidth: integer := 9;

-- group 0; pop 0; push 0
constant cmdNOP: integer := 0;
constant cmdRET: integer := 1;

-- group 1; pop 0; push 1;
constant cmdTEMP: integer := 16;
constant cmdDEPTH: integer := 17;
constant cmdRDEPTH: integer := 18;
constant cmdDUP: integer := 19;
constant cmdOVER: integer := 20;

-- group 2; pop 1; push 0;
constant cmdJMP: integer := 32;
constant cmdCALL: integer := 33;
constant cmdDROP: integer := 34;

-- group 3; pop 1; push 1;
constant cmdFETCH: integer := 48;
constant cmdINPORT: integer := 49;
constant cmdNOT: integer := 50;
constant cmdSHL: integer := 51;
constant cmdSHR: integer := 52;
constant cmdSHRA: integer := 53;

-- group 4; pop 2; push 0;
constant cmdIF: integer := 64;
constant cmdSTORE: integer := 65;
constant cmdOUTPORT: integer := 66;

-- group 5; pop 2; push 1;
constant cmdNIP: integer := 80;
constant cmdPLUS: integer := 81;
constant cmdMINUS: integer := 82;
constant cmdAND: integer := 83;
constant cmdOR: integer := 84;
constant cmdXOR: integer := 85;
constant cmdEQUAL: integer := 86;
constant cmdGREATER: integer := 87;
constant cmdLESS: integer := 88;
constant cmdMUL: integer := 89;
constant cmdMULH: integer := 90;

subtype DataSignal is std_logic_vector(DataWidth-1 downto 0);
subtype AddrSignal is std_logic_vector(AddrWidth-1 downto 0);
subtype CodeSignal is std_logic_vector(CodeWidth-1 downto 0);
subtype StackAddrSignal is std_logic_vector(StackWidth-1 downto 0);
subtype CodeAddrSignal is std_logic_vector(CodeMemoryWidth-1 downto 0);
subtype DataAddrSignal is std_logic_vector(DataMemoryWidth-1 downto 0);

type TDataStack is array(0 to StackSize-1) of DataSignal;
signal DataStack: TDataStack;
signal DSAddrA, DSAddrB: StackAddrSignal;
signal DSDoutA, DSDoutB: DataSignal;
signal DSDinA: DataSignal;
signal DSWeA: std_logic;

type TRetStack is array(0 to StackSize-1) of AddrSignal;
signal RetStack: TRetStack;
signal RSAddrA, RSAddrB: StackAddrSignal;
signal RSDoutA, RSDoutB: AddrSignal;
signal RSDinA: AddrSignal;
signal RSWeA: std_logic;

type TCodeMemory is array(0 to CodeSize-1) of CodeSignal;
signal CodeMemory: TCodeMemory := (
  0  => "000000000", -- lit tests
  1  => "100000000",
  2  => "100000001",
  3  => "100000010",
  4  => "000000000",
  5  => "100001111",
  6  => "000000000",
  7  => "100010000",
  8  => "100001000",
  9  => conv_std_logic_vector(cmdPLUS, CodeWidth),
  10 => conv_std_logic_vector(cmdPLUS, CodeWidth),
  11 => conv_std_logic_vector(cmdDROP, CodeWidth),
  12 => "100010011",
  13 => conv_std_logic_vector(cmdJMP, CodeWidth), -- jmp to 19
  14 => "100000010",
  15 => "000000000",
  16 => "100000010",
  17 => conv_std_logic_vector(cmdPLUS, CodeWidth),
  18 => conv_std_logic_vector(cmdRET, CodeWidth), -- ret
  19 => "100001110",
  20 => conv_std_logic_vector(cmdCALL, CodeWidth), -- call to 14
  21 => "111111111",
  others => (others => '0')
);
signal CodeAddrA, CodeAddrB: CodeAddrSignal;
signal CodeDoutA, CodeDoutB: CodeSignal;
signal CodeDinA: CodeSignal;
signal CodeWeA: std_logic;

type TDataMemory is array(0 to DataSize-1) of DataSignal;
signal DataMemory: TDataMemory;
signal DataAddrA, DataAddrB: DataAddrSignal;
signal DataDoutA, DataDoutB: DataSignal;
signal DataDinA: DataSignal;
signal DataWeA: std_logic;

signal IP: AddrSignal;
signal Cmd: CodeSignal;
signal fetching: std_logic;

signal PrevCmdIsLIT: std_logic;

signal CmdIsLit: std_logic;
signal TempReg: DataSignal;

signal int_reset: std_logic;

signal MulResult: std_logic_vector(DataWidth * 2 - 1 downto 0);

signal receivedByte: std_logic_vector(7 downto 0);
signal transmitByte: std_logic_vector(7 downto 0);
signal received: std_logic;
signal transmit: std_logic;

begin

process(clk)
begin
  if rising_edge(clk) then
    if DSWeA = '1' then
      DataStack(conv_integer(DSAddrA)) <= DSDinA;
      DSDoutA <= DSDinA;
    else
      DSDoutA <= DataStack(conv_integer(DSAddrA));
    end if;
    DSDoutB <= DataStack(conv_integer(DSAddrB));
  end if;
end process;

process(clk)
begin
  if rising_edge(clk) then
    if RSWeA = '1' then
      RetStack(conv_integer(RSAddrA)) <= RSDinA;
      RSDoutA <= RSDinA;
    else
      RSDoutA <= RetStack(conv_integer(RSAddrA));
    end if;    
    RSDoutB <= RetStack(conv_integer(RSAddrB));
  end if;
end process;

process(clk)
begin
  if rising_edge(clk) then
    if CodeWeA = '1' then
      CodeMemory(conv_integer(CodeAddrA)) <= CodeDinA;
    end if;
    CodeDoutA <= CodeMemory(conv_integer(CodeAddrA));
    CodeDoutB <= CodeMemory(conv_integer(CodeAddrB));
  end if;
end process;

process(clk)
begin
  if rising_edge(clk) then
    if DataWeA = '1' then
      DataMemory(conv_integer(DataAddrA)) <= DataDinA;     
    end if;
    DataDoutA <= DataMemory(conv_integer(DataAddrA));   
    DataDoutB <= DataMemory(conv_integer(DataAddrB));
  end if;
end process;

-- end of stack and memory declaration

-- loader
uart_unit: entity uart
  Generic map(
    ClkFreq => 50_000_000,
    Baudrate => 115200)
  port map(
    clk => clk,
    rxd => rx,
    txd => tx,
    dout => receivedByte,
    received => received,
    din => transmitByte,
    transmit => transmit);
    
process(clk)
begin
  if rising_edge(clk) then
    if received = '1' then
      case conv_integer(receivedByte) is
        when 0 to 15 => CodeDinA(3 downto 0) <= receivedByte(3 downto 0);
        when 16 to 31 => CodeDinA(7 downto 4) <= receivedByte(3 downto 0);
        when 32 to 47 => CodeDinA(8) <= receivedByte(0);
        when 240 => CodeAddrA <= (others => '0');
        when 241 => CodeWeA <= '1';
        when 242 => CodeWeA <= '0'; CodeAddrA <= CodeAddrA + 1;
        when 243 => int_reset <= '1';
        when 244 => int_reset <= '0';
        when others => null;
      end case;
    end if;
  end if;
end process;

-- end of loader

CodeAddrB <= ip(CodeAddrB'range);
cmd <= CodeDoutB;

CmdIsLit <= '1' when Cmd(8) = '1' else '0';

MulResult <= DSDoutA * DSDoutB;

DSAddrB <= DSAddrA - 1;

process(clk)
begin
  if rising_edge(clk) then
    -- ���������� �����, ����� �� ������ "������".
    if reset = '1' or int_reset = '1' then
      DSAddrA <= (others => '0');      
      
      RSAddrA <= (others => '0');
      RSAddrB <= (others => '0');
      RSWeA <= '0';
      
      DataAddrA <= (others => '0');
      DataAddrB <= (others => '0');
      DataWeA <= '0';
      
      ip <= (others => '0');
      fetching <= '1';
    else      
      if fetching = '1' then
        fetching <= '0';
        DSWeA <= '0';
        RSWeA <= '0';
        DataWeA <= '0';
        iowr <= '0';
      else
        fetching <= '1';
        PrevCmdIsLIT <= Cmd(CodeWidth-1);
        
        -- Data stack addr and we
        case conv_integer(cmd(8 downto 4)) is
          when 16 to 31 => -- LIT
            if PrevCmdIsLIT = '0' then
              DSAddrA <= DSAddrA + 1;
            end if;
            DSWeA <= '1';          
          when 0 => -- group 0; pop 0; push 0
            null;
          when 1 => -- group 1; pop 0; push 1;
            DSAddrA <= DSAddrA + 1;
            DSWeA <= '1';          
          when 2 => -- group 2; pop 1; push 0;
            DSAddrA <= DSAddrA - 1;                        
          when 3 => -- group 3; pop 1; push 1;
            DSWeA <= '1';          
          when 4 => -- group 4; pop 2; push 0;
            DSAddrA <= DSAddrA - 2;          
          when 5 => -- group 5; pop 2; push 1;
            DSAddrA <= DSAddrA - 1;
            DSWeA <= '1';             
          when others => null;
        end case;
        
        -- Data stack value
        case conv_integer(cmd) is
          when 256 to 511 => -- LIT
            if PrevCmdIsLIT = '1' then
              DSDinA <= DSDoutA(DataWidth - 9 downto 0) & Cmd(7 downto 0);
            else
              DSDinA <= sxt(Cmd(7 downto 0), DataWidth);              
            end if;
                      
          -- group 1; pop 0; push 1;
          when cmdTEMP => DSDinA <= TempReg;
          when cmdDEPTH => DSDinA <= ext(DSAddrA, DataWidth);
          when cmdRDEPTH => DSDinA <= ext(RSAddrA, DataWidth);
          when cmdDUP => DSDinA <= DSDoutA;
          when cmdOVER => DSDinA <= DSDoutB;

          -- group 2; pop 1; push 0;
          -- empty          

          -- group 3; pop 1; push 1;
          when cmdFETCH => DSDinA <= DataDoutA;
          when cmdINPORT => DSDinA <= Din;
          when cmdNOT => -- logical
            if DSDoutA = ext("0", DataWidth) then
              DSDinA <= (others => '1');
            else
              DSDinA <= (others => '0');
            end if;
         when cmdSHL => DSDinA <= DSDoutA(DataWidth-2 downto 0) & '0';
         when cmdSHR => DSDinA <= '0' & DSDoutA(DataWidth-1 downto 1);
         when cmdSHRA => DSDinA <= DSDoutA(DataWidth-1) & DSDoutA(DataWidth-1 downto 1);

          -- group 4; pop 2; push 0;          
          when cmdSTORE =>            
            DataAddrA <= DSDoutA(DataAddrA'range);
            DataDinA <= DSDoutB;
            DataWeA <= '1';
          when cmdOUTPORT =>
            Addr <= DSDoutA;
            Dout <= DSDoutB;
            iowr <= '1';

          -- group 5; pop 2; push 1;           
          when cmdNIP => 
            TempReg <= DSDoutB;
            DSDinA <= DSDoutA;
          when cmdPLUS => DSDinA <= DSDoutB + DSDoutA;
          when cmdMINUS => DSDinA <= DSDoutB - DSDoutA;
          when cmdAND => DSDinA <= DSDoutB and DSDoutA;
          when cmdOR => DSDinA <= DSDoutB or DSDoutA;
          when cmdXOR => DSDinA <= DSDoutB xor DSDoutA;
          when cmdEQUAL => 
            if DSDoutB = DSDoutA then
              DSDinA <= (others => '1');
            else
              DSDinA <= (others => '0');
            end if;          
          when cmdGREATER => 
            if signed(DSDoutB) > signed(DSDoutA) then
              DSDinA <= (others => '1');
            else
              DSDinA <= (others => '0');
            end if;
          when cmdLESS => 
            if signed(DSDoutB) < signed(DSDoutA) then
              DSDinA <= (others => '1');
            else
              DSDinA <= (others => '0');
            end if;
          when cmdMUL => DSDinA <= MulResult(DataWidth - 1 downto 0);
          --when cmdMULH => DSDinA <= MulResult(DataWidth * 2 - 1 downto DataWidth);
            
          when others => null;
        end case;
        
        -- New ip and ret stack;
        case conv_integer(cmd) is
          when cmdJMP => -- jmp
            ip <= DSDoutA(ip'range);
            
          when cmdIF => -- if
            if conv_integer(DSDoutB) = 0 then
              ip <= DSDoutA(ip'range);
            else
              ip <= ip + 1;
            end if;
            
          when cmdCALL => -- call
            RSAddrA <= RSAddrA + 1;
            RSDinA <= ip + 1;
            RSWeA <= '1';
            ip <= DSDoutA(ip'range);
            
          when cmdRET => -- ret
            RSAddrA <= RSAddrA - 1;            
            ip <= RSDoutA(ip'range);
        
          when others => ip <= ip + 1;
        end case;
      end if;
    end if;
  end if;
end process;

end Behavioral;