defmodule ObdPi4.Ui.Scene.Dashboard do
  @moduledoc false

  use Scenic.Scene

  alias Scenic.Graph
  import Scenic.Primitives

  @impl true
  def init(scene, _param, _opts) do
    viewport = Application.fetch_env!(:obd_pi4, :viewport)
    {vw, vh} = viewport.size

    graph =
      Graph.build()
      |> rect({vw, vh}, fill: :black)
      |> rect({600, 320}, translate: {340, 200}, fill: :green)
      |> rect({600, 320}, translate: {340, 200}, stroke: {6, :white})

    scene = push_graph(scene, graph)
    {:ok, scene}
  end
end
