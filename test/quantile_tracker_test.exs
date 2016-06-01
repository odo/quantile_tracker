defmodule QuantileTrackerTest do
  use ExUnit.Case
  doctest QuantileTracker

  test "empty estimator" do
    {:ok, qe} = QuantileTracker.start_link([])
    assert {:error, :empty_stats} = QuantileTracker.quantiles(qe, [0.0])
    :ok = QuantileTracker.record_as_call(qe, 1)
    assert [{0.0, 1}] = QuantileTracker.quantiles(qe, [0.0])
  end

  test "random estimator" do
    {:ok, qe} = QuantileTracker.start_link([{0.5, 0.0001}])
    Enum.each((1..1000), fn(e) -> QuantileTracker.record_as_call(qe, e * 1.0) end)
    assert [{0.5, 501.0}] = QuantileTracker.quantiles(qe, [0.5])
  end

  test "registered name" do
    {:ok, _pid} = QuantileTracker.start_link([{0.5, 0.0001}], :estimator)
    assert {:error, :empty_stats} = QuantileTracker.quantiles(:estimator, [0.0])
  end

end
