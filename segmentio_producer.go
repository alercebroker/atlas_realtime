package main

import (
	"fmt"
	"io/ioutil"
	"log"
        "context"
        kafka "github.com/segmentio/kafka-go"
)

func newKafkaWriter(kafkaURL, topic string) *kafka.Writer {
	return kafka.NewWriter(kafka.WriterConfig{
		Brokers:  []string{kafkaURL},
		Topic:    topic,
		Balancer: &kafka.LeastBytes{},
	})
}

func produce(file string) {
        fmt.Println(file)
    // Open AVRO file to send
	f, err := ioutil.ReadFile(file)
	if err != nil {
		log.Fatal(err)
	}

        kafkaURL := "host:port"
        topic := "atlas_mlo_test"
        writer := newKafkaWriter(kafkaURL, topic)
	defer writer.Close()
	fmt.Println("start producing ... !!")
	msg := kafka.Message{Value: []byte(f),
        }
	err = writer.WriteMessages(context.Background(), msg)
	if err != nil {
		fmt.Println(err)
	}

}
