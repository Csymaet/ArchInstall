"""config-manager TUI：对比仓库配置文件与系统配置文件。"""

from __future__ import annotations

import os

from rich.text import Text
from textual import work
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.reactive import reactive
from textual.screen import Screen
from textual.widgets import DataTable, Footer, Label, RichLog

from lib.constants import COLUMN_LABELS, STATUS_ICONS, TYPE_ICONS
from lib.models import CfgStatus, ConfigDiff, ConfigEntry
from lib.sources import SourceError, gather, get_diff_text


class DiffScreen(Screen):
    BINDINGS = [
        Binding("escape", "pop_screen", show=False),
        Binding("q", "pop_screen", "返回"),
        Binding("d", "pop_screen", show=False),
    ]

    def __init__(self, entry: ConfigEntry) -> None:
        super().__init__()
        self._entry = entry

    def compose(self) -> ComposeResult:
        icon = STATUS_ICONS.get(self._entry.status.value, "")
        yield Label(f"{icon} {self._entry.name}", classes="title")
        yield Label(f"仓库: files/{self._entry.source}", classes="meta")
        yield Label(f"系统: {self._entry.target}", classes="meta")
        yield RichLog()

    def on_mount(self) -> None:
        log = self.query_one(RichLog)
        diff = get_diff_text(self._entry)
        if not diff:
            log.write("（双方均不存在，无内容可对比）")
            return
        for line in diff.split("\n"):
            if line.startswith("+++") or line.startswith("---"):
                log.write(Text(line, style="bold"))
            elif line.startswith("+"):
                log.write(Text(line, style="green"))
            elif line.startswith("-"):
                log.write(Text(line, style="red"))
            elif line.startswith("@@"):
                log.write(Text(line, style="cyan"))
            else:
                log.write(line)

    def action_pop_screen(self) -> None:
        self.app.pop_screen()


class ConfigManagerApp(App):
    CSS_PATH = "lib/style.tcss"
    TITLE = "config-manager"

    BINDINGS = [
        Binding("q", "quit", "退出"),
        Binding("1", "filter_all", "全部"),
        Binding("2", "filter_synced", "已同步"),
        Binding("3", "filter_diff", "有差异"),
        Binding("4", "filter_system_only", "仅系统"),
        Binding("5", "filter_repo_only", "仅仓库"),
        Binding("6", "filter_config_only", "仅配置"),
        Binding("d", "show_diff", "对比"),
        Binding("j", "cursor_down", "↓"),
        Binding("k", "cursor_up", "↑"),
    ]

    current_filter: reactive[str] = reactive("all")

    def __init__(self) -> None:
        super().__init__()
        self._diff: ConfigDiff | None = None
        self._entries: list[ConfigEntry] = []

    def compose(self) -> ComposeResult:
        yield Label("", id="stats")
        yield DataTable(id="table")
        yield Footer()

    def on_mount(self) -> None:
        table = self.query_one(DataTable)
        for label in COLUMN_LABELS:
            table.add_column(label, key=label)
        table.cursor_type = "row"
        table.focus()
        self.load_data()

    def watch_current_filter(self, _: str) -> None:
        self._render()

    def action_filter_all(self) -> None:
        self.current_filter = "all"

    def action_filter_synced(self) -> None:
        self.current_filter = "synced"

    def action_filter_diff(self) -> None:
        self.current_filter = "diff"

    def action_filter_system_only(self) -> None:
        self.current_filter = "system_only"

    def action_filter_repo_only(self) -> None:
        self.current_filter = "repo_only"

    def action_filter_config_only(self) -> None:
        self.current_filter = "config_only"

    def action_cursor_down(self) -> None:
        self.query_one(DataTable).action_cursor_down()

    def action_cursor_up(self) -> None:
        self.query_one(DataTable).action_cursor_up()

    def action_show_diff(self) -> None:
        table = self.query_one(DataTable)
        if table.cursor_row < 0 or table.cursor_row >= len(self._entries):
            return
        entry = self._entries[table.cursor_row]
        self.push_screen(DiffScreen(entry))

    @work(exclusive=True, thread=True)
    def load_data(self) -> None:
        table = self.query_one(DataTable)
        self.call_from_thread(table.clear)
        try:
            diff = gather()
        except SourceError as e:
            self.call_from_thread(self.notify, f"⚠️ {e}", severity="error", timeout=30)
            diff = ConfigDiff(entries=[])
        self._diff = diff
        self.call_from_thread(self._render)

    def _update_stats(self) -> None:
        if not self._diff:
            return
        c = self._diff.counts
        parts = ["[1]全部", "[2]已同步", "[3]有差异", "[4]仅系统", "[5]仅仓库", "[6]仅配置"]
        counts = [c['all'], c['synced'], c['diff'], c['system_only'], c['repo_only'], c['config_only']]
        active_map = {"all": 0, "synced": 1, "diff": 2, "system_only": 3, "repo_only": 4, "config_only": 5}
        active = active_map[self.current_filter]
        rendered = []
        for i, part in enumerate(parts):
            text = f"{part}({counts[i]})"
            if i == active:
                rendered.append(f"[bold $accent]▶ {text}[/]")
            else:
                rendered.append(f"[$text-muted]{text}[/]")
        self.query_one("#stats", Label).update("  ".join(rendered))

    def _render(self) -> None:
        table = self.query_one(DataTable)
        table.clear()
        if not self._diff:
            return

        entries = self._visible_entries()
        self._entries = entries
        table.add_rows(
            (
                STATUS_ICONS.get(e.status.value, "").ljust(5),
                e.name,
                _target_dir(e.target),
                _newer_side(e.status),
                TYPE_ICONS.get(e.cfg_type, ""),
                e.stage,
            )
            for e in entries
        )
        self._update_stats()

    def _visible_entries(self) -> list[ConfigEntry]:
        if not self._diff:
            return []
        match self.current_filter:
            case "synced":
                return self._diff.synced
            case "diff":
                return self._diff.diff
            case "system_only":
                return self._diff.system_only
            case "repo_only":
                return self._diff.repo_only
            case "config_only":
                return self._diff.config_only
            case _:
                return self._diff.entries


def _newer_side(status: CfgStatus) -> str:
    if status in (CfgStatus.SYSTEM_NEWER, CfgStatus.SYSTEM_ONLY):
        return "系统"
    if status in (CfgStatus.REPO_NEWER, CfgStatus.REPO_ONLY):
        return "仓库"
    return "-"


def _target_dir(path: str) -> str:
    expanded = os.path.expanduser(path)
    parent = os.path.dirname(expanded)
    home = os.path.expanduser("~")
    if parent.startswith(home):
        parent = "~" + parent[len(home):]
    return parent + "/"


def main() -> None:
    ConfigManagerApp().run()


if __name__ == "__main__":
    main()
