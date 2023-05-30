import Config

host =
  case System.get_env("HOST_IP") do
    nil -> "127.0.0.1"
    defined -> defined
  end

redix_args = [host: host]

config :brook_stream,
  divo: [
    {DivoKafka,
    [
      create_topics: "test:1:1",
      outside_host: host,
      auto_topic: false,
      kafka_image_version: "2.12-2.1.1"
    ]},
    DivoRedis
  ],
  divo_wait: [dwell: 700, max_tries: 50],
  retry_count: 5,
  retry_initial_delay: 1500,
  storage: [
    module: Brook.Storage.Redis,
    init_arg: [redix_args: redix_args, namespace: "andi:view"]
  ]
