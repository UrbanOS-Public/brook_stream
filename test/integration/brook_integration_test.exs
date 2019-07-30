defmodule Brook.IntegrationTest do
  use ExUnit.Case
  use Divo
  import Assertions

  setup do
    {:ok, redix} = Redix.start_link(host: "localhost")

    config = [
      driver: %{
        module: Brook.Driver.Kafka,
        init_arg: [
          endpoints: [localhost: 9092],
          topic: "test",
          group: "test-group",
          config: [
            begin_offset: :earliest
          ]
        ]
      },
      handlers: [Test.Event.Handler],
      storage: %{
        module: Brook.Storage.Redis,
        init_arg: [redix_args: [host: "localhost"], namespace: "test:snapshot"]
      }
    ]

    {:ok, brook} = Brook.start_link(config)

    on_exit(fn ->
      kill_and_wait(redix)
      kill_and_wait(brook, 10_000)
    end)

    [redix: redix]
  end

  test "brook happy path" do
    Elsa.produce([localhost: 9092], "test", {"CREATE", Jason.encode!(%{"id" => 123, "name" => "George"})}, partition: 0)
    Elsa.produce([localhost: 9092], "test", {"UPDATE", Jason.encode!(%{"id" => 123, "age" => 67})})

    assert_async(timeout: 2_000, sleep_time: 200) do
      assert %{"id" => 123, "name" => "George", "age" => 67} == Brook.get(123)
    end

    assert_async(timeout: 2_000, sleep_time: 200) do
      events = Brook.get_events(123)
      assert 2 == length(events)

      create_event = List.first(events)
      assert "CREATE" == create_event.type
      assert %{"id" => 123, "name" => "George"} == create_event.data

      update_event = Enum.at(events, 1)
      assert "UPDATE" == update_event.type
      assert %{"id" => 123, "age" => 67} == update_event.data
    end

    Elsa.produce([localhost: 9092], "test", {"DELETE", Jason.encode!(%{"id" => 123})})

    assert_async(timeout: 2_000, sleep_time: 200) do
      assert nil == Brook.get(123)
    end
  end

  defp kill_and_wait(pid, timeout \\ 1_000) do
    ref = Process.monitor(pid)
    Process.exit(pid, :normal)
    assert_receive {:DOWN, ^ref, _, _, _}, timeout
  end
end
