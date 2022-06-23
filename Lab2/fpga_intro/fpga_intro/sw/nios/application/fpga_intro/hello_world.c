
#include <stdio.h>
#include <system.h>
#include <io.h>
#include <inttypes.h>
#include <altera_avalon_pio_regs.h>


#define IREGDATA 0
#define IREGDIR 1
#define MODE_ALL_OUTPUT 0xFF
#define MODE_ALL_INPUT 0X00

void init0()
{
	volatile unsigned int k;

	int a = 0b1;

	IOWR_8DIRECT(PIO_0_BASE, IREGDIR, MODE_ALL_OUTPUT);

	while(1)
	 {

		if (a == 0b1 << 8){
			a = 0b1;
		}


		IOWR_8DIRECT(PIO_0_BASE, IREGDATA, a);

		for(k=0;k<4000000;k++);

		a = a << 1;
	 }
}

int main0()
{

	init();
	/* Event loop never exits. */
	while (1);
	return 0;
}
