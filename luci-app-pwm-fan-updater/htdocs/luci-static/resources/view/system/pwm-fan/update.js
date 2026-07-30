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

return view.extend({
	handleSaveApply: null,
	handleSave: null,
	handleReset: null,

	load: function() {
		return callCheck();
	},

	render: function(status) {
		var body = E('div', { 'class': 'pwm-v2-field-grid' });

		if (!status.success) {
			body.appendChild(E('p', { 'class': 'alert-message error' }, [
				errorText(status.error)
			]));
		}
		else {
			body.appendChild(E('div', {}, [
				E('strong', {}, [ _('Installed version') ]),
				E('div', {}, [ status.installed ])
			]));
			body.appendChild(E('div', {}, [
				E('strong', {}, [ _('Latest community version') ]),
				E('div', {}, [ '%s-r%s'.format(status.version, status.release) ])
			]));
			body.appendChild(E('div', {}, [
				E('strong', {}, [ _('Source commit') ]),
				E('div', {}, [ status.source_commit ])
			]));
			if (status.update_available)
				body.appendChild(E('button', {
					'class': 'btn cbi-button-positive',
					'type': 'button',
					'click': function(ev) {
						var button = ev.currentTarget;
						ui.showModal(_('Install community update?'), [
							E('p', {}, [
								_('The APKs will be downloaded over HTTPS and checked with SHA-256 before installation.')
							]),
							E('div', { 'class': 'right' }, [
								E('button', {
									'class': 'btn',
									'click': ui.hideModal
								}, [ _('Cancel') ]),
								' ',
								E('button', {
									'class': 'btn cbi-button-positive',
									'click': function() {
										button.disabled = true;
										return callInstall().then(function(result) {
											if (!result.success)
												throw new Error(errorText(result.error));
											ui.hideModal();
											ui.addNotification(null, E('p', {}, [
												_('Update installed. Reload LuCI to use the new files.')
											]), 'info');
										}).catch(function(error) {
											ui.addNotification(null, E('p', {}, [
												error.message
											]), 'error');
										}).finally(function() {
											button.disabled = false;
										});
									}
								}, [ _('Install update') ])
							])
						]);
					}
				}, [ _('Install latest build') ]));
		}

		return E([], [
			fanV2.stylesheet(),
			E('div', { 'class': 'pwm-v2', 'data-page': 'update' }, [
				fanV2.card(_('Community updates'), body)
			])
		]);
	}
});
