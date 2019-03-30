defmodule Scenic.Component.Modal do
  @moduledoc """
  Provides a modal which will render the specified component or builder function when it opens.

  To open the modal call `Scenic.Component.Modal.open/2 from any scene passing your
  component module and, optionally, an argument for that component or by passing in a
  builder function. The `size` can be specified in decimal percent or pixels.
  ```
  def filter_event({:click, :my_button}, _, graph) do
    graph = Modal.open(graph, {MyApp.Component.Form, "test"}, size: {0.80, 0.60})
    {:noreply, graph}
  end
  ```

  The modal sends a `{:modal {:click, :dismiss_modal}}` event up to the parent scene when
  the user clicks the shadow area of the modal. All other events are sent to the parent as
  well in the form of `{:modal, event}`. In the parent scene:
  ```
  def filter_event({:modal, {:click, :dismiss_modal}}, _, graph) do
    graph = Modal.close(graph)
    {:halt, graph, push: graph}
  end
  ```
  """
  use Scenic.Component

  alias Scenic.ViewPort
  alias Scenic.Graph

  import Scenic.Primitives, only: [{:rect, 3}, {:rounded_rectangle, 3}, {:group, 3}]

  # --------------------------------------------------------
  def verify({component, _arg} = data) when is_atom(component), do: {:ok, data}
  def verify(component) when is_atom(component), do: {:ok, component}
  def verify(builder) when is_function(builder), do: {:ok, builder}

  def verify(_), do: :invalid_data

  # ----------------------------------------------------------------------------
  def init(builder, opts) do
    {:ok, %ViewPort.Status{size: {width, height}}} =
      opts[:viewport]
      |> ViewPort.info()

    {{left, top}, modal_styles} =
      (opts[:styles] || %{})
      |> Map.pop(:size, {0.80, 0.60})

    fill = Map.get(modal_styles, :fill, {255, 255, 255})

    graph =
      Graph.build()
      |> rect({width, height}, fill: {0, 0, 0, 150}, id: :modal_backdrop)
      |> group(
        fn g ->
          g =
            rounded_rectangle(g, {size(left, width), size(top, height), 3},
              fill: fill,
              id: :content_background
            )

          case builder do
            {module, data} ->
              module.add_to_graph(g, data)

            module when is_atom(module) ->
              module.add_to_graph(g)

            builder ->
              builder.(g)
          end
        end,
        modal_styles
        |> Map.put(:id, :content)
        |> Map.put_new(:translate, {translate(left, width), translate(top, height)})
      )

    {:ok, %{graph: graph}, push: graph}
  end

  def handle_input(
        {:cursor_button, {:left, :release, _, _pos}},
        %Scenic.ViewPort.Context{id: :modal_backdrop},
        state
      ) do
    send_event({:modal, {:click, :dismiss_modal}})
    {:noreply, state}
  end

  def handle_input(_event, _context, state) do
    {:noreply, state}
  end

  def filter_event({:click, :dismiss_modal} = event, _from, state) do
    send_event({:modal, event})
    {:halt, state}
  end

  def filter_event(event, _from, state) do
    send_event({:modal, event})
    {:halt, state}
  end

  @doc """
  Opens a modal and renders the given component module within
  """
  @spec open(
          Scenic.Graph.t(),
          module() | {module(), any()} | (Scenic.Graph.t() -> Scenic.Graph.t()),
          keyword()
        ) ::
          Scenic.Graph.t()
  def open(graph, args, opts \\ []) do
    opts = Keyword.put(opts, :id, :modal)
    add_to_graph(graph, args, opts)
  end

  @doc """
  Close the modal previously opened with `Modal.open/2`
  """
  @spec dismiss(Scenic.Graph.t()) :: Scenic.Graph.t()
  def dismiss(graph) do
    Scenic.Graph.delete(graph, :modal)
  end

  # decimal percentage
  defp translate(value, parent) when value < 1, do: round(parent * ((1 - value) / 2))
  # pixel
  defp translate(value, parent), do: round((parent - value) / 2)

  # decimal percentage
  defp size(value, parent) when value < 1, do: round(parent * value)
  # pixel
  defp size(value, _parent), do: value
end
