.PHONY: check-runtime install-systemd uninstall-systemd restart-runtime start-runtime stop-runtime status-runtime show-power monitor-power

# -----------------------------------------------------------------------------
# Common configuration
# -----------------------------------------------------------------------------
REPO_DIR ?= $(CURDIR)

# -----------------------------------------------------------------------------
# Power monitoring
# -----------------------------------------------------------------------------
# Shared data file written by the Super-AIO monitor.
POWER_DATA ?= $(REPO_DIR)/release/saio/osd/data.ini

show-power:
	@test -f "$(POWER_DATA)" || { echo 'ERROR: OSD data file not found: $(POWER_DATA)'; exit 1; }
	@awk -F ' *= *' '/^(voltage|current|temperature) *=/ { printf "%s: %s\n", $$1, $$2 }' "$(POWER_DATA)"

monitor-power:
	@test -f "$(POWER_DATA)" || { echo 'ERROR: OSD data file not found: $(POWER_DATA)'; exit 1; }
	@while true; do date; awk -F ' *= *' '/^(voltage|current|temperature) *=/ { printf "%s: %s\n", $$1, $$2 }' "$(POWER_DATA)"; echo; sleep 1; done

# -----------------------------------------------------------------------------
# systemd runtime management
# -----------------------------------------------------------------------------
install-systemd:
	@test "$$(id -u)" -eq 0 || { echo 'ERROR: install-systemd must run as root (try sudo make install-systemd)'; exit 1; }
	test -f "$(REPO_DIR)/release/saio/super-aio.service.in" || { echo 'ERROR: service template not found'; exit 1; }
	sed 's#__REPO_DIR__#$(REPO_DIR)#g' "$(REPO_DIR)/release/saio/super-aio.service.in" > /tmp/super-aio.service
	install -m 644 /tmp/super-aio.service /etc/systemd/system/super-aio.service
	rm -f /tmp/super-aio.service
	systemctl daemon-reload
	@echo 'Installed super-aio.service. Enable it with: sudo systemctl enable --now super-aio.service'

uninstall-systemd:
	@test "$$(id -u)" -eq 0 || { echo 'ERROR: uninstall-systemd must run as root (try sudo make uninstall-systemd)'; exit 1; }
	systemctl disable --now super-aio.service 2>/dev/null || true
	rm -f /etc/systemd/system/super-aio.service
	systemctl daemon-reload
	@echo 'Removed super-aio.service.'

restart-runtime:
	@if systemctl is-active --quiet super-aio.service; then systemctl restart super-aio.service; else echo 'ERROR: super-aio.service is not active'; exit 1; fi

stop-runtime:
	@test "$$(id -u)" -eq 0 || { echo 'ERROR: stop-runtime must run as root (try sudo make stop-runtime)'; exit 1; }
	systemctl stop super-aio.service

start-runtime:
	@test "$$(id -u)" -eq 0 || { echo 'ERROR: start-runtime must run as root (try sudo make start-runtime)'; exit 1; }
	systemctl start super-aio.service

status-runtime:
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
