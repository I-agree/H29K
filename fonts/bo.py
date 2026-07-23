import requests
import json
import os
import threading
import time
from datetime import datetime, timedelta
from io import BytesIO
from PIL import Image, ImageDraw, ImageFont

# ===================== 基础配置 =====================
SCREEN_W = 172
SCREEN_H = 320
PICSUM_RAW_URL = "https://picsum.photos/320/172"
FONT_PATH = "/usr/share/fonts/MiSans-Regular.ttf"
FONT_SIZE = 13
BG_COLOR_BLACK = (0, 0, 0)
TEXT_COLOR = (255, 255, 255)
REQUEST_TIMEOUT = 4
REFRESH_CYCLE = timedelta(minutes=15)
NETWORK_CHECK_INTERVAL = 900  # 15分钟 = 900秒，降低探测频率

HITOKOTO_URL = "https://v1.hitokoto.cn/?c=f&max_length=60"
TEST_NET_URL = "https://www.baidu.com"  # 网络连通性测试地址

# 断网兜底文案
FALLBACK_TEXT = """山林不向四季起誓，荣枯随缘；
海洋不需对沙滩承诺，遇合尽兴。
喜欢就处，别问是朋友还是恋人！
关系不是绳子，非要绑住谁的手脚；
缘分就像山风，吹到哪儿都是风景。
能走一段是礼物，能走一生是运气。
被你改变的那一部分我，代替了你永远陪在了我的身边。"""

# 内存tmpfs缓存，无EMMC写入
TMP_BG_FILE = "/tmp/bg_raw.jpg"
TMP_CUR_TEXT = "/tmp/sentence_current.txt"
TMP_NEXT_TEXT = "/tmp/sentence_next.txt"
TMP_LAST_REFRESH_TS = "/tmp/last_update_timestamp.txt"
OUTPUT_SCREEN_IMG = "/tmp/screen_out.jpg"

# 全局预缓存
preload_next_sentence = None
preload_next_bg_bytes = None
network_available = True  # 网络状态标记

# ===================== 内存文件工具 =====================
def ram_text_read(path: str):
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            return f.read().strip()
    return None

def ram_text_write(path: str, content: str):
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

def ram_bin_write(path: str, binary_data: bytes):
    with open(path, "wb") as f:
        f.write(binary_data)

# ===================== 网络检测线程（15分钟探测一次） =====================
def network_monitor():
    global network_available
    while True:
        try:
            resp = requests.get(TEST_NET_URL, timeout=3)
            if resp.status_code == 200:
                if not network_available:
                    # 断网恢复，立刻预加载新背景、句子
                    threading.Thread(target=thread_preload_sentence, daemon=True).start()
                    threading.Thread(target=thread_preload_background, daemon=True).start()
                network_available = True
            else:
                network_available = False
        except Exception:
            network_available = False
        time.sleep(NETWORK_CHECK_INTERVAL)

# ===================== 素材预加载 =====================
def thread_preload_sentence():
    global preload_next_sentence
    try:
        resp = requests.get(HITOKOTO_URL, timeout=REQUEST_TIMEOUT)
        resp.raise_for_status()
        data = resp.json()
        hitokoto = data.get("hitokoto", "")
        src = data.get("from", "")
        preload_next_sentence = f"{hitokoto}\n\n——{src}"
        ram_text_write(TMP_NEXT_TEXT, preload_next_sentence)
    except Exception:
        preload_next_sentence = FALLBACK_TEXT

def thread_preload_background():
    global preload_next_bg_bytes
    try:
        resp = requests.get(PICSUM_RAW_URL, timeout=REQUEST_TIMEOUT)
        resp.raise_for_status()
        preload_next_bg_bytes = resp.content
        ram_bin_write(TMP_BG_FILE, preload_next_bg_bytes)
    except Exception:
        preload_next_bg_bytes = None

# ===================== 获取背景画布 =====================
def get_background_canvas() -> Image.Image:
    last_ts_str = ram_text_read(TMP_LAST_REFRESH_TS)
    need_new_bg = True
    if last_ts_str:
        try:
            last_update = datetime.fromtimestamp(float(last_ts_str))
            if (datetime.now() - last_update) < REFRESH_CYCLE and network_available:
                need_new_bg = False
        except Exception:
            pass

    if not need_new_bg and os.path.exists(TMP_BG_FILE):
        try:
            return Image.open(TMP_BG_FILE)
        except Exception:
            pass

    if preload_next_bg_bytes:
        img = Image.open(BytesIO(preload_next_bg_bytes))
        ram_bin_write(TMP_BG_FILE, preload_next_bg_bytes)
        return img

    return Image.new("RGB", (SCREEN_W, SCREEN_H), BG_COLOR_BLACK)

# ===================== 获取显示文字 =====================
def get_display_text() -> str:
    last_ts_str = ram_text_read(TMP_LAST_REFRESH_TS)
    need_refresh = True
    if last_ts_str:
        try:
            last_update = datetime.fromtimestamp(float(last_ts_str))
            if (datetime.now() - last_update) < REFRESH_CYCLE and network_available:
                need_refresh = False
        except Exception:
            pass

    cur_text = ram_text_read(TMP_CUR_TEXT)
    if cur_text and not need_refresh:
        return cur_text

    new_text = preload_next_sentence if preload_next_sentence else FALLBACK_TEXT
    ram_text_write(TMP_CUR_TEXT, new_text)
    ram_text_write(TMP_LAST_REFRESH_TS, str(datetime.now().timestamp()))

    threading.Thread(target=thread_preload_sentence, daemon=True).start()
    threading.Thread(target=thread_preload_background, daemon=True).start()
    return new_text

# ===================== 居中文字绘制 =====================
def draw_center_text(bg: Image.Image, text: str) -> Image.Image:
    draw = ImageDraw.Draw(bg)
    try:
        font = ImageFont.truetype(FONT_PATH, FONT_SIZE)
    except Exception:
        font = ImageFont.load_default()

    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    x_pos = (SCREEN_W - text_w) // 2
    y_pos = (SCREEN_H - text_h) // 2
    draw.text((x_pos, y_pos), text, font=font, fill=TEXT_COLOR)
    return bg

# ===================== 主渲染 =====================
def generate_screen_image():
    # 启动网络监控后台线程（15分钟探测一次）
    threading.Thread(target=network_monitor, daemon=True).start()
    # 初始预加载素材
    threading.Thread(target=thread_preload_sentence, daemon=True).start()
    threading.Thread(target=thread_preload_background, daemon=True).start()

    bg_canvas = get_background_canvas()
    show_text = get_display_text()
    final_img = draw_center_text(bg_canvas, show_text)
    final_img.save(OUTPUT_SCREEN_IMG)

if __name__ == "__main__":
    generate_screen_image()
