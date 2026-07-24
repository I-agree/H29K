#!/usr/bin/env python3
"""bo.py - DRM 显示 + 一言 + 随机背景 (Rockchip AArch64, 纯 bytearray ioctl)"""

import requests
import json
import os
import struct
import mmap
import fcntl
import ctypes
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

# ===================== ioctl 编号计算 =====================
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

def _IOC(d, t, n, s):
    return (d << _IOC_DIRSHIFT) | (t << _IOC_TYPESHIFT) | (n << _IOC_NRSHIFT) | (s << _IOC_SIZESHIFT)

def _IOWR(t, n, s):
    return _IOC(_IOC_READ | _IOC_WRITE, t, n, s)

def _IOW(t, n, s):
    return _IOC(_IOC_WRITE, t, n, s)

DRM_BASE = ord('d')

# ===================== 结构体大小（从内核 drm_mode.h 精确计算） =====================
SZ_CARD_RES      = 64   # 4*u64 + 8*u32
SZ_MODEINFO      = 68   # u32 + 10*u16 + 3*u32 + char[32]
SZ_CRTC          = 104  # u64 + 7*u32 + modeinfo(68)
SZ_GET_CONNECTOR = 80   # 4*u64 + 12*u32
SZ_GET_ENCODER   = 20   # 5*u32
SZ_CREATE_DUMB   = 32   # 6*u32 + u64
SZ_MAP_DUMB      = 16   # 2*u32 + u64
SZ_DESTROY_DUMB  = 4    # u32
SZ_FB_CMD2       = 104  # 5*u32 + 3*(4*u32) + 4*u64

# ===================== ioctl 编号 =====================
IOCTL_GETRESOURCES  = _IOWR(DRM_BASE, 0xA0, SZ_CARD_RES)
IOCTL_GETCONNECTOR  = _IOWR(DRM_BASE, 0xA7, SZ_GET_CONNECTOR)
IOCTL_GETENCODER    = _IOWR(DRM_BASE, 0xA6, SZ_GET_ENCODER)
IOCTL_GETCRTC       = _IOWR(DRM_BASE, 0xA1, SZ_CRTC)
IOCTL_SETCRTC       = _IOWR(DRM_BASE, 0xA2, SZ_CRTC)
IOCTL_CREATE_DUMB   = _IOWR(DRM_BASE, 0xB2, SZ_CREATE_DUMB)
IOCTL_MAP_DUMB      = _IOWR(DRM_BASE, 0xB3, SZ_MAP_DUMB)
IOCTL_DESTROY_DUMB  = _IOW(DRM_BASE, 0xB4, SZ_DESTROY_DUMB)
IOCTL_ADDFB2        = _IOWR(DRM_BASE, 0xB8, SZ_FB_CMD2)
IOCTL_RMFB          = _IOWR(DRM_BASE, 0xAF, 4)

DRM_FORMAT_XRGB8888 = ord('X') | (ord('R') << 8) | (ord('2') << 16) | (ord('4') << 24)
DRM_MODE_CONNECTED = 1

# ===================== drm_mode_card_res 字段偏移 =====================
# offset 0:  fb_id_ptr        (u64)
# offset 8:  crtc_id_ptr      (u64)
# offset 16: connector_id_ptr (u64)
# offset 24: encoder_id_ptr   (u64)
# offset 32: count_fbs        (u32)
# offset 36: count_crtcs      (u32)
# offset 40: count_connectors (u32)
# offset 44: count_encoders   (u32)
# offset 48: min_width        (u32)
# offset 52: max_width        (u32)
# offset 56: min_height       (u32)
# offset 60: max_height       (u32)

# ===================== drm_mode_get_connector 字段偏移 =====================
# offset 0:  encoders_ptr      (u64)
# offset 8:  modes_ptr         (u64)
# offset 16: props_ptr         (u64)
# offset 24: prop_values_ptr   (u64)
# offset 32: count_modes       (u32)
# offset 36: count_props       (u32)
# offset 40: count_encoders    (u32)
# offset 44: encoder_id        (u32)
# offset 48: connector_id      (u32)
# offset 52: connector_type    (u32)
# offset 56: connector_type_id (u32)
# offset 60: connection        (u32)
# offset 64: mm_width          (u32)
# offset 68: mm_height         (u32)
# offset 72: subpixel          (u32)
# offset 76: pad               (u32)

# ===================== drm_mode_crtc 字段偏移 =====================
# offset 0:  set_connectors_ptr (u64)
# offset 8:  count_connectors   (u32)
# offset 12: crtc_id            (u32)
# offset 16: fb_id              (u32)
# offset 20: x                  (u32)
# offset 24: y                  (u32)
# offset 28: gamma_size         (u32)
# offset 32: mode_valid         (u32)
# offset 36: mode (modeinfo)    (68 bytes)

# ===================== drm_mode_modeinfo 字段偏移 =====================
# offset 0:  clock       (u32)
# offset 4:  hdisplay    (u16)
# offset 6:  hsync_start (u16)
# offset 8:  hsync_end   (u16)
# offset 10: htotal      (u16)
# offset 12: hskew       (u16)
# offset 14: vdisplay    (u16)
# offset 16: vsync_start (u16)
# offset 18: vsync_end   (u16)
# offset 20: vtotal      (u16)
# offset 22: vscan       (u16)
# offset 24: vrefresh    (u32)
# offset 28: flags       (u32)
# offset 32: type        (u32)
# offset 36: name        (char[32])

# ===================== drm_mode_create_dumb 字段偏移 =====================
# offset 0:  height (u32)
# offset 4:  width  (u32)
# offset 8:  bpp    (u32)
# offset 12: flags  (u32)
# offset 16: handle (u32)
# offset 20: pitch  (u32)
# offset 24: size   (u64)

# ===================== drm_mode_map_dumb 字段偏移 =====================
# offset 0: handle (u32)
# offset 4: pad    (u32)
# offset 8: offset (u64)

# ===================== drm_mode_fb_cmd2 字段偏移 =====================
# offset 0:  fb_id        (u32)
# offset 4:  width        (u32)
# offset 8:  height       (u32)
# offset 12: pixel_format (u32)
# offset 16: flags        (u32)
# offset 20: handles[4]   (4*u32)
# offset 36: pitches[4]   (4*u32)
# offset 52: offsets[4]   (4*u32)
# offset 68: modifier[4]  (4*u64)


def _get_buf_addr(buf):
    """获取 bytearray 的内存地址（用于填充 ptr 字段）"""
    return ctypes.addressof((ctypes.c_char * len(buf)).from_buffer(buf))


# ===================== DRM 显示类 =====================
class DRMDisplay:
    def __init__(self, device=DRM_DEVICE):
        self.fd = -1
        self.crtc_id = 0
        self.connector_id = 0
        self.mode_data = None   # 68 bytes raw modeinfo
        self.screen_w = 0
        self.screen_h = 0
        self.dumb_handle = [0, 0]
        self.dumb_size = [0, 0]
        self.fb_id = [0, 0]
        self.mm = [None, None]
        self.pitch = 0
        self.buf_size = 0
        self.cur = 0
        self._init_drm(device)

    def _init_drm(self, device):
        self.fd = os.open(device, os.O_RDWR | os.O_CLOEXEC)

        # === GETRESOURCES 第一次：获取 count ===
        buf = bytearray(SZ_CARD_RES)
        fcntl.ioctl(self.fd, IOCTL_GETRESOURCES, buf)
        count_connectors = struct.unpack_from('<I', buf, 40)[0]
        count_crtcs = struct.unpack_from('<I', buf, 36)[0]

        # === GETRESOURCES 第二次：获取 connector IDs ===
        conn_ids_buf = bytearray(count_connectors * 4)
        buf2 = bytearray(SZ_CARD_RES)
        struct.pack_into('<Q', buf2, 16, _get_buf_addr(conn_ids_buf))
        fcntl.ioctl(self.fd, IOCTL_GETRESOURCES, buf2)
        conn_ids = struct.unpack_from(f'<{count_connectors}I', conn_ids_buf)

        # === 遍历 connector ===
        encoder_id = 0
        for cid in conn_ids:
            # 第一次 GETCONNECTOR：获取 count_modes
            conn_buf = bytearray(SZ_GET_CONNECTOR)
            struct.pack_into('<I', conn_buf, 48, cid)  # connector_id
            struct.pack_into('<I', conn_buf, 32, 1)    # count_modes = 1
            dummy = bytearray(SZ_MODEINFO)
            struct.pack_into('<Q', conn_buf, 8, _get_buf_addr(dummy))  # modes_ptr
            fcntl.ioctl(self.fd, IOCTL_GETCONNECTOR, conn_buf)

            count_modes = struct.unpack_from('<I', conn_buf, 32)[0]
            connection = struct.unpack_from('<I', conn_buf, 60)[0]

            if count_modes > 0 and connection == DRM_MODE_CONNECTED:
                # 第二次 GETCONNECTOR：获取实际 modes
                modes_buf = bytearray(SZ_MODEINFO * count_modes)
                conn_buf2 = bytearray(SZ_GET_CONNECTOR)
                struct.pack_into('<I', conn_buf2, 48, cid)
                struct.pack_into('<I', conn_buf2, 32, count_modes)
                struct.pack_into('<Q', conn_buf2, 8, _get_buf_addr(modes_buf))
                fcntl.ioctl(self.fd, IOCTL_GETCONNECTOR, conn_buf2)

                self.connector_id = cid
                self.mode_data = bytes(modes_buf[:SZ_MODEINFO])
                self.screen_w = struct.unpack_from('<H', modes_buf, 4)[0]   # hdisplay
                self.screen_h = struct.unpack_from('<H', modes_buf, 14)[0]  # vdisplay
                encoder_id = struct.unpack_from('<I', conn_buf2, 44)[0]
                break

        if not self.connector_id:
            raise RuntimeError("No connected DRM connector found")

        # === 找 CRTC ===
        crtc_id = 0
        if encoder_id:
            enc_buf = bytearray(SZ_GET_ENCODER)
            struct.pack_into('<I', enc_buf, 0, encoder_id)
            fcntl.ioctl(self.fd, IOCTL_GETENCODER, enc_buf)
            crtc_id = struct.unpack_from('<I', enc_buf, 8)[0]

        if not crtc_id and count_crtcs > 0:
            crtc_ids_buf = bytearray(count_crtcs * 4)
            buf3 = bytearray(SZ_CARD_RES)
            struct.pack_into('<Q', buf3, 8, _get_buf_addr(crtc_ids_buf))
            fcntl.ioctl(self.fd, IOCTL_GETRESOURCES, buf3)
            crtc_id = struct.unpack_from('<I', crtc_ids_buf, 0)[0]

        if not crtc_id:
            raise RuntimeError("No CRTC found")
        self.crtc_id = crtc_id

        # === 创建 dumb buffers + FB + mmap ===
        for i in range(2):
            # CREATE_DUMB
            d_buf = bytearray(SZ_CREATE_DUMB)
            struct.pack_into('<IIII', d_buf, 0, self.screen_h, self.screen_w, BPP, 0)
            fcntl.ioctl(self.fd, IOCTL_CREATE_DUMB, d_buf)
            handle = struct.unpack_from('<I', d_buf, 16)[0]
            pitch = struct.unpack_from('<I', d_buf, 20)[0]
            size = struct.unpack_from('<Q', d_buf, 24)[0]
            self.dumb_handle[i] = handle
            self.dumb_size[i] = size
            if i == 0:
                self.pitch = pitch
                self.buf_size = size

            # ADDFB2
            fb_buf = bytearray(SZ_FB_CMD2)
            struct.pack_into('<IIIII', fb_buf, 0, 0, self.screen_w, self.screen_h, DRM_FORMAT_XRGB8888, 0)
            struct.pack_into('<I', fb_buf, 20, handle)   # handles[0]
            struct.pack_into('<I', fb_buf, 36, pitch)    # pitches[0]
            fcntl.ioctl(self.fd, IOCTL_ADDFB2, fb_buf)
            self.fb_id[i] = struct.unpack_from('<I', fb_buf, 0)[0]

            # MAP_DUMB
            m_buf = bytearray(SZ_MAP_DUMB)
            struct.pack_into('<I', m_buf, 0, handle)
            fcntl.ioctl(self.fd, IOCTL_MAP_DUMB, m_buf)
            offset = struct.unpack_from('<Q', m_buf, 8)[0]
            self.mm[i] = mmap.mmap(self.fd, size, offset=offset)

    def _set_crtc(self):
        """SetCrtc"""
        crtc_buf = bytearray(SZ_CRTC)
        # connector 数组
        conn_arr = bytearray(4)
        struct.pack_into('<I', conn_arr, 0, self.connector_id)
        struct.pack_into('<Q', crtc_buf, 0, _get_buf_addr(conn_arr))  # set_connectors_ptr
        struct.pack_into('<I', crtc_buf, 8, 1)                        # count_connectors
        struct.pack_into('<I', crtc_buf, 12, self.crtc_id)            # crtc_id
        struct.pack_into('<I', crtc_buf, 16, self.fb_id[self.cur])    # fb_id
        struct.pack_into('<I', crtc_buf, 32, 1)                       # mode_valid
        crtc_buf[36:36 + SZ_MODEINFO] = self.mode_data                # mode
        fcntl.ioctl(self.fd, IOCTL_SETCRTC, crtc_buf)

    def display_image(self, img):
        """将 PIL Image (RGB) 显示到 DRM 屏幕"""
        if img.size != (self.screen_w, self.screen_h):
            img = img.resize((self.screen_w, self.screen_h), Image.Resampling.LANCZOS)

        xrgb_data = fast_image_to_xrgb8888(img, self.screen_w, self.screen_h)
        buf = self.mm[self.cur]

        if self.pitch == self.screen_w * 4:
            buf[:len(xrgb_data)] = xrgb_data
        else:
            row_bytes = self.screen_w * 4
            for y in range(self.screen_h):
                src = y * row_bytes
                dst = y * self.pitch
                buf[dst:dst + row_bytes] = xrgb_data[src:src + row_bytes]

        self._set_crtc()
        self.cur = 1 - self.cur

    def clear(self):
        for i in range(2):
            self.mm[i][:] = b'\x00' * self.buf_size

    def close(self):
        for i in range(2):
            if self.mm[i]:
                self.mm[i].close()
            if self.fb_id[i]:
                rmfb_buf = bytearray(4)
                struct.pack_into('<I', rmfb_buf, 0, self.fb_id[i])
                fcntl.ioctl(self.fd, IOCTL_RMFB, rmfb_buf)
            if self.dumb_handle[i]:
                dd_buf = bytearray(SZ_DESTROY_DUMB)
                struct.pack_into('<I', dd_buf, 0, self.dumb_handle[i])
                fcntl.ioctl(self.fd, IOCTL_DESTROY_DUMB, dd_buf)
        if self.fd >= 0:
            os.close(self.fd)


# ===================== 高速像素写入 =====================
def fast_image_to_xrgb8888(img, screen_w, screen_h):
    """将 PIL Image 快速转为 XRGB8888 bytes (BGRX 内存序)"""
    try:
        import numpy as np
        arr = np.array(img.convert("RGB").resize((screen_w, screen_h), Image.Resampling.LANCZOS))
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
            out[i * 4]     = raw[i * 3 + 2]  # B
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
    display = DRMDisplay(DRM_DEVICE)

    threading.Thread(target=network_monitor, daemon=True).start()
    threading.Thread(target=thread_preload_sentence, daemon=True).start()
    threading.Thread(target=thread_preload_background, daemon=True).start()

    time.sleep(5)

    while True:
        try:
            bg_canvas = get_background_canvas()
            show_text = get_display_text()
            final_img = draw_center_text(bg_canvas, show_text)
            display.display_image(final_img)
        except Exception as e:
            pass

        time.sleep(REFRESH_CYCLE.total_seconds())


if __name__ == "__main__":
    main_loop()
