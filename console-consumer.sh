#!/bin/bash

sudo kafka-avro-console-consumer \
  --bootstrap-server localhost:29092 \
  --topic orders