# Omarchy Kraken

An Omarchy bar widget for NZXT Kraken Z coolers (Z53, Z63, Z73), built on
[liquidctl](https://github.com/liquidctl/liquidctl).

- Fan icon in the bar. Click it for live liquid, CPU and GPU temperatures and fan speeds.
- Cooling profiles: Silent, Auto, Performance.
- Change the image or GIF on the cooler's display, or go back to the temperature readout.
- Saved settings are reapplied at login and after resume.

## Install

Install the dependencies:

```bash
sudo pacman -S liquidctl python-pillow
```

Then open the Omarchy menu, go to **Setup > Plugins > Add Plugin**, and enter:

```
https://github.com/k61n/omarchy-kraken.git
```

Or from a terminal:

```bash
omarchy plugin add https://github.com/k61n/omarchy-kraken.git --enable
```

Enabling the plugin applies the saved settings straight away. On a new install, that's
the Auto profile and the temperature display.

Update with `omarchy plugin update k61n.kraken` and remove with **Remove Plugin** or
`omarchy plugin remove k61n.kraken`. Saved settings stay in `~/.local/state/omarchy-kraken`,
and the cooler keeps its current curve until power-off.

## Development

Replace the installed copy with a link to your checkout. Saving a file reloads the plugin;
if a change doesn't apply, run `omarchy restart shell`.

```bash
ln -sfn "$PWD" ~/.config/omarchy/plugins/k61n.kraken
omarchy plugin validate "$PWD"
```

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
```

## Notes

- Images are center-cropped to 320×320 and copied to `~/.local/state/omarchy-kraken/images`,
  so restores keep working if the original file moves. GIFs can be up to 24 MB after resizing.
- Settings are applied through liquidctl's `--direct-access`, because the kernel
  driver's hwmon files are only writable by root. Sensors are read from hwmon, except
  NVIDIA GPU temperature, which comes from `nvidia-smi`.
- Settings are restored by a background service inside the Omarchy shell, so they come
  back after you log in. Until then, the cooler uses whatever it last had or its firmware
  default.
- Fan and pump percentages are of rated top speed: 2800 rpm for the pump and 2000 rpm for
  the fan. The cooler can't report its model or fan type, so with Z63 or non-stock fans,
  change `FAN_MAX_RPM` in `bin/krakenctl`.
