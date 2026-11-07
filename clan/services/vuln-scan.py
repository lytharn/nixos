# Nightly CVE diff for every host that reports to deploy-report: scan the deployed system and
# the same config rebuilt with its flake inputs updated (`nix flake update`) with vulnix, and
# alert (ntfy) on what the update would fix. Configured through the environment by
# clan/services/vuln-scan.nix.
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.request
from pathlib import Path

REPORTS = Path(os.environ.get("REPORTS_DIR", "/var/lib/deploy-report"))
STATE = Path(os.environ["STATE_DIRECTORY"])
# Inputs left at their locked rev (e.g. private ones serx can't fetch without a token).
KEEP_INPUTS = set(os.environ.get("KEEP_INPUTS", "").split())
STALE_DAYS = int(os.environ["STALE_DAYS"])
NTFY_URL = os.environ["NTFY_URL"]
NIX = ["nix", "--extra-experimental-features", "nix-command flakes"]


def run(cmd, **kwargs):
    p = subprocess.run(cmd, capture_output=True, text=True, **kwargs)
    if p.returncode != 0:
        raise RuntimeError(f"{error_summary(p.stderr) or f'{cmd[0]} exited {p.returncode}'}\n"
                           f"{p.stderr.strip()[-1500:]}")
    return p.stdout


def error_summary(stderr):
    """Nix's last "error:" line; the stack trace before it is rarely the point. A bare "error:"
    (e.g. failed assertions) gets the first line with content after it."""
    lines = [line.strip() for line in stderr.splitlines()]
    starts = [i for i, line in enumerate(lines) if line.startswith("error:")]
    if not starts:
        return None
    first = lines[starts[-1]]
    if first == "error:":
        rest = [line for line in lines[starts[-1] + 1:] if line and line != "Failed assertions:"]
        if rest:
            more = sum(line.startswith("- ") for line in rest) - 1
            first = f"error: {rest[0]}" + (f" (+{more} more)" if more > 0 else "")
    return first


def vulnix(path):
    """CVE id -> {cve, packages, score, description} for the runtime closure of path."""
    p = subprocess.run(
        ["vulnix", "-C", "--json", "-D", "-c", str(STATE / "nvd-cache"), path],
        capture_output=True,
        text=True,
    )
    # vulnix exits 2 when it found anything, 0 when it found nothing.
    if p.returncode not in (0, 2):
        raise RuntimeError(f"vulnix failed on {path}:\n{p.stderr.strip()[-1500:]}")
    cves = {}
    for pkg in json.loads(p.stdout or "[]"):
        # Extra outputs like firefox-157.0-fish-completions parse with the suffix as part of
        # the version, which then matches CVEs the real package (scanned too) is fixed for.
        if re.search(r"-[a-z]", pkg["version"]):
            continue
        for cve in pkg["affected_by"]:
            entry = cves.setdefault(cve, {
                "cve": cve,
                "packages": [],
                "pnames": [],
                "score": (pkg.get("cvssv3_basescore") or {}).get(cve),
                "description": (pkg.get("description") or {}).get(cve, ""),
            })
            entry["packages"].append(pkg["name"])
            if pkg["pname"] not in entry["pnames"]:
                entry["pnames"].append(pkg["pname"])
    return cves


def root_inputs(lock):
    """Root input name -> its locked attrs."""
    return {
        name: lock["nodes"][node]["locked"]
        for name, node in lock["nodes"][lock["root"]]["inputs"].items()
        if isinstance(node, str)  # skip `follows` entries
    }


def updated_lock(flake, workdir):
    """Copy flake into workdir and update its inputs; returns the new flake.lock."""
    run(["cp", "-r", "--no-preserve=mode", f"{flake}/.", str(workdir)])
    lock = json.loads((workdir / "flake.lock").read_text())
    names = sorted(set(root_inputs(lock)) - KEEP_INPUTS)
    run(NIX + ["flake", "update", *names, "--flake", f"path:{workdir}"])
    return json.loads((workdir / "flake.lock").read_text())


def read(path, default=""):
    try:
        return path.read_text()
    except FileNotFoundError:
        return default


def iso(ts):
    return time.strftime("%Y-%m-%d", time.gmtime(ts))


def scan_host(host, hostdir, info):
    """Fill info with the host's scan results; raises on failure, leaving what it got so far."""
    system = os.path.realpath(hostdir / "system")
    flake = os.path.realpath(hostdir / "flake")
    nixpkgs = root_inputs(json.loads((Path(flake) / "flake.lock").read_text()))["nixpkgs"]
    state = STATE / "hosts" / host
    state.mkdir(parents=True, exist_ok=True)
    info.update({
        "system": system,
        "nixpkgs": {"rev": nixpkgs["rev"], "date": iso(nixpkgs["lastModified"])},
        "nixpkgsAgeDays": int((time.time() - nixpkgs["lastModified"]) // 86400),
        "deployedSince": read(hostdir / "since").strip(),
        "lastSeen": read(hostdir / "last-seen").strip(),
    })

    # vulnix reads package names/versions from the derivations, which a system copied from
    # another host lacks: re-instantiate it from its reported source (same .drv, eval is pure).
    deriver = run(["nix-store", "--query", "--deriver", system]).strip()
    if not os.path.exists(deriver):
        drv = run(NIX + [
            "eval", "--raw",
            f"path:{flake}#nixosConfigurations.{host}.config.system.build.toplevel.drvPath",
        ]).strip()
        if drv != deriver or not os.path.exists(deriver):
            raise RuntimeError(f"error: can't recreate {host}'s derivation (got {drv}, deployed {deriver})")
    current = vulnix(system)
    info["cves"] = len(current)
    link = state / "updated"
    with tempfile.TemporaryDirectory(dir=STATE) as tmp:
        workdir = Path(tmp)
        lock = updated_lock(flake, workdir)
        target = root_inputs(lock)["nixpkgs"]
        info["updatedNixpkgs"] = {"rev": target["rev"], "date": iso(target["lastModified"])}
        # Rebuild only when the deployed source or the updated lock changed; the out-link keeps
        # the updated system alive between runs.
        key = f"{flake} " + hashlib.sha256(json.dumps(lock, sort_keys=True).encode()).hexdigest()
        if read(state / "updated-key") != key or not link.exists():
            run(NIX + [
                "build", "--out-link", str(link),
                f"path:{workdir}#nixosConfigurations.{host}.config.system.build.toplevel",
            ])
            (state / "updated-key").write_text(key)
    updated = vulnix(os.path.realpath(link))

    fixed = [current[c] for c in sorted(set(current) - set(updated))]
    fixed.sort(key=lambda e: -(e["score"] or 0))
    info.update({
        "status": "ok",
        "fixed": fixed,
        "introduced": sorted(set(updated) - set(current)),
    })


def alert_lines(host, info):
    """What's worth pushing for this host tonight, tracking state so nothing repeats nightly."""
    state = STATE / "hosts" / host
    lines = []

    error = info.get("error")
    if error:
        if read(state / "error").splitlines()[:1] != error.splitlines()[:1]:
            lines.append(f"{host}: scan failed: {error.splitlines()[0]}")
        (state / "error").write_text(error)
        return lines
    (state / "error").unlink(missing_ok=True)

    # Fixable CVEs: alert only when ones we haven't alerted about appear.
    fixed = [e["cve"] for e in info["fixed"]]
    alerted = set(read(state / "alerted").split())
    new = [c for c in fixed if c not in alerted]
    if new:
        # Per package: how many fixed CVEs, and the highest score among them.
        by_pkg = {}
        for e in info["fixed"]:
            for pname in e["pnames"]:
                count, top = by_pkg.get(pname, (0, 0))
                by_pkg[pname] = (count + 1, max(top, e["score"] or 0))
        ranked = sorted(by_pkg.items(), key=lambda kv: (-kv[1][1], -kv[1][0]))
        pkgs = ", ".join(f"{name} {count} (max {top or '?'})" for name, (count, top) in ranked[:6])
        more = f", +{len(ranked) - 6} more packages" if len(ranked) > 6 else ""
        lines.append(f"{host}: updating fixes {len(fixed)} CVEs ({len(new)} new): {pkgs}{more}")
    (state / "alerted").write_text("\n".join(fixed))

    # Staleness: once when the host's nixpkgs crosses the threshold, reset by an update.
    age = info["nixpkgsAgeDays"]
    if age > STALE_DAYS:
        if not (state / "stale").exists():
            lines.append(f"{host}: nixpkgs is {age} days old (from {info['nixpkgs']['date']})")
            (state / "stale").touch()
    else:
        (state / "stale").unlink(missing_ok=True)
    return lines


def push(title, body):
    token = (Path(os.environ["CREDENTIALS_DIRECTORY"]) / "ntfy-token").read_text().strip()
    req = urllib.request.Request(NTFY_URL, data=body.encode(), headers={
        "Authorization": f"Bearer {token}",
        "Title": title,
        "Tags": "shield",
    })
    for attempt in range(5):
        try:
            urllib.request.urlopen(req, timeout=30)
            return
        except OSError as e:
            print(f"ntfy push failed ({e}), retrying", file=sys.stderr)
            time.sleep(30)
    raise RuntimeError("could not push the ntfy alert")


def main():
    report = {"generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "hosts": {}}
    lines = []
    for hostdir in sorted(p for p in REPORTS.iterdir() if (p / "system").exists()):
        host = hostdir.name
        info = {}
        try:
            scan_host(host, hostdir, info)
            print(f"{host}: {info['cves']} CVEs, {len(info['fixed'])} fixed by the update "
                  f"(nixpkgs {info['nixpkgs']['date']} -> {info['updatedNixpkgs']['date']})")
        except Exception as e:  # one host failing must not stop the others
            info.update({"status": "error", "error": str(e)})
            print(f"{host}: {e}", file=sys.stderr)
        report["hosts"][host] = info
        lines += alert_lines(host, info)

    tmp = STATE / "report.json.tmp"
    tmp.write_text(json.dumps(report, indent=2))
    tmp.replace(STATE / "report.json")

    if lines:
        fixes = any(": updating fixes " in line for line in lines)
        push("Security updates available" if fixes else "Update check", "\n".join(lines))


if __name__ == "__main__":
    main()
