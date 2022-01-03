/*
 * memory_access.h
 *
 *  Created on: 31 déc. 2021
 *      Author: hugom
 */

#ifndef MEMORY_ACCESS_H_
#define MEMORY_ACCESS_H_

#include <assert.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#include "io.h"
#include "system.h"

#define HPS_0_BRIDGES_BASE_1 (0x00000000)			/* address_span_expander base address of first frame */
#define HPS_0_BRIDGES_BASE_2 (0x1E8480)				/* address_span_expander base address of second frame */


int read_memory(uint32_t base_address_memory, char* filename);


#endif /* MEMORY_ACCESS_H_ */
