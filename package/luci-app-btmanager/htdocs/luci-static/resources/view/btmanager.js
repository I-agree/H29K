'use strict';

'require view';
'require fs';
'require poll';

var API = '/usr/sbin/btmanager';

var STYLE = [
	'.btm .btm-table { width:100%; border-collapse:collapse; }',
	'.btm .btm-table th { text-align:left; font-weight:600; padding:10px 14px; white-space:nowrap; border-bottom:1px solid rgba(128,128,128,.35); }',
	'.btm .btm-table td { padding:12px 14px; vertical-align:middle; border-bottom:1px solid rgba(128,128,128,.16); }',
	'.btm .btm-table tr:last-child td { border-bottom:none; }',
	'.btm .btm-name { font-weight:600; line-height:1.45; word-break:break-word; }',
	'.btm .btm-sub { margin-top:3px; font-size:12px; opacity:.62; line-height:1.5; }',
	'.btm .btm-mac { font-family:monospace; font-size:12.5px; opacity:.72; letter-spacing:.3px; }',
	'.btm .btm-btns { display:flex; flex-wrap:wrap; gap:8px; }',
	'.btm .btm-btns .btn { margin:0; }',
	'.btm .btm-row { display:flex; align-items:center; flex-wrap:wrap; gap:8px; }',
	'.btm .btm-card { margin-bottom:18px; }',
	'.btm .btm-note { margin-top:10px; font-size:12px; opacity:.65; line-height:1.6; }',
	'.btm .btm-empty { padding:16px 2px; opacity:.6; }',
	'.btm .btm-input { max-width:300px; }',
	'.btm .btm-scroll { overflow-x:auto; }'
].join('\n');

function exec(args) {
	return fs.exec(API, args).then(function(res) {
		if (res.code !== 0)
			throw new Error(((res.stderr || '') + (res.stdout || '')).trim() || _('后台执行失败'));
		return res.stdout || '';
	});
}

function api(args) {
	return exec(args).then(function(out) {
		var res;

		try {
			res = JSON.parse(out);
		} catch (e) {
			throw new Error(_('后台返回数据无法解析'));
		}

		if (res && res.ok === false)
			throw new Error(res.message || _('操作失败'));

		return res;
	});
}

function devLabel(dev) {
	return dev && dev.name ? dev.name : _('未命名设备');
}

function devNotes(dev) {
	var notes = [];

	if (!dev.name)
		notes.push(dev.random ? _('随机地址 · 未广播名称') : _('未广播名称'));
	else if (dev.cached)
		notes.push(_('本机命名'));
	else if (dev.random)
		notes.push(_('随机地址'));

	if (dev.audio)
		notes.push(_('音频设备'));

	return notes.join(' · ');
}

function typeLabel(dev) {
	var icon = (dev.icon || '').toLowerCase();

	if (icon === 'audio-card' || icon === 'audio-headset')
		return _('音箱/耳机');
	if (icon === 'input-keyboard')
		return _('键盘');
	if (icon === 'input-mouse' || icon === 'input-gaming')
		return _('鼠标/手柄');
	if (icon === 'phone')
		return _('手机');
	if (dev.audio)
		return _('音频设备');

	return _('其他设备');
}

function stateText(dev) {
	var parts = [];

	if (dev.connected)
		parts.push(_('已连接'));
	else if (dev.paired)
		parts.push(_('已配对'));
	else
		parts.push(_('未配对'));

	if (dev.trusted)
		parts.push(_('受信任'));

	return parts.join(' · ');
}

function button(label, cls, onclick) {
	return E('button', {
		'class': 'btn cbi-button ' + (cls || 'cbi-button-action'),
		'type': 'button',
		'click': function(ev) {
			ev.preventDefault();
			onclick();
		}
	}, label);
}

function styleNode() {
	var el = E('style', { 'type': 'text/css' });

	el.textContent = STYLE;

	return el;
}

return view.extend({
	load: function() {
		return Promise.all([
			api([ 'summary' ]).catch(function() { return null; }),
			api([ 'devices' ]).catch(function() { return null; })
		]);
	},

	render: function(data) {
		var self = this;

		this.summary = data[0] || {};
		this.devices = (data[1] && data[1].devices) || [];
		this.found = [];
		this.cfg = (this.summary && this.summary.config) || {};

		this.msgBar = E('div', { 'style': 'display:none' });
		this.statusBody = E('div', {});
		this.foundBody = E('div', {});
		this.devBody = E('div', {});
		this.diagBody = E('div', {});

		this.nameInput = E('input', {
			'type': 'text',
			'class': 'cbi-input-text btm-input',
			'placeholder': (this.summary.controller && this.summary.controller.name) || 'BlueZ 5.87',
			'value': this.cfg.devicename || ''
		});

		this.setMsg = function(text, isError) {
			this.msgBar.style.display = text ? '' : 'none';
			this.msgBar.style.padding = '8px 12px';
			this.msgBar.style.margin = '0 0 14px 0';
			this.msgBar.style.borderRadius = '4px';
			this.msgBar.style.background = isError ? '#fdecea' : '#e8f5e9';
			this.msgBar.style.color = isError ? '#b71c1c' : '#1b5e20';
			this.msgBar.textContent = text || '';
		};

		this.refresh = function() {
			return Promise.all([ api([ 'summary' ]), api([ 'devices' ]) ]).then(function(res) {
				self.summary = res[0] || {};
				self.devices = (res[1] && res[1].devices) || [];
				self.cfg = self.summary.config || self.cfg;
				self.paint();
			}).catch(function() { /* 轮询失败时不打扰用户 */ });
		};

		this.act = function(label, args) {
			self.setMsg(label + ' ...');
			return api(args).then(function(r) {
				if (r && r.found)
					self.found = r.found;
				self.setMsg((r && r.message) || (label + _('完成')), false);
				return self.refresh();
			}).catch(function(e) {
				self.setMsg(label + _('失败：') + (e.message || e), true);
			});
		};

		this.saveName = function() {
			var val = self.nameInput.value.trim();

			self.setMsg(val ? _('正在应用蓝牙名称 ...') : _('正在恢复默认名称 ...'));

			api([ 'name', val ]).then(function(r) {
				self.setMsg((r && r.message) || _('名称已更新'), false);
				if (!val)
					self.nameInput.value = '';
				return self.refresh();
			}).catch(function(e) {
				self.setMsg(_('修改名称失败：') + (e.message || e), true);
			});
		};

		this.editing = null;

		this.toggleBT = function() {
			var on = !(self.cfg && self.cfg.enabled === '0');

			if (on && !confirm(_('关闭蓝牙会断开所有已连接设备，并停止蓝牙服务。确定关闭？')))
				return;

			self.act(on ? _('关闭蓝牙') : _('开启蓝牙'), [ 'enable', on ? '0' : '1' ]);
		};

		var body = E('div', { 'class': 'cbi-map btm' }, [
			styleNode(),
			E('h2', {}, _('蓝牙管理')),
			E('div', { 'class': 'cbi-map-descr' },
				_('管理板载蓝牙控制器：扫描、配对、连接音箱/耳机/麦克风/键鼠，设置开机自动回连。')),
			this.msgBar,

			E('div', { 'class': 'cbi-section btm-card' }, [
				E('h3', {}, _('控制器状态')),
				E('div', { 'class': 'cbi-section-node' }, [
					this.statusBody,
					E('div', { 'class': 'btm-row', 'style': 'margin-top:12px' }, [
						button(_('重启蓝牙服务'), 'cbi-button-apply', function() {
							self.setMsg(_('正在重启蓝牙服务（约 3 秒）...'));
							api([ 'restart' ]).then(function() {
								return self.refresh();
							}).then(function() {
								self.setMsg(_('蓝牙服务已重启'), false);
							}).catch(function(e) {
								self.setMsg(_('重启失败：') + (e.message || e), true);
							});
						}),
						button(_('适配器上电'), 'cbi-button-action', function() {
							self.act(_('适配器上电'), [ 'power', 'on' ]);
						}),
						button(_('适配器下电'), 'cbi-button-action', function() {
							self.act(_('适配器下电'), [ 'power', 'off' ]);
						})
					])
				])
			]),

			E('div', { 'class': 'cbi-section btm-card' }, [
				E('h3', {}, _('蓝牙名称')),
				E('div', { 'class': 'cbi-section-node' }, [
					E('div', { 'class': 'btm-row' }, [
						this.nameInput,
						button(_('保存名称'), 'cbi-button-apply', function() {
							self.saveName();
						}),
						button(_('恢复默认'), 'cbi-button-action', function() {
							self.nameInput.value = '';
							self.saveName();
						})
					]),
					E('div', { 'class': 'btm-note' },
						_('就是手机/电脑搜索蓝牙时看到的名字，最多 64 字节；留空并保存会恢复 BlueZ 默认名称。修改后立即生效，并会在每次开机时重新应用。'))
				])
			]),

			E('div', { 'class': 'cbi-section btm-card' }, [
				E('h3', {}, _('扫描附近设备')),
				E('div', { 'class': 'cbi-section-node' }, [
					E('div', { 'class': 'btm-row' }, [
						button(_('开始扫描（8 秒）'), 'cbi-button-apply', function() {
							if (self.cfg && self.cfg.enabled === '0') {
								self.setMsg(_('蓝牙当前已关闭，请先在上方开启蓝牙'), true);
								return;
							}
							self.setMsg(_('正在扫描，请让设备保持在可被发现状态 ...'));
							api([ 'scan', '8' ]).then(function(r) {
								self.found = (r && r.found) || [];
								self.setMsg((r && r.message) || _('扫描完成'), false);
								self.paintFound();
								return self.refresh();
							}).catch(function(e) {
								self.setMsg(_('扫描失败：') + (e.message || e), true);
							});
						})
					]),
					this.foundBody,
					E('div', { 'class': 'btm-note' },
						_('配对前请先让设备进入配对模式（音箱/耳机通常长按电源键）。手机、手表等设备多用随机地址且不广播名称，会显示为“未命名设备”，一般无法配对，属正常现象。'))
				])
			]),

			E('div', { 'class': 'cbi-section btm-card' }, [
				E('h3', {}, _('设备列表')),
				E('div', { 'class': 'cbi-section-node' }, [ this.devBody ])
			]),

			E('div', { 'class': 'cbi-section btm-card' }, [
				E('h3', {}, _('服务设置')),
				E('div', { 'class': 'cbi-section-node' }, [ this.buildConfigForm() ])
			]),

			E('div', { 'class': 'cbi-section btm-card' }, [
				E('h3', {}, _('诊断')),
				E('div', { 'class': 'cbi-section-node' }, [
					E('div', { 'class': 'btm-row' }, [
						button(_('刷新诊断信息'), 'cbi-button-action', function() {
							self.loadDiag();
						}),
						button(_('查看蓝牙日志'), 'cbi-button-action', function() {
							self.loadLog();
						})
					]),
					this.diagBody
				])
			])
		]);

		this.paint();
		this.paintFound();

		poll.add(function() {
			return self.refresh();
		}, 8);

		return body;
	},

	buildConfigForm: function() {
		var self = this;
		var cfg = this.cfg || {};

		function field(label, node, desc) {
			return E('div', { 'class': 'cbi-value' }, [
				E('label', { 'class': 'cbi-value-title' }, label),
				E('div', { 'class': 'cbi-value-field' }, [
					node,
					desc ? E('div', { 'class': 'cbi-value-description' }, desc) : ''
				])
			]);
		}

		this.uartInput = E('input', {
			'type': 'text', 'class': 'cbi-input-text btm-input',
			'value': cfg.uart || '/dev/ttyS2'
		});
		this.baudInput = E('input', {
			'type': 'text', 'class': 'cbi-input-text btm-input',
			'value': cfg.baud || '1500000'
		});
		this.flowInput = E('select', { 'class': 'cbi-input-select' }, [
			E('option', { 'value': 'flow' }, 'flow'),
			E('option', { 'value': 'noflow' }, 'noflow')
		]);
		this.flowInput.value = cfg.flow || 'flow';

		this.typeInput = E('input', {
			'type': 'text', 'class': 'cbi-input-text btm-input',
			'value': cfg.type || 'any'
		});

		this.transportInput = E('select', { 'class': 'cbi-input-select' }, [
			E('option', { 'value': 'auto' }, _('自动（优先用厂商驱动自带的控制器）')),
			E('option', { 'value': 'uart' }, _('强制用 UART + hciattach'))
		]);
		this.transportInput.value = cfg.transport || 'auto';

		this.autoconnectInput = E('input', { 'type': 'checkbox' });
		this.autoconnectInput.checked = (cfg.autoconnect === '1');

		return E('div', {}, [
			field(_('传输方式'), this.transportInput,
				_('自动：内核里已有可用 HCI 控制器（如 AIC8800 通过 SDIO 提供的蓝牙）时，不再用 hciattach 挂 UART。')),
			field(_('串口设备'), this.uartInput, _('仅在“强制用 UART”时生效。板载蓝牙 HCI 所在 UART，默认 /dev/ttyS2（rk3528 uart2）。')),
			field(_('波特率'), this.baudInput, _('必须与芯片当前串口速率一致，AIC8800 常见 1500000，其次 115200 / 921600。')),
			field(_('硬件流控'), this.flowInput, _('默认 flow；若 UART 未引出 RTS 且出现丢包，可改 noflow。')),
			field(_('hciattach 协议'), this.typeInput, _('BlueZ hciattach 的 type，AIC8800 用 any。')),
			field(_('开机自动连接'), this.autoconnectInput, _('开启后，启动时自动连接下表勾选了“自动连接”的设备。')),
			E('div', { 'class': 'cbi-value' }, [
				E('label', { 'class': 'cbi-value-title' }, ''),
				E('div', { 'class': 'cbi-value-field' }, [
					button(_('保存设置并重启服务'), 'cbi-button-apply', function() {
						var chain = Promise.resolve();

						[
							[ 'uart', self.uartInput.value.trim() ],
							[ 'baud', self.baudInput.value.trim() ],
							[ 'flow', self.flowInput.value ],
							[ 'type', self.typeInput.value.trim() ],
							[ 'transport', self.transportInput.value ],
							[ 'autoconnect', self.autoconnectInput.checked ? '1' : '0' ]
						].forEach(function(item) {
							chain = chain.then(function() {
								return api([ 'set', item[0], item[1] ]);
							});
						});

						chain.then(function() {
							self.setMsg(_('配置已保存，正在重启蓝牙服务 ...'));
							return api([ 'restart' ]);
						}).then(function() {
							self.setMsg(_('配置已生效'), false);
							return self.refresh();
						}).catch(function(e) {
							self.setMsg(_('保存失败：') + (e.message || e), true);
						});
					})
				])
			])
		]);
	},

	paint: function() {
		this.paintStatus();
		this.paintDevices();
	},

	paintStatus: function() {
		var self = this;
		var s = this.summary || {};
		var svc = s.service || {};
		var ctl = s.controller || {};
		var cnt = s.counts || {};
		var ctrls = s.controllers || [];
		var enabled = !(this.cfg && this.cfg.enabled === '0');

		function row(label, value) {
			return E('tr', {}, [
				E('th', { 'style': 'width:150px;font-weight:500;opacity:.75' }, label),
				E('td', {}, value)
			]);
		}

		function mark(ok, text) {
			return E('span', { 'style': 'color:' + (ok ? '#2e7d32' : '#c62828') }, (ok ? '● ' : '○ ') + text);
		}

		while (this.statusBody.firstChild)
			this.statusBody.removeChild(this.statusBody.firstChild);

		this.statusBody.appendChild(E('div', { 'class': 'btm-scroll' }, E('table', { 'class': 'btm-table' }, [
			row(_('蓝牙开关'), [
				mark(enabled, enabled ? _('已开启') : _('已关闭')),
				'　',
				button(enabled ? _('关闭蓝牙') : _('开启蓝牙'),
					enabled ? 'cbi-button-action' : 'cbi-button-apply',
					function() { self.toggleBT(); })
			]),
			row(_('bluetoothd'), mark(svc.bluetoothd, svc.bluetoothd ? _('运行中') : _('未运行'))),
			row(_('hciattach'), mark(svc.hciattach, svc.hciattach ? _('运行中') : _('未运行'))),
			row(_('传输方式'), [
				E('div', {}, [
					E('div', {}, (this.cfg && this.cfg.transport === 'uart')
						? _('强制 UART + hciattach')
						: _('自动')),
					E('div', { 'class': 'btm-sub' },
						(this.cfg && this.cfg.transport === 'uart')
							? _('始终用串口挂 HCI')
							: _('内核已有可用 HCI 控制器时跳过 hciattach'))
				])
			]),
			row(_('控制器'), ctrls.length ? E('div', {}, ctrls.map(function(c) {
				var up = /^UP/.test(c.state || '');
				var zero = /^00:00:00:00:00:00$/.test(c.address || '');
				return E('div', { 'style': 'margin:2px 0' }, [
					mark(up && !zero, (c.hci || '?') + ' · ' + (c.bus || '?') + ' · '),
					E('span', { 'class': 'btm-mac' }, c.address || _('无地址')),
					'　',
					E('span', { 'class': 'btm-sub' }, c.state || _('状态未知'))
				]);
			})) : mark(false, _('未发现任何 HCI 控制器'))),
			row(_('适配器'), [
				E('div', {}, [
					E('div', { 'class': 'btm-name' }, ctl.name || (enabled ? _('（读取中）') : '—')),
					E('div', { 'class': 'btm-sub' }, [
						ctl.address ? E('span', { 'class': 'btm-mac' }, ctl.address) : '',
						ctl.address ? '　' : '',
						ctl.powered ? _('已上电') : _('未上电'),
						'　',
						ctl.discoverable ? _('可被发现') : _('不可发现')
					])
				])
			]),
			row(_('设备统计'), _('已配对 ') + (cnt.paired || 0) + _(' 台，已连接 ') + (cnt.connected || 0) + _(' 台'))
		])));

		var deadUart = ctrls.some(function(c) {
			return (c.bus === 'UART') && (/^00:00:00:00:00:00$/.test(c.address || '') || /^DOWN/.test(c.state || ''));
		});

		if (deadUart)
			this.statusBody.appendChild(E('div', { 'class': 'btm-note' },
				_('检测到一个 UART 控制器未握手（地址全 0 / DOWN，内核常报 command 0x1003 tx timeout）。这说明蓝牙不走串口：把“传输方式”设为自动，重启服务后这个多余控制器就会消失。')));

		if (!ctrls.length)
			this.statusBody.appendChild(E('div', { 'class': 'btm-note' },
				_('没有任何 HCI 控制器：先看“诊断”里的 hciconfig / dmesg。厂商驱动走 SDIO 时蓝牙控制器由厂商模块提供，不需要 hciattach。')));
	},

	paintDevices: function() {
		var self = this;
		var list = (this.devices || []).slice().sort(function(a, b) {
			if (a.connected !== b.connected)
				return a.connected ? -1 : 1;
			if (a.paired !== b.paired)
				return a.paired ? -1 : 1;
			return devLabel(a).localeCompare(devLabel(b));
		});

		while (this.devBody.firstChild)
			this.devBody.removeChild(this.devBody.firstChild);

		if (!list.length) {
			this.devBody.appendChild(E('div', { 'class': 'btm-empty' },
				(this.cfg && this.cfg.enabled === '0')
					? _('蓝牙已关闭。开启后这里会显示已配对和扫描到的设备。')
					: _('暂无设备。先扫描并配对，之后会出现在这里。')));
			return;
		}

		var rows = list.map(function(dev) {
			var auto = E('input', { 'type': 'checkbox' });
			auto.checked = !!dev.autoconnect;
			auto.addEventListener('change', function() {
				api([ 'autodev', dev.address, auto.checked ? '1' : '0' ]).then(function() {
					return self.refresh();
				}).catch(function(e) {
					self.setMsg(_('设置自动连接失败：') + (e.message || e), true);
				});
			});

			var btns = [];

			if (dev.connected) {
				btns.push(button(_('断开'), 'cbi-button-action', function() {
					self.act(_('断开 ') + devLabel(dev), [ 'disconnect', dev.address ]);
				}));
			} else if (dev.paired) {
				btns.push(button(_('连接'), 'cbi-button-apply', function() {
					self.act(_('连接 ') + devLabel(dev), [ 'connect', dev.address ]);
				}));
			} else {
				btns.push(button(_('配对并连接'), 'cbi-button-apply', function() {
					self.act(_('配对 ') + devLabel(dev), [ 'pair', dev.address ]);
				}));
			}

			btns.push(button(_('命名'), 'cbi-button-action', function() {
				self.editing = (self.editing === dev.address) ? null : dev.address;
				self.paintDevices();
			}));

			btns.push(button(dev.trusted ? _('取消信任') : _('设为信任'), 'cbi-button-action', function() {
				self.act(_('修改信任状态'), [ 'trust', dev.address, dev.trusted ? '0' : '1' ]);
			}));

			btns.push(button(_('删除'), 'cbi-button-remove', function() {
				if (confirm(_('确定删除 ') + devLabel(dev) + _(' 的配对信息吗？')))
					self.act(_('删除 ') + devLabel(dev), [ 'remove', dev.address ]);
			}));

			var notes = devNotes(dev);
			var editing = (self.editing === dev.address);
			var inp = null;

			if (editing) {
				inp = E('input', {
					'type': 'text',
					'placeholder': dev.address,
					'style': 'width:100%; max-width:220px',
					'value': dev.name || ''
				});
				inp.value = dev.name || '';
				btns.length = 0;
				btns.push(button(_('保存名称'), 'cbi-button-apply', function() {
					var v = (inp.value || '').replace(/^\s+|\s+$/g, '');
					if (!v) {
						self.setMsg(_('设备名称不能为空'), true);
						return;
					}
					self.editing = null;
					self.act(_('保存名称'), [ 'alias', dev.address, v ]);
				}));
				btns.push(button(_('取消'), 'cbi-button-reset', function() {
					self.editing = null;
					self.paintDevices();
				}));
			}

			return E('tr', {}, [
				E('td', {}, editing ? inp : [
					E('div', { 'class': 'btm-name' }, devLabel(dev)),
					notes ? E('div', { 'class': 'btm-sub' }, notes) : ''
				]),
				E('td', { 'style': 'white-space:nowrap' }, typeLabel(dev)),
				E('td', {}, E('span', { 'class': 'btm-mac' }, dev.address)),
				E('td', { 'style': 'white-space:nowrap' }, stateText(dev)),
				E('td', {}, auto),
				E('td', {}, E('div', { 'class': 'btm-btns' }, btns))
			]);
		});

		this.devBody.appendChild(E('div', { 'class': 'btm-scroll' }, E('table', { 'class': 'btm-table' }, [
			E('tr', {}, [
				E('th', {}, _('名称')),
				E('th', {}, _('类型')),
				E('th', {}, _('地址')),
				E('th', {}, _('状态')),
				E('th', {}, _('自动连接')),
				E('th', {}, _('操作'))
			])
		].concat(rows))));
	},

	paintFound: function() {
		var self = this;

		while (this.foundBody.firstChild)
			this.foundBody.removeChild(this.foundBody.firstChild);

		if (!this.found.length) {
			this.foundBody.appendChild(E('div', { 'class': 'btm-note' },
				_('尚未扫描，或本次没有发现新设备。')));
			return;
		}

		var rows = this.found.map(function(item) {
			var known = (self.devices || []).filter(function(d) { return d.address === item.address; })[0];

			var action;
			if (known && known.connected)
				action = E('span', { 'class': 'btm-sub' }, _('已连接'));
			else if (known && known.paired)
				action = button(_('连接'), 'cbi-button-apply', function() {
					self.act(_('连接 ') + devLabel(item), [ 'connect', item.address ]);
				});
			else
				action = button(_('配对并连接'), 'cbi-button-apply', function() {
					self.act(_('配对 ') + devLabel(item), [ 'pair', item.address ]);
				});

			var notes = devNotes(item);

			return E('tr', {}, [
				E('td', {}, [
					E('div', { 'class': 'btm-name' }, devLabel(item)),
					notes ? E('div', { 'class': 'btm-sub' }, notes) : ''
				]),
				E('td', {}, E('span', { 'class': 'btm-mac' }, item.address)),
				E('td', {}, action)
			]);
		});

		var table = E('table', { 'class': 'btm-table' }, [
			E('tr', {}, [
				E('th', {}, _('设备')),
				E('th', {}, _('地址')),
				E('th', {}, _('操作'))
			])
		].concat(rows));

		this.foundBody.appendChild(
			E('div', { 'class': 'btm-scroll', 'style': 'margin-top:12px' }, table));
	},

	loadDiag: function() {
		var self = this;

		this.setMsg(_('正在收集诊断信息 ...'));
		exec([ 'diag' ]).then(function(text) {
			self.showText(text);
			self.setMsg(_('诊断信息已刷新'), false);
		}).catch(function(e) {
			self.setMsg(_('诊断失败：') + (e.message || e), true);
		});
	},

	loadLog: function() {
		var self = this;

		this.setMsg(_('正在读取日志 ...'));
		exec([ 'log' ]).then(function(text) {
			self.showText(text || _('（没有相关日志）'));
			self.setMsg(_('日志已刷新'), false);
		}).catch(function(e) {
			self.setMsg(_('读取日志失败：') + (e.message || e), true);
		});
	},

	showText: function(text) {
		while (this.diagBody.firstChild)
			this.diagBody.removeChild(this.diagBody.firstChild);

		this.diagBody.appendChild(E('pre', {
			'style': 'white-space:pre-wrap;max-height:380px;overflow:auto;font-family:monospace;font-size:12px;line-height:1.55;padding:12px;margin-top:12px;border:1px solid rgba(128,128,128,.3);border-radius:4px'
		}, text));
	}
});
