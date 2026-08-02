"""数据模型：配置条目与对比状态。"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class CfgStatus(Enum):
    SYNCED = "synced"
    SYSTEM_NEWER = "system_newer"
    REPO_NEWER = "repo_newer"
    SYSTEM_ONLY = "system_only"
    REPO_ONLY = "repo_only"
    CONFIG_ONLY = "config_only"


@dataclass(frozen=True, slots=True)
class ConfigEntry:
    source: str
    target: str
    stage: str
    name: str
    cfg_type: str
    status: CfgStatus
    source_path: str
    target_path: str
    perm_ok: bool | None


@dataclass(frozen=True, slots=True)
class ConfigDiff:
    entries: list[ConfigEntry]

    @property
    def synced(self) -> list[ConfigEntry]:
        return [e for e in self.entries if e.status is CfgStatus.SYNCED]

    @property
    def diff(self) -> list[ConfigEntry]:
        return [
            e for e in self.entries
            if e.status in (CfgStatus.SYSTEM_NEWER, CfgStatus.REPO_NEWER)
            or e.perm_ok is False
        ]

    @property
    def system_only(self) -> list[ConfigEntry]:
        return [e for e in self.entries if e.status is CfgStatus.SYSTEM_ONLY]

    @property
    def repo_only(self) -> list[ConfigEntry]:
        return [e for e in self.entries if e.status is CfgStatus.REPO_ONLY]

    @property
    def config_only(self) -> list[ConfigEntry]:
        return [e for e in self.entries if e.status is CfgStatus.CONFIG_ONLY]

    @property
    def counts(self) -> dict[str, int]:
        return {
            "all": len(self.entries),
            "synced": len(self.synced),
            "diff": len(self.diff),
            "system_only": len(self.system_only),
            "repo_only": len(self.repo_only),
            "config_only": len(self.config_only),
        }
