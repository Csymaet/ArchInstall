"""数据模型：包信息和对比状态。"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class PkgState(Enum):
    MANAGED = "managed"
    LOCAL_ONLY = "local_only"
    CSV_ONLY = "csv_only"


@dataclass(frozen=True, slots=True)
class PkgInfo:
    name: str
    version: str = ""
    description: str = ""
    state: PkgState = PkgState.MANAGED
    category: str = ""
    level: str = ""


@dataclass(frozen=True, slots=True)
class PackageDiff:
    managed: list[PkgInfo]
    local_only: list[PkgInfo]
    csv_only: list[PkgInfo]

    @property
    def all(self) -> list[PkgInfo]:
        return self.managed + self.local_only + self.csv_only

    @property
    def counts(self) -> dict[str, int]:
        return {
            "all": len(self.all),
            "managed": len(self.managed),
            "local_only": len(self.local_only),
            "csv_only": len(self.csv_only),
        }
