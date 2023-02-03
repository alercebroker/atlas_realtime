from fastavro import reader
import sys
import os

avro_path = sys.argv[1]
avro_path = os.path.join(os.path.dirname(__file__), avro_path)

print(avro_path)

with open(avro_path,'rb') as f:
    freader = reader(f)
    schema = freader.writer_schema

    for packet in freader:
        print(packet.keys())
