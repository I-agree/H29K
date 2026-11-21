'use strict';

'require view';
'require fs';
'require poll';

var API = '/usr/sbin/btmanager';

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
		'style': 'margin:0 4px 4px 0',
		'click': function(ev) {
			ev.preventDefault();
			onclick();
		}
	}, label);
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
		this.configFilled = false;

		this.msgBar = E('div', { 'style': 'display:none' });
		this.statusBody = E('div', {});
		this.foundBody = E('div', {});
		this.devBody = E('div', {});
		this.diagBody = E('div', {});

		this.setMsg = function(text, isError) {
			this.msgBar.style.display = text ? '' : 'none';
			this.msgBar.style.padding = '8px 10px';
			this.msgBar.style.margin = '0 0 12px 0';
			this.msgBar.style.borderRadius = '4px';
			this.msgBar.style.background = isError ? '#fdecea' : '#e8f5e9';
			this.msgBar.style.color = isError ? '#b71c1c' : '#1b5e20';
			this.msgBar.textContent = text || '';
		};

		this.refresh = function() {
			return Promise.all([ api([ 'summary' ]), api([ 'devices' ]) ]).then(function(res) {
				self.summary = res[0] || {};
				self.devices = (res[1] && res[1].devices) || [];
				self.paint();
			}).catch(function() { /* polling errors are ignored */ });
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

		var body = E('div', { 'class': 'cbi-map' }, [
			E('h2', {}, _('蓝牙管理')),
			E('div', { 'class': 'cbi-map-descr' },
				_('管理 AIC8800 蓝牙控制器：扫描、配对、连接音箱/耳机/麦克风/键鼠，并设置开机自动回连。')),
			this.msgBar,

			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('控制器状态')),
				E('div', { 'class': 'cbi-section-node' }, [
					this.statusBody,
					E('div', { 'style': 'margin-top:10px' }, [
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
						' ',
						button(_('适配器上电'), 'cbi-button-action', function() {
							self.act(_('适配器上电'), [ 'power', 'on' ]);
						}),
						' ',
						button(_('适配器下电'), 'cbi-button-action', function() {
							self.act(_('适配器下电'), [ 'power', 'off' ]);
						})
					])
				])
			]),

			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('扫描附近设备')),
				E('div', { 'class': 'cbi-section-node' }, [
					E('div', { 'class': 'cbi-value' }, [
						E('div', { 'class': 'cbi-value-field' }, [
							button(_('开始扫描（8 秒）'), 'cbi-button-apply', function() {
								self.setMsg(_('正在扫描，8 秒内保持设备处于可发现状态 ...'));
								api([ 'scan', '8' ]).then(function(r) {
									self.found = (r && r.found) || [];
									self.setMsg((r && r.message) || _('扫描完成'), false);
									self.paintFound();
									return self.refresh();
								}).catch(function(e) {
									self.setMsg(_('扫描失败：') + (e.message || e), true);
								});
							})
						])
					]),
					this.foundBody
				])
			]),

			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('已配对设备')),
				E('div', { 'class': 'cbi-section-node' }, [ this.devBody ])
			]),

			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('服务设置')),
				E('div', { 'class': 'cbi-section-node' }, [ this.buildConfigForm() ])
			]),

			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('诊断')),
				E('div', { 'class': 'cbi-section-node' }, [
					E('div', { 'class': 'cbi-value' }, [
						E('div', { 'class': 'cbi-value-field' }, [
							button(_('刷新诊断信息'), 'cbi-button-action', function() {
								self.loadDiag();
							}),
							' ',
							button(_('查看蓝牙日志'), 'cbi-button-action', function() {
								self.loadLog();
							})
						])
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
		var cfg = (this.summary && this.summary.config) || {};

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
			'type': 'text', 'class': 'cbi-input-text',
			'value': cfg.uart || '/dev/ttyS2'
		});
		this.baudInput = E('input', {
			'type': 'text', 'class': 'cbi-input-text',
			'value': cfg.baud || '1500000'
		});
		this.flowInput = E('select', { 'class': 'cbi-input-select' }, [
			E('option', { 'value': 'flow' }, 'flow'),
			E('option', { 'value': 'noflow' }, 'noflow')
		]);
		this.flowInput.value = cfg.flow || 'flow';

		this.typeInput = E('input', {
			'type': 'text', 'class': 'cbi-input-text',
			'value': cfg.type || 'any'
		});

		this.autoconnectInput = E('input', { 'type': 'checkbox' });
		this.autoconnectInput.checked = (cfg.autoconnect === '1');

		return E('div', {}, [
			field(_('串口设备'), this.uartInput, _('AIC8800 蓝牙 HCI 所在 UART，默认 /dev/ttyS2（rk3528 uart2）。')),
			field(_('波特率'), this.baudInput, _('参考 AIC8800 方案：1500000。')),
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
		var s = this.summary || {};
		var svc = s.service || {};
		var ctl = s.controller || {};
		var cnt = s.counts || {};

		function row(label, value) {
			return E('tr', { 'class': 'cbi-section-table-row' }, [
				E('td', { 'class': 'cbi-value-title', 'style': 'width:140px' }, label),
				E('td', {}, value)
			]);
		}

		function mark(ok, text) {
			return E('span', { 'style': 'color:' + (ok ? '#2e7d32' : '#c62828') }, (ok ? '● ' : '○ ') + text);
		}

		while (this.statusBody.firstChild)
			this.statusBody.removeChild(this.statusBody.firstChild);

		this.statusBody.appendChild(E('table', { 'class': 'cbi-section-table' }, [
			row(_('bluetoothd'), mark(svc.bluetoothd, svc.bluetoothd ? _('运行中') : _('未运行'))),
			row(_('hciattach'), mark(svc.hciattach, svc.hciattach ? _('运行中') : _('未运行'))),
			row(_('HCI 控制器'), mark(svc.hci0, svc.hci0 ? 'hci0' : _('没有 hci0，检查 UART/波特率/固件'))),
			row(_('适配器'), [
				ctl.address ? (ctl.address + '　') : '',
				ctl.name ? ('“' + ctl.name + '”　') : '',
				mark(ctl.powered, ctl.powered ? _('已上电') : _('未上电')),
				'　',
				ctl.discoverable ? _('可被发现') : _('不可发现')
			]),
			row(_('设备统计'), _('已配对 ') + (cnt.paired || 0) + _(' 台，已连接 ') + (cnt.connected || 0) + _(' 台'))
		]));

		if (!svc.hci0)
			this.statusBody.appendChild(E('div', { 'class': 'cbi-value-description' },
				_('提示：hci0 不存在时先看“诊断”里的 hciconfig / dmesg / rfkill；必要时在服务设置里换 /dev/ttyS1、/dev/ttyS2 或改波特率后重启服务。')));
	},

	paintDevices: function() {
		var self = this;
		var list = (this.devices || []).slice().sort(function(a, b) {
			if (a.connected !== b.connected)
				return a.connected ? -1 : 1;
			return (a.name || '').localeCompare(b.name || '');
		});

		while (this.devBody.firstChild)
			this.devBody.removeChild(this.devBody.firstChild);

		if (!list.length) {
			this.devBody.appendChild(E('div', { 'class': 'cbi-value-description' },
				_('暂无设备。先扫描并配对，之后会出现在这里。')));
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

			var actions = [];

			if (dev.connected) {
				actions.push(button(_('断开'), 'cbi-button-action', function() {
					self.act(_('断开 ') + dev.name, [ 'disconnect', dev.address ]);
				}));
			} else if (dev.paired) {
				actions.push(button(_('连接'), 'cbi-button-apply', function() {
					self.act(_('连接 ') + dev.name, [ 'connect', dev.address ]);
				}));
			} else {
				actions.push(button(_('配对并连接'), 'cbi-button-apply', function() {
					self.act(_('配对 ') + dev.name, [ 'pair', dev.address ]);
				}));
			}

			actions.push(button(dev.trusted ? _('取消信任') : _('设为信任'), 'cbi-button-action', function() {
				self.act(_('修改信任状态'), [ 'trust', dev.address, dev.trusted ? '0' : '1' ]);
			}));

			actions.push(button(_('删除'), 'cbi-button-remove', function() {
				if (confirm(_('确定删除 ') + dev.name + _(' 的配对信息吗？')))
					self.act(_('删除 ') + dev.name, [ 'remove', dev.address ]);
			}));

			return E('tr', { 'class': 'cbi-section-table-row' }, [
				E('td', {}, [ E('strong', {}, dev.name || dev.address),
					dev.audio ? E('span', { 'class': 'cbi-value-description' }, ' ' + _('音频')) : '' ]),
				E('td', {}, typeLabel(dev)),
				E('td', {}, E('code', {}, dev.address)),
				E('td', {}, stateText(dev)),
				E('td', {}, auto),
				E('td', { 'style': 'white-space:nowrap' }, actions)
			]);
		});

		this.devBody.appendChild(E('table', { 'class': 'cbi-section-table' }, [
			E('tr', { 'class': 'cbi-section-table-titles' }, [
				E('th', {}, _('名称')),
				E('th', {}, _('类型')),
				E('th', {}, _('地址')),
				E('th', {}, _('状态')),
				E('th', {}, _('自动连接')),
				E('th', {}, _('操作'))
			])
		].concat(rows)));
	},

	paintFound: function() {
		var self = this;

		while (this.foundBody.firstChild)
			this.foundBody.removeChild(this.foundBody.firstChild);

		if (!this.found.length) {
			this.foundBody.appendChild(E('div', { 'class': 'cbi-value-description' },
				_('尚未扫描，或本次没有发现新设备。')));
			return;
		}

		var rows = this.found.map(function(item) {
			var known = (self.devices || []).filter(function(d) { return d.address === item.address; })[0];

			var action;
			if (known && known.connected)
				action = E('span', {}, _('已连接'));
			else if (known && known.paired)
				action = button(_('连接'), 'cbi-button-apply', function() {
					self.act(_('连接 ') + item.name, [ 'connect', item.address ]);
				});
			else
				action = button(_('配对并连接'), 'cbi-button-apply', function() {
					self.act(_('配对 ') + item.name, [ 'pair', item.address ]);
				});

			return E('tr', { 'class': 'cbi-section-table-row' }, [
				E('td', {}, item.name || _('未知设备')),
				E('td', {}, E('code', {}, item.address)),
				E('td', {}, action)
			]);
		});

		this.foundBody.appendChild(E('table', { 'class': 'cbi-section-table' }, [
			E('tr', { 'class': 'cbi-section-table-titles' }, [
				E('th', {}, _('发现的设备')),
				E('th', {}, _('地址')),
				E('th', {}, _('操作'))
			])
		].concat(rows)));
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
			'style': 'white-space:pre-wrap;max-height:360px;overflow:auto;font-family:monospace;font-size:12px;padding:8px;border:1px solid rgba(128,128,128,.35);border-radius:4px'
		}, text));
	}
});
