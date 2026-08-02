# ~/.zshenv - 所有 shell 都加载（交互/非交互/脚本/cron/systemd/AI agent）
# 放这里才能让 rm 安全替换在所有场景生效

# 安全删除：rm → trash（进回收站，可恢复）
# 注意：用 function 而非 alias，因为非交互式 shell 默认不展开 alias
if command -v trash >/dev/null 2>&1; then
    function rm {
        # 过滤掉 -r/-f/-rf/-v 等所有选项，trash 本身就递归且无需 -f
        local files=() arg
        for arg in "$@"; do
            case "$arg" in
                -*) ;;            # 跳过所有 - 开头的选项
                *) files+=("$arg") ;;
            esac
        done
        (( ${#files[@]} )) || { echo "rm: missing operand" >&2; return 1; }
        trash "${files[@]}"
    }
fi

# 真正的 rm 后门（绕过 trash，永久删除）
alias rm-real='/bin/rm'

# ranger: 已全量 copy 默认 rc.conf，避免加载两次
export RANGER_LOAD_DEFAULT_RC=FALSE

# sudo rm 也走 trash（文件进 root 用户的回收站）
function sudo {
    if [ "$1" = "rm" ]; then
        shift
        local files=() arg
        for arg in "$@"; do
            case "$arg" in
                -*) ;;
                *) files+=("$arg") ;;
            esac
        done
        (( ${#files[@]} )) || { echo "sudo rm: missing operand" >&2; return 1; }
        command sudo trash "${files[@]}"
    else
        command sudo "$@"
    fi
}
