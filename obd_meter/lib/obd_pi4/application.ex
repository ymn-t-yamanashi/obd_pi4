defmodule ObdPi4.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        ObdPi4.Obd.State,
        ObdPi4.Obd.Reader
      ] ++ target_children()

    opts = [strategy: :one_for_one, name: ObdPi4.Supervisor]
    Supervisor.start_link(children, opts)
  end

  if Mix.target() == :host do
    defp target_children, do: []
  else
    defp target_children do
      [
        {Scenic, viewports: [viewport_config()]}
      ]
    end

    defp viewport_config do
      Application.fetch_env!(:obd_pi4, :viewport)
    end
  end
end
