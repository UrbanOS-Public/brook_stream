require Protocol
Protocol.derive(Jason.Encoder, Brook.Event)

defimpl Brook.Event.Serializer, for: Any do
  def serialize(data) do
    Jason.encode(data)
  end
end

defimpl Brook.Event.Serializer, for: Brook.Event do
  def serialize(%Brook.Event{} = event) do
    %{"type" => event.type, "author" => event.author, "create_ts" => event.create_ts}
    |> serialize_data(event.data)
    |> add_struct(event.data)
    |> encode()
  end

  defp serialize_data(message, data) do
    case Brook.Event.Serializer.serialize(data) do
      {:ok, value} -> {:ok, Map.put(message, "data", value)}
      error_result -> error_result
    end
  end

  defp add_struct({:ok, message}, %custom_struct{}) do
    {:ok, Map.put(message, "__struct__", custom_struct)}
  end
  defp add_struct(message, _data), do: message

  defp encode({:ok, value}), do: Jason.encode(value)
  defp encode({:error, _reason} = error), do: error
end

defimpl Brook.Event.Deserializer, for: Any do
  def deserialize(:undefined, data) do
    Jason.decode(data)
  end

  def deserialize(%struct_module{}, data) do
    case Jason.decode(data, keys: :atoms) do
      {:ok, decoded_json} -> {:ok, struct(struct_module, decoded_json)}
      error_result -> error_result
    end
  end
end

defimpl Brook.Event.Deserializer, for: Brook.Event do
  def deserialize(%Brook.Event{}, data) do
    data
    |> Jason.decode(keys: :atoms)
    |> get_struct()
    |> deserialize_data()
    |> to_struct()
  end

  defp get_struct({:ok, %{__struct__: custom_struct} = data}) do
    struct_module = String.to_atom(custom_struct)
    Code.ensure_loaded(struct_module)
    case function_exported?(struct_module, :__struct__, 0) do
      true -> {:ok, struct(struct_module), Map.delete(data, :__struct__)}
      false -> {:error, :invalid_struct}
    end
  end
  defp get_struct({:ok, data}), do: {:ok, :undefined, data}
  defp get_struct({:error, _reason} = error), do: error

  defp deserialize_data({:ok, data_struct, decoded_json}) do
    case Brook.Event.Deserializer.deserialize(data_struct, decoded_json.data) do
      {:ok, value} -> {:ok, Map.put(decoded_json, :data, value)}
      error_result -> error_result
    end
  end
  defp deserialize_data({:error, _reason} = error), do: error

  defp to_struct({:ok, value}), do: {:ok, struct(Brook.Event, value)}
  defp to_struct({:error, _reason} = error), do: error

end
