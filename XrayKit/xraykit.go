// Package xraykit is a thin gomobile-friendly wrapper around Xray-core.
//
// gomobile bind exposes Swift-callable functions for everything declared
// at package level with primitive/byte-slice arg+return types. We keep the
// surface intentionally minimal:
//
//	Start(configJSON []byte) error
//	Stop() error
//	Version() string
//
// The PacketTunnel extension calls Start with the JSON we built in
// XrayConfigBuilder.swift. Xray then binds 127.0.0.1:10808 (socks) and
// 127.0.0.1:10809 (http) inside the extension process — tun2socks forwards
// TUN packets to the socks port.
package xraykit

import (
	"bytes"
	"errors"
	"sync"

	xcore "github.com/xtls/xray-core/core"
	// Slim distro registration lives in distro_slim.go — includes ONLY the
	// protocols / transports / features we use, to keep the binary small
	// enough for iOS NEPacketTunnelProvider's 50MB memory limit.
	"github.com/xtls/xray-core/infra/conf/serial"
)

var (
	mu      sync.Mutex
	running *xcore.Instance
)

// Start parses configJSON (Xray "config v5" JSON shape) and starts the core.
// Returns nil on success, an error otherwise. Idempotent guard: returns
// an error if the core is already running — caller should Stop first.
func Start(configJSON []byte) error {
	mu.Lock()
	defer mu.Unlock()
	if running != nil {
		return errors.New("xray: already running")
	}
	if len(configJSON) == 0 {
		return errors.New("xray: empty config")
	}

	// Xray accepts JSON via its conf loader.
	pbConfig, err := serial.LoadJSONConfig(bytes.NewReader(configJSON))
	if err != nil {
		return err
	}
	inst, err := xcore.New(pbConfig)
	if err != nil {
		return err
	}
	if err := inst.Start(); err != nil {
		return err
	}
	running = inst
	return nil
}

// Stop tears down the running core. Safe to call when not running.
func Stop() error {
	mu.Lock()
	defer mu.Unlock()
	if running == nil {
		return nil
	}
	err := running.Close()
	running = nil
	return err
}

// Version returns the embedded Xray-core version string.
func Version() string {
	return xcore.Version()
}
