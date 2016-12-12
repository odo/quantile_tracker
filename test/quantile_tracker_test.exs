defmodule QuantileTrackerTest do
  use ExUnit.Case
  doctest QuantileTracker

  test "empty estimator" do
    {:ok, qe} = QuantileTracker.start_link([])
    assert {:error, :empty_stats} = QuantileTracker.quantiles(qe, [0.0])
    :ok = QuantileTracker.record_as_call(qe, 1.0)
    assert [{0.0, 1.0}] = QuantileTracker.quantiles(qe, [0.0])
  end

  test "random estimator" do
    {:ok, qe} = QuantileTracker.start_link([{0.5, 0.0001}])
    Enum.each((1..1000), fn(e) -> QuantileTracker.record_as_call(qe, e * 1.0) end)
    assert [{0.5, 501.0}] = QuantileTracker.quantiles(qe, [0.5])
  end
  
  test "batch estimator" do
    {:ok, qe} = QuantileTracker.start_link([{0.1, 0.0001}, {0.5, 0.0001}, {0.9, 0.0001}])
    values = (1..1000) |> Enum.map(&(&1 * 1.0))
    QuantileTracker.record_as_call(qe, values)
    assert [{0.1, 101.0}, {0.5, 501.0}, {0.9, 901.0}] = QuantileTracker.quantiles(qe, [0.1, 0.5, 0.9])
  end

  test "registered name" do
    {:ok, _pid} = QuantileTracker.start_link([{0.5, 0.0001}], %{name: :estimator})
    assert {:error, :empty_stats} = QuantileTracker.quantiles(:estimator, [0.0])
  end

end
