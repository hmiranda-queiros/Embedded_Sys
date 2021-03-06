
#include <stdio.h>
#include <system.h>
#include <io.h>
#include <inttypes.h>
#include <altera_avalon_pio_regs.h>


#define IREGDIR 0
#define IREGPORT 1
#define IREGPERIOD 2
#define IREGDUTY 3
#define IREGPOLARITY 4
#define MODE_ALL_OUTPUT 0xFF
#define MODE_ALL_INPUT 0X00
#define PWM_BASE 0x00041000
#define F_50MHz 50000000					// Frequency of the clock of the FPGA in Hz
#define F_wanted 50							// Frequency wanted for the PWM in Hz
#define DUTY 5								// Duty cycle wanted for the PWM in %

void init()
{
	IOWR_32DIRECT(PWM_BASE, IREGDIR * 4, MODE_ALL_OUTPUT);								// sets all the pins in mode Output
	IOWR_32DIRECT(PWM_BASE, IREGPOLARITY * 4, 1);										// sets the polarity to 1
	IOWR_32DIRECT(PWM_BASE, IREGPERIOD * 4, (int)(F_50MHz / F_wanted));					// sets the period of the PWM
	IOWR_32DIRECT(PWM_BASE, IREGDUTY * 4, (int)(F_50MHz / F_wanted * DUTY / 100));		// sets the duty cycle of the PWM

	volatile unsigned int k;
	volatile unsigned int a = 0;

	while(1){

		if (a > 5){
			a = 0;
		}

		IOWR_32DIRECT(PWM_BASE, IREGDUTY * 4, (int)(F_50MHz / F_wanted * (DUTY + a) / 100));	// varies the value of duty cycle to change position of the servo

		for(k=0;k<4000000;k++);

		a += 1;
	 }

}

int main()
{
	init();
	/* Event loop never exits. */
	while (1);
	return 0;
}
