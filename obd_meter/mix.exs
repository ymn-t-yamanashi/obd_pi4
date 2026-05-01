defmodule ObdPi4.MixProject do
  use Mix.Project

  @app :obd_pi4
  @version "0.1.0"
  @all_targets [:rpi4]

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.19",
      archives: [nerves_bootstrap: "~> 1.15"],
      listeners: listeners(Mix.target(), Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [{@app, release()}]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {ObdPi4.Application, []}
    ]
  end

  def cli do
    [preferred_targets: [run: :host, test: :host]]
  end

  defp deps do
    [
      {:nerves, "~> 1.14", runtime: false},
      {:shoehorn, "~> 0.9.1"},
      {:ring_logger, "~> 0.11.0"},
      {:toolshed, "~> 0.4.0"},
      {:nerves_runtime, "~> 0.13.12"},
      {:nerves_pack, "~> 0.7.1", targets: @all_targets},
      {:nerves_system_rpi4, "~> 2.0", runtime: false, targets: :rpi4},
      {:scenic, "~> 0.11.2"},
      {:scenic_driver_local,
       github: "ScenicFramework/scenic_driver_local",
       ref: "26cd49dee26bb5951e63e39b16840087c9b7d96f",
       targets: @all_targets}
    ]
  end

  def release do
    [
      overwrite: true,
      cookie: "#{@app}_cookie",
      include_erts: &Nerves.Release.erts/0,
      steps: [&Nerves.Release.init/1, :assemble],
      strip_beams: Mix.env() == :prod or [keep: ["Docs"]]
    ]
  end

  defp listeners(_, _), do: []
end
