#!/usr/bin/env python3
"""Offline unit tests for sutra_xen: virt detection (fake sysfs trees +
an injected systemd-detect-virt callable), the balloon reader, and the
host-telemetry cache. No real hardware, no network."""
import os
import sys
import tempfile

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import sutra
import sutra_xen as sx

fails = 0


def check(name, cond):
    global fails
    print(("ok: " if cond else "FAIL: ") + name)
    if not cond:
        fails += 1


class FakeProc:
    def __init__(self, stdout):
        self.stdout = stdout


def run_says(name):
    return lambda *a, **k: FakeProc(name)


def run_missing(*a, **k):
    raise FileNotFoundError("no systemd-detect-virt here")


# --- virt detection: systemd-detect-virt answers directly ------------------
check("detect-virt xen", sx.virt_type(run=run_says("xen\n")) == "xen")
check("detect-virt none", sx.virt_type(run=run_says("none\n")) == "none")
check("detect-virt other honestly reported",
      sx.virt_type(run=run_says("kvm\n")) == "kvm")

with tempfile.TemporaryDirectory() as td:
    proc_xen = os.path.join(td, "proc_xen")
    hv_type = os.path.join(td, "hv_type")
    dmi_vendor = os.path.join(td, "dmi_vendor")

    # no binary, no fake signals present -> none
    check("fallback: no signals -> none",
          sx.virt_type(proc_xen=proc_xen, hypervisor_type=hv_type,
                       dmi_vendor=dmi_vendor, run=run_missing) == "none")

    # fallback: /proc/xen present
    os.mkdir(proc_xen)
    check("fallback: /proc/xen dir -> xen",
          sx.virt_type(proc_xen=proc_xen, hypervisor_type=hv_type,
                       dmi_vendor=dmi_vendor, run=run_missing) == "xen")
    os.rmdir(proc_xen)

    # fallback: /sys/hypervisor/type
    with open(hv_type, "w") as f:
        f.write("xen\n")
    check("fallback: hypervisor_type -> xen",
          sx.virt_type(proc_xen=proc_xen, hypervisor_type=hv_type,
                       dmi_vendor=dmi_vendor, run=run_missing) == "xen")
    os.remove(hv_type)

    # fallback: DMI vendor string, case-insensitive
    with open(dmi_vendor, "w") as f:
        f.write("Xen\n")
    check("fallback: dmi vendor -> xen",
          sx.virt_type(proc_xen=proc_xen, hypervisor_type=hv_type,
                       dmi_vendor=dmi_vendor, run=run_missing) == "xen")

    # systemd-detect-virt wins over a fake xen fallback signal (still there)
    check("detect-virt takes priority over fallback signals",
          sx.virt_type(proc_xen=proc_xen, hypervisor_type=hv_type,
                       dmi_vendor=dmi_vendor, run=run_says("none\n")) == "none")

# is_guest
check("is_guest(xen)", sx.is_guest("xen") is True)
check("is_guest(none)", sx.is_guest("none") is False)
check("is_guest(kvm) - any real hypervisor counts", sx.is_guest("kvm") is True)
# live, whatever this box actually is right now (never hard-code a specific
# hypervisor here: dev boxes migrate, and a "must be Xen" assertion is a
# flaky test waiting to fire the day it isn't -- exactly what happened to
# the previous version of this line). Real signature: consistent with a
# real virt_type() call, and it doesn't raise.
live_vtype = sx.virt_type()
check(f"is_guest() live on this box (virt_type={live_vtype!r})",
      sx.is_guest() == (live_vtype not in (None, "none")))


# --- balloon reader ---------------------------------------------------------
with tempfile.TemporaryDirectory() as td:
    xen_mem = os.path.join(td, "xen_memory0")
    os.mkdir(xen_mem)
    meminfo = os.path.join(td, "meminfo")

    # neither surface present -> all None
    check("balloon: absent -> None",
          sx.balloon_target_kb(xen_mem) is None)
    check("balloon_headroom: absent -> (None, None, None)",
          sx.balloon_headroom_kb(xen_mem, meminfo) == (None, None, None))

    # real fixture numbers from this box tonight
    with open(os.path.join(xen_mem, "target_kb"), "w") as f:
        f.write("16776828\n")
    check("balloon_target_kb reads target",
          sx.balloon_target_kb(xen_mem) == 16776828)

    # target present, meminfo missing -> (target, None, None)
    check("balloon_headroom: no meminfo -> target only",
          sx.balloon_headroom_kb(xen_mem, meminfo) == (16776828, None, None))

    with open(meminfo, "w") as f:
        f.write("MemTotal:       16077724 kB\n"
                "MemFree:         1234567 kB\n")
    check("balloon_headroom: full triple",
          sx.balloon_headroom_kb(xen_mem, meminfo) ==
          (16776828, 16077724, 16776828 - 16077724))


# --- host-telemetry cache ----------------------------------------------------
with tempfile.TemporaryDirectory() as td:
    status_path = os.path.join(td, "host_status.json")

    doc = sx.refresh_host_telemetry(status_path, lambda: {"thermal": 42})
    check("refresh_host_telemetry caches the fetched doc",
          doc == {"thermal": 42})
    check("refresh_host_telemetry wrote status.json",
          sutra.read_status(status_path) == {"thermal": 42})

    # a non-dict fetch result is rejected, existing cache untouched
    doc = sx.refresh_host_telemetry(status_path, lambda: ["not", "a", "dict"])
    check("refresh_host_telemetry rejects non-dict", doc is None)
    check("refresh_host_telemetry leaves cache untouched on bad shape",
          sutra.read_status(status_path) == {"thermal": 42})

    # a raising fetch (the unbuilt transport, today) never crashes the caller
    def boom():
        raise ConnectionError("XEN.md not landed yet")
    doc = sx.refresh_host_telemetry(status_path, boom)
    check("refresh_host_telemetry survives a raising fetch", doc is None)
    check("refresh_host_telemetry leaves cache untouched on fetch error",
          sutra.read_status(status_path) == {"thermal": 42})


print("XEN-UNIT " + ("OK" if fails == 0 else f"FAILED ({fails})"))
sys.exit(1 if fails else 0)
