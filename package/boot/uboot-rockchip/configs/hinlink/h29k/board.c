// SPDX-License-Identifier: GPL-2.0+
/*
 * Board init for Hinlink H29K RK3528
 */
#include <common.h>

#define SYS_SDRAM_BASE 0x40000000

int board_init(void)
{
	gd->bd->bi_boot_params = SYS_SDRAM_BASE + 0x100;
	return 0;
}
