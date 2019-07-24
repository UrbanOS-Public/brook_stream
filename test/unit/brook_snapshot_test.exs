defmodule Brook.SnapshotTest do
  use ExUnit.Case
  import Assertions

  defmodule TestSnapshot.Storage do
    @behaviour Brook.Snapshot.Storage
    use GenServer

    def start_link(args) do
      GenServer.start_link(__MODULE__, args, name: via())
    end

    def init(init_args) do
      {:ok, init_args}
    end

    def get_latest() do
      %{"key1" => "value1"}
    end

    def store(entries) do
      GenServer.cast(via(), {:store, entries})
    end

    def handle_cast({:store, entries}, state) do
      Enum.each(entries, fn {key, value} -> send(state.pid, {:entry, key, value}) end)
      {:noreply, state}
    end

    defp via(), do: {:via, Registry, {Brook.Registry, __MODULE__}}
  end

  setup do
    config = [
      handlers: [Test.Event.Handler],
      snapshot: %{
        module: TestSnapshot.Storage,
        interval: 10,
        init_arg: %{pid: self()}
      }
    ]

    {:ok, brook} = Brook.start_link(config)

    on_exit(fn ->
      ref = Process.monitor(brook)
      Process.exit(brook, :normal)
      assert_receive {:DOWN, ^ref, _, _, _}
    end)

    [brook: brook]
  end

  test "entries are snapshotted at the interval configured" do
    Brook.process("CREATE", %{"id" => 123, "name" => "Gary"})

    entry = Brook.get(123)

    assert_receive {:entry, 123, ^entry}, 15_000
  end

  test "entries are retrieved from latest snapshot on init" do
    assert_async(timeout: 5_000, sleep_time: 500) do
      assert "value1" == Brook.get("key1")
    end
  end
end
