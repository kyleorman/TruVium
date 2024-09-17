#!/bin/bash

# Get the current pane's command
current_command=$(tmux display -p "#{pane_current_command}")

# Define functions for actions
send_keys() {
  tmux send-keys "$1"
}

select_pane() {
  tmux select-pane "$1"
}

# Define key actions
case "$1" in
  h)
    if [[ "$current_command" =~ ^(g?view|n?vim?x?)(diff)?$ ]]; then
      send_keys "C-h"
    else
      select_pane "-L"
    fi
    ;;
  j)
    if [[ "$current_command" =~ ^(g?view|n?vim?x?)(diff)?$ ]]; then
      send_keys "C-j"
    elif [[ "$current_command" =~ ^fzf$ ]]; then
      send_keys "C-j"
    else
      select_pane "-D"
    fi
    ;;
  k)
    if [[ "$current_command" =~ ^(g?view|n?vim?x?)(diff)?$ ]]; then
      send_keys "C-k"
    elif [[ "$current_command" =~ ^fzf$ ]]; then
      send_keys "C-k"
    else
      select_pane "-U"
    fi
    ;;
  l)
    if [[ "$current_command" =~ ^(g?view|n?vim?x?)(diff)?$ ]]; then
      send_keys "C-l"
    else
      select_pane "-R"
    fi
    ;;
  \\)
    if [[ "$current_command" =~ ^(g?view|n?vim?x?)(diff)?$ ]]; then
      send_keys "C-\\"
    else
      select_pane "-l"
    fi
    ;;
  *)
    echo "Invalid key action"
    exit 1
    ;;
esac

