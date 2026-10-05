# weftplate

*Weaving your contacts into the fabric.*

An open design for a small **ESP32-C6** module that presents up to **six
dry-contact switches** to **Home Assistant** over **Thread** or **Wi-Fi**, using
[ESPHome](https://esphome.io). Each switch appears as an **event entity** that
fires `toggled` every time the switch changes position, ready to drive
automations and scripts — no cloud, no vendor bridge.

The intent is a compact, self-contained way to bring "dumb" dry contacts —
reed/door switches, relay outputs, wall switches, pushbuttons — into Home
Assistant as first-class triggers. The switch count and the transport are
build-time parameters, so the same configuration produces a one-input Thread
module or a six-input Wi-Fi one.

> **This branch is the ESPHome firmware.** It talks to Home Assistant over
> ESPHome's native API, not Matter, so it works with Home Assistant only — not
> Apple Home, Google Home or other Matter controllers. The `matter` branch holds
> a Matter firmware for the same hardware (contact sensors, BLE commissioning
> with a pairing code).

> **Status: a design project, not a product.** This repository is firmware plus
> (over time) the supporting hardware design. It is **not** a certified or listed
> appliance — it carries no CE, UKCA, FCC, RoHS, UL or other mark, and has not
> been evaluated by any regulatory or safety body. It is published for study,
> experimentation, and personal/educational use. See **Scope & disclaimer** below.

## What's here (and what's coming)

Currently in the repo:

- **Firmware** — the ESPHome configuration (`weftplate.yaml` and its includes).

Planned additions to make this a complete, reproducible design:

- **PCB files** — schematic and board layout for the module.
- **Bill of materials** — the parts the design is built around.
- **A parameterized, printable chassis** — an enclosure model generated to manifest a cohesive item.

## How a switch is sensed

- Each switch is an ESP32-C6 GPIO configured as an **input with an internal pull-up**.
- The field switch is placed **between that GPIO and ground**.
- Switch **closed** → pin pulled **LOW**; switch **open** → pin floats **HIGH**
  via the pull-up.
- A 40 ms software debounce filters contact bounce.
- Every debounced change — closed → open or open → closed — fires a `toggled`
  event on that switch's Home Assistant event entity. Nothing fires at boot, so
  a restart or power blip never looks like a toggle.

The raw pin state is read by an internal sensor that is not exposed; Home
Assistant only sees the events.

The switches are **dry inputs only**: the pin sources the C6's own 3.3 V logic
through the external switch to ground. The design senses the *position of a
switch*, not any external voltage or signal.

## Pin reference (Seeed XIAO ESP32-C6)

The firmware targets the Seeed XIAO ESP32-C6 and uses its D0–D5 pads — a
contiguous run on one side — chosen to avoid the strapping, flash and USB pins.

| Switch | XIAO pad | GPIO |
|--------|----------|------|
| 1 | D0 | GPIO0 |
| 2 | D1 | GPIO1 |
| 3 | D2 | GPIO2 |
| 4 | D3 | GPIO21 |
| 5 | D4 | GPIO22 |
| 6 | D5 | GPIO23 |

A build for *N* switches exposes the first *N* rows (D0 … D(N−1)) to Home
Assistant. All six pads are still configured as pulled-up inputs; the unused
ones are simply hidden. For a different ESP32-C6 board, edit the `packages:`
pin table in `weftplate.yaml` — the raw GPIO numbers differ from the XIAO's `Dx`
labels.

## Power

The module is designed to run from a regulated **3.3 V** supply on the board's
3V3 rail. The reference design is built around an isolated AC/DC step-down module
(e.g. a Hi-Link HLK-PM03 class part, mains input → 3.3 V output) so the whole
assembly can be powered from line voltage in a single enclosure.

Mains-side details — fusing, surge protection, isolation spacing, enclosure and
wiring — belong to the hardware design and the installer's judgement, and are
**not** prescribed here. Working with line voltage is hazardous and, in most
places, regulated work; see the disclaimer.

## Build & flash

The firmware builds with **ESPHome 2026.7** on the ESP-IDF framework. Install
the ESPHome CLI (`pip install esphome`, or `uv tool install esphome`), then:

```bash
# One-time: create your secrets file and fill it in (see "Secrets" below).
cp secrets.yaml.example secrets.yaml

# Build for N switches (1..6; default 6) over a transport (thread|wifi;
# default thread). Parameters are ESPHome substitutions, passed with -s.
esphome -s num_switches 3 -s transport thread compile weftplate.yaml

# First flash over USB (the XIAO enumerates as /dev/ttyACM0 on Linux).
esphome -s num_switches 3 -s transport thread upload --device /dev/ttyACM0 weftplate.yaml

# Watch the log.
esphome -s num_switches 3 -s transport thread logs --device /dev/ttyACM0 weftplate.yaml
```

Pass the same `-s` values to every command for a given device. After the first
flash, `upload` without `--device` updates the firmware over the air (see
**Design notes** for reaching a Thread device).

On boot the firmware logs its configuration, e.g.:

```
[D][main]: weftplate up: 3 switch(es) over thread
```

### Secrets

`secrets.yaml` is git-ignored; `secrets.yaml.example` lists the keys:

| Key | Used by | What it is |
|-----|---------|------------|
| `api_encryption_key` | both | Encrypts the Home Assistant link. 32 random bytes, base64: `openssl rand -base64 32`. Home Assistant asks for it when adding the device. |
| `ota_password` | both | Protects over-the-air updates. Any string. |
| `thread_tlv` | Thread only | Your Thread network's operational dataset. In Home Assistant: Settings → Devices & services → Thread → (your network) → ⓘ → **Active dataset TLVs**. |

## Onboarding

### Thread

ESPHome has no runtime Thread commissioning, so the Thread dataset is compiled
in from `thread_tlv`. After flashing, the device joins the Thread network on its
own and registers itself with the border router. Home Assistant discovers it as
a new **ESPHome** device (Settings → Devices & services); add it and enter the
`api_encryption_key`.

### Wi-Fi

No Wi-Fi credentials are built in. After flashing, give the device your network
by any of:

- **Bluetooth (Improv):** Home Assistant (or the ESPHome app) discovers the
  device over Bluetooth and offers to set it up.
- **USB (Improv serial):** open [web.esphome.io](https://web.esphome.io) with
  the device plugged in and choose *Connect* → *Configure Wi-Fi*.
- **Fallback hotspot:** while it isn't on Wi-Fi, the device opens an open
  `weftplate Setup` network; join it and pick your network in the captive
  portal.

Credentials are saved to flash and survive reboots and OTA updates. Once on
Wi-Fi, Home Assistant discovers it as an ESPHome device as above.

## Using the switches in Home Assistant

Each exposed switch is an event entity named **Switch 1** … **Switch N** on the
device (entity IDs like `event.weftplate_xxxxxx_switch_1`, where `xxxxxx` is the
unit's MAC suffix). In the automation editor, use the entity's event trigger, or
in YAML:

```yaml
triggers:
  - trigger: state
    entity_id: event.weftplate_xxxxxx_switch_1
    not_from: unavailable
conditions:
  - condition: state
    entity_id: event.weftplate_xxxxxx_switch_1
    attribute: event_type
    state: toggled
actions:
  - action: light.toggle
    target:
      entity_id: light.hallway
```

The `not_from: unavailable` guard keeps the automation from firing when the
device reconnects.

## Repository layout

```
weftplate/
  weftplate.yaml         # main config: substitutions, pin table, device, API, OTA
  switch.yaml            # one switch: GPIO input + debounce -> "toggled" event
  transport/
    thread.yaml          # OpenThread, dataset from secrets
    wifi.yaml            # Wi-Fi with Improv (BLE + serial) and fallback hotspot
  secrets.yaml.example   # keys to copy into secrets.yaml (git-ignored)
```

## Design notes

- **Home Assistant only.** ESPHome has no Matter support; the device speaks
  ESPHome's encrypted native API. For Matter (any controller, pairing code over
  BLE), use the `matter` branch.
- **One transport per build.** The C6 has both radios, but ESPHome runs one at a
  time: a build includes either `transport/thread.yaml` or
  `transport/wifi.yaml`.
- **Saved Thread dataset wins.** Once a device has joined a Thread network, it
  keeps that dataset in flash and ignores the one in the build. To move a device
  to a different network, erase it first
  (`esptool.py --chip esp32c6 erase_flash`) or set `force_dataset: true` under
  `openthread:` in `transport/thread.yaml`.
- **Over-the-air updates on Thread** go to the device's Thread IPv6 address, so
  the machine running `esphome upload` needs a route to the Thread network
  (Home Assistant's host has one; a desktop often doesn't unless it accepts the
  border router's route advertisements). The ESPHome Device Builder add-on in
  Home Assistant can always reach it.
- **Image size.** The Wi-Fi build is much larger than the Thread one, mostly
  because of the Bluetooth Improv stack; both fit the XIAO's app partition with
  room for OTA.
- **Unique names.** Each unit's hostname gets its MAC suffix
  (`weftplate-xxxxxx`), so several modules can share one network.

## Scope & disclaimer

This project is provided for informational, educational and experimental
purposes only, **as-is and without any warranty** of any kind, express or
implied, including merchantability and fitness for a particular purpose. Nothing
in this repository is an instruction to build, power, install or operate the
device in any particular way, nor a representation that any configuration is
safe, compliant, or suitable for a given use.

The design is **not certified or listed** by any safety or regulatory
authority. Any construction or use involving mains/line voltage is inherently
hazardous and is frequently subject to electrical and building codes and to
licensing requirements; such work may be legal only when performed by a
qualified or licensed person. You are solely responsible for determining what is
permissible and safe in your jurisdiction and circumstances, and for any
consequences of building or using anything based on this project. Use at your
own risk.
