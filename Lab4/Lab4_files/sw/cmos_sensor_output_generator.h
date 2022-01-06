/*
 * cmos_sensor_output_generator.h
 *
 *  Created on: 31 déc. 2021
 *      Author: hugom
 */

#ifndef CMOS_SENSOR_OUTPUT_GENERATOR_H_
#define CMOS_SENSOR_OUTPUT_GENERATOR_H_

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "cmos_sensor_output_generator/cmos_sensor_output_generator.h"
#include "cmos_sensor_output_generator/cmos_sensor_output_generator_regs.h"

#define CMOS_SENSOR_OUTPUT_GENERATOR_0_BASE       (0x10000820) /* cmos_sensor_output_generator base address from system.h (ADAPT TO YOUR DESIGN) */
#define CMOS_SENSOR_OUTPUT_GENERATOR_0_PIX_DEPTH  (12)     /* cmos_sensor_output_generator pix depth from system.h (ADAPT TO YOUR DESIGN) */
#define CMOS_SENSOR_OUTPUT_GENERATOR_0_MAX_WIDTH  (640)    /* cmos_sensor_output_generator max width from system.h (ADAPT TO YOUR DESIGN) */
#define CMOS_SENSOR_OUTPUT_GENERATOR_0_MAX_HEIGHT (480)    /* cmos_sensor_output_generator max height from system.h (ADAPT TO YOUR DESIGN) */

int start_cmos(void);

#endif /* CMOS_SENSOR_OUTPUT_GENERATOR_H_ */
