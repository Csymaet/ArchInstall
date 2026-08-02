"""数据层：读取 TOML 映射表，对比仓库与系统文件。"""

from __future__ import annotations

import hashlib
import subprocess
import tomllib
from pathlib import Path

from .constants import FILES_DIR, TOML_PATH
from .models import CfgStatus, ConfigDiff, ConfigEntry


class SourceError(Exception):
    pass


def gather() -> ConfigDiff:
    raw = _load_toml()
    entries: list[ConfigEntry] = []
    for item in raw:
        source = item["source"]
        target = item["target"]
        stage = item.get("stage", "config")

        source_path = FILES_DIR / source
        target_path = Path(target).expanduser()

        name = _derive_name(source)
        cfg_type = _infer_type(target)
        status = _compare(source_path, target_path)

        entries.append(ConfigEntry(
            source=source,
            target=target,
            stage=stage,
            name=name,
            cfg_type=cfg_type,
            status=status,
            source_path=str(source_path),
            target_path=str(target_path),
        ))

    entries.sort(key=lambda e: e.name)
    return ConfigDiff(entries=entries)


def get_diff_text(entry: ConfigEntry) -> str | None:
    import difflib

    source_lines = _read_lines(entry.source_path)
    target_lines = _read_lines(entry.target_path)

    if source_lines is None and target_lines is None:
        return None

    diff = difflib.unified_diff(
        source_lines or [],
        target_lines or [],
        fromfile=f"repo: {entry.source}",
        tofile=f"sys:  {entry.target}",
        lineterm="",
    )
    return "\n".join(diff)


def _load_toml() -> list[dict]:
    if not TOML_PATH.is_file():
        raise SourceError(f"找不到配置文件: {TOML_PATH}")
    with TOML_PATH.open("rb") as f:
        data = tomllib.load(f)
    return data.get("configs", [])


def _compare(source: Path, target: Path) -> CfgStatus:
    s_exists = source.is_file()
    t_exists = target.is_file()

    if not s_exists and not t_exists:
        return CfgStatus.MISSING
    if not s_exists:
        return CfgStatus.SYSTEM_ONLY
    if not t_exists:
        return CfgStatus.REPO_ONLY

    s_hash = _file_hash(source)
    t_hash = _file_hash(target)
    if s_hash == t_hash:
        return CfgStatus.SYNCED

    if source.stat().st_mtime > target.stat().st_mtime:
        return CfgStatus.REPO_NEWER
    return CfgStatus.SYSTEM_NEWER


def _file_hash(path: Path) -> str:
    try:
        data = path.read_bytes()
    except PermissionError:
        data = _sudo_read_bytes(path)
    return hashlib.sha256(data).hexdigest()


def _derive_name(source: str) -> str:
    parts = source.split("/", 1)
    if len(parts) == 2 and parts[0] in ("root", "eli"):
        return parts[1]
    return source


def _infer_type(target: str) -> str:
    expanded = Path(target).expanduser()
    home = Path.home()
    if expanded.is_relative_to(home):
        return "user"
    return "system"


def _read_lines(path: str) -> list[str] | None:
    p = Path(path)
    if not p.is_file():
        return None
    try:
        text = p.read_text(encoding="utf-8", errors="replace")
    except PermissionError:
        text = _sudo_read_text(p)
        if text is None:
            return None
    return text.splitlines()


def _sudo_read_bytes(path: Path) -> bytes:
    result = subprocess.run(
        ["sudo", "-n", "cat", str(path)],
        capture_output=True,
        timeout=10,
    )
    return result.stdout


def _sudo_read_text(path: Path) -> str | None:
    result = subprocess.run(
        ["sudo", "-n", "cat", str(path)],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=10,
    )
    if result.returncode != 0:
        return None
    return result.stdout
