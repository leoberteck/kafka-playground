#!/bin/bash

# {
#   "type": "record",
#   "name": "pgsinkdemo",
#   "fields": [
#     { "name": "id", "type": "int" },
#     { "name": "product", "type": "string" },
#     { "name": "quantity", "type": "int" },
#     { "name": "price", "type": "float" }
#   ]
# }


kafka-avro-console-producer \
 --broker-list localhost:9092 --topic orders \
 --property value.schema='{"type":"record","name":"myrecord","fields":[{"name":"id","type":"int"},{"name":"product", "type": "string"}, {"name":"quantity", "type": "int"}, {"name":"price",
 "type": "float"}]}'
