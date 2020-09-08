#include "fts_boost.h"

static struct fts_touch_pdata *touch_pdata;

static int fts_touch_dev_open(struct inode *inode, struct file *file)
{
	struct fts_touch *dev = NULL;
	int i = MINOR(inode->i_rdev);
	struct fts_touch_pdata *touch_pdata;

	pr_info("%s\n", __func__);
	dev = fts_touch_dev_get(i);
	if (!dev) {
		pr_err("%s cant get dev\n", __func__);
		return -ENOMEM;
	}
	touch_pdata = dev_get_drvdata(dev->dev);

	file->private_data = touch_pdata;
	return 0;
}

static ssize_t fts_touch_dev_read(struct file *file, char __user *buf,
		size_t count, loff_t *pos)
{
	return 0;
}

static ssize_t fts_touch_dev_write(struct file *file,
		const char __user *buf, size_t count, loff_t *pos)
{
	return 0;
}

static unsigned int fts_touch_dev_poll(struct file *file,
		poll_table *wait)
{
	return 0;
}

static long fts_touch_dev_ioctl(struct file *file, unsigned int cmd,
		unsigned long arg)
{
	int ret = -EINVAL;
	int buf[VALUE_TYPE_SIZE] = {0,};
	struct fts_touch_pdata *pdata = file->private_data;
	void __user *argp = (void __user *) arg;
	struct fts_touch_interface *touch_data = pdata->touch_data;
	struct fts_touch *dev = pdata->device;
	int user_cmd = _IOC_NR(cmd);

	if (!pdata || !touch_data || !dev) {
		pr_err("%s invalid memory\n", __func__);
		return -ENOMEM;
	}

	mutex_lock(&dev->mutex);
	ret = copy_from_user(&buf, (int __user *)argp, sizeof(buf));

	pr_info("%s cmd:%d, mode:%d, value:%d\n", __func__, user_cmd, buf[0], buf[1]);

	switch (user_cmd) {
	case SET_CUR_VALUE:
		if (touch_data->setModeValue)
			buf[0] = touch_data->setModeValue(buf[0], buf[1]);
		break;
	case GET_CUR_VALUE:
	case GET_DEF_VALUE:
	case GET_MIN_VALUE:
	case GET_MAX_VALUE:
		if (touch_data->getModeValue)
			buf[0] = touch_data->getModeValue(buf[0], user_cmd);
		break;
	case RESET_MODE:
		if (touch_data->resetMode)
			buf[0] = touch_data->resetMode(buf[0]);
		break;
	case GET_MODE_VALUE:
		if (touch_data->getModeValue)
			ret = touch_data->getModeAll(buf[0], buf);
		break;
	default:
		pr_err("%s don't support mode\n", __func__);
		ret = -EINVAL;
		break;
	}

	if (ret >= 0)
		ret = copy_to_user((int __user *)argp, &buf, sizeof(buf));
	else
		pr_err("%s can't get data from touch driver\n", __func__);

	mutex_unlock(&dev->mutex);

	return ret;
}

static int fts_touch_dev_release(struct inode *inode, struct file *file)
{
	return 0;
}

static const struct file_operations ftstouch_dev_fops = {
	.owner = THIS_MODULE,
	.open = fts_touch_dev_open,
	.read = fts_touch_dev_read,
	.write = fts_touch_dev_write,
	.poll = fts_touch_dev_poll,
	.unlocked_ioctl = fts_touch_dev_ioctl,
	.compat_ioctl = fts_touch_dev_ioctl,
	.release = fts_touch_dev_release,
	.llseek	= no_llseek,
};

static struct fts_touch fts_touch_dev = {
	.misc_dev = {
		.minor = MISC_DYNAMIC_MINOR,
		.name = "fts-touch",
		.fops = &ftstouch_dev_fops,
		.parent = NULL,
	},
	.mutex = __MUTEX_INITIALIZER(fts_touch_dev.mutex),
	.palm_mutex = __MUTEX_INITIALIZER(fts_touch_dev.palm_mutex),
	.psensor_mutex = __MUTEX_INITIALIZER(fts_touch_dev.psensor_mutex),
	.wait_queue = __WAIT_QUEUE_HEAD_INITIALIZER(fts_touch_dev.wait_queue),
};

struct fts_touch *fts_touch_dev_get(int minor)
{
	if (fts_touch_dev.misc_dev.minor == minor)
		return &fts_touch_dev;
	else
		return NULL;
}

struct class *get_fts_touch_class()
{
	return fts_touch_dev.class;
}

struct device *get_fts_touch_dev()
{
	return fts_touch_dev.dev;
}

int ftstouch_register_modedata(struct fts_touch_interface *data)
{
	int ret = 0;
	struct fts_touch_interface *touch_data = NULL;

	if (!touch_pdata)
		ret = -ENOMEM;

	touch_data = touch_pdata->touch_data;
	pr_info("%s\n", __func__);

	mutex_lock(&fts_touch_dev.mutex);

	touch_data->setModeValue = data->setModeValue;
	touch_data->getModeValue = data->getModeValue;
	touch_data->resetMode = data->resetMode;
	touch_data->getModeAll = data->getModeAll;
	touch_data->palm_sensor_read = data->palm_sensor_read;
	touch_data->palm_sensor_write = data->palm_sensor_write;
	touch_data->p_sensor_read = data->p_sensor_read;
	touch_data->p_sensor_write = data->p_sensor_write;

	mutex_unlock(&fts_touch_dev.mutex);

	return ret;
}

int update_palm_sensor_value(int value)
{
	struct fts_touch *dev = NULL;

	mutex_lock(&fts_touch_dev.palm_mutex);

	if (!touch_pdata) {
		mutex_unlock(&fts_touch_dev.palm_mutex);
		return -ENODEV;
	}

	dev = touch_pdata->device;

	if (value != touch_pdata->palm_value) {
		pr_info("%s value:%d\n", __func__, value);
		touch_pdata->palm_value = value;
		touch_pdata->palm_changed = true;
		wake_up(&dev->wait_queue);
	}

	mutex_unlock(&fts_touch_dev.palm_mutex);
	return 0;
}

int update_p_sensor_value(int value)
{
	struct fts_touch *dev = NULL;

	mutex_lock(&fts_touch_dev.psensor_mutex);

	if (!touch_pdata) {
		mutex_unlock(&fts_touch_dev.psensor_mutex);
		return -ENODEV;
	}

	dev = touch_pdata->device;

	if (value != touch_pdata->psensor_value) {
		pr_info("%s value:%d\n", __func__, value);
		touch_pdata->psensor_value = value;
		touch_pdata->psensor_changed = true;
		wake_up(&dev->wait_queue);
	}

	mutex_unlock(&fts_touch_dev.psensor_mutex);
	return 0;
}