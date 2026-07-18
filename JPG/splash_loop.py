from PIL import Image
import os, time

# 屏幕参数
FB_DEV = "/dev/fb0"
SCREEN_W = 172
SCREEN_H = 320
IMG_PATH_DIR = "/usr/share/splash"
DELAY_US = 70000 / 1000  # 转毫秒

def get_all_logo():
    imgs = []
    for f in sorted(os.listdir(IMG_PATH_DIR)):
        if f.startswith("LOGO") and f.endswith(".jpg"):
            imgs.append(os.path.join(IMG_PATH_DIR, f))
    return imgs

def draw_to_fb(img_path):
    # 打开图片、缩放适配屏幕
    img = Image.open(img_path).convert("RGB")
    img = img.resize((SCREEN_W, SCREEN_H))
    # 直接写入帧缓冲
    with open(FB_DEV, "wb") as fb:
        fb.write(img.tobytes())

if __name__ == "__main__":
    img_list = get_all_logo()
    if not img_list:
        exit(1)
    # 无限循环播放开机动画
    while True:
        for pic in img_list:
            draw_to_fb(pic)
            time.sleep(DELAY_US / 1000)
