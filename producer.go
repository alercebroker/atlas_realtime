package main

import (
	"fmt"
	"gopkg.in/confluentinc/confluent-kafka-go.v1/kafka"
	"io/ioutil"
	"log"
)

func produce(file string) {

    // Open AVRO file to send
	f, err := ioutil.ReadFile(file)
	if err != nil {
		log.Fatal(err)
	}

	p, err := kafka.NewProducer(&kafka.ConfigMap{"bootstrap.servers": "ec2-3-22-33-46.us-east-2.compute.amazonaws.com:9092"})
	if err != nil {
		panic(err)
	}

	defer p.Close()

	go func() {
		for e := range p.Events() {
			switch ev := e.(type) {
			case *kafka.Message:
				if ev.TopicPartition.Error != nil {
					fmt.Printf("Delivery failed: %v\n", ev.TopicPartition)
				} else {
					fmt.Printf("Delivered message to %v\n", ev.TopicPartition)
				}
			}
		}
	}()

  topic := "test_atlas"
	p.Produce(&kafka.Message{
		TopicPartition: kafka.TopicPartition{Topic: &topic, Partition: kafka.PartitionAny},
		Value:          []byte(f),
	}, nil)

	p.Flush(15 * 1000)
}
