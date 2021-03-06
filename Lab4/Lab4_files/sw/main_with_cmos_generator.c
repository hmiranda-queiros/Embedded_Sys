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

int main0(void) {

	//Starts the cmos_output_generator
	start_cmos();

	//Writes in Camera_Ctrl registers
	IOWR_32DIRECT(CAMERA_CTRL_BASE, IREGADR * 4, HPS_0_BRIDGES_BASE_1);		// sets the start address of the frame in memory
	IOWR_32DIRECT(CAMERA_CTRL_BASE, IREGBURST * 4, 16);						// sets the length of the burst to transfer in words of 32 bits
	IOWR_32DIRECT(CAMERA_CTRL_BASE, IREGLENGTH * 4, 38400);					// sets the length of one frame in memory in number of 32 bit words
	IOWR_32DIRECT(CAMERA_CTRL_BASE, IREGLIGHT * 4, 0);						// sets the lighting conditions of the camera
	IOWR_32DIRECT(CAMERA_CTRL_BASE, IREGENABLE * 4, 1);						// sets the state of the camera interface to enable

	volatile unsigned int read_enable = IORD_32DIRECT(CAMERA_CTRL_BASE, IREGENABLE * 4);

	// Waits that the first frame is written in memory
	while(read_enable == 1){
		read_enable = IORD_32DIRECT(CAMERA_CTRL_BASE, IREGENABLE * 4);
	}

	//Reads the first frame in memory
	read_memory(HPS_0_BRIDGES_BASE_1, "/mnt/host/image_1_cmos.ppm");

	//Changes the start address for the next frame and enables camera acquisition again
	IOWR_32DIRECT(CAMERA_CTRL_BASE, IREGADR * 4, HPS_0_BRIDGES_BASE_2);
	IOWR_32DIRECT(CAMERA_CTRL_BASE, IREGENABLE * 4, 1);

	read_enable = IORD_32DIRECT(CAMERA_CTRL_BASE, IREGENABLE * 4);

	// Waits that the second frame is written in memory
	while(read_enable == 1){
			read_enable = IORD_32DIRECT(CAMERA_CTRL_BASE, IREGENABLE * 4);
	}

	//Reads the second frame in memory
	read_memory(HPS_0_BRIDGES_BASE_2, "/mnt/host/image_2_cmos.ppm");

	return EXIT_SUCCESS;
}
