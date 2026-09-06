# homelab-talos

To load environment vars:

export TALOSCONFIG=./talosconfig

Make sure the following files are not committed:
- talosconfig
- secrets.yaml
- kubeconfig

## Scripts

When changed:
chmod +x control-planes.sh 

Bootstrapping


## Restarting

talosctl reset \
  --nodes IP-HERE \
  --graceful=false \
  --system-labels-to-wipe STATE \
  --system-labels-to-wipe EPHEMERAL \
  --reboot
