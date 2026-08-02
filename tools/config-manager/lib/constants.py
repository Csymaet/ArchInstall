"""常量定义：路径、状态图标、列配置。"""

from __future__ import annotations

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[3]
FILES_DIR: Path = PROJECT_ROOT / "files"
TOML_PATH: Path = Path(__file__).resolve().parents[1] / "configs.toml"

STATUS_SYNCED = "synced"
STATUS_SYSTEM_NEWER = "system_newer"
STATUS_REPO_NEWER = "repo_newer"
STATUS_SYSTEM_ONLY = "system_only"
STATUS_REPO_ONLY = "repo_only"
STATUS_CONFIG_ONLY = "config_only"

FILTER_ALL = "all"
FILTER_SYNCED = "synced"
FILTER_DIFF = "diff"
FILTER_SYSTEM_ONLY = "system_only"
FILTER_REPO_ONLY = "repo_only"
FILTER_CONFIG_ONLY = "config_only"

STATUS_ICONS: dict[str, str] = {
    STATUS_SYNCED: "✅",
    STATUS_SYSTEM_NEWER: "💻",
    STATUS_REPO_NEWER: "📦",
    STATUS_SYSTEM_ONLY: "🔵",
    STATUS_REPO_ONLY: "🟡",
    STATUS_CONFIG_ONLY: "❌",
}

TYPE_ICONS: dict[str, str] = {
    "system": "🖥️",
    "user": "👤",
}

COLUMN_LABELS: list[str] = ["状态", "文件", "系统路径", "更新方", "类型", "阶段"]
