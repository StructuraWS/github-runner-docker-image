curl -sL https://api.github.com/repos/protocolbuffers/protobuf/releases -o /tmp/releases.json

#  cat /tmp/releases.json
BUILDKIT_URL=$(jq -r '
            map(select(.prerelease == false and .draft == false))
            | sort_by(.published_at) | reverse
            | .[] 
            | .assets[]? 
            | select(.name | endswith("-linux-x86_64.zip")) 
            | .browser_download_url
            ' /tmp/releases.json | head -n 1)
 [ -z "$BUILDKIT_URL" ] && { echo "Error: BUILDKIT_URL is empty"; exit 1; }

echo "Downloading: $BUILDKIT_URL"
ZIPFILE="/tmp/protoc.zip"
curl -sL "$BUILDKIT_URL" -o "$ZIPFILE"
unzip "$ZIPFILE" -d /usr/local
