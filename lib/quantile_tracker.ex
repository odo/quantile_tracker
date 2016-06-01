defmodule QuantileTracker do

use GenServer

## API

def start_link(targets, name \\ nil) when is_list(targets) do
  GenServer.start_link(__MODULE__, {targets, name}, [])
end

def quantiles(server, quantiles) when is_list(quantiles) do
  GenServer.call(server, {:quantiles, quantiles})
end

def record(server, number) when is_number(number) do
  GenServer.cast(server, {:record, number})
end

# for testing
def record_as_call(server, number) when is_number(number) do
  GenServer.call(server, {:record, number})
end

## Server Callbacks

def init({targets, name}) do
  if name, do: Process.register(self(), name)
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
def handle_call({:record, number}, _from, state) do
  {:noreply, next_state} = handle_cast({:record, number}, state)
  {:reply, :ok, next_state}
end

def handle_cast({:record, number}, state) do
  next_estimator = :quantile_estimator.insert(number, state.estimator)
  next_calls_since_compression = state.calls_since_compression + 1
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
