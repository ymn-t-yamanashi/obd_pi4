import Config

config :logger, :default_handler, false

config :shoehorn, init: [:nerves_runtime, :nerves_pack]

config :nerves_runtime, startup_guard_enabled: true

config :nerves, :erlinit, update_clock: true

keys =
  System.user_home!()
  |> Path.join(".ssh/id_{rsa,ecdsa,ed25519}.pub")
  |> Path.wildcard()

if keys == [],
  do:
    Mix.raise("""
    No SSH public keys found in ~/.ssh. An ssh authorized key is needed to
    log into the Nerves device and update firmware on it using ssh.
    See your project's config.exs for this error message.
    """)

config :nerves_ssh,
  authorized_keys: Enum.map(keys, &File.read!/1)

config :vintage_net,
  regulatory_domain: "00",
  config: [
    {"usb0", %{type: VintageNetDirect}},
    {"eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}}},
    {"wlan0", %{type: VintageNetWiFi}}
  ]

config :mdns_lite,
  hosts: [:hostname, "nerves"],
  ttl: 120,
  services: [
    %{protocol: "ssh", transport: "tcp", port: 22},
    %{protocol: "sftp-ssh", transport: "tcp", port: 22},
    %{protocol: "epmd", transport: "tcp", port: 4369}
  ]

config :obd_pi4, :viewport, %{
  name: :main_viewport,
  size: {1920, 1080},
  theme: :dark,
  default_scene: {ObdPi4.Ui.Scene.Dashboard, nil},
  drivers: [
    [
      module: Scenic.Driver.Local,
      layer: 2,
      cursor: false,
      limit_ms: 33,
      antialias: false,
      position: [scaled: true, centered: true, orientation: :normal]
    ]
  ]
}
