
#!/bin/bash

# ~/.tmux_keys.sh
# Usage: ~/.tmux_keys.sh <key>

LOGFILE=~/tmux_key_binding.log

{
  echo "Timestamp: $(date)"
  echo "Key Pressed: $1"

  # Get the current pane's command
  current_command=$(tmux display -p "#{pane_current_command}")
  echo "Current Command: $current_command"

  case "$1" in
    h)
      if [[ "$current_command" =~ ^(g?view|n?vim?x?)(diff)?$ ]]; then
        echo "Action: send-keys C-h"
        tmux send-keys "C-h"
      else
        echo "Action: select-pane -L"
        tmux select-pane -L
      fi
      ;;
    j)
      if [[ "$current_command" =~ ^(g?view|n?vim?x?)(diff)?$ ]]; then
        echo "Action: send-keys C-j"
        tmux send-keys "C-j"
      elif [[ "$current_command" =~ ^fzf$ ]]; then
        echo "Action: send-keys C-j"
        tmux send-keys "C-j"
      else
        echo "Action: select-pane -D"
        tmux select-pane -D
      fi
      ;;
    k)
      if [[ "$current_command" =~ ^(g?view|n?vim?x?)(diff)?$ ]]; then
        echo "Action: send-keys C-k"
        tmux send-keys "C-k"
      elif [[ "$current_command" =~ ^fzf$ ]]; then
        echo "Action: send-keys C-k"
        tmux send-keys "C-k"
      else
        echo "Action: select-pane -U"
        tmux select-pane -U
      fi
      ;;
    l)
      if [[ "$current_command" =~ ^(g?view|n?vim?x?)(diff)?$ ]]; then
        echo "Action: send-keys C-l"
        tmux send-keys "C-l"
      else
        echo "Action: select-pane -R"
        tmux select-pane -R
      fi
      ;;
    \\)
      if [[ "$current_command" =~ ^(g?view|n?vim?x?)(diff)?$ ]]; then
        echo "Action: send-keys C-\\"
        tmux send-keys "C-\\"
      else
        echo "Action: select-pane -L"
        tmux select-pane -L
      fi
      ;;
    *)
      echo "Invalid key action: $1"
      ;;
  esac

  echo "----------------------------------------"
} >> "$LOGFILE" 2>&1
