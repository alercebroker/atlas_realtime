package main

import (
	"encoding/json"
	"os"
)

// Configuration struct
type Configuration struct {
	OutputDirectory string
	MongodbHost     string
	MongodbPort     string
	MongodbUser     string
	MongodbPass     string
	Db              string
	Col             string
	KafkaServer1    string
	KafkaServer2    string
	LogFile         string
	ErrFile         string
}

/*
* loadConfiguration receives the path to a configuration file and returns
* a Configuration instance that contains the values of the file.
 */
func loadConfiguration(filename string) (*Configuration, error) {
	bytes, err := os.ReadFile(filename)
	if err != nil {
		return &Configuration{}, err
	}
	var c Configuration
	err = json.Unmarshal(bytes, &c)
	if err != nil {
		return &Configuration{}, err
	}
	return &c, nil
}
