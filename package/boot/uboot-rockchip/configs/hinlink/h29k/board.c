// SPDX-License-Identifier: GPL-2.0+
/*
 * Board init for Hinlink H29K RK3528
 */
#include <common.h>

int board_init(void)
{
	gd->bd->bi_boot_params = 0x40000000 + 0x100;
	return 0;
}
