#include <stdio.h>
#include <system.h>
#include <io.h>
#include <inttypes.h>

#include "cmos_sensor_output_generator.h"
#include "memory_access.h"

#define IREGADR 0
#define IREGLENGTH 1
#define IREGENABLE 2
#define IREGBURST 3
#define IREGLIGHT 4
#define CAMERA_CTRL_BASE (0x10000840)

int main(void) {

	start_cmos();

	IOWR_32DIRECT(CAMERA_CTRL_BASE, IREGADR * 4, 0);								// sets all the pins in mode Output
	IOWR_32DIRECT(CAMERA_CTRL_BASE, IREGBURST * 4, 1);
	IOWR_32DIRECT(CAMERA_CTRL_BASE, IREGLENGTH * 4, 2);										// sets the polarity to 1
	IOWR_32DIRECT(CAMERA_CTRL_BASE, IREGLIGHT * 4, 0);		// sets the duty cycle of the PWM
	IOWR_32DIRECT(CAMERA_CTRL_BASE, IREGENABLE * 4, 1);					// sets the period of the PWM

	volatile unsigned int read_enable = IORD_32DIRECT(CAMERA_CTRL_BASE, IREGENABLE * 4);
	volatile unsigned int k = 0;

	while(read_enable == 1){
		read_enable = IORD_32DIRECT(CAMERA_CTRL_BASE, IREGENABLE * 4);
		for(k=0;k<4000000;k++);
	}

	//read_memory();

    return EXIT_SUCCESS;
}
