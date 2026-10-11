#!/bin/sh
# Publish the landing page and the replay viewer to https://yusa.app/mihenk/.
# Layout on the server (nginx root /var/www/yusa.app, plain static files):
#   mihenk/index.html          <- site/index.html
#   mihenk/replay/index.html   <- replay.html wrapped in a document skeleton
#   mihenk/replay/data/*.json  <- data/
# Usage: sh viewer/deploy.sh   (SSH_KEY and SSH_TARGET can be overridden)
set -eu

here=$(cd "$(dirname "$0")" && pwd)
key=${SSH_KEY:-$HOME/.ssh/cantiin_deploy}
target=${SSH_TARGET:-yusa@207.180.223.10}
remote=/var/www/yusa.app/mihenk

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/replay/data"
cp "$here/site/index.html" "$stage/index.html"
cp "$here"/data/*.json "$stage/replay/data/"

# replay.html is a fragment (no doctype). The redirect makes /mihenk/replay
# resolve its relative data/ path under replay/, not under mihenk/.
{
  printf '<!doctype html>\n<html lang="tr">\n'
  printf '<script>if (!location.pathname.endsWith("/") && !location.pathname.endsWith(".html")) location.replace(location.pathname + "/" + location.search + location.hash);</script>\n'
  cat "$here/replay.html"
  printf '\n</html>\n'
} > "$stage/replay/index.html"

ssh -i "$key" -o BatchMode=yes "$target" "rm -rf $remote.new && mkdir -p $remote.new"
tar -C "$stage" -cf - . | ssh -i "$key" -o BatchMode=yes "$target" "tar -C $remote.new -xf - && rm -rf $remote.old && { [ ! -d $remote ] || mv $remote $remote.old; } && mv $remote.new $remote && rm -rf $remote.old"
echo "Published to https://yusa.app/mihenk/"
