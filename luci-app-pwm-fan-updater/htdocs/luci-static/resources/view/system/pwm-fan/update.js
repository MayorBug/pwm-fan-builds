// SPDX-License-Identifier: GPL-2.0-only

'use strict';
'require pwm.fan_v2 as fanV2';
'require rpc';
'require ui';
'require view';
/* global fanV2 */

var callCheck = rpc.declare({
	object: 'pwm.fan.update',
	method: 'check',
	expect: { '': { success: false } }
});
var callInstall = rpc.declare({
	object: 'pwm.fan.update',
	method: 'install',
	expect: { '': { success: false } }
});
var callStatus = rpc.declare({
	object: 'pwm.fan.update',
	method: 'status',
	expect: { '': { running: false, success: false, phase: 'idle' } }
});

function errorText(code) {
	return {
		manifest_download_failed: _('Release information could not be downloaded.'),
		manifest_invalid: _('Release information is invalid.'),
		manifest_origin_rejected: _('The release points outside the trusted project repository.'),
		package_download_failed: _('An update package could not be downloaded.'),
		package_size_mismatch: _('A downloaded APK has an unexpected size.'),
		checksum_failed: _('The downloaded APK checksum did not match.'),
		update_in_progress: _('Another update is already running.'),
		insufficient_space: _('There is not enough temporary storage for the update.'),
		install_failed: _('APK could not install the update.')
	}[code] || _('The update operation failed.');
}

function formatBytes(value) {
	value = Number(value) || 0;
	return value < 1024 ? _('%d B').format(value) : _('%s KiB').format((value / 1024).toFixed(1));
}

function phaseText(status) {
	switch (status.phase) {
	case 'starting': return _('Starting update…');
	case 'manifest': return _('Downloading release information…');
	case 'downloading': return _('Downloading %s…').format(status.package || _('package'));
	case 'verifying': return _('Verifying %s…').format(status.package || _('package'));
	case 'verified': return _('%s verified.').format(status.package || _('Package'));
	case 'installing': return _('Installing packages…');
	case 'complete': return _('Build installed successfully.');
	case 'failed': return errorText(status.error);
	default: return _('Waiting for updater…');
	}
}

function showProgress(mainButton) {
	var message = E('p', {}, [ _('Starting update…') ]);
	var detail = E('p', { 'class': 'pwm-v2-muted' }, [ _('Files: 0 of 3') ]);
	var progress = E('progress', { 'max': 100, 'value': 0, 'style': 'width:100%' });
	var actions = E('div', { 'class': 'right' });
	var reconnectAttempts = 0;

	function delay() {
		return new Promise(function(resolve) {
			window.setTimeout(resolve, 750);
		});
	}

	function finish(status) {
		message.textContent = phaseText(status);
		progress.value = status.success ? 100 : progress.value;
		actions.appendChild(E('button', {
			'class': 'btn cbi-button-positive',
			'click': status.success
				? function() { window.location.reload(); }
				: ui.hideModal
		}, [ status.success ? _('Reload LuCI') : _('Close') ]));
		mainButton.disabled = false;
	}

	function update(status) {
		var downloaded = Number(status.downloaded) || 0;
		var total = Number(status.total) || 0;
		var completed = Number(status.completed) || 0;
		var count = Number(status.package_count) || 3;
		var current = total > 0 ? Math.min(1, downloaded / total) : 0;
		var overall = status.phase === 'verified' ||
			status.phase === 'installing' || status.phase === 'complete'
			? completed : completed + current;

		reconnectAttempts = 0;
		message.textContent = phaseText(status);
		detail.textContent = _('Files: %d of %d').format(completed, count);
		progress.value = Math.min(100, Math.floor(overall * 100 / count));
		if (total > 0)
			detail.textContent += ' · ' + _('%s of %s').format(
				formatBytes(downloaded), formatBytes(total));
		if (!status.running) {
			finish(status);
			return Promise.resolve();
		}
		return delay().then(pollStatus);
	}

	function pollStatus() {
		return callStatus().then(update).catch(function(error) {
			if (++reconnectAttempts > 40)
				throw error;
			message.textContent = _('Reconnecting to updater…');
			return delay().then(pollStatus);
		});
	}

	ui.showModal(_('Installing PWM Fan build'), [ message, progress, detail, actions ]);
	return callInstall().then(function(result) {
		if (!result.success)
			throw new Error(errorText(result.error));
		return pollStatus();
	}).catch(function(error) {
		finish({ success: false, phase: 'failed', error: error.message });
		message.textContent = error.message;
	});
}

function renderCheck(body, status) {
	body.replaceChildren();
	if (!status.success) {
		body.appendChild(E('p', { 'class': 'alert-message error' }, [
			errorText(status.error)
		]));
		return;
	}
	body.appendChild(E('div', {}, [
		E('strong', {}, [ _('Installed version') ]),
		E('div', {}, [ status.installed ])
	]));
	body.appendChild(E('div', {}, [
		E('strong', {}, [ _('Latest build') ]),
		E('div', {}, [ '%s-r%s'.format(status.version, status.release) ])
	]));
	body.appendChild(E('div', {}, [
		E('strong', {}, [ _('LuCI source commit') ]),
		E('div', {}, [ status.source_commit ])
	]));
	body.appendChild(E('div', {}, [
		E('strong', {}, [ _('Controller source commit') ]),
		E('div', {}, [ status.controller_source_commit ])
	]));
	var sameVersion = status.same_version === true;
	var action = E('button', {
		'class': 'btn ' + (status.update_available ? 'cbi-button-positive' : 'cbi-button-neutral'),
		'type': 'button',
		'disabled': !status.update_available && !sameVersion ? 'disabled' : null,
		'click': function(ev) {
			var button = ev.currentTarget;
			var reinstall = sameVersion;
			ui.showModal(reinstall ? _('Reinstall current build?') : _('Install new build?'), [
				E('p', {}, [ reinstall
					? _('The installed and latest builds are the same. Reinstall this build?')
					: _('The latest build will be downloaded and installed.')
				]),
				E('div', { 'class': 'right' }, [
					E('button', { 'class': 'btn', 'click': ui.hideModal }, [ _('Cancel') ]),
					' ',
					E('button', {
						'class': 'btn cbi-button-positive',
						'click': function() {
							button.disabled = true;
							return showProgress(button);
						}
					}, [ reinstall ? _('Reinstall build') : _('Install build') ])
				])
			]);
		}
	}, [ status.update_available ? _('Download new build')
		: sameVersion ? _('Reinstall current build') : _('Up to date') ]);
	body.appendChild(action);
}

return view.extend({
	handleSaveApply: null,
	handleSave: null,
	handleReset: null,

	load: function() {
		return Promise.resolve();
	},

	render: function() {
		var body = E('div', { 'class': 'pwm-v2-field-grid' }, [
			E('p', { 'class': 'pwm-v2-muted' }, [ _('Checking for updates…') ])
		]);
		callCheck().then(function(status) {
			renderCheck(body, status);
		}).catch(function() {
			renderCheck(body, { success: false, error: 'manifest_download_failed' });
		});

		return E([], [
			fanV2.stylesheet(),
			E('div', { 'class': 'pwm-v2', 'data-page': 'update' }, [
				fanV2.card(_('PWM Fan Builds'), body)
			])
		]);
	}
});
