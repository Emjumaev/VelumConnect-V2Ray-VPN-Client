// Slim Xray-core distro for V2RaySabLab.
//
// Registers ONLY the protocols, transports, and features actually used by
// our VLESS + Reality + XHTTP setup. Cuts the resulting binary roughly in
// half vs. xray-core/main/distro/all, which matters because iOS limits
// NEPacketTunnelProvider to ~50MB of memory and the Go runtime is hungry.
//
// If you ever change XrayConfigBuilder.swift to use a new transport,
// security, or proxy, add the corresponding blank-import here and rebuild
// XrayKit.xcframework via Scripts/build-xraykit.sh.

package xraykit

import (
	// Mandatory features
	_ "github.com/xtls/xray-core/app/dispatcher"
	_ "github.com/xtls/xray-core/app/proxyman/inbound"
	_ "github.com/xtls/xray-core/app/proxyman/outbound"

	// Core features we actually use
	_ "github.com/xtls/xray-core/app/dns"
	_ "github.com/xtls/xray-core/app/log"
	_ "github.com/xtls/xray-core/app/policy"
	_ "github.com/xtls/xray-core/app/router"

	// Proxies referenced in XrayConfigBuilder.swift
	_ "github.com/xtls/xray-core/proxy/blackhole"     // "block" outbound
	_ "github.com/xtls/xray-core/proxy/freedom"       // "direct" outbound
	_ "github.com/xtls/xray-core/proxy/http"          // http inbound (port 10809)
	_ "github.com/xtls/xray-core/proxy/socks"         // socks inbound (port 10808, used by tun2socks)
	_ "github.com/xtls/xray-core/proxy/vless/outbound" // "proxy" outbound

	// Transport base layers
	_ "github.com/xtls/xray-core/transport/internet/tcp"
	_ "github.com/xtls/xray-core/transport/internet/udp"

	// Security layers
	_ "github.com/xtls/xray-core/transport/internet/reality" // security=reality
	_ "github.com/xtls/xray-core/transport/internet/tls"     // tls infra (reality depends on parts of this)

	// XHTTP transport (newer Xray merged xhttp into splithttp)
	_ "github.com/xtls/xray-core/transport/internet/splithttp"

	// Config format
	_ "github.com/xtls/xray-core/main/json"
)
