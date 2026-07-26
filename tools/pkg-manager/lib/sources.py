"""数据层：pacman 查询与 CSV 读取。"""

from __future__ import annotations

import csv
import os
import subprocess
from dataclasses import replace
from pathlib import Path

from .constants import CSV_DIR, PACMAN_ENV, PACMAN_INFO_CMD
from .models import PackageDiff, PkgInfo, PkgState


class SourceError(Exception):
    pass


def fetch_local_packages() -> dict[str, PkgInfo]:
    try:
        result = subprocess.run(
            PACMAN_INFO_CMD,
            capture_output=True,
            text=True,
            encoding="utf-8",
            check=True,
            timeout=15,
            env={**os.environ, **PACMAN_ENV},
        )
    except FileNotFoundError:
        raise SourceError("找不到 pacman，此工具仅支持 Arch 系")
    except subprocess.TimeoutExpired:
        raise SourceError("pacman 响应超时")
    except subprocess.CalledProcessError as e:
        raise SourceError(f"pacman 退出码 {e.returncode}")

    packages: dict[str, PkgInfo] = {}
    for block in result.stdout.strip().split("\n\n"):
        fields = _parse_pacman_block(block)
        name = fields.get("Name", "")
        if not name:
            continue
        packages[name] = PkgInfo(
            name=name,
            version=fields.get("Version", ""),
            description=fields.get("Description", ""),
        )
    return packages


def load_csv_packages(csv_dir: Path = CSV_DIR) -> dict[str, PkgInfo]:
    packages: dict[str, PkgInfo] = {}
    if not csv_dir.is_dir():
        return packages

    groups = _load_package_groups()

    for csv_file in sorted(csv_dir.glob("*.csv")):
        category = csv_file.stem
        with csv_file.open(encoding="utf-8", newline="") as f:
            for row in csv.reader(f):
                if not row or not row[0].strip():
                    continue
                name = row[0].strip()
                desc = row[1].strip() if len(row) > 1 else ""
                level = row[2].strip() if len(row) > 2 else ""
                for member in groups.get(name, [name]):
                    packages[member] = PkgInfo(
                        name=member,
                        description=desc,
                        category=category,
                        level=level,
                    )
    return packages


def _load_package_groups() -> dict[str, list[str]]:
    try:
        result = subprocess.run(
            ["pacman", "-Sgg"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            env={**os.environ, **PACMAN_ENV},
            timeout=10,
        )
    except Exception:
        return {}

    groups: dict[str, list[str]] = {}
    for line in result.stdout.splitlines():
        parts = line.split(maxsplit=1)
        if len(parts) == 2:
            groups.setdefault(parts[0], []).append(parts[1])
    return groups


def diff_packages(
    local: dict[str, PkgInfo],
    csv_pkgs: dict[str, PkgInfo],
) -> PackageDiff:
    local_names = set(local)
    csv_names = set(csv_pkgs)

    managed = [
        PkgInfo(
            name=name,
            version=local[name].version,
            description=csv_pkgs[name].description or local[name].description,
            state=PkgState.MANAGED,
            category=csv_pkgs[name].category,
            level=csv_pkgs[name].level,
        )
        for name in sorted(local_names & csv_names)
    ]

    local_only = [
        replace(local[name], state=PkgState.LOCAL_ONLY)
        for name in sorted(local_names - csv_names)
    ]

    csv_only = [
        replace(csv_pkgs[name], state=PkgState.CSV_ONLY)
        for name in sorted(csv_names - local_names)
    ]

    return PackageDiff(managed=managed, local_only=local_only, csv_only=csv_only)


def gather() -> PackageDiff:
    return diff_packages(fetch_local_packages(), load_csv_packages())


def _parse_pacman_block(block: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for line in block.splitlines():
        if " : " not in line:
            continue
        key, _, val = line.partition(" : ")
        fields[key.strip()] = val.strip()
    return fields
