defmodule ObdPi4.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        {Scenic, []},
        ObdPi4.Ui.Bootstrapper
      ] ++ validation_child() ++ target_children()

    opts = [strategy: :one_for_one, name: ObdPi4.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp validation_child do
    if Code.ensure_loaded?(Nerves.Runtime) and function_exported?(Nerves.Runtime, :validate_firmware, 0) do
      [
        {Task,
         fn ->
           Process.sleep(5_000)
           Nerves.Runtime.validate_firmware()
         end}
      ]
    else
      []
    end
  end

  if Mix.target() == :host do
    defp target_children, do: []
  else
    defp target_children, do: []
  end
end
