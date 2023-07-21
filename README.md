# Snake Game
This game was created by me as the final project of Computer-Aided Design(CAD) course (Instructed by Dr.Aminian) in University of Guilan.

## How To Play
As the game starts, you can control the snake with 4 micro-switches on the FPGA. There are 4 7-segments in total. The 2 left-side ones show the timer. And the other 2 show the score of player. Red squares are apples and they increase player's total score and length of snake when the snake hits/eats them. The white squares that appear and disappear randomly are bombs. They explode 10 seconds after spawning.

**Game finishes when:**
 - Snake is within range of 2 blocks of bomb when bomb explodes
 - Snake head hits its body
 - Timer reaches 99

Green LEDs on FPGA will turn on when the game is finished.