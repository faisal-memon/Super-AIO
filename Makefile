# -----------------------------------------------------------------------------
# Common configuration
# -----------------------------------------------------------------------------
REPO_DIR ?= $(CURDIR)

# -----------------------------------------------------------------------------
# Install
# -----------------------------------------------------------------------------
.PHONY: install install-systemd install-config

CONFIG_BACKUP_DIR ?= /var/backups/super-aio

install: install-systemd install-config
	@echo 'Installed Super-AIO systemd integration and boot configuration.'

install-systemd:
	@test "$$(id -u)" -eq 0 || { echo 'ERROR: install-systemd must run as root (try sudo make install-systemd)'; exit 1; }
	test -f "$(REPO_DIR)/release/saio/super-aio.service.in" || { echo 'ERROR: service template not found'; exit 1; }
	sed 's#__REPO_DIR__#$(REPO_DIR)#g' "$(REPO_DIR)/release/saio/super-aio.service.in" > /tmp/super-aio.service
	install -m 644 /tmp/super-aio.service /etc/systemd/system/super-aio.service
	rm -f /tmp/super-aio.service
	systemctl daemon-reload
	@echo 'Installed super-aio.service. Enable it with: sudo systemctl enable --now super-aio.service'

install-config:
	@test "$$(id -u)" -eq 0 || { echo 'ERROR: install-config must run as root (try sudo make install-config)'; exit 1; }
	test -f "$(REPO_DIR)/release/saio/config-saio.txt" || { echo 'ERROR: config-saio.txt template not found'; exit 1; }
	install -d -m 700 "$(CONFIG_BACKUP_DIR)"
	if [ -e /boot/config-saio.txt ] && [ ! -e "$(CONFIG_BACKUP_DIR)/config-saio.txt" ]; then cp -p /boot/config-saio.txt "$(CONFIG_BACKUP_DIR)/config-saio.txt"; fi
	sed 's#/home/pi/Super-AIO#$(REPO_DIR)#g' "$(REPO_DIR)/release/saio/config-saio.txt" > /tmp/config-saio.txt
	install -m 644 /tmp/config-saio.txt /boot/config-saio.txt
	rm -f /tmp/config-saio.txt
	@echo 'Installed /boot/config-saio.txt from the repository template.'

# -----------------------------------------------------------------------------
# Uninstall
# -----------------------------------------------------------------------------
.PHONY: uninstall uninstall-systemd uninstall-config

uninstall: uninstall-systemd uninstall-config
	@echo 'Removed Super-AIO systemd integration and restored boot configuration.'

uninstall-systemd:
	@test "$$(id -u)" -eq 0 || { echo 'ERROR: uninstall-systemd must run as root (try sudo make uninstall-systemd)'; exit 1; }
	systemctl disable --now super-aio.service 2>/dev/null || true
	rm -f /etc/systemd/system/super-aio.service
	systemctl daemon-reload
	@echo 'Removed super-aio.service.'

uninstall-config:
	@test "$$(id -u)" -eq 0 || { echo 'ERROR: uninstall-config must run as root (try sudo make uninstall-config)'; exit 1; }
	@test -f "$(CONFIG_BACKUP_DIR)/config-saio.txt" || { echo 'ERROR: no backed-up config-saio.txt found'; exit 1; }
	install -m 644 "$(CONFIG_BACKUP_DIR)/config-saio.txt" /boot/config-saio.txt
	@echo 'Restored the backed-up /boot/config-saio.txt.'

# -----------------------------------------------------------------------------
# Migration cleanup
# -----------------------------------------------------------------------------
.PHONY: remove-cron

TARGET_USER ?= pi

remove-cron:
	@test "$$(id -u)" -eq 0 || { echo 'ERROR: remove-cron must run as root (try sudo make remove-cron)'; exit 1; }
	install -d -m 700 "$(CONFIG_BACKUP_DIR)"
	if [ ! -e "$(CONFIG_BACKUP_DIR)/$(TARGET_USER).cron.before-systemd" ]; then crontab -u "$(TARGET_USER)" -l 2>/dev/null > "$(CONFIG_BACKUP_DIR)/$(TARGET_USER).cron.before-systemd" || :; fi
	tmp_cron=$$(mktemp); trap 'rm -f "$$tmp_cron"' EXIT; crontab -u "$(TARGET_USER)" -l 2>/dev/null | grep -v -E 'saio-osd.py|Super-AIO managed runtime' > "$$tmp_cron" || :; crontab -u "$(TARGET_USER)" "$$tmp_cron"
	@echo 'Removed the legacy Super-AIO cron entry; other cron jobs were preserved.'

# -----------------------------------------------------------------------------
# Service lifecycle
# -----------------------------------------------------------------------------
.PHONY: start-systemd stop-systemd restart-systemd status-systemd

start-systemd:
	@test "$$(id -u)" -eq 0 || { echo 'ERROR: start-systemd must run as root (try sudo make start-systemd)'; exit 1; }
	systemctl start super-aio.service

stop-systemd:
	@test "$$(id -u)" -eq 0 || { echo 'ERROR: stop-systemd must run as root (try sudo make stop-systemd)'; exit 1; }
	systemctl stop super-aio.service

restart-systemd:
	@if systemctl is-active --quiet super-aio.service; then systemctl restart super-aio.service; else echo 'ERROR: super-aio.service is not active'; exit 1; fi

status-systemd:
	@systemctl --no-pager --full status super-aio.service

# -----------------------------------------------------------------------------
# Tests and diagnostics
# -----------------------------------------------------------------------------
.PHONY: check-runtime show-power monitor-power

POWER_DATA ?= $(REPO_DIR)/release/saio/osd/data.ini

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

show-power:
	@test -f "$(POWER_DATA)" || { echo 'ERROR: OSD data file not found: $(POWER_DATA)'; exit 1; }
	@awk -F ' *= *' '/^(voltage|current|temperature) *=/ { printf "%s: %s\n", $$1, $$2 }' "$(POWER_DATA)"

monitor-power:
	@test -f "$(POWER_DATA)" || { echo 'ERROR: OSD data file not found: $(POWER_DATA)'; exit 1; }
	@while true; do date; awk -F ' *= *' '/^(voltage|current|temperature) *=/ { printf "%s: %s\n", $$1, $$2 }' "$(POWER_DATA)"; echo; sleep 1; done
