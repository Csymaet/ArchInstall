"""数据模型：包信息和对比状态。无 Textual 依赖。"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class PkgState(Enum):
    """包的三态分类。"""
    MANAGED = "managed"        # 本机有 + CSV 有
    LOCAL_ONLY = "local_only"  # 仅本机
    CSV_ONLY = "csv_only"      # 仅 CSV


@dataclass(frozen=True, slots=True)
class PkgInfo:
    """单个包的完整信息。"""
    name: str
    version: str = ""
    description: str = ""
    state: PkgState = PkgState.MANAGED
    category: str = ""        # CSV 来源分类（base/tools/dev/...）
    level: str = ""           # 必装/默认/可选（仅 CSV 包有）


@dataclass(frozen=True, slots=True)
class PackageDiff:
    """三态对比结果。"""
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
