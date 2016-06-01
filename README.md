# Elixir QuantileTracker

Track quantiles of measurements with predefined error tolerance in a memory-efficient way.

This server uses [quantile_estimator](https://github.com/odo/quantile_estimator) internally.

## Usage

```
iex(1)> {:ok, qe} = QuantileTracker.start_link([{0.5, 0.01}, {0.99, 0.0001}])
{:ok, #PID<0.93.0>}
iex(2)> Enum.each((1..1000), fn(e) -> QuantileTracker.record(qe, e * 1.0) end)
:ok
iex(3)> QuantileTracker.quantiles(qe, [0.5, 0.99])
[{0.5, 504.0}, {0.99, 991.0}]
```

With `start_link/1` we pass a limit of the error in rank allowed. In the example we define a maximum error of 1.0% for the median and 0.1% for the 99th percentile.

After recording the numbers 1 to 1000, we retrieve the quantiles and see that they are within the margin of error we allowed.