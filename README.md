# Complex Number Lab

A CLI complex-number calculator written in **Guile Scheme**: algebraic, trigonometric and exponential forms, arithmetic, integer powers, all n-th roots, adjustable display precision, an automatic calculation log, and Argand-diagram plots via **gnuplot**.

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Guile](https://img.shields.io/badge/Guile-3.x-blue.svg)
![gnuplot](https://img.shields.io/badge/gnuplot-optional-green.svg)

---

## Contents

- [Features](#features)
- [Two versions](#two-versions)
- [Requirements](#requirements)
- [Installing dependencies](#installing-dependencies)
- [Running](#running)
- [Menu](#menu)
- [Input](#input)
- [Math and representations](#math-and-representations)
- [Sample output](#sample-output)
- [Calculation log](#calculation-log)
- [Plotting (complex_plot.scm)](#plotting-complex_plotscm)
- [Repository layout](#repository-layout)
- [Limitations and notes](#limitations-and-notes)
- [Roadmap ideas](#roadmap-ideas)
- [License](#license)
- [Acknowledgments](#acknowledgments)

---

## Features

**Arithmetic and analysis**
- addition, subtraction, multiplication, division;
- integer powers (positive, negative and zero);
- **all** n-th roots via De Moivre's formula;
- for every number: `Re(z)`, `Im(z)`, `|z|`, `arg(z)` in radians **and degrees**;
- trigonometric and exponential forms in radians **and degrees**;
- a "full view" of the number — the chain `algebraic = trigonometric = exponential`.

**Interface**
- fully English UI;
- mathematical notation instead of wordy labels: `Re(z)`, `Im(z)`, `|z|`, `arg(z)`;
- the imaginary part is printed as `4.0000*i`;
- adjustable precision: **0–12 decimal places** (default 4);
- decorative output framing (`****`, `<<<< >>>>`, `____`, `----`);
- every operation block shows **both operands** and an `expression` line, so it is always clear what is being multiplied, divided, etc.;
- errors never crash the program: the message is printed inside the frame and the loop continues.

**Logging**
- `complex-lab.log` is created automatically at startup, next to the script;
- append mode — history survives across runs;
- `SESSION START` / `SESSION END` markers and a timestamp for every block;
- everything is recorded: operands, expression, results in all forms, errors, plot file paths.

**Plotting (`complex_plot.scm` only)**
- Argand diagram: vectors from the origin, labelled points, modulus circle;
- n-th roots: all points on the circle `|z|^(1/n)` plus the regular n-gon connecting them;
- automatic PNG export for every operation, with the path written to the log;
- interactive gnuplot window via `[9]` / `[0]`;
- an auto-PNG toggle `[p]` so you don't flood the directory with files;
- graceful behaviour without gnuplot and without a display (headless / SSH).

---

## Two versions

| | `complex.scm` | `complex_plot.scm` |
|---|---|---|
| Arithmetic, powers, roots | ✅ | ✅ |
| All forms, degrees, precision, framing | ✅ | ✅ |
| `complex-lab.log` journal | ✅ | ✅ |
| gnuplot window | — | ✅ `[9]`, `[0]` |
| Auto-PNG + paths in the log | — | ✅ (toggle with `[p]`) |
| External dependencies | Guile only | Guile + gnuplot (optional) |

The calculation logic is identical in both. If gnuplot is missing, `complex_plot.scm` behaves exactly like `complex.scm`, and each block simply shows `plot = skipped (gnuplot not found)`.

---

## Requirements

- **Guile** 2.2+ (3.0 recommended). The modules used — `ice-9 format`, `ice-9 rdelim`, `ice-9 popen` — ship with standard Guile.
- **gnuplot ≥ 5.0** — only for `complex_plot.scm`, and entirely optional:
  - *inline datablocks* (`$D << EOD`) are required, introduced in 5.0;
  - PNG output needs the `pngcairo` terminal;
  - a window needs one of `qt`, `wxt`, `x11` (tried in that order).

Developed on Linux. On Windows, WSL is the easiest path.

---

## Installing dependencies

```bash
# Debian / Ubuntu
sudo apt install guile-3.0 gnuplot

# Fedora
sudo dnf install guile gnuplot

# Arch
sudo pacman -S guile gnuplot

# macOS (Homebrew)
brew install guile gnuplot
```

Verify:

```bash
guile --version
gnuplot --version
```

---

## Running

```bash
https://github.com/medvjj/cli-complex-number-calc.git
cd cli-complex-number-calc

chmod +x complex.scm complex_plot.scm

./complex.scm          # no plotting
./complex_plot.scm     # with plotting
```

Or invoke the interpreter explicitly:

```bash
guile -s complex.scm
guile -s complex_plot.scm
```

> The shebang in both files is `#!/usr/bin/guile -s`. If Guile lives elsewhere (for example `/usr/local/bin/guile` after a Homebrew install), run it via `guile -s ...` or adjust the shebang for your system.

Quit with `q` or `Ctrl-D` (EOF) — the log is closed properly with a `SESSION END` marker.

---

## Menu

| Key | Action | Version |
|---|---|---|
| `1` | Addition `w = z1 + z2` | both |
| `2` | Subtraction `w = z1 - z2` | both |
| `3` | Multiplication `w = z1 * z2` | both |
| `4` | Division `w = z1 / z2` | both |
| `5` | Inspect — all forms of a number | both |
| `6` | Power `w = z^n` | both |
| `7` | Roots `w = z^(1/n)` | both |
| `8` | Display precision (0–12) | both |
| `9` | Plot z — gnuplot window + PNG | `complex_plot.scm` |
| `0` | Plot roots — gnuplot window + PNG | `complex_plot.scm` |
| `p` | Toggle auto-PNG | `complex_plot.scm` |
| `q` | Quit | both |

`q` and `p` are case-insensitive. An empty line just redraws the menu.

---

## Input

A number is entered in two parts:

```
  Enter z1:
    Re(z1) = 3
    Im(z1) = 4
```

- accepted: integers, decimals (`-2.5`), scientific notation (`1e3`), rationals (`1/2`);
- surrounding whitespace is trimmed; empty or invalid input re-prompts;
- complex literals such as `3+4i` are **not** parsed — two real numbers only;
- the exponent `n` and the root degree must be integers;
- limits: power `|n| ≤ 1000`, root degree `1 ≤ n ≤ 100`, precision `0 ≤ d ≤ 12`.

These limits are deliberate: they prevent hangs on huge exponents and thousands of lines / points of output.

---

## Math and representations

Internal representation is a pair `(re . im)`.

```
z = a + b*i

addition:       (a + c) + (b + d)*i
multiplication: (a*c - b*d) + (a*d + b*c)*i
division:       ((a*c + b*d) + (b*c - a*d)*i) / (c^2 + d^2)

modulus:        |z|   = sqrt(a^2 + b^2)
argument:       arg z = atan2(b, a)          [-pi, pi]

trigonometric:  |z| * (cos(arg z) + i*sin(arg z))
exponential:    |z| * e^(i*arg z)

roots (De Moivre):
  z_k = |z|^(1/n) * ( cos((arg z + 2*pi*k)/n)
                    + i*sin((arg z + 2*pi*k)/n) ),   k = 0..n-1
```

Precision affects **display only**: internally everything is computed at full Guile precision (exact rationals and doubles). Display rounding is half-to-even (banker's rounding), matching the standard `round`.

Conventions: `arg(0) = 0`, `z^0 = 1` (including `0^0`), a negative power of zero raises a division-by-zero error.

---

## Sample output

Division of `z1 = 3 + 4i` by `z2 = 1 - 2i`, precision 4 (abridged):

```
************************************************************************
                   <<<<  DIVISION:  w = z1 / z2  >>>>
________________________________________________________________________
  z1             = 3.0000 + 4.0000*i
  |z1|           = 5.0000
  arg(z1)        = 0.9273 rad   (53.1301 deg)

  z2             = 1.0000 - 2.0000*i
  |z2|           = 2.2361
  arg(z2)        = -1.1071 rad   (-63.4349 deg)
------------------------------------------------------------------------
  expression     = (3.0000 + 4.0000*i) / (1.0000 - 2.0000*i)

  w              = -1.0000 + 2.0000*i
  Re(w)          = -1.0000
  Im(w)          = 2.0000
  |w|            = 2.2361
  arg(w)         = 2.0344 rad   (116.5651 deg)
  trig (rad)     = 2.2361 * (cos(2.0344) + i*sin(2.0344))
  trig (deg)     = 2.2361 * (cos(116.5651 deg) + i*sin(116.5651 deg))
  exp (rad)      = 2.2361 * e^(i*2.0344)
  exp (deg)      = 2.2361 * e^(i*116.5651 deg)
  full view:
      w = -1.0000 + 2.0000*i
        = 2.2361 * (cos(116.5651 deg) + i*sin(116.5651 deg))
        = 2.2361 * e^(i*116.5651 deg)
  plot           = /path/to/plot-20261122-142530-12345-3.png
________________________________________________________________________
************************************************************************
```

Cube roots of `z = 8`:

```
  z_0            = 2.0000 + 0.0000*i
  z_1            = -1.0000 + 1.7321*i
  z_2            = -1.0000 - 1.7321*i
```

Division by zero:

```
  !! ERROR: Division by zero: z2 = 0
```

---

## Calculation log

**`complex-lab.log`** appears automatically on startup in the script's directory and is appended to. Each operation is the same block you see on screen, plus a timestamp.

```
=========== SESSION START  2026-11-22 14:25:30 ===========
script dir: /home/user/complex-number-lab
gnuplot: yes | auto PNG: on

[2026-11-22 14:26:04]
************************************************************************
                   <<<<  DIVISION:  w = z1 / z2  >>>>
...
  plot           = /home/user/complex-number-lab/plot-20261122-142530-12345-3.png
...
=========== SESSION END    2026-11-22 14:31:12 ===========
```

Notes:
- errors are logged too, so the journal reflects what actually happened;
- if the directory is not writable, the program does not crash: it warns and keeps working without a log;
- there is no rotation or cleanup — the file grows, prune it manually.

What you should not commit (add to `.gitignore`):

```gitignore
complex-lab.log
plot-*.png
```

---

## Plotting (complex_plot.scm)

What gets drawn:

| Operation | Plot contents |
|---|---|
| `+`, `-`, `*`, `/` | vectors `z1`, `z2`, `w` from the origin, labelled points, circle of the largest modulus |
| `z^n` | vectors `z` and `w` — rotation and scaling made visible |
| Inspect / Plot z | vector `z` and the circle `|z|` |
| Roots / Plot roots | all `z_k` on the circle `|z|^(1/n)` plus the regular n-gon |

Modes:
- **auto-PNG** — on by default: every operation saves `plot-<session>-<n>.png` next to the script, and the path is printed both on screen and into the log. `session` = date-time + PID, so restarts never overwrite earlier images;
- **window** — `[9]` (a number) and `[0]` (roots): a PNG is saved **and** an interactive window opens (`gnuplot -persist`, terminals tried in order `qt` → `wxt` → `x11`);
- **`[p]`** — the auto-PNG toggle. Explicit `[9]` / `[0]` always save an image.

Implementation details worth knowing:
- `set size ratio -1` gives equal axis scaling; without it a circle becomes an ellipse and the geometry lies;
- PNG via `pngcairo` (800×800) works **without a display**