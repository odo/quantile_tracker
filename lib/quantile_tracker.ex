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

def call_count(server) do
  GenServer.call(server, :call_count)
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
  if Map.get(options, :name),                      do: Process.register(self(), options.name)
  if timed_flush = Map.get(options, :timed_flush), do: maybe_init_flush(timed_flush)
  estimator = targets
              |> :quantile_estimator.f_targeted
              |> :quantile_estimator.new
  recorded_quantiles =
    ([0.0]
    ++ Enum.map(targets, fn({value, _}) -> value * 1.0 end)
    ++ [1.0])
    |> Enum.uniq
  init_state = %{
    call_count: 0,
    estimator: estimator,
    null_estimator: estimator,
    calls_since_compression: 0,
    recorded_quantiles: recorded_quantiles,
    timed_flush: timed_flush,
  }
  {:ok, init_state}
end

def maybe_init_flush(nil) do
  :noop
end
def maybe_init_flush({interval, _fun}) do
  Process.send_after(self(), :flush, interval)
end

def handle_call({:quantiles, quantiles}, _from, state) do
  reply = quantiles_internal(state.estimator, quantiles)
  {:reply, reply, state}
end
def handle_call(:call_count, _from, state) do
  reply = state.call_count
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
  {next_estimator, next_calls_since_compression, next_call_count}
  = Enum.reduce(
    value_chunks,
    {state.estimator, state.calls_since_compression, state.call_count},
    fn(chunk, {estimator, calls_since_compression, call_count}) ->
      next_estimator = Enum.reduce(chunk, estimator, fn(value, est) -> :quantile_estimator.insert(value * 1.0, est) end)
      chunk_length = length(chunk)
      next_calls_since_compression = calls_since_compression + chunk_length
      case next_calls_since_compression >= @compress_after do
        true  -> {:quantile_estimator.compress(next_estimator), 0, call_count + chunk_length}
        false -> {next_estimator, next_calls_since_compression, call_count + chunk_length}
      end 
    end
  )
  next_state = %{state | estimator: next_estimator, calls_since_compression: next_calls_since_compression, call_count: next_call_count}
  {:noreply, maybe_compress(next_state)}
end

def handle_info(:flush, state = %{timed_flush: {interval, fun}}) do
  case quantiles_internal(state.estimator, state.recorded_quantiles) do
    error = {:error, :empty_stats} ->
      fun.(error)
    quantiles ->
      fun.({state.call_count, quantiles})
  end
  Process.send_after(self(), :flush, interval)
  next_state = %{state | estimator: state.null_estimator, call_count: 0}
  {:noreply, next_state}
end

## Internal

def quantiles_internal(estimator, quantiles) do
  try do
      get_quantile = fn(q) -> {q, :quantile_estimator.quantile(q, estimator)} end
      quantiles |> Enum.map(get_quantile)
    catch
      {:error, :empty_stats} -> {:error, :empty_stats}
    end
end

def maybe_compress(state = %{estimator: estimator, calls_since_compression: 100}) do
  next_estimator = :quantile_estimator.compress(estimator)
  %{state | estimator: next_estimator, calls_since_compression: 0}
end
def maybe_compress(state), do: state

end
