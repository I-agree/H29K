// SPDX-License-Identifier: GPL-2.0-only
/*
 * ChipOne / AXS Technology AXS5106L capacitive touch controller driver
 *
 * Protocol extracted from Waveshare user-space demo (axs5106l.c / DEV_Config.c):
 *   - I2C 7-bit address: 0x63
 *   - 8-bit register address
 *   - ID register 0x08: 3 ASCII bytes
 *   - Touch register 0x01: 14 bytes, up to 2 points, 12-bit X/Y
 *   - Reset: RST low 100ms → high → wait 200ms
 *   - INT: falling edge
 */

#include <linux/delay.h>
#include <linux/gpio/consumer.h>
#include <linux/i2c.h>
#include <linux/input.h>
#include <linux/input/mt.h>
#include <linux/interrupt.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/slab.h>

#define AXS5106_REG_TOUCH	0x01
#define AXS5106_REG_ID		0x08
#define AXS5106_TOUCH_LEN	14
#define AXS5106_ID_LEN		3
#define AXS5106_MAX_POINTS	2

/* Default resolution; overridable via DT touchscreen-size-x/y */
#define AXS5106_DEF_MAX_X	0x0FFF
#define AXS5106_DEF_MAX_Y	0x0FFF

struct axs5106_ts {
	struct i2c_client	*client;
	struct input_dev	*input;
	struct gpio_desc	*reset_gpio;
	u32			max_x;
	u32			max_y;
	bool			inverted_x;
	bool			inverted_y;
	bool			swapped_xy;
};

/*
 * 8-bit register read: [write 1B reg addr][read N bytes]
 * Combined I2C transfer (two messages, no repeated start needed).
 */
static int axs5106_read(struct i2c_client *client, u8 reg, u8 *buf, size_t len)
{
	int ret;

	/*
	 * Split into two separate I2C transactions.
	 * The rk3x I2C controller cannot do a proper REPEATED START,
	 * so combined write+read (2 msgs in one transfer) fails with
	 * "unexpected irq in STOP: 0x90".
	 *
	 * Transaction 1: [START][addr+W][reg][STOP]
	 * Transaction 2: [START][addr+R][data...][STOP]
	 */
	ret = i2c_master_send(client, &reg, 1);
	if (ret != 1)
		return ret < 0 ? ret : -EIO;

	ret = i2c_master_recv(client, buf, len);
	if (ret != (int)len)
		return ret < 0 ? ret : -EIO;

	return 0;
}

/*
 * Hardware reset: RST low 100ms → RST high → wait 200ms.
 * (Mirrors axs5106l_touch_rst() from Waveshare demo.)
 *
 * !! POLARITY CONTRACT (DO NOT MODIFY WITHOUT READING) !!
 *
 * This driver uses "logical value == physical level" convention:
 *   set_value(0) → physical LOW  → reset asserted
 *   set_value(1) → physical HIGH → reset released
 *
 * Therefore the DTS reset-gpios MUST use GPIO_ACTIVE_HIGH.
 * If someone changes DTS to GPIO_ACTIVE_LOW, they MUST also swap
 * the 0/1 values below, otherwise reset polarity inverts and the
 * chip will never come up.
 *
 * The two (driver logic + DTS polarity) are a coupled pair;
 * modifying one without the other WILL break reset.
 */
static void axs5106_hard_reset(struct axs5106_ts *ts)
{
	if (!ts->reset_gpio)
		return;

	gpiod_set_value_cansleep(ts->reset_gpio, 0);	/* physical LOW = assert reset */
	msleep(100);
	gpiod_set_value_cansleep(ts->reset_gpio, 1);	/* physical HIGH = release reset */
	msleep(200);
}

static irqreturn_t axs5106_irq(int irq, void *dev_id)
{
	struct axs5106_ts *ts = dev_id;
	u8 data[AXS5106_TOUCH_LEN];
	int points, i;
	int ret;

	ret = axs5106_read(ts->client, AXS5106_REG_TOUCH, data, sizeof(data));
	if (ret) {
		dev_dbg(&ts->client->dev, "read touch data failed: %d\n", ret);
		goto out;
	}

	points = data[1] & 0x0F;
	if (points > AXS5106_MAX_POINTS)
		points = AXS5106_MAX_POINTS;

	for (i = 0; i < AXS5106_MAX_POINTS; i++) {
		u16 x, y;

		input_mt_slot(ts->input, i);

		if (i < points) {
			x = ((u16)(data[2 + i * 6] & 0x0F) << 8) | data[3 + i * 6];
			y = ((u16)(data[4 + i * 6] & 0x0F) << 8) | data[5 + i * 6];

			if (ts->swapped_xy)
				swap(x, y);
			if (ts->inverted_x)
				x = (ts->max_x - 1) - x;
			if (ts->inverted_y)
				y = (ts->max_y - 1) - y;

			input_mt_report_slot_state(ts->input, MT_TOOL_FINGER, true);
			input_report_abs(ts->input, ABS_MT_POSITION_X, x);
			input_report_abs(ts->input, ABS_MT_POSITION_Y, y);
		} else {
			input_mt_report_slot_state(ts->input, MT_TOOL_FINGER, false);
		}
	}

	input_mt_sync_frame(ts->input);
	input_sync(ts->input);
out:
	return IRQ_HANDLED;
}

static int axs5106_probe(struct i2c_client *client)
{
	struct device *dev = &client->dev;
	struct axs5106_ts *ts;
	u8 id[AXS5106_ID_LEN];
	int ret;

	if (!i2c_check_functionality(client->adapter, I2C_FUNC_I2C)) {
		dev_err(dev, "I2C_FUNC_I2C not supported\n");
		return -EIO;
	}

	ts = devm_kzalloc(dev, sizeof(*ts), GFP_KERNEL);
	if (!ts)
		return -ENOMEM;
	ts->client = client;

	/*
	 * Reset GPIO: initial GPIOD_OUT_HIGH → physical HIGH → not in reset.
	 * Must be GPIO_ACTIVE_HIGH in DTS (see axs5106_hard_reset comment).
	 */
	ts->reset_gpio = devm_gpiod_get_optional(dev, "reset", GPIOD_OUT_HIGH);
	if (IS_ERR(ts->reset_gpio))
		return dev_err_probe(dev, PTR_ERR(ts->reset_gpio),
				     "failed to get reset gpio\n");

	/* Optional DT properties for orientation / resolution */
	ts->max_x = AXS5106_DEF_MAX_X;
	ts->max_y = AXS5106_DEF_MAX_Y;
	device_property_read_u32(dev, "touchscreen-size-x", &ts->max_x);
	device_property_read_u32(dev, "touchscreen-size-y", &ts->max_y);
	ts->inverted_x = device_property_read_bool(dev, "touchscreen-inverted-x");
	ts->inverted_y = device_property_read_bool(dev, "touchscreen-inverted-y");
	ts->swapped_xy = device_property_read_bool(dev, "touchscreen-swapped-x-y");

	axs5106_hard_reset(ts);

	ret = axs5106_read(client, AXS5106_REG_ID, id, sizeof(id));
	if (ret) {
		dev_err(dev, "failed to read chip id: %d\n", ret);
		return ret;
	}
	dev_info(dev, "AXS5106 ID: %3phN\n", id);

	ts->input = devm_input_allocate_device(dev);
	if (!ts->input)
		return -ENOMEM;

	ts->input->name = "AXS5106 touchscreen";
	ts->input->phys = "input/ts";
	ts->input->id.bustype = BUS_I2C;

	__set_bit(EV_ABS, ts->input->evbit);
	__set_bit(EV_KEY, ts->input->evbit);
	__set_bit(BTN_TOUCH, ts->input->keybit);

	/*
	 * !! COORDINATE-RANGE CONTRACT (read before touching DTS) !!
	 *
	 * touchscreen-size-x/y carry the *pixel count* (e.g. 320 / 172),
	 * i.e. hardware_max + 1. From it we derive:
	 *   - absinfo range : [0, size-1]   (the values we actually report)
	 *   - invert mirror : (size-1) - v  (see axs5106_irq)
	 * Both use (size-1) on purpose, so absinfo max and the invert
	 * pivot are identical -- matching edt-ft5x06 / goodix convention.
	 *
	 * Consequence: size MUST equal hardware_max + 1. If someone writes
	 * size = hardware_max (e.g. 319 instead of 320), the invert pivot
	 * becomes 318 while the chip can still emit 319, and (318 - 319)
	 * underflows the u16 -> garbage at the edge. There is NO clamp by
	 * design (same as upstream drivers); correctness rests on the DTS
	 * value. For this panel hardware_max is 319 x 171, so size = 320/172.
	 *
	 * Resolution (units/mm) below intentionally keeps using ts->max_x
	 * (the discrete-value count), not the abs max; off by one there is
	 * immaterial after rounding.
	 */
	input_set_abs_params(ts->input, ABS_MT_POSITION_X, 0, ts->max_x - 1, 0, 0);
	input_set_abs_params(ts->input, ABS_MT_POSITION_Y, 0, ts->max_y - 1, 0, 0);

	/*
	 * Physical size (mm) -> evdev resolution (units/mm), so libinput shows
	 * real millimetres instead of misreporting raw pixels as mm.
	 *
	 * touchscreen-x-mm / touchscreen-y-mm are *standard* properties
	 * (see touchscreen.yaml), but this driver parses orientation by hand
	 * and never calls touchscreen_parse_properties(), so we read them
	 * manually here. Read-and-use is kept in a block scope on purpose:
	 * unlike size/inverted/swapped, these values are NOT needed in the
	 * IRQ, so they need not live in struct axs5106_ts.
	 *
	 * Guarded by (x_mm && ts->max_x): if the DT omits the property,
	 * device_property_read_u32() fails, x_mm stays 0 and we skip,
	 * preserving the old behaviour (resolution == 0). Backward compatible.
	 *
	 * Rounding: (max + mm/2)/mm == DIV_ROUND_CLOSEST(max, mm) for positive
	 * ints, written out by hand to avoid any <linux/math.h> dependency.
	 * 320/37 -> 9, 172/20 -> 9 (plain truncation would give 8, less exact).
	 */
	{
		u32 x_mm = 0, y_mm = 0;

		device_property_read_u32(dev, "touchscreen-x-mm", &x_mm);
		device_property_read_u32(dev, "touchscreen-y-mm", &y_mm);

		if (x_mm && ts->max_x)
			input_abs_set_res(ts->input, ABS_MT_POSITION_X,
					  (ts->max_x + x_mm / 2) / x_mm);
		if (y_mm && ts->max_y)
			input_abs_set_res(ts->input, ABS_MT_POSITION_Y,
					  (ts->max_y + y_mm / 2) / y_mm);
	}

	input_mt_init_slots(ts->input, AXS5106_MAX_POINTS,
			    INPUT_MT_DIRECT | INPUT_MT_DROP_UNUSED);

	ret = input_register_device(ts->input);
	if (ret)
		return dev_err_probe(dev, ret, "failed to register input\n");

	/*
	 * Trigger type is specified by DTS (interrupts = <... IRQ_TYPE_EDGE_FALLING>).
	 * Driver does NOT hardcode IRQF_TRIGGER_* here.
	 */
	ret = devm_request_threaded_irq(dev, client->irq, NULL, axs5106_irq,
					IRQF_ONESHOT,
					client->name, ts);
	if (ret)
		return dev_err_probe(dev, ret, "failed to request irq %d\n",
				     client->irq);

	i2c_set_clientdata(client, ts);
	return 0;
}

/*
 * Remove callback for 6.18+ kernels: returns void.
 *
 * The input device is allocated with devm_input_allocate_device() and
 * registered with input_register_device(); both steps enqueue devres
 * nodes whose release callbacks (input_put_device / __input_unregister_device)
 * fire automatically on driver detach. We must NOT call
 * input_unregister_device() here:
 *
 *   - It would remove the devres unregister node (via devres_destroy)
 *     and unregister the input device *now*, while the devres-managed
 *     IRQ (#5 on the stack) is still enabled. The remaining devres
 *     unwind would then run free_irq *after* the input device has
 *     already been torn down -- inverting the safe LIFO order
 *     (free_irq → unregister → put) into (unregister → free_irq → put)
 *     and opening a use-after-free window for axs5106_irq().
 *
 *   - Verified against drivers/input/input.c (devres_destroy does NOT
 *     invoke the release callback) and drivers/base/devres.c
 *     (release_nodes iterates list_for_each_entry_safe_reverse = LIFO).
 *
 * This callback is kept only to log detachment.
 */
static void axs5106_remove(struct i2c_client *client)
{
	dev_info(&client->dev, "AXS5106 removed\n");
}

static const struct of_device_id axs5106_of_match[] = {
	{ .compatible = "chipone,axs5106" },
	{ .compatible = "chipone,axs5106l" },
	{ /* sentinel */ }
};
MODULE_DEVICE_TABLE(of, axs5106_of_match);

static const struct i2c_device_id axs5106_i2c_id[] = {
	{ "axs5106", 0 },
	{ "axs5106l", 0 },
	{ /* sentinel */ }
};
MODULE_DEVICE_TABLE(i2c, axs5106_i2c_id);

static struct i2c_driver axs5106_driver = {
	.driver = {
		.name = "axs5106",
		.of_match_table = axs5106_of_match,
	},
	.probe		= axs5106_probe,
	.remove		= axs5106_remove,
	.id_table	= axs5106_i2c_id,
};
module_i2c_driver(axs5106_driver);

MODULE_AUTHOR("Derived from Waveshare AXS5106L demo");
MODULE_DESCRIPTION("ChipOne AXS5106L capacitive touch controller");
MODULE_LICENSE("GPL v2");
