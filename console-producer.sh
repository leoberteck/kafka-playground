#!/bin/bash

confluent-5.3.1/bin/kafka-avro-console-producer \
  --broker-list localhost:9092 \
  --topic orders \
  --property parse.key=true \
  --property key.separator=,\
  --property key.schema='{"type":"record","name":"pgsinkdemo_key","fields":[{"name":"id","type":"int"}]}' \
  --property value.schema='["null",{"type":"record","name":"pgsinkdemo","fields":[{"name":"id","type":"int"},{"name":"product","type":"string"},{"name":"quantity","type":"int"},{"name":"price","type":"float"}]}]'

# { "id": 1 },{ "id": 1, "product": "foo", "quantity": 100, "price": 10 }
# { "id": 2 },{ "id": 2, "product": "bolacha", "quantity": 10, "price": 20 }
# { "id": 3 },{ "id": 3, "product": "farofa", "quantity": 2, "price": 13 }
# { "id": 4 },{ "id": 4, "product": "macarrao", "quantity": 32, "price": 15 }
# { "id": 5 },{ "id": 5, "product": "arroz", "quantity": 5, "price": 3 }
