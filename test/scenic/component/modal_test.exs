#
#  Created by Boyd Multerer on 2018-07-15.
#  Copyright © 2018 Kry10 Industries. All rights reserved.
#

defmodule Scenic.Component.ModalTest do
  use ExUnit.Case, async: true
  doctest Scenic

  alias Scenic.Graph
  alias Scenic.Primitive
  alias Scenic.ViewPort
  alias Scenic.Component.Modal
  alias Scenic.ViewPort.Tables

  defmodule TestSceneOne do
    use Scenic.Scene
    def init(_, _), do: {:ok, :test_one_state}
  end

  defmodule TestComponentOne do
    use Scenic.Component
    def verify(arg), do: {:ok, arg}
    def init(_, _), do: {:ok, :test_one_state} |> IO.inspect()
  end

  @config %ViewPort.Config{
    name: :dyanmic_viewport,
    size: {700, 600},
    opts: [font: :roboto, font_size: 30, scale: 1.4],
    default_scene: {TestSceneOne, nil},
    drivers: []
  }

  @styles %{theme: :dark}

  setup_all do
    start_supervised!(Tables)
    _ = DynamicSupervisor.start_link(strategy: :one_for_one, name: :scenic_dyn_viewports)
    {:ok, vp_pid} = ViewPort.start(@config)
    {:ok, %{viewport: vp_pid}}
  end

  # ============================================================================
  # info

  test "info works" do
    assert is_bitstring(Modal.info(:bad_data))
    assert Modal.info(:bad_data) =~ ":bad_data"
  end

  # ============================================================================
  # verify

  test "verify passes all valid data types" do
    assert Modal.verify(Scenic.Component.ModalTest.Container) ==
             {:ok, Scenic.Component.ModalTest.Container}

    assert Modal.verify({Scenic.Component.ModalTest.Container, "test"}) ==
             {:ok, {Scenic.Component.ModalTest.Container, "test"}}

    builder = fn g -> g end

    assert {:ok, ^builder} = Modal.verify(builder)
  end

  test "verify fails invalid data" do
    assert Modal.verify("some text") == :invalid_data
  end

  # ============================================================================
  # init

  test "init works with a builder function", %{viewport: vp_pid} do
    assert {:ok, _state, _} = Modal.init(fn g -> g end, viewport: vp_pid, styles: @styles)
  end

  test "init works with a component module", %{viewport: vp_pid} do
    {:ok, state, _} = Modal.init(TestComponentOne, viewport: vp_pid, styles: @styles)

    # 80% X 60% of the viewport
    assert %Primitive{data: {560, 360, _radius}} = Graph.get!(state.graph, :content_background)
    # to center the modal it will be half of the difference between viewport and modal dimensions
    assert %Primitive{transforms: %{translate: {70, 120}}} = Graph.get!(state.graph, :content)
  end

  test "init works with a component module and an argument", %{viewport: vp_pid} do
    assert {:ok, _state, _} =
             Modal.init({TestComponentOne, "test"}, viewport: vp_pid, styles: @styles)
  end

  test "modal defaults to 80% X 60% of viewport and is centered", %{viewport: vp_pid} do
    {:ok, state, _} = Modal.init(fn g -> g end, viewport: vp_pid, styles: @styles)

    assert %Primitive{data: {560, 360, _radius}} = Graph.get!(state.graph, :content_background)
    # half of the difference between viewport and modal dimensions
    assert %Primitive{transforms: %{translate: {70, 120}}} = Graph.get!(state.graph, :content)
  end

  test "modal is centered when custom dimensions are given", %{viewport: vp_pid} do
    {:ok, state, _} =
      Modal.init(fn g -> g end, viewport: vp_pid, styles: Map.put(@styles, :size, {200, 150}))

    assert %Primitive{data: {200, 150, _radius}} = Graph.get!(state.graph, :content_background)
    # half of the difference between viewport and modal dimensions
    assert %Primitive{transforms: %{translate: {250, 225}}} = Graph.get!(state.graph, :content)
  end
end
