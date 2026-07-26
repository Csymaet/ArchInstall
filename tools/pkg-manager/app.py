"""pkg-manager TUI：对比本机包与 archinstall CSV。"""

from __future__ import annotations

from rich.text import Text

from textual import work
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.reactive import reactive
from textual.widgets import DataTable, Footer, Label

from lib.constants import COLUMN_LABELS, STATE_ICONS
from lib.models import PackageDiff, PkgInfo
from lib.sources import SourceError, gather


class PkgManagerApp(App):
    CSS_PATH = "lib/style.tcss"
    TITLE = "pkg-manager"

    BINDINGS = [
        Binding("q", "quit", "退出"),
        Binding("1", "filter_all", "全部"),
        Binding("2", "filter_managed", "已管理"),
        Binding("3", "filter_local_only", "仅本机"),
        Binding("4", "filter_csv_only", "仅CSV"),
        Binding("r", "refresh", "刷新"),
    ]

    current_filter: reactive[str] = reactive("all")

    def __init__(self) -> None:
        super().__init__()
        self._diff: PackageDiff | None = None
        self._sort_column: str | None = None
        self._sort_desc: bool = False

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

    def on_data_table_header_selected(self, event: DataTable.HeaderSelected) -> None:
        col = event.column_key
        if self._sort_column == col:
            if not self._sort_desc:
                self._sort_desc = True
            else:
                self._sort_column = None
                self._sort_desc = False
        else:
            self._sort_column = col
            self._sort_desc = False
        self._update_headers()
        self._render()

    def watch_current_filter(self, _: str) -> None:
        self._render()

    def action_filter_all(self) -> None:
        self.current_filter = "all"

    def action_filter_managed(self) -> None:
        self.current_filter = "managed"

    def action_filter_local_only(self) -> None:
        self.current_filter = "local_only"

    def action_filter_csv_only(self) -> None:
        self.current_filter = "csv_only"

    def action_refresh(self) -> None:
        self.load_data()

    @work(exclusive=True, thread=True)
    def load_data(self) -> None:
        table = self.query_one(DataTable)
        self.call_from_thread(table.clear)
        try:
            diff = gather()
        except SourceError as e:
            self.call_from_thread(self.notify, f"⚠️ {e}", severity="error", timeout=30)
            diff = PackageDiff([], [], [])
        self._diff = diff
        self.call_from_thread(self._update_stats)
        self.call_from_thread(self._render)

    def _update_stats(self) -> None:
        if not self._diff:
            return
        c = self._diff.counts
        parts = ["[1]全部", "[2]已管理", "[3]仅本机", "[4]仅CSV"]
        counts = [c['all'], c['managed'], c['local_only'], c['csv_only']]
        active = {"all": 0, "managed": 1, "local_only": 2, "csv_only": 3}[self.current_filter]
        rendered = []
        for i, part in enumerate(parts):
            text = f"{part}({counts[i]})"
            if i == active:
                rendered.append(f"[bold $accent]▶ {text}[/]")
            else:
                rendered.append(f"[$text-muted]{text}[/]")
        self.query_one("#stats", Label).update("  ".join(rendered))

    def _update_headers(self) -> None:
        table = self.query_one(DataTable)
        for i, col in enumerate(table.ordered_columns):
            base = COLUMN_LABELS[i]
            if base == self._sort_column:
                arrow = " ▼" if self._sort_desc else " ▲"
                col.label = Text(base + arrow)
            else:
                col.label = Text(base)
        table.refresh()

    def _render(self) -> None:
        table = self.query_one(DataTable)
        table.clear()
        if not self._diff:
            return

        rows = self._visible_rows()
        table.add_rows(
            (
                STATE_ICONS.get(pkg.state.value, "").ljust(5),
                pkg.name,
                pkg.category or "-",
                (pkg.level or "-").ljust(4),
                pkg.version or "-",
                pkg.description,
            )
            for pkg in rows
        )

        if self._sort_column:
            table.sort(self._sort_column, reverse=self._sort_desc)
        self._update_stats()

    def _visible_rows(self) -> list[PkgInfo]:
        if not self._diff:
            return []
        match self.current_filter:
            case "managed":
                return self._diff.managed
            case "local_only":
                return self._diff.local_only
            case "csv_only":
                return self._diff.csv_only
            case _:
                return self._diff.all


def main() -> None:
    PkgManagerApp().run()


if __name__ == "__main__":
    main()
