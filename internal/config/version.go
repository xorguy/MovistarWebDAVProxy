package config

// BuildVersion is injected at build time with:
//
//	-ldflags "-X movistar-webdav-proxy/internal/config.BuildVersion=v2.1.2"
//
// When empty (e.g. plain `go build`), the source constant Version is used.
var BuildVersion string

// AppVersion returns the effective application version: the build-time
// injected value if present, otherwise the hardcoded Version constant.
func AppVersion() string {
	if BuildVersion != "" {
		return BuildVersion
	}
	return Version
}
