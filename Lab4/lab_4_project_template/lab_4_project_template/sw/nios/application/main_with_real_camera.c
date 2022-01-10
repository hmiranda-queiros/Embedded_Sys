/*
 * main_with_real_camera.c
 *
 *  Created on: 2 janv. 2022
 *      Author: hugom
 */

#include <stdio.h>
#include <system.h>
#include <io.h>
#include <inttypes.h>

#include "i2c_m.h"
#include "memory_access.h"
#include "LCD_control.h"

#define IREGADR 0
#define IREGLENGTH 1
#define IREGENABLE 2
#define IREGBURST 3
#define IREGLIGHT 4
#define CAMERA_CTRL_BASE (0x10000820)

#define ADDRESS_REG 	0b100
#define COMMAND_REG 	0b00
#define IMAGE_READ_REG 	0b1000
#define DISPLAY_COMMAND 0x0000002C
#define NOP_COMMAND		0x00000000

int main(void) {

	//initialize the LCD
	LCD_init();

	//Configures the camera
	configure_camera();

	//Writes in Camera_Ctrl registers
	IOWR_32DIRECT(CAMERA_CTRL_BASE, IREGADR * 4, HPS_0_BRIDGES_BASE_1);		// sets the start address of the frame in memory
	IOWR_32DIRECT(CAMERA_CTRL_BASE, IREGBURST * 4, 16);						// sets the length of the burst to transfer in words of 32 bits
	IOWR_32DIRECT(CAMERA_CTRL_BASE, IREGLENGTH * 4, 38400);					// sets the length of one frame in memory in number of 32 bit words
	IOWR_32DIRECT(CAMERA_CTRL_BASE, IREGLIGHT * 4, 1);						// sets the lighting conditions of the camera
	IOWR_32DIRECT(CAMERA_CTRL_BASE, IREGENABLE * 4, 1);						// sets the state of the camera interface to enable

	IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, IMAGE_READ_REG, 1);

	volatile unsigned int enable_camera = IORD_32DIRECT(CAMERA_CTRL_BASE, IREGENABLE * 4);

	//tells the LCD to display the written image
	//IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, ADDRESS_REG, HPS_0_BRIDGES_BASE_1);
	//IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, COMMAND_REG, DISPLAY_COMMAND);
	volatile unsigned int image_read_lcd = IORD_32DIRECT(LCD_CONTROLLER_0_BASE, IMAGE_READ_REG);

	volatile unsigned int img_1_written = 0;
	volatile unsigned int img_2_written = 1;
	volatile unsigned int img_1_read = 0;
	volatile unsigned int img_2_read = 1;

	while(1){
		enable_camera = IORD_32DIRECT(CAMERA_CTRL_BASE, IREGENABLE * 4);
		image_read_lcd = IORD_32DIRECT(LCD_CONTROLLER_0_BASE, IMAGE_READ_REG);

		if (enable_camera == 0){
			if (img_2_written == 1){
				img_1_written = 1;
				if (img_2_read == 1){
					img_2_written = 0;
					read_memory(HPS_0_BRIDGES_BASE_1, "/mnt/host/image_1_camera.ppm");
					IOWR_32DIRECT(CAMERA_CTRL_BASE, IREGADR * 4, HPS_0_BRIDGES_BASE_2);
					IOWR_32DIRECT(CAMERA_CTRL_BASE, IREGENABLE * 4, 1);
				}
			}
			else if (img_1_written == 1){
				img_2_written = 1;
				if (img_1_read == 1){
					img_1_written = 0;
					//read_memory(HPS_0_BRIDGES_BASE_2, "/mnt/host/image_1_camera.ppm");
					IOWR_32DIRECT(CAMERA_CTRL_BASE, IREGADR * 4, HPS_0_BRIDGES_BASE_1);
					IOWR_32DIRECT(CAMERA_CTRL_BASE, IREGENABLE * 4, 1);
				}
			}
		}

		if (image_read_lcd == 1){
			if (img_2_read == 1){
				img_1_read = 1;
				if (img_2_written == 1){
					IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, IMAGE_READ_REG, 0);
					img_2_read = 0;
					IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, ADDRESS_REG, HPS_0_BRIDGES_BASE_2);
					IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, COMMAND_REG, DISPLAY_COMMAND);
				}
			}
			else if (img_1_read == 1){
				img_2_read = 1;
				if (img_1_written == 1){
					IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, IMAGE_READ_REG, 0);
					img_1_read = 0;
					IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, ADDRESS_REG, HPS_0_BRIDGES_BASE_1);
					IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, COMMAND_REG, DISPLAY_COMMAND);
				}
			}
		}
	}



	/*
	while(enable_camera == 1){
		enable_camera = IORD_32DIRECT(CAMERA_CTRL_BASE, IREGENABLE * 4);
	}

	//Reads the first frame in memory
	read_memory(HPS_0_BRIDGES_BASE_1, "/mnt/host/image_1_camera.ppm");

	//Changes the start address for the next frame and enables camera acquisition again
	IOWR_32DIRECT(CAMERA_CTRL_BASE, IREGADR * 4, HPS_0_BRIDGES_BASE_2);
	IOWR_32DIRECT(CAMERA_CTRL_BASE, IREGENABLE * 4, 1);

	/*
	read_enable = IORD_32DIRECT(CAMERA_CTRL_BASE, IREGENABLE * 4);

	// Waits that the second frame is written in memory
	while(read_enable == 1){
			read_enable = IORD_32DIRECT(CAMERA_CTRL_BASE, IREGENABLE * 4);
	}

	//Reads the second frame in memory
	read_memory(HPS_0_BRIDGES_BASE_2, "/mnt/host/image_2_camera.ppm");
	*/
	return EXIT_SUCCESS;
}
