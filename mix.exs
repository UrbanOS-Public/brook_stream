defmodule Brook.MixProject do
  use Mix.Project

  def project do
    [
      app: :brook_stream,
      version: "1.0.0",
      elixir: "~> 1.14",
      description: description(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: test_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [plt_file: {:no_warn, ".plt/dialyzer.plt"}]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:brook_serializer, "~> 2.2.1"},
      {:json_serde, "~> 1.1"},
      {:redix, "~> 1.2"},
      {:elsa_kafka, "~> 2.0"},
      {:mock, "~> 0.3.7", only: [:dev, :test, :integration]},
      {:assertions, "~> 0.19", only: [:test, :integration]},
      {:divo, "~> 2.0", only: [:dev, :integration]},
      {:divo_kafka, "~> 1.0", only: [:integration]},
      {:divo_redis, "~> 1.0", only: [:integration]},
      {:ex_doc, "~> 0.29", only: [:dev]},
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false}
    ]
  end

  defp elixirc_paths(env) when env in [:test, :integration], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]

  defp package do
    [
      maintainers: ["smartcitiesData"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/UrbanOS-Public/brook_stream"}
    ]
  end

  defp description do
    "Brook provides an event stream client interface for distributed applications.
    Brook sends and receives messages with the event stream via a driver
    module and persists an application-specific view of the event stream via a
    storage module."
  end
end
