.PHONY: check-runtime install-runtime uninstall-runtime dry-run install-systemd uninstall-systemd restart-runtime status-runtime

REPO_DIR ?= $(CURDIR)
TARGET_USER ?= pi
BACKUP_DIR ?= /var/backups/super-aio
CRON_MARKER := \# Super-AIO managed runtime

dry-run:
	@echo "Would install Super-AIO from: $(REPO_DIR)"
	@echo "Would configure $(TARGET_USER)'s @reboot monitor"
	@echo "Would back up runtime files to: $(BACKUP_DIR)"
	@echo "Would install: /opt/retropie/configs/all/autostart.sh"
	@echo "Would install: /boot/config-saio.txt"

install-systemd:
	@test "$$(id -u)" -eq 0 || { echo 'ERROR: install-systemd must run as root (try sudo make install-systemd)'; exit 1; }
	test -f "$(REPO_DIR)/release/saio/super-aio.service.in" || { echo 'ERROR: service template not found'; exit 1; }
	sed 's#__REPO_DIR__#$(REPO_DIR)#g' "$(REPO_DIR)/release/saio/super-aio.service.in" > /tmp/super-aio.service
	install -m 644 /tmp/super-aio.service /etc/systemd/system/super-aio.service
	rm -f /tmp/super-aio.service
	systemctl daemon-reload
	@echo 'Installed super-aio.service. Cron remains active until an explicit cutover.'

uninstall-systemd:
	@test "$$(id -u)" -eq 0 || { echo 'ERROR: uninstall-systemd must run as root (try sudo make uninstall-systemd)'; exit 1; }
	systemctl disable --now super-aio.service 2>/dev/null || true
	rm -f /etc/systemd/system/super-aio.service
	systemctl daemon-reload
	@echo 'Removed super-aio.service.'

restart-runtime:
	@if systemctl is-active --quiet super-aio.service; then systemctl restart super-aio.service; else echo 'ERROR: super-aio.service is not active'; exit 1; fi

status-runtime:
	@systemctl --no-pager --full status super-aio.service

install-runtime:
	@test "$$(id -u)" -eq 0 || { echo 'ERROR: install-runtime must run as root (try sudo make install-runtime)'; exit 1; }
	@test -f "$(REPO_DIR)/release/saio/autostart.sh" || { echo 'ERROR: release/saio/autostart.sh not found'; exit 1; }
	@test -f "$(REPO_DIR)/release/saio/config-saio.txt" || { echo 'ERROR: release/saio/config-saio.txt not found'; exit 1; }
	@test -f "$(REPO_DIR)/release/saio/saio-osd.py" || { echo 'ERROR: release/saio/saio-osd.py not found'; exit 1; }
	install -d -m 700 "$(BACKUP_DIR)"
	if [ ! -e "$(BACKUP_DIR)/autostart.sh" ] && [ -e /opt/retropie/configs/all/autostart.sh ]; then cp -p /opt/retropie/configs/all/autostart.sh "$(BACKUP_DIR)/autostart.sh"; fi
	if [ ! -e "$(BACKUP_DIR)/config-saio.txt" ] && [ -e /boot/config-saio.txt ]; then cp -p /boot/config-saio.txt "$(BACKUP_DIR)/config-saio.txt"; fi
	if [ ! -e "$(BACKUP_DIR)/$(TARGET_USER).cron" ]; then crontab -u "$(TARGET_USER)" -l 2>/dev/null > "$(BACKUP_DIR)/$(TARGET_USER).cron" || :; fi
	install -m 755 "$(REPO_DIR)/release/saio/autostart.sh" /opt/retropie/configs/all/autostart.sh
	sed 's#/home/pi/Super-AIO#$(REPO_DIR)#g' "$(REPO_DIR)/release/saio/config-saio.txt" > /tmp/super-aio-config-saio.txt
	install -m 644 /tmp/super-aio-config-saio.txt /boot/config-saio.txt
	rm -f /tmp/super-aio-config-saio.txt
	crontab -u "$(TARGET_USER)" -l 2>/dev/null | grep -v 'saio-osd.py' > /tmp/super-aio-cron || :
	echo '@reboot sleep 30 && /usr/bin/nice -n 19 /usr/bin/python $(REPO_DIR)/release/saio/saio-osd.py $(CRON_MARKER)' >> /tmp/super-aio-cron
	crontab -u "$(TARGET_USER)" /tmp/super-aio-cron
	rm -f /tmp/super-aio-cron
	@echo 'Installed Super-AIO runtime. Reboot or restart the monitor to apply it.'

uninstall-runtime:
	@test "$$(id -u)" -eq 0 || { echo 'ERROR: uninstall-runtime must run as root (try sudo make uninstall-runtime)'; exit 1; }
	@test -d "$(BACKUP_DIR)" || { echo 'ERROR: no Super-AIO backup directory found'; exit 1; }
	if [ -f "$(BACKUP_DIR)/autostart.sh" ]; then install -m 755 "$(BACKUP_DIR)/autostart.sh" /opt/retropie/configs/all/autostart.sh; fi
	if [ -f "$(BACKUP_DIR)/config-saio.txt" ]; then install -m 644 "$(BACKUP_DIR)/config-saio.txt" /boot/config-saio.txt; fi
	if [ -f "$(BACKUP_DIR)/$(TARGET_USER).cron" ]; then crontab -u "$(TARGET_USER)" "$(BACKUP_DIR)/$(TARGET_USER).cron"; fi
	@echo 'Restored the backed-up Super-AIO runtime configuration. Stop the running monitor separately if needed.'

# Verify that the Super-AIO monitor and its native OSD child are running.
# Run this target on the Raspberry Pi; it is intentionally read-only.
check-runtime:
	@set -eu; \
	monitor_pid=$$(pgrep -f '/release/saio/saio-osd.py' | head -n 1 || true); \
	if [ -z "$$monitor_pid" ]; then \
		echo 'FAIL: Super-AIO Python monitor is not running'; \
		exit 1; \
	fi; \
	osd_pid=$$(pgrep -f '/release/saio/osd/saio-osd' | head -n 1 || true); \
	if [ -z "$$osd_pid" ]; then \
		echo 'FAIL: Super-AIO OSD process is not running'; \
		exit 1; \
	fi; \
	echo "PASS: Super-AIO monitor is running (PID $$monitor_pid)"; \
	echo "PASS: Super-AIO OSD is running (PID $$osd_pid)"
