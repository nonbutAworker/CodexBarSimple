#!/bin/zsh

set -euo pipefail

script_directory="${0:A:h}"
source_app="$script_directory/CodexBarSimple.app"
current_user_id="$(/usr/bin/id -u)"
current_user_home="${HOME:?}"
target_directory="$current_user_home/Applications"
target_app="$target_directory/CodexBarSimple.app"
target_executable="$target_app/Contents/MacOS/CodexBarSimple"
launch_agent_directory="$current_user_home/Library/LaunchAgents"
launch_agent_label="app.codexbarsimple.CodexBarSimple"
launch_agent_path="$launch_agent_directory/$launch_agent_label.plist"
launch_agent_domain="gui/$current_user_id"

show_error() {
    /usr/bin/osascript -e "display alert \"CodexBarSimple 安装失败\" message \"$1\" as critical"
}

if [[ "$(/usr/bin/uname -m)" != "arm64" ]]; then
    show_error "这个版本只支持 Apple Silicon Mac。"
    exit 1
fi

if [[ ! -d "$source_app" ]]; then
    show_error "安装包中缺少 CodexBarSimple.app。"
    exit 1
fi

if ! /usr/bin/codesign --verify --deep --strict "$source_app"; then
    show_error "应用完整性校验失败，请重新获取安装包。"
    exit 1
fi

/bin/mkdir -p "$target_directory" "$launch_agent_directory"
/bin/launchctl bootout "$launch_agent_domain/$launch_agent_label" >/dev/null 2>&1 || true
/usr/bin/pkill -x CodexBarSimple 2>/dev/null || true

/usr/bin/ditto "$source_app" "$target_app"
/usr/bin/xattr -dr com.apple.quarantine "$target_app"
/bin/chmod 755 "$target_executable"

if ! /usr/bin/codesign --verify --deep --strict "$target_app"; then
    show_error "安装后完整性校验失败。"
    exit 1
fi

/usr/bin/plutil -create xml1 "$launch_agent_path"
/usr/bin/plutil -insert Label -string "$launch_agent_label" "$launch_agent_path"
/usr/bin/plutil -insert ProgramArguments -json '[]' "$launch_agent_path"
/usr/bin/plutil -insert ProgramArguments.0 -string "$target_executable" "$launch_agent_path"
/usr/bin/plutil -insert RunAtLoad -bool true "$launch_agent_path"
/usr/bin/plutil -insert ProcessType -string Interactive "$launch_agent_path"
/usr/bin/plutil -insert KeepAlive -json '{}' "$launch_agent_path"
/usr/bin/plutil -insert KeepAlive.SuccessfulExit -bool false "$launch_agent_path"
/bin/chmod 644 "$launch_agent_path"

/bin/launchctl bootstrap "$launch_agent_domain" "$launch_agent_path"
/bin/launchctl kickstart -k "$launch_agent_domain/$launch_agent_label"

/usr/bin/osascript -e 'display notification "已安装，菜单栏服务已启动" with title "CodexBarSimple"'
