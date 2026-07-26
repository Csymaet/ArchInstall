"""常量定义：路径、命令、列配置。"""

from __future__ import annotations

import os
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[3]
CSV_DIR: Path = Path(os.environ.get(
    "ARCHINSTALL_CSV_DIR",
    PROJECT_ROOT / "apps",
))

PACMAN_INFO_CMD: list[str] = ["pacman", "-Qei"]
PACMAN_ENV: dict[str, str] = {"LC_ALL": "C", "LANG": "C"}

FILTER_ALL = "all"
FILTER_MANAGED = "managed"
FILTER_LOCAL_ONLY = "local_only"
FILTER_CSV_ONLY = "csv_only"

FILTER_LABELS: dict[str, str] = {
    FILTER_ALL: "全部",
    FILTER_MANAGED: "已管理",
    FILTER_LOCAL_ONLY: "仅本机",
    FILTER_CSV_ONLY: "仅CSV",
}

STATE_ICONS: dict[str, str] = {
    FILTER_MANAGED: "✅",
    FILTER_LOCAL_ONLY: "📦",
    FILTER_CSV_ONLY: "📋",
}

COLUMN_LABELS: list[str] = ["状态", "包名", "分类", "级别", "版本", "描述"]
