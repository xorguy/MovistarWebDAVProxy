package webui

import (
	"regexp"

	"movistar-webdav-proxy/internal/config"
)

// versionBadge matches the hardcoded version badge in templates/index.html
// (e.g. "v2.1.0 (Go)"), which upstream has to bump by hand and can drift
// from the real binary version.
var versionBadge = regexp.MustCompile(`v\d+\.\d+\.\d+[0-9A-Za-z.+-]* \(Go\)`)

func init() {
	indexHTML = versionBadge.ReplaceAll(indexHTML, []byte(config.AppVersion()+" (Go)"))
}
