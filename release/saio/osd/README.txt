Version: OSD_20170826_1
Author : Giles Burgess

The OSD service is launched with:

./saio-osd -d <ini file for data> -c <ini file for config>

Where:
ini file for data   : An INI file that contains the data to display
ini file for config : An INI file that contains the configuration data

It is recommended to run this as a background job.

The native OSD binary currently supports debug, Wi-Fi, and mute visibility
fields. It does not expose a separate battery-visibility field, so battery
hide/show requires rebuilding the native OSD rather than changing the Python
monitor alone.

Once running, make changes to the 'ini file for data' by editing/replacing with fresh data, then send a SIGUSR1 to the process:

kill -s SIGUSR1 <PID>

The OSD service will then read the 'ini file for data' and update the display with the new data.
