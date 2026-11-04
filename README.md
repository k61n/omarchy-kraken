# Omarchy Kraken

An Omarchy bar widget for NZXT Kraken Z coolers (Z53, Z63, Z73), built on
[liquidctl](https://github.com/liquidctl/liquidctl).

- Fan icon in the bar. Click it for live temperature and fan speeds.
- Cooling profiles: Silent, Auto, Performance.
- Change the image or GIF on the cooler's display, or go back to the temperature readout.
- Saved settings are reapplied at login and after resume.

## Install

```bash
./install.sh     # links the plugin, adds the widget, enables the service
./uninstall.sh
```

The plugin is a symlink to this folder, so keep the folder in place. After editing
QML, run `omarchy restart shell`; the shell doesn't reliably hot-reload it through
the symlink.

## Profiles

Curves live in `profiles.json` as `[liquid °C, duty %]` points. The cooler's firmware
runs the curve itself, so no daemon has to keep polling. Curves follow **liquid**
temperature, not CPU temperature, so they react gradually to load. Above 59 °C
liquidctl forces 100%. After editing a curve, reapply it with `bin/krakenctl restore`.

## Command line

```bash
bin/krakenctl status                # sensors and saved settings as JSON
bin/krakenctl profile silent        # silent | auto | performance
bin/krakenctl screen pick           # open the file chooser
bin/krakenctl screen set ~/cat.gif
bin/krakenctl screen liquid
bin/krakenctl restore
journalctl --user -u omarchy-kraken # restore log
```

## Notes

- Images are center-cropped to 320×320 and copied to `~/.local/state/omarchy-kraken/images`,
  so restores keep working if the original file moves. GIFs can be up to 24 MB after resizing.
- Settings are applied through liquidctl's `--direct-access`, because the kernel
  driver's hwmon files are only writable by root. Sensors are read from hwmon.
- The service runs in your user session, so between power-on and login the cooler
  uses its firmware default.
