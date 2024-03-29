package main

import (
	"gopkg.in/confluentinc/confluent-kafka-go.v1/kafka"
	"io/ioutil"
)

func produce(directory string, topic string, server string, user string, password string) error {
	files, err := ioutil.ReadDir(directory)
	if err != nil {
		return err
	}

	p, err := kafka.NewProducer(&kafka.ConfigMap{
		"bootstrap.servers": server,
		"linger.ms":         5,
		"sasl.mechanisms":   "SCRAM-SHA-512",
		"security.protocol": "SASL_SSL",
		"sasl.username":     user,
		"sasl.password":     password,
	})

	if err != nil {
		return err
	}

	defer p.Close()
	go func() {
		for e := range p.Events() {
			switch ev := e.(type) {
			case *kafka.Message:
				if ev.TopicPartition.Error != nil {
					ErrorLogger.Printf("Delivery failed: %v\n", ev.TopicPartition)
				}
			}
		}
	}()

	for _, file := range files {
		f, err := ioutil.ReadFile(directory + "/" + file.Name())
		if err != nil {
			ErrorLogger.Println(file.Name(), err)
			continue
		}

		err = p.Produce(&kafka.Message{
			TopicPartition: kafka.TopicPartition{Topic: &topic, Partition: kafka.PartitionAny},
			Key:            []byte(file.Name()[:len(file.Name())-5]),
			Value:          []byte(f),
		}, nil)
		if err != nil {
			ErrorLogger.Println(file.Name(), err)
			continue
		}
	}
	p.Flush(1500 * 1000)
	return err
}
