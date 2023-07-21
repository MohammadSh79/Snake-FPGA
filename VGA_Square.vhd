library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity VGA_Square is
  port ( CLK_24MHz		: in std_logic;
			RESET				: in std_logic;
			ColorOut			: out std_logic_vector(5 downto 0); -- RED & GREEN & BLUE
			ScanlineX		: in std_logic_vector(10 downto 0);
			ScanlineY		: in std_logic_vector(10 downto 0);
			Buttons			: in std_logic_vector(3 downto 0); -- Buttons
			AN					: out std_logic_vector(3 downto 0); -- 7Seg Select
			SSEG				: out std_logic_vector(7 downto 0);  -- 7Seg Display
			LEDs				: out std_logic_vector(7 downto 0)
  );
end VGA_Square;

architecture Behavioral of VGA_Square is
 
  signal HeadX: std_logic_vector(11 downto 0) := "000101000000";
  signal HeadY: std_logic_vector(11 downto 0) := "000011110000";
  signal AppleX: std_logic_vector(11 downto 0) := "000010100000";
  signal AppleY: std_logic_vector(11 downto 0) := "000001111000";
  signal BombX : std_logic_vector(11 downto 0) := "111111111111";
  signal BombY : std_logic_vector(11 downto 0) := "111111111111";
  signal BombEn : std_logic := '0'; -- Bomb is disabled at the start
  signal Prescaler1: std_logic_vector(31 downto 0) := (others => '0'); -- for game speed
  signal Prescaler2: std_logic_vector(31 downto 0) := (others => '0'); -- for 1 second timer
  signal Prescaler3: std_logic_vector(31 downto 0) := (others => '0'); -- for 15 second timer
  signal Prescaler4: std_logic_vector(31 downto 0) := (others => '0'); -- for 7seg delay
  signal Prescaler5: std_logic_vector(34 downto 0) := (others => '0'); -- 5 second bomb explosion
  signal gameSpeed: std_logic_vector(31 downto 0) := "00000001011011100011011000000000";
  type t_cord is array (0 to 19, 0 to 1) of std_logic_vector(11 downto 0);
  signal tailPos : t_cord := ((others=> (others=>"111111111111")));
  signal size : integer range 0 to 19 := 3;
  signal direction : integer range 0 to 3 := 0;
  signal timer : integer range 0 to 99 := 0;
  signal AN_Buffer : std_logic_vector(3 downto 0) := "0111";
  signal SSEG_Buffer : std_logic_vector(7 downto 0) := "11111111";
  signal paused: std_logic := '1';
  signal ended: std_logic := '0';
  signal win: std_logic := '0';
  
  Constant DWidth : integer := 640;
  Constant DHeight : integer := 480;
  Constant SquareSize : std_logic_vector(11 downto 0) := "000000010100";

	-- Convert integer to 7segment input
	function int_to_ss(A: integer := 0) return std_logic_vector is
	begin
		if A = 0 then return "11000000";
		elsif A = 1 then return "11111001";
		elsif A = 2 then return "10100100";
		elsif A = 3 then return "10110000";
		elsif A = 4 then return "10011001";
		elsif A = 5 then return "10010010";
		elsif A = 6 then return "10000010";
		elsif A = 7 then return "11111000";
		elsif A = 8 then return "10000000";
		elsif A = 9 then return "10010000";
		else return "11101111";
		end if;
	end function;
	
	-- Pseudo rand
	function lfsr32(x : std_logic_vector(31 downto 0)) return std_logic_vector is
	begin
		return x(30 downto 0) & (x(0) xnor x(1) xnor x(21) xnor x(31));
	end function;

begin
	SevenSegment: process(CLK_24MHZ, RESET)
	begin
		if RESET = '1' then
			Prescaler4 <= (others => '0');
			SSEG_Buffer <= (others => '1');
		elsif rising_edge(CLK_24MHZ) then
			Prescaler4 <= Prescaler4 + 1;
			if Prescaler4 = "00000000000000001011101110000000" then -- 7Segment display delay - 2ms
				AN_Buffer <= AN_Buffer(2 downto 0) & AN_Buffer(3);
				if paused = '1' and ended = '0' then
					-- Show student id
					if AN_Buffer = "0111" then
						SSEG_Buffer <= "11000000";
					elsif AN_Buffer = "1110" then
						SSEG_Buffer <= "00000000";
					elsif AN_Buffer = "1101" then
						SSEG_Buffer <= "10110000";
					elsif AN_Buffer = "1011" then
						SSEG_Buffer <= "10010000";
					end if;
				else
					-- Show timer and score
					if AN_Buffer = "0111" then
						SSEG_Buffer <= int_to_ss(timer / 10);
					elsif AN_Buffer = "1110" then
						SSEG_Buffer <= int_to_ss(timer mod 10);
					elsif AN_Buffer = "1101" then
						SSEG_Buffer <= int_to_ss((size - 3) / 10);
					elsif AN_Buffer = "1011" then
						SSEG_Buffer <= int_to_ss((size - 3) mod 10);
					end if;
				end if;
				Prescaler4 <= (others => '0');
			end if;
		end if;
		SSEG <= SSEG_Buffer;
		AN <= AN_Buffer;
	end process SevenSegment;
	
	PrescalerCounter: process(CLK_24MHz, RESET, Buttons)
	variable tmpX, tmpY, oldX, oldY : integer;
	variable tmp1, tmp2 : std_logic_vector(31 downto 0);
	begin
		if RESET = '1' then
			win <= '0';
			direction <= 1;
			size <= 3;
			ended <= '0';
			paused <= '1';
			timer <= 0;
			Prescaler1 <= (others => '0');
			Prescaler2 <= (others => '0');
			Prescaler3 <= (others => '0');
			Prescaler5 <= (others => '0');
			BombEn <= '0';
			gameSpeed <= "00000001011011100011011000000000";
			HeadX <= "000101000000";
			HeadY <= "000011110000";
			AppleX <= "000010100000";
			AppleY <= "000001111000";
			-- Turn LEDs off
			LEDs <= "00000000";
			-- Adding 3 tail blocks
			tailPos <= ((others=> (others=>"111111111111")));
			tailPos(0, 0) <= "000101000000";
			tailPos(0, 1) <= "000100000100";
			tailPos(1, 0) <= "000101000000";
			tailPos(1, 1) <= "000100011000";
			tailPos(2, 0) <= "000101000000";
			tailPos(2, 1) <= "000100101100";
		elsif rising_edge(CLK_24MHz) then
			if paused = '1' and ended = '0' then -- At the start of the game
				tailPos(0, 0) <= "000101000000";
				tailPos(0, 1) <= "000100000100";
				tailPos(1, 0) <= "000101000000";
				tailPos(1, 1) <= "000100011000";
				tailPos(2, 0) <= "000101000000";
				tailPos(2, 1) <= "000100101100";
			end if;
			
			Prescaler1 <= Prescaler1 + 1;
			Prescaler2 <= Prescaler2 + 1;
			Prescaler3 <= Prescaler3 + 1;
			if BombEn = '1' then
				Prescaler5 <= Prescaler5 + 1;
			end if;
			
			if paused = '1' then
				Prescaler1 <= (others => '0');
				Prescaler2 <= (others => '0');
				Prescaler3 <= (others => '0');
				Prescaler5 <= (others => '0');
			end if;
			
			if Prescaler1 >= gameSpeed then
				-- Score is 15 and game is finished
				if size = 18 then
					paused <= '1';
					ended <= '1';
					win <= '1';
					-- Turn leds on
					LEDs <= "11111111";
				end if;
				
				-- Move snake head to the direction
				oldX := to_integer(unsigned(HeadX));
				oldY := to_integer(unsigned(HeadY));
				if direction = 0 then -- Move head up
					tmpY := to_integer(unsigned(HeadY)) - to_integer(unsigned(SquareSize));
					if tmpY < 0 then -- Going out of screen boundary
						tmpY := tmpY + DHeight;
					end if;
					HeadY <= std_logic_vector(to_unsigned(tmpY, 12));					
				elsif direction = 1 then -- Move head right
					tmpX := to_integer(unsigned(HeadX)) + to_integer(unsigned(SquareSize));
					if tmpX > DWidth then -- Going out of screen boundary
						tmpX := tmpX - DWidth;
					end if;
					HeadX <= std_logic_vector(to_unsigned(tmpX, 12));
				elsif direction = 2 then -- Move head down
					tmpY := to_integer(unsigned(HeadY)) + to_integer(unsigned(SquareSize));
					if tmpY > DHeight then -- Going out of screen boundary
						tmpY := tmpY - DHeight;
					end if;
					HeadY <= std_logic_vector(to_unsigned(tmpY, 12));
				elsif direction = 3 then -- Move head left
					tmpX := to_integer(unsigned(HeadX)) - to_integer(unsigned(SquareSize));
					if tmpX < 0 then -- Going out of screen boundary
						tmpX := tmpX + DWidth;
					end if;
					HeadX <= std_logic_vector(to_unsigned(tmpX, 12));
				end if;
				
				-- Move tail blocks
				for i in 0 to 15 loop
					-- return if value = 11111111111111111111
					if tailPos(i, 0) /= "111111111111" and tailPos(i, 1) /= "111111111111" then					
						tmpX := to_integer(unsigned(tailPos(i, 0)));
						tailPos(i, 0) <= std_logic_vector(to_unsigned(oldX, 12));
						oldX := tmpX;
						
						tmpY := to_integer(unsigned(tailPos(i, 1)));
						tailPos(i, 1) <= std_logic_vector(to_unsigned(oldY, 12));
						oldY := tmpY;
						
						-- Is head hitting a tail block?
						if HeadX = tailPos(i, 0) and HeadY = tailPos(i, 1) then
							ended <= '1';
							paused <= '1';
						end if;
					end if;
				end loop;
				
				Prescaler1 <= (others => '0');
			end if;
			
			if Prescaler2 = "001011011100011011000000000" then -- Activated every 1 second
				if timer < 99 then
					timer <= timer + 1;
				else
					-- Time is up and game is finished
					win <= '1';
					paused <= '1';
					ended <= '1';
					-- Turn leds on
					LEDs <= "11111111";
				end if;
				Prescaler2 <= (others => '0');
			end if;
			
			if paused = '1' then
					Prescaler2 <= (others => '0');
			end if;
			
			if Prescaler3 = "00010101011101010010101000000000" then -- Activated every 15 second
				if gameSpeed > "00000000001111010000100100000000" then
					gameSpeed <= gameSpeed - "00000000001111010000100100000000"; -- Increase game speed
					-- Place the bomb and enable it
					BombEn <= '1';
					tmpX := (to_integer(unsigned(lfsr32("00000000000000000000" & BombX))) mod (DWidth - to_integer(unsigned(SquareSize)))) / 20;
					tmp1 := std_logic_vector(to_unsigned(tmpX * 20, 32));
					BombX <= tmp1(11 downto 0);
					tmpY := (to_integer(unsigned(lfsr32("00000000000000000000" & BombY))) mod (DHeight - to_integer(unsigned(SquareSize)))) / 20;
					tmp2 := std_logic_vector(to_unsigned(tmpY * 20, 32));
					BombY <= tmp2(11 downto 0);
				else
					gameSpeed <= "00000000001111010000100100000000";
				end if;
				Prescaler3 <= (others => '0');
			end if;
			
			if Prescaler5 = "1110010011100001110000000000" and BombEn = '1' then -- Explode bomb
				BombEn <= '0';
				-- Check if snake head is around <----------------------------------------------------
				if abs(to_integer(unsigned(HeadX)) - to_integer(unsigned(BombX))) <= (to_integer(unsigned(SquareSize)) * 2) and abs(to_integer(unsigned(HeadY)) - to_integer(unsigned(BombY))) <= (to_integer(unsigned(SquareSize)) * 2) then
					paused <= '1';
					ended <= '1';
				end if;
				Prescaler5 <= (others => '0');
			end if;
			
			-- Eat the apple
			if HeadX = AppleX and HeadY = AppleY then
				-- Add one to snake's tail
				tailPos(size, 0) <= std_logic_vector(to_unsigned(oldX, 12));
				tailPos(size, 1) <= std_logic_vector(to_unsigned(oldY, 12));
				size <= size + 1;
				-- Change apple's position
				tmpX := (to_integer(unsigned(lfsr32("00000000000000000000" & AppleX))) mod (DWidth - to_integer(unsigned(SquareSize)))) / 20;
				tmp1 := std_logic_vector(to_unsigned(tmpX * 20, 32));
				AppleX <= tmp1(11 downto 0);
				tmpY := (to_integer(unsigned(lfsr32("00000000000000000000" & AppleY))) mod (DHeight - to_integer(unsigned(SquareSize)))) / 20;
				tmp2 := std_logic_vector(to_unsigned(tmpY * 20, 32));
				AppleY <= tmp2(11 downto 0);
			end if;
			
			-- Snake hits the bomb
			if HeadX = BombX and HeadY = BombY and BombEn = '1' then -- Kaboom
				paused <= '1';
				ended <= '1';
				win <= '0';
			end if;
			
			-- Unpause the game if button pressed
			if (Buttons(0) = '0' or Buttons(1) = '0' or Buttons(2) = '0' or Buttons(3) = '0') and ended = '0' then
				paused <= '0';
			end if;
			
			-- Change direction if button pressed
			if Buttons(0) = '0' and direction /= 2 then direction <= 0;
			elsif Buttons(1) = '0' and direction /= 3 then direction <= 1;
			elsif Buttons(2) = '0' and direction /= 0 then direction <= 2;
			elsif Buttons(3) = '0' and direction /= 1 then direction <= 3;
			end if;
			
		end if;
	end process PrescalerCounter; 
	
	-- Rendering process
	ColorSelect: process(ScanlineX, ScanlineY)
	begin
	ColorOut <= "000000"; -- Default color is black (Background)
	
	if ScanlineX > HeadX and ScanlineX < (HeadX + SquareSize) and ScanlineY > HeadY and ScanlineY < (HeadY + SquareSize)
		then
			if ended = '1' and paused = '1' and win = '0' then
				ColorOut <= "010000"; -- Render head red
			else
				ColorOut <= "000100"; -- Render head green
			end if;
	end if;
	
	for i in 0 to 15 loop
		-- Render if tail is not 111111111111
		if tailPos(i, 0) /= "111111111111" and tailPos(i, 1) /= "111111111111" then					
			if ScanlineX > tailPos(i, 0) and ScanlineX < (tailPos(i, 0) + SquareSize) and ScanlineY > tailPos(i, 1) and ScanlineY < (tailPos(i, 1) + SquareSize)
				then
					if ended = '1' and paused = '1' and win = '0' then
						ColorOut <= "110000"; -- Render tails red
					else
						ColorOut <= "001100"; -- Render tails green
					end if;
					exit; -- Break out of loop
			end if;
		end if;
	end loop;
	
	-- Render Apple
	if ScanlineX > AppleX and ScanlineX < (AppleX + SquareSize) and ScanlineY > AppleY and ScanlineY < (AppleY + SquareSize)
		then ColorOut <= "110000"; -- Render head	
	end if;
	
	-- Render Bomb
	if BombEn = '1' and ScanlineX > BombX and ScanlineX < (BombX + SquareSize) and ScanlineY > BombY and ScanlineY < (BombY + SquareSize)
		then ColorOut <= "010101"; -- Render head	
	end if;
	
	end process ColorSelect;

end Behavioral;