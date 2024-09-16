# Function to update plugins
update_plugin() {
    local plugin_dir="$1"

    if [ -d "$plugin_dir/.git" ]; then
        echo "Updating plugin in '$plugin_dir'..." | tee -a "$LOGFILE"
        git -C "$plugin_dir" pull --ff-only || {
            echo "Warning: Failed to update plugin in '$plugin_dir'." | tee -a "$LOGFILE"
        }
    else
        echo "No git repository found in '$plugin_dir'. Skipping update." | tee -a "$LOGFILE"
    fi
}

# Update all start plugins
echo "Updating essential start plugins..." | tee -a "$LOGFILE"
for plugin in "${START_PLUGINS[@]}"; do
    plugin_name=$(basename "$plugin")
    target_path="$START_PLUGIN_DIR/$plugin_name"
    update_plugin "$target_path"
done

# Update all optional plugins
echo "Updating optional plugins..." | tee -a "$LOGFILE"
for plugin in "${OPTIONAL_PLUGINS[@]}"; do
    plugin_name=$(basename "$plugin")
    target_path="$OPT_PLUGIN_DIR/$plugin_name"
    update_plugin "$target_path"
done

# Update all color schemes
echo "Updating color schemes..." | tee -a "$LOGFILE"
for color in "${COLOR_SCHEMES[@]}"; do
    color_name=$(basename "$color")
    target_path="$COLOR_PLUGIN_DIR/$color_name"
    update_plugin "$target_path"
done

# Function to automate TPM's plugin update
automate_tpm_update() {
    echo "Automating TPM plugin update..." | tee -a "$LOGFILE"

    # Start a detached tmux session named 'plugin_update' as the actual user
    sudo -u "$SUDO_USER" tmux new-session -d -s plugin_update "echo 'Updating tmux plugins using TPM...'; sleep 2"

    # Wait briefly to ensure the session is fully initialized
    sleep 2

    # Send the key sequence to update plugins: <prefix> + U
    sudo -u "$SUDO_USER" tmux send-keys -t plugin_update:0.0 C-a U C-m

    # Wait for the update to complete
    sleep 5

    # Kill the plugin_update session
    sudo -u "$SUDO_USER" tmux kill-session -t plugin_update

    echo "Tmux plugins update triggered." | tee -a "$LOGFILE"
}

# Call the update function
automate_tpm_update

echo "All plugins updated successfully." | tee -a "$LOGFILE"

