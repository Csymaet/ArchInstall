"""数据层：pacman 查询与 CSV 读取。无 Textual 依赖。"""

from __future__ import annotations

import csv
import os
import subprocess
from dataclasses import replace
from pathlib import Path

from constants import CSV_DIR, PACMAN_ENV, PACMAN_INFO_CMD
from models import PackageDiff, PkgInfo, PkgState


class SourceError(Exception):
    """数据获取失败。"""


def fetch_local_packages() -> dict[str, PkgInfo]:
    """查询本机显式安装的包，返回 {包名: PkgInfo}。

    Raises:
        SourceError: pacman 调用失败。
    """
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
    """读取 CSV 目录下所有 .csv，返回 {包名: PkgInfo}。

    CSV 格式：包名,描述,级别
    文件名（去 .csv）作为分类标签。
    """
    packages: dict[str, PkgInfo] = {}
    if not csv_dir.is_dir():
        return packages

    for csv_file in sorted(csv_dir.glob("*.csv")):
        category = csv_file.stem
        with csv_file.open(encoding="utf-8", newline="") as f:
            for row in csv.reader(f):
                if not row or not row[0].strip():
                    continue
                name = row[0].strip()
                desc = row[1].strip() if len(row) > 1 else ""
                level = row[2].strip() if len(row) > 2 else ""
                packages[name] = PkgInfo(
                    name=name,
                    description=desc,
                    category=category,
                    level=level,
                )
    return packages


def diff_packages(
    local: dict[str, PkgInfo],
    csv_pkgs: dict[str, PkgInfo],
) -> PackageDiff:
    """对比本机包与 CSV 包，返回三态结果。"""
    local_names = set(local)
    csv_names = set(csv_pkgs)

    managed: list[PkgInfo] = []
    for name in sorted(local_names & csv_names):
        l = local[name]
        c = csv_pkgs[name]
        managed.append(PkgInfo(
            name=name,
            version=l.version,
            description=c.description or l.description,
            state=PkgState.MANAGED,
            category=c.category,
            level=c.level,
        ))

    local_only: list[PkgInfo] = [
        replace(local[name], state=PkgState.LOCAL_ONLY)
        for name in sorted(local_names - csv_names)
    ]

    csv_only: list[PkgInfo] = [
        replace(csv_pkgs[name], state=PkgState.CSV_ONLY)
        for name in sorted(csv_names - local_names)
    ]

    return PackageDiff(managed=managed, local_only=local_only, csv_only=csv_only)


def gather() -> PackageDiff:
    """一步到位：查 pacman + 读 CSV + 对比。"""
    local = fetch_local_packages()
    csv_pkgs = load_csv_packages()
    return diff_packages(local, csv_pkgs)


def _parse_pacman_block(block: str) -> dict[str, str]:
    """解析 pacman -Qei 输出的单个记录块。"""
    fields: dict[str, str] = {}
    for line in block.splitlines():
        if " : " not in line:
            continue
        key, _, val = line.partition(" : ")
        fields[key.strip()] = val.strip()
    return fields
