package main

import (
	"io/ioutil"
	"log"
        "time"
        "github.com/Shopify/sarama"
)

func produce(directory string, topic string) {

	config := sarama.NewConfig()
	config.Version = sarama.V2_0_0_0
        config.Producer.Flush.Frequency = time.Second * 1
	config.Producer.Flush.Messages = 1000
	config.Producer.Flush.MaxMessages = 1000
        broker := "23.23.87.67:9200,35.174.222.219:9200,54.145.72.101:9200"
        p, err := sarama.NewAsyncProducer([]string{broker}, config)

	if err != nil {
		panic(err)
	}

	defer p.Close()

        //topic := "atlas_mlo_59073"

        files, err := ioutil.ReadDir(directory)
        if err != nil {
                panic(err)
        }

        for _, file := range files {
                f, err := ioutil.ReadFile(directory+"/"+file.Name())
                if err != nil {
                       panic(err)
                }  

                p.Input() <- &sarama.ProducerMessage{Topic: topic, Value: sarama.ByteEncoder([]byte(f))}
		        if err != nil {
			        log.Printf("FAILED to send message: %s\n", err)
		        }
        }
        
}
