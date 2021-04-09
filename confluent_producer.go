package main

import (
	"fmt"
	"gopkg.in/confluentinc/confluent-kafka-go.v1/kafka"
	"io/ioutil"
)

func produce(directory string, topic string) {
        files, err := ioutil.ReadDir(directory)
        if err != nil {
		panic(err)
        }

        server := "23.23.87.67:9200,35.174.222.219:9200,54.145.72.101:9200"
        //topic := "test_atlas"

        p, err := kafka.NewProducer(&kafka.ConfigMap{
                        "bootstrap.servers": server,
                        "linger.ms": 5,
                })

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
                                }
                        }
                }
        }()

        
        for _, file := range files {
       	        f, err := ioutil.ReadFile(directory+"/"+file.Name())
	        if err != nil {
		       panic(err)
	        }

	        p.Produce(&kafka.Message{
		        TopicPartition: kafka.TopicPartition{Topic: &topic, Partition: kafka.PartitionAny},
		        Value:          []byte(f),
	        }, nil)
        }
        p.Flush(1500 * 1000)
}
