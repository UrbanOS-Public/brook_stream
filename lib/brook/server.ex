defmodule Brook.Server do
  use GenServer
  require Logger

  defmodule State do
    defstruct [:elsa, :kafka_config, :decoder, :event_handlers, :snapshot, :snapshot_state, :snapshot_timer]
  end

  def start_link(%Brook.Config{} = config) do
    GenServer.start_link(__MODULE__, config, name: {:via, Registry, {Brook.Registry, __MODULE__}})
  end

  def init(%Brook.Config{} = config) do
    :ets.new(__MODULE__, [:named_table, :set, :protected])

    {:ok, config, {:continue, :snapshot_init}}
  end

  def handle_continue(:snapshot_init, %{snapshot: %{module: module} = snapshot_config} = state) do
    init_arg = Map.get(snapshot_config, :init_arg, [])
    interval = Map.get(snapshot_config, :interval, 60)

    load_entries_from_snapshot(module)
    {:ok, ref} = :timer.send_interval(interval * 1_000, self(), :snapshot)

    Logger.debug(fn -> "Brook snapshot configured every #{interval} to #{inspect(module)}" end)
    {:noreply, %{state | snapshot_timer: ref}}
  end

  def handle_continue(:snapshot_init, state) do
    {:noreply, state}
  end

  def handle_call({:process, type, event}, _from, state) do
    decoded_event = apply(state.decoder, :decode, [event])

    Enum.each(state.event_handlers, fn handler ->
      case apply(handler, :handle_event, [type, decoded_event]) do
        {:update, key, value} -> :ets.insert(__MODULE__, {key, value})
        {:delete, key} -> :ets.delete(__MODULE__, key)
        :discard -> nil
      end
    end)

    {:reply, :ok, state}
  end

  def handle_info(:snapshot, state) do
    Logger.debug(fn -> "Snapshotting to event store #{inspect(state.snapshot.module)}" end)

    entries =
      :ets.match_object(__MODULE__, :_)
      |> Enum.into(%{})

    apply(state.snapshot.module, :store, [entries])

    {:noreply, state}
  end

  defp load_entries_from_snapshot(module) do
    apply(module, :get_latest, [])
    |> Enum.each(fn {key, value} ->
      :ets.insert(__MODULE__, {key, value})
    end)
  end
end
