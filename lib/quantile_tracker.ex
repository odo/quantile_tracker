defmodule QuantileTracker do

@compress_after 10

use GenServer


## API

def start_link(targets, options \\ %{}) when is_list(targets) do
  GenServer.start_link(__MODULE__, {targets, options}, [])
end

def quantiles(server, quantiles) when is_list(quantiles) do
  GenServer.call(server, {:quantiles, quantiles})
end

def record(server, value) when is_number(value) or is_list(value) do
  GenServer.cast(server, {:record, value})
end

# for testing
def record_as_call(server, value) when is_number(value) or is_list(value) do
  GenServer.call(server, {:record, value})
end

## Server Callbacks

def init({targets, options}) do
  if Map.get(options, :name), do: Process.register(self(), options.name)
  estimator = targets
              |> :quantile_estimator.f_targeted
              |> :quantile_estimator.new
  {:ok, %{estimator: estimator, calls_since_compression: 0}}
end

def handle_call({:quantiles, quantiles}, _from, state) do
  reply = try do
      get_quantile = fn(q) -> {q, :quantile_estimator.quantile(q, state.estimator)} end
      quantiles |> Enum.map(get_quantile)
    catch
      {:error, :empty_stats} -> {:error, :empty_stats}
    end
  {:reply, reply, state}
end
def handle_call({:record, value}, _from, state) do
  {:noreply, next_state} = handle_cast({:record, value}, state)
  {:reply, :ok, next_state}
end

def handle_cast({:record, value}, state) when is_number(value) do
  handle_cast({:record, [value]}, state)
end
def handle_cast({:record, values}, state) when is_list(values) do
  value_chunks   = Enum.chunk(values, @compress_after, @compress_after, [])
  {next_estimator, next_calls_since_compression}
  = Enum.reduce(
    value_chunks,
    {state.estimator, state.calls_since_compression},
    fn(chunk, {estimator, calls_since_compression}) ->
      next_estimator = Enum.reduce(chunk, estimator, fn(value, est) -> :quantile_estimator.insert(value * 1.0, est) end)
      next_calls_since_compression = calls_since_compression + length(chunk)
      case next_calls_since_compression >= @compress_after do
        true  -> {:quantile_estimator.compress(next_estimator), 0}
        false -> {next_estimator, next_calls_since_compression}
      end 
    end
  )
  next_state = %{estimator: next_estimator, calls_since_compression: next_calls_since_compression}
  {:noreply, maybe_compress(next_state)}
end

## Internal

def maybe_compress(state = %{estimator: estimator, calls_since_compression: 100}) do
  next_estimator = :quantile_estimator.compress(estimator)
  %{state | estimator: next_estimator, calls_since_compression: 0}
end
def maybe_compress(state), do: state

end
