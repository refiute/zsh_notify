autoload -U add-zsh-hook 2> /dev/null || return

__notify_threshold=60
read -r -d '' __notify_ignore_programs <<EOF
less
man
vi vim emacs nano
git
ssh
EOF

export __notify_threshold
export __notify_ignore_programs

function __notify_preexec() {
	export __notify_time_start=`date +%s`
	export __notify_command=$1
}

function __notify_precmd() {
	export __notify_time_end=`date +%s`

	local cmd=$__notify_command
	local prog=$(echo $cmd | awk '{print $1}')
	local notify_method

	if which terminal-notifier >/dev/null 2>&1; then
		notify_method="terminal-notifier"
	elif [ -n "$NOTIFY_URL" ]; then
		notify_method="curl"
	else
		return
	fi

	if [ -z "$__notify_time_start" ] || [ -z "$__notify_threshold" ]; then
		return
	fi
	exec_time=$((__notify_time_end-__notify_time_start))

	for ignore_prog in $(echo $__notify_ignore_programs); do
		[ "$prog" = "$ignore_prog" ] && return
	done

	if [ -z "$__notify_command" ]; then
		cmd="<UNKNOWN>"
	fi

	local message="Command finished!\ncommand: $cmd\nexec time: $exec_time"

	if [ "$exec_time" -ge "$__notify_threshold" ]; then
		case $notify_method in
			"terminal-notifier" )
				echo "$message" | terminal-notifier
				;;
			"curl" )
				local payload="payload={'channel': '@refiute', 'username': 'zsh-notify', 'text': '$message', 'icon_emoji': ':robot_face:'}"
				curl -X POST --data-urlencode "$payload" $NOTIFY_URL
				;;
		esac
	fi

	unset __notify_time_start
	unset __notify_command
}

if which curl >/dev/null 2>&1 ||
	which terminal-notifier >/dev/null 2>&1; then
	add-zsh-hook preexec __notify_preexec
	add-zsh-hook precmd __notify_precmd
fi
