# weftplate

*Weaving your contacts into the fabric.*

An open design for a small **ESP32-C6** module that presents up to **six
dry-contact loops** as Matter **Contact Sensors** over **Thread** or **Wi-Fi**.
Each loop's open/closed state appears to any Matter controller (Home Assistant,
Apple Home, etc.) as a contact `binary_sensor`, joined to the Matter **fabric**
over the Thread mesh or your Wi-Fi network — no cloud, no vendor bridge.

The intent is a compact, self-contained way to bring "dumb" dry contacts —
reed/door switches, relay outputs, pushbuttons, resistor-terminated alarm loops —
into a Matter smart home as first-class sensors. The loop count and the transport
are build-time parameters, so the same codebase produces a one-input Thread
module or a six-input Wi-Fi one.

> **Status: a design project, not a product.** This repository is firmware plus
> (over time) the supporting hardware design. It is **not** a certified or listed
> appliance — it carries no CE, UKCA, FCC, RoHS, UL or other mark, and has not
> been evaluated by any regulatory or safety body. It is published for study,
> experimentation, and personal/educational use. See **Scope & disclaimer** below.

## What's here (and what's coming)

Currently in the repo:

- **Firmware** — the ESP32-C6 application (`main/app_main.cpp`) and its build.

Planned additions to make this a complete, reproducible design:

- **PCB files** — schematic and board layout for the module.
- **Bill of materials** — the parts the design is built around.
- **A parameterized, printable chassis** — an enclosure model generated to manifest a cohesive item.

## How a loop is sensed

- Each loop is an ESP32-C6 GPIO configured as an **input with an internal pull-up**.
- A field contact is placed **between that GPIO and ground**.
- Contact **closed** → pin pulled **LOW** → Matter `StateValue = true` (contact).
- Contact **open** → pin floats **HIGH** via the pull-up → `StateValue = false`.
- A 40 ms software debounce filters contact bounce before the state is published.

The loops are **dry inputs only**: the pin sources the C6's own 3.3 V logic
through the external contact to ground. The design senses the *position of a
switch*, not any external voltage or signal.

## Pin reference (Seeed XIAO ESP32-C6)

The default firmware targets the Seeed XIAO ESP32-C6 and uses its D0–D5 pads — a
contiguous run on one side — chosen to leave the UART0 console (D6/D7) and the
strapping, flash and USB pins free.

| Loop | XIAO pad | GPIO |
|------|----------|------|
| 1 | D0 | GPIO0 |
| 2 | D1 | GPIO1 |
| 3 | D2 | GPIO2 |
| 4 | D3 | GPIO21 |
| 5 | D4 | GPIO22 |
| 6 | D5 | GPIO23 |

A build for *N* loops uses the first *N* rows (D0 … D(N−1)); the remaining pads are
left as unused pulled-up inputs. For a different ESP32-C6 board, edit `LOOP_GPIOS[]`
in `main/app_main.cpp` — the raw GPIO numbers differ from the XIAO's `Dx` labels.

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

The firmware builds against **ESP-IDF v5.4.1** and **esp-matter 1.5**. The
simplest, most reproducible path is the official `espressif/esp-matter` Docker
image — no host toolchain install. Two wrapper scripts drive it:

```bash
# Build for N loops (1..6; default 6) over a transport (thread|wifi; default
# thread). First build is long — it compiles connectedhomeip from source inside
# the container.
./docker-build.sh 3 wifi

# Flash that build to a C6 on the given serial port (default /dev/ttyACM0).
./docker-flash.sh /dev/ttyACM0 wifi
```

- `docker-build.sh` runs the image as the host user (so build artifacts aren't
  root-owned) with host networking (so the component manager can resolve
  esp-matter's few managed dependencies on first configure).
- The loop count and transport are passed as CMake cache defines:
  `idf.py -D WEFTPLATE_NUM_LOOPS=N -D WEFTPLATE_TRANSPORT=thread|wifi`.
- The transport layers `transport/<transport>.defaults` over the common
  `sdkconfig.defaults`. Each transport builds into its own `build/<transport>`
  directory with its own generated sdkconfig, so switching transports never
  reuses a stale configuration.
- `docker-flash.sh` adds the host's `dialout` group so the container can open the
  serial device.

If you already have ESP-IDF v5.4.1 + esp-matter exported in your shell
(`idf.py` on `PATH`), `./build.sh N [thread|wifi] [flash]` does the same without
Docker.

On boot the firmware logs its configuration, e.g.:

```
weftplate: loop 0 -> GPIO0 -> endpoint 1
weftplate: loop 1 -> GPIO1 -> endpoint 2
weftplate: loop 2 -> GPIO2 -> endpoint 3
weftplate: weftplate up: 3 loop(s) as Matter contact sensors over Thread
```

## Commissioning

The firmware ships with Matter **test** attestation credentials (it is an
uncertified/test device), using the standard Matter test onboarding values:

- **Setup passcode:** `20202021`
- **Discriminator:** `3840`
- **Manual pairing code:** `34970112332`

For both transports the device advertises over BLE for commissioning, and the
controller hands it the network to join; no network credentials are built into
the firmware.

- **Thread:** requires a Thread border router on the network. The controller
  sends the Thread dataset over BLE, and the device joins the mesh.
- **Wi-Fi:** the controller sends the Wi-Fi SSID and password over BLE (2.4 GHz
  only), and the device joins as a station.

Once on the network it exposes *N* contact `binary_sensor` endpoints. In Home Assistant:
Settings → Devices & services → Matter → Add device → enter the manual pairing
code. Because the endpoint count and transport are fixed at build time,
re-flashing with a different loop count or transport means removing and
re-adding the device in the controller.

## Repository layout

```
weftplate/
  CMakeLists.txt        # top-level project; reads WEFTPLATE_TRANSPORT, picks defaults
  build.sh              # native build: ./build.sh N [thread|wifi] [flash]
  docker-build.sh       # containerized build: ./docker-build.sh N [thread|wifi]
  docker-flash.sh       # containerized flash: ./docker-flash.sh [PORT] [thread|wifi]
  partitions.csv        # 4 MB Matter partition table
  sdkconfig.defaults    # C6 + BLE + test-credential configuration (both transports)
  transport/
    thread.defaults     # OpenThread on, Wi-Fi off, platform mDNS
    wifi.defaults       # Wi-Fi station on, OpenThread off
  main/
    app_main.cpp        # N contact-sensor endpoints, GPIO poll + debounce
    CMakeLists.txt       # reads WEFTPLATE_NUM_LOOPS, applies the compile define
    idf_component.yml    # IDF version constraint (esp-matter comes from the image)
```

## Design notes

- **One transport per build.** The C6 has both radios, but a build enables only
  the selected one; the other is compiled out.
- **Polarity.** To treat *open* as the "contact" state, invert `read_closed()` in
  `main/app_main.cpp`.
- **Certification.** The test attestation credentials make this an uncertified
  device by design. A production unit would require its own manufacturer
  attestation (DAC) and CSA certification — out of scope for this project.

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
