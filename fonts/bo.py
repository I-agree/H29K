import requests
import json
import os
import ctypes
import ctypes.util
import struct
import mmap
import fcntl
import threading
import time
from datetime import datetime, timedelta
from io import BytesIO
from PIL import Image, ImageDraw, ImageFont

# ===================== 基础配置 =====================
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

TMP_BG_FILE = "/tmp/bg_raw.jpg"
TMP_CUR_TEXT = "/tmp/sentence_current.txt"
TMP_NEXT_TEXT = "/tmp/sentence_next.txt"
TMP_LAST_REFRESH_TS = "/tmp/last_update_timestamp.txt"

DRM_DEVICE = "/dev/dri/card1"
BPP = 32

preload_next_sentence = None
preload_next_bg_bytes = None
network_available = False
lock = threading.Lock()

# ===================== DRM 常量 =====================
# ioctl 编号 (AArch64)
_IOC_NRBITS = 8
_IOC_TYPEBITS = 8
_IOC_SIZEBITS = 14
_IOC_DIRBITS = 2
_IOC_NRSHIFT = 0
_IOC_TYPESHIFT = _IOC_NRSHIFT + _IOC_NRBITS
_IOC_SIZESHIFT = _IOC_TYPESHIFT + _IOC_TYPEBITS
_IOC_DIRSHIFT = _IOC_SIZESHIFT + _IOC_SIZEBITS
_IOC_WRITE = 1
_IOC_READ = 2

def _IOC(dir, type, nr, size):
    return (dir << _IOC_DIRSHIFT) | (type << _IOC_TYPESHIFT) | (nr << _IOC_NRSHIFT) | (size << _IOC_SIZESHIFT)

def _IOWR(type, nr, size):
    return _IOC(_IOC_READ | _IOC_WRITE, type, nr, size)

def _IOW(type, nr, size):
    return _IOC(_IOC_WRITE, type, nr, size)

def _IOR(type, nr, size):
    return _IOC(_IOC_READ, type, nr, size)

DRM_IOCTL_BASE = ord('d')

class drm_mode_card_res(ctypes.Structure):
    _fields_ = [
        ("fb_id_ptr", ctypes.c_uint64),
        ("count_fbs", ctypes.c_uint32),
        ("crtc_id_ptr", ctypes.c_uint64),
        ("count_crtcs", ctypes.c_uint32),
        ("connector_id_ptr", ctypes.c_uint64),
        ("count_connectors", ctypes.c_uint32),
        ("encoder_id_ptr", ctypes.c_uint64),
        ("count_encoders", ctypes.c_uint32),
        ("min_width", ctypes.c_uint32),
        ("max_width", ctypes.c_uint32),
        ("min_height", ctypes.c_uint32),
        ("max_height", ctypes.c_uint32),
    ]

class drm_mode_crtc(ctypes.Structure):
    _fields_ = [
        ("set_connectors_ptr", ctypes.c_uint64),
        ("count_connectors", ctypes.c_uint32),
        ("crtc_id", ctypes.c_uint32),
        ("fb_id", ctypes.c_uint32),
        ("x", ctypes.c_uint32),
        ("y", ctypes.c_uint32),
        ("gamma_size", ctypes.c_uint32),
        ("mode_valid", ctypes.c_uint32),
        # drm_mode_modeinfo inline (32 bytes on 64-bit... actually 68 bytes)
        ("clock", ctypes.c_uint32),
        ("hdisplay", ctypes.c_uint16),
        ("hsync_start", ctypes.c_uint16),
        ("hsync_end", ctypes.c_uint16),
        ("htotal", ctypes.c_uint16),
        ("hskew", ctypes.c_uint16),
        ("vdisplay", ctypes.c_uint16),
        ("vsync_start", ctypes.c_uint16),
        ("vsync_end", ctypes.c_uint16),
        ("vtotal", ctypes.c_uint16),
        ("vscan", ctypes.c_uint16),
        ("vrefresh", ctypes.c_uint32),
        ("flags", ctypes.c_uint32),
        ("type", ctypes.c_uint32),
        ("name", ctypes.c_char * 32),
    ]

class drm_mode_get_connector(ctypes.Structure):
    _fields_ = [
        ("encoders_ptr", ctypes.c_uint64),
        ("modes_ptr", ctypes.c_uint64),
        ("props_ptr", ctypes.c_uint64),
        ("prop_values_ptr", ctypes.c_uint64),
        ("count_modes", ctypes.c_uint32),
        ("count_props", ctypes.c_uint32),
        ("count_encoders", ctypes.c_uint32),
        ("encoder_id", ctypes.c_uint32),
        ("connector_id", ctypes.c_uint32),
        ("connector_type", ctypes.c_uint32),
        ("connector_type_id", ctypes.c_uint32),
        ("connection", ctypes.c_uint32),
        ("mm_width", ctypes.c_uint32),
        ("mm_height", ctypes.c_uint32),
        ("subpixel", ctypes.c_uint32),
        ("pad", ctypes.c_uint32),
    ]

class drm_mode_get_encoder(ctypes.Structure):
    _fields_ = [
        ("encoder_id", ctypes.c_uint32),
        ("encoder_type", ctypes.c_uint32),
        ("crtc_id", ctypes.c_uint32),
        ("possible_crtcs", ctypes.c_uint32),
        ("possible_clones", ctypes.c_uint32),
    ]

class drm_mode_create_dumb(ctypes.Structure):
    _fields_ = [
        ("height", ctypes.c_uint32),
        ("width", ctypes.c_uint32),
        ("bpp", ctypes.c_uint32),
        ("flags", ctypes.c_uint32),
        ("handle", ctypes.c_uint32),
        ("pitch", ctypes.c_uint32),
        ("size", ctypes.c_uint64),
    ]

class drm_mode_map_dumb(ctypes.Structure):
    _fields_ = [
        ("handle", ctypes.c_uint32),
        ("pad", ctypes.c_uint32),
        ("offset", ctypes.c_uint64),
    ]

class drm_mode_destroy_dumb(ctypes.Structure):
    _fields_ = [
        ("handle", ctypes.c_uint32),
    ]

class drm_mode_fb_cmd2(ctypes.Structure):
    _fields_ = [
        ("fb_id", ctypes.c_uint32),
        ("width", ctypes.c_uint32),
        ("height", ctypes.c_uint32),
        ("pixel_format", ctypes.c_uint32),
        ("flags", ctypes.c_uint32),
        ("handles", ctypes.c_uint32 * 4),
        ("pitches", ctypes.c_uint32 * 4),
        ("offsets", ctypes.c_uint32 * 4),
        ("modifier", ctypes.c_uint64 * 4),
    ]

# drm_mode_modeinfo size = 68 bytes
MODEINFO_SIZE = ctypes.sizeof(ctypes.c_uint32) + ctypes.sizeof(ctypes.c_uint16)*10 + \
                ctypes.sizeof(ctypes.c_uint32)*3 + 32

DRM_IOCTL_MODE_GETRESOURCES = _IOWR(DRM_IOCTL_BASE, 0xA0, ctypes.sizeof(drm_mode_card_res))
DRM_IOCTL_MODE_GETCONNECTOR = _IOWR(DRM_IOCTL_BASE, 0xA7, ctypes.sizeof(drm_mode_get_connector))
DRM_IOCTL_MODE_GETENCODER = _IOWR(DRM_IOCTL_BASE, 0xA6, ctypes.sizeof(drm_mode_get_encoder))
DRM_IOCTL_MODE_GETCRTC = _IOWR(DRM_IOCTL_BASE, 0xA1, ctypes.sizeof(drm_mode_crtc))
DRM_IOCTL_MODE_SETCRTC = _IOWR(DRM_IOCTL_BASE, 0xA2, ctypes.sizeof(drm_mode_crtc))
DRM_IOCTL_MODE_CREATE_DUMB = _IOWR(DRM_IOCTL_BASE, 0xB2, ctypes.sizeof(drm_mode_create_dumb))
DRM_IOCTL_MODE_MAP_DUMB = _IOWR(DRM_IOCTL_BASE, 0xB3, ctypes.sizeof(drm_mode_map_dumb))
DRM_IOCTL_MODE_DESTROY_DUMB = _IOW(DRM_IOCTL_BASE, 0xB4, ctypes.sizeof(drm_mode_destroy_dumb))
DRM_IOCTL_MODE_ADDFB2 = _IOWR(DRM_IOCTL_BASE, 0xB8, ctypes.sizeof(drm_mode_fb_cmd2))
DRM_IOCTL_MODE_RMFB = _IOWR(DRM_IOCTL_BASE, 0xAF, ctypes.sizeof(ctypes.c_uint32))
DRM_IOCTL_GEM_CLOSE = _IOW(DRM_IOCTL_BASE, 0x09, ctypes.sizeof(ctypes.c_uint32))

# DRM_FORMAT_XRGB8888 = fourcc_code('X','R','2','4')
DRM_FORMAT_XRGB8888 = (ord('X')) | (ord('R') << 8) | (ord('2') << 16) | (ord('4') << 24)

DRM_MODE_CONNECTED = 1

# ===================== DRM 显示类 =====================
class DRMDisplay:
    def __init__(self, device=DRM_DEVICE):
        self.fd = -1
        self.crtc_id = 0
        self.connector_id = 0
        self.conn_modes_buf = None  # 保存 modeinfo 用于 SetCrtc
        self.screen_w = 0
        self.screen_h = 0
        self.dumb = [None, None]
        self.fb_id = [0, 0]
        self.mm = [None, None]
        self.pitch = 0
        self.buf_size = 0
        self.cur = 0
        self._init_drm(device)

    def _init_drm(self, device):
        self.fd = os.open(device, os.O_RDWR | os.O_CLOEXEC)

        # 获取资源
        res = drm_mode_card_res()
        fcntl.ioctl(self.fd, DRM_IOCTL_MODE_GETRESOURCES, res)

        # 获取 connector 列表
        conn_ids = (ctypes.c_uint32 * res.count_connectors)()
        res.connector_id_ptr = ctypes.addressof(conn_ids)
        res.count_connectors = res.count_connectors
        fcntl.ioctl(self.fd, DRM_IOCTL_MODE_GETRESOURCES, res)

        # 找第一个已连接的 connector
        for i in range(res.count_connectors):
            conn = drm_mode_get_connector()
            conn.connector_id = conn_ids[i]
            fcntl.ioctl(self.fd, DRM_IOCTL_MODE_GETCONNECTOR, conn)

            if conn.count_modes > 0 and conn.connection == DRM_MODE_CONNECTED:
                # 读取 modes
                modes_buf = (ctypes.c_char * (68 * conn.count_modes))()
                conn.modes_ptr = ctypes.addressof(modes_buf)
                fcntl.ioctl(self.fd, DRM_IOCTL_MODE_GETCONNECTOR, conn)

                self.connector_id = conn.connector_id
                self.conn_modes_buf = modes_buf  # 保存完整 modes 数据
                self.screen_w = struct.unpack_from('<H', modes_buf, 4)[0]   # hdisplay offset
                self.screen_h = struct.unpack_from('<H', modes_buf, 14)[0]  # vdisplay offset
                break

        if not self.connector_id:
            raise RuntimeError("No connected DRM connector found")

        # 找 CRTC
        crtc_id = 0
        if conn.encoder_id:
            enc = drm_mode_get_encoder()
            enc.encoder_id = conn.encoder_id
            fcntl.ioctl(self.fd, DRM_IOCTL_MODE_GETENCODER, enc)
            crtc_id = enc.crtc_id

        if not crtc_id:
            # 取第一个 CRTC
            crtc_ids = (ctypes.c_uint32 * res.count_crtcs)()
            res.crtc_id_ptr = ctypes.addressof(crtc_ids)
            fcntl.ioctl(self.fd, DRM_IOCTL_MODE_GETRESOURCES, res)
            if res.count_crtcs > 0:
                crtc_id = crtc_ids[0]

        if not crtc_id:
            raise RuntimeError("No CRTC found")

        self.crtc_id = crtc_id

        # 创建 dumb buffers
        for i in range(2):
            d = drm_mode_create_dumb()
            d.width = self.screen_w
            d.height = self.screen_h
            d.bpp = BPP
            fcntl.ioctl(self.fd, DRM_IOCTL_MODE_CREATE_DUMB, d)
            self.dumb[i] = d

            # 创建 framebuffer
            fb = drm_mode_fb_cmd2()
            fb.width = self.screen_w
            fb.height = self.screen_h
            fb.pixel_format = DRM_FORMAT_XRGB8888
            fb.handles[0] = d.handle
            fb.pitches[0] = d.pitch
            fcntl.ioctl(self.fd, DRM_IOCTL_MODE_ADDFB2, fb)
            self.fb_id[i] = fb.fb_id

            # mmap
            mp = drm_mode_map_dumb()
            mp.handle = d.handle
            fcntl.ioctl(self.fd, DRM_IOCTL_MODE_MAP_DUMB, mp)

            self.mm[i] = mmap.mmap(self.fd, d.size, offset=mp.offset)

        self.pitch = self.dumb[0].pitch
        self.buf_size = self.dumb[0].size

    def display_image(self, img):
        """将 PIL Image (RGB) 显示到 DRM 屏幕"""
        if img.size != (self.screen_w, self.screen_h):
            img = img.resize((self.screen_w, self.screen_h), Image.Resampling.LANCZOS)

        # 转为 XRGB8888: PIL 没有 XRGB，用 BGRX 然后调整
        # 实际上 XRGB8888 在内存中是: B G R X (little-endian)
        # PIL 的 RGB 转成 XRGB8888 需要: B, G, R, 0xFF
        img_rgb = img.convert("RGB")
        raw = img_rgb.tobytes()

        buf = self.mm[self.cur]

        # 逐行写入，处理 pitch 对齐
        row_bytes = self.screen_w * 4
        for y in range(self.screen_h):
            src_offset = y * self.screen_w * 3
            dst_offset = y * self.pitch
            for x in range(self.screen_w):
                r = raw[src_offset + x * 3]
                g = raw[src_offset + x * 3 + 1]
                b = raw[src_offset + x * 3 + 2]
                # XRGB8888 little-endian: B G R X
                pixel = struct.pack('BBBB', b, g, r, 0xFF)
                buf[dst_offset + x * 4: dst_offset + x * 4 + 4] = pixel

        # 用 modes_buf 设置 CRTC (包含 modeinfo)
        # 构造 drm_mode_crtc 结构
        crtc_data = bytearray(ctypes.sizeof(drm_mode_crtc))
        # 设置 fb_id
        struct.pack_into('<I', crtc_data, 16, self.fb_id[self.cur])  # fb_id offset
        # 复制 modeinfo (从 offset 28 开始，32 bytes 的 modeinfo)
        mode_offset = 28  # offset of modeinfo within drm_mode_crtc
        crtc_data[mode_offset:mode_offset + 68] = self.conn_modes_buf[:68]

        fcntl.ioctl(self.fd, DRM_IOCTL_MODE_SETCRTC, bytes(crtc_data))

        self.cur = 1 - self.cur

    def clear(self):
        """清屏"""
        for i in range(2):
            self.mm[i][:] = b'\x00' * self.buf_size

    def close(self):
        """释放资源"""
        for i in range(2):
            if self.mm[i]:
                self.mm[i].close()
            if self.fb_id[i]:
                fb_id_buf = struct.pack('<I', self.fb_id[i])
                fcntl.ioctl(self.fd, DRM_IOCTL_MODE_RMFB, fb_id_buf)
            if self.dumb[i]:
                dd = drm_mode_destroy_dumb()
                dd.handle = self.dumb[i].handle
                fcntl.ioctl(self.fd, DRM_IOCTL_MODE_DESTROY_DUMB, dd)
        if self.fd >= 0:
            os.close(self.fd)

# ===================== 高速像素写入 =====================
def fast_image_to_xrgb8888(img, screen_w, screen_h):
    """将 PIL Image 快速转为 XRGB8888 bytes (BGRX 内存序)"""
    # 用 numpy 加速如果可用，否则用纯 Python
    try:
        import numpy as np
        arr = np.array(img.convert("RGB").resize((screen_w, screen_h), Image.Resampling.LANCZOS))
        # arr shape: (H, W, 3) RGB
        # 目标: BGRX
        bgrx = np.zeros((screen_h, screen_w, 4), dtype=np.uint8)
        bgrx[:, :, 0] = arr[:, :, 2]  # B
        bgrx[:, :, 1] = arr[:, :, 1]  # G
        bgrx[:, :, 2] = arr[:, :, 0]  # R
        bgrx[:, :, 3] = 0xFF           # X
        return bgrx.tobytes()
    except ImportError:
        img_rgb = img.convert("RGB").resize((screen_w, screen_h), Image.Resampling.LANCZOS)
        raw = img_rgb.tobytes()
        out = bytearray(screen_w * screen_h * 4)
        for i in range(screen_w * screen_h):
            out[i * 4] = raw[i * 3 + 2]      # B
            out[i * 4 + 1] = raw[i * 3 + 1]  # G
            out[i * 4 + 2] = raw[i * 3]      # R
            out[i * 4 + 3] = 0xFF             # X
        return bytes(out)

# ===================== 内存文件工具 =====================
def ram_text_read(path):
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                return f.read().strip()
        except Exception:
            pass
    return None

def ram_text_write(path, content):
    try:
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
    except Exception:
        pass

def ram_bin_write(path, data):
    try:
        with open(path, "wb") as f:
            f.write(data)
    except Exception:
        pass

# ===================== 网络检测 =====================
def network_monitor():
    global network_available
    while True:
        try:
            resp = requests.get(TEST_NET_URL, timeout=3)
            if resp.status_code == 200:
                if not network_available:
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
        sentence = f"{hitokoto}\n\n——{src}"
        with lock:
            preload_next_sentence = sentence
        ram_text_write(TMP_NEXT_TEXT, sentence)
    except Exception:
        with lock:
            preload_next_sentence = FALLBACK_TEXT

def thread_preload_background():
    global preload_next_bg_bytes
    try:
        resp = requests.get(PICSUM_RAW_URL, timeout=REQUEST_TIMEOUT)
        resp.raise_for_status()
        with lock:
            preload_next_bg_bytes = resp.content
        ram_bin_write(TMP_BG_FILE, preload_next_bg_bytes)
    except Exception:
        with lock:
            preload_next_bg_bytes = None

# ===================== 获取背景 =====================
def get_background_canvas():
    last_ts_str = ram_text_read(TMP_LAST_REFRESH_TS)
    need_new_bg = True
    if last_ts_str:
        try:
            last_update = datetime.fromtimestamp(float(last_ts_str))
            if (datetime.now() - last_update) < REFRESH_CYCLE:
                need_new_bg = False
        except Exception:
            pass

    if not need_new_bg and os.path.exists(TMP_BG_FILE):
        try:
            return Image.open(TMP_BG_FILE).convert("RGB")
        except Exception:
            pass

    with lock:
        bg_bytes = preload_next_bg_bytes

    if bg_bytes:
        try:
            img = Image.open(BytesIO(bg_bytes)).convert("RGB")
            ram_bin_write(TMP_BG_FILE, bg_bytes)
            return img
        except Exception:
            pass

    return Image.new("RGB", (SCREEN_W, SCREEN_H), BG_COLOR_BLACK)

# ===================== 获取文字 =====================
def get_display_text():
    last_ts_str = ram_text_read(TMP_LAST_REFRESH_TS)
    need_refresh = True
    if last_ts_str:
        try:
            last_update = datetime.fromtimestamp(float(last_ts_str))
            if (datetime.now() - last_update) < REFRESH_CYCLE:
                need_refresh = False
        except Exception:
            pass

    cur_text = ram_text_read(TMP_CUR_TEXT)
    if cur_text and not need_refresh:
        return cur_text

    with lock:
        new_text = preload_next_sentence if preload_next_sentence else FALLBACK_TEXT

    ram_text_write(TMP_CUR_TEXT, new_text)
    ram_text_write(TMP_LAST_REFRESH_TS, str(datetime.now().timestamp()))

    threading.Thread(target=thread_preload_sentence, daemon=True).start()
    threading.Thread(target=thread_preload_background, daemon=True).start()
    return new_text

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
    # 初始化 DRM
    display = DRMDisplay(DRM_DEVICE)

    # 启动后台线程
    threading.Thread(target=network_monitor, daemon=True).start()
    threading.Thread(target=thread_preload_sentence, daemon=True).start()
    threading.Thread(target=thread_preload_background, daemon=True).start()

    # 等待预加载
    time.sleep(5)

    while True:
        try:
            bg_canvas = get_background_canvas()
            show_text = get_display_text()
            final_img = draw_center_text(bg_canvas, show_text)

            # 高速转像素并显示
            xrgb_data = fast_image_to_xrgb8888(final_img, display.screen_w, display.screen_h)

            buf = display.mm[display.cur]
            # 快速写入整个 buffer（如果 pitch == screen_w * 4）
            if display.pitch == display.screen_w * 4:
                buf[:len(xrgb_data)] = xrgb_data
            else:
                # pitch 不对齐时逐行写
                row_bytes = display.screen_w * 4
                for y in range(display.screen_h):
                    src = y * row_bytes
                    dst = y * display.pitch
                    buf[dst:dst + row_bytes] = xrgb_data[src:src + row_bytes]

            # SetCrtc
            crtc_data = bytearray(ctypes.sizeof(drm_mode_crtc))
            struct.pack_into('<I', crtc_data, 16, display.fb_id[display.cur])
            crtc_data[28:28 + 68] = display.conn_modes_buf[:68]
            fcntl.ioctl(display.fd, DRM_IOCTL_MODE_SETCRTC, bytes(crtc_data))

            display.cur = 1 - display.cur

        except Exception:
            pass

        time.sleep(REFRESH_CYCLE.total_seconds())

if __name__ == "__main__":
    main_loop()
