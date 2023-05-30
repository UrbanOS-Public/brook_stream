defmodule Brook.Driver.KafkaTest do
  use ExUnit.Case
  import Mock

  setup_with_mocks([
    {Registry, [], [meta: fn(_, _) -> {:ok, %{connection: :client, topic: :topic}} end]}
  ]) do
    :ok
  end

  describe "send_event/2" do
    test "will retry several times before giving up" do
      :meck.new(Elsa)
      :meck.expect(Elsa, :produce, 3, :meck.seq([{:error, "message", []}, {:error, "message", []}, :ok]))

      assert :ok == Brook.Driver.Kafka.send_event(:registry, :type, :message)

      assert_called_exactly Elsa.produce(:client, :topic, {:type, :message}), 3

      :meck.unload(Elsa)
    end

    test "will return the last error received" do
      with_mock(Elsa, [produce: fn(_, _, _) -> {:error, "message", []} end]) do
        assert {:error, "message", []} == Brook.Driver.Kafka.send_event(:registry, :type, :message)
      end
    end
  end
end
