#!/usr/bin/env python3
"""bo.py - 一言 + 随机背景，通过管道调用 drm_show_arm64 显示，零 eMMC 写入"""

import requests
import os
import subprocess
import threading
import time
from datetime import datetime, timedelta
from io import BytesIO
from PIL import Image, ImageDraw, ImageFont

try:
    import numpy as np
    HAS_NUMPY = True
except ImportError:
    HAS_NUMPY = False

# ===================== 配置 =====================
SCREEN_W = 320
SCREEN_H = 172
PICSUM_RAW_URL = "https://picsum.photos/320/172"
FONT_PATH = "/usr/share/fonts/MiSans-Regular.ttf"
FONT_SIZE = 13
BG_COLOR_BLACK = (0, 0, 0)
TEXT_COLOR = (255, 255, 255)
REQUEST_TIMEOUT = 4
REFRESH_CYCLE = timedelta(minutes=15)
NETWORK_CHECK_INTERVAL = 60

HITOKOTO_URL = "https://v1.hitokoto.cn/?c=f&max_length=60"
TEST_NET_URL = "https://www.baidu.com"

FALLBACK_TEXT = """山林不向四季起誓，荣枯随缘；
海洋不需对沙滩承诺，遇合尽兴。
喜欢就处，别问是朋友还是恋人！
关系不是绳子，非要绑住谁的手脚；
缘分就像山风，吹到哪儿都是风景。
能走一段是礼物，能走一生是运气。
被你改变的那一部分我，代替了你永远陪在了我的身边。"""

DRM_DEVICE = "/dev/dri/card1"
DRM_SHOW = "/usr/sbin/drm_show_arm64"

# ===================== 内存缓存（全部在 RAM 中） =====================
_cache = {
    "bg_bytes": None,          # 背景图片原始数据 (JPEG bytes)
    "bg_image": None,          # 背景 PIL Image
    "current_text": None,      # 当前显示文字
    "next_text": None,         # 预加载的下一句
    "next_bg_bytes": None,     # 预加载的下一张背景
    "last_refresh": None,      # 上次刷新时间 (datetime)
    "network_available": False,
}
_lock = threading.Lock()


# ===================== 显示函数（管道模式，零文件 I/O） =====================
def display_image(img):
    """将 PIL Image 转为 XRGB8888 并通过管道传给 drm_show_arm64"""
    if img.size != (SCREEN_W, SCREEN_H):
        img = img.resize((SCREEN_W, SCREEN_H), Image.Resampling.LANCZOS)

    # 转为 XRGB8888 (内存序 BGRX)
    if HAS_NUMPY:
        arr = np.array(img.convert("RGB"))
        bgrx = np.zeros((SCREEN_H, SCREEN_W, 4), dtype=np.uint8)
        bgrx[:, :, 0] = arr[:, :, 2]  # B
        bgrx[:, :, 1] = arr[:, :, 1]  # G
        bgrx[:, :, 2] = arr[:, :, 0]  # R
        bgrx[:, :, 3] = 0xFF           # X
        raw_data = bgrx.tobytes()
    else:
        img_rgb = img.convert("RGB")
        raw = img_rgb.tobytes()
        out = bytearray(SCREEN_W * SCREEN_H * 4)
        for i in range(SCREEN_W * SCREEN_H):
            out[i*4]   = raw[i*3+2]
            out[i*4+1] = raw[i*3+1]
            out[i*4+2] = raw[i*3]
            out[i*4+3] = 0xFF
        raw_data = bytes(out)

    # 通过 stdin 管道传给 C 程序，不写任何文件
    subprocess.run(
        [DRM_SHOW, DRM_DEVICE, "-", str(SCREEN_W), str(SCREEN_H)],
        input=raw_data,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=10
    )


# ===================== 网络检测 =====================
def network_monitor():
    while True:
        try:
            resp = requests.get(TEST_NET_URL, timeout=3)
            ok = (resp.status_code == 200)
        except Exception:
            ok = False

        with _lock:
            was_available = _cache["network_available"]
            _cache["network_available"] = ok

        # 网络恢复时触发预加载
        if ok and not was_available:
            threading.Thread(target=preload_sentence, daemon=True).start()
            threading.Thread(target=preload_background, daemon=True).start()

        time.sleep(NETWORK_CHECK_INTERVAL)


# ===================== 素材预加载（全部存内存） =====================
def preload_sentence():
    try:
        resp = requests.get(HITOKOTO_URL, timeout=REQUEST_TIMEOUT)
        resp.raise_for_status()
        data = resp.json()
        hitokoto = data.get("hitokoto", "")
        src = data.get("from", "")
        sentence = f"{hitokoto}\n\n——{src}"
        with _lock:
            _cache["next_text"] = sentence
    except Exception:
        with _lock:
            _cache["next_text"] = FALLBACK_TEXT


def preload_background():
    try:
        resp = requests.get(PICSUM_RAW_URL, timeout=REQUEST_TIMEOUT)
        resp.raise_for_status()
        with _lock:
            _cache["next_bg_bytes"] = resp.content
    except Exception:
        pass


# ===================== 获取背景（内存缓存） =====================
def get_background_canvas():
    with _lock:
        need_refresh = _need_refresh()

        if not need_refresh and _cache["bg_image"] is not None:
            return _cache["bg_image"].copy()

        # 使用预加载的背景
        bg_bytes = _cache["next_bg_bytes"]
        if bg_bytes:
            try:
                img = Image.open(BytesIO(bg_bytes)).convert("RGB")
                _cache["bg_image"] = img
                _cache["bg_bytes"] = bg_bytes
                return img.copy()
            except Exception:
                pass

        # 使用旧背景
        if _cache["bg_image"] is not None:
            return _cache["bg_image"].copy()

    return Image.new("RGB", (SCREEN_W, SCREEN_H), BG_COLOR_BLACK)


# ===================== 获取文字（内存缓存） =====================
def get_display_text():
    with _lock:
        need_refresh = _need_refresh()

        if not need_refresh and _cache["current_text"] is not None:
            return _cache["current_text"]

        # 刷新：使用预加载的文字
        new_text = _cache["next_text"] if _cache["next_text"] else FALLBACK_TEXT
        _cache["current_text"] = new_text
        _cache["last_refresh"] = datetime.now()

    # 触发下一轮预加载
    threading.Thread(target=preload_sentence, daemon=True).start()
    threading.Thread(target=preload_background, daemon=True).start()
    return new_text


def _need_refresh():
    """判断是否需要刷新（调用时必须持有 _lock）"""
    if _cache["last_refresh"] is None:
        return True
    return (datetime.now() - _cache["last_refresh"]) >= REFRESH_CYCLE


# ===================== 居中文字 =====================
def draw_center_text(bg, text):
    draw = ImageDraw.Draw(bg)
    try:
        font = ImageFont.truetype(FONT_PATH, FONT_SIZE)
    except Exception:
        font = ImageFont.load_default()

    lines = text.split('\n')
    line_widths = []
    line_heights = []

    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font)
        line_widths.append(bbox[2] - bbox[0])
        line_heights.append(bbox[3] - bbox[1])

    total_height = sum(line_heights) + (len(lines) - 1) * 4
    y_start = (SCREEN_H - total_height) // 2
    y_pos = y_start

    for i, line in enumerate(lines):
        x_pos = (SCREEN_W - line_widths[i]) // 2
        draw.text((x_pos, y_pos), line, font=font, fill=TEXT_COLOR)
        y_pos += line_heights[i] + 4

    return bg


# ===================== 主循环 =====================
def main_loop():
    threading.Thread(target=network_monitor, daemon=True).start()
    threading.Thread(target=preload_sentence, daemon=True).start()
    threading.Thread(target=preload_background, daemon=True).start()

    time.sleep(5)

    while True:
        try:
            bg_canvas = get_background_canvas()
            show_text = get_display_text()
            final_img = draw_center_text(bg_canvas, show_text)
            display_image(final_img)
        except Exception:
            pass

        time.sleep(REFRESH_CYCLE.total_seconds())


if __name__ == "__main__":
    main_loop()
