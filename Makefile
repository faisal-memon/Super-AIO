.PHONY: check-runtime install uninstall config-install config-uninstall systemd-install systemd-uninstall systemd-restart systemd-start systemd-stop systemd-status show-power monitor-power

# -----------------------------------------------------------------------------
# Common configuration
# -----------------------------------------------------------------------------
REPO_DIR ?= $(CURDIR)
CONFIG_BACKUP_DIR ?= /var/backups/super-aio

# -----------------------------------------------------------------------------
# Power monitoring
# -----------------------------------------------------------------------------
# Shared data file written by the Super-AIO monitor.
POWER_DATA ?= $(REPO_DIR)/release/saio/osd/data.ini

# -----------------------------------------------------------------------------
# Top-level orchestration
# -----------------------------------------------------------------------------
install: systemd-install config-install
	@echo 'Installed Super-AIO systemd integration and boot configuration.'

uninstall: systemd-uninstall config-uninstall
	@echo 'Removed Super-AIO systemd integration and restored boot configuration.'

show-power:
	@test -f "$(POWER_DATA)" || { echo 'ERROR: OSD data file not found: $(POWER_DATA)'; exit 1; }
	@awk -F ' *= *' '/^(voltage|current|temperature) *=/ { printf "%s: %s\n", $$1, $$2 }' "$(POWER_DATA)"

monitor-power:
	@test -f "$(POWER_DATA)" || { echo 'ERROR: OSD data file not found: $(POWER_DATA)'; exit 1; }
	@while true; do date; awk -F ' *= *' '/^(voltage|current|temperature) *=/ { printf "%s: %s\n", $$1, $$2 }' "$(POWER_DATA)"; echo; sleep 1; done

# -----------------------------------------------------------------------------
# Installation components: boot configuration
# -----------------------------------------------------------------------------
config-install:
	@test "$$(id -u)" -eq 0 || { echo 'ERROR: config-install must run as root (try sudo make config-install)'; exit 1; }
	test -f "$(REPO_DIR)/release/saio/config-saio.txt" || { echo 'ERROR: config-saio.txt template not found'; exit 1; }
	install -d -m 700 "$(CONFIG_BACKUP_DIR)"
	if [ -e /boot/config-saio.txt ] && [ ! -e "$(CONFIG_BACKUP_DIR)/config-saio.txt" ]; then cp -p /boot/config-saio.txt "$(CONFIG_BACKUP_DIR)/config-saio.txt"; fi
	sed 's#/home/pi/Super-AIO#$(REPO_DIR)#g' "$(REPO_DIR)/release/saio/config-saio.txt" > /tmp/config-saio.txt
	install -m 644 /tmp/config-saio.txt /boot/config-saio.txt
	rm -f /tmp/config-saio.txt
	@echo 'Installed /boot/config-saio.txt from the repository template.'

config-uninstall:
	@test "$$(id -u)" -eq 0 || { echo 'ERROR: config-uninstall must run as root (try sudo make config-uninstall)'; exit 1; }
	@test -f "$(CONFIG_BACKUP_DIR)/config-saio.txt" || { echo 'ERROR: no backed-up config-saio.txt found'; exit 1; }
	install -m 644 "$(CONFIG_BACKUP_DIR)/config-saio.txt" /boot/config-saio.txt
	@echo 'Restored the backed-up /boot/config-saio.txt.'

# -----------------------------------------------------------------------------
# Installation components: systemd service
# -----------------------------------------------------------------------------
systemd-install:
	@test "$$(id -u)" -eq 0 || { echo 'ERROR: systemd-install must run as root (try sudo make systemd-install)'; exit 1; }
	test -f "$(REPO_DIR)/release/saio/super-aio.service.in" || { echo 'ERROR: service template not found'; exit 1; }
	sed 's#__REPO_DIR__#$(REPO_DIR)#g' "$(REPO_DIR)/release/saio/super-aio.service.in" > /tmp/super-aio.service
	install -m 644 /tmp/super-aio.service /etc/systemd/system/super-aio.service
	rm -f /tmp/super-aio.service
	systemctl daemon-reload
	@echo 'Installed super-aio.service. Enable it with: sudo systemctl enable --now super-aio.service'

systemd-uninstall:
	@test "$$(id -u)" -eq 0 || { echo 'ERROR: systemd-uninstall must run as root (try sudo make systemd-uninstall)'; exit 1; }
	systemctl disable --now super-aio.service 2>/dev/null || true
	rm -f /etc/systemd/system/super-aio.service
	systemctl daemon-reload
	@echo 'Removed super-aio.service.'

# -----------------------------------------------------------------------------
# Runtime controls
# -----------------------------------------------------------------------------
systemd-restart:
	@if systemctl is-active --quiet super-aio.service; then systemctl restart super-aio.service; else echo 'ERROR: super-aio.service is not active'; exit 1; fi

systemd-stop:
	@test "$$(id -u)" -eq 0 || { echo 'ERROR: systemd-stop must run as root (try sudo make systemd-stop)'; exit 1; }
	systemctl stop super-aio.service

systemd-start:
	@test "$$(id -u)" -eq 0 || { echo 'ERROR: systemd-start must run as root (try sudo make systemd-start)'; exit 1; }
	systemctl start super-aio.service

systemd-status:
	@systemctl --no-pager --full status super-aio.service

# -----------------------------------------------------------------------------
# Runtime health check
# -----------------------------------------------------------------------------
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
